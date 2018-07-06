//
//  Camera.swift
//  Project_Camera_Metal
//
//  Created by iOS Development on 7/3/18.
//  Copyright © 2018 Genisys. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit
import MetalKit


class VideoProcessor : UIViewController {
    
    
    let player : AVPlayer = AVPlayer()
    // Remove this dummy name
    var videoFileName:String? = "video"
    var videoExtension:String? = "mp4"
    
    
    @IBOutlet var metalView: MetalView!
    
    
   convenience init(videoFileName:String, videoExtension:String) {
        self.init()
        self.videoFileName = videoFileName
        self.videoExtension = videoExtension
    }
    
   
    
    lazy var playerItemVideoOutput: AVPlayerItemVideoOutput = {
        let attributes = [kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA)]
        return AVPlayerItemVideoOutput(pixelBufferAttributes: attributes)
    }()
    
    lazy var displayLink: CADisplayLink = {
        let dl = CADisplayLink(target: self, selector: #selector(readBuffer(_:)))
        dl.add(to: .current, forMode: .defaultRunLoopMode)
        dl.isPaused = true
        return dl
    }()
    
    fileprivate func setupPlayer(){
        guard let url = Bundle.main.url(forResource: videoFileName, withExtension: videoExtension) else {
            print("Impossible to find the video.")
            return
        }
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.add(playerItemVideoOutput)
        player.replaceCurrentItem(with: playerItem)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPlayer()
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
       
        displayLink.isPaused = false
        player.play()
    }

    
    @objc private func readBuffer(_ sender: CADisplayLink) {
        
        var currentTime = kCMTimeInvalid
        let nextVSync = sender.timestamp + sender.duration
        currentTime = playerItemVideoOutput.itemTime(forHostTime: nextVSync)
        
        if playerItemVideoOutput.hasNewPixelBuffer(forItemTime: currentTime), let pixelBuffer = playerItemVideoOutput.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil) {
           
            self.metalView.pixelBuffer = pixelBuffer
            self.metalView.inputTime = currentTime.seconds
        }
    }
}
