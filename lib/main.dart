import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const AutoElectricApp());
}

// مدل خودرو
class Car {
  String model;
  String plateTwoDigits;
  String plateLetter;
  String plateThreeDigits;
  String plateProvinceCode;

  Car({
    required this.model,
    required this.plateTwoDigits,
    required this.plateLetter,
    required this.plateThreeDigits,
    required this.plateProvinceCode,
  });

  String get fullPlate => '$plateTwoDigits $plateLetter $plateThreeDigits - ایران $plateProvinceCode';

  Map<String, dynamic> toMap() => {
    'model': model,
    'two': plateTwoDigits,
    'letter': plateLetter,
    'three': plateThreeDigits,
    'prov': plateProvinceCode,
  };

  factory Car.fromMap(Map<String, dynamic> map) => Car(
    model: map['model'] ?? '',
    plateTwoDigits: map['two'] ?? '',
    plateLetter: map['letter'] ?? '',
    plateThreeDigits: map['three'] ?? '',
    plateProvinceCode: map['prov'] ?? '',
  );
}

// مدل مشتری (یک مشتری می‌تواند چند خودرو داشته باشد)
class Customer {
  String id;
  String name;
  String phone;
  List<Car> cars;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.cars,
  });

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
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF38BDF8),
          secondary: Colors.amberAccent,
          surface: const Color(0xFF1E293B),
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
    final String? raw = prefs.getString('customers_data');
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
    await prefs.setString('customers_data', encoded);
  }

  void _addCustomer(Customer customer) {
    setState(() {
      customers.insert(0, customer);
    });
    _saveData();
  }

  void _addCarToCustomer(String customerId, Car car) {
    setState(() {
      final index = customers.indexWhere((c) => c.id == customerId);
      if (index != -1) {
        customers[index].cars.add(car);
      }
    });
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = customers.where((c) {
      final matchesName = c.name.contains(searchQuery);
      final matchesPhone = c.phone.contains(searchQuery);
      final matchesPlate = c.cars.any((car) =>
          car.fullPlate.contains(searchQuery) ||
          car.model.contains(searchQuery));
      return matchesName || matchesPhone || matchesPlate;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚡ کلینیک برق خودرو', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: Column(
        children: [
          // کادر جستجوی شیک
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: (val) => setState(() => searchQuery = val),
              decoration: InputDecoration(
                hintText: 'جستجوی نام مشتری، شماره پلاک یا مدل خودرو...',
                prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // لیست مشتریان
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('مشتری یا خودرویی یافت نشد!', style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final item = filtered[i];
                      return _buildCustomerCard(item);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0284C7),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('مشتری جدید', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _openAddCustomerDialog(),
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
        subtitle: Text('📞 ${customer.phone}  |  🚗 ${customer.cars.length} خودرو ثبت‌شده'),
        children: [
          ...customer.cars.map((car) => _buildPlateWidget(car)).toList(),
          TextButton.icon(
            icon: const Icon(Icons.add_circle_outline, color: Colors.cyanAccent),
            label: const Text('افزودن خودروی دیگر برای این مشتری'),
            onPressed: () => _openAddCarDialog(customer.id),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ویجت گرافیکی پلاک ایران
  Widget _buildPlateWidget(Car car) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(car.model, style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(car.plateProvinceCode, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                const Text(' ایران | ', style: TextStyle(color: Colors.black, fontSize: 10)),
                Text('${car.plateThreeDigits} ', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                Text('${car.plateLetter} ', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                Text(car.plateTwoDigits, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
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
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'شماره موبایل')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                final newCust = Customer(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameCtrl.text,
                  phone: phoneCtrl.text,
                  cars: [],
                );
                _addCustomer(newCust);
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
        title: const Text('افزودن خودرو و پلاک'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'مدل خودرو (مثلاً: پژو ۲۰۶)')),
              const SizedBox(height: 12),
              const Text('مشخصات پلاک خودرو:', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                final car = Car(
                  model: modelCtrl.text,
                  plateTwoDigits: twoCtrl.text,
                  plateLetter: letterCtrl.text,
                  plateThreeDigits: threeCtrl.text,
                  plateProvinceCode: provCtrl.text,
                );
                _addCarToCustomer(customerId, car);
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
