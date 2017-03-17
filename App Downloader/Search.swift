//
//  Search.swift
//  AppDownloader
//
//  Copyright (C) 2017 Jahn Bertsch
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

protocol SearchDelegate {
    func searchError(messageText: String, informativeText: String)
    func resetSearchResults(statusText: String)
    func display(searchResults: [SearchResult])
}

class Search: SearchProtocol {

    private let config: URLSessionConfiguration
    private let session: URLSession
    
    public var delegate: SearchDelegate? = nil
    
    init() {
        config = URLSessionConfiguration.default
        session = URLSession(configuration: config)
    }
    
    func startSearch(searchString: String) {
        if let url = URL(string: "https://api.github.com/search/code?q=repo:caskroom/homebrew-cask+" + searchString) {
            let task = session.dataTask(with: url, completionHandler: searchCompletionHandler)
            task.resume() // do the search
        }
    }
    
    func searchCompletionHandler(dataOptional: Data?, responseOptional: URLResponse?, errorOptional: Error?) {
        if let error = errorOptional {
            delegate?.searchError(messageText: "Search Error", informativeText: error.localizedDescription)
        } else {
            if let data = dataOptional {
                parseSearchResult(data: data)
            }
        }
    }
    
    func parseSearchResult(data: Data) {
        do {
            let json = try JSONSerialization.jsonObject(with: data) as! [String: AnyObject]
            parseSearchResult(json: json)
        } catch {
            delegate?.searchError(messageText: "Search Error", informativeText: "JSON decoding failed: \(error.localizedDescription)")
        }
    }
    
    func parseSearchResult(json: [String: AnyObject]) {
        if let totalCount = json["total_count"] as? Int {
            if totalCount == 0 {
                delegate?.resetSearchResults(statusText: "No search results")
            } else {
                for (key, value) in json {
                    if key == "items" {
                        if let itemsArray = value as? NSArray {
                            parseSearchResult(itemsArray: itemsArray)
                        }
                    }
                }
            }
        } else {
            delegate?.resetSearchResults(statusText: "No search results")
        }
    }
    
    func parseSearchResult(itemsArray: NSArray) {
        var searchResults: [SearchResult] = []
        
        for itemArrayElement in itemsArray {
            if let item = itemArrayElement as? [String: AnyObject] {
                if let name = item["name"] as? String {
                    let suffix = name.substring(from: name.index(name.characters.endIndex, offsetBy: -3))
                    if suffix == ".rb" {
                        let nameWithoutSuffix = name.substring(to: name.index(name.characters.endIndex, offsetBy: -3))
                        
                        if let urlString = item["url"] as? String {
                            if let url = URL(string: urlString) {
                                let searchResult = SearchResult(name: nameWithoutSuffix, url: url)
                                searchResults.append(searchResult)
                            }
                        }
                    }
                }
            }
        }
        
        searchResults.sort { (a, b) -> Bool in
            if a.name < b.name {
                return true
            } else {
                return false
            }
        }
        
        delegate?.display(searchResults: searchResults)
    }

}
