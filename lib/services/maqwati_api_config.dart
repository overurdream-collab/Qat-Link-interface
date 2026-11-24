/// The ONLY public API origin used for FIN25 OTP and Identity.
/// The origin is supplied once by the deployment pipeline. No test tunnel,
/// operator key, manual request ID, or changeable endpoint in the login UI.
class MaqwatiApiConfig {
  static const configuredOrigin = String.fromEnvironment('MAQWATI_API_BASE_URL');

  static Uri? get origin {
    return parseOrigin(configuredOrigin);
  }

  static Uri? parseOrigin(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment ||
        uri.path != '' && uri.path != '/' ||
        uri.host == 'localhost' || uri.host == '::1' ||
        uri.host.startsWith('127.') || uri.host.endsWith('.localhost') ||
        uri.host.endsWith('.local') || uri.host.endsWith('.trycloudflare.com') ||
        (uri.hasPort && uri.port != 443)) {
      return null;
    }
    return uri.replace(path: '/');
  }
}
