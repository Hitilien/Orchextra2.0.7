//
//  EddystoneBeacon.swift
//  EddystoneExample
//
//  Created by Carlos Vicente on 1/7/16.
//  Copyright © 2016 Gigigo. All rights reserved.
//

import Foundation

@objc public enum proximity: Int {
    case unknown
    case inmediate
    case near
    case far
}

@objc public class ORCEddystoneBeacon:NSObject {
    
    public var peripheralId:UUID?
    public var txPower:Int?
    public var rangingData:Int? // Calibrated Tx power at 0 m
    public var rssiBuffer:[Int]?
    public var rssi:Double { get {
        var totalRssi: Double = 0
        guard let rssiBuffer = self.rssiBuffer else {
            return 0
        }
        
        for rssi in rssiBuffer {
            totalRssi += Double(rssi)
        }
        
        return totalRssi / Double(rssiBuffer.count)
        }
    }
    
    public var url:URL?
    public var uid:EddystoneUID?
    public var eid:String?
    public var telemetry:Telemetry?
    public var proximityTimer: Timer?
    public var requestWaitTime: Int
    public var proximity: proximity {
        
        get {
            let rangingDataUnWrapped = (self.rangingData != nil) ? self.rangingData! : 0
            return self.convertRSSIToProximity(self.rssi, rangingData:rangingDataUnWrapped)
        }
    }
    
    public init(peripheralId:UUID, requestWaitTime: Int) {
        self.peripheralId = peripheralId
        self.requestWaitTime = requestWaitTime
        
        super.init()        
    }
    
    public func updateRssiBuffer(rssi: Int) {
        let rssiBufferCount: Int = (self.rssiBuffer != nil) ? (self.rssiBuffer?.count)! : 0
        
        if rssiBufferCount == 0 {
            self.rssiBuffer = [Int]()
            self.rssiBuffer?.insert(rssi, at: 0)
        } else if rssiBufferCount < EddystoneConstants.maxRssiBufferCount {
            self.rssiBuffer?.insert(rssi, at: 0)
        } else {
            self.rssiBuffer?.removeLast()
            self.rssiBuffer?.insert(rssi, at: 0)
        }
        
    }
    
    public func canBeSentToValidateAction() -> Bool {
        var canBeSentToValidateAction: Bool = false
        
        if (self.uid?.namespace != nil),
            (self.uid?.instance != nil ),
            (self.url != nil),
            (self.telemetry?.temperature != nil),
            (self.telemetry?.batteryPercentage != nil),
            (self.telemetry?.uptime != nil),
            (self.proximity != .unknown),
            (self.proximityTimer == nil) {
            canBeSentToValidateAction = true
        }
        
        return canBeSentToValidateAction
    }
    
    public func updateProximity(currentProximity: proximity) {
        self.updateProximityTimer()
    }
    
    public func updateProximityTimer() {
        let timerTimeInterval = TimeInterval(self.requestWaitTime)
        
        self.proximityTimer = Timer.scheduledTimer(timeInterval: timerTimeInterval,
                                                   target: self,
                                                   selector: #selector(resetProximityTimer),
                                                   userInfo: nil,
                                                   repeats: false)
    }
    
    public func resetProximityTimer() {
        self.proximityTimer?.invalidate()
        self.proximityTimer = nil
    }
    
     func convertRSSIToProximity(_ rssi: Double, rangingData: Int) -> proximity {
        var rangingDataUpdated = rangingData
        
        if rangingData == 0 {
            rangingDataUpdated = EddystoneConstants.defaultRangingData
        }
        
        let distance: Double = self.calculateDistanceFromRSSI(rssi, rangingData: rangingDataUpdated)
        let proximity:proximity  = self.convertDistanceFromRSSI(distance)
        
        return proximity
    }
    
     func calculateDistanceFromRSSI(_ rssi: Double, rangingData: Int) -> Double {
        var distance: Double = 0.0

        if rssi == 0 {
            distance = -1 // Distance not determined
        }
        
        let ratio: Double = rssi / Double(rangingData)
        
        if ratio < 1 {
            distance = pow(ratio, 10)
        } else {
            distance = 0.89976 * pow(ratio, 7.7095) + 0.111
        }
        
        return distance
    }
    
     func convertDistanceFromRSSI(_ distance: Double) -> proximity {
        var proximity: proximity = .unknown
        if distance > 0,
            distance <= 1 {
            proximity = .inmediate
        } else if distance > 1,
            distance <= 3 {
            
            proximity = .near
            
        } else if distance > 3 {
            proximity = .far
        }
        return proximity
    }
}