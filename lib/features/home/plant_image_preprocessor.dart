import 'package:image/image.dart' as img;

img.Image centerCropToSquare(img.Image image) {
  final size = image.width < image.height ? image.width : image.height;
  return img.copyCrop(
    image,
    x: (image.width - size) ~/ 2,
    y: (image.height - size) ~/ 2,
    width: size,
    height: size,
  );
}
