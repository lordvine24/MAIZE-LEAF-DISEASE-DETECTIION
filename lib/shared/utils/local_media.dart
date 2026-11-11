import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'local_media_io.dart'
    if (dart.library.html) 'local_media_web.dart'
    as platform;

Future<String> saveImageLocally({
  required Uint8List bytes,
  required String folder,
  required String filename,
}) {
  return platform.saveImageLocally(
    bytes: bytes,
    folder: folder,
    filename: filename,
  );
}

Future<void> deleteLocalImage(String path) {
  if (path.startsWith('https://') || path.startsWith('http://')) {
    return Future<void>.value();
  }
  return platform.deleteLocalImage(path);
}

Widget localImage({
  required String path,
  required Widget fallback,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  if (path.startsWith('https://') || path.startsWith('http://')) {
    return Image.network(
      path,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) => fallback,
    );
  }

  return platform.localImage(
    path: path,
    fallback: fallback,
    width: width,
    height: height,
    fit: fit,
  );
}
