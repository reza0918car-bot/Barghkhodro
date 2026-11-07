import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  runApp(const AutoElectricApp());
}

// مبدل تاریخ میلادی به شمسی بدون نیاز به پکیج خارجی
class JalaliHelper {
  static String nowShamsi() {
    final now = DateTime.now();
    return gregorianToJalali(now.year, now.month, now.day);
  }

  static String gregorianToJalali(int gy, int gm, int gd) {
    List<int> g_d_m = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
    int jy = (gy <= 1600) ? 0 : 979;
    gy -= (gy <= 1600) ? 621 : 1600;
    int gy2 = (gm > 2) ? (gy + 1) : gy;
    int days = (365 * gy) + ((gy2 + 3) ~/ 4) - ((gy2 + 99) ~/ 100) +
        ((gy2 + 399) ~/ 400) - 80 + gd + g_d_m[gm - 1];
    jy += 33 * (days ~/ 12053);
    days %= 12053;
    jy += 4 * (days ~/ 1461);
    days %= 1461;
    jy += (days > 365) ? ((days - 1) ~/ 365) : 0;
    if (days > 365) days = (days - 1) % 365;
    int jm = (days < 186) ? 1 + (days ~/ 31) : 7 + ((days - 186) ~/ 30);
    int jd = 1 + ((days < 186) ? (days % 31) : ((days - 186) % 30));
    return '$jy/${jm.toString().padLeft(2, '0')}/${jd.toString().padLeft(2, '0')}';
  }
}

String formatToman(int amount) {
  final formatter = intl.NumberFormat('#,###');
  return '${formatter.format(amount)} تومان';
}

// قطعات مصرفی
class PartItem {
  String name;
  int price;

  PartItem({required this.name, required this.price});

  Map<String, dynamic> toMap() => {'name': name, 'price': price};
  factory PartItem.fromMap(Map<String, dynamic> map) => PartItem(
        name: map['name'] ?? '',
        price: map['price'] ?? 0,
      );
}

// فاکتور و خدمات ثبت شده
class ServiceRecord {
  String id;
  String title;
  String date; // تاریخ شمسی
  int laborCost; // دستمزد
  List<PartItem> parts;

  ServiceRecord({
    required this.id,
    required this.title,
    required this.date,
    required this.laborCost,
    required this.parts,
  });

  int get partsTotal => parts.fold(0, (sum, item) => sum + item.price);
  int get grandTotal => laborCost + partsTotal;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'date': date,
        'laborCost': laborCost,
        'parts': parts.map((p) => p.toMap()).toList(),
      };

  factory ServiceRecord.fromMap(Map<String, dynamic> map) => ServiceRecord(
        id: map['id'] ?? '',
        title: map['title'] ?? '',
        date: map['date'] ?? JalaliHelper.nowShamsi(),
        laborCost: map['laborCost'] ?? 0,
        parts: (map['parts'] as List? ?? []).map((p) => PartItem.fromMap(p)).toList(),
      );
}

// مشخصات خودرو
class Car {
  String id;
  String model;
  String plateTwoDigits;
  String plateLetter;
  String plateThreeDigits;
  String plateProvinceCode;
  List<ServiceRecord> services;

  Car({
    required this.id,
    required this.model,
    required this.plateTwoDigits,
    required this.plateLetter,
    required this.plateThreeDigits,
    required this.plateProvinceCode,
    required this.services,
  });

  String get fullPlate => '$plateTwoDigits $plateLetter $plateThreeDigits - ایران $plateProvinceCode';

  Map<String, dynamic> toMap() => {
        'id': id,
        'model': model,
        'two': plateTwoDigits,
        'letter': plateLetter,
        'three': plateThreeDigits,
        'prov': plateProvinceCode,
        'services': services.map((s) => s.toMap()).toList(),
      };

  factory Car.fromMap(Map<String, dynamic> map) => Car(
        id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        model: map['model'] ?? '',
        plateTwoDigits: map['two'] ?? '',
        plateLetter: map['letter'] ?? '',
        plateThreeDigits: map['three'] ?? '',
        plateProvinceCode: map['prov'] ?? '',
        services: (map['services'] as List? ?? []).map((s) => ServiceRecord.fromMap(s)).toList(),
      );
}

// پرونده مشتری
class Customer {
  String id;
  String name;
  String phone;
  List<Car> cars;

  Customer({required this.id, required this.name, required this.phone, required this.cars});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'cars': cars.map((c) => c.toMap()).toList(),
      };

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        phone: map['phone'] ?? '',
        cars: (map['cars'] as List? ?? []).map((c) => Car.fromMap(c)).toList(),
      );
}

class AutoElectricApp extends StatelessWidget {
  const AutoElectricApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'کلینیک تخصصی برق خودرو',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF0284C7),
        cardColor: const Color(0xFF1E293B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Colors.amberAccent,
          surface: Color(0xFF1E293B),
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  List<Customer> customers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('customers_data_v3');
    if (raw != null) {
      final List decoded = jsonDecode(raw);
      setState(() {
        customers = decoded.map((e) => Customer.fromMap(e)).toList();
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(customers.map((c) => c.toMap()).toList());
    await prefs.setString('customers_data_v3', encoded);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(customers: customers, onDataChanged: _saveData),
      DailyReportScreen(customers: customers),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: Colors.cyanAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.build), label: 'میز کار و مشتریان'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'گزارش دخل و سود'),
        ],
      ),
    );
  }
}

// ۱. صفحه اصلی مشتریان و خودروها با جستجوی پیشرفته
class HomeScreen extends StatefulWidget {
  final List<Customer> customers;
  final VoidCallback onDataChanged;

  const HomeScreen({super.key, required this.customers, required this.onDataChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.customers.where((c) {
      final q = searchQuery.trim();
      if (q.isEmpty) return true;
      final matchCust = c.name.contains(q) || c.phone.contains(q);
      final matchCar = c.cars.any((car) =>
          car.fullPlate.contains(q) ||
          car.model.contains(q) ||
          car.services.any((s) => s.title.contains(q) || s.date.contains(q)));
      return matchCust || matchCar;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚡ کلینیک برق خودرو', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_sync, color: Colors.cyanAccent),
            tooltip: 'پشتیبان‌گیری',
            onPressed: _openBackupDialog,
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: (val) => setState(() => searchQuery = val),
              decoration: InputDecoration(
                hintText: 'جستجو با نام، پلاک، تاریخ شمسی (مثلاً ۱۴۰۳/۰۸) یا نوع کار...',
                prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('موردی با این مشخصات یافت نشد.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _buildCustomerCard(filtered[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0284C7),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('مشتری جدید', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _openAddCustomerDialog,
      ),
    );
  }

  Widget _buildCustomerCard(Customer customer) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF0284C7),
          child: Icon(Icons.person, color: Colors.white),
        ),
        title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text('📞 ${customer.phone}  |  🚗 ${customer.cars.length} خودرو'),
        children: [
          ...customer.cars.map((car) => _buildCarRow(customer, car)).toList(),
          TextButton.icon(
            icon: const Icon(Icons.add_circle_outline, color: Colors.cyanAccent),
            label: const Text('افزودن خودروی دیگر برای این مشتری'),
            onPressed: () => _openAddCarDialog(customer.id),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildCarRow(Customer customer, Car car) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(car.model, style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 15)),
              _buildPlateVisual(car),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${car.services.length} فاکتور ثبت شده', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                icon: const Icon(Icons.receipt_long, size: 16, color: Colors.white),
                label: const Text('فاکتورها و سوابق', style: TextStyle(color: Colors.white, fontSize: 12)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => CarServicesScreen(
                        customer: customer,
                        car: car,
                        onChanged: () {
                          setState(() {});
                          widget.onDataChanged();
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlateVisual(Car car) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(car.plateProvinceCode, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
          const Text(' ایران | ', style: TextStyle(color: Colors.black, fontSize: 9)),
          Text('${car.plateThreeDigits} ', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
          Text('${car.plateLetter} ', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11)),
          Text(car.plateTwoDigits, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }

  void _openAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ثبت مشتری جدید'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'نام و نام خانوادگی')),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'شماره تماس')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                setState(() {
                  widget.customers.insert(
                    0,
                    Customer(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameCtrl.text,
                      phone: phoneCtrl.text,
                      cars: [],
                    ),
                  );
                });
                widget.onDataChanged();
                Navigator.pop(ctx);
              }
            },
            child: const Text('ثبت'),
          )
        ],
      ),
    );
  }

  void _openAddCarDialog(String customerId) {
    final modelCtrl = TextEditingController();
    final twoCtrl = TextEditingController();
    final letterCtrl = TextEditingController();
    final threeCtrl = TextEditingController();
    final provCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('افزودن خودرو به پرونده'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'مدل خودرو (مثلاً: دنا پلاس)')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: provCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'ایران'))),
                  const SizedBox(width: 4),
                  Expanded(child: TextField(controller: threeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '۳ رقم'))),
                  const SizedBox(width: 4),
                  Expanded(child: TextField(controller: letterCtrl, decoration: const InputDecoration(hintText: 'حرف'))),
                  const SizedBox(width: 4),
                  Expanded(child: TextField(controller: twoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '۲ رقم'))),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () {
              if (modelCtrl.text.isNotEmpty) {
                final index = widget.customers.indexWhere((c) => c.id == customerId);
                if (index != -1) {
                  setState(() {
                    widget.customers[index].cars.add(
                          Car(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            model: modelCtrl.text,
                            plateTwoDigits: twoCtrl.text,
                            plateLetter: letterCtrl.text,
                            plateThreeDigits: threeCtrl.text,
                            plateProvinceCode: provCtrl.text,
                            services: [],
                          ),
                        );
                  });
                  widget.onDataChanged();
                }
                Navigator.pop(ctx);
              }
            },
            child: const Text('ذخیره خودرو'),
          )
        ],
      ),
    );
  }

  void _openBackupDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('💾 پشتیبان‌گیری و بازیابی'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('کپی کردن کد پشتیبان (Backup)'),
              onPressed: () {
                final encoded = jsonEncode(widget.customers.map((c) => c.toMap()).toList());
                Clipboard.setData(ClipboardData(text: encoded));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('کد پشتیبان کپی شد! در تلگرام یا پیامک ذخیره کنید.')),
                );
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800]),
              icon: const Icon(Icons.download, color: Colors.white),
              label: const Text('بازیابی اطلاعات از کد قبلی', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.pop(ctx);
                _openRestoreDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openRestoreDialog() {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بازیابی فایل پشتیبان'),
        content: TextField(
          controller: codeCtrl,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'کد متنی پشتیبان را اینجا Paste کنید...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () {
              try {
                final List decoded = jsonDecode(codeCtrl.text);
                setState(() {
                  widget.customers.clear();
                  widget.customers.addAll(decoded.map((e) => Customer.fromMap(e)).toList());
                });
                widget.onDataChanged();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اطلاعات با موفقیت بازگردانده شد!')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('کد پشتیبان نامعتبر است!')));
              }
            },
            child: const Text('اعمال بازیابی'),
          )
        ],
      ),
    );
  }
}

// ۲. صفحه فاکتورها، ثبت کار با تاریخ شمسی و دکمه پرینت/PDF
class CarServicesScreen extends StatefulWidget {
  final Customer customer;
  final Car car;
  final VoidCallback onChanged;

  const CarServicesScreen({super.key, required this.customer, required this.car, required this.onChanged});

  @override
  State<CarServicesScreen> createState() => _CarServicesScreenState();
}

class _CarServicesScreenState extends State<CarServicesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.car.model} (${widget.customer.name})'),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: widget.car.services.isEmpty
          ? const Center(child: Text('هنوز خدماتی برای این خودرو ثبت نشده است.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: widget.car.services.length,
              itemBuilder: (context, i) {
                final s = widget.car.services[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(s.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.cyanAccent)),
                            Text('📅 تاریخ: ${s.date}', style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
                          ],
                        ),
                        const Divider(height: 20),
                        if (s.parts.isNotEmpty) ...[
                          const Text('قطعات و لوازم تعویض شده:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          ...s.parts.map((p) => Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('• ${p.name}', style: const TextStyle(fontSize: 13)),
                                  Text(formatToman(p.price), style: const TextStyle(fontSize: 13, color: Colors.white70)),
                                ],
                              )),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('اجرت دستمزد و تعمیرات:', style: TextStyle(fontSize: 13)),
                            Text(formatToman(s.laborCost), style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('جمع کل فاکتور:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(formatToman(s.grandTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.greenAccent)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // دکمه پرینت و ذخیره PDF
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                            icon: const Icon(Icons.print, size: 18, color: Colors.white),
                            label: const Text('چاپ / فاکتور PDF', style: TextStyle(color: Colors.white, fontSize: 12)),
                            onPressed: () => _printPdfInvoice(s),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0284C7),
        icon: const Icon(Icons.note_add, color: Colors.white),
        label: const Text('ثبت خدمات و فاکتور جدید', style: TextStyle(color: Colors.white)),
        onPressed: _openAddServiceDialog,
      ),
    );
  }

  // ایجاد و چاپ فاکتور PDF رسمی
  Future<void> _printPdfInvoice(ServiceRecord service) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.vazirmatnRegular();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text('فاکتور خدمات برق و عیب‌یابی خودرو', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 15),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('نام مشتری: ${widget.customer.name}'),
                    pw.Text('شماره تماس: ${widget.customer.phone}'),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('مدل خودرو: ${widget.car.model}'),
                    pw.Text('پلاک: ${widget.car.fullPlate}'),
                    pw.Text('تاریخ شمسی: ${service.date}'),
                  ],
                ),
                pw.Divider(thickness: 1.5, height: 25),
                pw.Text('شرح عیب و خدمات: ${service.title}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text('لیست قطعات مصرفی:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                ...service.parts.map((p) => pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('- ${p.name}'),
                        pw.Text(formatToman(p.price)),
                      ],
                    )),
                pw.Divider(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('اجرت دستمزد و خدمات:'),
                    pw.Text(formatToman(service.laborCost)),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  color: PdfColors.grey200,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('مبلغ کل قابل پرداخت:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                      pw.Text(formatToman(service.grandTotal), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('امضاء و مهر کارگاه برق خودرو'),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  void _openAddServiceDialog() {
    final titleCtrl = TextEditingController();
    final laborCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: JalaliHelper.nowShamsi());
    final List<PartItem> partsList = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('ثبت خدمات و فاکتور برق'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'تاریخ شمسی (مثلاً: ۱۴۰۳/۰۸/۱۷)')),
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'شرح کار (مثلاً: عیب‌یابی دیاگ و تعویض رله دوبل)')),
                TextField(controller: laborCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'اجرت دستمزد (به تومان)')),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('قطعات مصرفی:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.cyanAccent),
                      onPressed: () {
                        _openAddPartMiniDialog((part) {
                          setDialogState(() => partsList.add(part));
                        });
                      },
                    )
                  ],
                ),
                ...partsList.map((p) => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(p.name),
                        Text(formatToman(p.price)),
                      ],
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.isNotEmpty) {
                  final record = ServiceRecord(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleCtrl.text,
                    date: dateCtrl.text.isNotEmpty ? dateCtrl.text : JalaliHelper.nowShamsi(),
                    laborCost: int.tryParse(laborCtrl.text) ?? 0,
                    parts: partsList,
                  );
                  setState(() {
                    widget.car.services.insert(0, record);
                  });
                  widget.onChanged();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('ثبت نهایی فاکتور'),
            )
          ],
        ),
      ),
    );
  }

  void _openAddPartMiniDialog(Function(PartItem) onAdded) {
    final pNameCtrl = TextEditingController();
    final pPriceCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('افزودن قطعه خریداری شده'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: pNameCtrl, decoration: const InputDecoration(labelText: 'نام قطعه (مثلاً: آفتامات دینام)')),
            TextField(controller: pPriceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'قیمت فروش قطعه (تومان)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () {
              if (pNameCtrl.text.isNotEmpty) {
                onAdded(PartItem(name: pNameCtrl.text, price: int.tryParse(pPriceCtrl.text) ?? 0));
                Navigator.pop(ctx);
              }
            },
            child: const Text('افزودن'),
          )
        ],
      ),
    );
  }
}

// ۳. داشبورد گزارش روزانه دستمزد، قطعات و سود خالص
class DailyReportScreen extends StatefulWidget {
  final List<Customer> customers;

  const DailyReportScreen({super.key, required this.customers});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  late String selectedDate;

  @override
  void initState() {
    super.initState();
    selectedDate = JalaliHelper.nowShamsi();
  }

  @override
  Widget build(BuildContext context) {
    // استخراج تمام فاکتورهای مربوط به روز انتخاب شده
    List<Map<String, dynamic>> dailyServices = [];
    int totalLabor = 0;
    int totalParts = 0;

    for (var cust in widget.customers) {
      for (var car in cust.cars) {
        for (var s in car.services) {
          if (s.date == selectedDate) {
            totalLabor += s.laborCost;
            totalParts += s.partsTotal;
            dailyServices.add({
              'customer': cust.name,
              'car': car.model,
              'plate': car.fullPlate,
              'service': s,
            });
          }
        }
      }
    }

    final totalRevenue = totalLabor + totalParts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 گزارش کارکرد و دخل روزانه'),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // انتخاب تاریخ شمسی
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('تاریخ گزارش (شمسی):', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(selectedDate, style: const TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.edit_calendar, color: Colors.cyanAccent),
                    onPressed: () {
                      final ctrl = TextEditingController(text: selectedDate);
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('تغییر تاریخ گزارش'),
                          content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'تاریخ شمسی')),
                          actions: [
                            ElevatedButton(
                              onPressed: () {
                                setState(() => selectedDate = ctrl.text);
                                Navigator.pop(ctx);
                              },
                              child: const Text('اعمال'),
                            )
                          ],
                        ),
                      );
                    },
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
            // کارت دستمزد و سود خالص
            Card(
              color: const Color(0xFF0284C7).withOpacity(0.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.cyanAccent)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('💰 دستمزد و سود خالص امروز شما', style: TextStyle(fontSize: 16, color: Colors.white70)),
                    const SizedBox(height: 8),
                    Text(formatToman(totalLabor), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('جمع کل قطعات', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(formatToman(totalParts), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('کل دخل کارگاه (با قطعات)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(formatToman(totalRevenue), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Text('خودروهای سرویس شده امروز (${dailyServices.length} خودرو):', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            if (dailyServices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('هیچ فعالیتی در این تاریخ ثبت نشده است.', style: TextStyle(color: Colors.grey)),
              )
            else
              ...dailyServices.map((item) {
                final s = item['service'] as ServiceRecord;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text('${item['car']} - ${item['customer']}'),
                    subtitle: Text('${s.title}\nاجرت: ${formatToman(s.laborCost)}'),
                    trailing: Text(formatToman(s.grandTotal), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
