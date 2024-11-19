// Copyright (c) 2021, Christian Betancourt
// https://github.com/criistian14
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_document_scanner/src/models/area.dart';
import 'package:flutter_document_scanner/src/utils/crop_photo_document_style.dart';
import 'package:flutter_document_scanner/src/bloc/crop/crop_event.dart';
import 'package:flutter_document_scanner/src/bloc/crop/crop_state.dart';

/// Dots utilities
class DotUtils {
  /// Create a dot utils
  DotUtils({
    required this.minDistanceDots,
  });

  /// Minimum distance between the dots that can be
  ///
  /// Can be modified from [CropPhotoDocumentStyle.minDistanceDots]
  final int minDistanceDots;

  /// Move the entire area by the given delta values.
  Area moveArea({
    required Area original,
    required double deltaX,
    required double deltaY,
    required Rect imageRect,
  }) {
    // Calculate width and height of current area
    final width = (original.bottomRight.x - original.bottomLeft.x).abs();
    final height = (original.bottomLeft.y - original.topLeft.y).abs();

    // Calculate new positions with bounds checking
    var newTopLeftX = max(min(original.topLeft.x + deltaX, imageRect.right - width), imageRect.left);
    var newTopLeftY = max(min(original.topLeft.y + deltaY, imageRect.bottom - height), imageRect.top);

    final newArea = Area(
      topLeft: Point(newTopLeftX, newTopLeftY),
      topRight: Point(newTopLeftX + width, newTopLeftY),
      bottomLeft: Point(newTopLeftX, newTopLeftY + height),
      bottomRight: Point(newTopLeftX + width, newTopLeftY + height),
      orientation: original.orientation,
      imageWidth: original.imageWidth,
      imageHeight: original.imageHeight,
    );
    return newArea;
  }

  /// Move dot top left by the given delta values.
  /// and respecting a space of [minDistanceDots] between the other dots.
  Point<double> moveTopLeft({
    required Point<double> original,
    required double deltaX,
    required double deltaY,
    required Rect imageRect,
    required Area originalArea,
  }) {
    // Calculate proposed position
    var proposedX = original.x + deltaX;
    var proposedY = original.y + deltaY;

    // Apply bounds checking
    proposedX = proposedX.clamp(
        imageRect.left,  // Minimum X (left edge of image)
        originalArea.topRight.x - minDistanceDots  // Maximum X (relative to right point)
    );
    proposedY = proposedY.clamp(
        imageRect.top,  // Minimum Y (top of image)
        originalArea.bottomLeft.y - minDistanceDots  // Maximum Y (relative to bottom point)
    );

    return Point(proposedX, proposedY);
  }

  /// Move dot top right by the given delta values
  /// and respecting a space of [minDistanceDots] between the other dots.
  Point<double> moveTopRight({
    required Point<double> original,
    required double deltaX,
    required double deltaY,
    required Rect imageRect,
    required Area originalArea,
  }) {
    debugPrint('''🔄 Moving top-right point:
    Original: $original
    Delta X: $deltaX
    Delta Y: $deltaY
    Image bounds: left=${imageRect.left}, top=${imageRect.top}, right=${imageRect.right}, bottom=${imageRect.bottom}
    Min distance: $minDistanceDots
  ''');

    // Calculate proposed position
    var proposedX = original.x + deltaX;
    var proposedY = original.y + deltaY;

    // Apply bounds checking
    proposedX = proposedX.clamp(
        originalArea.topLeft.x + minDistanceDots,  // Minimum X (relative to left point)
        imageRect.right  // Maximum X (image boundary)
    );
    proposedY = proposedY.clamp(
        imageRect.top,  // Minimum Y (top of image)
        originalArea.bottomRight.y - minDistanceDots  // Maximum Y (relative to bottom point)
    );

    final newPoint = Point(proposedX, proposedY);
    debugPrint('✨ New top-right position: $newPoint');
    return newPoint;
  }

  /// Move dot bottom left by the given delta values
  /// and respecting a space of [minDistanceDots] between the other dots.
  Point<double> moveBottomLeft({
    required Point<double> original,
    required double deltaX,
    required double deltaY,
    required Rect imageRect,
    required Area originalArea,
  }) {
    // Calculate proposed position
    var proposedX = original.x + deltaX;
    var proposedY = original.y + deltaY;

    // Apply bounds checking
    proposedX = proposedX.clamp(
        imageRect.left,  // Minimum X (left edge of image)
        originalArea.bottomRight.x - minDistanceDots  // Maximum X (relative to right point)
    );
    proposedY = proposedY.clamp(
        originalArea.topLeft.y + minDistanceDots,  // Minimum Y (relative to top point)
        imageRect.bottom  // Maximum Y (bottom of image)
    );

    return Point(proposedX, proposedY);
  }

  /// Move the bottom right point by the given delta values
  /// and respecting a space of [minDistanceDots] between the other dots.
  Point<double> moveBottomRight({
    required Point<double> original,
    required double deltaX,
    required double deltaY,
    required Rect imageRect,
    required Area originalArea,
  }) {
    debugPrint('''🔄 Moving bottom-right point:
    Original: $original
    Delta X: $deltaX
    Delta Y: $deltaY
    Image bounds: left=${imageRect.left}, top=${imageRect.top}, right=${imageRect.right}, bottom=${imageRect.bottom}
    Min distance: $minDistanceDots
  ''');

    // Calculate proposed position
    var proposedX = original.x + deltaX;
    var proposedY = original.y + deltaY;

    // Apply bounds checking
    proposedX = proposedX.clamp(
        originalArea.bottomLeft.x + minDistanceDots,  // Minimum X (relative to left point)
        imageRect.right  // Maximum X (right edge of image)
    );
    proposedY = proposedY.clamp(
        originalArea.topRight.y + minDistanceDots,  // Minimum Y (relative to top point)
        imageRect.bottom  // Maximum Y (bottom of image)
    );

    final newPoint = Point(proposedX, proposedY);
    debugPrint('✨ New bottom-right position: $newPoint');
    return newPoint;
  }
}