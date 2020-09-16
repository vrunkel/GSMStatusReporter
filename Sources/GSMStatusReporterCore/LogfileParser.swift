//
//  LogfileParser.swift
//  GSMStatusReporter
//
//  Created by Volker Runkel for ecoObs GmbH on 13.09.20.
//

import Foundation

public final class LogfileParser {

    var logfilePath: String?
    var logfileContent : String?
    var loglineArray: Array<String>?
    var firstTSLCount = 0
    
    public init?(path: String) {
        if !FileManager.default.fileExists(atPath: path) {
            return nil
        }
        guard let content = try? String(contentsOf: URL(fileURLWithPath: path), encoding: .macOSRoman) else {
            return nil
        }
        self.logfileContent = content
        self.loglineArray = logfileContent!.components(separatedBy: CharacterSet.newlines)
    }
    
    func recordingCount() -> Int? {
        guard let lineArray = self.loglineArray else {
            print("Line array nil")
            return nil
        }
        for aLine in lineArray {
            if aLine.hasPrefix("Files total") {
                if let recCount = Int(aLine.components(separatedBy: ":")[1].replacingOccurrences(of: " ", with: "")) {
                    return recCount
                }
                return nil
            }
        }
        return nil
    }
    
    func getLastStatusMessage() -> String? {
        guard let lineArray = self.loglineArray else {
            print("Line array nil")
            return nil
        }
        var returnString = ""
        for aLine in lineArray.reversed() {
            if aLine.hasPrefix("Timer off") {
                return returnString
            }
            if aLine.hasPrefix("S") {
                returnString += aLine
                returnString += "\n"
            }
        }
        return returnString
    }
    
    func getTimerOff() -> String? {
        guard let lineArray = self.loglineArray else {
            print("Line array nil")
            return nil
        }
        var offFound = false
        var returnString = ""
        var TSLStrings = ""
        var TSLFound = false
        for aLine in lineArray.reversed() {
            if aLine.hasPrefix("Timer off") && !offFound {
                returnString += aLine
                offFound = true
            }
            else if aLine.hasPrefix("Timer on") {
                let TSLArray = TSLStrings.components(separatedBy: CharacterSet.newlines)
                let returnTSL = TSLArray.reversed().joined(separator: "\n")
                return aLine + "\n" + returnString + "\n" + returnTSL
            }
            else if aLine.hasPrefix("TSL-Result") {
                TSLStrings += "\n" + aLine
                TSLFound = true
            }
            else if TSLFound && aLine.hasPrefix("T\t") {
                TSLFound = false
                TSLStrings += "\n" + aLine
                if TSLStrings.count > 90 {
                    let lineComps = aLine.components(separatedBy: "\t")
                    if lineComps.count >= 4 {
                        let filename = lineComps[3]
                        let filenameComps = filename.components(separatedBy: "-")
                        if filenameComps.count == 3 {
                            if let recNumberBeginning = Int(filenameComps.last!.replacingOccurrences(of: ".raw", with: "")) {
                                self.firstTSLCount = recNumberBeginning
                            }
                        }
                    }
                }
            }
        }
        return nil
    }
    
    func getFilecode() -> String? {
       guard let lineArray = self.loglineArray else {
            print("Line array nil")
            return nil
        }
        
        for aLine in lineArray.reversed() {
            if aLine.hasPrefix("Timer on") {
                let lineComps = aLine.components(separatedBy: "\t")
                if lineComps.count >= 4 {
                    return lineComps[3]
                }
                else {
                    return "GSM - no filecode"
                }
            }
        }
        return nil
        
    }
    
}
