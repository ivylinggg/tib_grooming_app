// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../models/captured_image.dart';

/// Live, horizontally-mirrored webcam preview for Flutter Web, backed by
/// a real HTML `<video>` element wired to `getUserMedia`.
///
/// Flutter Web has no in-app camera preview otherwise -- see
/// `ImageService.pickFromCamera`'s doc comment: `image_picker`'s camera
/// source on web just opens the browser/OS's own native camera UI, which
/// Flutter can't render inside itself, let alone mirror. This widget is
/// the actual in-app preview surface: a `<video>` element registered as
/// a platform view via `dart:ui_web`, shown through [HtmlElementView].
///
/// Mirroring is applied with a pure CSS transform (`scaleX(-1)`) on the
/// `<video>` element only -- it is a display-only effect. [capture]
/// always grabs the frame straight from the underlying `<video>` source
/// via `CanvasRenderingContext2D.drawImage`, which reads the real,
/// unmirrored video frame data regardless of any CSS transform applied
/// to how the element is displayed. That is what keeps the captured
/// photo byte-for-byte what a non-mirrored capture would have produced:
/// full-body validation, AI assessment, and every downstream photo (PDF,
/// Share Result, Firestore) never see a flipped image.
class MirroredWebCameraPreview extends StatefulWidget {
  final ValueChanged<CapturedImage> onCapture;
  final ValueChanged<String> onError;

  const MirroredWebCameraPreview({
    super.key,
    required this.onCapture,
    required this.onError,
  });

  @override
  State<MirroredWebCameraPreview> createState() =>
      MirroredWebCameraPreviewState();
}

class MirroredWebCameraPreviewState extends State<MirroredWebCameraPreview> {
  // One view type per widget instance -- more than one check-in/
  // assessment screen could in principle exist in the widget tree at
  // once (e.g. mid route transition), and each needs its own registered
  // factory/video element rather than sharing one.
  late final String _viewType =
      'mirrored-webcam-preview-${identityHashCode(this)}';

  html.VideoElement? _video;
  html.MediaStream? _stream;
  bool _ready = false;
  String? _error;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final video = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      // The one line that actually mirrors this -- purely visual, does
      // not touch the underlying video frame data [capture] reads.
      ..style.transform = 'scaleX(-1)';

    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        throw Exception('Camera not supported in this browser.');
      }

      final stream = await mediaDevices.getUserMedia({
        'video': {'facingMode': 'user'},
        'audio': false,
      });

      video.srcObject = stream;

      if (!mounted) {
        for (final track in stream.getTracks()) {
          track.stop();
        }
        return;
      }

      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int _) => video,
      );

      setState(() {
        _video = video;
        _stream = stream;
        _ready = true;
        _registered = true;
      });
    } catch (e) {
      final message = _messageForError(e);
      if (!mounted) return;
      setState(() {
        _error = message;
      });
      widget.onError(message);
    }
  }

  String _messageForError(Object e) {
    final text = e.toString();
    if (text.contains('NotAllowedError') || text.contains('Permission')) {
      return 'Camera permission was denied. Please allow camera access in '
          'your browser and try again.';
    }
    if (text.contains('NotFoundError')) {
      return 'No camera was found on this device.';
    }
    return 'Could not start the camera: $e';
  }

  /// Grabs the current frame straight from the live (unmirrored) video
  /// source -- see the class doc comment for why this is never flipped
  /// even though the on-screen preview is.
  Future<void> capture() async {
    final video = _video;
    if (video == null || !_ready) return;

    final width = video.videoWidth;
    final height = video.videoHeight;
    if (width == 0 || height == 0) {
      widget.onError('The camera preview is not ready yet.');
      return;
    }

    try {
      final canvas = html.CanvasElement(width: width, height: height);
      final ctx = canvas.context2D;
      ctx.drawImage(video, 0, 0);

      final blob = await canvas.toBlob('image/jpeg', 0.85);

      final reader = html.FileReader();
      final completer = Completer<Uint8List>();

      reader.onLoadEnd.listen((_) {
        if (!completer.isCompleted) {
          completer.complete(reader.result as Uint8List);
        }
      });
      reader.onError.listen((event) {
        if (!completer.isCompleted) {
          completer.completeError(Exception('Failed to read captured frame.'));
        }
      });
      reader.readAsArrayBuffer(blob);

      final bytes = await completer.future;

      widget.onCapture(
        CapturedImage.fromBytes(bytes, name: 'webcam_capture.jpg'),
      );
    } catch (e) {
      widget.onError('Could not capture the photo: $e');
    }
  }

  @override
  void dispose() {
    final stream = _stream;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        track.stop();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    if (!_ready || !_registered) {
      return const Center(child: CircularProgressIndicator());
    }

    return HtmlElementView(viewType: _viewType);
  }
}
