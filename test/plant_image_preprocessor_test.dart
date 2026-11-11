import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:chloroscan/features/home/plant_image_preprocessor.dart';

void main() {
  test('center-crops landscape images to a square', () {
    final image = img.Image(width: 4, height: 2);
    image.setPixel(0, 0, img.ColorRgb8(255, 0, 0));
    image.setPixel(1, 0, img.ColorRgb8(0, 255, 0));
    image.setPixel(2, 0, img.ColorRgb8(0, 0, 255));
    image.setPixel(3, 0, img.ColorRgb8(255, 255, 0));

    final cropped = centerCropToSquare(image);

    expect(cropped.width, 2);
    expect(cropped.height, 2);
    expect(cropped.getPixel(0, 0).g, 255);
    expect(cropped.getPixel(1, 0).b, 255);
  });

  test('center-crops portrait images to a square', () {
    final image = img.Image(width: 2, height: 4);

    final cropped = centerCropToSquare(image);

    expect(cropped.width, 2);
    expect(cropped.height, 2);
  });
}
