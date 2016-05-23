//
//  ViewController.swift
//  InfiniScroll
//
//  Created by Michael Zuccarino on 5/20/16.
//  Copyright © 2016 asd. All rights reserved.
//

import UIKit
import QuartzCore

class ViewController: UIViewController, UIScrollViewDelegate {

    var touchEngaged:Bool = false

    var dataSource:[String] = ["1","2","3"]

    var cells:[CarouselCell] = []

    var touching:Bool = false

    var initialOffset:CGFloat = 0
    var prevTouch:CGPoint = CGPoint(x: 0, y: 0)
    var currentTouch:CGPoint = CGPoint(x: 0, y: 0)

    var prevVQ:[CGPoint] = []
    var prevV:CGPoint = CGPoint(x: 0, y: 0)
    var currV:CGPoint = CGPoint(x: 0, y: 0)

    var prevTQ:[NSTimeInterval] = []
    var prevT:NSTimeInterval!
    var currT:NSTimeInterval!

    var panGest:UIPanGestureRecognizer!

    var mInitialPoint:CGPoint = CGPointMake(0, 0)
    var mInitialTime:NSTimeInterval = 0

    var pointHistory:[CGPoint] = []

    var decaying:Bool = false
    var dragging:Bool = true
    var released:Bool = false // one time flag to check for start decay velocity

    var decayingVelocity:CGPoint = CGPoint(x: 0, y: 0)

    var displayLink:CADisplayLink!

    struct TouchEvent {
        var time:NSTimeInterval
        var coord:CGPoint
    }

    struct Velocity {
        var time:NSTimeInterval
        var velocity:CGPoint
    }

    var veloHistory:[Velocity] = []

    let kVELOTHRESH = 5
    let kFRAMEINT:Int = 1
    let kFRAMEFLOAT:CGFloat = CGFloat(1)
    let kFRAMEUINT64:UInt64 = 1

    var lastRequestTime:NSTimeInterval = 0

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()

    }

    override func viewDidAppear(animated: Bool) {
        generateCells()
        placeCells()

        self.displayLink = CADisplayLink(target: self, selector: #selector(ViewController.displayLinkRequest))
        self.displayLink.frameInterval = kFRAMEINT
        self.displayLink.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)

    }

    func displayLinkRequest() {

        if (dragging) { return }

        let timestmap = NSDate.timeIntervalSinceReferenceDate()

        if (self.lastRequestTime == 0) {
            self.lastRequestTime = timestmap
        }

        if (released) {
            self.decayingVelocity = getAverageVelocity()
            let timeDiff =  CGFloat(timestmap-self.lastRequestTime)
            let offset = CGPointMake(self.decayingVelocity.x * timeDiff, self.decayingVelocity.y * timeDiff)
            performCellTransform(vector: offset)
            self.lastRequestTime = timestmap
            decaying = true
            released = false
        } else if (decaying) {

            let timeDiff =  CGFloat(timestmap-self.lastRequestTime)

            // -5u/tu/tu gravity
            self.decayingVelocity = CGPointMake(self.decayingVelocity.x-(0.5 * timeDiff), self.decayingVelocity.y-(0.5 * timeDiff))

            if (self.decayingVelocity.x <= 0 && self.decayingVelocity.y <= 0) {
                decaying = false
                dragging = true
                return
            }

            // by leaving this signed, and switching gravity on sign change, one could techincally make the spring API (todo later)
            let offset = CGPointMake((self.decayingVelocity.x * timeDiff) >= 0 ? (self.decayingVelocity.x * timeDiff) : 0,(self.decayingVelocity.y * timeDiff) >= 0 ? (self.decayingVelocity.y * timeDiff) : 0)
            performCellTransform(vector: offset)

            self.lastRequestTime = timestmap
        }

    }

    func performCellTransform(vector vector:CGPoint) {
        for (_,cell) in self.cells.enumerate() {
            cell.center = CGPointMake(cell.center.x+(vector.x*(1/30)),cell.center.y+(vector.y*(1/30)))
        }
    }

    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        dragging = true
        released = false
        decaying = false
        self.veloHistory = []
        self.mInitialPoint = touches.first!.locationInView(self.view)
        self.mInitialTime = NSDate.timeIntervalSinceReferenceDate()
    }

    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        let stamp = NSDate.timeIntervalSinceReferenceDate()
        let currPoint = touches.first!.locationInView(self.view)

        if (self.veloHistory.count == 0) {
            let timeDiff = CGFloat(stamp - self.mInitialTime)
            print("timeDiff \(timeDiff)")
            let velocity = Velocity(time: stamp, velocity: CGPointMake((currPoint.x-self.mInitialPoint.x)/timeDiff, (currPoint.y-self.mInitialPoint.y)/timeDiff))
            self.veloHistory.append(velocity)
            self.prevTouch = currPoint
            return
        } else {
            let latestVelo = self.veloHistory.last!
            let timeDiff = CGFloat(stamp - latestVelo.time)
            print("timeDiff \(timeDiff)")
            let currPoint = touches.first!.locationInView(self.view)
            // decay velocity
            let velocity = Velocity(time: stamp, velocity: CGPointMake((currPoint.x-self.prevTouch.x)/timeDiff, (currPoint.y-self.prevTouch.y)/timeDiff))
            if (self.veloHistory.count >= kVELOTHRESH) {
                self.veloHistory.removeAtIndex(0)
            }
            self.veloHistory.append(velocity)
            self.prevTouch = currPoint
            let offset = CGPointMake(velocity.velocity.x * timeDiff, velocity.velocity.y * timeDiff)
            performCellTransform(vector: offset)
        }
    }

    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        dragging = false
        released = true
    }

    override func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?) {
        dragging = false
    }

    func getAverageVelocity() -> CGPoint {
        var totalVelocity = CGPointMake(0, 0)
        var totalTime:Double = 0
        for (_,velo) in self.veloHistory.enumerate() {
            totalVelocity = CGPointMake(totalVelocity.x+velo.velocity.x, totalVelocity.y+velo.velocity.y)
            totalTime += Double(velo.time)
        }
        return CGPointMake(totalVelocity.x/CGFloat(totalTime), totalVelocity.y/CGFloat(totalTime))
    }


//    func handleSwipeGesture() {
//        if (panGest.state == UIGestureRecognizerState.Began) {
//
//            self.view.layer.removeAllAnimations()
//            prevTouch = panGest.locationInView(self.view)
//
//        } else if (panGest.state == UIGestureRecognizerState.Changed) {
//
//            currentTouch = panGest.locationInView(self.view)
//
//            let diff = CGPointMake(prevTouch.x - currentTouch.x, 0)
//            for (_,cell) in cells.enumerate() {
//                var frm = cell.frame
//                frm.origin.x -= diff.x
//                cell.frame = frm
//            }
//            prevTouch = currentTouch
//
//            // velo queue
//            let prevR = panGest.velocityInView(self.view)
//            if (prevVQ.count == 3) {
//                prevVQ.removeLast()
//            }
//            prevVQ.insert(prevR, atIndex: 0)
//
//            // stamp queue
//            let prevP = NSDate.timeIntervalSinceReferenceDate()
//            if (prevTQ.count == 3) {
//                prevTQ.removeLast()
//            }
//            prevTQ.insert(prevP, atIndex: 0)
//
//        } else if (panGest.state == UIGestureRecognizerState.Ended) {
//
////            currV = panGest.velocityInView(self.view)
////            currT = NSDate.timeIntervalSinceReferenceDate()
//
//            let trampoline = calculateTargetHuck(gravAdjust: 1)
//
//            let cellAllocCount = Int(floor(fabs(trampoline.x)/self.view.frame.size.width))
//
//            var multi:CGFloat
//            if prevVQ.first!.x < 0 {
//                multi = 1
//                for _ in 0...cellAllocCount {
//                    self.insertCellToRight()
//                }
//            } else {
//                multi = -1
//                for _ in 0...cellAllocCount {
//                    self.insertCellToLeft()
//                }
//            }
//
//
//
////            UIView.animateKeyframesWithDuration(1, delay: 0, options: UIViewKeyframeAnimationOptions.BeginFromCurrentState, animations: {
////                for (_,cell) in self.cells.enumerate() {
////                    var frm = cell.frame
////                    frm.origin.x +=  multi*trampoline.x
////                    cell.frame = frm
////                }
////                }, completion: nil)
//
//            UIView.animateWithDuration(1, delay: 0, options: UIViewAnimationOptions.CurveEaseOut, animations: { 
//                for (_,cell) in self.cells.enumerate() {
//                    var frm = cell.frame
//                    frm.origin.x -= multi*trampoline.x
//                    cell.frame = frm
//                }
//                }, completion: { (completion) in
//
//            })
//
//        } else if (panGest.state == UIGestureRecognizerState.Cancelled) {
//
//        }
//    }
//
//    func calculateTargetHuck(gravAdjust gravAdjust:Double) -> CGPoint {
//
//        let coordinateShrink:CGFloat = 10
//
//        prevV = prevVQ.last!
//        currV = prevVQ[prevVQ.count-2]
//
//        prevT = prevTQ.last!
//        currT = prevTQ[prevTQ.count-2]
//
//        var accelBase = Double((fabs(currV.x)/coordinateShrink - fabs(prevV.x)/coordinateShrink))/(currT - prevT)
//        accelBase *= gravAdjust
//
//        let targetDist = ((pow(fabs(currV.x)/coordinateShrink,2) - pow(fabs(prevV.x)/coordinateShrink,2))/10)
//        print("targetdist : \(targetDist)")
//        return CGPointMake(targetDist, 0)
//    }

    func insertCellToLeft() {
        let cell = CarouselCell.createCarouselCell(parent: self.view, frame: self.view.bounds)
        cells.insert(cell, atIndex: 0)
        var frame = cell.frame
        frame.origin.x = cells[1].frame.origin.x - cell.frame.size.width
        cell.frame = frame
        self.view.addSubview(cell)
    }

    func insertCellToRight() {
        let cell = CarouselCell.createCarouselCell(parent: self.view, frame: self.view.bounds)
        cells.append(cell)
        var frame = cell.frame
        frame.origin.x = cells[cells.count-2].frame.origin.x + cell.frame.size.width
        cell.frame = frame
        self.view.addSubview(cell)
    }

    func generateCells() {
        for index in 1...dataSource.count {
            let cell = CarouselCell.createCarouselCell(parent: self.view, frame: self.view.bounds)
            cell.num.text = "\(index)"
            cells.append(cell)
        }
    }

    func placeCells() {
        for (index,cell) in cells.enumerate() {
            switch index {
            case 0:
                //     ____
                // [ ] |--| --
                //     ____
                var frame = cell.frame
                frame.origin.x = -CGRectGetWidth(cell.frame)
                cell.frame = frame
                self.view.addSubview(cell)
            case 1:
                //    ____
                // -- |[ ]| --
                //    ____
                var frame = cell.frame
                frame.origin.x = 0
                cell.frame = frame
                self.view.addSubview(cell)
            case 2:
                //    ____
                // -- |--| [ ]
                //    ____
                var frame = cell.frame
                frame.origin.x = CGRectGetWidth(cell.frame)
                cell.frame = frame
                self.view.addSubview(cell)
            default:
                print("memes")
            }
        }
    }

//    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
//        touching = true
//        currentTouch = touches.first!.locationInView(self.view)
//        initialOffset = currentTouch.x
//
////        stamp queue
//        let prevP = NSDate.timeIntervalSinceReferenceDate()
//        if (prevTQ.count == 3) {
//            prevTQ.removeLast()
//        }
//        prevTQ.insert(prevP, atIndex: 0)
//
////         velo queue
//        let prevR = panGest.velocityInView(self.view)
//        if (prevVQ.count == 3) {
//            prevVQ.removeLast()
//        }
//        prevVQ.insert(prevR, atIndex: 0)
//    }
//
//    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
//        currentTouch = touches.first!.locationInView(self.view)
//
////        stamp queue
//        let prevP = NSDate.timeIntervalSinceReferenceDate()
//        if (prevTQ.count == 3) {
//            prevTQ.removeLast()
//        }
//        prevTQ.insert(prevP, atIndex: 0)
//
////         velo queue
//        let prevR = panGest.velocityInView(self.view)
//        if (prevVQ.count == 3) {
//            prevVQ.removeLast()
//        }
//        prevVQ.insert(prevR, atIndex: 0)
//    }
//
//    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
//        touching = false
//        currentTouch = touches.first!.locationInView(self.view)
//
//        var averageVelo:CGFloat = 0
//
//        if (prevVQ.count >= 2) {
//            let dDist = prevVQ[1].x - prevVQ[0].x
//            let dTime = CGFloat(prevTQ[1] - prevTQ[0])
//            averageVelo = dDist/dTime
//        }
//
//        prevTQ.removeAll()
//        prevTQ.removeAll()
//    }
//
//    override func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?) {
//        touching = false
//    }

}

