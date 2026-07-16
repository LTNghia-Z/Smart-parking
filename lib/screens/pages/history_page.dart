import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const Color _blue = Color(0xFF2563EB);
  static const Color _red = Color(0xFFDC2626);
  static const Color _black = Color(0xFF111827);
  static const Color _line = Color(0xFFE5E7EB);

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _keyword = "";

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 760;

        return Container(
          color: const Color(0xFFF7FAFC),
          padding: EdgeInsets.fromLTRB(
            isCompact ? 14 : 28,
            isCompact ? 14 : 24,
            isCompact ? 14 : 28,
            isCompact ? 18 : 28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildToolbar(isCompact: isCompact),
              const SizedBox(height: 18),
              Expanded(
                child: StreamBuilder<List<ParkingLogRecord>>(
                  stream: FirestoreService.instance.watchParkingLogs(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _buildMessage(
                        icon: Icons.error_outline,
                        title: "Không đọc được lịch sử",
                        subtitle: snapshot.error.toString(),
                        color: _red,
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final logs = (snapshot.data ?? [])
                        .where((log) => log.containsKeyword(_keyword))
                        .toList();

                    if (logs.isEmpty) {
                      return _buildMessage(
                        icon: Icons.history,
                        title: "Chưa có dữ liệu lịch sử",
                        subtitle:
                            "Dữ liệu sẽ hiển thị khi collection parking_logs có bản ghi.",
                        color: _blue,
                      );
                    }

                    return _HistoryTable(
                      logs: logs,
                      scrollController: _scrollController,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbar({required bool isCompact}) {
    final title = const Text(
      "Lịch sử ra / vào",
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: _black,
        fontSize: 28,
        fontWeight: FontWeight.w800,
      ),
    );

    final search = TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _keyword = value;
        });
      },
      decoration: InputDecoration(
        hintText: "Tìm kiếm",
        prefixIcon: const Icon(Icons.search, color: _blue),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _blue, width: 1.5),
        ),
      ),
    );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [title, const SizedBox(height: 12), search],
      );
    }

    return Row(
      children: [
        Expanded(child: title),
        const SizedBox(width: 18),
        SizedBox(width: 360, child: search),
      ],
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 54, color: color),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _black,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTable extends StatelessWidget {
  const _HistoryTable({
    required this.logs,
    required this.scrollController,
  });

  static const Color _blue = Color(0xFF2563EB);
  static const Color _black = Color(0xFF111827);
  static const Color _line = Color(0xFFE5E7EB);
  static const Color _header = Color(0xFFEFF6FF);

  final List<ParkingLogRecord> logs;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final isTiny = width < 620;
        final rowHeight = isTiny ? 52.0 : 58.0;
        final padding = isTiny ? 6.0 : 14.0;

        final tableWidth = isTiny ? 760.0 : width;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            height: height,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildHeaderRow(
                    isTiny: isTiny,
                    height: rowHeight,
                    padding: padding,
                  ),
                  Expanded(
                    child: Scrollbar(
                      controller: scrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: scrollController,
                        child: Column(
                          children: [
                            for (var index = 0; index < logs.length; index++) ...[
                              _buildDataRow(
                                index,
                                logs[index],
                                isTiny: isTiny,
                                height: rowHeight,
                                padding: padding,
                              ),
                              if (index < logs.length - 1)
                                const Divider(height: 1, color: _line),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderRow({
    required bool isTiny,
    required double height,
    required double padding,
  }) {
    return Container(
      height: height,
      color: _header,
      child: Row(
        children: [
          _FixedCell(width: isTiny ? 42 : 54, child: const _HeaderText("STT")),
          _FlexCell(
            flex: isTiny ? 2 : 3,
            padding: padding,
            alignment: Alignment.center,
            child: const _HeaderText("ID"),
          ),
          _FlexCell(
            flex: isTiny ? 2 : 3,
            padding: padding,
            alignment: Alignment.center,
            child: const _HeaderText("UID thẻ"),
          ),
          _FlexCell(
            flex: isTiny ? 2 : 3,
            padding: padding,
            alignment: Alignment.center,
            child: const _HeaderText("Biển số xe"),
          ),
          _FlexCell(
            flex: isTiny ? 2 : 4,
            padding: padding,
            alignment: Alignment.center,
            child: const _HeaderText("Thời gian"),
          ),
          _FlexCell(
            flex: isTiny ? 2 : 3,
            padding: padding,
            alignment: Alignment.center,
            child: const _HeaderText("Sửa"),
          ),
          _FixedCell(
            width: isTiny ? 78 : 124,
            child: const _HeaderText("Trạng thái"),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(
    int index,
    ParkingLogRecord log, {
    required bool isTiny,
    required double height,
    required double padding,
  }) {
    final isEntry = log.state == 1;

    return Container(
      height: height,
      color: index.isEven ? Colors.white : const Color(0xFFF8FAFC),
      child: Row(
        children: [
          _FixedCell(
            width: isTiny ? 42 : 54,
            child: _BodyText("${index + 1}", isStrong: true),
          ),
          _FlexCell(
            flex: isTiny ? 2 : 3,
            padding: padding,
            child: _BodyText(log.id, fontSize: isTiny ? 12 : 14),
          ),
          _FlexCell(
            flex: isTiny ? 2 : 3,
            padding: padding,
            child: _BodyText(log.uid, fontSize: isTiny ? 12 : 14),
          ),
          _FlexCell(
            flex: isTiny ? 2 : 3,
            padding: padding,
            child: _BodyText(
              log.plate,
              isStrong: true,
              fontSize: isTiny ? 12 : 14,
            ),
          ),
          _FlexCell(
            flex: isTiny ? 2 : 4,
            padding: padding,
            child: _BodyText(log.displayTime, fontSize: isTiny ? 12 : 14),
          ),
          _FlexCell(
            flex: isTiny ? 2 : 3,
            padding: padding,
            child: _BodyText(
              log.fix.isEmpty ? "-" : log.fix,
              isStrong: log.fix.isNotEmpty,
              fontSize: isTiny ? 12 : 14,
            ),
          ),
          _FixedCell(
            width: isTiny ? 78 : 124,
            child: _StateBadge(
              text: log.stateText,
              isEntry: isEntry,
              isCompact: isTiny,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
      style: const TextStyle(
        color: _HistoryTable._black,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  const _BodyText(this.text, {this.isStrong = false, this.fontSize = 14});

  final String text;
  final bool isStrong;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
      style: TextStyle(
        color: const Color(0xFF111827),
        fontSize: fontSize,
        fontWeight: isStrong ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({
    required this.text,
    required this.isEntry,
    required this.isCompact,
  });

  final String text;
  final bool isEntry;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final color = isEntry ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final background = isEntry
        ? const Color(0xFFEAF7EF)
        : const Color(0xFFFDECEC);
    final icon = isEntry ? Icons.login : Icons.logout;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 12,
        vertical: isCompact ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isCompact) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: isCompact ? 12 : 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FixedCell extends StatelessWidget {
  const _FixedCell({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: _HistoryTable._blue.withValues(alpha: 0.16),
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: child,
      ),
    );
  }
}

class _FlexCell extends StatelessWidget {
  const _FlexCell({
    required this.flex,
    required this.padding,
    required this.child,
    this.alignment = Alignment.centerLeft,
  });

  final int flex;
  final double padding;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        alignment: alignment,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: _HistoryTable._blue.withValues(alpha: 0.16),
            ),
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: padding),
        child: child,
      ),
    );
  }
}
