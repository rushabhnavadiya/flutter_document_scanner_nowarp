// Copyright (c) 2021, Christian Betancourt
// https://github.com/criistian14
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:math';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_document_scanner/src/bloc/crop/crop_event.dart';
import 'package:flutter_document_scanner/src/bloc/crop/crop_state.dart';
import 'package:flutter_document_scanner/src/models/area.dart';
import 'package:flutter_document_scanner/src/utils/dot_utils.dart';
import 'package:flutter_document_scanner/src/utils/image_utils.dart';
import 'package:flutter_document_scanner_platform_interface/flutter_document_scanner_platform_interface.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

/// Control everything related to image cropping and perspective adjustment
class CropBloc extends Bloc<CropEvent, CropState> {
  /// Create an instance of the bloc
  CropBloc({
    required DotUtils dotUtils,
    required ImageUtils imageUtils,
  })
      : _dotUtils = dotUtils,
        _imageUtils = imageUtils,
        super(CropState.init()) {
    on<CropAreaInitialized>(_areaInitialized);
    on<CropDotMoved>(_dotMoved);
    on<CropPhotoByAreaCropped>(_photoByAreaCropped);
  }

  final DotUtils _dotUtils;
  final ImageUtils _imageUtils;

  late Rect _imageRect;

  /// Screen size by adjusting the screen image position
  late Size newScreenSize;

  Future<void> _areaInitialized(
      CropAreaInitialized event,
      Emitter<CropState> emit,
      ) async {
    debugPrint('🎯 Initializing crop area');

    // Calculate effective screen dimensions
    newScreenSize = Size(
        event.screenSize.width - event.positionImage.left - event.positionImage.right,
        event.screenSize.height - event.positionImage.top - event.positionImage.bottom
    );

    // Decode image to get dimensions
    final imageDecoded = await decodeImageFromList(event.image.readAsBytesSync());

    // Get image dimensions and orientation
    final bool isLandscape = event.deviceOrientation == NativeDeviceOrientation.landscapeLeft ||
        event.deviceOrientation == NativeDeviceOrientation.landscapeRight;

    debugPrint('''📏 Initialization parameters:
        Device orientation: ${event.deviceOrientation}
        Screen size: ${newScreenSize.width}x${newScreenSize.height}
        Image size: ${imageDecoded.width}x${imageDecoded.height}
        Is landscape: $isLandscape
    ''');

    // Calculate image rect with proper orientation
    _imageRect = _imageUtils.imageRect(
        newScreenSize,
        deviceOrientation: event.deviceOrientation,
        previewSize: event.previewSize,
        imageSize: Size(imageDecoded.width.toDouble(), imageDecoded.height.toDouble())
    );

    debugPrint('''📐 Image rect calculated:
        Left: ${_imageRect.left}
        Top: ${_imageRect.top}
        Width: ${_imageRect.width}
        Height: ${_imageRect.height}
    ''');

    Area area;
    if (isLandscape) {
      // For landscape, we want to rotate our coordinate system 90 degrees
      final defaultWidth = _imageRect.width * 0.8;  // 80% of available width
      final defaultHeight = _imageRect.height * 0.8; // 80% of available height

      // Calculate margins for centering
      final horizontalMargin = (_imageRect.width - defaultWidth) / 2;
      final verticalMargin = (_imageRect.height - defaultHeight) / 2;

      // Base coordinates relative to image rect
      final left = _imageRect.left + horizontalMargin;
      final top = _imageRect.top + verticalMargin;

      debugPrint('''📏 Landscape layout:
            Default width: $defaultWidth
            Default height: $defaultHeight
            Left margin: $horizontalMargin
            Top margin: $verticalMargin
            Base coordinates: ($left, $top)
        ''');

      area = Area(
          topLeft: Point(left, top),
          topRight: Point(left + defaultWidth, top),
          bottomLeft: Point(left, top + defaultHeight),
          bottomRight: Point(left + defaultWidth, top + defaultHeight),
          orientation: event.orientation,
          // For landscape, we swap width/height to match the rotated view
          imageWidth: imageDecoded.height,
          imageHeight: imageDecoded.width
      );

      debugPrint('''📍 Created landscape area:
            TL: ${area.topLeft}
            TR: ${area.topRight}
            BL: ${area.bottomLeft}
            BR: ${area.bottomRight}
            Orientation: ${area.orientation}
        ''');
    } else {
      // Portrait mode - standard layout
      final defaultWidth = _imageRect.width * 0.8;
      final defaultHeight = _imageRect.height * 0.8;
      final left = _imageRect.left + (_imageRect.width - defaultWidth) / 2;
      final top = _imageRect.top + (_imageRect.height - defaultHeight) / 2;

      area = Area(
          topLeft: Point(left, top),
          topRight: Point(left + defaultWidth, top),
          bottomLeft: Point(left, top + defaultHeight),
          bottomRight: Point(left + defaultWidth, top + defaultHeight),
          orientation: event.orientation,
          imageWidth: imageDecoded.width,
          imageHeight: imageDecoded.height
      );

      debugPrint('''📍 Created portrait area:
            TL: ${area.topLeft}
            TR: ${area.topRight}
            BL: ${area.bottomLeft}
            BR: ${area.bottomRight}
            Orientation: ${area.orientation}
        ''');
    }

    // Ensure all points are within bounds
    area = _ensureAreaWithinBounds(area, _imageRect);

    emit(state.copyWith(area: area));
  }

  Area _ensureAreaWithinBounds(Area area, Rect bounds) {
      Point<double> clampPoint(Point<double> point) {
        return Point(
            point.x.clamp(bounds.left, bounds.right),
            point.y.clamp(bounds.top, bounds.bottom)
        );
      }

      final clampedArea = Area(
          topLeft: clampPoint(area.topLeft),
          topRight: clampPoint(area.topRight),
          bottomLeft: clampPoint(area.bottomLeft),
          bottomRight: clampPoint(area.bottomRight),
          orientation: area.orientation,
          imageWidth: area.imageWidth,
          imageHeight: area.imageHeight
      );

      // If points were clamped, log the changes
      if (clampedArea != area) {
        debugPrint('''⚠️ Area points were clamped:
            Original: TL:${area.topLeft}, TR:${area.topRight}, BL:${area.bottomLeft}, BR:${area.bottomRight}
            Clamped: TL:${clampedArea.topLeft}, TR:${clampedArea.topRight}, BL:${clampedArea.bottomLeft}, BR:${clampedArea.bottomRight}
        ''');
      }

      return clampedArea;
    }

  Future<void> _dotMoved(
      CropDotMoved event,
      Emitter<CropState> emit,
      ) async {
    debugPrint('''👆 Dot move event received:
   Position: ${event.dotPosition}
   Delta X: ${event.deltaX}
   Delta Y: ${event.deltaY}
   Image rect: left=${_imageRect.left}, top=${_imageRect.top}, right=${_imageRect.right}, bottom=${_imageRect.bottom}
   Current area:
     topLeft: ${state.area.topLeft}
     topRight: ${state.area.topRight}
     bottomLeft: ${state.area.bottomLeft}
     bottomRight: ${state.area.bottomRight}
 ''');

    Area newArea;
    switch (event.dotPosition) {
      case DotPosition.topRight:
        final result = _dotUtils.moveTopRight(
          original: state.area.topRight,
          deltaX: event.deltaX,
          deltaY: event.deltaY,
          imageRect: _imageRect,
          originalArea: state.area,
        );
        newArea = state.area.copyWith(topRight: result);
        break;

      case DotPosition.topLeft:
        final result = _dotUtils.moveTopLeft(
          original: state.area.topLeft,
          deltaX: event.deltaX,
          deltaY: event.deltaY,
          imageRect: _imageRect,
          originalArea: state.area,
        );
        newArea = state.area.copyWith(topLeft: result);
        break;

      case DotPosition.bottomRight:
        final result = _dotUtils.moveBottomRight(
          original: state.area.bottomRight,
          deltaX: event.deltaX,
          deltaY: event.deltaY,
          imageRect: _imageRect,
          originalArea: state.area,
        );
        newArea = state.area.copyWith(bottomRight: result);
        break;

      case DotPosition.bottomLeft:
        final result = _dotUtils.moveBottomLeft(
          original: state.area.bottomLeft,
          deltaX: event.deltaX,
          deltaY: event.deltaY,
          imageRect: _imageRect,
          originalArea: state.area,
        );
        newArea = state.area.copyWith(bottomLeft: result);
        break;

      case DotPosition.all:
        newArea = _dotUtils.moveArea(
          original: state.area,
          deltaX: event.deltaX,
          deltaY: event.deltaY,
          imageRect: _imageRect,
        );
        break;
    }

    debugPrint('''✨ After movement:
   New area:
     topLeft: ${newArea.topLeft}
     topRight: ${newArea.topRight}
     bottomLeft: ${newArea.bottomLeft}
     bottomRight: ${newArea.bottomRight}
 ''');

    emit(state.copyWith(area: newArea));
  }
  int _calculateOrientation(NativeDeviceOrientation? deviceOrientation) {
    if (deviceOrientation == null) return 0;

    switch (deviceOrientation) {
      case NativeDeviceOrientation.portraitUp:
        return 0;
      case NativeDeviceOrientation.portraitDown:
        return 1;
      case NativeDeviceOrientation.landscapeLeft:
        return 2;
      case NativeDeviceOrientation.landscapeRight:
        return 3;
      default:
        return 0;
    }
  }

  /// Crop the image and then adjust the perspective
  ///
  /// lastly change the page
  Future<void> _photoByAreaCropped(
      CropPhotoByAreaCropped event,
      Emitter<CropState> emit,
      ) async {
    debugPrint('''🔄 Starting photo crop:
        Current orientation: ${state.area.orientation}
        Image rect: $_imageRect
        Visible crop area:
            topLeft: ${state.area.topLeft}
            topRight: ${state.area.topRight}
            bottomLeft: ${state.area.bottomLeft}
            bottomRight: ${state.area.bottomRight}
    ''');

    final imageDecoded = await decodeImageFromList(event.image.readAsBytesSync());

    // Determine natural orientation
    final isNaturallyLandscape = imageDecoded.width > imageDecoded.height;
    final effectiveOrientation = isNaturallyLandscape ? 2 : state.area.orientation;
    final isLandscape = effectiveOrientation == 2 || effectiveOrientation == 3;

    // Calculate scaling factors based on natural orientation
    final scaleX = imageDecoded.width / _imageRect.width;
    final scaleY = imageDecoded.height / _imageRect.height;

    debugPrint('''📏 Scaling calculation:
        Image size: ${imageDecoded.width}x${imageDecoded.height}
        Rect size: ${_imageRect.width}x${_imageRect.height}
        Scale factors: ($scaleX, $scaleY)
        Is landscape: $isLandscape
    ''');

    Point<double> scaledTopLeft, scaledTopRight, scaledBottomLeft, scaledBottomRight;
    if (isLandscape) {
      // Landscape transformation code remains the same
      final adjustedScaleX = imageDecoded.height / _imageRect.width;
      final adjustedScaleY = imageDecoded.width / _imageRect.height;

      debugPrint('''📐 Landscape transformation:
        Original scales: ($scaleX, $scaleY)
        Adjusted scales: ($adjustedScaleX, $adjustedScaleY)
    ''');

      // Normalize and rotate points for landscape
      final normalizedPoints = [
        Point(
            (state.area.topLeft.x - _imageRect.left) / _imageRect.width,
            (state.area.topLeft.y - _imageRect.top) / _imageRect.height
        ),
        Point(
            (state.area.topRight.x - _imageRect.left) / _imageRect.width,
            (state.area.topRight.y - _imageRect.top) / _imageRect.height
        ),
        Point(
            (state.area.bottomLeft.x - _imageRect.left) / _imageRect.width,
            (state.area.bottomLeft.y - _imageRect.top) / _imageRect.height
        ),
        Point(
            (state.area.bottomRight.x - _imageRect.left) / _imageRect.width,
            (state.area.bottomRight.y - _imageRect.top) / _imageRect.height
        )
      ];

      debugPrint('''📊 Normalized points (0-1 range):
        TL: ${normalizedPoints[0]}
        TR: ${normalizedPoints[1]}
        BL: ${normalizedPoints[2]}
        BR: ${normalizedPoints[3]}
    ''');

      scaledTopLeft = Point(
          imageDecoded.width * (1 - normalizedPoints[0].y),
          imageDecoded.height * normalizedPoints[0].x
      );
      scaledTopRight = Point(
          imageDecoded.width * (1 - normalizedPoints[1].y),
          imageDecoded.height * normalizedPoints[1].x
      );
      scaledBottomLeft = Point(
          imageDecoded.width * (1 - normalizedPoints[2].y),
          imageDecoded.height * normalizedPoints[2].x
      );
      scaledBottomRight = Point(
          imageDecoded.width * (1 - normalizedPoints[3].y),
          imageDecoded.height * normalizedPoints[3].x
      );
    } else {
      // Portrait mode - direct scaling with offset adjustment
      debugPrint('📐 Portrait transformation');

      // Normalize points to account for image rect position
      final normalizedPoints = [
        Point(
            (state.area.topLeft.x - _imageRect.left) / _imageRect.width,
            (state.area.topLeft.y - _imageRect.top) / _imageRect.height
        ),
        Point(
            (state.area.topRight.x - _imageRect.left) / _imageRect.width,
            (state.area.topRight.y - _imageRect.top) / _imageRect.height
        ),
        Point(
            (state.area.bottomLeft.x - _imageRect.left) / _imageRect.width,
            (state.area.bottomLeft.y - _imageRect.top) / _imageRect.height
        ),
        Point(
            (state.area.bottomRight.x - _imageRect.left) / _imageRect.width,
            (state.area.bottomRight.y - _imageRect.top) / _imageRect.height
        )
      ];

      // Scale normalized points to image dimensions
      scaledTopLeft = Point(
          normalizedPoints[0].x * imageDecoded.width,
          normalizedPoints[0].y * imageDecoded.height
      );
      scaledTopRight = Point(
          normalizedPoints[1].x * imageDecoded.width,
          normalizedPoints[1].y * imageDecoded.height
      );
      scaledBottomLeft = Point(
          normalizedPoints[2].x * imageDecoded.width,
          normalizedPoints[2].y * imageDecoded.height
      );
      scaledBottomRight = Point(
          normalizedPoints[3].x * imageDecoded.width,
          normalizedPoints[3].y * imageDecoded.height
      );
    }

    final scaledArea = Area(
      topLeft: scaledTopLeft,
      topRight: scaledTopRight,
      bottomLeft: scaledBottomLeft,
      bottomRight: scaledBottomRight,
      orientation: effectiveOrientation,
      imageWidth: imageDecoded.width,
      imageHeight: imageDecoded.height,
    );

    // Create contour with correct point order based on orientation
    // Adjust contour point order for landscape
    final List<Point<double>> contourPoints = isLandscape ?
    [
      scaledArea.topLeft,      // Top-left in final orientation
      scaledArea.bottomLeft,   // Bottom-left in final orientation
      scaledArea.topRight,     // Top-right in final orientation
      scaledArea.bottomRight   // Bottom-right in final orientation
    ] :
    [
      scaledArea.topLeft,
      scaledArea.bottomLeft,
      scaledArea.topRight,
      scaledArea.bottomRight
    ];

    debugPrint('''🔄 Transformation debug:
    Original area:
        TL: ${state.area.topLeft}
        TR: ${state.area.topRight}
        BL: ${state.area.bottomLeft}
        BR: ${state.area.bottomRight}
    Scaled area:
        TL: ${scaledArea.topLeft}
        TR: ${scaledArea.topRight}
        BL: ${scaledArea.bottomLeft}
        BR: ${scaledArea.bottomRight}
    Final contour points:
        1: ${contourPoints[0]}
        2: ${contourPoints[1]}
        3: ${contourPoints[2]}
        4: ${contourPoints[3]}
''');

    final contour = Contour(
      points: contourPoints,
      width: imageDecoded.width,
      height: imageDecoded.height,
    );

    debugPrint('''🔲 Final contour:
        Orientation: ${isLandscape ? 'landscape' : 'portrait'}
        Points: ${contour.points.map((p) => '(${p.x}, ${p.y})').join(' -> ')}
        Image size: ${contour.width}x${contour.height}
    ''');

    final response = await _imageUtils.adjustingPerspective(
      event.image.readAsBytesSync(),
      contour,
    );

    emit(state.copyWith(
      imageCropped: response ?? event.image.readAsBytesSync(),
      areaParsed: scaledArea,
    ));
  }

  bool _arePointsWithinBounds(Area area, int width, int height) {
    final points = [
      area.topLeft,
      area.topRight,
      area.bottomLeft,
      area.bottomRight,
    ];

    for (var point in points) {
      if (point.x < 0 || point.x > width || point.y < 0 || point.y > height) {
        debugPrint('''⚠️ Point out of bounds:
                Point: $point
                Image bounds: ${width}x$height
            ''');
        return false;
      }
    }
    return true;
  }
}