import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/navigation_provider.dart';

class LeftSidebar extends StatefulWidget {
  const LeftSidebar({super.key});

  @override
  State<LeftSidebar> createState() => _LeftSidebarState();
}

class _LeftSidebarState extends State<LeftSidebar> {
  @override
  Widget build(BuildContext context) {
    final navigation = context.watch<NavigationProvider>();

    return Container(
      width: 230,
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 253, 253, 254),
        boxShadow: [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 20,
            offset: Offset(3, 0),
          ),
        ],
      ),
      child: Stack(
        children: [
          /// Background
          Align(
            alignment: Alignment.bottomCenter,
            child: Image.asset(
              "assets/background_leftbar.png",
              width: 230,
              fit: BoxFit.fitWidth,
            ),
          ),

          Column(
            children: [
              const SizedBox(height: 20),

              Image.asset("assets/logo.png", width: 100),

              const SizedBox(height: 12),

              const Text(
                "Smart-Parking",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 6),

              const Text(
                "Bãi đỗ xe thông minh",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),

              const SizedBox(height: 35),

              _menuItem(
                context,
                icon: Icons.home_outlined,
                text: "Trang chính",
                index: 0,
                selected: navigation.selectedIndex == 0,
              ),

              const SizedBox(height: 18),

              _menuItem(
                context,
                icon: Icons.local_parking_outlined,
                text: "Bãi đỗ xe",
                index: 1,
                selected: navigation.selectedIndex == 1,
              ),

              const SizedBox(height: 18),

              _menuItem(
                context,
                icon: Icons.history,
                text: "Lịch sử ra/vào",
                index: 2,
                selected: navigation.selectedIndex == 2,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required String text,
    required int index,
    required bool selected,
  }) {
    final Color activeColor = selected
        ? const Color(0xff12A150)
        : const Color(0xffE74C3C);

    final Color backgroundColor = selected
        ? const Color(0xffEDF9F0)
        : const Color(0xffFDEEEE);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        print("Click: $index");
        context.read<NavigationProvider>().changePage(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(horizontal: 14),
        height: 65,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 5,
              height: double.infinity,
              decoration: BoxDecoration(
                color: selected ? activeColor : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
            ),

            const SizedBox(width: 15),

            Icon(icon, color: activeColor, size: 20),

            const SizedBox(width: 15),

            Text(
              text,
              style: TextStyle(
                color: activeColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
