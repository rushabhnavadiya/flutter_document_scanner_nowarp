// Copyright (c) 2021, Christian Betancourt
// https://github.com/criistian14
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'dart:typed_data';  // Add this import
import 'package:image/image.dart' as img;  // Add this import
import 'package:flutter/foundation.dart' show debugPrint;  // Add this at the top
import 'package:camera/camera.dart';
import 'package:flutter_document_scanner/src/bloc/app/app.dart';
import 'package:flutter_document_scanner/src/bloc/crop/crop.dart';
import 'package:flutter_document_scanner/src/bloc/edit/edit.dart';
import 'package:flutter_document_scanner/src/document_scanner_controller.dart';
import 'package:flutter_document_scanner/src/utils/image_utils.dart';
import 'package:flutter_document_scanner_platform_interface/flutter_document_scanner_platform_interface.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:flutter_document_scanner/src/models/area.dart';
import 'dart:math';
import 'package:equatable/equatable.dart';

/// Controls interactions throughout the application by means
/// of the [DocumentScannerController]
class AppBloc extends Bloc<AppEvent, AppState> {
  /// Create instance AppBloc
  AppBloc({
    required ImageUtils imageUtils,
  })  : _imageUtils = imageUtils,
        super(AppState.init()) {
    on<AppCameraInitialized>(_cameraInitialized);
    on<AppPhotoTaken>(_photoTaken);
    on<AppExternalImageContoursFound>(_externalImageContoursFound);
    on<AppPageChanged>(_pageChanged);
    on<AppPhotoCropped>(_photoCropped);
    on<AppLoadCroppedPhoto>(_loadCroppedPhoto);
    on<AppFilterApplied>(_filterApplied);
    on<AppNewEditedImageLoaded>(_newEditedImageLoaded);
    on<AppStartedSavingDocument>(_startedSavingDocument);
    on<AppDocumentSaved>(_documentSaved);
  }

  final ImageUtils _imageUtils;

  CameraController? _cameraController;
  late XFile? _pictureTaken;

  /// Initialize [CameraController]
  /// based on the parameters sent by [AppCameraInitialized]
  ///
  /// [AppCameraInitialized.cameraLensDirection] for [CameraLensDirection]
  /// [AppCameraInitialized.resolutionCamera] for the [ResolutionPreset] camera
  Future<void> _cameraInitialized(
    AppCameraInitialized event,
    Emitter<AppState> emit,
  ) async {
    emit(
      state.copyWith(
        statusCamera: AppStatus.loading,
      ),
    );

    final cameras = await availableCameras();
    final camera = cameras.firstWhere(
      (camera) => camera.lensDirection == event.cameraLensDirection,
      orElse: () => cameras.first,
    );

    if (_cameraController != null) {
      await _cameraController?.dispose();
      _cameraController = null;
    }

    _cameraController = CameraController(
      camera,
      event.resolutionCamera,
      enableAudio: false,
    );

    await _cameraController!.initialize();

    emit(
      state.copyWith(
        statusCamera: AppStatus.success,
        cameraController: _cameraController,
      ),
    );
  }

  Future<void> _photoTaken(
      AppPhotoTaken event,
      Emitter<AppState> emit,
      ) async {
    print("🎬 _photoTaken started");  // Add this
    emit(state.copyWith(
      statusTakePhotoPage: AppStatus.loading,
    ));
    if (_cameraController == null) return;

    try {
      print("📸 Starting photo capture in try block");

      final previewSize = _cameraController!.value.previewSize;
      final sensorOrientation = _cameraController!.description.sensorOrientation;
      final deviceOrientation = await NativeDeviceOrientationCommunicator()
          .orientation(useSensor: true);
      print("📱 Orientations - Device: $deviceOrientation, Sensor: $sensorOrientation");
      print("📐 Preview size: $previewSize");

      _pictureTaken = await _cameraController!.takePicture();

      // Handle rotation if needed
      Uint8List imageBytes;
      if ((deviceOrientation == NativeDeviceOrientation.landscapeLeft ||
          deviceOrientation == NativeDeviceOrientation.landscapeRight) &&
          !Platform.isIOS) {
        img.Image? capturedImage = img.decodeImage(
            await _pictureTaken!.readAsBytes());

        if (deviceOrientation == NativeDeviceOrientation.landscapeLeft) {
          capturedImage = img.copyRotate(capturedImage!, angle: 270);
        } else {
          capturedImage = img.copyRotate(capturedImage!, angle: 90);
        }
        imageBytes = Uint8List.fromList(img.encodeJpg(capturedImage));
      } else {
        imageBytes = await _pictureTaken!.readAsBytes();
      }
      print("🖼️ Image bytes processed, length: ${imageBytes.length}");

      final contour = await _imageUtils.findContourPhoto(
        imageBytes,
        minContourArea: event.minContourArea ?? 0,
        deviceOrientation: deviceOrientation,
        sensorOrientation: sensorOrientation,
        previewWidth: previewSize?.width,
        previewHeight: previewSize?.height,
      );
      print("📍 Contour received: ${contour != null ? 'yes' : 'no'}");
      if (contour != null) {
        print("📍 Contour points: ${contour.points}");
      }
      print("⚡ After findContourPhoto, before Area processing");
      Area? area;
      if (contour != null) {
        print("🎯 Processing contour points to create Area");

        // Convert contour points to top/bottom points
        int numTopFound = 0;
        int numBottomFound = 0;

        Point<double> top1 = const Point<double>(0, 0);
        Point<double> top2 = const Point<double>(0, 0);
        Point<double> bottom1 = const Point<double>(0, 0);
        Point<double> bottom2 = const Point<double>(0, 0);
        Point<double> lastTopFound = const Point<double>(0, 1000000);
        Point<double> lastBottomFound = const Point<double>(0, 0);

        // Move the point sorting logic here
        for (int i = 0; i < 4; i++) {
          for (final point in contour.points) {
            if (point.y > lastBottomFound.y) {
              if (bottom1.y == 0 || point.y != bottom1.y) {
                lastBottomFound = point;
              }
            }

            if (point.y < lastTopFound.y) {
              if (top1.y == 0 || point.y != top1.y) {
                lastTopFound = point;
              }
            }
          }

          if (numTopFound < 2) {
            if (numTopFound == 0) {
              top1 = lastTopFound;
            } else {
              top2 = lastTopFound;
            }
            numTopFound++;
          }

          if (numBottomFound < 2) {
            if (numBottomFound == 0) {
              bottom1 = lastBottomFound;
            } else {
              bottom2 = lastBottomFound;
            }
            numBottomFound++;
          }

          lastTopFound = const Point(0, 1000000);
          lastBottomFound = const Point(0, 0);
        }

        // Sort points
        Point<double> topLeft, topRight, bottomLeft, bottomRight;

        if (top1.x < top2.x) {
          topLeft = top1;
          topRight = top2;
        } else {
          topRight = top1;
          topLeft = top2;
        }

        if (bottom1.x < bottom2.x) {
          bottomLeft = bottom1;
          bottomRight = bottom2;
        } else {
          bottomRight = bottom1;
          bottomLeft = bottom2;
        }

        // Check for equal points
        final anyEqualPoints = topRight == topLeft ||
            topRight == bottomLeft ||
            topRight == bottomRight ||
            topLeft == bottomLeft ||
            topLeft == bottomRight ||
            bottomLeft == bottomRight;

        if (!anyEqualPoints) {
          area = Area(
            topRight: topRight,
            topLeft: topLeft,
            bottomLeft: bottomLeft,
            bottomRight: bottomRight,
            orientation: _calculateEffectiveOrientation(
              deviceOrientation,
              sensorOrientation,
            ),
            imageWidth: contour.width ?? 0,
            imageHeight: contour.height ?? 0,
          );
        }
      }
      print("🔲 Area created: ${area != null ? 'yes' : 'no'}");
      if (area != null) {
        print("""🔲 Area details:
        topLeft: ${area.topLeft}
        topRight: ${area.topRight}
        bottomLeft: ${area.bottomLeft}
        bottomRight: ${area.bottomRight}
        orientation: ${area.orientation}
        dimensions: ${area.imageWidth}x${area.imageHeight}""");
      }

      final fileImage = File(_pictureTaken!.path);
      print("📤 About to emit new state with area: ${area != null}");

      emit(state.copyWith(
        statusTakePhotoPage: AppStatus.success,
        pictureInitial: fileImage,
        contourInitial: area,
        deviceOrientation: deviceOrientation,
        previewSize: previewSize,
      ));
      print("💫 First emit complete");
      print("📤 Emitting new state with area");
      emit(state.copyWith(
        currentPage: AppPages.cropPhoto,
      ));
      print("🏁 _photoTaken completed successfully");
    } catch (e) {
      print("💥 Error in _photoTaken: $e");
      emit(state.copyWith(
        statusTakePhotoPage: AppStatus.failure,
      ));
    }
  }

  /// Calculates the effective orientation based on device and sensor orientations
  /// Returns an integer representing the final orientation:
  /// 0 = up, 1 = down, 2 = left, 3 = right
  int _calculateEffectiveOrientation(
      NativeDeviceOrientation? deviceOrientation,
      int? sensorOrientation,
      ) {
    // If we don't have both orientations, return the default (up) orientation
    if (deviceOrientation == null || sensorOrientation == null) {
      return 0;
    }

    // Convert device orientation to match Area model orientation values
    int orientationValue;
    switch (deviceOrientation) {
      case NativeDeviceOrientation.portraitUp:
        orientationValue = 0;  // up
        break;
      case NativeDeviceOrientation.portraitDown:
        orientationValue = 1;  // down
        break;
      case NativeDeviceOrientation.landscapeLeft:
        orientationValue = 2;  // left
        break;
      case NativeDeviceOrientation.landscapeRight:
        orientationValue = 3;  // right
        break;
      default:
        orientationValue = 0;  // default to up
    }

    // Get the non-null sensor orientation value
    int sensorValue = sensorOrientation;  // At this point we know it's not null

    // Adjust orientation based on sensor rotation
    if (sensorValue == 90) {
      orientationValue = (orientationValue + 1) % 4;
    } else if (sensorValue == 180) {
      orientationValue = (orientationValue + 2) % 4;
    } else if (sensorValue == 270) {
      orientationValue = (orientationValue + 3) % 4;
    }

    return orientationValue;
  }

  /// Find the contour from an external image like gallery
  Future<void> _externalImageContoursFound(
      AppExternalImageContoursFound event,
      Emitter<AppState> emit,
      ) async {
    try {
      final deviceOrientation = await NativeDeviceOrientationCommunicator()
          .orientation(useSensor: true);

      final byteData = await event.image.readAsBytes();
      final imgData = img.decodeImage(byteData);

      debugPrint('''📸 Image Analysis:
            Device orientation: $deviceOrientation
            Image dimensions: ${imgData?.width}x${imgData?.height}
            Natural orientation: ${(imgData?.width ?? 0) > (imgData?.height ?? 0) ? 'landscape' : 'portrait'}
            EXIF exists: ${imgData?.exif != null}
            EXIF orientation: ${imgData?.exif?.imageIfd?.orientation}
        ''');

      // Determine effective orientation
      bool isNaturallyLandscape = (imgData?.width ?? 0) > (imgData?.height ?? 0);
      int effectiveOrientation;

      if (isNaturallyLandscape) {
        switch (deviceOrientation) {
          case NativeDeviceOrientation.landscapeLeft:
            effectiveOrientation = 2;  // landscape left
            break;
          case NativeDeviceOrientation.landscapeRight:
            effectiveOrientation = 3;  // landscape right
            break;
          default:
            effectiveOrientation = 2;  // default to landscape left
            break;
        }
      } else {
        switch (deviceOrientation) {
          case NativeDeviceOrientation.portraitUp:
            effectiveOrientation = 0;
            break;
          case NativeDeviceOrientation.portraitDown:
            effectiveOrientation = 1;
            break;
          default:
            effectiveOrientation = 0;
            break;
        }
      }

      debugPrint('📱 Effective orientation: $effectiveOrientation');

      // Rest of your contour finding code...
      final contour = await _imageUtils.findContourPhoto(
        byteData,
        minContourArea: event.minContourArea ?? 0,
        deviceOrientation: deviceOrientation,
        sensorOrientation: null,
        previewWidth: imgData?.width?.toDouble(),
        previewHeight: imgData?.height?.toDouble(),
      );

    Area? area;  // Declare as local variable
    if (contour != null) {
      final sortedPoints = _sortPoints(contour.points);
      area = Area(
        topLeft: sortedPoints[0],
        topRight: sortedPoints[1],
        bottomRight: sortedPoints[2],
        bottomLeft: sortedPoints[3],
        orientation: effectiveOrientation,  // Use our calculated orientation
        imageWidth: contour.width ?? imgData?.width ?? 0,
        imageHeight: contour.height ?? imgData?.height ?? 0,
      );

      debugPrint('''📐 Created Area:
                  Orientation: ${area.orientation}
                  Points:
                    TL: ${area.topLeft}
                    TR: ${area.topRight}
                    BL: ${area.bottomLeft}
                    BR: ${area.bottomRight}
                  Dimensions: ${area.imageWidth}x${area.imageHeight}
              ''');
    }

    debugPrint('📤 Emitting first state update...');
      final updatedState = state.copyWith(
        pictureInitial: event.image,
        contourInitial: area,
        deviceOrientation: deviceOrientation,
      );
      debugPrint('   New state: $updatedState');
      emit(updatedState);
      debugPrint('✅ First state update emitted');

      debugPrint('📤 Emitting page change to cropPhoto...');
      final cropState = state.copyWith(
        currentPage: AppPages.cropPhoto,
      );
      debugPrint('   New state: $cropState');
      emit(cropState);
      debugPrint('🏁 _externalImageContoursFound completed successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error in _externalImageContoursFound:');
      debugPrint('   Error: $e');
      debugPrint('   Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// When changing the page, the state will be initialized.
  Future<void> _pageChanged(
    AppPageChanged event,
    Emitter<AppState> emit,
  ) async {
    switch (event.newPage) {
      case AppPages.takePhoto:
        emit(
          state.copyWith(
            currentPage: event.newPage,
            statusTakePhotoPage: AppStatus.initial,
            statusCropPhoto: AppStatus.initial,
            contourInitial: null,
          ),
        );
        break;

      case AppPages.cropPhoto:
        emit(
          state.copyWith(
            currentPage: event.newPage,
            currentFilterType: FilterType.natural,
          ),
        );
        break;

      case AppPages.editDocument:
        emit(
          state.copyWith(
            currentPage: event.newPage,
            statusEditPhoto: AppStatus.initial,
            statusSavePhotoDocument: AppStatus.initial,
          ),
        );
        break;
    }
  }

  /// It will change the state and
  /// execute the event [CropPhotoByAreaCropped] to crop the image that is in
  /// the [CropBloc].
  Future<void> _photoCropped(
    AppPhotoCropped event,
    Emitter<AppState> emit,
  ) async {
    emit(
      state.copyWith(
        statusCropPhoto: AppStatus.loading,
      ),
    );
  }

  /// It will change the state and then change page to [AppPages.editDocument]
  Future<void> _loadCroppedPhoto(
    AppLoadCroppedPhoto event,
    Emitter<AppState> emit,
  ) async {
    emit(
      state.copyWith(
        statusCropPhoto: AppStatus.success,
        pictureCropped: event.image,
        contourInitial: event.area,
      ),
    );

    emit(
      state.copyWith(
        currentPage: AppPages.editDocument,
      ),
    );
  }

  /// It will change the state and
  /// execute the event [EditFilterChanged] to crop the image that is
  /// in the [EditBloc].
  Future<void> _filterApplied(
    AppFilterApplied event,
    Emitter<AppState> emit,
  ) async {
    if (event.filter == state.currentFilterType) return;

    emit(
      state.copyWith(
        currentFilterType: event.filter,
        statusEditPhoto: AppStatus.loading,
      ),
    );
  }

  /// It is called when the image filter changes
  Future<void> _newEditedImageLoaded(
    AppNewEditedImageLoaded event,
    Emitter<AppState> emit,
  ) async {
    emit(
      state.copyWith(
        statusEditPhoto:
            event.isSuccess ? AppStatus.success : AppStatus.failure,
      ),
    );
  }

  /// It will change the state and
  /// validate if image edited is valid.
  Future<void> _startedSavingDocument(
    AppStartedSavingDocument event,
    Emitter<AppState> emit,
  ) async {
    emit(
      state.copyWith(
        statusSavePhotoDocument: AppStatus.loading,
      ),
    );
  }

  /// Change state after saved the document
  Future<void> _documentSaved(
    AppDocumentSaved event,
    Emitter<AppState> emit,
  ) async {
    emit(
      state.copyWith(
        statusSavePhotoDocument:
            event.isSuccess ? AppStatus.success : AppStatus.failure,
      ),
    );
  }

  /// Sort points into a consistent order: [topLeft, topRight, bottomRight, bottomLeft]
  List<Point<double>> _sortPoints(List<Point<double>> points) {
    debugPrint('🔄 Sorting points: $points');
    if (points.length != 4) {
      debugPrint('⚠️ Expected 4 points, got ${points.length}');
      return points;
    }

    // First find center point
    double centerX = points.map((p) => p.x).reduce((a, b) => a + b) / 4;
    double centerY = points.map((p) => p.y).reduce((a, b) => a + b) / 4;
    debugPrint('📍 Center point: ($centerX, $centerY)');

    // Categorize points relative to center
    var topLeft = points[0];
    var topRight = points[0];
    var bottomLeft = points[0];
    var bottomRight = points[0];

    for (var point in points) {
      if (point.x <= centerX) {
        // Left points
        if (point.y <= centerY) {
          // Top left
          if (point.x + point.y < topLeft.x + topLeft.y) {
            topLeft = point;
          }
        } else {
          // Bottom left
          if (point.y - point.x > bottomLeft.y - bottomLeft.x) {
            bottomLeft = point;
          }
        }
      } else {
        // Right points
        if (point.y <= centerY) {
          // Top right
          if (point.x - point.y > topRight.x - topRight.y) {
            topRight = point;
          }
        } else {
          // Bottom right
          if (point.x + point.y > bottomRight.x + bottomRight.y) {
            bottomRight = point;
          }
        }
      }
    }

    final sortedPoints = [topLeft, topRight, bottomRight, bottomLeft];
    debugPrint('''✅ Sorted points:
    topLeft: $topLeft
    topRight: $topRight
    bottomRight: $bottomRight
    bottomLeft: $bottomLeft
  ''');

    return sortedPoints;
  }

  @override
  Future<void> close() async {
    await _cameraController?.dispose();
    return super.close();
  }
}
