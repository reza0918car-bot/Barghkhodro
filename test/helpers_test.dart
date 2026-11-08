import 'package:flutter_test/flutter_test.dart';
import 'package:auto_electric_app/main.dart';

void main() {
  group('NumberHelper', () {
    test('converts Persian and Arabic digits to ASCII', () {
      expect(NumberHelper.cleanNumbers('۱۲۳٤۵'), '12345');
    });

    test('normalizes Iranian mobile numbers', () {
      expect(NumberHelper.normalizePhone('989121234567'), '09121234567');
      expect(NumberHelper.normalizePhone('+989121234567'), '09121234567');
    });

    test('returns zero for invalid integer input', () {
      expect(NumberHelper.safeParseInt('نامعتبر'), 0);
    });
  });

  test('converts Nowruz date to Jalali new year', () {
    expect(JalaliHelper.gregorianToJalali(2024, 3, 20), '1403/01/01');
  });
}
