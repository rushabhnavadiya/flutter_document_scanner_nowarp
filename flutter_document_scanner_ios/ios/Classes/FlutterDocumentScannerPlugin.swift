//
//  FlutterDocumentScanner.swift
//  flutter_document_scanner_ios
//
//  Created by Christian Betancourt Barajas on 28/04/23.
//

import Flutter
import UIKit

enum ErrorsPlugin : Error {
    case stringError(String )
}

public class FlutterDocumentScannerPlugin: NSObject, FlutterPlugin {
    private let visionPlugin = VisionPlugin() // Add this line

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_document_scanner_ios", binaryMessenger: registrar.messenger())
        let instance = FlutterDocumentScannerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }


    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch (call.method) {
        case "findContourPhoto":
                guard let args = call.arguments as? [String: Any],
                      let byteData = args["byteData"] as? FlutterStandardTypedData,
                      let minContourArea = args["minContourArea"] as? Double else {
                    result(FlutterError(
                        code: "FIND_CONTOUR_PHOTO",
                        message: "Invalid arguments",
                        details: nil
                    ))
                    return
                }

                // Extract optional parameters
                let deviceOrientation = args["deviceOrientation"] as? Int
                let sensorOrientation = args["sensorOrientation"] as? Int
                let previewWidth = args["previewWidth"] as? Double
                let previewHeight = args["previewHeight"] as? Double

                visionPlugin.findContourPhoto(
                    result: result,
                    byteData: byteData,
                    minContourArea: minContourArea,
                    deviceOrientation: deviceOrientation,
                    sensorOrientation: sensorOrientation,
                    previewWidth: previewWidth,
                    previewHeight: previewHeight
                )
                break;
            
        case "adjustingPerspective":
            do {
                guard let arguments = call.arguments as? Dictionary<String, Any>
                        
                else {
                    throw ErrorsPlugin.stringError("Invalid Arguments")
                }
                
                let visionPlugin = VisionPlugin()
                
                visionPlugin.adjustingPerspective(
                    result: result,
                    byteData: arguments["byteData"] as! FlutterStandardTypedData,
                    points: arguments["points"] as! Array<Dictionary<String, Double>>
                )
                
            } catch {
                result(FlutterError(
                    code: "FlutterDocumentScanner-Error",
                    message: "adjustingPerspective \(error.localizedDescription)",
                    details: error
                ))
            }
            break;
            
        case "applyFilter":
            do {
                guard let arguments = call.arguments as? Dictionary<String, Any>
                        
                else {
                    throw ErrorsPlugin.stringError("Invalid Arguments")
                }
                
                let visionPlugin = VisionPlugin()
                
                visionPlugin.applyFilter(
                    result: result,
                    byteData: arguments["byteData"] as! FlutterStandardTypedData,
                    filter: arguments["filter"] as! Int
                )
                
            } catch {
                result(FlutterError(
                    code: "FlutterDocumentScanner-Error",
                    message: "applyFilter \(error.localizedDescription)",
                    details: error
                ))
            }
            break;
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
