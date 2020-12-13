//
//  Search.swift
//  AppDownloader
//
//  Copyright (C) 2017-2020 Jahn Bertsch
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

protocol SearchDelegate: class {
    func searchError(messageText: String, informativeText: String)
    func resetSearchResults(statusText: String)
    func display(searchResults: [SearchResult])
}

class Search: SearchProtocol {
    private let config: URLSessionConfiguration
    private let session: URLSession
    
    public weak var delegate: SearchDelegate? = nil
    
    init() {
        config = URLSessionConfiguration.default
        session = URLSession(configuration: config)
    }
    
    func startSearch(searchString: String) {
        if let url = URL(string: "https://api.github.com/search/code?q=repo:homebrew/homebrew-cask+" + searchString) {
            let task = session.dataTask(with: url, completionHandler: searchCompletionHandler)
            task.resume() // do the search
        }
    }
    
    // MARK: - private
    
    fileprivate func searchCompletionHandler(data: Data?, response: URLResponse?, error: Error?) {
        if let error = error {
            delegate?.searchError(messageText: "Search Error", informativeText: error.localizedDescription)
        } else if let data = data {
            do {
                if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: AnyObject] {
                    handle(jsonObject: jsonObject)
                } else {
                    delegate?.searchError(messageText: "Search Error", informativeText: "JSON decoding of search result failed")
                }
            } catch {
                delegate?.searchError(messageText: "Search Error", informativeText: "JSON decoding of search result failed: \(error.localizedDescription)")
            }
        } else {
            delegate?.searchError(messageText: "Search Error", informativeText: "No data received.")
        }
    }
    
    fileprivate func handle(jsonObject: [String: AnyObject]) {
        let jsonSearchResults = extractJsonSearchResults(jsonObject)
        var searchResults = extractSearchResults(jsonSearchResults)
        sortByName(&searchResults)
        delegate?.display(searchResults: searchResults) // done
    }

    fileprivate func extractJsonSearchResults(_ json: [String : AnyObject]) -> NSArray {
        var jsonSearchResults = NSArray()
        
        if let totalCount = json["total_count"] as? Int {
            if totalCount == 0 {
                delegate?.resetSearchResults(statusText: "No search results")
            } else {
                for (key, value) in json {
                    if key == "items",
                        let jsonSearchResultsArray = value as? NSArray
                    {
                        jsonSearchResults = jsonSearchResultsArray
                    }
                }
            }
        } else {
            delegate?.resetSearchResults(statusText: "No search results")
        }
        
        return jsonSearchResults
    }
    
    fileprivate func extractSearchResults(_ jsonSearchResultItemsArray: NSArray) -> [SearchResult] {
        var searchResults: [SearchResult] = []
        
        for itemArrayElement in jsonSearchResultItemsArray {
            if let item = itemArrayElement as? [String: AnyObject],
                let name = item["name"] as? String
            {
                let index = name.index(name.endIndex, offsetBy: -3)
                if name[index...] == ".rb",
                    let urlString = item["url"] as? String,
                    let url = URL(string: urlString)
                {
                    let searchResult = SearchResult(name: String(name[..<index]), url: url)
                    searchResults.append(searchResult)
                }
            }
        }

        return searchResults
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
