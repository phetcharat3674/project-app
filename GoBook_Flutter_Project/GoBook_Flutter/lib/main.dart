import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GoBookApp());
}

const brand = Color(0xFF1769D2);
String dateLabel(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String makeId() => DateTime.now().millisecondsSinceEpoch.toString().substring(5);

class TravelBooking {
  final String id, from, to, type, date;
  final int passengers, price;
  TravelBooking({required this.id, required this.from, required this.to, required this.type, required this.date, required this.passengers, required this.price});
  Map<String, dynamic> toJson() => {'id': id, 'from': from, 'to': to, 'type': type, 'date': date, 'passengers': passengers, 'price': price};
  factory TravelBooking.fromJson(Map<String, dynamic> j) => TravelBooking(id: j['id'], from: j['from'], to: j['to'], type: j['type'], date: j['date'], passengers: j['passengers'], price: j['price']);
}

class ParkingBooking {
  final String id, ticketId, slot, date;
  final int hours, price;
  ParkingBooking({required this.id, required this.ticketId, required this.slot, required this.date, required this.hours, required this.price});
  Map<String, dynamic> toJson() => {'id': id, 'ticketId': ticketId, 'slot': slot, 'date': date, 'hours': hours, 'price': price};
  factory ParkingBooking.fromJson(Map<String, dynamic> j) => ParkingBooking(id: j['id'], ticketId: j['ticketId'], slot: j['slot'], date: j['date'], hours: j['hours'], price: j['price']);
}

class GoBookApp extends StatelessWidget {
  const GoBookApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GoBook',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: brand),
      scaffoldBackgroundColor: const Color(0xFFDDF5E8),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: Color(0xFF18263A), centerTitle: false),
      cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE4EAF2)))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
    ),
    home: const MainPage(),
  );
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int tab = 0;
  bool loading = true;
  final List<TravelBooking> tickets = [];
  final List<ParkingBooking> parks = [];

  @override
  void initState() { super.initState(); _load(); }


Future<void> _load() async {
  try {
    final p = await SharedPreferences.getInstance();

    tickets.addAll(
      (jsonDecode(p.getString('tickets') ?? '[]') as List)
          .map((e) => TravelBooking.fromJson(
                Map<String, dynamic>.from(e),
              )),
    );

    parks.addAll(
      (jsonDecode(p.getString('parks') ?? '[]') as List)
          .map((e) => ParkingBooking.fromJson(
                Map<String, dynamic>.from(e),
              )),
    );
  } catch (e) {
    debugPrint('Load error: $e');
  } finally {
    if (mounted) {
      setState(() => loading = false);
    }
  }
}

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('tickets', jsonEncode(tickets.map((e) => e.toJson()).toList()));
    await p.setString('parks', jsonEncode(parks.map((e) => e.toJson()).toList()));
  }

  Future<void> _newTicket(TravelBooking b) async { setState(() => tickets.insert(0, b)); await _save(); }
  Future<void> _newPark(ParkingBooking b) async { setState(() => parks.insert(0, b)); await _save(); }

  Future<void> _cancelTicket(TravelBooking b) async {
    final linked = parks.where((p) => p.ticketId == b.id).toList();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('ยกเลิกการจองตั๋ว?'),
      content: Text(linked.isEmpty ? 'ต้องการยกเลิกตั๋ว ${b.from} → ${b.to} ใช่ไหม' : 'ตั๋วนี้มีที่จอดรถผูกอยู่ ${linked.length} รายการ การยกเลิกจะลบการจองที่จอดรถที่เกี่ยวข้องด้วย'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ไม่ใช่')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ยกเลิกการจอง'))],
    ));
    if (ok == true) {
      setState(() { tickets.removeWhere((t) => t.id == b.id); parks.removeWhere((p) => p.ticketId == b.id); });
      await _save();
    }
  }

  Future<void> _cancelPark(ParkingBooking b) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('ยกเลิกที่จอดรถ?'),
      content: Text('ต้องการยกเลิกช่อง ${b.slot} ใช่ไหม'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('กลับ')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ยืนยันยกเลิก'))],
    ));
    if (ok == true) { setState(() => parks.removeWhere((p) => p.id == b.id)); await _save(); }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(ticketCount: tickets.length, parkCount: parks.length, onGo: (i) => setState(() => tab = i)),
      TicketPage(onCreated: _newTicket),
      ParkingPage(tickets: tickets, parks: parks, onCreated: _newPark),
      BookingsPage(tickets: tickets, parks: parks, onCancelTicket: _cancelTicket, onCancelPark: _cancelPark),
      const ProfilePage(),
    ];
    return Scaffold(
      appBar: AppBar(title: const Row(children: [Icon(Icons.confirmation_num_rounded, color: brand), SizedBox(width: 8), Text('GoBook', style: TextStyle(fontWeight: FontWeight.w800))]), actions: [Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: Text('TRAVEL + PARK', style: TextStyle(fontSize: 10, letterSpacing: 1.1, color: Colors.blueGrey.shade600, fontWeight: FontWeight.bold))))]),
      body: loading ? const Center(child: CircularProgressIndicator()) : IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'หน้าหลัก'),
          NavigationDestination(icon: Icon(Icons.confirmation_num_outlined), selectedIcon: Icon(Icons.confirmation_num), label: 'จองตั๋ว'),
          NavigationDestination(icon: Icon(Icons.local_parking_outlined), selectedIcon: Icon(Icons.local_parking), label: 'ที่จอดรถ'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'รายการจอง'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'โปรไฟล์'),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final int ticketCount, parkCount;
  final ValueChanged<int> onGo;
  const HomePage({super.key, required this.ticketCount, required this.parkCount, required this.onGo});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1769D2), Color(0xFF4398F5)]), borderRadius: BorderRadius.circular(24)),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.explore, color: Colors.white, size: 36),
        SizedBox(height: 16),
        Text('เดินทางง่าย จองได้ในแอปเดียว', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('จองตั๋วเดินทาง พร้อมล็อกช่องจอดรถของคุณ', style: TextStyle(color: Colors.white, height: 1.5)),
      ]),
    ),
    const SizedBox(height: 22),
    const Text('เริ่มต้นใช้งาน', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    const SizedBox(height: 12),
    _action(context, Icons.confirmation_num, 'จองตั๋วเดินทาง', 'เลือกรถ เส้นทาง และวันเดินทาง', () => onGo(1)),
    _action(context, Icons.local_parking, 'จองที่จอดรถ', 'สำหรับผู้ที่มีตั๋วเดินทางแล้ว', () => onGo(2)),
    const SizedBox(height: 16),
    Row(children: [
      Expanded(child: _stat('ตั๋วเดินทาง', '$ticketCount', Icons.train)),
      const SizedBox(width: 12),
      Expanded(child: _stat('ที่จอดรถ', '$parkCount', Icons.local_parking)),
    ]),
    const SizedBox(height: 18),
    const Card(child: Padding(padding: EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline, color: brand), SizedBox(width: 10), Expanded(child: Text('วิธีใช้: จองตั๋วเดินทางก่อน จากนั้นนำตั๋วที่จองไปเลือกช่องจอดรถได้'))]))),
  ]);
  Widget _action(BuildContext c, IconData icon, String title, String sub, VoidCallback tap) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(contentPadding: const EdgeInsets.all(16), leading: CircleAvatar(backgroundColor: const Color(0xFFE7F0FF), child: Icon(icon, color: brand)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(sub), trailing: const Icon(Icons.arrow_forward_ios, size: 16), onTap: tap));
  Widget _stat(String title, String value, IconData icon) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: brand), const SizedBox(height: 12), Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)), Text(title, style: const TextStyle(color: Colors.black54))])));
}

class TicketPage extends StatefulWidget {
  final ValueChanged<TravelBooking> onCreated;
  const TicketPage({super.key, required this.onCreated});
  @override
  State<TicketPage> createState() => _TicketPageState();
}
class _TicketPageState extends State<TicketPage> {
  final places = const ['กรุงเทพฯ', 'เชียงใหม่', 'พัทยา', 'ขอนแก่น', 'นครราชสีมา'];
  String from = 'กรุงเทพฯ', to = 'เชียงใหม่', type = 'รถทัวร์';
  DateTime date = DateTime.now();
  int passengers = 1;
  int get fare => type == 'รถทัวร์' ? 350 : 550;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('จองตั๋วเดินทาง', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    const SizedBox(height: 6), const Text('เลือกข้อมูลการเดินทางของคุณ'),
    const SizedBox(height: 20),
    DropdownButtonFormField<String>(value: from, decoration: const InputDecoration(labelText: 'ต้นทาง'), items: places.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(), onChanged: (v) => setState(() => from = v!)),
    const SizedBox(height: 14),
    DropdownButtonFormField<String>(value: to, decoration: const InputDecoration(labelText: 'ปลายทาง'), items: places.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(), onChanged: (v) => setState(() => to = v!)),
    const SizedBox(height: 14),
    DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'ประเภทรถ'), items: const [DropdownMenuItem(value: 'รถทัวร์', child: Text('รถทัวร์')), DropdownMenuItem(value: 'รถไฟ', child: Text('รถไฟ'))], onChanged: (v) => setState(() => type = v!)),
    const SizedBox(height: 14),
    _datePicker(context, 'วันเดินทาง', date, (d) => setState(() => date = d)),
    const SizedBox(height: 14),
    DropdownButtonFormField<int>(value: passengers, decoration: const InputDecoration(labelText: 'จำนวนผู้โดยสาร'), items: List.generate(5, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1} คน'))), onChanged: (v) => setState(() => passengers = v!)),
    const SizedBox(height: 20),
    _priceCard('ค่าโดยสารต่อคน $fare บาท', fare * passengers),
    const SizedBox(height: 16),
    FilledButton.icon(onPressed: () async {
      if (from == to) { _snack(context, 'ต้นทางและปลายทางต้องไม่เหมือนกัน'); return; }
      final b = TravelBooking(id: makeId(), from: from, to: to, type: type, date: dateLabel(date), passengers: passengers, price: fare * passengers);
      final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => ConfirmPage(title: 'ยืนยันตั๋วเดินทาง', details: ['เส้นทาง: $from → $to', 'ประเภทรถ: $type', 'วันเดินทาง: ${dateLabel(date)}', 'ผู้โดยสาร: $passengers คน', 'รหัสการจอง: ${b.id}'], price: b.price)));
      if (ok == true) { widget.onCreated(b); if (context.mounted) _snack(context, 'จองตั๋วสำเร็จ'); }
    }, icon: const Icon(Icons.check_circle_outline), label: const Text('ตรวจสอบและยืนยันการจอง')),
  ]);
}

class ParkingPage extends StatefulWidget {
  final List<TravelBooking> tickets;
  final List<ParkingBooking> parks;
  final ValueChanged<ParkingBooking> onCreated;
  const ParkingPage({super.key, required this.tickets, required this.parks, required this.onCreated});
  @override
  State<ParkingPage> createState() => _ParkingPageState();
}
class _ParkingPageState extends State<ParkingPage> {
  String? ticketId;
  String slot = 'A1';
  int hours = 1;
  DateTime date = DateTime.now();
  @override
  Widget build(BuildContext context) {
    if (widget.tickets.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.lock_outline, size: 54, color: brand), SizedBox(height: 12), Text('ต้องจองตั๋วเดินทางก่อน', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), SizedBox(height: 8), Text('เมื่อมีตั๋วแล้ว กลับมาหน้านี้เพื่อเลือกช่องจอดรถ', textAlign: TextAlign.center)])));
    final selectedId = widget.tickets.any((t) => t.id == ticketId) ? ticketId! : widget.tickets.first.id;
    final occupied = widget.parks.where((p) => p.date == dateLabel(date)).map((p) => p.slot).toSet();
    if (occupied.contains(slot)) slot = List.generate(8, (i) => 'A${i + 1}').firstWhere((s) => !occupied.contains(s), orElse: () => 'A1');
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('จองที่จอดรถ', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6), const Text('จองได้เมื่อมีตั๋วเดินทางในระบบ'),
      const SizedBox(height: 20),
      DropdownButtonFormField<String>(value: selectedId, decoration: const InputDecoration(labelText: 'ผูกกับตั๋วเดินทาง'), items: widget.tickets.map((t) => DropdownMenuItem(value: t.id, child: Text('${t.from} → ${t.to} (${t.date})'))).toList(), onChanged: (v) => setState(() => ticketId = v)),
      const SizedBox(height: 14),
      _datePicker(context, 'วันที่จอดรถ', date, (d) => setState(() => date = d)),
      const SizedBox(height: 14),
      DropdownButtonFormField<int>(value: hours, decoration: const InputDecoration(labelText: 'ระยะเวลาจอด'), items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1} ชั่วโมง'))), onChanged: (v) => setState(() => hours = v!)),
      const SizedBox(height: 20),
      const Text('เลือกช่องจอด', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6), const Text('สีฟ้า = เลือกอยู่ • สีเทา = ถูกจองแล้ว'),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, children: List.generate(8, (i) {
        final s = 'A${i + 1}'; final busy = occupied.contains(s);
        return ChoiceChip(label: Text(busy ? '$s ไม่ว่าง' : s), selected: slot == s && !busy, onSelected: busy ? null : (_) => setState(() => slot = s), avatar: Icon(busy ? Icons.block : Icons.local_parking, size: 17));
      })),
      const SizedBox(height: 20),
      _priceCard('ค่าจอดรถ 30 บาท/ชั่วโมง', hours * 30),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: () async {
        if (occupied.contains(slot)) { _snack(context, 'ช่องนี้ถูกจองแล้ว กรุณาเลือกช่องอื่น'); return; }
        final b = ParkingBooking(id: makeId(), ticketId: selectedId, slot: slot, date: dateLabel(date), hours: hours, price: hours * 30);
        final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => ConfirmPage(title: 'ยืนยันที่จอดรถ', details: ['รหัสรายการ: ${b.id}', 'ช่องจอด: $slot', 'วันที่: ${b.date}', 'ระยะเวลา: $hours ชั่วโมง', 'ผูกกับตั๋ว: $selectedId'], price: b.price)));
        if (ok == true) { widget.onCreated(b); if (context.mounted) _snack(context, 'จองที่จอดรถสำเร็จ'); }
      }, icon: const Icon(Icons.local_parking), label: const Text('ยืนยันจองที่จอดรถ')),
    ]);
  }
}

class ConfirmPage extends StatelessWidget {
  final String title;
  final List<String> details;
  final int price;
  const ConfirmPage({super.key, required this.title, required this.details, required this.price});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ตรวจสอบรายการ')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const SizedBox(height: 10), const Icon(Icons.receipt_long, size: 72, color: brand),
      const SizedBox(height: 12), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
      const SizedBox(height: 20),
      Card(child: Column(children: details.map((d) => ListTile(leading: const Icon(Icons.check_circle_outline, color: brand), title: Text(d))).toList())),
      _priceCard('ยอดชำระจำลอง', price),
      const SizedBox(height: 18),
      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ยืนยันการจอง')),
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('กลับไปแก้ไข')),
      const Padding(padding: EdgeInsets.only(top: 12), child: Text('หมายเหตุ: เป็นระบบต้นแบบ ไม่มีการชำระเงินจริง', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54))),
    ]),
  );
}

class BookingsPage extends StatelessWidget {
  final List<TravelBooking> tickets;
  final List<ParkingBooking> parks;
  final ValueChanged<TravelBooking> onCancelTicket;
  final ValueChanged<ParkingBooking> onCancelPark;
  const BookingsPage({super.key, required this.tickets, required this.parks, required this.onCancelTicket, required this.onCancelPark});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('รายการจองของฉัน', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    const SizedBox(height: 18),
    const Text('ตั๋วเดินทาง', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    if (tickets.isEmpty) const _Empty(text: 'ยังไม่มีตั๋วเดินทาง'),
    ...tickets.map((t) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      ListTile(contentPadding: EdgeInsets.zero, leading: const CircleAvatar(child: Icon(Icons.train)), title: Text('${t.from} → ${t.to}', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${t.type} • ${t.date}\n${t.passengers} คน • รหัส ${t.id}'), isThreeLine: true, trailing: Text('${t.price} ฿')),
      Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => onCancelTicket(t), icon: const Icon(Icons.cancel_outlined), label: const Text('ยกเลิกตั๋ว'))),
    ])))),
    const SizedBox(height: 20),
    const Text('ที่จอดรถ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    if (parks.isEmpty) const _Empty(text: 'ยังไม่มีที่จอดรถที่จอง'),
    ...parks.map((p) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      ListTile(contentPadding: EdgeInsets.zero, leading: const CircleAvatar(child: Icon(Icons.local_parking)), title: Text('ช่อง ${p.slot}', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${p.date} • ${p.hours} ชั่วโมง\nรหัสรายการ ${p.id}'), isThreeLine: true, trailing: Text('${p.price} ฿')),
      Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => onCancelPark(p), icon: const Icon(Icons.cancel_outlined), label: const Text('ยกเลิกที่จอดรถ'))),
    ])))),
  ]);
}
class _Empty extends StatelessWidget {
  final String text;
  const _Empty({required this.text});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Center(child: Text(text, style: const TextStyle(color: Colors.black54)))));
}

Widget _priceCard(String subtitle, int amount) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
  const Icon(Icons.payments_outlined, color: brand, size: 28), const SizedBox(width: 12),
  Expanded(child: Text(subtitle)),
  Text('$amount บาท', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: brand)),
])));
Widget _datePicker(BuildContext context, String title, DateTime value, ValueChanged<DateTime> onPick) => Card(child: ListTile(title: Text(title), subtitle: Text(dateLabel(value)), trailing: const Icon(Icons.calendar_month, color: brand), onTap: () async {
  final d = await showDatePicker(context: context, initialDate: value.isBefore(DateTime.now()) ? DateTime.now() : value, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
  if (d != null) onPick(d);
}));
void _snack(BuildContext context, String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));


class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 24),
          const Center(
            child: CircleAvatar(
              radius: 46,
              backgroundColor: Color(0xFFB7E4C7),
              child: Icon(Icons.person, size: 52, color: Color(0xFF276749)),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'ผู้ใช้งาน GoBook',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          const Center(child: Text('ยินดีต้อนรับสู่ GoBook')),
          const SizedBox(height: 28),
          const Card(
            child: ListTile(
              leading: Icon(Icons.confirmation_num_outlined),
              title: Text('GoBook'),
              subtitle: Text('ระบบจองการเดินทางและที่จอดรถ'),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.palette_outlined),
              title: Text('ธีมสี'),
              subtitle: Text('เขียวมิ้นต์'),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('เกี่ยวกับแอป'),
              subtitle: Text('GoBook Travel + Parking'),
            ),
          ),
        ],
      );
}
