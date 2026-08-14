/// Public entry point for [MirroredWebCameraPreview] -- the actual
/// implementation is chosen at compile time per platform target:
///
/// - `mirrored_web_camera_preview_web.dart` (real implementation, backed
///   by `dart:html`/`dart:ui_web` getUserMedia) when compiling for web.
/// - `mirrored_web_camera_preview_stub.dart` (inert no-op) for every
///   other target -- `dart:html` doesn't exist outside a web build, so
///   Android/iOS/desktop compiles must never reach that file.
///
/// Callers (CheckInCard/AppearanceCard, AIAssessmentScreen) only ever
/// mount this widget when `kIsWeb` is true, so the stub body is never
/// actually reached at runtime -- it exists purely so this import
/// compiles for every platform.
library;

export 'mirrored_web_camera_preview_stub.dart'
    if (dart.library.html) 'mirrored_web_camera_preview_web.dart';