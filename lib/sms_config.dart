abstract final class SmsConfig {
  static const campaignKey = String.fromEnvironment('CHINGUISOFT_CAMPAIGN_KEY');

  static const campaignToken = String.fromEnvironment(
    'CHINGUISOFT_CAMPAIGN_TOKEN',
  );

  static const campaignUrl = String.fromEnvironment(
    'CHINGUISOFT_CAMPAIGN_URL',
    defaultValue: 'https://example.com/promo',
  );

  static bool get isConfigured =>
      campaignKey.trim().isNotEmpty && campaignToken.trim().isNotEmpty;
}
