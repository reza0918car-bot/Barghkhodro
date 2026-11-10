import 'package:sms_sender_background/sms_sender_background.dart';

class SmsHelper {
  static final SmsSender _smsSender = SmsSender();

  /// ارسال پیامک با پشتیبانی از متن‌های طولانی
  static Future<bool> sendSms({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      // ۱. بررسی و دریافت مجوز
      bool hasPermission = await _smsSender.checkSmsPermission();
      if (!hasPermission) {
        hasPermission = await _smsSender.requestSmsPermission();
      }

      if (!hasPermission) {
        print('SMS permission not granted');
        return false;
      }

      // ۲. ارسال پیامک (پکیج به‌طور خودکار متن طولانی را چندبخشی می‌کند)
      bool success = await _smsSender.sendSms(
        phoneNumber: phoneNumber,
        message: message,
      );
      
      return success;
    } catch (e) {
      print('Error sending SMS: $e');
      return false;
    }
  }
}
