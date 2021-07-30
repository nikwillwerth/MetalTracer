//
//  ViewController.swift
//  RayTracer
//
//  Created by Nik Willwerth on 7/23/21.
//

import Cocoa
import MetalKit

class ViewController: NSViewController {
    @IBOutlet      var mtkView: MTKView!
    @IBOutlet weak var label:   NSTextField!
    
    private let windowWidth:  CGFloat = 1920
    private let windowHeight: CGFloat = 1080
    
    private let maxSamplesPerPixel = 100
    
    private var rayTracer: RayTracer!
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        self.view.window?.setFrame(NSRect(x: 0, y: 0, width: self.windowWidth / 2, height: (self.windowHeight / 2) + self.view.window!.titlebarHeight), display: true)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        self.view.window?.positionCenter()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.rayTracer = RayTracer(mtkView: self.mtkView, imageWidth: self.windowWidth, imageHeight: self.windowHeight)
        self.rayTracer.setup()

        DispatchQueue.global().async {
            while(self.rayTracer.renderPass < self.maxSamplesPerPixel) {
                self.mtkView.draw()
                
                DispatchQueue.main.async {
                    self.label.stringValue = String(format: "Render Pass %d", self.rayTracer.renderPass)
                }
            }
            
            DispatchQueue.main.async {
                self.label.stringValue = ""
            }
        }
    }
}
