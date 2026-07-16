import 'package:baidoxe_app/providers/camera_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:baidoxe_app/widgets/left_sidebar_widget.dart';
import '../providers/navigation_provider.dart';
import '../providers/parking_provider.dart';
import '../providers/swipe_card_provider.dart';
import 'pages/dashboard_page.dart';
import 'pages/parking_page.dart';
import 'pages/history_page.dart';
import '../services/firebase_realtime_service.dart';
import '../services/realtime_dispatcher.dart';
import '../services/firestore_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ///==========================
  /// TODO: Sau này lấy từ Provider
  ///==========================

  late final RealtimeDispatcher dispatcher;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      FirebaseRealtimeService.instance.initialize(
        RealtimeDispatcher(
          swipeCardProvider: context.read<SwipeCardProvider>(),
          parkingProvider: context.read<ParkingProvider>(),
        ),
      );

      FirebaseRealtimeService.instance.connect();
      context.read<CameraProvider>().initializeCamera();
    });
  }

  @override
  Widget build(BuildContext context) {
    final navigation = context.watch<NavigationProvider>();

    debugPrint("Current index = ${navigation.selectedIndex}");

    return Scaffold(
      backgroundColor: const Color(0xffF7F8FA),
      body: SafeArea(
        child: Row(
          children: [
            const LeftSidebar(),

            Expanded(
              child: Column(
                children: [
                  _buildHeader(),

                  Expanded(
                    child: IndexedStack(
                      index: navigation.selectedIndex,
                      children: [DashboardPage(), ParkingPage(), HistoryPage()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 35),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Spacer(),
          Row(
            children: [
              const Text(
                "Smart-",
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff0B7A44),
                ),
              ),
              const Text(
                "Parking",
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 10, 10, 10),
                ),
              ),
            ],
          ),

          const Spacer(),

          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildStatus(
                "KẾT NỐI FIREBASE",
                FirebaseRealtimeService.instance.isConnected,
              ),

              const SizedBox(height: 4),

              _buildStatus(
                "KẾT NỐI CAMERA",
                context.watch<CameraProvider>().isConnected,
              ),

              const SizedBox(height: 4),

              _buildStatus("KẾT NỐI DATABASE", FirestoreService.instance.isConnected),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatus(String title, bool connected) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(fontSize: 7, color: Colors.black87)),

        const SizedBox(width: 8),

        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: connected ? Colors.green : Colors.red,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (connected ? Colors.green : Colors.red).withValues(
                  alpha: 0.4,
                ),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
