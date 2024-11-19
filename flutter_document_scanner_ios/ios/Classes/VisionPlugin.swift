//
//  VisionPlugin.swift
//  flutter_document_scanner_ios
//
//  Created by Christian Betancourt Barajas on 6/11/23.
//

import Flutter
import Foundation
import Vision
import UIKit


extension UIImage.Orientation {
    func toCGImagePropertyOrientation() -> CGImagePropertyOrientation {
        switch self {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

class VisionPlugin {
    func findContourPhoto(
            result: @escaping FlutterResult,
            byteData: FlutterStandardTypedData,
            minContourArea: Double,
            deviceOrientation: Int?,
            sensorOrientation: Int?,
            previewWidth: Double?,
            previewHeight: Double?
        ) {
        guard let image = UIImage(data: byteData.data) else {
            result(FlutterError(code: "FIND_CONTOUR_PHOTO", message: "Invalid ByteData", details: nil))
            return
        }

        // Get the base image orientation
        var imageOrientation = image.imageOrientation

        // First apply sensor orientation if available
        if let sensorOrientation = sensorOrientation {
            // Convert sensor orientation (in degrees) to UIImage.Orientation
            switch sensorOrientation {
            case 0:
                imageOrientation = .up
            case 90:
                imageOrientation = .right
            case 180:
                imageOrientation = .down
            case 270:
                imageOrientation = .left
            default:
                imageOrientation = .up
            }
        }

        // Then apply device orientation if available
        if let deviceOrientation = deviceOrientation {
            // Store the current orientation to combine with device orientation
            let currentOrientation = imageOrientation

            // Convert Flutter device orientation to rotation angle
            // 0 = portraitUp, 1 = landscapeLeft, 2 = portraitDown, 3 = landscapeRight
            let deviceRotation: Int
            switch deviceOrientation {
            case 0: // portraitUp
                deviceRotation = 0
            case 1: // landscapeLeft
                deviceRotation = 270
            case 2: // portraitDown
                deviceRotation = 180
            case 3: // landscapeRight
                deviceRotation = 90
            default:
                deviceRotation = 0
            }

            // Convert current orientation to degrees
            let currentDegrees: Int
            switch currentOrientation {
            case .up:
                currentDegrees = 0
            case .right:
                currentDegrees = 90
            case .down:
                currentDegrees = 180
            case .left:
                currentDegrees = 270
            default:
                currentDegrees = 0
            }

            // Combine rotations
            let totalRotation = (currentDegrees + deviceRotation) % 360

            // Convert back to UIImage.Orientation
            switch totalRotation {
            case 0:
                imageOrientation = .up
            case 90:
                imageOrientation = .right
            case 180:
                imageOrientation = .down
            case 270:
                imageOrientation = .left
            default:
                imageOrientation = .up
            }
        }

        guard let cgImage = image.cgImage else {
            result(FlutterError(code: "FIND_CONTOUR_PHOTO", message: "Invalid CGImage", details: nil))
            return
        }

        let request = VNDetectRectanglesRequest { request, error in
            DispatchQueue.main.async {
                guard let results = request.results as? [VNRectangleObservation],
                      let rectangle = results.first else {
                    result(nil)
                    return
                }

                // Convert points using orientation
                let topLeft = self.convertToPointOfInterest(
                    from: rectangle.topLeft,
                    imageSize: image.size,
                    orientation: imageOrientation
                )
                let topRight = self.convertToPointOfInterest(
                    from: rectangle.topRight,
                    imageSize: image.size,
                    orientation: imageOrientation
                )
                let bottomLeft = self.convertToPointOfInterest(
                    from: rectangle.bottomLeft,
                    imageSize: image.size,
                    orientation: imageOrientation
                )
                let bottomRight = self.convertToPointOfInterest(
                    from: rectangle.bottomRight,
                    imageSize: image.size,
                    orientation: imageOrientation
                )

                // Use preview dimensions if provided, otherwise use image dimensions
                let width = previewWidth ?? Double(image.size.width)
                let height = previewHeight ?? Double(image.size.height)

                let resultEnd = [
                    "height": NSNumber(value: Int(height)),
                    "width": NSNumber(value: Int(width)),
                    "orientation": NSNumber(value: imageOrientation.rawValue),
                    "points": [
                        [
                            "x": NSNumber(value: topLeft.x),
                            "y": NSNumber(value: topLeft.y),
                        ],
                        [
                            "x": NSNumber(value: topRight.x),
                            "y": NSNumber(value: topRight.y),
                        ],
                        [
                            "x": NSNumber(value: bottomRight.x),
                            "y": NSNumber(value: bottomRight.y),
                        ],
                        [
                            "x": NSNumber(value: bottomLeft.x),
                            "y": NSNumber(value: bottomLeft.y),
                        ],
                    ],
                ]

                result(resultEnd)
            }
        }

        // Configure request
        request.minimumAspectRatio = 0.5
        request.maximumAspectRatio = 1.5
        request.minimumSize = 0.2
        request.maximumObservations = 1

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: imageOrientation.toCGImagePropertyOrientation())
        do {
            try handler.perform([request])
        } catch {
            result(FlutterError(code: "FIND_CONTOUR_PHOTO", message: error.localizedDescription, details: nil))
        }
    }
    
   private func convertToPointOfInterest(
       from point: CGPoint,
       imageSize: CGSize,
       orientation: UIImage.Orientation
   ) -> CGPoint {
       // The Vision framework returns normalized coordinates (0.0 to 1.0)
       // We need to convert these to actual pixel coordinates while handling orientation

       switch orientation {
       case .right: // 3
           // When rotated right, swap x/y and adjust y
           return CGPoint(
               x: point.y * imageSize.width,
               y: (1 - point.x) * imageSize.height
           )

       case .left: // 2
           // When rotated left, swap x/y and adjust x
           return CGPoint(
               x: (1 - point.y) * imageSize.width,
               y: point.x * imageSize.height
           )

       case .down: // 1
           // When upside down, invert both coordinates
           return CGPoint(
               x: (1 - point.x) * imageSize.width,
               y: (1 - point.y) * imageSize.height
           )

       default: // .up (0)
           // Normal orientation
           return CGPoint(
               x: point.x * imageSize.width,
               y: point.y * imageSize.height
           )
       }
   }

    func adjustingPerspective(
        result: @escaping FlutterResult,
        byteData: FlutterStandardTypedData,
        points: Array<Dictionary<String, Double>>
    ) {
        guard let image = UIImage(data: byteData.data) else {
            result(FlutterError(code: "ADJUSTING_PERSPECTIVE", message: "Invalid ByteData", details: nil))
            return
        }

        // Create oriented CIImage, maintaining original orientation
        guard let ciImage = CIImage(image: image) else {
            result(FlutterError(code: "ADJUSTING_PERSPECTIVE", message: "Invalid CIImage", details: nil))
            return
        }

        // The points we receive are already adjusted for orientation,
        // so we can use them directly
        guard points.count == 4,
              let topLeft = CGPoint(dictionary: points[0]),
              let topRight = CGPoint(dictionary: points[1]),
              let bottomRight = CGPoint(dictionary: points[2]),
              let bottomLeft = CGPoint(dictionary: points[3]) else {
            result(FlutterError(code: "ADJUSTING_PERSPECTIVE", message: "Invalid Points", details: nil))
            return
        }

        guard let perspectiveCorrection = CIFilter(name: "CIPerspectiveCorrection") else {
            result(FlutterError(
                code: "ADJUSTING_PERSPECTIVE",
                message: "Could not create perspective correction filter",
                details: nil
            ))
            return
        }

        // Apply perspective correction
        perspectiveCorrection.setValue(ciImage, forKey: kCIInputImageKey)
        perspectiveCorrection.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        perspectiveCorrection.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        perspectiveCorrection.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        perspectiveCorrection.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")

        guard let outputImage = perspectiveCorrection.outputImage else {
            result(FlutterError(
                code: "ADJUSTING_PERSPECTIVE",
                message: "Could not get output image from filter",
                details: nil
            ))
            return
        }

        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            result(FlutterError(code: "ADJUSTING_PERSPECTIVE",
                              message: "Could not create CGImage from CIImage",
                              details: nil))
            return
        }

        // Create new UIImage maintaining the original orientation
        let uiImage = UIImage(cgImage: cgImage,
                             scale: image.scale,
                             orientation: image.imageOrientation)

        guard let imageData = uiImage.jpegData(compressionQuality: 1) else {
            result(FlutterError(code: "ADJUSTING_PERSPECTIVE",
                              message: "Could not get JPEG data from UIImage",
                              details: nil))
            return
        }

        result(FlutterStandardTypedData(bytes: imageData))
    }
    
    func applyFilter(
        result: @escaping FlutterResult,
        byteData: FlutterStandardTypedData,
        filter: Int
    ) {
        guard let image = UIImage(data: byteData.data) else {
            result(FlutterError(code: "APPLY_FILTER", message: "Invalid ByteData", details: nil))
            return
        }
        
        guard let ciImage = CIImage(image: image) else {
            result(FlutterError(code: "ADJUSTING_PERSPECTIVE", message: "Invalid CIImage", details: nil))
            return
        }
        
        switch filter {
            // Gray
        case 2:
            guard let grayFilter = CIFilter(name: "CIColorControls") else {
                result(FlutterError(code: "APPLY_FILTER", message: "Could not make filter", details: nil))
                break
            }
            
            grayFilter.setValue(ciImage, forKey: kCIInputImageKey)
            grayFilter.setValue(0, forKey: kCIInputSaturationKey)
            
            guard let output = grayFilter.outputImage else {
                result(FlutterError(code: "APPLY_FILTER", message: "Could not apply filter", details: nil))
                break
            }
            
            let context = CIContext(options: nil)
            guard let cgimg = context.createCGImage(output, from: output.extent) else {
                result(FlutterError(code: "APPLY_FILTER", message: "Could not create CGImage", details: nil))
                break
            }
            
            let uiImage = UIImage(cgImage: cgimg)
            guard let imageData = uiImage.jpegData(compressionQuality: 1) else {
                result(FlutterError(
                    code: "APPLY_FILTER",
                    message: "Could not get JPEG data from UIImage",
                    details: nil
                ))
                return
            }
            
            result(FlutterStandardTypedData(bytes: imageData))
            break
            
            // Eco
        case 3:
            guard let colorMonochromeFilter = CIFilter(name: "CIColorMonochrome") else {
                result(FlutterError(
                    code: "APPLY_FILTER",
                    message: "Could not make color mono chrome filter",
                    details: nil
                ))
                break
            }
            
            colorMonochromeFilter.setValue(ciImage, forKey: kCIInputImageKey)
            colorMonochromeFilter.setValue(CIColor(color: UIColor.white), forKey: "inputColor")
            colorMonochromeFilter.setValue(1, forKey: "inputIntensity")
            
            guard let monochromeImage = colorMonochromeFilter.outputImage else {
                result(FlutterError(
                    code: "APPLY_FILTER",
                    message: "Could not apply color mono chrome filter",
                    details: nil
                ))
                break
            }
            
            
            guard let colorControlsFilter = CIFilter(name: "CIColorControls") else {
                result(FlutterError(code: "APPLY_FILTER", message: "Could not make color control filter", details: nil))
                break
            }
            
            colorControlsFilter.setValue(monochromeImage, forKey: kCIInputImageKey)
            colorControlsFilter.setValue(0, forKey: "inputBrightness")
            colorControlsFilter.setValue(1, forKey: "inputContrast")
            
            guard let colorControlsImage = colorControlsFilter.outputImage else {
                result(FlutterError(code: "APPLY_FILTER", message: "Could not apply color control filter", details: nil))
                break
            }
            
            
            guard let unsharpMaskFilter = CIFilter(name: "CIUnsharpMask") else {
                result(FlutterError(code: "APPLY_FILTER", message: "Could not make unsharp filter", details: nil))
                break
            }
            
            unsharpMaskFilter.setValue(colorControlsImage, forKey: kCIInputImageKey)
            unsharpMaskFilter.setValue(1, forKey: kCIInputRadiusKey)
            unsharpMaskFilter.setValue(2, forKey: kCIInputIntensityKey)
            
            guard let unsharpMaskImage = unsharpMaskFilter.outputImage else {
                result(FlutterError(code: "APPLY_FILTER", message: "Could not apply unsharp filter", details: nil))
                break
            }
            
            
            let context = CIContext(options: nil)
            guard let cgimg = context.createCGImage(unsharpMaskImage, from: unsharpMaskImage.extent) else {
                result(FlutterError(code: "APPLY_FILTER", message: "Could not create CGImage", details: nil))
                break
            }
            
            let uiImage = UIImage(cgImage: cgimg)
            guard let imageData = uiImage.jpegData(compressionQuality: 1) else {
                result(FlutterError(code: "APPLY_FILTER", message: "Could not get JPEG data from UIImage", details: nil))
                return
            }
            
            result(FlutterStandardTypedData(bytes: imageData))
            break
            
        default:
            result(byteData)
        }
    }
}

extension CGPoint {
    init?(dictionary: [String: Double]) {
        guard let x = dictionary["x"], let y = dictionary["y"] else {
            return nil
        }
        self.init(x: x, y: y)
    }
}

