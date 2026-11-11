import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart'
    if (dart.library.html) 'tflite_flutter_stub.dart'
    as tflite;

import 'plant_image_preprocessor.dart';

final plantInferenceServiceProvider = Provider<PlantInferenceService>((ref) {
  final service = PlantInferenceService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

class PlantInferenceResult {
  final bool isMaize;
  final bool isUncertain;
  final int stage;
  final String status;
  final String title;
  final String localDisease;
  final String symptoms;
  final double confidence;
  final double maizeScore;
  final double maizeThreshold;
  final String guidance;
  final PlantAdvice? advice;

  const PlantInferenceResult({
    required this.isMaize,
    required this.isUncertain,
    required this.stage,
    required this.status,
    required this.title,
    required this.localDisease,
    required this.symptoms,
    required this.confidence,
    required this.maizeScore,
    required this.maizeThreshold,
    required this.guidance,
    this.advice,
  });
}

class PlantAdvice {
  final String product;
  final String application;
  final String otherSteps;
  final String safety;

  const PlantAdvice({
    required this.product,
    required this.application,
    required this.otherSteps,
    required this.safety,
  });

  Map<String, String> toMap() => {
    'product': product,
    'application': application,
    'other_steps': otherSteps,
    'safety': safety,
  };
}

class PlantInferenceService {
  static const _gatekeeperAsset = 'assets/models/model1_gatekeeper.tflite';
  static const _classifierAsset = 'assets/models/model2_classifier.tflite';
  static const _svmAsset = 'assets/models/ocsvm_params.json';
  static const _classNames = [
    'Bercak Daun',
    'Daun Sehat',
    'Hawar Daun',
    'Karat Daun',
  ];
  static const _englishNames = [
    'Gray Leaf Spot',
    'Healthy Leaf',
    'Northern Corn Leaf Blight',
    'Maize Rust',
  ];

  static String englishDiseaseName(String name) => switch (name) {
    'Bercak Daun' || 'Leaf Spot' => 'Gray Leaf Spot',
    'Daun Sehat' => 'Healthy Leaf',
    'Hawar Daun' || 'Leaf Blight' => 'Northern Corn Leaf Blight',
    'Karat Daun' => 'Maize Rust',
    _ => name,
  };

  late final tflite.Interpreter _gatekeeper;
  late final tflite.Interpreter _classifier;
  late final tflite.IsolateInterpreter _gatekeeperWorker;
  late final tflite.IsolateInterpreter _classifierWorker;
  late final List<List<double>> _supportVectors;
  late final List<double> _dualCoefficients;
  late final double _svmGamma;
  late final double _svmIntercept;
  late final double _svmThreshold;
  Future<void>? _loadFuture;

  Future<void> _ensureLoaded() => _loadFuture ??= _load();

  Future<void> _load() async {
    final timer = Stopwatch()..start();
    final json =
        jsonDecode(await rootBundle.loadString(_svmAsset))
            as Map<String, dynamic>;
    _supportVectors = (json['support_vectors'] as List)
        .map(
          (row) =>
              (row as List).map((value) => (value as num).toDouble()).toList(),
        )
        .toList();
    _dualCoefficients = ((json['dual_coef'] as List).first as List)
        .map((value) => (value as num).toDouble())
        .toList();
    _svmGamma = (json['gamma'] as num).toDouble();
    _svmIntercept = ((json['intercept'] as List).first as num).toDouble();
    _svmThreshold = (json['threshold'] as num).toDouble();

    _gatekeeper = await tflite.Interpreter.fromAsset(_gatekeeperAsset);
    _gatekeeperWorker = await tflite.IsolateInterpreter.create(
      address: _gatekeeper.address,
    );
    _classifier = await tflite.Interpreter.fromAsset(_classifierAsset);
    _classifierWorker = await tflite.IsolateInterpreter.create(
      address: _classifier.address,
    );
    timer.stop();
    _logTiming('Load gatekeeper and classifier models', timer);
  }

  Future<PlantInferenceResult> classify(Uint8List imageBytes) async {
    final totalTimer = Stopwatch()..start();
    await _ensureLoaded();
    _logTiming('Wait for gatekeeper and classifier models', totalTimer);
    final decodeTimer = Stopwatch()..start();
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw const FormatException('The selected image could not be opened.');
    }

    final resized = img.copyResize(
      centerCropToSquare(decoded),
      width: 224,
      height: 224,
      interpolation: img.Interpolation.linear,
    );
    decodeTimer.stop();
    _logTiming('Decode, center-crop, and resize input image', decodeTimer);

    final preprocessTimer = Stopwatch()..start();
    final input = _preprocess(resized);
    preprocessTimer.stop();
    _logTiming('Prepare gatekeeper input', preprocessTimer);

    final featuresOutput = <List<double>>[List<double>.filled(576, 0)];
    final gatekeeperTimer = Stopwatch()..start();
    await _gatekeeperWorker.run(input, featuresOutput);
    gatekeeperTimer.stop();
    _logTiming('Run maize gatekeeper', gatekeeperTimer);

    final svmTimer = Stopwatch()..start();
    final maizeScore = _decisionScore(featuresOutput.first);
    svmTimer.stop();
    _logTiming('Calculate maize score', svmTimer);
    if (maizeScore < _svmThreshold) {
      totalTimer.stop();
      _logTiming('Total inference (non-maize result)', totalTimer);
      return PlantInferenceResult(
        isMaize: false,
        isUncertain: false,
        stage: 1,
        status: 'REJECTED: Image is not recognized as a Maize leaf.',
        title: 'Not a maize leaf',
        localDisease: '',
        symptoms: '',
        confidence: 0,
        maizeScore: maizeScore,
        maizeThreshold: _svmThreshold,
        guidance: 'Choose a clear photo of one maize leaf and try again.',
      );
    }

    final classifierPreprocessTimer = Stopwatch()..start();
    final classifierInput = _preprocess(resized);
    classifierPreprocessTimer.stop();
    _logTiming('Prepare classifier input', classifierPreprocessTimer);
    final logitsOutput = <List<double>>[
      List<double>.filled(_classNames.length, 0),
    ];
    final classifierTimer = Stopwatch()..start();
    await _classifierWorker.run(classifierInput, logitsOutput);
    classifierTimer.stop();
    _logTiming('Run disease classifier', classifierTimer);
    final probabilities = _softmax(logitsOutput.first);
    if (kDebugMode) {
      for (
        var classIndex = 0;
        classIndex < probabilities.length;
        classIndex++
      ) {
        debugPrint(
          '[Model 2] ${_englishNames[classIndex]}: ${(probabilities[classIndex] * 100).toStringAsFixed(1)}%',
        );
      }
    }
    var predictedIndex = 0;
    for (var index = 1; index < probabilities.length; index++) {
      if (probabilities[index] > probabilities[predictedIndex]) {
        predictedIndex = index;
      }
    }

    final confidence = probabilities[predictedIndex];
    final localDisease = _classNames[predictedIndex];
    final isUncertain = confidence < 0.6;
    final advice = isUncertain
        ? const PlantAdvice(
            product:
                'Classification confidence is too low to reliably diagnose this image.',
            application:
                'The image is not correctly classified. Please take another picture focusing closely on a single leaf blade.',
            otherSteps:
                'Ensure good lighting and avoid blur, harsh glare, or taking photos from a distance.',
            safety:
                'Do not apply chemical treatments based on uncertain predictions.',
          )
        : _adviceFor(predictedIndex);
    totalTimer.stop();
    _logTiming('Total inference', totalTimer);
    return PlantInferenceResult(
      isMaize: true,
      isUncertain: isUncertain,
      stage: 2,
      status: isUncertain
          ? 'UNCERTAIN: Image Not Correctly Classified'
          : 'PASSED: Verified Maize Leaf',
      title: isUncertain
          ? 'Uncertain (${_englishNames[predictedIndex]} suspect)'
          : _englishNames[predictedIndex],
      localDisease: localDisease,
      symptoms: symptomsForDisease(localDisease),
      confidence: confidence * 100,
      maizeScore: maizeScore,
      maizeThreshold: _svmThreshold,
      guidance: isUncertain
          ? 'The image is not classified confidently. Take another close, well-lit photo; do not treat the plant based on this result.'
          : _guidanceFor(predictedIndex),
      advice: advice,
    );
  }

  void _logTiming(String label, Stopwatch timer) {
    if (kDebugMode) {
      debugPrint('[Scan timing] $label: ${timer.elapsedMilliseconds} ms');
    }
  }

  List<List<List<List<double>>>> _preprocess(img.Image image) {
    const means = [0.485, 0.456, 0.406];
    const standardDeviations = [0.229, 0.224, 0.225];

    return [
      List.generate(
        224,
        (y) => List.generate(224, (x) {
          final pixel = image.getPixel(x, y);
          return [
            (pixel.r / 255 - means[0]) / standardDeviations[0],
            (pixel.g / 255 - means[1]) / standardDeviations[1],
            (pixel.b / 255 - means[2]) / standardDeviations[2],
          ];
        }),
      ),
    ];
  }

  double _decisionScore(List<double> features) {
    var score = _svmIntercept;
    for (
      var vectorIndex = 0;
      vectorIndex < _supportVectors.length;
      vectorIndex++
    ) {
      var squaredDistance = 0.0;
      final supportVector = _supportVectors[vectorIndex];
      for (
        var featureIndex = 0;
        featureIndex < features.length;
        featureIndex++
      ) {
        final difference = features[featureIndex] - supportVector[featureIndex];
        squaredDistance += difference * difference;
      }
      score +=
          _dualCoefficients[vectorIndex] *
          math.exp(-_svmGamma * squaredDistance);
    }
    return score;
  }

  List<double> _softmax(List<double> logits) {
    final maximum = logits.reduce(math.max);
    final exponentials = logits
        .map((value) => math.exp(value - maximum))
        .toList();
    final total = exponentials.reduce((sum, value) => sum + value);
    return exponentials.map((value) => value / total).toList();
  }

  String _guidanceFor(int index) {
    switch (index) {
      case 1:
        return 'No disease is indicated by this result. Continue monitoring the plant.';
      case 0:
        return 'Possible gray leaf spot. Confirm with a local agricultural extension officer before treatment.';
      case 2:
        return 'Possible northern corn leaf blight. Confirm with a local agricultural extension officer before treatment.';
      case 3:
        return 'Possible maize rust. Confirm with a local agricultural extension officer before treatment.';
      default:
        return 'Check the leaf and consult a local agricultural extension officer.';
    }
  }

  static String symptomsForDisease(String disease) => switch (disease) {
    'Bercak Daun' || 'Gray Leaf Spot' =>
      'Look for long, rectangular gray or tan spots, often starting on lower leaves and limited by the leaf veins.',
    'Daun Sehat' || 'Healthy Leaf' =>
      'No clear disease symptoms were identified in this image. Keep checking new leaves because this scan cannot confirm the health of the whole plant.',
    'Hawar Daun' || 'Northern Corn Leaf Blight' || 'Leaf Blight' =>
      'Look for long, cigar-shaped gray-green lesions that begin on lower leaves and may spread or join together.',
    'Karat Daun' || 'Maize Rust' =>
      'Look for small raised orange-brown, powdery pustules on the leaf surface. They may darken as they mature.',
    _ => 'Check for changing spots, streaks, or raised growths on the leaves.',
  };

  PlantAdvice _adviceFor(int index) {
    switch (index) {
      case 0:
        return const PlantAdvice(
          product:
              'Do not spray based on an image result alone. Ask a local agricultural officer to confirm the disease first.',
          application:
              'If confirmed and treatment is recommended locally, use only a product labeled for maize and follow its label exactly.',
          otherSteps:
              'Check lower leaves and nearby plants. Rotate crops, use locally recommended resistant varieties, and manage infected crop residue where practical.',
          safety:
              'Wear the protective equipment on the label. Avoid spraying in strong wind or before rain, and follow the re-entry and pre-harvest intervals.',
        );
      case 1:
        return const PlantAdvice(
          product: 'No pesticide is recommended for a healthy-looking leaf.',
          application:
              'Do not spray fungicide. Keep checking the crop for new symptoms.',
          otherSteps:
              'Use locally recommended resistant varieties and rotate crops where practical.',
          safety:
              'If a problem appears or spreads, ask a local agricultural extension officer to confirm the cause before treating.',
        );
      case 2:
        return const PlantAdvice(
          product:
              'Get expanding cigar-shaped lesions checked by a local agricultural officer before considering any fungicide.',
          application:
              'If treatment is advised, use only a locally registered product labeled for maize and follow its label exactly.',
          otherSteps:
              'Scout the lower leaves and field for spread. Consider resistant varieties, crop rotation, and residue management for future planting.',
          safety:
              'Wear the protective equipment on the label. Avoid spraying in strong wind or before rain, and follow the re-entry and pre-harvest intervals.',
        );
      case 3:
        return const PlantAdvice(
          product:
              'Do not treat from this scan alone. Ask a local agricultural officer to confirm that the orange pustules are maize rust.',
          application:
              'If treatment is advised, use only a locally registered product labeled for maize and follow its label exactly.',
          otherSteps:
              'Monitor how quickly pustules spread, check nearby plants, remove volunteer maize where practical, and consider locally recommended resistant varieties.',
          safety:
              'Wear the protective equipment on the label. Avoid spraying in strong wind or before rain, and follow the re-entry and pre-harvest intervals.',
        );
      default:
        return const PlantAdvice(
          product: 'Do not treat until the result is confirmed.',
          application: 'Follow local agricultural guidance and product labels.',
          otherSteps:
              'Check the leaf and consult a local agricultural extension officer.',
          safety: 'Follow all label precautions.',
        );
    }
  }

  Future<void> dispose() async {
    if (_loadFuture == null) return;
    await _loadFuture;
    await _gatekeeperWorker.close();
    await _classifierWorker.close();
    _gatekeeper.close();
    _classifier.close();
  }
}
