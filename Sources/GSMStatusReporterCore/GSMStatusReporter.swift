//
//  GSMStatusReporter.swift
//  GSMStatusReporter
//
//  Created by Volker Runkel for ecoObs GmbH on 13.09.20.
//

import Foundation

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Darwin
#elseif os(Linux)
import Glibc
#endif

import SwiftSMTP
import INIParser

public final class GSMStatusReporter {
       
    private let arguments: [String]
    private var pN : String { return ProcessInfo.processInfo.processName }
    private var RPiName: String = "RPi-WEA"
    
    private var ini: INIParser?
    
    private var smtpserver : String?
    private var smtpuser: String?
    private var smtppwd: String?
    
    private var receiver: Mail.User?
    private var sender: Mail.User?
    
    var GSMMounted: Bool = false
    var lastMediaMissingMessage: Date?
       
    public init(arguments: [String] = CommandLine.arguments) {
        self.arguments = arguments

        guard let localini = try? INIParser(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents").appendingPathComponent("GSMStatusReporter.ini").path) else {
            Logger.log(self.pN + " no ini file found")
            print("Aborting: no initialisation file in Documents")
            exit(0)
        }
        self.ini = localini
        
        guard let server = self.ini!.sections["Mail"]?["SMTPServer"], let user = self.ini!.sections["Mail"]?["SMTPUser"], let pwd = self.ini!.sections["Mail"]?["SMTPPassword"] else {
            Logger.log(self.pN + " no mail settings in ini file found")
            print("Aborting: no mail setup in initialisation file")
            exit(0)
        }
        
        if let name = ini!.sections["RPi"]?["Name"] {
            self.RPiName = name
        }
        
        self.smtpserver = server
        self.smtpuser = user
        self.smtppwd = pwd
    }
    
    func mountedMedia() -> [String]? {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey, .volumeIsEjectableKey]
        let paths = FileManager().mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [])
        var mountedURLs = Array<String>()
        if let urls = paths {
            for url in urls {
                let components = url.pathComponents
                if components.count > 1
                   && components[1] == "media"
                {
                    mountedURLs.append(url.path)
                }
            }
        }
        if mountedURLs.isEmpty {
            return nil
        }
        else {
            return mountedURLs
        }
    }
    
    func sendEmail(receiver: Mail.User, sender: Mail.User, subject: String, message: String) {
        
        let smtp = SMTP(
            hostname: self.smtpserver!,
            email: self.smtpuser!,
            password: self.smtppwd!
            )
                
        let mail = Mail(
            from: sender,
            to: [receiver],
            subject: self.RPiName + " " + subject,
            text: message
        )

        smtp.send(mail) { (error) in
            if let error = error {
                print(error)
            }
            else {
                Logger.log(self.pN + " Mail sent")
            }
        }
    }
    
    func parseLogfile(logfilePath: String) {
                
        let parser = LogfileParser(path: logfilePath)
        let filecode = parser?.getFilecode() ?? "No filecode"
        let recOverallCount = parser?.recordingCount() ?? -1
        let statusString = parser?.getLastStatusMessage() ?? "No status"
        let timerOffString = parser?.getTimerOff() ?? "Timer has not turned off"
        let recsLastNight = 1 + recOverallCount - (parser?.firstTSLCount ?? 0)
        
        var mailMessage = "Daily status for GSM-batcorder running with filecode " + filecode
        mailMessage += "\n\n" + timerOffString
        mailMessage += "\n\n" + statusString
        mailMessage += "\n\nOverall Recs \(recOverallCount as Int)"
        mailMessage += "\nRecs last night \(recsLastNight)"
        mailMessage += "\n\n **** Good bye for today ****"
        
        self.sendEmail(receiver: self.receiver!, sender: self.sender!, subject: "Logfile parsed for " + filecode, message: mailMessage)
    }
    
    public func checkMediaMounts() {
        let fm = FileManager.default
        guard let volumes = self.mountedMedia() else {
            Logger.log(self.pN + " No media mounted")
            let lastMessageInterval = abs(self.lastMediaMissingMessage?.timeIntervalSinceNow ?? 24*60*60)
            if self.lastMediaMissingMessage == nil || lastMessageInterval > 23*60*60 {
                self.sendEmail(receiver: self.receiver!, sender: self.sender!, subject: "Error", message: "No media mounted")
                self.lastMediaMissingMessage = Date()
            }
            self.GSMMounted = false
            return
        }
        
        var logfilePath: String?
        for aVolume in volumes {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: aVolume, isDirectory: &isDir) && isDir.boolValue {
                if !fm.fileExists(atPath: aVolume + "/LOGFILE.TXT") {
                    continue
                }
                else {
                    logfilePath = aVolume + "/LOGFILE.TXT"
                    break
                }
            }
        }
        if logfilePath == nil {
            Logger.log(self.pN + " No logfile found")
            self.sendEmail(receiver: self.receiver!, sender: self.sender!, subject: "Error: No logfile found", message: "No logfile found")
            self.GSMMounted = false
        }
        
        if self.GSMMounted {
            Logger.log(self.pN + " GSM mounted - mail already sent. idling.")
            return
        }
        Logger.log(self.pN + " GSM mounted - will send email.")
        self.GSMMounted = true
        self.parseLogfile(logfilePath: logfilePath!)
    }
    
    public func run() {
        /*guard arguments.count > 1 else {
            throw Error.missingEmail
        }
        let email = arguments[1]*/
        // go through all Volume subfolders and check existence of LOGFILE.TXT
        // if found, read it
        // else error
                     
        Logger.log("GSMStatusReporter" + " **** **** **** starting **** **** ****")
        guard let _ = try? INIParser(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents").appendingPathComponent("GSMStatusReporter.ini").path) else {
            Logger.log("GSMStatusReporter" + " no ini file found")
            print("Aborting: no initialisation file in Documents")
            exit(0)
        }
        
        guard let receiverName = self.ini!.sections["Receiver"]?["ReceiverName"], let receiverEmail = self.ini!.sections["Receiver"]?["ReceiverEMail"] else {
            Logger.log(self.pN + " no mail receiver in ini file found")
            print("Aborting: no mail receiver in initialisation file")
            exit(0)
        }
        
        var mailSender = Mail.User(name: "RPi", email: "runkel@ecoobs.de")
        if let senderName = self.ini!.sections["Sender"]?["SenderName"], let senderEmail = self.ini!.sections["Sender"]?["SenderEMail"] {
            mailSender = Mail.User(name: senderName, email: senderEmail)
            
        } else {
            Logger.log(self.pN + " no mail sender in ini file found, setting default")
        }
        self.sender = mailSender
        self.receiver = Mail.User(name: receiverName, email: receiverEmail)
    }
}

public extension GSMStatusReporter   {
    enum Error: Swift.Error {
        case missingEmail
    }
}
