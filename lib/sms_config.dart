abstract final class SmsConfig {
  static const apiKey = String.fromEnvironment('SMS_TO_API_KEY');

  static const senderId = String.fromEnvironment(
    'SMS_TO_SENDER_ID',
    defaultValue: 'Epsilon',
  );

  static bool get isConfigured => apiKey.trim().isNotEmpty;
}
