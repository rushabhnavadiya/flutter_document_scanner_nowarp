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

  /// Position the dots according to the
  /// sent contour [CropAreaInitialized.areaInitial]
  Future<void> _areaInitialized(
      CropAreaInitialized event,
      Emitter<CropState> emit,
      ) async {
    debugPrint('🎯 Initializing crop area');

    // Calculate effective screen dimensions
    final effectiveWidth = event.screenSize.width - event.positionImage.left - event.positionImage.right;
    final effectiveHeight = event.screenSize.height - event.positionImage.top - event.positionImage.bottom;

    // Ensure we have positive dimensions
    if (effectiveWidth <= 0 || effectiveHeight <= 0) {
      debugPrint('⚠️ Invalid effective dimensions calculated. Using default margins.');
      // Use reasonable margins (10% of screen size)
      final horizontalMargin = event.screenSize.width * 0.1;
      final verticalMargin = event.screenSize.height * 0.1;

      newScreenSize = Size(
          event.screenSize.width - (horizontalMargin * 2),
          event.screenSize.height - (verticalMargin * 2)
      );
    } else {
      newScreenSize = Size(effectiveWidth, effectiveHeight);
    }

    debugPrint('''📏 Screen dimensions:
    Full screen: ${event.screenSize.width}x${event.screenSize.height}
    Effective area: ${newScreenSize.width}x${newScreenSize.height}
    Original margins: L:${event.positionImage.left} R:${event.positionImage.right} T:${event.positionImage.top} B:${event.positionImage.bottom}
  ''');
    // Decode image to get dimensions
    final imageDecoded = await decodeImageFromList(event.image.readAsBytesSync());
    final imageSize = Size(imageDecoded.width.toDouble(), imageDecoded.height.toDouble());

    _imageRect = _imageUtils.imageRect(
      newScreenSize,
      deviceOrientation: event.deviceOrientation,
      previewSize: event.previewSize,
      imageSize: imageSize,
    );

    // Determine if we're in landscape mode
    bool isLandscape = event.deviceOrientation == NativeDeviceOrientation.landscapeLeft ||
        event.deviceOrientation == NativeDeviceOrientation.landscapeRight;

    debugPrint('''📍 Initialization values:
      Image size: ${imageSize.width}x${imageSize.height}
      Screen size: ${newScreenSize.width}x${newScreenSize.height}
      Image rect: left=${_imageRect.left}, top=${_imageRect.top}, right=${_imageRect.right}, bottom=${_imageRect.bottom}
      Is Landscape: $isLandscape
      Using contours: ${event.areaInitial != null}
    ''');

    Area area;
    if (isLandscape) {
      // Landscape orientation calculations
      final centerX = _imageRect.left + (_imageRect.width / 2);
      final centerY = _imageRect.top + (_imageRect.height / 2);

      // Swap width and height for scaling in landscape
      final adjustedScaleX = _imageRect.height / imageDecoded.width;
      final adjustedScaleY = _imageRect.width / imageDecoded.height;

      if (event.areaInitial != null) {
        area = Area(
            topLeft: Point(
                centerX - ((event.areaInitial!.topLeft.y * adjustedScaleY) / 2),
                centerY - ((event.areaInitial!.topLeft.x * adjustedScaleX) / 2)
            ),
            topRight: Point(
                centerX + ((event.areaInitial!.topRight.y * adjustedScaleY) / 2),
                centerY - ((event.areaInitial!.topRight.x * adjustedScaleX) / 2)
            ),
            bottomLeft: Point(
                centerX - ((event.areaInitial!.bottomLeft.y * adjustedScaleY) / 2),
                centerY + ((event.areaInitial!.bottomLeft.x * adjustedScaleX) / 2)
            ),
            bottomRight: Point(
                centerX + ((event.areaInitial!.bottomRight.y * adjustedScaleY) / 2),
                centerY + ((event.areaInitial!.bottomRight.x * adjustedScaleX) / 2)
            ),
            orientation: event.orientation,
            imageWidth: imageDecoded.height,
            imageHeight: imageDecoded.width
        );
      } else {
        // Default landscape area
        final defaultHeight = _imageRect.width * 0.8;
        final defaultWidth = _imageRect.height * 0.8;
        final left = _imageRect.left + (_imageRect.width - defaultWidth) / 2;
        final top = _imageRect.top + (_imageRect.height - defaultHeight) / 2;

        area = Area(
            topLeft: Point(left, top),
            topRight: Point(left + defaultWidth, top),
            bottomLeft: Point(left, top + defaultHeight),
            bottomRight: Point(left + defaultWidth, top + defaultHeight),
            orientation: event.orientation,
            imageWidth: imageDecoded.height,
            imageHeight: imageDecoded.width
        );
      }
    } else {
      // Portrait orientation calculations
      if (event.areaInitial != null) {
        final scaleX = _imageRect.width / imageDecoded.width;
        final scaleY = _imageRect.height / imageDecoded.height;

        area = Area(
            topLeft: Point(
                _imageRect.left + (event.areaInitial!.topLeft.x * scaleX),
                _imageRect.top + (event.areaInitial!.topLeft.y * scaleY)
            ),
            topRight: Point(
                _imageRect.left + (event.areaInitial!.topRight.x * scaleX),
                _imageRect.top + (event.areaInitial!.topRight.y * scaleY)
            ),
            bottomLeft: Point(
                _imageRect.left + (event.areaInitial!.bottomLeft.x * scaleX),
                _imageRect.top + (event.areaInitial!.bottomLeft.y * scaleY)
            ),
            bottomRight: Point(
                _imageRect.left + (event.areaInitial!.bottomRight.x * scaleX),
                _imageRect.top + (event.areaInitial!.bottomRight.y * scaleY)
            ),
            orientation: event.orientation,
            imageWidth: imageDecoded.width,
            imageHeight: imageDecoded.height
        );
      } else {
        // Default portrait area
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
      }
    }

    emit(state.copyWith(area: area));
  }

  // Make sure to access minDistanceDots through _dotUtils
  Future<void> _dotMoved(
      CropDotMoved event,
      Emitter<CropState> emit,
      ) async {
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
      // Adjust scaling for landscape orientation
      final adjustedScaleX = imageDecoded.height / _imageRect.width;
      final adjustedScaleY = imageDecoded.width / _imageRect.height;

      debugPrint('''📐 Landscape transformation:
        Original scales: ($scaleX, $scaleY)
        Adjusted scales: ($adjustedScaleX, $adjustedScaleY)
    ''');

      // Transform coordinates for landscape orientation
      // Rotate 90 degrees counterclockwise and scale
      scaledTopLeft = Point(
          ((state.area.topLeft.x - _imageRect.left) * adjustedScaleX),
          ((state.area.topLeft.y - _imageRect.top) * adjustedScaleY)
      );
      scaledTopRight = Point(
          ((state.area.topRight.x - _imageRect.left) * adjustedScaleX),
          ((state.area.topRight.y - _imageRect.top) * adjustedScaleY)
      );
      scaledBottomLeft = Point(
          ((state.area.bottomLeft.x - _imageRect.left) * adjustedScaleX),
          ((state.area.bottomLeft.y - _imageRect.top) * adjustedScaleY)
      );
      scaledBottomRight = Point(
          ((state.area.bottomRight.x - _imageRect.left) * adjustedScaleX),
          ((state.area.bottomRight.y - _imageRect.top) * adjustedScaleY)
      );

      // Rotate points 90 degrees clockwise
      final rotatedPoints = [
        Point(imageDecoded.width - scaledTopLeft.y, scaledTopLeft.x),
        Point(imageDecoded.width - scaledTopRight.y, scaledTopRight.x),
        Point(imageDecoded.width - scaledBottomLeft.y, scaledBottomLeft.x),
        Point(imageDecoded.width - scaledBottomRight.y, scaledBottomRight.x),
      ];

      scaledTopLeft = rotatedPoints[0];
      scaledTopRight = rotatedPoints[1];
      scaledBottomLeft = rotatedPoints[2];
      scaledBottomRight = rotatedPoints[3];
    } else {
      // Portrait mode - direct scaling
      scaledTopLeft = Point(
          (state.area.topLeft.x - _imageRect.left) * scaleX,
          (state.area.topLeft.y - _imageRect.top) * scaleY
      );
      scaledTopRight = Point(
          (state.area.topRight.x - _imageRect.left) * scaleX,
          (state.area.topRight.y - _imageRect.top) * scaleY
      );
      scaledBottomLeft = Point(
          (state.area.bottomLeft.x - _imageRect.left) * scaleX,
          (state.area.bottomLeft.y - _imageRect.top) * scaleY
      );
      scaledBottomRight = Point(
          (state.area.bottomRight.x - _imageRect.left) * scaleX,
          (state.area.bottomRight.y - _imageRect.top) * scaleY
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