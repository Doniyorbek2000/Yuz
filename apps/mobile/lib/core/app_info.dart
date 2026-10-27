/// Build metadata injected with `--dart-define=YUZ_VERSION=...` by CI.
abstract final class AppInfo {
  static const version = String.fromEnvironment('YUZ_VERSION', defaultValue: '0.1.0-dev');
}
