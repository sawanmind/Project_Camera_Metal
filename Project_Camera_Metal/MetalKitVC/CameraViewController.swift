//
//  ViewController.swift
//  Project_Camera_Metal
//
//  Created by iOS Development on 7/2/18.
//  Copyright © 2018 Genisys. All rights reserved.
//


import UIKit
import Metal
import AVFoundation
import Vision

public class DynamicType<T> {
    public typealias Listener = (T) -> Void
    public var listener:Listener?
    public var value:T { didSet { listener?(value) } }
    public init(_ value:T) { self.value = value }
    public func bind(listner:Listener?) { self.listener = listner ; listener?(value) }
}



internal final class CameraViewController: MTKViewController {
    
    
    var session: MetalCameraSession?
    let imageViewSize = UIScreen.main.bounds.size
    var faceBox : UIView? = nil
    var previewView = PreviewView()
    
    
    //MARK: Text Detection Properties
    private var textDetectionRequest: VNDetectTextRectanglesRequest?
    private var textObservations = [VNTextObservation]()
    
    //MARK: Face Detection Properties
    private var requests = [VNRequest]()
    private var faceDetectionRequest: VNRequest!
    
    
    private var detectedResultString:DynamicType<String?> = DynamicType(nil)
    
    lazy var labelView: UILabel = {
        let instance = UILabel()
        instance.contentMode = .scaleAspectFill
        instance.isUserInteractionEnabled = true
        instance.textAlignment = .center
        instance.textColor = UIColor.green
        instance.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        instance.layer.cornerRadius = 2.5
        instance.layer.masksToBounds = true
        instance.translatesAutoresizingMaskIntoConstraints = false
        instance.font = UIFont.systemFont(ofSize: 26, weight: .black)
        return instance
    }()
    
    func setuplabelView(){
        self.detectedResultString.bind(listner: {
            if $0 == nil {
                self.labelView.text = $0
            }
        })
        
        view.addSubview(labelView)
        labelView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        labelView.bottomAnchor.constraint(equalTo: view.bottomAnchor,constant: -10).isActive = true
        labelView.widthAnchor.constraint(equalTo: view.widthAnchor,constant: -20).isActive = true
        labelView.heightAnchor.constraint(equalToConstant: 36).isActive = true
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        session = MetalCameraSession(pixelFormat: .rgb, captureDevicePosition: .front, delegate: self)
        self.view.addSubview(previewView)
        previewView.frame = self.view.frame
        //configureTextDetection()
        configureFaceDetection()
        setuplabelView()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.session?.start()
        
    }
    
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        session?.stop()
    }
}

// MARK: - MetalCameraSessionDelegate
extension CameraViewController: MetalCameraSessionDelegate {
    
    func metalCameraSession(_ session: MetalCameraSession, didReceiveFrameAsTextures textures: [MTLTexture], withTimestamp timestamp: Double) {
        self.texture = textures[0]
    }
    
    func metalCameraSession(_ cameraSession: MetalCameraSession, didUpdateState state: MetalCameraSessionState, error: MetalCameraSessionError?) {
        
        if error == .captureSessionRuntimeError {
            cameraSession.start()
        }
        
        NSLog("Session changed state to \(state) with error: \(error?.localizedDescription ?? "None").")
    }
    
    func getSampleBuffer(sampleBuffer: CMSampleBuffer) {
        DispatchQueue(label: "com.sawanmind.objectDetection").async {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
                let exifOrientation = CGImagePropertyOrientation(rawValue: 3) else { return }
            var requestOptions: [VNImageOption : Any] = [:]
            
            if let cameraIntrinsicData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
                requestOptions = [.cameraIntrinsics : cameraIntrinsicData]
            }
            
            // perform image request for face recognition
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: requestOptions)
            
            do {
                try imageRequestHandler.perform(self.requests)
            }
                
            catch {
                print(error)
            }
        }
    }
    
    
    
}

//MARK:Object Detection
extension CameraViewController {
    
    
    private func configureTextDetection() {
        textDetectionRequest = VNDetectTextRectanglesRequest(completionHandler: handleTextDetection)
        textDetectionRequest?.reportCharacterBoxes = true
    }
    
 
    private func configureFaceDetection() {
         faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: handleFaces)
         self.requests = [faceDetectionRequest]
    }
    
    
    
    func handleObjectDetection(sampleBuffer:CMSampleBuffer){
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        var imageRequestOptions = [VNImageOption: Any]()
        if let cameraData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
            imageRequestOptions[.cameraIntrinsics] = cameraData
        }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: CGImagePropertyOrientation(rawValue: 6)!, options: imageRequestOptions)
        
        
        do {
            try imageRequestHandler.perform([faceDetectionRequest!])
        }
        catch {
            print("Error occured \(error)")
        }
    }
    
    //MARK:Face Detection
    
    func handleFaces(request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            //perform all the UI updates on the main queue
            guard let results = request.results as? [VNFaceObservation] else { return }
            print("face count = \(results.count) ")
            self.previewView.removeMask()
            
            for face in results {
                print(face)
                self.previewView.drawFaceboundingBox(face: face)
            }
        }
    }
    
    
    private func handleFaceDetection(request: VNRequest, error: Error?) {
        
        
        faceDetectionRequest?.results?.forEach({ (res) in
              guard let faceObservation = res as? VNFaceObservation else { return }
            print(faceObservation)
        })
        
    }
    
    //MARK:Text Block Detection
    private func handleTextDetection(request: VNRequest, error: Error?) {
        
        guard let detectionResults = request.results else {
            print("No detection results")
            return
        }
        let textResults = detectionResults.map() {
            return $0 as? VNTextObservation
        }
        if textResults.isEmpty {
            return
        }
        textObservations = textResults as! [VNTextObservation]
        print(textResults)
        
        
        DispatchQueue.main.async {
            self.drawRectangleBoundingBox(textResults: textResults)
        }
        
        
    }
    
    private func drawRectangleBoundingBox(textResults: [VNTextObservation?]){
        guard let sublayers = self.view.layer.sublayers else {
            return
        }
        for layer in sublayers[1...] {
            if (layer as? CATextLayer) == nil {
                layer.removeFromSuperlayer()
            }
        }
        let viewWidth = self.view.frame.size.width
        let viewHeight = self.view.frame.size.height
        for result in textResults {
            
            if let textResult = result {
                
                let layer = CALayer()
                var rect = textResult.boundingBox
                rect.origin.x *= viewWidth
                rect.size.height *= viewHeight
                rect.origin.y = ((1 - rect.origin.y) * viewHeight) - rect.size.height
                rect.size.width *= viewWidth
                
                layer.frame = rect
                layer.borderWidth = 2
                layer.borderColor = UIColor.red.cgColor
                self.view.layer.addSublayer(layer)
            }
        }
    }
}



//MARK:Face Detection
extension CameraViewController {
    
    
    func detect(image:CIImage, context:CIContext) {
        
        let accuracy = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: accuracy)
        let faces = faceDetector?.features(in: image)
        
        let ciImageSize = image.extent.size
        var transform = CGAffineTransform(scaleX: 1, y: -1)
        transform = transform.translatedBy(x: 0, y: -ciImageSize.height)
        
        
        for face in faces as! [CIFaceFeature] {
            print("Face: \(face)")
            self.drawMaskOnface(face, transform: transform, ciImageSize: ciImageSize)
        }
    }
    
    
    fileprivate func drawMaskOnface(_ face: CIFaceFeature ,transform :CGAffineTransform, ciImageSize: CGSize) {
        
        
        var faceViewBounds = face.bounds.applying(transform)
        
        let viewSize = self.imageViewSize
        let scale = min(viewSize.width / ciImageSize.width,
                        viewSize.height / ciImageSize.height)
        let offsetX = (viewSize.width - ciImageSize.width * scale) / 2
        let offsetY = (viewSize.height - ciImageSize.height * scale) / 2 - 50
        
        faceViewBounds = faceViewBounds.applying(CGAffineTransform(scaleX: scale, y: scale))
        faceViewBounds.origin.x += offsetX
        faceViewBounds.origin.y += offsetY
        print(faceViewBounds)
        
    }
    
    
    fileprivate func drawRect(_ frame: (CGRect)) {
        DispatchQueue.main.async {
            
            self.faceBox?.removeFromSuperview()
            self.faceBox = UIView(frame: frame)
            self.faceBox?.layer.borderWidth = 3
            self.faceBox?.layer.borderColor = UIColor.red.cgColor
            self.faceBox?.backgroundColor = UIColor.clear
            //  self.cameraRenderView.addSubview(self.faceBox!)
        }
        
    }
    
}




//
//
//
//func exifOrientationFromDeviceOrientation() -> UInt32 {
//    enum DeviceOrientation: UInt32 {
//        case top0ColLeft = 1
//        case top0ColRight = 2
//        case bottom0ColRight = 3
//        case bottom0ColLeft = 4
//        case left0ColTop = 5
//        case right0ColTop = 6
//        case right0ColBottom = 7
//        case left0ColBottom = 8
//    }
//    var exifOrientation: DeviceOrientation
//
//    switch UIDevice.current.orientation {
//    case .portraitUpsideDown:
//        exifOrientation = .left0ColBottom
//    case .landscapeLeft:
//        exifOrientation = devicePosition == .front ? .bottom0ColRight : .top0ColLeft
//    case .landscapeRight:
//        exifOrientation = devicePosition == .front ? .top0ColLeft : .bottom0ColRight
//    default:
//        exifOrientation = .right0ColTop
//    }
//    return exifOrientation.rawValue
//}
//
//
//
//
//
//
//
//
//




