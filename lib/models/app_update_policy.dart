/// Only an activated, remotely supplied policy can require an update.
class AppUpdatePolicy {
  const AppUpdatePolicy({
    this.enabled = false,
    this.minimumBuild = 0,
    this.installedBuild = 0,
    this.installedVersion = '',
    this.remotePolicy = false,
    this.message = defaultMessage,
    this.fetchSucceeded = true,
  });

  static const defaultMessage =
      'يتوفر تحديث ضروري لمتابعة اللعب. حدّث اللعبة للحصول على أحدث التحسينات.';
  final bool enabled, remotePolicy, fetchSucceeded;
  final int minimumBuild, installedBuild;
  final String installedVersion, message;

  bool get requiresUpdate =>
      remotePolicy &&
      enabled &&
      installedBuild > 0 &&
      minimumBuild > installedBuild &&
      minimumBuild <= 2147483647;

  factory AppUpdatePolicy.fromMap(Map<String, dynamic> data) {
    int build(String key) =>
        data[key] is int && data[key] >= 0 && data[key] <= 2147483647
            ? data[key] as int
            : 0;
    final message = data['message'];
    return AppUpdatePolicy(
      enabled: data['enabled'] == true,
      minimumBuild: build('minimumBuild'),
      installedBuild: build('installedBuild'),
      installedVersion: data['installedVersion'] is String
          ? data['installedVersion'] as String
          : '',
      remotePolicy: data['remotePolicy'] == true,
      message: message is String && message.trim().isNotEmpty
          ? message.trim().substring(0, message.trim().length.clamp(0, 300))
          : defaultMessage,
      fetchSucceeded: data['fetchSucceeded'] != false,
    );
  }
}
