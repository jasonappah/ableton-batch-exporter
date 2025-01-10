//
//  main.swift
//  ableton-batch-export
//
//  Created by Jason Antwi-Appah on 6/17/24.
//

import Foundation
import Accessibility
import CoreGraphics
import ApplicationServices

let abletonOwnerName = "Live"

//func getAbletonPids() -> [Int32] {
//	guard let list = CGWindowListCopyWindowInfo(.excludeDesktopElements, kCGNullWindowID) else {
//		print("rip")
//		return []
//	}
//	
//	var pids: [Int32] = []
//	
//	for entry in list as Array {
//		let ownerName: String = entry.object(forKey: kCGWindowOwnerName) as? String ?? "N/A"
//		
//		if ownerName == abletonOwnerName {
//			let ownerPID: Int32 = entry.object(forKey: kCGWindowOwnerPID) as? Int32 ?? 0
//			if !pids.contains(where: ownerPID) {
//				pids.append(ownerPID)
//			}
//		}
//	}
//	
//	return pids
//	
//
//}

func acquirePrivileges() -> Bool {
  var accessEnabled = AXIsProcessTrustedWithOptions(
	[kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
	
  if accessEnabled != true {
	accessEnabled = AXIsProcessTrusted()
//	  NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)

  }
	
  return accessEnabled == true;
}

struct PlayheadPosition {
	let bars: Int
	let beats: Int
	let sixteenths: Int
}

enum ExportTracks {
	case master
	case allIndividual
}

enum SampleRates {
	case rate_44100
	case rate_48000
}


enum PCMFileType {
	case WAV
	case AIFF
	case FLAC
}

enum DitherOptions {
	case noDither
	case triangular
	case rectangular
}

enum BitDepth {
	case depth_16(DitherOptions)
	case depth_24(DitherOptions)
	case depth_32
}

struct PCMEncoding {
	let encodePCM: Bool?
	let fileType: PCMFileType?
	let bitDepth: BitDepth?
}

struct ExportSettings {
	let renderedTrack: ExportTracks?
	let renderStart: PlayheadPosition?
	let renderEnd: PlayheadPosition?
	
	
	let convertToMono: Bool?
	let normalize: Bool?
	let createAnalysisFile: Bool?
	let sampleRate: SampleRates?
	
	let pcm: PCMEncoding?
	let mp3: Bool?
	
	let destinationPath: URL
	
}

struct Err: Error {
	let msg: String
}

// maybe i can implement an extension on axerror and use debugdescription here idk
struct SwiftAXError: Error {
	let msg: String
	init(_ err: AXError) {
		msg = switch err {
			case .noValue:
				"The requested value or AXUIElementRef does not exist."
			case .invalidUIElement:
				"The AXUIElementRef passed to the function is invalid."
			case .actionUnsupported:
				"The action is not supported by the AXUIElementRef."
			case .attributeUnsupported:
				"The attribute is not supported by the AXUIElementRef."
			default:
				"Unhandled AXError type \(err.rawValue). See AXError enum def for info"
		}
	}
}

enum AbletonStates {
	case readyToOpenFile
	case openingFile(file: String)
	case openedFile(file: String)
}

extension AXUIElement {
	func accessAttributeNames() throws -> NSArray {
		var attrNames = NSArray() as CFArray?
		let result = AXUIElementCopyAttributeNames(self, &attrNames)
		
		if result != .success {
			throw SwiftAXError(result)
		}
		
		guard let attrNames = attrNames else {
			throw Err(msg: "Failed to unwrap attribute names on \(self)")
		}
		
		return attrNames
	}
	
	func accessAttribute<T>(_ attr: String) throws -> T {
		var dataPtr: CFTypeRef?
		let result = AXUIElementCopyAttributeValue(self, attr as CFString, &dataPtr)
		
		if result != .success {
			throw SwiftAXError(result)
		}
		
		guard let data = dataPtr else {
			throw Err(msg: "Failed to unwrap data pointer when accessing \(attr) on \(self)")
		}
		
		guard let castedData = data as? T else {
			throw Err(msg: "Failed to cast accessed data from \(attr) on \(self) to requested type")
		}
	
		return castedData
	}
	
	func perform(action: String = kAXPressAction) throws {
		let result = AXUIElementPerformAction(self, action as CFString)
		if result != .success {
			throw SwiftAXError(result)
		}
	}
}


struct AbletonInstance {
	let pid: Int32
	let app: AXUIElement
	var state: AbletonStates
	
	init(p: Int32) {
		pid = p;
		app = AXUIElementCreateApplication(pid);
		state = .readyToOpenFile
	}
	
	func menuBar() -> AXUIElement {
		let menuBar: AXUIElement = try! app.accessAttribute(kAXMenuBarRole)
		return menuBar
	}
		
	func selectMenuBarOption(_ path: [String]) throws {
		if path.isEmpty {
			throw Err(msg: "Didn't expect empty option path")
		}
		var optionPath = path
		var currentEl = self.menuBar()
	
		
		while optionPath.count > 0 {
			let role: String = try currentEl.accessAttribute(kAXRoleAttribute) ?? "Unknown"
			let title: String = try currentEl.accessAttribute(kAXTitleAttribute) ?? "Unknown"
			print("Current el role: \(role), title: \(title)")
			print(try currentEl.accessAttributeNames())
			
			let currentItem = optionPath[0]
			print("Finding '\(currentItem)'...")
			
			let children: [AXUIElement] = try! currentEl.accessAttribute(kAXChildrenAttribute)
			
			let elementWithMatchingTitle = children.first(where: { r in
				let title: String? = try? r.accessAttribute(kAXTitleAttribute)
				if title != nil {
					return title == currentItem
				}
				return false
			}) ?? nil
			
			guard let el = elementWithMatchingTitle else {
				throw Err(msg: "Path invalid, failed to find '\(currentItem)' when traversing path \(path)")
			}
			
			currentEl = el
			
			print("Found '\(currentItem)' with ref \(currentEl)")
			let _ = optionPath.remove(at: 0)
			
		}
		let currentElTitle: String = try currentEl.accessAttribute(kAXTitleAttribute) ?? "Unknown"
		print("Current el: \(currentElTitle): \(currentEl)")
		try! currentEl.perform()
	}
	
}

/*
 *  LaunchApplication()
 *
 *  DEPRECATED: Use +[NSWorkspace launchApplication:],
 *      +[NSWorkspace launchApplicationAtURL:options:configuration:error:]
 *    or other LaunchServices functions ( LSOpenCFURLRef(),
 *      LSOpenFromURLSpec() ) to launch applications.
 */

print("Hello, World!")
let instance = AbletonInstance(p: 55025)
//try! instance.selectMenuBarOption(["File", "Open Live Set..."])

//selectMenuBarOption(["File", "Export Audio..."])
try instance.selectMenuBarOption(["Edit", "Select All"])

//print(getAbletonPids())

