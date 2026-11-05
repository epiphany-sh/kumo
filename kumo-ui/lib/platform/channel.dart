/// The release channel, fixed at build time:
/// `flutter build macos --dart-define=KUMO_CHANNEL=beta` (`make sandbox`).
///
/// A channel build keeps its daemon, its data and its settings apart from
/// the stable app's (the engine does the same, see
/// `crates/infrastructure/src/channel.rs`), so both run side by side.
library;

/// Empty for stable builds.
const kumoChannel = String.fromEnvironment('KUMO_CHANNEL');

/// The daemon's data directory name: `kumo`, or `kumo-<channel>`. Must match
/// the engine's `channel::app_name()`.
String get engineDirName => kumoChannel.isEmpty ? 'kumo' : 'kumo-$kumoChannel';

/// The UI's settings directory name: `Kumo`, or `Kumo-<channel>`.
String get settingsDirName => kumoChannel.isEmpty ? 'Kumo' : 'Kumo-$kumoChannel';
