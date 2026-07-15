import 'dart:typed_data';

import 'package:baidoxe_app/models/message_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../../providers/swipe_card_provider.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  // Tông màu lấy theo demo (card xanh đậm, nút xanh dương / đỏ, pill trắng)
  static const Color _cardColor = Color(0xFF173A2E);
  static const Color _iconBoxColor = Color(0xFF2C5C48);
  static const Color _openColor = Color(0xFF4A90D9);
  static const Color _closeColor = Color(0xFFE05A54);
  static const Color _accentGreen = Color(0xFF0B7A44);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SwipeCardProvider>();

    switch (provider.state) {
      // 1 = Chỉ có xe vào -> hiển thị 1 card, canh giữa màn hình
      case 1:
        return Center(
          child: SizedBox(
            width: 480,
            child: _buildVehicleCard(
              title: "Thông tin xe vào",
              headerIcon: Icons.login,
              message: provider.entryMessage,
              imageBytes: provider.entryImageBytes,
              isFixing: true,
              isHintButtom: false,
            ),
          ),
        );

      // 2 = Có cả xe vào và xe ra -> hiển thị 2 card song song
      case 2:
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildVehicleCard(
                  title: "Thông tin xe vào",
                  headerIcon: Icons.login,
                  message: provider.entryMessage,
                  imageBytes: provider.entryImageBytes,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildVehicleCard(
                  title: "Thông tin xe ra",
                  headerIcon: Icons.logout,
                  message: provider.exitMessage,
                  imageBytes: provider.exitImageBytes,
                  isFixing: true,
                  isHintButtom: false,
                ),
              ),
            ],
          ),
        );

      // 0 = Chưa có dữ liệu
      default:
        return _buildEmptyState();
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_car_outlined, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            "Chưa có dữ liệu",
            style: TextStyle(
              fontSize: 22,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Card thông tin xe dùng chung cho cả xe vào và xe ra
  Widget _buildVehicleCard({
    required String title,
    required IconData headerIcon,
    required Message? message,
    required Uint8List? imageBytes,
    bool isFixing = false,
    bool isHintButtom = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTitlePill(title, headerIcon),
          const SizedBox(height: 24),

          _buildInfoRow(
            icon: Icons.credit_card,
            label: "ID thẻ",
            value: message?.data["uid"]?.toString() ?? "",
          ),
          const SizedBox(height: 14),

          _buildInfoRow(
            icon: Icons.directions_car,
            label: "Biển số xe",
            value: message?.data["plate"]?.toString() ?? "",
          ),
          const SizedBox(height: 14),

          _buildInfoRow(
            icon: Icons.access_time,
            label: "Thời gian",
            value: message?.data["time"]?.toString() ?? "",
          ),
          const SizedBox(height: 14),

          _buildInfoRow(
            icon: Icons.edit,
            label: "Sửa biển số ",
            value: message?.data["fix"]?.toString() ?? "",
            editable: isFixing,
            onSubmit: (newValue) {
              // TODO: lưu newValue vào provider, ví dụ:
              // context.read<SwipeCardProvider>().updateFixPlate(...);
            },
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              _buildIconBox(Icons.image_outlined),
              const SizedBox(width: 10),
              const Text(
                "Ảnh",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildImageBox(imageBytes),

          const SizedBox(height: 24),
          if (!isHintButtom)
            Row(
              children: [
                Expanded(child: _buildActionButton("Mở cổng", Icons.lock_open, _openColor, () {})),
                const SizedBox(width: 16),
                Expanded(child: _buildActionButton("Đóng cổng", Icons.lock, _closeColor, () {})),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTitlePill(String title, IconData icon) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(color: _accentGreen, shape: BoxShape.circle),
            child: Icon(icon, size: 15, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBox(IconData icon) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(color: _iconBoxColor, borderRadius: BorderRadius.circular(6)),
      child: Icon(icon, size: 16, color: Colors.white),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool editable = false,
    ValueChanged<String>? onSubmit,
  }) {
    return Row(
      children: [
        _buildIconBox(icon),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15)),
        ),
        Expanded(
          child: editable
              ? _EditableValueField(
                  initialValue: value,
                  onSubmit: onSubmit,
                )
              : Container(
                  height: 38,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    value.isEmpty ? "—" : value,
                    style: TextStyle(
                      fontSize: 15,
                      color: value.isEmpty ? Colors.grey.shade400 : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildImageBox(Uint8List? imageBytes) {
    return AspectRatio(
      aspectRatio: 6 / 4,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
        clipBehavior: Clip.antiAlias,
        child: imageBytes == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_outlined, size: 40, color: Colors.grey.shade400),
                    const SizedBox(height: 6),
                    Text("6x4", style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                  ],
                ),
              )
            : Image.memory(imageBytes, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    );
  }
}

/// Ô nhập liệu cho phần "Sửa biển số" khi isFixing = true
class _EditableValueField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String>? onSubmit;

  const _EditableValueField({
    required this.initialValue,
    this.onSubmit,
  });

  @override
  State<_EditableValueField> createState() => _EditableValueFieldState();
}

class _EditableValueFieldState extends State<_EditableValueField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _EditableValueField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Khi có xe mới (AI đọc biển số mới) thì đồng bộ lại text,
    // nhưng không ghi đè nếu admin đang gõ dở giá trị khác
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: _controller,
        style: const TextStyle(fontSize: 15, color: Colors.black87),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: InputBorder.none,
          hintText: "Nhập biển số đúng...",
        ),
        onSubmitted: widget.onSubmit,
        onEditingComplete: () => widget.onSubmit?.call(_controller.text),
      ),
    );
  }
}