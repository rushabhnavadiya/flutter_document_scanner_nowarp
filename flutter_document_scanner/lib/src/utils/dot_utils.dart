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
    debugPrint('''🔄 Moving area:
        Delta: ($deltaX, $deltaY)
        Image bounds: $imageRect
        Current area: $original
    ''');

    // Calculate current dimensions
    final width = (original.bottomRight.x - original.bottomLeft.x).abs();
    final height = (original.bottomLeft.y - original.topLeft.y).abs();

    // Calculate new positions with strict bounds checking
    double newX = original.topLeft.x + deltaX;
    double newY = original.topLeft.y + deltaY;

    // Enforce left/right boundaries
    if (newX < imageRect.left) {
      newX = imageRect.left;
    }
    if (newX + width > imageRect.right) {
      newX = imageRect.right - width;
    }

    // Enforce top/bottom boundaries
    if (newY < imageRect.top) {
      newY = imageRect.top;
    }
    if (newY + height > imageRect.bottom) {
      newY = imageRect.bottom - height;
    }

    debugPrint('''📏 New position calculated:
        New X: $newX
        New Y: $newY
        Width: $width
        Height: $height
    ''');

    return Area(
      topLeft: Point(newX, newY),
      topRight: Point(newX + width, newY),
      bottomLeft: Point(newX, newY + height),
      bottomRight: Point(newX + width, newY + height),
      orientation: original.orientation,
      imageWidth: original.imageWidth,
      imageHeight: original.imageHeight,
    );
  }
  /// Move dot top left by the given delta values
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

  /// Move dot top right by the given delta values
  /// and respecting a space of [minDistanceDots] between the other dots.

  Point<double> moveTopRight({
    required Point<double> original,
    required double deltaX,
    required double deltaY,
    required Rect imageRect,
    required Area originalArea,
  }) {
    // Calculate proposed position
    var proposedX = original.x + deltaX;
    var proposedY = original.y + deltaY;

    // Apply strict boundary checks
    proposedX = proposedX.clamp(
        originalArea.topLeft.x + minDistanceDots,
        imageRect.right
    );
    proposedY = proposedY.clamp(
        imageRect.top,
        originalArea.bottomRight.y - minDistanceDots
    );

    // Add additional validation to ensure we stay within image bounds
    if (proposedX > imageRect.right) proposedX = imageRect.right;
    if (proposedY < imageRect.top) proposedY = imageRect.top;

    debugPrint('''📍 Top-right point movement:
        Original: $original
        Proposed: ($proposedX, $proposedY)
        Image bounds: $imageRect
    ''');

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