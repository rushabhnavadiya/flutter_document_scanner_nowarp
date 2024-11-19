// Copyright (c) 2021, Christian Betancourt
// https://github.com/criistian14
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_document_scanner/flutter_document_scanner.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:flutter_document_scanner_platform_interface/flutter_document_scanner_platform_interface.dart';

/// ImageUtils class
class ImageUtils {
  FlutterDocumentScannerPlatform get _platform =>
      FlutterDocumentScannerPlatform.instance;

  /// Calculates the rect of the image accounting for orientation
  Rect imageRect(
      Size screenSize, {
        NativeDeviceOrientation? deviceOrientation,
        int? sensorOrientation,
        Size? previewSize,
        Size? imageSize,
      }) {
    debugPrint("""📱 imageRect called with:
        Screen size: $screenSize
        Device orientation: $deviceOrientation
        Preview size: $previewSize
        Image size: $imageSize""");

    // Use referenceSize for calculations - prioritize actual image dimensions
    Size referenceSize = imageSize ?? previewSize ?? screenSize;

    // Calculate if we're in landscape mode
    bool isLandscape = deviceOrientation == NativeDeviceOrientation.landscapeLeft ||
        deviceOrientation == NativeDeviceOrientation.landscapeRight;

    // In landscape, we want to fill the width and maintain aspect ratio
    if (isLandscape) {
      // For landscape, we want to maximize width usage
      double width = screenSize.width;
      // Calculate height based on original image aspect ratio
      double height = width * (referenceSize.height / referenceSize.width);

      // If height is too large, scale down to fit screen
      if (height > screenSize.height) {
        height = screenSize.height;
        width = height * (referenceSize.width / referenceSize.height);
      }

      // Center the image
      double left = (screenSize.width - width) / 2;
      double top = (screenSize.height - height) / 2;

      debugPrint("""📐 Landscape layout calculated:
            Width: $width
            Height: $height
            Left: $left
            Top: $top""");

      return Rect.fromLTWH(left, top, width, height);
    } else {
      // For portrait, maintain original aspect ratio logic
      double srcRatio = referenceSize.height / referenceSize.width;
      double screenRatio = screenSize.height / screenSize.width;

      double width, height;
      double left = 0, top = 0;

      if (srcRatio > screenRatio) {
        height = screenSize.height;
        width = height / srcRatio;
        left = (screenSize.width - width) / 2;
      } else {
        width = screenSize.width;
        height = width * srcRatio;
        top = (screenSize.height - height) / 2;
      }

      debugPrint("""📐 Portrait layout calculated:
            Width: $width
            Height: $height
            Left: $left
            Top: $top""");

      return Rect.fromLTWH(left, top, width, height);
    }
  }
  /// Apply filters to the image with opencv
  /// Then get the contours and return only the largest one that has four sides
  /// (this is done from native code)
  ///
  /// The [Contour.points] are sorted and returned as [Area]
  Future<Contour?> findContourPhoto(
      Uint8List byteData, {
        required double minContourArea,
        NativeDeviceOrientation? deviceOrientation,
        int? sensorOrientation,
        double? previewWidth,
        double? previewHeight,
      }) async {
    try {
      print("""🔍 findContourPhoto called with:
    minContourArea: $minContourArea
    deviceOrientation: $deviceOrientation
    sensorOrientation: $sensorOrientation
    previewSize: ${previewWidth}x${previewHeight}""");

      final contour = await FlutterDocumentScannerPlatform.instance.findContourPhoto(
        byteData: byteData,
        minContourArea: minContourArea,
        deviceOrientation: deviceOrientation,
        sensorOrientation: sensorOrientation,
        previewWidth: previewWidth,
        previewHeight: previewHeight,
      );
      print("📥 Platform response received");

      if (contour == null) {
        print("❌ Platform returned null contour");
        return null;
      }
      if (contour.points.isEmpty) {
        print("❌ Contour has no points");
        return null;
      }
      if (contour.points.length != 4) {
        print("❌ Contour doesn't have exactly 4 points (has ${contour.points.length})");
        return null;
      }

      print("""✅ Valid contour found:
    Points: ${contour.points}
    Width: ${contour.width}
    Height: ${contour.height}""");

      // Validate points are within image bounds
      if (previewWidth != null && previewHeight != null) {
        print('🔍 Validating contour points against image bounds');
        for (var point in contour.points) {
          print('   Point: $point');
          if (point.x > previewWidth || point.y > previewHeight || point.x < 0 || point.y < 0) {
            print('⚠️ Warning: Point outside image bounds');
            print('   Image dimensions: ${previewWidth}x${previewHeight}');
          }
        }
      }

      return contour;
    } catch (e) {
      print("💥 Error in findContourPhoto: $e");
      return null;
    }
  }
  /// Calculates the effective orientation based on device and sensor orientations
  /// Returns an integer representing the final orientation:
  /// 0 = up, 1 = down, 2 = left, 3 = right
  int _calculateEffectiveOrientation(
      NativeDeviceOrientation? deviceOrientation,
      int? exifOrientation,
      ) {
    debugPrint('''🧭 Calculating Orientation:
        Input device orientation: $deviceOrientation
        Input EXIF orientation: ${exifOrientation ?? 'none'}
    ''');

    // First handle device orientation
    int baseOrientation;
    switch (deviceOrientation) {
      case NativeDeviceOrientation.landscapeLeft:
        baseOrientation = 2;  // left
        break;
      case NativeDeviceOrientation.landscapeRight:
        baseOrientation = 3;  // right
        break;
      case NativeDeviceOrientation.portraitDown:
        baseOrientation = 1;  // down
        break;
      case NativeDeviceOrientation.portraitUp:
      case null:
      default:
        baseOrientation = 0;  // up
        break;
    }

    // Then apply EXIF orientation if available
    final safeExifOrientation = exifOrientation ?? 0;  // Default to 0 if null
    if (safeExifOrientation > 0) {
      switch (safeExifOrientation) {
        case 3:  // 180° rotation
          baseOrientation = (baseOrientation + 2) % 4;
          break;
        case 6:  // 90° CW
          baseOrientation = (baseOrientation + 1) % 4;
          break;
        case 8:  // 90° CCW
          baseOrientation = (baseOrientation + 3) % 4;
          break;
      }
    }

    debugPrint('''🎯 Orientation Result:
        Base orientation: $baseOrientation
        After EXIF: $baseOrientation
        Device was: $deviceOrientation
        EXIF was: $safeExifOrientation
    ''');

    return baseOrientation;
  }

  Future<Uint8List?> adjustingPerspective(
      Uint8List byteData,
      Contour contour,
      ) async {
    try {
      debugPrint('''🔄 Adjusting perspective:
      Image size: ${byteData.length} bytes
      Contour points: ${contour.points}
      Image dimensions: ${contour.width}x${contour.height}
    ''');

      final newImage = await _platform.adjustingPerspective(
        byteData: byteData,
        contour: contour,
      );

      if (newImage != null) {
        debugPrint('✅ Perspective adjustment successful: ${newImage.length} bytes');
      } else {
        debugPrint('❌ Platform returned null image');
      }

      return newImage;
    } catch (e, stackTrace) {
      debugPrint('''💥 Error in adjustingPerspective:
      Error: $e
      Stack trace: $stackTrace
    ''');
      return null;
    }
  }

  /// Apply the selected [filter] with the opencv library
  Future<Uint8List> applyFilter(
      Uint8List byteData,
      FilterType filter,
      ) async {
    try {
      final newImage = await _platform.applyFilter(
        byteData: byteData,
        filter: filter,
      );

      if (newImage == null) {
        return byteData;
      }

      return newImage;
    } catch (e) {
      // TODO(utils): add error handler
      // print(e);
      return byteData;
    }
  }
}