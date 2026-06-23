import os
import re
import json
import requests

from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware


app = FastAPI(title="Parking Plate Recognition API - Plate Recognizer")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


PLATE_RECOGNIZER_TOKEN = os.getenv("PLATE_RECOGNIZER_TOKEN")
PLATE_RECOGNIZER_URL = "https://api.platerecognizer.com/v1/plate-reader/"


def normalize_plate_text(text: str) -> str:
    """
    Chuẩn hóa biển số để lưu DB.
    Ví dụ:
    29-B1 555.55 -> 29B155555
    29b155555 -> 29B155555
    """
    if not text:
        return ""

    text = text.upper()
    text = text.replace(" ", "")
    text = text.replace("-", "")
    text = text.replace(".", "")
    text = text.replace(":", "")
    text = text.replace("_", "")
    text = re.sub(r"[^A-Z0-9]", "", text)
    return text


def is_possible_vietnam_plate(text: str) -> bool:
    """
    Check tương đối biển Việt Nam.
    Không quá chặt để tránh API trả đúng nhưng format hơi khác.
    """
    text = normalize_plate_text(text)

    if len(text) < 7 or len(text) > 10:
        return False

    patterns = [
        r"^[0-9]{2}[A-Z][0-9]{5}$",       # 30A12345
        r"^[0-9]{2}[A-Z][0-9]{6}$",       # 29B155555
        r"^[0-9]{2}[A-Z][0-9]{7}$",       # rộng hơn
        r"^[0-9]{2}[A-Z]{2}[0-9]{5}$",    # 30AB12345
        r"^[0-9]{2}[A-Z]{2}[0-9]{6}$",    # 30AB123456
    ]

    return any(re.match(pattern, text) for pattern in patterns)


def format_plate_for_display(plate: str) -> str:
    """
    Format để hiển thị.
    DB vẫn nên lưu dạng normalize.
    """
    plate = normalize_plate_text(plate)

    # 29B155555 -> 29-B1 555.55
    if re.match(r"^[0-9]{2}[A-Z][0-9]{6}$", plate):
        province = plate[:2]
        series = plate[2:4]
        numbers = plate[4:]
        return f"{province}-{series} {numbers[:3]}.{numbers[3:]}"

    # 30A12345 -> 30-A 123.45
    if re.match(r"^[0-9]{2}[A-Z][0-9]{5}$", plate):
        province = plate[:2]
        series = plate[2]
        numbers = plate[3:]
        return f"{province}-{series} {numbers[:3]}.{numbers[3:]}"

    # 30AB12345 -> 30-AB 123.45
    if re.match(r"^[0-9]{2}[A-Z]{2}[0-9]{5}$", plate):
        province = plate[:2]
        series = plate[2:4]
        numbers = plate[4:]
        return f"{province}-{series} {numbers[:3]}.{numbers[3:]}"

    return plate


def call_plate_recognizer(image_bytes: bytes):
    if not PLATE_RECOGNIZER_TOKEN:
        raise Exception(
            "Thiếu PLATE_RECOGNIZER_TOKEN. Hãy chạy: "
            "set PLATE_RECOGNIZER_TOKEN=YOUR_API_TOKEN"
        )

    headers = {
        "Authorization": f"Token {PLATE_RECOGNIZER_TOKEN}",
    }

    files = {
        "upload": ("plate.jpg", image_bytes, "image/jpeg"),
    }

    # text_formats giúp engine ưu tiên dạng biển số gần với Việt Nam.
    # Nếu API báo lỗi config, có thể xóa phần data này và chỉ gửi files.
    config = {
        "text_formats": [
            "[0-9][0-9][a-z][0-9][0-9][0-9][0-9][0-9][0-9]",
            "[0-9][0-9][a-z][0-9][0-9][0-9][0-9][0-9]",
            "[0-9][0-9][a-z][a-z][0-9][0-9][0-9][0-9][0-9]",
        ],
        "plates_per_vehicle": 1,
    }

    data = {
        # Có thể thử thêm regions="vn".
        # Nếu API báo region không hợp lệ, bỏ dòng này.
        "regions": "vn",
        "config": json.dumps(config),
    }

    response = requests.post(
        PLATE_RECOGNIZER_URL,
        headers=headers,
        files=files,
        data=data,
        timeout=30,
    )

    if response.status_code >= 400:
        raise Exception(
            f"Plate Recognizer error {response.status_code}: {response.text}"
        )

    return response.json()


def pick_best_result(api_json: dict):
    results = api_json.get("results", [])

    if not results:
        return None

    # Ưu tiên kết quả có score OCR cao và dscore detect cao.
    def result_score(item):
        score = float(item.get("score", 0))
        dscore = float(item.get("dscore", 0))
        return score * 0.7 + dscore * 0.3

    results.sort(key=result_score, reverse=True)

    return results[0]


@app.get("/")
def health_check():
    return {
        "status": "AI server is running",
        "engine": "Plate Recognizer Cloud API",
        "message": "Use POST /recognize-plate to upload image",
    }


@app.post("/recognize-plate")
async def recognize_plate(file: UploadFile = File(...)):
    try:
        image_bytes = await file.read()

        api_json = call_plate_recognizer(image_bytes)
        best = pick_best_result(api_json)

        if best is None:
            return {
                "success": False,
                "plateNumber": None,
                "displayPlate": None,
                "message": "Plate Recognizer không phát hiện được biển số",
                "rawApi": api_json,
            }

        raw_plate = best.get("plate", "")
        normalized_plate = normalize_plate_text(raw_plate)
        display_plate = format_plate_for_display(normalized_plate)

        return {
            "success": True,
            "plateNumber": normalized_plate,
            "displayPlate": display_plate,
            "rawText": raw_plate,
            "confidence": best.get("score"),
            "detectionConfidence": best.get("dscore"),
            "box": best.get("box"),
            "vehicle": best.get("vehicle"),
            "isVietnamPlateLike": is_possible_vietnam_plate(normalized_plate),
            "rawApi": api_json,
        }

    except Exception as e:
        return {
            "success": False,
            "plateNumber": None,
            "displayPlate": None,
            "message": str(e),
            "rawApi": None,
        }