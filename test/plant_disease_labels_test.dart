import 'package:flutter_test/flutter_test.dart';
import 'package:chloroscan/features/home/plant_inference_service.dart';

void main() {
  test('translates saved Indonesian and legacy disease names to English', () {
    expect(
      PlantInferenceService.englishDiseaseName('Bercak Daun'),
      'Gray Leaf Spot',
    );
    expect(
      PlantInferenceService.englishDiseaseName('Hawar Daun'),
      'Northern Corn Leaf Blight',
    );
    expect(
      PlantInferenceService.englishDiseaseName('Leaf Blight'),
      'Northern Corn Leaf Blight',
    );
  });

  test('preserves non-localized result titles', () {
    expect(
      PlantInferenceService.englishDiseaseName(
        'Uncertain (Maize Rust suspect)',
      ),
      'Uncertain (Maize Rust suspect)',
    );
  });

  test('provides distinct symptom guidance for each disease label', () {
    final grayLeafSpot = PlantInferenceService.symptomsForDisease(
      'Bercak Daun',
    );
    final leafBlight = PlantInferenceService.symptomsForDisease('Hawar Daun');
    final maizeRust = PlantInferenceService.symptomsForDisease('Karat Daun');
    final healthyLeaf = PlantInferenceService.symptomsForDisease('Daun Sehat');

    expect(grayLeafSpot, contains('rectangular'));
    expect(leafBlight, contains('cigar-shaped'));
    expect(maizeRust, contains('pustules'));
    expect(healthyLeaf, contains('No clear disease symptoms'));
    expect({grayLeafSpot, leafBlight, maizeRust, healthyLeaf}, hasLength(4));
  });
}
