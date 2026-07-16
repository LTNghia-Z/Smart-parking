import 'dart:math' as math;
import 'dart:typed_data';

import 'package:baidoxe_app/models/message_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/swipe_card_provider.dart';
import '../../services/firebase_realtime_service.dart';
import '../../services/gate_image_service.dart';

/// Xác định card đang thao tác là xe VÀO hay xe RA
/// -> quyết định type message gửi đi ("..._vao" / "..._ra")
enum GateSide { entry, exit }

extension GateSideCommand on GateSide {
  String get openType => this == GateSide.entry ? 'mo_cong_vao' : 'mo_cong_ra';
  String get closeType =>
      this == GateSide.entry ? 'dong_cong_vao' : 'dong_cong_ra';
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SwipeCardProvider>();

    switch (provider.state) {
      // 1 = Chỉ có xe vào -> hiển thị 1 card, canh giữa màn hình
      case 1:
        return LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth < 760
                ? constraints.maxWidth
                : (constraints.maxWidth - 24) / 2;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: cardWidth),
                  child: _VehicleCard(
                    title: "Thông tin xe vào",
                    headerIcon: Icons.login,
                    message: provider.entryMessage,
                    imageBytes: provider.entryImageBytes,
                    requestVersion: provider.requestVersion,
                    isFixing: true,
                    isHintButtom: false,
                    side: GateSide.entry,
                  ),
                ),
              ),
            );
          },
        );

      // 2 = Có cả xe vào và xe ra -> hiển thị 2 card song song
      case 2:
        return _buildExitState(provider);

      // 0 = Chưa có dữ liệu
      default:
        return _buildEmptyState(
          errorMessage: provider.errorMessage,
          isLoading: provider.isLoading,
        );
    }
  }

  Widget _buildExitState(SwipeCardProvider provider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final entryCard = _VehicleCard(
          title: "Thông tin xe vào",
          headerIcon: Icons.login,
          message: provider.entryMessage,
          imageBytes: provider.entryImageBytes,
          requestVersion: provider.requestVersion,
          side: GateSide.entry,
        );
        final exitCard = _VehicleCard(
          title: "Thông tin xe ra",
          headerIcon: Icons.logout,
          message: provider.exitMessage,
          imageBytes: provider.exitImageBytes,
          requestVersion: provider.requestVersion,
          isFixing: true,
          isHintButtom: false,
          side: GateSide.exit,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = math.min(constraints.maxWidth, 1320.0);
              final isCompact = maxWidth < 860;

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _VehicleComparisonBanner(
                        isMatched: provider.platesMatch,
                        message:
                            provider.comparisonMessage ??
                            "Không đủ dữ liệu biển số để đối chiếu.",
                      ),
                      const SizedBox(height: 18),
                      if (!isCompact)
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: entryCard),
                              const SizedBox(width: 24),
                              Expanded(child: exitCard),
                            ],
                          ),
                        )
                      else ...[
                        entryCard,
                        const SizedBox(height: 24),
                        exitCard,
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({String? errorMessage, required bool isLoading}) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF0B7A44)),
            SizedBox(height: 16),
            Text(
              "Đang xử lý dữ liệu quẹt thẻ...",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    final hasError = errorMessage != null && errorMessage.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasError ? Icons.error_outline : Icons.directions_car_outlined,
              size: 72,
              color: hasError ? Colors.red.shade400 : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              hasError ? errorMessage : "Chưa có dữ liệu",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                color: hasError ? Colors.red.shade700 : Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleComparisonBanner extends StatelessWidget {
  final bool? isMatched;
  final String message;

  const _VehicleComparisonBanner({
    required this.isMatched,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (isMatched) {
      true => const Color(0xFF14804A),
      false => const Color(0xFFC63838),
      null => const Color(0xFF9A6700),
    };
    final icon = switch (isMatched) {
      true => Icons.verified,
      false => Icons.warning_rounded,
      null => Icons.info_outline,
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card thông tin 1 xe (vào hoặc ra), tự quản lý ô sửa biển số
/// và xử lý logic gửi message khi bấm mở/đóng cổng.
class _VehicleCard extends StatefulWidget {
  final String title;
  final IconData headerIcon;
  final Message? message;
  final Uint8List? imageBytes;
  final int requestVersion;
  final bool isFixing;
  final bool isHintButtom;
  final GateSide side;

  const _VehicleCard({
    required this.title,
    required this.headerIcon,
    required this.message,
    required this.imageBytes,
    required this.requestVersion,
    required this.side,
    this.isFixing = false,
    this.isHintButtom = true,
  });

  @override
  State<_VehicleCard> createState() => _VehicleCardState();
}

class _VehicleCardState extends State<_VehicleCard> {
  static const Color _cardColor = Color(0xFF173A2E);
  static const Color _iconBoxColor = Color(0xFF2C5C48);
  static const Color _openColor = Color(0xFF4A90D9);
  static const Color _closeColor = Color(0xFFE05A54);
  static const Color _accentGreen = Color(0xFF0B7A44);

  final GateImageService _gateImageService = GateImageService();

  late TextEditingController _fixController;
  String? _lastUid; // để biết khi nào đổi sang xe khác thì reset ô fix

  @override
  void initState() {
    super.initState();
    _fixController = TextEditingController(text: _initialFixValue);
    _lastUid = widget.message?.data["uid"]?.toString();
  }

  String get _initialFixValue => widget.message?.data["fix"]?.toString() ?? "";

  @override
  void didUpdateWidget(covariant _VehicleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newUid = widget.message?.data["uid"]?.toString();
    // Chỉ reset nội dung ô fix khi ĐỔI SANG XE KHÁC (uid khác),
    // để không ghi đè giá trị admin đang gõ dở cho cùng 1 xe.
    if (newUid != _lastUid) {
      _lastUid = newUid;
      _fixController.text = _initialFixValue;
    }
  }

  @override
  void dispose() {
    _fixController.dispose();
    super.dispose();
  }

  // ----------------- Logic gửi message -----------------

  Future<void> _handleOpenGate() async {
    final plate = widget.message?.data["plate"]?.toString() ?? "";
    final fix = _fixController.text.trim();

    widget.message?.data["plate"] =
        plate; // Nếu sửa thì gửi biển số sửa, không thì giữ nguyên
    widget.message?.data["fix"] =
        fix; // Cập nhật biển số sửa vào message trước khi gửi

    final message = Message(
      type: widget.side.openType, // "mo_cong_vao" hoặc "mo_cong_ra"
      data: widget.message?.data ?? const {},
    );

    await _sendMessage(message);
  }

  Future<void> _handleCloseGate() async {
    final expectedRequestVersion = widget.requestVersion;
    final success = await _sendCommand(type: widget.side.closeType, data: "");

    if (!success || !mounted) {
      return;
    }

    final provider = context.read<SwipeCardProvider>();

    if (widget.side == GateSide.entry && provider.state == 1) {
      await _saveGateImage();
    }

    provider.clearIfCurrentRequest(expectedRequestVersion);
  }

  Future<bool> _sendMessage(Message message) async {
    return _sendCommand(type: message.type, data: message.data);
  }

  Future<bool> _sendCommand({required String type, Object? data}) async {
    try {
      await FirebaseRealtimeService.instance.sendCommand(
        type: type,
        data: data,
      );
      debugPrint("Gửi message: type=$type, data=$data");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi lệnh lên Firebase')),
        );
      }
      return true;
    } catch (e) {
      debugPrint("Gửi message thất bại: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gửi thất bại: $e')));
      }
      return false;
    }
  }

  Future<void> _saveGateImage() async {
    final imageBytes = widget.imageBytes;

    if (imageBytes == null) {
      debugPrint("Không có ảnh để lưu lên ai_server.");
      return;
    }

    final data = widget.message?.data ?? const <String, dynamic>{};
    final uid = data["uid"]?.toString() ?? "unknown";
    final time = data["time"]?.toString() ?? "";
    try {
    
      final result = await _gateImageService.saveGateImage(
        imageBytes: imageBytes,
        uid: uid,
        time: time,
      );

      debugPrint(
        "Lưu ảnh ai_server: success=${result.success}, path=${result.relativePath}",
      );

      if (mounted && !result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lưu ảnh thất bại: ${result.message ?? ""}')),
        );
      }
    } catch (e) {
      debugPrint("Lưu ảnh ai_server thất bại: $e");

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lưu ảnh thất bại: $e')));
      }
    }
  }

  // ----------------- UI -----------------

  @override
  Widget build(BuildContext context) {
    final message = widget.message;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTitlePill(widget.title, widget.headerIcon),
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

          Row(
            children: [
              _buildIconBox(Icons.edit),
              const SizedBox(width: 10),
              const SizedBox(
                width: 100,
                child: Text(
                  "Sửa biển số",
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
              Expanded(
                child: widget.isFixing
                    ? _EditableValueField(controller: _fixController)
                    : _ReadOnlyValueBox(value: _initialFixValue),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              _buildIconBox(Icons.image_outlined),
              const SizedBox(width: 10),
              const Text(
                "Ảnh",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildImageBox(widget.imageBytes),

          const SizedBox(height: 24),
          if (!widget.isHintButtom)
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    "Mở cổng",
                    Icons.lock_open,
                    _openColor,
                    _handleOpenGate,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    "Đóng cổng",
                    Icons.lock,
                    _closeColor,
                    _handleCloseGate,
                  ),
                ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: _accentGreen,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBox(IconData icon) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: _iconBoxColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 16, color: Colors.white),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        _buildIconBox(icon),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
        Expanded(child: _ReadOnlyValueBox(value: value)),
      ],
    );
  }

  Widget _buildImageBox(Uint8List? imageBytes) {
    return AspectRatio(
      aspectRatio: 6 / 4,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
        ),
        clipBehavior: Clip.antiAlias,
        child: imageBytes == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 40,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "6x4",
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            : Image.memory(imageBytes, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }
}

/// Ô hiển thị giá trị dạng đọc (không sửa được)
class _ReadOnlyValueBox extends StatelessWidget {
  final String value;
  const _ReadOnlyValueBox({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

/// Ô nhập liệu cho phần "Sửa biển số" — nhận controller từ bên ngoài
/// để widget cha (_VehicleCardState) đọc được giá trị hiện tại khi bấm nút.
class _EditableValueField extends StatelessWidget {
  final TextEditingController controller;
  const _EditableValueField({required this.controller});

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
        controller: controller,
        style: const TextStyle(fontSize: 15, color: Colors.black87),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: InputBorder.none,
          hintText: "Nhập biển số đúng...",
        ),
      ),
    );
  }
}
