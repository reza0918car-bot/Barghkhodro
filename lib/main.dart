import 'dart:async';
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
- name: Fix or Generate Android Files
        run: |
          if [ ! -f "android/app/build.gradle" ] && [ ! -f "android/app/build.gradle.kts" ]; then
            echo "Android files missing. Regenerating..."
            rm -rf android
            flutter create --platforms=android .
          fi

          # 👈👈 دقیقاً اینجا، بعد از fi اضافه کنید:
          sed -i 's/android:label="[^"]*"/android:label="برق خودرو مهندس"/g' android/app/src/main/AndroidManifest.xml

          chmod +x android/gradlew || true
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AutoElectricApp());
}

// ======================== لیست حروف معتبر پلاک ملی ایران ========================
const List<String> kIranPlateLetters = [
  'ب', 'ج', 'د', 'س', 'ص', 'ط', 'ق', 'ل', 'م', 'ن', 'و', 'هـ', 'ی',
  'الف', 'پ', 'ت', 'ث', 'ز', 'ش', 'ع', 'ف', 'ک', 'گ', '♿'
];

// لیست خودروهای متداول جهت انتخاب سریع
const List<String> kPopularCars = [
  'پژو پارس', 'پژو ۲۰۶', 'پژو ۲۰۷', 'پژو ۴۰۵', 'پراید ۱۳۱', 'پراید ۱۱۱',
  'کوییک', 'تیبا', 'ساینا', 'سمند EF7', 'دنا پلاس', 'تارا', 'شاهین',
  'رانا', 'نیسان وانت', 'پیکان وانت', 'ال ۹۰ (تندر)', 'ام‌وی‌ام (MVM)', 'جک (JAC)'
];

// لیست خدمات پرکاربرد برق خودرو با اجرت پیشنهادی پایه (تومان)
const List<Map<String, dynamic>> kQuickLabors = [
  {'title': 'تعمیر و سرویس دینام', 'cost': 350000},
  {'title': 'تعمیر و سرویس استارت', 'cost': 350000},
  {'title': 'دیاگ، عیب‌یابی و پاک کردن خطا', 'cost': 150000},
  {'title': 'عیب‌یابی سیم‌کشی و فن خنک‌کننده', 'cost': 250000},
  {'title': 'تست باتری و شارژ دینام', 'cost': 80000},
  {'title': 'تعویض رله دوبل و فیوزها', 'cost': 120000},
  {'title': 'سرویس شمع و وایر', 'cost': 180000},
  {'title': 'شارژ گاز و نشت‌یابی کولر', 'cost': 450000},
];

// ======================== ابزارهای کمکی و بهینه‌سازی ========================
class NumberHelper {
  static String cleanNumbers(String input) {
    const f = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const a = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const e = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    String res = input.trim();
    for (int i = 0; i < 10; i++) {
      res = res.replaceAll(f[i], e[i]).replaceAll(a[i], e[i]);
    }
    return res.replaceAll(',', '').replaceAll(' ', '');
  }

  static String normalizePhone(String input) {
    String res = cleanNumbers(input).replaceAll('-', '').replaceAll('+', '');
    if (res.startsWith('0098')) {
      res = '0${res.substring(4)}';
    } else if (res.startsWith('98') && res.length == 12) {
      res = '0${res.substring(2)}';
    } else if (res.length == 10 && res.startsWith('9')) {
      res = '0$res';
    }
    return res;
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

  static String currentMonthShamsi() => nowShamsi().substring(0, 7);

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

// ======================== توابع ایزوله پردازش پس‌زمینه (Isolates) ========================
// این توابع مانع از قفل شدن یا لگ زدن صفحه در تعداد ۳۰۰۰+ مشتری می‌شوند
List<Customer> _decodeCustomersIsolate(String rawJson) {
  final List decoded = jsonDecode(rawJson);
  return decoded.map((e) => Customer.fromMap(e)).toList();
}

String _encodeCustomersIsolate(List<Map<String, dynamic>> rawMaps) {
  return jsonEncode(rawMaps);
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
  String km;
  String warrantyNote;
  String paymentMethod;
  int discount;
  int paidAmount;
  List<LaborItem> labors;
  List<PartItem> parts;

  ServiceRecord({
    required this.id,
    required this.date,
    this.km = '',
    this.warrantyNote = '',
    this.paymentMethod = 'کارت‌خوان (POS)',
    this.discount = 0,
    this.paidAmount = 0,
    required this.labors,
    required this.parts,
  });

  int get laborTotal => labors.fold(0, (sum, i) => sum + i.cost);
  int get partsTotal => parts.fold(0, (sum, i) => sum + i.price);
  int get subTotal => laborTotal + partsTotal;
  int get grandTotal => (subTotal - discount) > 0 ? (subTotal - discount) : 0;
  int get remainingDebt => (grandTotal - paidAmount) > 0 ? (grandTotal - paidAmount) : 0;

  String get summaryTitle =>
      labors.isNotEmpty ? labors.map((l) => l.title).join(' ، ') : 'خدمات عمومی برق خودرو';

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date,
        'km': km,
        'warrantyNote': warrantyNote,
        'paymentMethod': paymentMethod,
        'discount': discount,
        'paidAmount': paidAmount,
        'labors': labors.map((l) => l.toMap()).toList(),
        'parts': parts.map((p) => p.toMap()).toList(),
      };

  factory ServiceRecord.fromMap(Map<String, dynamic> map) {
    List<LaborItem> parsedLabors = [];
    if (map['labors'] != null) {
      parsedLabors = (map['labors'] as List).map((l) => LaborItem.fromMap(l)).toList();
    } else if (map['title'] != null) {
      parsedLabors = [LaborItem(title: map['title'], cost: map['laborCost'] ?? 0)];
    }

    final rawGrand = (map['parts'] as List? ?? []).fold(0, (sum, p) => sum + (p['price'] as int? ?? 0)) +
        parsedLabors.fold(0, (sum, l) => sum + l.cost);

    return ServiceRecord(
      id: map['id'] ?? '',
      date: map['date'] ?? JalaliHelper.nowShamsi(),
      km: map['km'] ?? '',
      warrantyNote: map['warrantyNote'] ?? '',
      paymentMethod: map['paymentMethod'] ?? 'کارت‌خوان (POS)',
      discount: map['discount'] ?? 0,
      paidAmount: map['paidAmount'] ?? rawGrand,
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

  bool matchesPlate(String otherTwo, String otherLetter, String otherThree, String otherProv) {
    final t1 = NumberHelper.cleanNumbers(plateTwoDigits);
    final t2 = NumberHelper.cleanNumbers(otherTwo);
    final l1 = plateLetter.trim();
    final l2 = otherLetter.trim();
    final th1 = NumberHelper.cleanNumbers(plateThreeDigits);
    final th2 = NumberHelper.cleanNumbers(otherThree);
    final p1 = NumberHelper.cleanNumbers(plateProvinceCode);
    final p2 = NumberHelper.cleanNumbers(otherProv);

    if (t1.isEmpty || th1.isEmpty || t2.isEmpty || th2.isEmpty) return false;
    if (t1 != t2 || l1 != l2 || th1 != th2) return false;
    if (p1.isNotEmpty && p2.isNotEmpty) return p1 == p2;
    return true;
  }

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
        plateLetter: map['letter'] ?? 'ب',
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

  // فیلد ایندکس شده جهت سرچ آنی بدون افت فریم در ۳۰۰۰ رکورد
  late String searchKey;

  Customer({required this.id, required this.name, required this.phone, required this.cars}) {
    updateSearchKey();
  }

  void updateSearchKey() {
    final carsStr = cars.map((c) => '${c.model} ${c.fullPlate} ${c.plateTwoDigits}${c.plateLetter}${c.plateThreeDigits}').join(' ');
    searchKey = '${name.toLowerCase()} ${phone.replaceAll(' ', '')} $carsStr'.toLowerCase();
  }

  int get totalDebt => cars.fold(0, (sum, c) => sum + c.services.fold(0, (s, srv) => s + srv.remainingDebt));

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

// ======================== بدنه برنامه و تم گرافیکی ========================
class AutoElectricApp extends StatelessWidget {
  const AutoElectricApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'کلینیک برق خودرو مهندس',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0F1D),
        primaryColor: const Color(0xFF0284C7),
        cardColor: const Color(0xFF131D31),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Colors.amberAccent,
          surface: Color(0xFF131D31),
        ),
        // تغییر CardTheme به CardThemeData جهت سازگاری با نسخه‌های جدید فلاتر
        cardTheme: const CardThemeData(
          color: Color(0xFF131D31),
          elevation: 2,
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
    final String? raw = prefs.getString('customers_data_v9');
    if (raw != null && raw.isNotEmpty) {
      try {
        final parsed = await compute(_decodeCustomersIsolate, raw);
        setState(() {
          customers = parsed;
          _isLoading = false;
        });
        return;
      } catch (e) {
        debugPrint('Error loading: $e');
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = customers.map((c) => c.toMap()).toList();
    final encoded = await compute(_encodeCustomersIsolate, rawList);
    await prefs.setString('customers_data_v9', encoded);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.cyanAccent),
              SizedBox(height: 14),
              Text('در حال بارگذاری سریع پرونده‌ها...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    final screens = [
      HomeScreen(customers: customers, onDataChanged: _saveData),
      DebtorsScreen(customers: customers),
      DailyReportScreen(customers: customers),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white12, width: 0.8)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: const Color(0xFF0F172A),
          selectedItemColor: Colors.cyanAccent,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.engineering), label: 'میز کار مشتریان'),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'حساب دفتری (نسیه)'),
            BottomNavigationBarItem(icon: Icon(Icons.query_stats), label: 'دخل و گزارش کارگاه'),
          ],
        ),
      ),
    );
  }
}

// ======================== صفحه اصلی میز کار مشتریان ========================
class HomeScreen extends StatefulWidget {
  final List<Customer> customers;
  final VoidCallback onDataChanged;

  const HomeScreen({super.key, required this.customers, required this.onDataChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<Customer> _filteredList = [];

  @override
  void initState() {
    super.initState();
    _filteredList = widget.customers;
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applyFilter(searchQuery);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      _applyFilter(query);
    });
  }

  void _applyFilter(String q) {
    final cleanQ = q.trim().toLowerCase();
    setState(() {
      searchQuery = cleanQ;
      if (cleanQ.isEmpty) {
        _filteredList = widget.customers;
      } else {
        _filteredList = widget.customers.where((c) => c.searchKey.contains(cleanQ)).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final int totalCars = widget.customers.fold(0, (sum, c) => sum + c.cars.length);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, color: Colors.amberAccent, size: 26),
            SizedBox(width: 6),
            Text('کلینیک برق خودرو مهندس', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0F172A),
        actions: [
          IconButton(
            icon: const Icon(Icons.campaign, color: Colors.amberAccent, size: 26),
            tooltip: 'پیامک گروهی و خروجی',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => BulkSmsScreen(customers: widget.customers)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud_sync, color: Colors.cyanAccent),
            tooltip: 'پشتیبان‌گیری در فایل و بازیابی',
            onPressed: () => _openSmartBackupDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // نوار آمار بالای صفحه
          Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF0284C7).withOpacity(0.35), const Color(0xFF131D31)],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.groups, color: Colors.cyanAccent, size: 22),
                    const SizedBox(width: 8),
                    Text('مشتریان: ${widget.customers.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                Container(height: 18, width: 1, color: Colors.white24),
                Row(
                  children: [
                    const Icon(Icons.directions_car, color: Colors.amberAccent, size: 20),
                    const SizedBox(width: 8),
                    Text('خودروها: $totalCars', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[800],
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.sms, size: 14, color: Colors.white),
                  label: const Text('پیامک', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (ctx) => BulkSmsScreen(customers: widget.customers)),
                    );
                  },
                )
              ],
            ),
          ),

          // فیلد سرچ هوشمند و سریع
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'جستجوی آنی (نام، شماره، مدل خودرو یا پلاک)...',
                hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () {
                          _searchCtrl.clear();
                          _applyFilter('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF131D31),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),

          // لیست بدون لگ پرونده‌ها با ListView.builder
          Expanded(
            child: _filteredList.isEmpty
                ? const Center(child: Text('پرونده‌ای یافت نشد.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _filteredList.length,
                    itemBuilder: (context, i) => _buildCustomerCard(_filteredList[i]),
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
    final bool hasDebt = customer.totalDebt > 0;
    return Card(
      key: ValueKey(customer.id),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        key: PageStorageKey('cust_${customer.id}'),
        leading: CircleAvatar(
          backgroundColor: hasDebt ? Colors.redAccent.withOpacity(0.85) : const Color(0xFF0284C7),
          child: Icon(hasDebt ? Icons.priority_high : Icons.person, color: Colors.white),
        ),
        title: Row(
          children: [
            Expanded(child: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            if (hasDebt)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(color: Colors.red[900], borderRadius: BorderRadius.circular(6)),
                child: Text('بدهکار: ${formatToman(customer.totalDebt)}', style: const TextStyle(fontSize: 10, color: Colors.white)),
              ),
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
        subtitle: Text('📞 ${customer.phone.isNotEmpty ? customer.phone : 'بدون شماره'}  |  🚗 ${customer.cars.length} خودرو',
            style: const TextStyle(fontSize: 12, color: Colors.white60)),
        children: [
          ...customer.cars.map((car) => _buildCarRow(customer, car)),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), side: const BorderSide(color: Colors.cyanAccent)),
              icon: const Icon(Icons.add_circle_outline, color: Colors.cyanAccent, size: 18),
              label: const Text('ثبت خودروی دیگر برای این مشتری', style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
              onPressed: () => _openCarDialog(customer: customer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarRow(Customer customer, Car car) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1D),
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
                        style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 16, color: Colors.white60),
                      onPressed: () => _openCarDialog(customer: customer, carToEdit: car),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_forever, size: 16, color: Colors.redAccent),
                      onPressed: () => _confirmDeleteCar(customer, car),
                    ),
                  ],
                ),
              ),
              RealisticPlateBadge(car: car),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${car.services.length} فاکتور ثبت شده', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                icon: const Icon(Icons.receipt_long, size: 15, color: Colors.white),
                label: const Text('فاکتورها و سوابق', style: TextStyle(color: Colors.white, fontSize: 11)),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => CarServicesScreen(
                        customer: customer,
                        car: car,
                        onChanged: () {
                          customer.updateSearchKey();
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

  void _openCustomerDialog({Customer? customer}) {
    showDialog(
      context: context,
      builder: (ctx) => _CustomerEditDialog(
        customer: customer,
        existingCustomers: widget.customers,
        onSave: (name, phone) {
          setState(() {
            if (customer == null) {
              final newCust = Customer(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
                phone: phone,
                cars: [],
              );
              widget.customers.insert(0, newCust);
            } else {
              customer.name = name;
              customer.phone = phone;
              customer.updateSearchKey();
            }
          });
          _applyFilter(searchQuery);
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
        content: Text('آیا از حذف پرونده "${customer.name}" و تمام سوابق فاکتورهای آن اطمینان دارید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              setState(() => widget.customers.removeWhere((c) => c.id == customer.id));
              _applyFilter(searchQuery);
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
        customer: customer,
        existingCustomers: widget.customers,
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
            customer.updateSearchKey();
          });
          _applyFilter(searchQuery);
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
              setState(() => customer.cars.removeWhere((c) => c.id == car.id));
              customer.updateSearchKey();
              _applyFilter(searchQuery);
              widget.onDataChanged();
              Navigator.pop(ctx);
            },
            child: const Text('حذف'),
          )
        ],
      ),
    );
  }

  // دیالوگ هوشمند پشتیبان‌گیری در قالب فایل واقعی
  void _openSmartBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.save_as, color: Colors.cyanAccent),
            SizedBox(width: 8),
            Text('پشتیبان‌گیری و بازیابی فایل'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('پشتیبان‌گیری در این نسخه به شکل یک فایل اختصاصی JSON ذخیره و به اشتراک گذاشته می‌شود.',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), minimumSize: const Size.fromHeight(45)),
              icon: const Icon(Icons.share, color: Colors.white),
              label: const Text('اشتراک و ذخیره فایل پشتیبان (.json)', style: TextStyle(color: Colors.white, fontSize: 13)),
              onPressed: () async {
                Navigator.pop(ctx);
                _exportBackupAsFile(context);
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800], minimumSize: const Size.fromHeight(45)),
              icon: const Icon(Icons.file_upload, color: Colors.white),
              label: const Text('بازیابی اطلاعات از متن یا فایل قبلی', style: TextStyle(color: Colors.white, fontSize: 13)),
              onPressed: () {
                Navigator.pop(ctx);
                _openRestoreDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // خروجی فایل واقعی از طریق سامانه اشتراک امن نیتیو
  Future<void> _exportBackupAsFile(BuildContext context) async {
    try {
      final rawList = widget.customers.map((c) => c.toMap()).toList();
      final jsonString = await compute(_encodeCustomersIsolate, rawList);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));
      final shamsiDate = JalaliHelper.nowShamsi().replaceAll('/', '_');
      final fileName = 'پشتیبان_برق_خودرو_$shamsiDate.json';

      // باز کردن دیالوگ ذخیره در فایل یا اشتراک مستقیم در واتساپ، تلگرام یا درایو
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا در ایجاد فایل پشتیبان: $e')));
      }
    }
  }

  void _openRestoreDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بازیابی فایل پشتیبان'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('محتوای فایل پشتیبان JSON را در کادر زیر قرار دهید:', style: TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 8),
            TextField(
              controller: codeCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'کدهای متنی فایل پشتیبان را Paste کنید...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () async {
              try {
                final text = codeCtrl.text.trim();
                final parsed = await compute(_decodeCustomersIsolate, text);
                setState(() {
                  widget.customers.clear();
                  widget.customers.addAll(parsed);
                });
                _applyFilter(searchQuery);
                widget.onDataChanged();
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${parsed.length} پرونده با موفقیت بازیابی شد!')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فایل یا کد پشتیبان نامعتبر است!')));
                }
              }
            },
            child: const Text('اعمال بازیابی'),
          )
        ],
      ),
    );
  }
}

// ======================== ویجت نمایش گرافیکی پلاک واقعی ========================
class RealisticPlateBadge extends StatelessWidget {
  final Car car;

  const RealisticPlateBadge({super.key, required this.car});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.black87, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // نشان پرچم و I.R. IRAN
            Container(
              width: 14,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFF003399),
                borderRadius: BorderRadius.circular(2),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🇮🇷', style: TextStyle(fontSize: 6)),
                  Text('IR', style: TextStyle(color: Colors.white, fontSize: 5, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Text(car.plateTwoDigits, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 3),
            Text(car.plateLetter, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(width: 3),
            Text(car.plateThreeDigits, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
            Container(height: 20, width: 1, color: Colors.black38, margin: const EdgeInsets.symmetric(horizontal: 4)),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('ایران', style: TextStyle(color: Colors.black, fontSize: 7, height: 1)),
                Text(car.plateProvinceCode, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10, height: 1)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ======================== دیالوگ ثبت خودرو با پلاک کاملاً استاندارد ========================
class _CarEditDialog extends StatefulWidget {
  final Car? carToEdit;
  final Customer customer;
  final List<Customer> existingCustomers;
  final Function(String model, String two, String letter, String three, String prov) onSave;

  const _CarEditDialog({
    this.carToEdit,
    required this.customer,
    required this.existingCustomers,
    required this.onSave,
  });

  @override
  State<_CarEditDialog> createState() => _CarEditDialogState();
}

class _CarEditDialogState extends State<_CarEditDialog> {
  late final TextEditingController modelCtrl;
  late final TextEditingController twoCtrl;
  late final TextEditingController threeCtrl;
  late final TextEditingController provCtrl;
  late String selectedLetter;

  final FocusNode twoFocus = FocusNode();
  final FocusNode threeFocus = FocusNode();
  final FocusNode provFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    modelCtrl = TextEditingController(text: widget.carToEdit?.model ?? '');
    twoCtrl = TextEditingController(text: widget.carToEdit?.plateTwoDigits ?? '');
    selectedLetter = widget.carToEdit?.plateLetter ?? 'ب';
    threeCtrl = TextEditingController(text: widget.carToEdit?.plateThreeDigits ?? '');
    provCtrl = TextEditingController(text: widget.carToEdit?.plateProvinceCode ?? '');

    if (!kIranPlateLetters.contains(selectedLetter)) {
      selectedLetter = 'ب';
    }
  }

  @override
  void dispose() {
    modelCtrl.dispose();
    twoCtrl.dispose();
    threeCtrl.dispose();
    provCtrl.dispose();
    twoFocus.dispose();
    threeFocus.dispose();
    provFocus.dispose();
    super.dispose();
  }

  void _handleSave() {
    final model = modelCtrl.text.trim();
    final two = NumberHelper.cleanNumbers(twoCtrl.text);
    final letter = selectedLetter.trim();
    final three = NumberHelper.cleanNumbers(threeCtrl.text);
    final prov = NumberHelper.cleanNumbers(provCtrl.text);

    if (model.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لطفاً مدل خودرو را وارد کنید.')));
      return;
    }

    // اعتبارسنجی تکراری نبودن پلاک در کل سیستم
    if (two.isNotEmpty && three.isNotEmpty) {
      for (final cust in widget.existingCustomers) {
        for (final car in cust.cars) {
          if (widget.carToEdit != null && car.id == widget.carToEdit!.id) continue;
          if (car.matchesPlate(two, letter, three, prov)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('این پلاک قبلاً برای پرونده «${cust.name}» ثبت شده است!'),
                backgroundColor: Colors.redAccent,
              ),
            );
            return;
          }
        }
      }
    }

    widget.onSave(model, two, letter, three, prov);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.carToEdit == null ? 'افزودن خودرو' : 'ویرایش خودرو'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: modelCtrl,
              decoration: const InputDecoration(
                labelText: 'مدل خودرو (مثلاً: پژو ۲۰۶ سفید)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),

            // پیشنهاد سریع مدل خودرو
            const Text('انتخاب سریع خودرو:', style: TextStyle(fontSize: 11, color: Colors.white70)),
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: kPopularCars.take(8).map((carName) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 6.0),
                    child: ActionChip(
                      label: Text(carName, style: const TextStyle(fontSize: 11)),
                      onPressed: () => setState(() => modelCtrl.text = carName),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            const Text('شماره پلاک ملی خودرو:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
            const SizedBox(height: 6),

            // پلاک هوشمند با محدودیت ۲ رقم، ۳ رقم، و کد استان با پرش خودکار
            Directionality(
              textDirection: TextDirection.ltr,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amberAccent, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22,
                      height: 48,
                      decoration: BoxDecoration(color: const Color(0xFF003399), borderRadius: BorderRadius.circular(4)),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('🇮🇷', style: TextStyle(fontSize: 8)),
                          Text('I.R.', style: TextStyle(color: Colors.white, fontSize: 6, fontWeight: FontWeight.bold)),
                          Text('IRAN', style: TextStyle(color: Colors.white, fontSize: 5)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),

                    // ۲ رقم اول (محدود به دقیقاً ۲ رقم با پرش خودکار به ۳ رقم)
                    SizedBox(
                      width: 44,
                      child: TextField(
                        controller: twoCtrl,
                        focusNode: twoFocus,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 2,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17),
                        decoration: const InputDecoration(counterText: '', hintText: '۲۲', border: InputBorder.none),
                        onChanged: (val) {
                          if (val.length == 2) FocusScope.of(context).requestFocus(threeFocus);
                        },
                      ),
                    ),

                    // لیست کشویی حروف استاندارد پلاک
                    DropdownButton<String>(
                      value: selectedLetter,
                      dropdownColor: const Color(0xFF1E293B),
                      underline: const SizedBox(),
                      style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 17),
                      items: kIranPlateLetters.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                      onChanged: (v) => setState(() => selectedLetter = v ?? 'ب'),
                    ),

                    // ۳ رقم پلاک (محدود به دقیقاً ۳ رقم با پرش به کد استان)
                    SizedBox(
                      width: 58,
                      child: TextField(
                        controller: threeCtrl,
                        focusNode: threeFocus,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 3,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17),
                        decoration: const InputDecoration(counterText: '', hintText: '۳۶۵', border: InputBorder.none),
                        onChanged: (val) {
                          if (val.length == 3) FocusScope.of(context).requestFocus(provFocus);
                        },
                      ),
                    ),

                    Container(height: 38, width: 1.5, color: Colors.black45, margin: const EdgeInsets.symmetric(horizontal: 4)),

                    // کد ۲ رقمی ایران (استان)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('ایران', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold, height: 1)),
                        SizedBox(
                          width: 38,
                          height: 32,
                          child: TextField(
                            controller: provCtrl,
                            focusNode: provFocus,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 2,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
                            decoration: const InputDecoration(counterText: '', hintText: '۶۸', border: InputBorder.none, isDense: true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
        ElevatedButton(onPressed: _handleSave, child: const Text('ذخیره')),
      ],
    );
  }
}

// ======================== دیالوگ ثبت و ویرایش مشتری ========================
class _CustomerEditDialog extends StatefulWidget {
  final Customer? customer;
  final List<Customer> existingCustomers;
  final Function(String name, String phone) onSave;

  const _CustomerEditDialog({this.customer, required this.existingCustomers, required this.onSave});

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

  void _handleSave() {
    final name = nameCtrl.text.trim();
    final rawPhone = phoneCtrl.text.trim();
    final cleanPhone = NumberHelper.cleanNumbers(rawPhone);
    final normPhone = NumberHelper.normalizePhone(rawPhone);

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لطفاً نام مشتری را وارد کنید.')));
      return;
    }

    if (normPhone.isNotEmpty) {
      for (final c in widget.existingCustomers) {
        if (widget.customer != null && c.id == widget.customer!.id) continue;
        if (NumberHelper.normalizePhone(c.phone) == normPhone) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('این شماره قبلاً برای پرونده «${c.name}» ثبت شده است!'),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }
      }
    }

    widget.onSave(name, cleanPhone);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.customer == null ? 'ثبت مشتری جدید' : 'ویرایش مشتری'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'نام و نام خانوادگی')),
          const SizedBox(height: 8),
          TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'شماره همراه')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
        ElevatedButton(onPressed: _handleSave, child: const Text('ذخیره')),
      ],
    );
  }
}

// ======================== صفحه سوابق فاکتورهای خودرو ========================
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
        backgroundColor: const Color(0xFF0F172A),
      ),
      body: widget.car.services.isEmpty
          ? const Center(child: Text('هنوز فاکتوری برای این خودرو ثبت نشده است.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: widget.car.services.length,
              itemBuilder: (context, i) {
                final s = widget.car.services[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('📅 تاریخ: ${s.date}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amberAccent)),
                                if (s.km.isNotEmpty)
                                  Text('🚗 کارکرد: ${s.km} km', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18, color: Colors.cyanAccent),
                                  onPressed: () => _openServiceDialog(serviceToEdit: s),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                  onPressed: () => _confirmDeleteService(s),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (s.warrantyNote.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.3), borderRadius: BorderRadius.circular(6)),
                            child: Text('🛡 گارانتی: ${s.warrantyNote}', style: const TextStyle(fontSize: 11, color: Colors.cyanAccent)),
                          ),
                        ],
                        const Divider(height: 16),
                        ...s.labors.map((l) => Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('• ${l.title}', style: const TextStyle(fontSize: 12)),
                                Text(formatToman(l.cost), style: const TextStyle(fontSize: 12, color: Colors.white70)),
                              ],
                            )),
                        ...s.parts.map((p) => Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('• قطعه: ${p.name}', style: const TextStyle(fontSize: 12, color: Colors.amberAccent)),
                                Text(formatToman(p.price), style: const TextStyle(fontSize: 12, color: Colors.white70)),
                              ],
                            )),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('جمع کل نهایی:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(formatToman(s.grandTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.greenAccent)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('پرداخت شده (${s.paymentMethod}):', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                            Text(formatToman(s.paidAmount), style: const TextStyle(fontSize: 12, color: Colors.cyanAccent)),
                          ],
                        ),
                        if (s.remainingDebt > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.red[900]?.withOpacity(0.4), borderRadius: BorderRadius.circular(6)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('مانده بدهی (نسیه):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
                                Text(formatToman(s.remainingDebt), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 13)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800]),
                              icon: const Icon(Icons.sms, size: 14, color: Colors.white),
                              label: const Text('پیامک تحویل', style: TextStyle(color: Colors.white, fontSize: 11)),
                              onPressed: () => _sendSmsNotification(s),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[800]),
                              icon: const Icon(Icons.receipt, size: 14, color: Colors.white),
                              label: const Text('فیش حرارتی', style: TextStyle(color: Colors.white, fontSize: 11)),
                              onPressed: () => _printPdfInvoice(s, isThermal: true),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                              icon: const Icon(Icons.print, size: 14, color: Colors.white),
                              label: const Text('فاکتور A4', style: TextStyle(color: Colors.white, fontSize: 11)),
                              onPressed: () => _printPdfInvoice(s, isThermal: false),
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
              setState(() => widget.car.services.removeWhere((item) => item.id == s.id));
              widget.onChanged();
              Navigator.pop(ctx);
            },
            child: const Text('حذف'),
          )
        ],
      ),
    );
  }

  Future<void> _sendSmsNotification(ServiceRecord s) async {
    final cleanPhone = NumberHelper.cleanNumbers(widget.customer.phone);
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('شماره همراه مشتری ثبت نشده است!')));
      return;
    }
    final msg = 'مشتری گرامی ${widget.customer.name}\n'
        'خودروی ${widget.car.model} (${widget.car.fullPlate}) آماده تحویل است.\n'
        'مبلغ کل: ${formatToman(s.grandTotal)}\n'
        '⚡ کلینیک برق خودرو مهندس';

    final encoded = Uri.encodeComponent(msg);
    final uri = Uri.parse('sms:$cleanPhone?body=$encoded');
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (_) {}
  }

  Future<void> _printPdfInvoice(ServiceRecord service, {required bool isThermal}) async {
    try {
      final pdf = pw.Document();
      final pageFormat = isThermal ? PdfPageFormat.roll80 : PdfPageFormat.a4;

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          textDirection: pw.TextDirection.rtl,
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Center(child: pw.Text('کلینیک برق خودرو مهندس', style: pw.TextStyle(fontSize: isThermal ? 13 : 18, fontWeight: pw.FontWeight.bold))),
                  pw.Divider(),
                  pw.Text('مشتری: ${widget.customer.name}  |  تلفن: ${widget.customer.phone}', style: pw.TextStyle(fontSize: isThermal ? 8 : 10)),
                  pw.Text('خودرو: ${widget.car.model}  |  پلاک: ${widget.car.fullPlate}', style: pw.TextStyle(fontSize: isThermal ? 8 : 10)),
                  pw.Text('تاریخ: ${service.date}', style: pw.TextStyle(fontSize: isThermal ? 8 : 10)),
                  pw.Divider(),
                  ...service.labors.map((l) => pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(l.title, style: pw.TextStyle(fontSize: isThermal ? 8 : 10)),
                          pw.Text(formatToman(l.cost), style: pw.TextStyle(fontSize: isThermal ? 8 : 10)),
                        ],
                      )),
                  pw.Divider(),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('مبلغ نهایی:', style: pw.TextStyle(fontSize: isThermal ? 9 : 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text(formatToman(service.grandTotal), style: pw.TextStyle(fontSize: isThermal ? 9 : 11, fontWeight: pw.FontWeight.bold)),
                  ]),
                ],
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا در صدور PDF: $e')));
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
              serviceToEdit.km = record.km;
              serviceToEdit.warrantyNote = record.warrantyNote;
              serviceToEdit.paymentMethod = record.paymentMethod;
              serviceToEdit.discount = record.discount;
              serviceToEdit.paidAmount = record.paidAmount;
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

// ======================== دیالوگ فاکتور با چیپ‌های انتخاب سریع اجرت ========================
class _ServiceEditDialog extends StatefulWidget {
  final ServiceRecord? serviceToEdit;
  final Function(ServiceRecord) onSave;

  const _ServiceEditDialog({this.serviceToEdit, required this.onSave});

  @override
  State<_ServiceEditDialog> createState() => _ServiceEditDialogState();
}

class _ServiceEditDialogState extends State<_ServiceEditDialog> {
  late final TextEditingController dateCtrl;
  late final TextEditingController kmCtrl;
  late final TextEditingController warrantyCtrl;
  late final TextEditingController discountCtrl;
  late final TextEditingController paidCtrl;
  String paymentMethod = 'کارت‌خوان (POS)';
  late final List<LaborItem> laborsList;
  late final List<PartItem> partsList;

  @override
  void initState() {
    super.initState();
    final s = widget.serviceToEdit;
    dateCtrl = TextEditingController(text: s?.date ?? JalaliHelper.nowShamsi());
    kmCtrl = TextEditingController(text: s?.km ?? '');
    warrantyCtrl = TextEditingController(text: s?.warrantyNote ?? '');
    discountCtrl = TextEditingController(text: s != null && s.discount > 0 ? s.discount.toString() : '');
    paidCtrl = TextEditingController(text: s != null ? s.paidAmount.toString() : '');
    paymentMethod = s?.paymentMethod ?? 'کارت‌خوان (POS)';
    laborsList = s != null ? s.labors.map((l) => LaborItem(title: l.title, cost: l.cost)).toList() : [];
    partsList = s != null ? s.parts.map((p) => PartItem(name: p.name, price: p.price)).toList() : [];
  }

  @override
  void dispose() {
    dateCtrl.dispose();
    kmCtrl.dispose();
    warrantyCtrl.dispose();
    discountCtrl.dispose();
    paidCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int subTotal = laborsList.fold(0, (sum, i) => sum + i.cost) + partsList.fold(0, (sum, i) => sum + i.price);
    int discount = NumberHelper.safeParseInt(discountCtrl.text);
    int grandTotal = (subTotal - discount) > 0 ? (subTotal - discount) : 0;

    return AlertDialog(
      title: Text(widget.serviceToEdit == null ? 'ثبت فاکتور جدید' : 'ویرایش فاکتور'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'تاریخ فاکتور'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: kmCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'کیلومتر ماشین'))),
                ],
              ),
              TextField(controller: warrantyCtrl, decoration: const InputDecoration(labelText: 'یادداشت/گارانتی قطعه')),
              const SizedBox(height: 10),

              // انتخاب سریع اجرت‌های پرکاربرد برق خودرو با چیپس
              const Text('خدمات پرکاربرد برق خودرو (کلیک برای افزودن):', style: TextStyle(fontSize: 11, color: Colors.cyanAccent)),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: kQuickLabors.map((ql) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 6.0),
                      child: ActionChip(
                        backgroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Colors.white24),
                        label: Text('${ql['title']}', style: const TextStyle(fontSize: 11)),
                        onPressed: () {
                          setState(() {
                            laborsList.add(LaborItem(title: ql['title'], cost: ql['cost']));
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),

              // بخش اجرت‌ها
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF0A0F1D), borderRadius: BorderRadius.circular(10)),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('🔧 لیست خدمات:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent, fontSize: 13)),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('دستی', style: TextStyle(fontSize: 10)),
                          onPressed: () => _openAddItemDialog(isLabor: true),
                        ),
                      ],
                    ),
                    ...laborsList.asMap().entries.map((e) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('• ${e.value.title}: ${formatToman(e.value.cost)}', style: const TextStyle(fontSize: 12)),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                              onPressed: () => setState(() => laborsList.removeAt(e.key)),
                            )
                          ],
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // بخش قطعات
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF0A0F1D), borderRadius: BorderRadius.circular(10)),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('🔩 قطعات و لوازم:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent, fontSize: 13)),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800]),
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('افزودن قطعه', style: TextStyle(fontSize: 10)),
                          onPressed: () => _openAddItemDialog(isLabor: false),
                        ),
                      ],
                    ),
                    ...partsList.asMap().entries.map((e) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('• ${e.value.name}: ${formatToman(e.value.price)}', style: const TextStyle(fontSize: 12)),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                              onPressed: () => setState(() => partsList.removeAt(e.key)),
                            )
                          ],
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: discountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'تخفیف (تومان)'),
                onChanged: (_) => setState(() {}),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: paidCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'مبلغ دریافتی'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: paymentMethod,
                    items: ['کارت‌خوان (POS)', 'نقد', 'کارت‌به‌کارت'].map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) => setState(() => paymentMethod = v!),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('جمع نهایی قابل پرداخت:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(formatToman(grandTotal), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent, fontSize: 14)),
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
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حداقل یک خدمت یا قطعه ثبت کنید.')));
              return;
            }
            final enteredPaid = NumberHelper.safeParseInt(paidCtrl.text);
            final record = ServiceRecord(
              id: widget.serviceToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
              date: dateCtrl.text.isNotEmpty ? dateCtrl.text.trim() : JalaliHelper.nowShamsi(),
              km: kmCtrl.text.trim(),
              warrantyNote: warrantyCtrl.text.trim(),
              paymentMethod: paymentMethod,
              discount: discount,
              paidAmount: paidCtrl.text.isEmpty ? grandTotal : enteredPaid,
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

  void _openAddItemDialog({required bool isLabor}) {
    final titleCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isLabor ? 'افزودن خدمت و اجرت' : 'افزودن قطعه مصرفی'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: InputDecoration(labelText: isLabor ? 'شرح کار' : 'نام قطعه')),
            TextField(controller: costCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مبلغ (تومان)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isNotEmpty) {
                final price = NumberHelper.safeParseInt(costCtrl.text);
                setState(() {
                  if (isLabor) {
                    laborsList.add(LaborItem(title: titleCtrl.text.trim(), cost: price));
                  } else {
                    partsList.add(PartItem(name: titleCtrl.text.trim(), price: price));
                  }
                });
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

// ======================== تب حساب دفتری و لیست بدهکاران ========================
class DebtorsScreen extends StatelessWidget {
  final List<Customer> customers;

  const DebtorsScreen({super.key, required this.customers});

  @override
  Widget build(BuildContext context) {
    final debtors = customers.where((c) => c.totalDebt > 0).toList();
    final int totalShopDebt = debtors.fold(0, (sum, c) => sum + c.totalDebt);

    return Scaffold(
      appBar: AppBar(title: const Text('📋 حساب دفتری و لیست نسیه‌ها'), backgroundColor: const Color(0xFF0F172A)),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[900]?.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('کل طلب شما از مشتریان:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(formatToman(totalShopDebt), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.redAccent)),
                  ],
                ),
                Text('${debtors.length} نفر بدهکار', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: debtors.isEmpty
                ? const Center(child: Text('هیچ بدهی و نسیه ثبت‌شده‌ای ندارید! 🎉', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: debtors.length,
                    itemBuilder: (context, i) {
                      final c = debtors[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: const CircleAvatar(backgroundColor: Colors.redAccent, child: Icon(Icons.money_off, color: Colors.white)),
                          title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('📞 ${c.phone}\nمانده بدهی: ${formatToman(c.totalDebt)}', style: const TextStyle(color: Colors.redAccent)),
                          trailing: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800]),
                            icon: const Icon(Icons.sms, size: 16, color: Colors.white),
                            label: const Text('یادآوری', style: TextStyle(color: Colors.white, fontSize: 12)),
                            onPressed: () => _sendDebtReminderSms(c, context),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendDebtReminderSms(Customer c, BuildContext context) async {
    final cleanPhone = NumberHelper.cleanNumbers(c.phone);
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('شماره همراه مشتری ثبت نشده است!')));
      return;
    }
    final msg = 'مشتری گرامی ${c.name}\n'
        'با سلام، احتراما مانده حساب شما در کلینیک برق خودرو مهندس مبلغ ${formatToman(c.totalDebt)} می‌باشد.\n'
        'با تشکر - برق خودرو مهندس';

    final encoded = Uri.encodeComponent(msg);
    final uri = Uri.parse('sms:$cleanPhone?body=$encoded');
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (_) {}
  }
}

// ======================== باشگاه مشتریان و اکسل ========================
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
    _msgCtrl.text = 'مشتری گرامی کلینیک برق خودرو مهندس،\nخدمات تخصصی برق، باتری، دینام و استارت خودرو با ضمانت.\nتلفن: [شماره تماس]';
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
      if (p.isNotEmpty && p.length >= 10) phones.add(p);
    }
    return phones.toList();
  }

  @override
  Widget build(BuildContext context) {
    final phones = _getValidPhones();

    return Scaffold(
      appBar: AppBar(title: const Text('📢 باشگاه مشتریان و خروجی اکسل'), backgroundColor: const Color(0xFF0F172A)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF0284C7).withOpacity(0.2), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.cyanAccent)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${phones.length} شماره تماس ثبت شده', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.greenAccent)),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800]),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('کپی شماره‌ها', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: phones.join(', ')));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('شماره‌ها کپی شدند.')));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _msgCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'متن پیامک گروهی',
                filled: true,
                fillColor: const Color(0xFF131D31),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.send, color: Colors.white),
              label: const Text('ارسال پیامک دسته‌جمعی', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                if (phones.isEmpty) return;
                final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
                final separator = isIos ? ';' : ',';
                final phoneList = phones.take(20).join(separator);
                final encoded = Uri.encodeComponent(_msgCtrl.text);
                final uri = Uri.parse('sms:$phoneList?body=$encoded');
                try {
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                } catch (_) {}
              },
            ),
          ],
        ),
      ),
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
        title: const Text('📊 دخل و گزارش مالی کارگاه'),
        backgroundColor: const Color(0xFF0F172A),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          tabs: const [Tab(text: 'گزارش روزانه'), Tab(text: 'گزارش ماهانه')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildReportView(isMonthly: false), _buildReportView(isMonthly: true)],
      ),
    );
  }

  Widget _buildReportView({required bool isMonthly}) {
    List<Map<String, dynamic>> servicesList = [];
    int totalLabor = 0;
    int totalParts = 0;
    int totalPos = 0;
    int totalCash = 0;

    final target = isMonthly ? selectedMonth : selectedDay;

    for (var cust in widget.customers) {
      for (var car in cust.cars) {
        for (var s in car.services) {
          final isMatch = isMonthly ? s.date.startsWith(target) : (s.date == target);
          if (isMatch) {
            totalLabor += s.laborTotal;
            totalParts += s.partsTotal;
            if (s.paymentMethod.contains('POS') || s.paymentMethod.contains('کارت‌خوان')) {
              totalPos += s.paidAmount;
            } else {
              totalCash += s.paidAmount;
            }
            servicesList.add({'customer': cust.name, 'car': car.model, 'service': s});
          }
        }
      }
    }

    final totalIncome = totalLabor + totalParts;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isMonthly ? 'ماه: $target' : 'تاریخ: $target', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amberAccent)),
              IconButton(
                icon: const Icon(Icons.edit_calendar, color: Colors.cyanAccent),
                onPressed: () {
                  final ctrl = TextEditingController(text: target);
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(isMonthly ? 'تغییر ماه (مثلاً 1405/08)' : 'تغییر تاریخ (مثلاً 1405/08/18)'),
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
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF0284C7).withOpacity(0.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.cyanAccent)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text('💰 دستمزد و سود خالص (اجرت‌ها)', style: TextStyle(fontSize: 14, color: Colors.white70)),
                  const SizedBox(height: 6),
                  Text(formatToman(totalLabor), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(children: [const Text('فروش قطعات', style: TextStyle(fontSize: 11, color: Colors.grey)), Text(formatToman(totalParts), style: const TextStyle(fontWeight: FontWeight.bold))]),
                      Column(children: [const Text('کل دخل ناخالص', style: TextStyle(fontSize: 11, color: Colors.grey)), Text(formatToman(totalIncome), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent))]),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text('💳 پوز: ${formatToman(totalPos)}', style: const TextStyle(fontSize: 12, color: Colors.cyanAccent)),
                      Text('💵 نقد/کارت: ${formatToman(totalCash)}', style: const TextStyle(fontSize: 12, color: Colors.amberAccent)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(alignment: Alignment.centerRight, child: Text('فاکتورهای ثبت شده (${servicesList.length}):', style: const TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(height: 8),
          ...servicesList.map((item) {
            final s = item['service'] as ServiceRecord;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text('${item['car']} - ${item['customer']}'),
                subtitle: Text('${s.summaryTitle}\nاجرت: ${formatToman(s.laborTotal)} | پرداختی: ${formatToman(s.paidAmount)}'),
                trailing: Text(formatToman(s.grandTotal), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              ),
            );
          }),
        ],
      ),
    );
  }
}
