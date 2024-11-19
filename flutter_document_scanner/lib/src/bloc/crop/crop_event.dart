// Copyright (c) 2021, Christian Betancourt
// https://github.com/criistian14
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_document_scanner/src/models/area.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

/// Class to create events
abstract class CropEvent extends Equatable {}

/// Initializes page and cropping area with the values
class CropAreaInitialized extends CropEvent {
  /// Create an event instance
  CropAreaInitialized({
    this.areaInitial,
    required this.image,
    required this.screenSize,
    required this.positionImage,
    required this.defaultAreaInitial,
    required this.orientation,
    this.deviceOrientation,  // Add these new parameters
    this.previewSize,
  });

  /// Image contour in case it is found
  final Area? areaInitial;

  /// Default area defined in case image contour is not found
  final Area defaultAreaInitial;

  /// Image to crop
  final File image;

  /// Screen size
  final Size screenSize;

  /// Position of the image in the screen
  final Rect positionImage;

  /// Device orientation when photo was taken
  final NativeDeviceOrientation? deviceOrientation;  // Add this

  /// Preview size from camera
  final Size? previewSize;  // Add this

  final int orientation;  // Add this field


  @override
  List<Object?> get props => [
    areaInitial,
    image,
    screenSize,
    positionImage,
    deviceOrientation,  // Add these to props
    previewSize,
    orientation
  ];
}


/// Define which dot is the one being moved
enum DotPosition {
  /// The top right dot
  topRight,

  /// The top left dot
  topLeft,

  /// The bottom right dot
  bottomRight,

  /// The bottom left dot
  bottomLeft,

  /// The all dots
  all,
}

/// Move the dot to the new position
class CropDotMoved extends CropEvent {
  /// Create an event instance
  CropDotMoved({
    required this.deltaX,
    required this.deltaY,
    required this.dotPosition,
  });

  /// The delta of the movement in X axis
  final double deltaX;

  /// The delta of the movement in Y axis
  final double deltaY;

  /// Define which dot moved
  final DotPosition dotPosition;

  @override
  List<Object?> get props => [
        deltaX,
        deltaY,
        dotPosition,
      ];
}

/// To the cropped image apply the perspective adjustment
class CropPhotoByAreaCropped extends CropEvent {
  /// Create an event instance
  CropPhotoByAreaCropped(this.image);

  /// Image cropped
  final File image;

  @override
  List<Object?> get props => [image];
}
