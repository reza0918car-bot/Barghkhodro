import 'dart:convert';
import 'package:flutter/foundation.dart';
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

// ======================== ابزارهای کمکی (تبدیل اعداد و تقویم) ========================
class NumberHelper {
  /// تبدیل ارقام فارسی و عربی به ارقام استاندارد انگلیسی و حذف کاراکترهای اضافه
  static String cleanNumbers(String input) {
    const farsi = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    String res = input.trim();
    for (int i = 0; i < 10; i++) {
      res = res.replaceAll(farsi[i], english[i]).replaceAll(arabic[i], english[i]);
    }
    return res.replaceAll(',', '').replaceAll(' ', '');
  }

  static int safeParseInt(String input) {
    final cleaned = cleanNumbers(input);
    return int.tryParse(cleaned) ?? 0;
  }
}

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
    List<int> gDM = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
    int jy = (gy <= 1600) ? 0 : 979;
    gy -= (gy <= 1600) ? 621 : 1600;
    int gy2 = (gm > 2) ? (gy + 1) : gy;
    int days = (365 * gy) + ((gy2 + 3) ~/ 4) - ((gy2 + 99) ~/ 100) +
        ((gy2 + 399) ~/ 400) - 80 + gd + gDM[gm - 1];
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
  String date;
  List<LaborItem> labors;
  List<PartItem> parts;

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

// ======================== بدنه برنامه ========================
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('customers_data_v6');
    if (raw != null) {
      try {
        final List decoded = jsonDecode(raw);
        setState(() {
          customers = decoded.map((e) => Customer.fromMap(e)).toList();
          _isLoading = false;
        });
        return;
      } catch (e) {
        debugPrint('Error decoding storage: $e');
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(customers.map((c) => c.toMap()).toList());
    await prefs.setString('customers_data_v6', encoded);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
    final int totalCars = widget.customers.fold(0, (sum, c) => sum + c.cars.length);

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
            icon: const Icon(Icons.campaign, color: Colors.amberAccent, size: 26),
            tooltip: 'پیامک گروهی و باشگاه مشتریان',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => BulkSmsScreen(customers: widget.customers),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud_sync, color: Colors.cyanAccent),
            tooltip: 'پشتیبان‌گیری و بازیابی',
            onPressed: _openBackupDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF0284C7).withOpacity(0.3), const Color(0xFF1E293B)],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_alt, color: Colors.cyanAccent, size: 20),
                    const SizedBox(width: 8),
                    Text('کل مشتریان: ${widget.customers.length} نفر',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                Container(height: 16, width: 1, color: Colors.white24),
                Row(
                  children: [
                    const Icon(Icons.directions_car, color: Colors.amberAccent, size: 20),
                    const SizedBox(width: 8),
                    Text('کل خودروها: $totalCars دستگاه',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => BulkSmsScreen(customers: widget.customers),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('ارسال پیامک',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: (val) => setState(() => searchQuery = val),
              decoration: InputDecoration(
                hintText: 'جستجو با نام، شماره، مدل خودرو یا پلاک...',
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
          ...customer.cars.map((car) => _buildCarRow(customer, car)),
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
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        car.model,
                        style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => CarServicesScreen(
                        customer: customer,
                        car: car,
                        onChanged: () {
                          widget.onDataChanged();
                          setState(() {});
                        },
                      ),
                    ),
                  );
                  setState(() {});
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
    showDialog(
      context: context,
      builder: (ctx) => _CustomerEditDialog(
        customer: customer,
        onSave: (name, phone) {
          setState(() {
            if (customer == null) {
              widget.customers.insert(
                0,
                Customer(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  phone: phone,
                  cars: [],
                ),
              );
            } else {
              customer.name = name;
              customer.phone = phone;
            }
          });
          widget.onDataChanged();
        },
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
    showDialog(
      context: context,
      builder: (ctx) => _CarEditDialog(
        carToEdit: carToEdit,
        onSave: (model, two, letter, three, prov) {
          setState(() {
            if (carToEdit == null) {
              customer.cars.add(
                Car(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  model: model,
                  plateTwoDigits: two,
                  plateLetter: letter,
                  plateThreeDigits: three,
                  plateProvinceCode: prov,
                  services: [],
                ),
              );
            } else {
              carToEdit.model = model;
              carToEdit.plateTwoDigits = two;
              carToEdit.plateLetter = letter;
              carToEdit.plateThreeDigits = three;
              carToEdit.plateProvinceCode = prov;
            }
          });
          widget.onDataChanged();
        },
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
                  const SnackBar(content: Text('کد پشتیبان کپی شد! می‌توانید آن را ذخیره یا در پیام‌رسان بفرستید.')),
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
                final List decoded = jsonDecode(codeCtrl.text.trim());
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

// ======================== دیالوگ‌های مستقل با مدیریت حافظه ========================
class _CustomerEditDialog extends StatefulWidget {
  final Customer? customer;
  final Function(String name, String phone) onSave;

  const _CustomerEditDialog({this.customer, required this.onSave});

  @override
  State<_CustomerEditDialog> createState() => _CustomerEditDialogState();
}

class _CustomerEditDialogState extends State<_CustomerEditDialog> {
  late final TextEditingController nameCtrl;
  late final TextEditingController phoneCtrl;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.customer?.name ?? '');
    phoneCtrl = TextEditingController(text: widget.customer?.phone ?? '');
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.customer == null ? 'ثبت مشتری جدید' : 'ویرایش مشخصات مشتری'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'نام و نام خانوادگی')),
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'شماره همراه'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
        ElevatedButton(
          onPressed: () {
            if (nameCtrl.text.trim().isNotEmpty) {
              widget.onSave(nameCtrl.text.trim(), NumberHelper.cleanNumbers(phoneCtrl.text));
              Navigator.pop(context);
            }
          },
          child: const Text('ذخیره'),
        )
      ],
    );
  }
}

class _CarEditDialog extends StatefulWidget {
  final Car? carToEdit;
  final Function(String model, String two, String letter, String three, String prov) onSave;

  const _CarEditDialog({this.carToEdit, required this.onSave});

  @override
  State<_CarEditDialog> createState() => _CarEditDialogState();
}

class _CarEditDialogState extends State<_CarEditDialog> {
  late final TextEditingController modelCtrl;
  late final TextEditingController twoCtrl;
  late final TextEditingController letterCtrl;
  late final TextEditingController threeCtrl;
  late final TextEditingController provCtrl;

  @override
  void initState() {
    super.initState();
    modelCtrl = TextEditingController(text: widget.carToEdit?.model ?? '');
    twoCtrl = TextEditingController(text: widget.carToEdit?.plateTwoDigits ?? '');
    letterCtrl = TextEditingController(text: widget.carToEdit?.plateLetter ?? '');
    threeCtrl = TextEditingController(text: widget.carToEdit?.plateThreeDigits ?? '');
    provCtrl = TextEditingController(text: widget.carToEdit?.plateProvinceCode ?? '');
  }

  @override
  void dispose() {
    modelCtrl.dispose();
    twoCtrl.dispose();
    letterCtrl.dispose();
    threeCtrl.dispose();
    provCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.carToEdit == null ? 'افزودن خودرو به پرونده' : 'ویرایش مشخصات خودرو'),
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
        ElevatedButton(
          onPressed: () {
            if (modelCtrl.text.trim().isNotEmpty) {
              widget.onSave(
                modelCtrl.text.trim(),
                NumberHelper.cleanNumbers(twoCtrl.text),
                letterCtrl.text.trim(),
                NumberHelper.cleanNumbers(threeCtrl.text),
                NumberHelper.cleanNumbers(provCtrl.text),
              );
              Navigator.pop(context);
            }
          },
          child: const Text('ذخیره'),
        )
      ],
    );
  }
}

// ======================== باشگاه مشتریان و ارسال پیامک گروهی ========================
class BulkSmsScreen extends StatefulWidget {
  final List<Customer> customers;

  const BulkSmsScreen({super.key, required this.customers});

  @override
  State<BulkSmsScreen> createState() => _BulkSmsScreenState();
}

class _BulkSmsScreenState extends State<BulkSmsScreen> {
  final TextEditingController _msgCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _msgCtrl.text = 'مشتری گرامی کلینیک برق خودرو مهندس،\n'
        'به اطلاع می‌رساند مکان کارگاه به آدرس جدید انتقال یافت.\n'
        'آدرس جدید: [آدرس خود را اینجا بنویسید]\n'
        'تلفن: [شماره تماس شما]';
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  List<String> _getValidPhones() {
    final Set<String> phones = {};
    for (var c in widget.customers) {
      final p = NumberHelper.cleanNumbers(c.phone);
      if (p.isNotEmpty && p.length >= 10) {
        phones.add(p);
      }
    }
    return phones.toList();
  }

  void _copyAllNumbers({bool withComma = true}) {
    final phones = _getValidPhones();
    if (phones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هیچ شماره تماسی یافت نشد!')));
      return;
    }
    final text = phones.join(withComma ? ', ' : '\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${phones.length} شماره تماس کپی شد!')),
    );
  }

  Future<void> _openGroupSms() async {
    final phones = _getValidPhones();
    if (phones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هیچ شماره تماسی وجود ندارد!')));
      return;
    }

    // بررسی تعداد شماره‌ها برای جلوگیری از شکست باز شدن پروتکل در سیستم‌عامل
    if (phones.length > 25) {
      _copyAllNumbers(withComma: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعداد شماره‌ها زیاد است. شماره‌ها در کلیپ‌بورد کپی شدند تا مستقیماً در نرم‌افزار پیامک Paste کنید.')),
      );
      return;
    }

    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final separator = isIos ? ';' : ',';
    final recipients = phones.join(separator);
    final uri = Uri(
      scheme: 'sms',
      path: recipients,
      queryParameters: {'body': _msgCtrl.text},
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _copyAllNumbers(withComma: true);
      }
    } catch (e) {
      _copyAllNumbers(withComma: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phones = _getValidPhones();

    return Scaffold(
      appBar: AppBar(
        title: const Text('📢 باشگاه مشتریان و پیامک گروهی'),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.cyanAccent),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تعداد شماره‌های آماده ارسال:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('${phones.length} شماره فعال و بدون تکرار',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.greenAccent)),
                    ],
                  ),
                  const Icon(Icons.contact_phone, color: Colors.cyanAccent, size: 36),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('متن پیامک ارسالی:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _msgCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            const Text('نمونه متن‌های آماده:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  backgroundColor: const Color(0xFF1E293B),
                  label: const Text('📢 تغییر آدرس مغازه'),
                  onPressed: () {
                    setState(() {
                      _msgCtrl.text = 'مشتری گرامی برق خودرو مهندس،\n'
                          'مکان کارگاه به آدرس جدید انتقال یافت:\n'
                          '[آدرس جدید خود را اینجا بنویسید]\n'
                          'تلفن: [شماره تماس]';
                    });
                  },
                ),
                ActionChip(
                  backgroundColor: const Color(0xFF1E293B),
                  label: const Text('🎁 تخفیف و دیاگ رایگان'),
                  onPressed: () {
                    setState(() {
                      _msgCtrl.text = 'جشنواره تخفیف برق خودرو مهندس!\n'
                          'دیاگ رایگان و ۲۰٪ تخفیف در اجرت سیم‌کشی و تعمیر دینام تا پایان هفته.\n'
                          'منتظر حضور گرمتان هستیم.';
                    });
                  },
                ),
                ActionChip(
                  backgroundColor: const Color(0xFF1E293B),
                  label: const Text('❄️ تست رایگان باتری و دینام'),
                  onPressed: () {
                    setState(() {
                      _msgCtrl.text = 'طرح فصلی برق خودرو مهندس:\n'
                          'تست رایگان باتری، دینام و سلامت سیستم شارژ با دستگاه دیجیتال.\n'
                          'آدرس: [آدرس کارگاه]';
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[800],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.copy, color: Colors.white),
                    label: const Text('کپی شماره‌ها (با کاما)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () => _copyAllNumbers(withComma: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.send, color: Colors.white),
                    label: const Text('ارسال پیامک گروهی', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: _openGroupSms,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.list_alt, size: 18),
                label: const Text('کپی شماره‌ها خط‌به‌خط (جهت اکسل)'),
                onPressed: () => _copyAllNumbers(withComma: false),
              ),
            ),
            const Divider(height: 24),
            const Text('لیست مشتریان و شماره‌ها:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            ...widget.customers.where((c) => c.phone.trim().isNotEmpty).map((c) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.phone_android, color: Colors.cyanAccent, size: 20),
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Text(c.phone, style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ======================== صفحه فاکتورهای خودرو ========================
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
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20, color: Colors.cyanAccent),
                                  tooltip: 'ویرایش فاکتور',
                                  onPressed: () => _openServiceDialog(serviceToEdit: s),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                  tooltip: 'حذف فاکتور',
                                  onPressed: () => _confirmDeleteService(s),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 16),
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
                        if (s.parts.isNotEmpty) ...[
                          const Text('🔩 قطعات و لوازم مصرفی:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent, fontSize: 13)),
                          const SizedBox(height: 6),
                          ...s.parts.map((p) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('• ${p.name}', style: const TextStyle(fontSize: 13)),
                                    Text(formatToman(p.price), style: const TextStyle(fontSize: 13, color: Colors.white70)),
                                  ],
                                ),
                              )),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('جمع قطعات:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(formatToman(s.partsTotal), style: const TextStyle(fontSize: 12, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(height: 16),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('مبلغ کل قابل پرداخت:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(formatToman(s.grandTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.greenAccent)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700]),
                              icon: const Icon(Icons.sms, size: 16, color: Colors.white),
                              label: const Text('پیامک به مشتری', style: TextStyle(color: Colors.white, fontSize: 12)),
                              onPressed: () => _sendSmsNotification(s),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                              icon: const Icon(Icons.print, size: 16, color: Colors.white),
                              label: const Text('فاکتور PDF', style: TextStyle(color: Colors.white, fontSize: 12)),
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
        label: const Text('ثبت فاکتور جدید', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _openServiceDialog(),
      ),
    );
  }

  Future<void> _sendSmsNotification(ServiceRecord s) async {
    if (widget.customer.phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('شماره همراه مشتری ثبت نشده است!')));
      return;
    }

    final laborsText = s.labors.map((l) => l.title).join('، ');
    final msg = 'مشتری گرامی ${widget.customer.name}\n'
        'خودروی ${widget.car.model} (${widget.car.fullPlate}) آماده تحویل است.\n'
        'خدمات: $laborsText\n'
        'مبلغ کل فاکتور: ${formatToman(s.grandTotal)}\n'
        '⚡ کلینیک برق خودرو مهندس';

    final uri = Uri(
      scheme: 'sms',
      path: NumberHelper.cleanNumbers(widget.customer.phone),
      queryParameters: {'body': msg},
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        Clipboard.setData(ClipboardData(text: msg));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('متن پیامک کپی شد.')));
        }
      }
    } catch (e) {
      Clipboard.setData(ClipboardData(text: msg));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('متن پیامک در کلیپ‌بورد کپی شد.')));
      }
    }
  }

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

  Future<void> _printPdfInvoice(ServiceRecord service) async {
    try {
      final pdf = pw.Document();

      // لود ایمن فونت فارسی با مکانیزم Fallback برای زمان قطعی اینترنت
      pw.Font font;
      pw.Font fontBold;
      try {
        font = await PdfGoogleFonts.vazirmatnRegular();
        fontBold = await PdfGoogleFonts.vazirmatnBold();
      } catch (_) {
        // در صورت عدم دسترسی به اینترنت فونت سیستمی استفاده می‌شود
        font = pw.Font.helvetica();
        fontBold = pw.Font.helveticaBold();
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          textDirection: pw.TextDirection.rtl,
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(24),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Center(
                      child: pw.Text('صورت‌حساب کلینیک برق خودرو مهندس',
                          style: pw.TextStyle(font: fontBold, fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('نام مشتری: ${widget.customer.name}', style: pw.TextStyle(font: font)),
                        pw.Text('شماره تماس: ${widget.customer.phone}', style: pw.TextStyle(font: font)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('مدل خودرو: ${widget.car.model}', style: pw.TextStyle(font: font)),
                        pw.Text('پلاک: ${widget.car.fullPlate}', style: pw.TextStyle(font: font)),
                        pw.Text('تاریخ فاکتور: ${service.date}', style: pw.TextStyle(font: font)),
                      ],
                    ),
                    pw.Divider(thickness: 1.2, height: 25),
                    pw.Text('🔧 خدمات و اجرت‌های انجام شده:', style: pw.TextStyle(font: fontBold, fontWeight: pw.FontWeight.bold, fontSize: 13)),
                    pw.SizedBox(height: 6),
                    ...service.labors.map((l) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('• ${l.title}', style: pw.TextStyle(font: font)),
                              pw.Text(formatToman(l.cost), style: pw.TextStyle(font: font)),
                            ],
                          ),
                        )),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('جمع اجرت‌ها:', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                        pw.Text(formatToman(service.laborTotal), style: pw.TextStyle(font: fontBold, fontSize: 10)),
                      ],
                    ),
                    pw.Divider(height: 16),
                    if (service.parts.isNotEmpty) ...[
                      pw.Text('🔩 قطعات و لوازم مصرفی:', style: pw.TextStyle(font: fontBold, fontWeight: pw.FontWeight.bold, fontSize: 13)),
                      pw.SizedBox(height: 6),
                      ...service.parts.map((p) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 2),
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('• ${p.name}', style: pw.TextStyle(font: font)),
                                pw.Text(formatToman(p.price), style: pw.TextStyle(font: font)),
                              ],
                            ),
                          )),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('جمع قطعات:', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                          pw.Text(formatToman(service.partsTotal), style: pw.TextStyle(font: fontBold, fontSize: 10)),
                        ],
                      ),
                      pw.Divider(height: 16),
                    ],
                    pw.SizedBox(height: 10),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      color: PdfColors.grey200,
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('مبلغ نهایی قابل پرداخت:', style: pw.TextStyle(font: fontBold, fontWeight: pw.FontWeight.bold, fontSize: 13)),
                          pw.Text(formatToman(service.grandTotal), style: pw.TextStyle(font: fontBold, fontWeight: pw.FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                    pw.Spacer(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('امضاء و رضایت مشتری', style: pw.TextStyle(font: font)),
                        pw.Text('مهر و امضاء برق خودرو مهندس', style: pw.TextStyle(font: font)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'فاکتور_${widget.customer.name}_${service.date}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در صدور PDF: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _openServiceDialog({ServiceRecord? serviceToEdit}) {
    showDialog(
      context: context,
      builder: (ctx) => _ServiceEditDialog(
        serviceToEdit: serviceToEdit,
        onSave: (record) {
          setState(() {
            if (serviceToEdit == null) {
              widget.car.services.insert(0, record);
            } else {
              serviceToEdit.date = record.date;
              serviceToEdit.labors = record.labors;
              serviceToEdit.parts = record.parts;
            }
          });
          widget.onChanged();
        },
      ),
    );
  }
}

// ======================== دیالوگ ثبت و ویرایش فاکتور ========================
class _ServiceEditDialog extends StatefulWidget {
  final ServiceRecord? serviceToEdit;
  final Function(ServiceRecord) onSave;

  const _ServiceEditDialog({this.serviceToEdit, required this.onSave});

  @override
  State<_ServiceEditDialog> createState() => _ServiceEditDialogState();
}

class _ServiceEditDialogState extends State<_ServiceEditDialog> {
  late final TextEditingController dateCtrl;
  late final List<LaborItem> laborsList;
  late final List<PartItem> partsList;

  @override
  void initState() {
    super.initState();
    dateCtrl = TextEditingController(text: widget.serviceToEdit?.date ?? JalaliHelper.nowShamsi());
    laborsList = widget.serviceToEdit != null ? widget.serviceToEdit!.labors.map((l) => LaborItem(title: l.title, cost: l.cost)).toList() : [];
    partsList = widget.serviceToEdit != null ? widget.serviceToEdit!.parts.map((p) => PartItem(name: p.name, price: p.price)).toList() : [];
  }

  @override
  void dispose() {
    dateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int currentLaborTotal = laborsList.fold(0, (sum, i) => sum + i.cost);
    int currentPartsTotal = partsList.fold(0, (sum, i) => sum + i.price);
    int currentGrandTotal = currentLaborTotal + currentPartsTotal;

    return AlertDialog(
      title: Text(widget.serviceToEdit == null ? 'ثبت خدمات و فاکتور جدید' : 'ویرایش فاکتور'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'تاریخ شمسی فاکتور (مثلاً: 1403/08/17)')),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('🔧 خدمات و اجرت‌ها:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('افزودن کار', style: TextStyle(fontSize: 11)),
                          onPressed: () => _openAddLaborDialog(),
                        ),
                      ],
                    ),
                    if (laborsList.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6.0),
                        child: Text('هنوز خدمتی اضافه نشده است.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      )
                    else
                      ...laborsList.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final l = entry.value;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('• ${l.title}: ${formatToman(l.cost)}', style: const TextStyle(fontSize: 12)),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                              onPressed: () => setState(() => laborsList.removeAt(idx)),
                            )
                          ],
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('🔩 لوازم و قطعات:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800], padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('افزودن قطعه', style: TextStyle(fontSize: 11)),
                          onPressed: () => _openAddPartDialog(),
                        ),
                      ],
                    ),
                    if (partsList.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6.0),
                        child: Text('قطعه‌ای اضافه نشده است.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      )
                    else
                      ...partsList.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final p = entry.value;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('• ${p.name}: ${formatToman(p.price)}', style: const TextStyle(fontSize: 12)),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                              onPressed: () => setState(() => partsList.removeAt(idx)),
                            )
                          ],
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('جمع کل فاکتور:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(formatToman(currentGrandTotal), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent, fontSize: 15)),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
        ElevatedButton(
          onPressed: () {
            if (laborsList.isEmpty && partsList.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حداقل یک خدمت یا یک قطعه اضافه کنید.')));
              return;
            }
            final record = ServiceRecord(
              id: widget.serviceToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
              date: dateCtrl.text.isNotEmpty ? dateCtrl.text.trim() : JalaliHelper.nowShamsi(),
              labors: List.from(laborsList),
              parts: List.from(partsList),
            );
            widget.onSave(record);
            Navigator.pop(context);
          },
          child: const Text('ذخیره فاکتور'),
        )
      ],
    );
  }

  void _openAddLaborDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _SingleItemDialog(
        title: 'افزودن شرح کار و دستمزد',
        firstFieldLabel: 'شرح کار (مثلاً: عیب‌یابی دیاگ یا تعویض دینام)',
        secondFieldLabel: 'اجرت دستمزد (تومان)',
        onAdd: (name, price) {
          setState(() {
            laborsList.add(LaborItem(title: name, cost: price));
          });
        },
      ),
    );
  }

  void _openAddPartDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _SingleItemDialog(
        title: 'افزودن قطعه مصرفی',
        firstFieldLabel: 'نام قطعه (مثلاً: رله دوبل یا لامپ)',
        secondFieldLabel: 'قیمت فروش قطعه (تومان)',
        onAdd: (name, price) {
          setState(() {
            partsList.add(PartItem(name: name, price: price));
          });
        },
      ),
    );
  }
}

class _SingleItemDialog extends StatefulWidget {
  final String title;
  final String firstFieldLabel;
  final String secondFieldLabel;
  final Function(String name, int price) onAdd;

  const _SingleItemDialog({
    required this.title,
    required this.firstFieldLabel,
    required this.secondFieldLabel,
    required this.onAdd,
  });

  @override
  State<_SingleItemDialog> createState() => _SingleItemDialogState();
}

class _SingleItemDialogState extends State<_SingleItemDialog> {
  late final TextEditingController nameCtrl;
  late final TextEditingController costCtrl;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController();
    costCtrl = TextEditingController();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    costCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameCtrl, decoration: InputDecoration(labelText: widget.firstFieldLabel)),
          TextField(
            controller: costCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: widget.secondFieldLabel),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
        ElevatedButton(
          onPressed: () {
            if (nameCtrl.text.trim().isNotEmpty) {
              widget.onAdd(nameCtrl.text.trim(), NumberHelper.safeParseInt(costCtrl.text));
              Navigator.pop(context);
            }
          },
          child: const Text('افزودن'),
        )
      ],
    );
  }
}

// ======================== داشبورد دخل و سود روزانه و ماهانه ========================
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
            totalLabor += s.laborTotal;
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
                        title: Text(isMonthly ? 'تغییر ماه (مثلاً: 1403/08)' : 'تغییر تاریخ (مثلاً: 1403/08/17)'),
                        content: TextField(controller: ctrl),
                        actions: [
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                if (isMonthly) {
                                  selectedMonth = ctrl.text.trim();
                                } else {
                                  selectedDay = ctrl.text.trim();
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
            child: Text('سوابق فاکتورهای این بازه (${servicesList.length} فاکتور):', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  subtitle: Text('${s.summaryTitle}\nاجرت: ${formatToman(s.laborTotal)}'),
                  trailing: Text(formatToman(s.grandTotal), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                ),
              );
            }),
        ],
      ),
    );
  }
}
