//
//  ViewController.swift
//  CoreML-YOLOv5
//
//  Created by DAISUKE MAJIMA on 2021/12/28.
//

import UIKit
import PhotosUI
import Vision

class ViewController: UIViewController, PHPickerViewControllerDelegate {

    lazy var coreMLRequest:VNCoreMLRequest? = {
        do {
            let model = try yolov5s(configuration: MLModelConfiguration()).model
            let vnCoreMLModel = try VNCoreMLModel(for: model)
            let request = VNCoreMLRequest(model: vnCoreMLModel)
            request.imageCropAndScaleOption = .scaleFill
            return request
        } catch let error {
            print(error)
            return nil
        }
    }()
    
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        presentPhPicker()
    }
    
    func detect(image:UIImage) {
        guard let coreMLRequest = coreMLRequest else {fatalError("Model initialization failed.")}
        guard let ciImage = CIImage(image: image) else {fatalError("Image failed.")}
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])

        do {
            try handler.perform([coreMLRequest])
            guard let detectResults = coreMLRequest.results as? [VNDetectedObjectObservation] else { return }
            var detections:[Detection] = []
            for detectResult in detectResults {
                let flippedBox = CGRect(x: detectResult.boundingBox.minX, y: 1 - detectResult.boundingBox.maxY, width: detectResult.boundingBox.width, height: detectResult.boundingBox.height)
                let box = VNImageRectForNormalizedRect(flippedBox, Int(image.size.width), Int(image.size.height))
                print(box)
                let confidence = detectResult.confidence
                var label:String?
                if let recognizedResult = detectResult as? VNRecognizedObjectObservation {
                    label = recognizedResult.labels.first?.identifier
                }
                let detection = Detection(box: box, confidence: confidence, label: label)
                detections.append(detection)
            }
            DispatchQueue.main.async { [weak self] in
                guard let safeSelf = self else { return }
                let newImage = safeSelf.drawDetectionsOnImage(detections, image)
                safeSelf.imageView.image = newImage
            }
        } catch let error {
            print(error)
        }
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else { return }
        if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error  in
                if let image = image as? UIImage,  let safeSelf = self {
                    let correctOrientImage = safeSelf.getCorrectOrientationUIImage(uiImage: image)
                    safeSelf.detect(image: correctOrientImage)
                }
            }
        }
    }
    
    
    
    @IBAction func selectImageButtonTapped(_ sender: UIButton) {
        presentPhPicker()
    }
    
    @IBAction func saveButtonTapped(_ sender: UIButton) {
        UIImageWriteToSavedPhotosAlbum(imageView.image!, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            // we got back an error!
            let ac = UIAlertController(title: "Save error", message: error.localizedDescription, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
        } else {
            let ac = UIAlertController(title: NSLocalizedString("saved!",value: "saved!", comment: ""), message: NSLocalizedString("Saved in photo library",value: "Saved in photo library", comment: ""), preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
        }
    }
    
    func presentPhPicker(){
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 1
        configuration.filter = .images
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    func getCorrectOrientationUIImage(uiImage:UIImage) -> UIImage {
        var newImage = UIImage()
        let ciContext = CIContext()
        switch uiImage.imageOrientation.rawValue {
        case 1:
            guard let orientedCIImage = CIImage(image: uiImage)?.oriented(CGImagePropertyOrientation.down),
                  let cgImage = ciContext.createCGImage(orientedCIImage, from: orientedCIImage.extent) else { return uiImage}
            
            newImage = UIImage(cgImage: cgImage)
        case 3:
            guard let orientedCIImage = CIImage(image: uiImage)?.oriented(CGImagePropertyOrientation.right),
                  let cgImage = ciContext.createCGImage(orientedCIImage, from: orientedCIImage.extent) else { return uiImage}
            newImage = UIImage(cgImage: cgImage)
        default:
            newImage = uiImage
        }
        return newImage
    }
    
    private func drawDetectionsOnImage(_ detections: [Detection], _ image: UIImage) -> UIImage? {
        let imageSize = image.size
        let scale: CGFloat = 0.0
        UIGraphicsBeginImageContextWithOptions(imageSize, false, scale)

        image.draw(at: CGPoint.zero)
        let ctx = UIGraphicsGetCurrentContext()
        var rects:[CGRect] = []
        for detection in detections {
            rects.append(detection.box)
            if let labelText = detection.label {
            let text = "\(labelText) : \(round(detection.confidence*100))"
                let textRect  = CGRect(x: detection.box.minX + imageSize.width * 0.01, y: detection.box.minY + imageSize.width * 0.01, width: detection.box.width, height: detection.box.height)
                    
            let textStyle = NSMutableParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
                    
            let textFontAttributes = [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: textRect.width * 0.1, weight: .bold),
                NSAttributedString.Key.foregroundColor: UIColor.red,
                NSAttributedString.Key.paragraphStyle: textStyle
            ]
                    
            text.draw(in: textRect, withAttributes: textFontAttributes)
            }
        }
        ctx?.addRects(rects)
        ctx?.setStrokeColor(UIColor.red.cgColor)
        ctx?.setLineWidth(9.0)
        ctx?.strokePath()

        guard let drawnImage = UIGraphicsGetImageFromCurrentImageContext() else {
            fatalError()
        }

        UIGraphicsEndImageContext()
        return drawnImage
    }
}

struct Detection {
    let box:CGRect
    let confidence:Float
    let label:String?
}
