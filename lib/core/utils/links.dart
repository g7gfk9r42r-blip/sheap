/// Links Utility - Handles mailto, subscriptions, external URLs
import 'package:url_launcher/url_launcher.dart';

class AppLinks {
  AppLinks._();

  /// Opens mailto link
  static Future<bool> openMailto(String email, {String? subject, String? body}) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: <String, String?>{
        if (subject != null) 'subject': subject,
        if (body != null) 'body': body,
      },
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        return await launchUrl(emailUri);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Opens iOS Manage Subscriptions URL
  static Future<bool> openManageSubscriptionsIOS() async {
    const url = 'https://apps.apple.com/account/subscriptions';
    return _launchUrl(url);
  }

  /// Opens Android Play Store Subscriptions
  static Future<bool> openManageSubscriptionsAndroid() async {
    // Play Store Subscriptions URL - opens in Play Store app
    const url = 'https://play.google.com/store/account/subscriptions';
    return _launchUrl(url);
  }

  /// Opens manage subscriptions (platform-aware)
  static Future<bool> openManageSubscriptions() async {
    // Note: In production, use platform detection
    // For now, try iOS first (most common in development)
    final success = await openManageSubscriptionsIOS();
    if (!success) {
      return await openManageSubscriptionsAndroid();
    }
    return success;
  }

  static Future<bool> _launchUrl(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

