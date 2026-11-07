import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const AutoElectricApp());
}

// فرمت کننده قیمت به تومان (سه رقم سه رقم)
String formatToman(int amount) {
  final formatter = intl.NumberFormat('#,###');
  return '${formatter.format(amount)} تومان';
}

// ۱. مدل قطعه مصرفی یا وسیله خریداری شده
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

// ۲. مدل فاکتور و خدمات برق
class ServiceRecord {
  String id;
  String title; // شرح کار: مثل سرویس استارت، رفع اتصالی
  String date;
  int laborCost; // اجرت دستمزد به تومان
  List<PartItem> parts; // وسایل مصرفی خریداری شده
  String notes;

  ServiceRecord({
    required this.id,
    required this.title,
    required this.date,
    required this.laborCost,
    required this.parts,
    this.notes = '',
  });

  int get partsTotal => parts.fold(0, (sum, item) => sum + item.price);
  int get grandTotal => laborCost + partsTotal;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'date': date,
        'laborCost': laborCost,
        'parts': parts.map((p) => p.toMap()).toList(),
        'notes': notes,
      };

  factory ServiceRecord.fromMap(Map<String, dynamic> map) => ServiceRecord(
        id: map['id'] ?? '',
        title: map['title'] ?? '',
        date: map['date'] ?? '',
        laborCost: map['laborCost'] ?? 0,
        parts: (map['parts'] as List? ?? []).map((p) => PartItem.fromMap(p)).toList(),
        notes: map['notes'] ?? '',
      );
}

// ۳. مدل خودرو
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

// ۴. مدل مشتری
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
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Customer> customers = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('customers_data_v2');
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
    await prefs.setString('customers_data_v2', encoded);
  }

  // بخش پشتیبان‌گیری
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
                final encoded = jsonEncode(customers.map((c) => c.toMap()).toList());
                Clipboard.setData(ClipboardData(text: encoded));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('کد پشتیبان با موفقیت کپی شد! آن را در یادداشت گوشی یا تلگرام ذخیره کنید.')),
                );
              },
            ),
            const Divider(height: 30),
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
                  customers = decoded.map((e) => Customer.fromMap(e)).toList();
                });
                _saveData();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('اطلاعات با موفقیت بازیابی شدند!')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('کد پشتیبان نامعتبر است!')),
                );
              }
            },
            child: const Text('اعمال بازیابی'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = customers.where((c) {
      final matchesName = c.name.contains(searchQuery);
      final matchesPhone = c.phone.contains(searchQuery);
      final matchesPlate = c.cars.any((car) =>
          car.fullPlate.contains(searchQuery) || car.model.contains(searchQuery));
      return matchesName || matchesPhone || matchesPlate;
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
                hintText: 'جستجوی مشتری، پلاک یا مدل خودرو...',
                prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('موردی یافت نشد', style: TextStyle(color: Colors.grey)))
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.build, size: 16, color: Colors.white),
                label: const Text('سوابق و فاکتورها', style: TextStyle(color: Colors.white, fontSize: 12)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => CarServicesScreen(
                        customer: customer,
                        car: car,
                        onChanged: () {
                          setState(() {});
                          _saveData();
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
                  customers.insert(
                    0,
                    Customer(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameCtrl.text,
                      phone: phoneCtrl.text,
                      cars: [],
                    ),
                  );
                });
                _saveData();
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
              TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'مدل خودرو (مثلاً: پژو پارس)')),
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
                final index = customers.indexWhere((c) => c.id == customerId);
                if (index != -1) {
                  setState(() {
                    customers[index].cars.add(
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
                  _saveData();
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
}

// ۵. صفحه تخصصی سوابق خدمات، قیمت و قطعات خودرو
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
                            Text(s.date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                        const Divider(height: 20),
                        // لیست قطعات خریداری شده
                        if (s.parts.isNotEmpty) ...[
                          const Text('لوازم و قطعات مصرفی:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amberAccent)),
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
                        // اجرت
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('اجرت دستمزد و عیب‌یابی:', style: TextStyle(fontSize: 13)),
                            Text(formatToman(s.laborCost), style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                        const Divider(height: 16),
                        // مجموع فاکتور
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('جمع کل فاکتور:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(formatToman(s.grandTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.greenAccent)),
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
        label: const Text('ثبت خدمات و فاکتور جدید', style: TextStyle(color: Colors.white)),
        onPressed: _openAddServiceDialog,
      ),
    );
  }

  void _openAddServiceDialog() {
    final titleCtrl = TextEditingController();
    final laborCtrl = TextEditingController();
    final List<PartItem> partsList = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('ثبت خدمات و هزینه برق خودرو'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'شرح خدمات (مثلاً: تعمیر دینام و تعویض بلبرینگ)')),
                TextField(controller: laborCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'اجرت دستمزد (به تومان)')),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('قطعات مصرفی:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.cyanAccent),
                      onPressed: () {
                        _openAddPartMiniDialog((part) {
                          setDialogState(() {
                            partsList.add(part);
                          });
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
                  final now = DateTime.now();
                  final dateStr = '${now.year}/${now.month}/${now.day}';
                  final record = ServiceRecord(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleCtrl.text,
                    date: dateStr,
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
            TextField(controller: pPriceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'قیمت خرید (به تومان)')),
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
