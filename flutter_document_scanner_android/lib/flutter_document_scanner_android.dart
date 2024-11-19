// Copyright (c) 2021, Christian Betancourt
// https://github.com/criistian14
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_document_scanner_platform_interface/flutter_document_scanner_platform_interface.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

/// The Android implementation of [FlutterDocumentScannerPlatform].
class FlutterDocumentScannerAndroid extends FlutterDocumentScannerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_document_scanner_android');

  /// Registers this class as the default instance
  /// of [FlutterDocumentScannerPlatform]
  static void registerWith() {
    FlutterDocumentScannerPlatform.instance = FlutterDocumentScannerAndroid();
  }

  @override
  Future<Contour?> findContourPhoto({
    required Uint8List byteData,
    required double minContourArea,
    NativeDeviceOrientation? deviceOrientation,
    int? sensorOrientation,
    double? previewWidth,
    double? previewHeight,
  }) async {
    // Convert NativeDeviceOrientation to integer value
    int? deviceOrientationValue;
    if (deviceOrientation != null) {
      switch (deviceOrientation) {
        case NativeDeviceOrientation.portraitUp:
          deviceOrientationValue = 0;
          break;
        case NativeDeviceOrientation.landscapeLeft:
          deviceOrientationValue = 1;
          break;
        case NativeDeviceOrientation.portraitDown:
          deviceOrientationValue = 2;
          break;
        case NativeDeviceOrientation.landscapeRight:
          deviceOrientationValue = 3;
          break;
        default:
          deviceOrientationValue = 0;
      }
    }

    final contour = await methodChannel.invokeMapMethod<String, dynamic>(
      'findContourPhoto',
      <String, Object?>{
        'byteData': byteData,
        'minContourArea': minContourArea,
        'deviceOrientation': deviceOrientationValue,
        'sensorOrientation': sensorOrientation,
        'previewWidth': previewWidth,
        'previewHeight': previewHeight,
      },
    );

    if (contour != null) {
      return Contour.fromMap(contour);
    }

    return null;
  }

  @override
  Future<Uint8List?> adjustingPerspective({
    required Uint8List byteData,
    required Contour contour,
  }) async {
    return methodChannel.invokeMethod<Uint8List>(
      'adjustingPerspective',
      <String, Object>{
        'byteData': byteData,
        'points': contour.points
            .map(
              (e) => {
                'x': e.x,
                'y': e.y,
              },
            )
            .toList(),
      },
    ).then((value) => value);
  }

  @override
  Future<Uint8List?> applyFilter({
    required Uint8List byteData,
    required FilterType filter,
  }) async {
    return methodChannel.invokeMethod<Uint8List>(
      'applyFilter',
      <String, Object>{
        'byteData': byteData,
        'filter': filter.value,
      },
    ).then((value) => value);
  }
}
