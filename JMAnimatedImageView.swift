//
//  JMAnimatedImageView.swift
//  JMAnimatedImageView
//
//  Copyright (c) 2016 J.M. Schaeffer
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import UIKit
import ImageIO
import QuartzCore


private struct AnimatedImageFrame: Equatable {
    let image: UIImage
    let duration: NSTimeInterval
}

private func == (leftAnimatedImageFrame: AnimatedImageFrame, rightAnimatedImageFrame: AnimatedImageFrame) -> Bool {
    return leftAnimatedImageFrame.image === rightAnimatedImageFrame.image
        && leftAnimatedImageFrame.duration == rightAnimatedImageFrame.duration
}


final class JMAnimatedImageView: UIImageView {
    private var imageFrames: [AnimatedImageFrame]?
    private var displayLink: CADisplayLink?
    private var currentFrameRemainingDuration: NSTimeInterval = 0
    
    var repeats: Bool = false
    
    private var currentIndex: Int? {
        guard let image = image else {
            return nil
        }
        
        return imageFrames?.map({ $0.image }).indexOf(image)
    }
    
    private var imageFrame: AnimatedImageFrame? {
        set {
            if let newValue = newValue {
                if let imageFrame = imageFrame where newValue == imageFrame {
                    return
                }
                
                image = newValue.image
                
                if !repeats && newValue == imageFrames?.last {
                    currentFrameRemainingDuration = 0
                    stopAnimating()
                } else {
                    currentFrameRemainingDuration += newValue.duration
                }
            } else {
                image = nil
                currentFrameRemainingDuration = 0
            }
        }
        get {
            if let imageFrames = imageFrames,
                currentIndex = currentIndex {
                
                return imageFrames[currentIndex]
            } else {
                return nil
            }
        }
    }
    
    private class func framesFromData(data: NSData) -> [AnimatedImageFrame]? {
        guard let source = CGImageSourceCreateWithData(data, nil) else {
            print("ERROR: 🖼 GIF source unreadable")
            
            return nil
        }
        
        let count = CGImageSourceGetCount(source)
        
        var frames = [AnimatedImageFrame]()
        
        for i in 0..<count {
            if let CGImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                let image = UIImage(CGImage: CGImage, scale: UIScreen.mainScreen().scale, orientation: .Up)
                let duration = frameDurationWithSource(source, at: i)
                let frame = AnimatedImageFrame(image: image, duration: duration)
                
                frames.append(frame)
            } else {
                print("WARNING: 🖼 GIF subimage at index \(i) unreadable")
            }
        }
        
        return frames
    }
    
    private class func frameDurationWithSource(source: CGImageSourceRef, at index: Int) -> NSTimeInterval {
        var frameDuration: NSTimeInterval = 0.1
        
        if let dictionary = CGImageSourceCopyPropertiesAtIndex(source, index, nil),
            properties = dictionary as NSDictionary as? [NSString: NSObject],
            gifDictionary = properties[kCGImagePropertyGIFDictionary] as? [NSString: NSObject] {
            if let unclampedDelayTime = gifDictionary[kCGImagePropertyGIFUnclampedDelayTime] as? NSTimeInterval {
                frameDuration = unclampedDelayTime
            } else if let delayTime = gifDictionary[kCGImagePropertyGIFDelayTime] as? NSTimeInterval {
                frameDuration = delayTime
            }
            
            // GIF animation speed throttling: https://bugzilla.mozilla.org/show_bug.cgi?id=440882
            if frameDuration <= 0.01 {
                frameDuration = 0.1
            }
        }
        
        return frameDuration
    }
    
    func setUpWithImageData(data: NSData) {
        if let imageFrames = self.dynamicType.framesFromData(data) {
            setUpWithImageFrames(imageFrames)
        }
    }
    
    private func setUpWithImageFrames(imageFrames: [AnimatedImageFrame]) {
        self.imageFrames = imageFrames
        
        imageFrame = imageFrames.first
        
        setUpDisplayLink()
    }
    
    func clear() {
        imageFrame = nil
        imageFrames = nil
    }
    
    // MARK: - CADisplayLink
    private func setUpDisplayLink() {
        if superview != nil && displayLink == nil {
            let displayLink = CADisplayLink(target: self, selector: #selector(self.dynamicType.refresh(_:)))
            displayLink.paused = true
            displayLink.addToRunLoop(.currentRunLoop(), forMode: NSRunLoopCommonModes)
            self.displayLink = displayLink
        }
    }
    
    private var previousTimestamp: CFTimeInterval?
    func refresh(displayLink: CADisplayLink) { // Cannot be private cause it needs to be available in the Objective-C runtime
        guard let imageFrames = imageFrames,
            currentIndex = currentIndex else {
                print("INFO: 🖼 Animated image view unconfigured!")
                
                return
        }
        
        if let previousTimestamp = previousTimestamp {
            let interval = displayLink.timestamp - previousTimestamp
            
            currentFrameRemainingDuration -= interval
            if currentFrameRemainingDuration <= 0 {
                self.imageFrame = imageFrames[(currentIndex + 1) % imageFrames.count]
            }
        }
        previousTimestamp = displayLink.timestamp
    }
    
    // MARK: - UIImageView
    override func startAnimating() {
        guard let imageFrames = imageFrames where NSThread.isMainThread() else {
            super.startAnimating()
            
            return
        }
        
        guard let displayLink = displayLink where displayLink.paused else {
            return
        }
        
        imageFrame = imageFrames.first
        
        previousTimestamp = nil
        displayLink.paused = false
    }
    
    override func stopAnimating() {
        guard imageFrames != nil && NSThread.isMainThread() else {
            super.stopAnimating()
            
            return
        }
        
        displayLink?.paused = true
    }
    
    // MARK: - UIView
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        setUpDisplayLink()
    }
    
    override func removeFromSuperview() {
        super.removeFromSuperview()
        
        displayLink?.invalidate()
    }
}
