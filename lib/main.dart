import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AutoElectricApp());
}

// ======================== مبدل تاریخ شمسی ========================
class JalaliHelper {
  static String nowShamsi() {
    final now = DateTime.now();
    return gregorianToJalali(now.year, now.month, now.day);
  }

  static String currentMonthShamsi() {
    final now = JalaliHelper.nowShamsi();
    return now.substring(0, 7); // مثلاً 1403/08
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

// ======================== مدل‌های داده ========================
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

class ServiceRecord {
  String id;
  String title;
  String date;
  int laborCost;
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

// ======================== بدنه اصلی برنامه ========================
class AutoElectricApp extends StatelessWidget {
  const AutoElectricApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'برق خودرو مهندس', // تغییر نام پنجره برنامه
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
    final String? raw = prefs.getString('customers_data_v4');
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
    await prefs.setString('customers_data_v4', encoded);
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
          BottomNavigationBarItem(icon: Icon(Icons.build_circle), label: 'میز کار و مشتریان'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'گزارش دخل و سود'),
        ],
      ),
    );
  }
}

// ======================== صفحه اصلی و مدیریت پرونده‌ها ========================
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
        title: const Text('⚡ کلینیک برق و دیاگ خودرو', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_sync, color: Colors.cyanAccent),
            tooltip: 'پشتیبان‌گیری و بازیابی',
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
                hintText: 'جستجو با نام مشتری، پلاک، شماره یا تاریخ (۱۴۰۳)...',
                prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('پرونده‌ای یافت نشد.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _buildCustomerCard(filtered[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0284C7),
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text('مشتری جدید', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _openCustomerDialog(),
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
        title: Row(
          children: [
            Expanded(child: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            IconButton(
              icon: const Icon(Icons.edit, size: 20, color: Colors.cyanAccent),
              tooltip: 'ویرایش مشخصات مشتری',
              onPressed: () => _openCustomerDialog(customer: customer),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
              tooltip: 'حذف مشتری',
              onPressed: () => _confirmDeleteCustomer(customer),
            ),
          ],
        ),
        subtitle: Text('📞 ${customer.phone.isNotEmpty ? customer.phone : 'بدون شماره'}  |  🚗 ${customer.cars.length} خودرو'),
        children: [
          ...customer.cars.map((car) => _buildCarRow(customer, car)).toList(),
          TextButton.icon(
            icon: const Icon(Icons.add_circle_outline, color: Colors.cyanAccent),
            label: const Text('ثبت خودروی جدید برای این مشتری'),
            onPressed: () => _openCarDialog(customer: customer),
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
              Row(
                children: [
                  Text(car.model, style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 17, color: Colors.white60),
                    onPressed: () => _openCarDialog(customer: customer, carToEdit: car),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_forever, size: 17, color: Colors.redAccent),
                    onPressed: () => _confirmDeleteCar(customer, car),
                  ),
                ],
              ),
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
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.black, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(car.plateTwoDigits, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(width: 4),
            Text(car.plateLetter, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 4),
            Text(car.plateThreeDigits, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
            Container(
              height: 14,
              width: 1,
              color: Colors.black38,
              margin: const EdgeInsets.symmetric(horizontal: 6),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('ایران', style: TextStyle(color: Colors.black, fontSize: 8, height: 1)),
                Text(car.plateProvinceCode, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11, height: 1)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // دیالوگ افزودن و ویرایش مشتری
  void _openCustomerDialog({Customer? customer}) {
    final nameCtrl = TextEditingController(text: customer?.name ?? '');
    final phoneCtrl = TextEditingController(text: customer?.phone ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(customer == null ? 'ثبت مشتری جدید' : 'ویرایش اطلاعات مشتری'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'نام و نام خانوادگی')),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'شماره همراه')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                setState(() {
                  if (customer == null) {
                    widget.customers.insert(
                      0,
                      Customer(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        cars: [],
                      ),
                    );
                  } else {
                    customer.name = nameCtrl.text.trim();
                    customer.phone = phoneCtrl.text.trim();
                  }
                });
                widget.onDataChanged();
                Navigator.pop(ctx);
              }
            },
            child: const Text('ذخیره'),
          )
        ],
      ),
    );
  }

  void _confirmDeleteCustomer(Customer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ حذف پرونده مشتری', style: TextStyle(color: Colors.redAccent)),
        content: Text('آیا از حذف پرونده "${customer.name}" و تمام خودروها و فاکتورهای مربوط به آن مطمئن هستید؟ این عملیات غیرقابل بازگشت است.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              setState(() {
                widget.customers.removeWhere((c) => c.id == customer.id);
              });
              widget.onDataChanged();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('پرونده مشتری حذف شد.')));
            },
            child: const Text('بله، حذف کن', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // دیالوگ افزودن و ویرایش خودرو
  void _openCarDialog({required Customer customer, Car? carToEdit}) {
    final modelCtrl = TextEditingController(text: carToEdit?.model ?? '');
    final twoCtrl = TextEditingController(text: carToEdit?.plateTwoDigits ?? '');
    final letterCtrl = TextEditingController(text: carToEdit?.plateLetter ?? '');
    final threeCtrl = TextEditingController(text: carToEdit?.plateThreeDigits ?? '');
    final provCtrl = TextEditingController(text: carToEdit?.plateProvinceCode ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(carToEdit == null ? 'افزودن خودرو به پرونده' : 'ویرایش مشخصات خودرو'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'مدل خودرو (مثلاً: پژو ۲۰۶)')),
              const SizedBox(height: 12),
              const Text('مشخصات پلاک انتظامی:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: TextField(controller: provCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'کد ایران'))),
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
                setState(() {
                  if (carToEdit == null) {
                    customer.cars.add(
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
                  } else {
                    carToEdit.model = modelCtrl.text;
                    carToEdit.plateTwoDigits = twoCtrl.text;
                    carToEdit.plateLetter = letterCtrl.text;
                    carToEdit.plateThreeDigits = threeCtrl.text;
                    carToEdit.plateProvinceCode = provCtrl.text;
                  }
                });
                widget.onDataChanged();
                Navigator.pop(ctx);
              }
            },
            child: const Text('ذخیره'),
          )
        ],
      ),
    );
  }

  void _confirmDeleteCar(Customer customer, Car car) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف خودرو', style: TextStyle(color: Colors.redAccent)),
        content: Text('آیا از حذف خودروی "${car.model} (${car.fullPlate})" با تمام فاکتورهای آن اطمینان دارید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              setState(() {
                customer.cars.removeWhere((c) => c.id == car.id);
              });
              widget.onDataChanged();
              Navigator.pop(ctx);
            },
            child: const Text('حذف'),
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
              label: const Text('کپی کد فایل پشتیبان'),
              onPressed: () {
                final encoded = jsonEncode(widget.customers.map((c) => c.toMap()).toList());
                Clipboard.setData(ClipboardData(text: encoded));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('کد پشتیبان کپی شد! می‌توانید آن را در تلگرام ذخیره کنید.')),
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

// ======================== صفحه فاکتورها، چاپ PDF و ارسال پیامک ========================
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
                            Row(
                              children: [
                                Text('📅 ${s.date}', style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                  onPressed: () => _confirmDeleteService(s),
                                )
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        if (s.parts.isNotEmpty) ...[
                          const Text('قطعات و لوازم مصرفی:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // دکمه ارسال پیامک خلاصه صورتحساب
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700]),
                              icon: const Icon(Icons.sms, size: 16, color: Colors.white),
                              label: const Text('پیامک ترخیص', style: TextStyle(color: Colors.white, fontSize: 12)),
                              onPressed: () => _sendSmsNotification(s),
                            ),
                            const SizedBox(width: 8),
                            // دکمه پرینت و خروجی PDF
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                              icon: const Icon(Icons.print, size: 16, color: Colors.white),
                              label: const Text('چاپ فاکتور PDF', style: TextStyle(color: Colors.white, fontSize: 12)),
                              onPressed: () => _printPdfInvoice(s),
                            ),
                          ],
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
        label: const Text('ثبت فاکتور جدید', style: TextStyle(color: Colors.white)),
        onPressed: _openAddServiceDialog,
      ),
    );
  }

  // ارسال پیامک خودکار با متن آماده به راننده
  Future<void> _sendSmsNotification(ServiceRecord s) async {
    if (widget.customer.phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('شماره همراه مشتری ثبت نشده است!')));
      return;
    }
    final msg = 'مشتری گرامی ${widget.customer.name}\n'
        'خودروی ${widget.car.model} شما در کلینیک برق خودرو آماده تحویل است.\n'
        'شرح کار: ${s.title}\n'
        'مبلغ قابل پرداخت: ${formatToman(s.grandTotal)}';

    final uri = Uri.parse('sms:${widget.customer.phone}?body=${Uri.encodeComponent(msg)}');
    try {
      await launchUrl(uri);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('برنامه پیامک گوشی باز نشد.')));
    }
  }

  // حذف فاکتور
  void _confirmDeleteService(ServiceRecord s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف فاکتور'),
        content: const Text('آیا از حذف این فاکتور مطمئن هستید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              setState(() {
                widget.car.services.removeWhere((item) => item.id == s.id);
              });
              widget.onChanged();
              Navigator.pop(ctx);
            },
            child: const Text('حذف'),
          )
        ],
      ),
    );
  }

  // ایجاد و چاپ PDF با فونت استاندارد
  Future<void> _printPdfInvoice(ServiceRecord service) async {
    try {
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.vazirmatnRegular();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font),
          textDirection: pw.TextDirection.rtl,
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text('صورت‌حساب خدمات برق و الکترونیک خودرو', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('نام مشتری: ${widget.customer.name}'),
                      pw.Text('شماره تماس: ${widget.customer.phone}'),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('مدل خودرو: ${widget.car.model}'),
                      pw.Text('شماره پلاک: ${widget.car.fullPlate}'),
                      pw.Text('تاریخ: ${service.date}'),
                    ],
                  ),
                  pw.Divider(thickness: 1.2, height: 25),
                  pw.Text('شرح خدمات انجام شده: ${service.title}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  if (service.parts.isNotEmpty) ...[
                    pw.Text('قطعات و لوازم یدکی مصرفی:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    ...service.parts.map((p) => pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('• ${p.name}'),
                            pw.Text(formatToman(p.price)),
                          ],
                        )),
                    pw.Divider(height: 16),
                  ],
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('اجرت دستمزد و تعمیرات:'),
                      pw.Text(formatToman(service.laborCost)),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    color: PdfColors.grey200,
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('مبلغ نهایی قابل پرداخت:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                        pw.Text(formatToman(service.grandTotal), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ),
                  pw.Spacer(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('امضاء مشتری'),
                      pw.Text('مهر و امضاء کلینیک برق خودرو'),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در صدور PDF: $e'), backgroundColor: Colors.redAccent),
      );
    }
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
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'شرح کار (مثلاً: سیم‌کشی فن و تعویض فیوز)')),
                TextField(controller: laborCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'اجرت دستمزد (تومان)')),
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
        title: const Text('افزودن قطعه خریده شده'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: pNameCtrl, decoration: const InputDecoration(labelText: 'نام قطعه (مثلاً: رله دوبل)')),
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

// ======================== داشبورد دخل روزانه و ماهانه ========================
class DailyReportScreen extends StatefulWidget {
  final List<Customer> customers;

  const DailyReportScreen({super.key, required this.customers});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String selectedDay;
  late String selectedMonth;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    selectedDay = JalaliHelper.nowShamsi();
    selectedMonth = JalaliHelper.currentMonthShamsi();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 گزارش دخل و سود کارگاه'),
        backgroundColor: const Color(0xFF1E293B),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          tabs: const [
            Tab(text: 'گزارش روزانه'),
            Tab(text: 'گزارش ماهانه'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportView(isMonthly: false),
          _buildReportView(isMonthly: true),
        ],
      ),
    );
  }

  Widget _buildReportView({required bool isMonthly}) {
    List<Map<String, dynamic>> servicesList = [];
    int totalLabor = 0;
    int totalParts = 0;

    final targetFilter = isMonthly ? selectedMonth : selectedDay;

    for (var cust in widget.customers) {
      for (var car in cust.cars) {
        for (var s in car.services) {
          final isMatch = isMonthly ? s.date.startsWith(targetFilter) : (s.date == targetFilter);
          if (isMatch) {
            totalLabor += s.laborCost;
            totalParts += s.partsTotal;
            servicesList.add({
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isMonthly ? 'ماه گزارش (شمسی):' : 'روز گزارش (شمسی):', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(targetFilter, style: const TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.edit_calendar, color: Colors.cyanAccent),
                  onPressed: () {
                    final ctrl = TextEditingController(text: targetFilter);
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(isMonthly ? 'تغییر ماه (مثلاً: ۱۴۰۳/۰۸)' : 'تغییر تاریخ (مثلاً: ۱۴۰۳/۰۸/۱۷)'),
                        content: TextField(controller: ctrl),
                        actions: [
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                if (isMonthly) {
                                  selectedMonth = ctrl.text;
                                } else {
                                  selectedDay = ctrl.text;
                                }
                              });
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
          Card(
            color: const Color(0xFF0284C7).withOpacity(0.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.cyanAccent)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(isMonthly ? '💰 دستمزد و سود خالص این ماه' : '💰 دستمزد و سود خالص این روز', style: const TextStyle(fontSize: 16, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text(formatToman(totalLabor), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('جمع کل لوازم و قطعات', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
            child: Text('سوابق خدمات در این بازه (${servicesList.length} مورد):', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          if (servicesList.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text('هیچ فاکتوری در این تاریخ ثبت نشده است.', style: TextStyle(color: Colors.grey)),
            )
          else
            ...servicesList.map((item) {
              final s = item['service'] as ServiceRecord;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text('${item['car']} - ${item['customer']} (${s.date})'),
                  subtitle: Text('${s.title}\nاجرت: ${formatToman(s.laborCost)}'),
                  trailing: Text(formatToman(s.grandTotal), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                ),
              );
            }),
        ],
      ),
    );
  }
}
