import Foundation
import Vision
import UIKit

extension ViewController {
    
    func initializeModel() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let model = try yolov5s(configuration: MLModelConfiguration()).model
                let vnCoreMLModel = try VNCoreMLModel(for: model)
                let request = VNCoreMLRequest(model: vnCoreMLModel)
                request.imageCropAndScaleOption = .scaleFill
                self.coreMLRequest = request
            } catch let error {
                fatalError(error.localizedDescription)
            }
        }
    }

    func detectPartsVisualizing(ciImage:CIImage) -> CIImage {
        frame += 1
        DispatchQueue.main.async { [weak self] in
            self?.messageLabel.isHidden = false
            self?.messageLabel.text = "\((self?.frame)!)frames proccessed"
        }
        guard let coreMLRequest = coreMLRequest else {fatalError("Model initialization failed.")}
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])

        do {
            try handler.perform([coreMLRequest])
            
            guard let detectResults = coreMLRequest.results as? [VNDetectedObjectObservation] else { return ciImage }
            
            var detections:[Detection] = []
            for detectResult in detectResults {
                let flippedBox = CGRect(x: detectResult.boundingBox.minX, y: 1 - detectResult.boundingBox.maxY, width: detectResult.boundingBox.width, height: detectResult.boundingBox.height)
                let box = VNImageRectForNormalizedRect(flippedBox, Int(ciImage.extent.width), Int(ciImage.extent.height))
                let confidence = detectResult.confidence
                // Assume a single class "golfball" for all detections
                let label = "golfball"
                let detection = Detection(box: box, confidence: confidence, label: label, color: .red)
                detections.append(detection)
            }
                let newImage = drawRectOnImage(detections, ciImage)
            return newImage!.resize(as: ciImage.extent.size)
        } catch let error {
            print(error)
            return ciImage
        }
    }
    
    func detect(image:UIImage) {
        guard let ciImage = CIImage(image: image) else { fatalError("Image failed.") }
        let start = Date()
        // Run SAHI tiling detection
        let tileSize = CGSize(width: sahiTileWidth, height: sahiTileHeight)
        let detections = detectOnTiles(ciImage: ciImage,
                                       tileSize: tileSize,
                                       overlap: sahiOverlap,
                                       iouThreshold: sahiIoUThreshold,
                                       scoreThreshold: sahiScoreThreshold)
        let end = Date()
        let diff = end.timeIntervalSince(start)
        print("SAHI detect time: \(diff)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let newImage = self.drawRectOnImage(detections, ciImage) {
                self.imageView.image = UIImage(ciImage: newImage)
            } else {
                self.imageView.image = UIImage(ciImage: ciImage)
            }
        }
    }
//    
//    func addAnalizingResult(image:UIImage,detections:[Detection]) {
//        var partsArray:[AnalizingResults.Result.Parts] = []
//        for detection in detections {
//            if let partsLabelIndex = classLabels.firstIndex(of: detection.label!) {
//                let bbox = AnalizingResults.Result.Parts.BBox(x: Double(detection.box.minX), y: Double(detection.box.minY), w: Double(detection.box.width), h: Double(detection.box.height))
//                let parts = AnalizingResults.Result.Parts(partsLabel: partsLabelIndex, bbox: bbox)
//                partsArray.append(parts)
//            }
//        }
//        guard let png = image.pngData() else {
//            self.presentAlert("解析できませんでした")
//            return
//        }
//        
//        let fileName = UUID().uuidString + ".png"
//            do {
//                let pngURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(fileName)
//                try png.write(to: pngURL)
//                let result = AnalizingResults.Result(filePath: fileName, angleLabel: 0, parts: partsArray)
//                self.analizingResults.results.append(result)
//                print(self.analizingResults)
//            } catch {
//                    self.presentAlert("解析できませんでした")
//                    return
//                }
//        }
}

