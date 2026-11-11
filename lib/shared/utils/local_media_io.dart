import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

Future<String> saveImageLocally({
  required Uint8List bytes,
  required String folder,
  required String filename,
}) async {
  final root = await getApplicationDocumentsDirectory();
  final safeFolder = folder.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  final safeFilename = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final directory = Directory('${root.path}/$safeFolder');
  await directory.create(recursive: true);
  final file = File('${directory.path}/$safeFilename');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<void> deleteLocalImage(String path) async {
  final file = File(path);
  if (await file.exists()) await file.delete();
}

Widget localImage({
  required String path,
  required Widget fallback,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  return Image.file(
    File(path),
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (_, _, _) => fallback,
  );
}
