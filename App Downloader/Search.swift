//
//  Search.swift
//  AppDownloader
//
//  Copyright (C) 2017-2023 Jahn Bertsch
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

protocol SearchDelegate: AnyObject {
    func searchError(messageText: String, informativeText: String)
    func display(searchResults: [SearchResult])
}

class Search {
    public weak var delegate: SearchDelegate?
    
    private let caskJsonURL = URL(string: "https://formulae.brew.sh/api/cask.json")!
    private var caskInfoArray: [Any]?
    
    init() {
        let dataTask = URLSession.shared.dataTask(with: caskJsonURL, completionHandler: caskJsonDownloadCompletionHandler)
        dataTask.resume() // start cask json download
    }
    
    func startSearch(searchString: String) {
        guard let caskInfoArray = caskInfoArray else {
            delegate?.searchError(messageText: "Search Failed", informativeText: "Search index not available.")
            return
        }
        
        var searchResults: [SearchResult] = []

        for caskInfo in caskInfoArray {
            if let caskInfo = caskInfo as? [String: Any] {
                if let searchResult = search(for: searchString, in: caskInfo) {
                    searchResults.append(searchResult)
                }
            } else {
                delegate?.searchError(messageText: "Processing search index failed", informativeText: "Could not convert cask info to dictionary.")
                break
            }
        }
        
        sortByName(&searchResults)
        delegate?.display(searchResults: searchResults) // search done
    }
    
    fileprivate func search(for searchString: String, in caskInfo: [String: Any]) -> SearchResult? {
        if let names       = caskInfo["name"] as? [String],
           let description = caskInfo["desc"] as? String,
           let homepage    = caskInfo["homepage"] as? String,
           let urlString   = caskInfo["url"] as? String,
           let sha256      = caskInfo["sha256"] as? String,
           let url = URL(string: urlString)
        {
            var displayName = ""
            for name in names {
                if name.lowercased().contains(searchString) {
                    displayName = name
                }
            }
            if description.lowercased().contains(searchString) && displayName == "" {
                displayName = names.first ?? "Unknown Name"
            }
            
            if displayName != "" {
                return SearchResult(name: displayName, description: description, homepage: homepage, url: url, sha256: sha256)
            }
        }

        return nil
    }
    
    // MARK: - private
    
    fileprivate func caskJsonDownloadCompletionHandler(data: Data?, response: URLResponse?, error: Error?) {
        guard response != nil else {
            delegate?.searchError(messageText: "Downloading search index failed", informativeText: "You have to be connected to the Internet to search.")
            return
        }
        
        if let error = error {
            delegate?.searchError(messageText: "Downloading search index failed", informativeText: error.localizedDescription)
        } else if let data = data {
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: data)
                if let jsonArray = jsonObject as? [Any] {
                    caskInfoArray = jsonArray
                } else {
                    delegate?.searchError(messageText: "Processing search index failed", informativeText: "Could not convert cask JSON to array.")
                }
            } catch {
                delegate?.searchError(messageText: "Decoding search index failed", informativeText: error.localizedDescription)
            }
        } else {
            delegate?.searchError(messageText: "Downloading search index failed", informativeText: "No data received.")
        }
    }

    fileprivate func sortByName(_ searchResults: inout [SearchResult]) {
        searchResults.sort { (a, b) -> Bool in
            if a.name < b.name {
                return true
            } else {
                return false
            }
        }
    }
}
