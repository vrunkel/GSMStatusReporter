//
//  main.swift
//  GSMStatusReporter
//
//  Created by Volker Runkel for ecoObs GmbH on 13.09.20.
//


import Foundation
import GSMStatusReporterCore

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Darwin
#elseif os(Linux)
import Glibc
#endif

let tool = GSMStatusReporter()

weak var timer: Timer?

func startTimer() {
    timer?.invalidate()   // just in case you had existing `Timer`, `invalidate` it before we lose our reference to it
    timer = Timer.scheduledTimer(withTimeInterval: 600.0, repeats: true) { _ in
        tool.checkMediaMounts()
    }
}

func stopTimer() {
    timer?.invalidate()
}

// if appropriate, make sure to stop your timer in `deinit`

    tool.run()
    tool.checkMediaMounts()
    startTimer()
    RunLoop.main.run()


/*
 Logging: Protokolldatei erstellen
    - Start/Stopp
    - Fehler (Kein Mount, Kein Log, ...)
 */
