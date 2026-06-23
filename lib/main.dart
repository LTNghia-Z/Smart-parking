import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';
import 'screens/plate_camera_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
 runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PlateCameraScreen(),
    ),
  );
}

class SmartParkingApp extends StatelessWidget {
  const SmartParkingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Parking',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ParkingScreen(),
    );
  }
}

class ParkingScreen extends StatefulWidget {
  const ParkingScreen({super.key});

  @override
  State<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends State<ParkingScreen> {
  // 1. Đổi sang kết nối đúng nhánh gốc bãi xe của bạn trên Firebase
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Bãi Đỗ Xe Thông Minh', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        elevation: 2,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: _dbRef.onValue, // Lắng nghe toàn bộ thay đổi dữ liệu từ node gốc
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Lỗi kết nối: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(child: Text('Không tìm thấy dữ liệu trên Firebase.'));
          }

          // Ép kiểu dữ liệu gốc nhận về từ Firebase
          final Map<dynamic, dynamic> data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

          // Lấy thông số tổng quan trực tiếp từ Firebase của bạn
          final int availableSlots = data['available_slots'] ?? 0;
          final int totalSlots = data['total_slots'] ?? 0;
          final String barrierStatus = data['barrier_status'] ?? "CLOSE";

          // Lấy map danh sách các ô đỗ xe bên trong nhánh 'slots'
          final Map<dynamic, dynamic> slots = data['slots'] ?? {};
          final slotKeys = slots.keys.toList()..sort(); // Sắp xếp lại thứ tự slot_1, slot_2...

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. Khối hiển thị Dashboard tổng quan + Trạng thái cổng chắn (Barrier)
                _buildDashboard(availableSlots, totalSlots, barrierStatus),
                const SizedBox(height: 20),
                const Text(
                  'Sơ đồ vị trí:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                // 3. Lưới hiển thị trạng thái các ô đỗ xe
                Expanded(
                  child: GridView.builder(
                    itemCount: slotKeys.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio: 1.2,
                    ),
                    itemBuilder: (context, index) {
                      String key = slotKeys[index].toString();

                      // Firebase của bạn lưu trực tiếp trạng thái chuỗi ví dụ: slot_1: "EMPTY"
                      String status = slots[key].toString();
                      bool isOccupied = status != "EMPTY"; // Nếu khác EMPTY tức là đã có xe đỗ

                      // Định dạng lại tên hiển thị (Ví dụ: slot_1 -> Vị trí 1)
                      String displayName = key.replaceAll('_', ' ').toUpperCase();

                      return _buildParkingSlot(displayName, isOccupied);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Dashboard tùy biến thêm thanh hiển thị trạng thái cổng Barrier
  Widget _buildDashboard(int freeSlots, int totalSlots, String barrierStatus) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoColumn('Tổng số chỗ', '$totalSlots', Colors.blue),
              _buildInfoColumn('Còn trống', '$freeSlots', Colors.green),
              _buildInfoColumn('Đã đỗ', '${totalSlots - freeSlots}', Colors.red),
            ],
          ),
          const Divider(height: 25, thickness: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Trạng thái cổng Barrier: ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              Text(
                barrierStatus == "OPEN" ? "ĐANG MỞ" : "ĐANG ĐÓNG",
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: barrierStatus == "OPEN" ? Colors.green : Colors.orange
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String title, String value, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildParkingSlot(String slotName, bool isOccupied) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: isOccupied ? Colors.red[50] : Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isOccupied ? Colors.red : Colors.green, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isOccupied ? Icons.directions_car : Icons.local_parking,
            size: 40,
            color: isOccupied ? Colors.red : Colors.green,
          ),
          const SizedBox(height: 8),
          Text(slotName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            isOccupied ? 'ĐÃ CÓ XE' : 'TRỐNG',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isOccupied ? Colors.red : Colors.green),
          ),
        ],
      ),
    );
  }
}