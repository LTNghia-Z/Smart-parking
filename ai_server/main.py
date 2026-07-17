import os
import re
import json
import requests

from datetime import datetime
from pathlib import Path

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles


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
BASE_DIR = Path(__file__).resolve().parent
UPLOADS_DIR = BASE_DIR / "uploads"
UPLOADS_DIR.mkdir(parents=True, exist_ok=True)

app.mount("/uploads", StaticFiles(directory=str(UPLOADS_DIR)), name="uploads")


def sanitize_filename_part(value: str) -> str:
    value = (value or "").strip()

    if not value:
        return "unknown"

    value = re.sub(r"[^A-Za-z0-9_.-]+", "_", value)
    value = value.strip("._-")

    return value or "unknown"


def normalize_time_key(value: str) -> str:
    value = (value or "").strip()
    if not value:
        return ""

    candidates = [
        "%Y-%m-%d_%H-%M-%S",
        "%Y-%m-%d_%H_%M_%S",
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%dT%H:%M:%S.%fZ",
        "%Y-%m-%d %H:%M:%S.%f",
    ]

    for fmt in candidates:
        try:
            dt = datetime.strptime(value, fmt)
            return dt.strftime("%Y-%m-%d_%H_%M_%S")
        except ValueError:
            continue

    normalized = value.replace("T", " ").replace("t", " ")
    normalized = re.sub(r"[\s:]+", "_", normalized)
    normalized = re.sub(r"_+", "_", normalized)
    return normalized.strip("_ ")


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


@app.post("/save-gate-image")
async def save_gate_image(
    file: UploadFile = File(...),
    cid: str = Form("unknown"),
    time: str = Form(""),
):
    try:
        safe_cid = sanitize_filename_part(cid)
        safe_time = sanitize_filename_part(
            normalize_time_key(time)
            or datetime.now().strftime("%Y-%m-%d_%H_%M_%S")
        )

        target_dir = UPLOADS_DIR
        target_dir.mkdir(parents=True, exist_ok=True)

        file_name = f"{safe_cid}_{safe_time}.jpg"
        file_path = target_dir / file_name

        image_bytes = await file.read()
        file_path.write_bytes(image_bytes)

        relative_path = f"uploads/{file_name}"

        return {
            "success": True,
            "fileName": file_name,
            "relativePath": relative_path,
            "url": f"/{relative_path}",
        }

    except Exception as e:
        return {
            "success": False,
            "message": str(e),
        }


@app.get("/gate-image")
def get_gate_image(cid: str, time: str):
    safe_cid = sanitize_filename_part(cid)
    safe_time = sanitize_filename_part(normalize_time_key(time))
    file_path = UPLOADS_DIR / f"{safe_cid}_{safe_time}.jpg"

    if not file_path.is_file():
        raise HTTPException(status_code=404, detail="Không tìm thấy ảnh quẹt thẻ")

    return FileResponse(file_path, media_type="image/jpeg")


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
