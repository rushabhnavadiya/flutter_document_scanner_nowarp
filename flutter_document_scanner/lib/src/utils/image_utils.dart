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
        Size? imageSize,  // Add imageSize parameter
      }) {
    debugPrint("""📱 imageRect called with:
    Screen size: $screenSize
    Device orientation: $deviceOrientation
    Sensor orientation: $sensorOrientation
    Preview size: $previewSize
    Image size: $imageSize""");

    // Validate input dimensions
    if (screenSize.width <= 0 || screenSize.height <= 0) {
      debugPrint('⚠️ Invalid screen size, using fallback dimensions');
      return const Rect.fromLTWH(0, 0, 360, 640);
    }

    // Use preview size, image size, or screen size for aspect ratio calculation
    Size referenceSize;
    if (previewSize != null && previewSize.width > 0 && previewSize.height > 0) {
      referenceSize = previewSize;
      debugPrint('📏 Using preview size for calculations');
    } else if (imageSize != null && imageSize.width > 0 && imageSize.height > 0) {
      referenceSize = imageSize;
      debugPrint('📏 Using image size for calculations');
    } else {
      debugPrint('⚠️ Using screen size as fallback');
      return Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);
    }

    // Calculate aspect ratios
    final sourceAspectRatio = referenceSize.height / referenceSize.width;
    final screenAspectRatio = screenSize.height / screenSize.width;

    debugPrint("""📐 Aspect ratios:
    Source: $sourceAspectRatio
    Screen: $screenAspectRatio""");

    // Determine rotation based on device and sensor orientation
    bool isRotated = false;
    if (deviceOrientation != null) {
      switch (deviceOrientation) {
        case NativeDeviceOrientation.landscapeLeft:
        case NativeDeviceOrientation.landscapeRight:
          isRotated = true;
          break;
        case NativeDeviceOrientation.portraitUp:
        case NativeDeviceOrientation.portraitDown:
          isRotated = false;
          break;
        default:
          isRotated = false;
      }
    }

    // Adjust for sensor orientation
    if (sensorOrientation != null) {
      if (sensorOrientation == 90 || sensorOrientation == 270) {
        isRotated = !isRotated; // Flip rotation state
      }
    }

    debugPrint('🔄 Final rotation state: $isRotated');

    // Calculate dimensions and position
    double width, height, left = 0, top = 0;
    if (isRotated) {
      // For landscape, we want to fill the width first
      final effectiveAspectRatio = 1 / sourceAspectRatio;

      // Always start with full width
      width = screenSize.width;
      height = width / effectiveAspectRatio;

      // If height exceeds screen height, scale down
      if (height > screenSize.height) {
        height = screenSize.height;
        width = height * effectiveAspectRatio;
      }

      // Center the image
      left = (screenSize.width - width) / 2;
      top = (screenSize.height - height) / 2;

      debugPrint('''📏 Landscape calculations:
      Screen size: ${screenSize.width}x${screenSize.height}
      Image size: ${width}x${height}
      Position: ($left, $top)
      Aspect ratio: $effectiveAspectRatio
  ''');
    } else {
      if (sourceAspectRatio > screenAspectRatio) {
        // Image is taller relative to screen
        width = screenSize.width;
        height = width * sourceAspectRatio;
        top = (screenSize.height - height) / 2;
        left = 0;
      } else {
        // Image is wider relative to screen
        height = screenSize.height;
        width = height / sourceAspectRatio;
        left = (screenSize.width - width) / 2;
        top = 0;
      }
    }

    debugPrint("""📍 Final dimensions:
    Width: $width
    Height: $height
    Left: $left
    Top: $top""");
    // Ensure we're not exceeding screen bounds
    assert(width <= screenSize.width, 'Width exceeds screen bounds');
    assert(height <= screenSize.height, 'Height exceeds screen bounds');

    final rect = Rect.fromLTWH(left, top, width, height);
    debugPrint('📦 Final rect: $rect');

    return rect;
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