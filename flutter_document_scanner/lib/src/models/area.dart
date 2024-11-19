// Copyright (c) 2021, Christian Betancourt
// https://github.com/criistian14
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.
import 'dart:math';
import 'package:equatable/equatable.dart';

/// Area composed of 4 points and orientation information
class Area extends Equatable {
  /// Create a new area
  const Area({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
    this.orientation = 0,  // Default to 0 (up) orientation
    this.imageWidth = 0,   // Add image dimensions
    this.imageHeight = 0,
  });

  /// The top left dot
  final Point<double> topLeft;

  /// The top right dot
  final Point<double> topRight;

  /// The bottom left dot
  final Point<double> bottomLeft;

  /// The bottom right dot
  final Point<double> bottomRight;

  /// The orientation of the image when captured
  /// 0 = up (default), 1 = down, 2 = left, 3 = right
  /// Corresponds to UIImage.Orientation values from iOS
  final int orientation;

  /// The width of the original image
  final int imageWidth;

  /// The height of the original image
  final int imageHeight;

  @override
  List<Object?> get props => [
    topLeft,
    topRight,
    bottomLeft,
    bottomRight,
    orientation,
    imageWidth,
    imageHeight,
  ];

  /// Creates a copy of this Area but with the given fields replaced with
  /// the new values.
  Area copyWith({
    Point<double>? topLeft,
    Point<double>? topRight,
    Point<double>? bottomLeft,
    Point<double>? bottomRight,
    int? orientation,
    int? imageWidth,
    int? imageHeight,
  }) {
    return Area(
      topLeft: topLeft ?? this.topLeft,
      topRight: topRight ?? this.topRight,
      bottomLeft: bottomLeft ?? this.bottomLeft,
      bottomRight: bottomRight ?? this.bottomRight,
      orientation: orientation ?? this.orientation,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
    );
  }

  /// Factory constructor to create Area from map
  factory Area.fromMap(Map<String, dynamic> map) {
    final points = map['points'] as List;
    return Area(
      topLeft: Point<double>(
        points[0]['x'].toDouble(),
        points[0]['y'].toDouble(),
      ),
      topRight: Point<double>(
        points[1]['x'].toDouble(),
        points[1]['y'].toDouble(),
      ),
      bottomRight: Point<double>(
        points[2]['x'].toDouble(),
        points[2]['y'].toDouble(),
      ),
      bottomLeft: Point<double>(
        points[3]['x'].toDouble(),
        points[3]['y'].toDouble(),
      ),
      orientation: map['orientation'] ?? 0,
      imageWidth: map['width']?.toInt() ?? 0,
      imageHeight: map['height']?.toInt() ?? 0,
    );
  }

  /// Convert area to a map representation
  Map<String, dynamic> toMap() {
    return {
      'points': [
        {'x': topLeft.x, 'y': topLeft.y},
        {'x': topRight.x, 'y': topRight.y},
        {'x': bottomRight.x, 'y': bottomRight.y},
        {'x': bottomLeft.x, 'y': bottomLeft.y},
      ],
      'orientation': orientation,
      'width': imageWidth,
      'height': imageHeight,
    };
  }

  /// Helper method to adjust points based on orientation
  Area adjustForOrientation() {
    switch (orientation) {
      case 1: // down
        return Area(
          topLeft: Point(imageWidth - topLeft.x, imageHeight - topLeft.y),
          topRight: Point(imageWidth - topRight.x, imageHeight - topRight.y),
          bottomLeft: Point(imageWidth - bottomLeft.x, imageHeight - bottomLeft.y),
          bottomRight: Point(imageWidth - bottomRight.x, imageHeight - bottomRight.y),
          orientation: orientation,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
        );
      case 2: // left
        return Area(
          topLeft: Point(topLeft.y, imageWidth - topLeft.x),
          topRight: Point(topRight.y, imageWidth - topRight.x),
          bottomLeft: Point(bottomLeft.y, imageWidth - bottomLeft.x),
          bottomRight: Point(bottomRight.y, imageWidth - bottomRight.x),
          orientation: orientation,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
        );
      case 3: // right
        return Area(
          topLeft: Point(imageHeight - topLeft.y, topLeft.x),
          topRight: Point(imageHeight - topRight.y, topRight.x),
          bottomLeft: Point(imageHeight - bottomLeft.y, bottomLeft.x),
          bottomRight: Point(imageHeight - bottomRight.y, bottomRight.x),
          orientation: orientation,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
        );
      default: // up (0)
        return this;
    }
  }
}