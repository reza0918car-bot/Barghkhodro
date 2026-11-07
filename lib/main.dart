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

// ======================== تقویم شمسی ========================
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
// اجرت هر کار به طور جداگانه
class LaborItem {
  String title;
  int cost;

  LaborItem({required this.title, required this.cost});

  Map<String, dynamic> toMap() => {'title': title, 'cost': cost};
  factory LaborItem.fromMap(Map<String, dynamic> map) => LaborItem(
        title: map['title'] ?? '',
        cost: map['cost'] ?? 0,
      );
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

// فاکتور ثبت شده
class ServiceRecord {
  String id;
  String date;
  List<LaborItem> labors; // لیست اجرت‌ها
  List<PartItem> parts;   // لیست قطعات

  ServiceRecord({
    required this.id,
    required this.date,
    required this.labors,
    required this.parts,
  });

  int get laborTotal => labors.fold(0, (sum, item) => sum + item.cost);
  int get partsTotal => parts.fold(0, (sum, item) => sum + item.price);
  int get grandTotal => laborTotal + partsTotal;

  String get summaryTitle => labors.isNotEmpty 
      ? labors.map((l) => l.title).join(' ، ') 
      : 'خدمات عمومی برق خودرو';

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date,
        'labors': labors.map((l) => l.toMap()).toList(),
        'parts': parts.map((p) => p.toMap()).toList(),
      };

  factory ServiceRecord.fromMap(Map<String, dynamic> map) {
    List<LaborItem> parsedLabors = [];
    if (map['labors'] != null) {
      parsedLabors = (map['labors'] as List).map((l) => LaborItem.fromMap(l)).toList();
    } else if (map['title'] != null || map['laborCost'] != null) {
      // سازگاری با رکوردهای قدیمی
      parsedLabors = [
        LaborItem(
          title: map['title'] ?? 'خدمات برق',
          cost: map['laborCost'] ?? 0,
        )
      ];
    }

    return ServiceRecord(
      id: map['id'] ?? '',
      date: map['date'] ?? JalaliHelper.nowShamsi(),
      labors: parsedLabors,
      parts: (map['parts'] as List? ?? []).map((p) => PartItem.fromMap(p)).toList(),
    );
  }
}

// خودرو
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

// مشتری
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

// ======================== ویجت اصلی برنامه ========================
class AutoElectricApp extends StatelessWidget {
  const AutoElectricApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'برق خودرو مهندس',
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
    final String? raw = prefs.getString('customers_data_v5');
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
    await prefs.setString('customers_data_v5', encoded);
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

// ======================== صفحه اصلی ========================
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
          car.services.any((s) => s.summaryTitle.contains(q) || s.date.contains(q)));
      return matchCust || matchCar;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚡ برق خودرو مهندس', style: TextStyle(fontWeight: FontWeight.bold)),
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
                hintText: 'جستجو با نام، پلاک، کار انجام شده یا تاریخ...',
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
              onPressed: () => _openCustomerDialog(customer: customer),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
              onPressed: () => _confirmDeleteCustomer(customer),
            ),
          ],
        ),
        subtitle: Text('📞 ${customer.phone.isNotEmpty ? customer.phone : 'بدون شماره'}  |  🚗 ${customer.cars.length} خودرو'),
        children: [
          ...customer.cars.map((car) => _buildCarRow(customer, car)).toList(),
          TextButton.icon(
            icon: const Icon(Icons.add_circle_outline, color: Colors.cyanAccent),
            label: const Text('ثبت خودروی دیگر برای این مشتری'),
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

  void _openCustomerDialog({Customer? customer}) {
    final nameCtrl = TextEditingController(text: customer?.name ?? '');
    final phoneCtrl = TextEditingController(text: customer?.phone ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(customer == null ? 'ثبت مشتری جدید' : 'ویرایش مشخصات مشتری'),
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
        content: Text('آیا از حذف پرونده "${customer.name}" و کلیه خودروها و فاکتورها اطمینان دارید؟'),
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
            },
            child: const Text('حذف'),
          )
        ],
      ),
    );
  }

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
              TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'مدل خودرو (مثلاً: دنا پلاس)')),
              const SizedBox(height: 12),
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
        content: Text('آیا از حذف خودروی "${car.model}" مطمئن هستید؟'),
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

// ======================== صفحه فاکتور با لیست خدمات و قطعات ========================
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
          ? const Center(child: Text('هنوز فاکتوری برای این خودرو ثبت نشده است.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: widget.car.services.length,
              itemBuilder: (context, i) {
                final s = widget.car.services[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('📅 تاریخ: ${s.date}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amberAccent)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                              onPressed: () => _confirmDeleteService(s),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        
                        // ۱. لیست اجرت‌ها و خدمات
                        const Text('🔧 خدمات و اجرت‌های انجام شده:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent, fontSize: 13)),
                        const SizedBox(height: 6),
                        ...s.labors.map((l) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('• ${l.title}', style: const TextStyle(fontSize: 13)),
                              Text(formatToman(l.cost), style: const TextStyle(fontSize: 13, color: Colors.white70)),
                            ],
                          ),
                        )),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('جمع اجرت‌ها:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(formatToman(s.laborTotal), style: const TextStyle(fontSize: 12, color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(height: 16),

                        // ۲. لیست لوازم و قطعات
                        if (s.parts.isNotEmpty) ...[
                          const Text('🔩 قطعات و لوازم مصرفی:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent, fontSize: 13)),
                          const SizedBox(height: 6),
                          ...s.parts.map((p) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
