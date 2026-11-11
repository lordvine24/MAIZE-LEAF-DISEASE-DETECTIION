import 'dart:typed_data';

import 'package:flutter/widgets.dart';

Future<String> saveImageLocally({
  required Uint8List bytes,
  required String folder,
  required String filename,
}) async {
  throw UnsupportedError('Local image files are available on mobile only.');
}

Future<void> deleteLocalImage(String path) async {}

Widget localImage({
  required String path,
  required Widget fallback,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) => fallback;
