import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../../core/theme/app_theme.dart';

class LeafCropPage extends StatefulWidget {
  final Uint8List imageBytes;

  const LeafCropPage({super.key, required this.imageBytes});

  @override
  State<LeafCropPage> createState() => _LeafCropPageState();
}

class _LeafCropPageState extends State<LeafCropPage> {
  Rect _cropRect = const Rect.fromLTRB(0.15, 0.1, 0.85, 0.9);
  List<int>? _imageDimensions;
  String? _error;
  bool _isCropping = false;
  _CropDragMode? _dragMode;
  Offset _dragStart = Offset.zero;
  Rect _startRect = Rect.zero;

  @override
  void initState() {
    super.initState();
    _loadImageDimensions();
  }

  Future<void> _loadImageDimensions() async {
    try {
      final dimensions = await compute(_readImageDimensions, widget.imageBytes);
      if (mounted) setState(() => _imageDimensions = dimensions);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not open this photo: $error');
      }
    }
  }

  Future<void> _cropImage() async {
    final dimensions = _imageDimensions;
    if (dimensions == null || _isCropping) return;

    setState(() {
      _isCropping = true;
      _error = null;
    });

    try {
      final croppedBytes = await compute(_cropImageBytes, <String, Object>{
        'bytes': widget.imageBytes,
        'left': _cropRect.left,
        'top': _cropRect.top,
        'right': _cropRect.right,
        'bottom': _cropRect.bottom,
      });
      if (mounted) Navigator.of(context).pop(croppedBytes);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isCropping = false;
          _error = 'Could not crop this photo: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dimensions = _imageDimensions;
    return Scaffold(
      backgroundColor: AppTheme.surfaceDark,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Crop to one leaf'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Frame a single leaf',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Drag inside the frame to move it. Drag a corner to resize.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _error != null && dimensions == null
                    ? Center(
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.errorColor),
                        ),
                      )
                    : dimensions == null
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryGreen,
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final imageSize = Size(
                            dimensions[0].toDouble(),
                            dimensions[1].toDouble(),
                          );
                          final imageRect = _imageBounds(
                            Size(constraints.maxWidth, constraints.maxHeight),
                            imageSize.width / imageSize.height,
                          );
                          final selectedRect = Rect.fromLTRB(
                            imageRect.left + _cropRect.left * imageRect.width,
                            imageRect.top + _cropRect.top * imageRect.height,
                            imageRect.left + _cropRect.right * imageRect.width,
                            imageRect.top + _cropRect.bottom * imageRect.height,
                          );

                          return Stack(
                            children: [
                              Positioned.fromRect(
                                rect: imageRect,
                                child: Image.memory(
                                  widget.imageBytes,
                                  fit: BoxFit.fill,
                                ),
                              ),
                              Positioned.fill(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onPanStart: (details) => _startCropDrag(
                                    details.localPosition,
                                    imageRect,
                                    selectedRect,
                                  ),
                                  onPanUpdate: (details) => _updateCropDrag(
                                    details.localPosition,
                                    imageRect,
                                  ),
                                  onPanEnd: (_) => _dragMode = null,
                                  child: CustomPaint(
                                    painter: _CropOverlayPainter(
                                      imageRect: imageRect,
                                      cropRect: selectedRect,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              if (_error != null && dimensions != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.errorColor),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: dimensions == null || _isCropping
                      ? null
                      : _cropImage,
                  icon: _isCropping
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.crop),
                  label: Text(_isCropping ? 'Cropping...' : 'Crop and scan'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startCropDrag(Offset position, Rect imageRect, Rect selectedRect) {
    final point = _toNormalized(position, imageRect);
    if (point == null) return;

    _dragStart = point;
    _startRect = _cropRect;
    final corners = <(_CropDragMode, Offset)>[
      (_CropDragMode.topLeft, selectedRect.topLeft),
      (_CropDragMode.topRight, selectedRect.topRight),
      (_CropDragMode.bottomLeft, selectedRect.bottomLeft),
      (_CropDragMode.bottomRight, selectedRect.bottomRight),
    ];
    final nearestCorner = corners.reduce(
      (a, b) =>
          (a.$2 - position).distanceSquared < (b.$2 - position).distanceSquared
          ? a
          : b,
    );

    if ((nearestCorner.$2 - position).distance <= 28) {
      _dragMode = nearestCorner.$1;
    } else if (_cropRect.contains(point)) {
      _dragMode = _CropDragMode.move;
    } else {
      _dragMode = _CropDragMode.create;
      _startRect = Rect.fromPoints(point, point);
    }
  }

  void _updateCropDrag(Offset position, Rect imageRect) {
    final mode = _dragMode;
    final point = _toNormalized(position, imageRect);
    if (mode == null || point == null) return;

    setState(() {
      if (mode == _CropDragMode.move) {
        final dx = point.dx - _dragStart.dx;
        final dy = point.dy - _dragStart.dy;
        final left = (_startRect.left + dx).clamp(0.0, 1.0 - _startRect.width);
        final top = (_startRect.top + dy).clamp(0.0, 1.0 - _startRect.height);
        _cropRect = Rect.fromLTWH(
          left,
          top,
          _startRect.width,
          _startRect.height,
        );
        return;
      }

      final anchor = switch (mode) {
        _CropDragMode.topLeft => _startRect.bottomRight,
        _CropDragMode.topRight => _startRect.bottomLeft,
        _CropDragMode.bottomLeft => _startRect.topRight,
        _CropDragMode.bottomRight => _startRect.topLeft,
        _CropDragMode.create => _dragStart,
        _CropDragMode.move => Offset.zero,
      };
      _cropRect = _rectFromAnchor(anchor, point);
    });
  }

  Offset? _toNormalized(Offset position, Rect imageRect) {
    if (!imageRect.contains(position)) return null;
    return Offset(
      ((position.dx - imageRect.left) / imageRect.width).clamp(0.0, 1.0),
      ((position.dy - imageRect.top) / imageRect.height).clamp(0.0, 1.0),
    );
  }

  Rect _rectFromAnchor(Offset anchor, Offset point) {
    double keepMinimum(double value, double fixed) {
      final bounded = value.clamp(0.0, 1.0);
      if ((bounded - fixed).abs() >= 0.08) return bounded;
      return (fixed + (bounded >= fixed ? 0.08 : -0.08)).clamp(0.0, 1.0);
    }

    return Rect.fromPoints(
      Offset(
        keepMinimum(point.dx, anchor.dx),
        keepMinimum(point.dy, anchor.dy),
      ),
      anchor,
    );
  }
}

enum _CropDragMode { move, topLeft, topRight, bottomLeft, bottomRight, create }

Rect _imageBounds(Size bounds, double aspectRatio) {
  final width = math.min(bounds.width, bounds.height * aspectRatio);
  final height = width / aspectRatio;
  return Rect.fromLTWH(
    (bounds.width - width) / 2,
    (bounds.height - height) / 2,
    width,
    height,
  );
}

List<int> _readImageDimensions(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Unsupported image file.');
  final oriented = img.bakeOrientation(decoded);
  return <int>[oriented.width, oriented.height];
}

Uint8List _cropImageBytes(Map<String, Object> request) {
  final bytes = request['bytes']! as Uint8List;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Unsupported image file.');
  final oriented = img.bakeOrientation(decoded);
  final left = ((request['left']! as double) * oriented.width)
      .floor()
      .clamp(0, oriented.width - 1)
      .toInt();
  final top = ((request['top']! as double) * oriented.height)
      .floor()
      .clamp(0, oriented.height - 1)
      .toInt();
  final right = ((request['right']! as double) * oriented.width)
      .ceil()
      .clamp(left + 1, oriented.width)
      .toInt();
  final bottom = ((request['bottom']! as double) * oriented.height)
      .ceil()
      .clamp(top + 1, oriented.height)
      .toInt();
  final cropped = img.copyCrop(
    oriented,
    x: left,
    y: top,
    width: right - left,
    height: bottom - top,
  );
  return Uint8List.fromList(img.encodeJpg(cropped, quality: 95));
}

class _CropOverlayPainter extends CustomPainter {
  final Rect imageRect;
  final Rect cropRect;

  const _CropOverlayPainter({required this.imageRect, required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final dimPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(imageRect)
      ..addRect(cropRect);
    canvas.drawPath(
      dimPath,
      Paint()..color = Colors.black.withValues(alpha: 0.58),
    );

    final outline = Paint()
      ..color = AppTheme.primaryGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(cropRect, outline);

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = cropRect.left + cropRect.width * i / 3;
      final y = cropRect.top + cropRect.height * i / 3;
      canvas.drawLine(
        Offset(x, cropRect.top),
        Offset(x, cropRect.bottom),
        grid,
      );
      canvas.drawLine(
        Offset(cropRect.left, y),
        Offset(cropRect.right, y),
        grid,
      );
    }

    final handle = Paint()..color = Colors.white;
    for (final corner in <Offset>[
      cropRect.topLeft,
      cropRect.topRight,
      cropRect.bottomLeft,
      cropRect.bottomRight,
    ]) {
      canvas.drawCircle(corner, 5, handle);
    }
  }

  @override
  bool shouldRepaint(_CropOverlayPainter oldDelegate) =>
      oldDelegate.imageRect != imageRect || oldDelegate.cropRect != cropRect;
}
