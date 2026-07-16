import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/parking_provider.dart';

class ParkingPage extends StatelessWidget {
  const ParkingPage({super.key});

  static const Color _green = Color(0xFF18A558);
  static const Color _red = Color(0xFFE5484D);
  static const Color _ink = Color(0xFF16251E);

  @override
  Widget build(BuildContext context) {
    final parking = context.watch<ParkingProvider>();

    return ColoredBox(
      color: const Color(0xFFF4F8F6),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PageHeader(errorMessage: parking.errorMessage),
                const SizedBox(height: 20),
                Expanded(
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _ParkingGrid(slots: parking.slots)),
                            const SizedBox(width: 24),
                            SizedBox(
                              width: 280,
                              child: _ParkingSummary(
                                total: parking.totalSlots,
                                available: parking.availableSlots,
                                occupied: parking.occupiedSlots,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _CompactParkingSummary(
                              total: parking.totalSlots,
                              available: parking.availableSlots,
                              occupied: parking.occupiedSlots,
                            ),
                            const SizedBox(height: 18),
                            Expanded(child: _ParkingGrid(slots: parking.slots)),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  final String? errorMessage;

  const _PageHeader({required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    final hasError = errorMessage != null && errorMessage!.trim().isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final title = const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Sơ đồ bãi đỗ xe",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ParkingPage._ink,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            Text(
              "Trạng thái chỗ đỗ theo thời gian thực",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Color(0xFF64736C), fontSize: 14),
            ),
          ],
        );
        final status = Container(
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: hasError ? const Color(0xFFFFECEC) : const Color(0xFFE7F7EE),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasError
                  ? const Color(0xFFF3A6A6)
                  : const Color(0xFF9BD5B5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasError ? Icons.error_outline : Icons.sensors,
                size: 18,
                color: hasError ? ParkingPage._red : ParkingPage._green,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  hasError ? errorMessage! : "Đang nhận dữ liệu realtime",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasError
                        ? const Color(0xFF9F2525)
                        : const Color(0xFF126C3B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [title, const SizedBox(height: 10), status],
          );
        }

        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: status,
            ),
          ],
        );
      },
    );
  }
}

class _ParkingGrid extends StatelessWidget {
  final List<ParkingSlot> slots;

  const _ParkingGrid({required this.slots});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 330,
        mainAxisExtent: 220,
        crossAxisSpacing: 18,
        mainAxisSpacing: 18,
      ),
      itemCount: slots.length,
      itemBuilder: (context, index) => _ParkingSlotCard(slot: slots[index]),
    );
  }
}

class _ParkingSlotCard extends StatelessWidget {
  final ParkingSlot slot;

  const _ParkingSlotCard({required this.slot});

  @override
  Widget build(BuildContext context) {
    final color = slot.occupied ? ParkingPage._red : ParkingPage._green;
    final status = slot.occupied ? "Đã có xe" : "Trống";
    final icon = slot.occupied
        ? Icons.directions_car_filled
        : Icons.local_parking_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.12),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: Colors.white,
                  size: 19,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Chỗ đỗ ${slot.slot}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Column(
                key: ValueKey(slot.occupied),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 54),
                  const SizedBox(height: 12),
                  Text(
                    status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParkingSummary extends StatelessWidget {
  final int total;
  final int available;
  final int occupied;

  const _ParkingSummary({
    required this.total,
    required this.available,
    required this.occupied,
  });

  @override
  Widget build(BuildContext context) {
    final occupancy = total == 0 ? 0.0 : occupied / total;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDCE7E1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            color: const Color(0xFF173A2E),
            child: const Row(
              children: [
                Icon(Icons.analytics_outlined, color: Colors.white, size: 21),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Thông tin bãi đỗ",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _SummaryRow(
                  label: "Tổng số chỗ",
                  value: total,
                  color: const Color(0xFF3178C6),
                ),
                const Divider(height: 26),
                _SummaryRow(
                  label: "Chỗ trống",
                  value: available,
                  color: ParkingPage._green,
                ),
                const Divider(height: 26),
                _SummaryRow(
                  label: "Đã có xe",
                  value: occupied,
                  color: ParkingPage._red,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Tỷ lệ sử dụng",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF536159),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${(occupancy * 100).round()}%",
                      style: const TextStyle(
                        color: ParkingPage._ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: occupancy,
                    minHeight: 8,
                    color: occupancy >= 1
                        ? ParkingPage._red
                        : ParkingPage._green,
                    backgroundColor: const Color(0xFFE6ECE9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF536159), fontSize: 14),
          ),
        ),
        Text(
          value.toString(),
          style: const TextStyle(
            color: ParkingPage._ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CompactParkingSummary extends StatelessWidget {
  final int total;
  final int available;
  final int occupied;

  const _CompactParkingSummary({
    required this.total,
    required this.available,
    required this.occupied,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDCE7E1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _CompactStat(
              label: "Tổng chỗ",
              value: total,
              color: const Color(0xFF3178C6),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _CompactStat(
              label: "Chỗ trống",
              value: available,
              color: ParkingPage._green,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _CompactStat(
              label: "Có xe",
              value: occupied,
              color: ParkingPage._red,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _CompactStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            color: color,
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF64736C), fontSize: 12),
        ),
      ],
    );
  }
}
