//
//  Download.swift
//  AppDownloader
//
//  Copyright (C) 2017, 2018 Jahn Bertsch
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//  Also add information on how to contact you by electronic and paper mail.
//

import Foundation
import AppKit

protocol DownloadLocationDelegate: class {
    func downloadLocationError(messageText: String, informativeText: String)
    func downloadLocationFound(url: URL)
}

class Download: NSObject, URLSessionDelegate, DownloadLocationProtocol {
    private let config = URLSessionConfiguration.default
    private var session: URLSession?
    private var downloadLocationTask: URLSessionDownloadTask?
    
    public weak var delegate: DownloadLocationDelegate? = nil
    
    override init() {
        super.init()
        session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
    }
    
    func getDownloadLocation(name: String, url: URL) {
        let task = session?.dataTask(with: url, completionHandler: getDownloadLocationCompletionHandler)
        task?.resume()
    }

    // MARK: - get download location

    fileprivate func getDownloadLocationCompletionHandler(dataOptional: Data?, responseOptional: URLResponse?, errorOptional: Error?) {
        if let error = errorOptional {
            delegate?.downloadLocationError(messageText: "Download Location Unknown", informativeText: error.localizedDescription)
        } else {
            if let data = dataOptional {
                parseDownloadLocation(data: data)
            }
        }
    }
    
    fileprivate func parseDownloadLocation(data: Data) {
        do {
            let json = try JSONSerialization.jsonObject(with: data) as! [String: AnyObject]
            parseDownloadLocation(json: json)
        } catch {
            delegate?.downloadLocationError(messageText: "Error", informativeText: "JSON decoding failed: \(error.localizedDescription)")
        }
    }
    
    fileprivate func parseDownloadLocation(json: [String: AnyObject]) {
        if let downloadUrl = json["download_url"] as? String {
            if let url = URL(string: downloadUrl) {
                let task = session?.dataTask(with: url, completionHandler: getCaskFileCompletionHandler)
                task?.resume()
            }
        }
    }
    
    // MARK: - get cask file
    
    fileprivate func getCaskFileCompletionHandler(dataOptional: Data?, responseOptional: URLResponse?, errorOptional: Error?) {
        if let error = errorOptional {
            delegate?.downloadLocationError(messageText: "Download failed", informativeText: error.localizedDescription)
        } else {
            if let data = dataOptional {
                if let caskFile = String(data: data, encoding: .utf8) {
                    parse(caskFile: caskFile)
                }
            }
        }
    }
    
    fileprivate func parse(caskFile: String) {
        let (version, _) = parseCaskFile(caskFile: caskFile)
        
        if var downloadUrl = extract(searchString: "url", from: caskFile) {
            downloadUrl = replace(version: version, in: downloadUrl)
            
            if let url = URL(string: downloadUrl) {
                delegate?.downloadLocationFound(url: url)
            } else {
                delegate?.downloadLocationError(messageText: "Unknown Download URL", informativeText: "Unknown download URL for version \(version):\n\n\(downloadUrl)")
                print(caskFile)
            }
        } else {
            delegate?.downloadLocationError(messageText: "Unknown Download URL", informativeText: "Could not find download location.")
            print(caskFile)
        }
    }

    // MARK: - private

    fileprivate func parseCaskFile(caskFile: String) -> (String, String) {
        var version = "", sha256 = ""
        let caskFileLines = caskFile.components(separatedBy: .newlines)
        
        for line in caskFileLines {
            if let extractedVersion = extract(searchString: "version '", from: line) {
                version = extractedVersion
            }
            if let extractedSha256 = extract(searchString: "sha256 '", from: line) {
                sha256 = extractedSha256 // currently unused
            }
        }
        
        // print("\nversion: \(version), sha256: \(sha256)")

        return (version, sha256)
    }
    
    fileprivate func replace(version: String, in source: String) -> String {
        let (major, minor, patch, patchOnly, beforeComma, afterComma, afterCommaBeforeColon, afterColon) = split(version: version)
        
        var result = source.replacingOccurrences(of: "#{version}", with: version)
        result = result.replacingOccurrences(of: "#{version.major}", with: major)
        result = result.replacingOccurrences(of: "#{version.minor}", with: minor)
        result = result.replacingOccurrences(of: "#{version.major_minor}", with: "\(major).\(minor)")
        result = result.replacingOccurrences(of: "#{version.major_minor.no_dots}", with: "\(major)\(minor)")
        result = result.replacingOccurrences(of: "#{version.major_minor_patch}", with: "\(major).\(minor).\(patchOnly)")
        result = result.replacingOccurrences(of: "#{version.major_minor}", with: major)
        result = result.replacingOccurrences(of: "#{version.dots_to_underscores}", with: "\(major)_\(minor)_\(patch)")
        result = result.replacingOccurrences(of: "#{version.no_dots}", with: "\(major)\(minor)\(patch)")
        result = result.replacingOccurrences(of: "#{version.patch}", with: patch)
        result = result.replacingOccurrences(of: "#{version.dots_to_hyphens}", with: "\(major)-\(minor)-\(patch)")
        result = result.replacingOccurrences(of: "#{version.before_comma}", with: "\(beforeComma)")
        result = result.replacingOccurrences(of: "#{version.after_comma}", with: "\(afterComma)")
        result = result.replacingOccurrences(of: "#{version.after_comma.before_colon}", with: "\(afterCommaBeforeColon)")
        result = result.replacingOccurrences(of: "#{version.after_colon}", with: "\(afterColon)")
        result = result.replacingOccurrences(of: "#{language}", with: "en-US") // thunderbird
        result = result.replacingOccurrences(of: "#{version.sub(%r{-.*},'')}", with: "\(major).\(minor).\(patchOnly)") // virtualbox

        return result
    }
    
    private func split(version: String) -> (String, String, String, String, String, String, String, String) {
        var versionMajor = "", versionMinor = "", versionPatch = "", versionPatchOnly = "", beforeComma = "", afterComma = "", afterCommaBeforeColon = "", afterColon = ""

        let versionArray = version.split(separator: ".")

        if versionArray.count >= 3 {
            versionPatch = String(versionArray[2])
        }
        if versionArray.count >= 2 {
            versionMinor = String(versionArray[1])
        }
        if versionArray.count >= 1 {
            versionMajor = String(versionArray[0])
        }
        
        let patchArray = versionPatch.split(separator: "-")
        if patchArray.count > 0 {
            versionPatchOnly = String(patchArray[0])
        }
        
        let commaArray = version.split(separator: ",")
        if commaArray.count > 1 {
            beforeComma = String(commaArray[0])
            afterComma  = String(commaArray[1])
            
            let beforeColonArray = afterComma.split(separator: ":")
            if beforeColonArray.count > 1 {
                afterCommaBeforeColon = String(beforeColonArray[0])
            }
        }

        let colonArray = version.split(separator: ":")
        if colonArray.count > 1 {
            afterColon = String(colonArray[1])
        }

        return (versionMajor, versionMinor, versionPatch, versionPatchOnly, beforeComma, afterComma, afterCommaBeforeColon, afterColon)
    }
    
    fileprivate func extract(searchString: String, from source: String) -> String? {
        if let sourceLine = extractTextLine(containingString: searchString, in: source) {
            let sourceLineWithoutSpaces = sourceLine.replacingOccurrences(of: ", '", with: ",'")
            var sourceArray = sourceLineWithoutSpaces.split(separator: " ").map(String.init)
            if sourceArray.count == 2 {
                return trim(sourceArray[1])
            }
        }
        
        return nil
    }
    
    fileprivate func trim(_ source: String) -> String {
        return source.trimmingCharacters(in: CharacterSet(charactersIn: ",\"'\n"))
    }
    
    fileprivate func extractTextLine(containingString searchString: String, in sourceString: String) -> String? {
        if let searchRange = sourceString.range(of: searchString) {
            return sourceString.substring(with: sourceString.lineRange(for: searchRange))
        }
        
        return nil
    }
    
}
