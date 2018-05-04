//
//  ViewController.swift
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

import Cocoa

protocol SearchProtocol {
    func startSearch(searchString: String)
}

protocol DownloadLocationProtocol {
    func getDownloadLocation(name: String, url: URL)
}

struct SearchResult {
    let name: String
    let url: URL
}

class ViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSSearchFieldDelegate, SearchDelegate, DownloadLocationDelegate {
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var statusTextField: NSTextField!
    @IBOutlet weak var button: NSButton!
    
    private let cellIdentifier = "searchResultCellIdentifier"
    private let defaultStatusString = "Enter app name and press \"Search\" button."
    private let search = Search()
    private let download = Download()
    private var searchResults: [SearchResult] = []
    private var searchStartedByButtonPress = false
    private var timer: Timer?
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        search.delegate = self
        download.delegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        searchField.delegate = self
        statusTextField.allowsEditingTextAttributes = true
        statusTextField.stringValue = defaultStatusString
   
        let cacheSize = 50 * 1024 * 1024; // 50 MB
        URLCache.shared = URLCache(memoryCapacity: cacheSize, diskCapacity: 0, diskPath: nil)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        if searchField.acceptsFirstResponder {
            searchField.window?.makeFirstResponder(searchField)
        }
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        statusTextField.preferredMaxLayoutWidth = statusTextField.frame.size.height
    }
    
    @IBAction func buttonPressed(_ sender: NSButton) {
        if searchField.stringValue != "" {
            searchStartedByButtonPress = true
            search.startSearch(searchString: searchField.stringValue)
        }
    }
    
    // MARK: - private
    
    private func showAlert(messageText: String, informativeText: String) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()) {
            let alert = NSAlert()
            alert.messageText = messageText
            alert.informativeText = informativeText
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    private func textFieldChanged() {
        if searchField.stringValue == "" {
            resetSearchResults(statusText: defaultStatusString)
        } else {
            if timer == nil {
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false, block: { (timer: Timer) in
                    let searchString = self.searchField.stringValue
                    if searchString != "" {
                        self.statusTextField.stringValue = "Searching for \"\(searchString)\"..."
                        self.search.startSearch(searchString: searchString)
                    }
                    self.timer = nil
                })
            }
        }
        
        updateButtonState()
    }
    
    private func updateButtonState() {
        if tableView.selectedRowIndexes.count != 0 || searchField.stringValue == "" {
            button.isEnabled = false
        } else {
            button.isEnabled = true
        }
    }
    
    // MARK: - NSSearchFieldDelegate
    
    override func controlTextDidChange(_ obj: Notification) {
        textFieldChanged()
    }
    
    // MARK: - NSControlTextEditingDelegate
    
    func control(_ control: NSControl, textShouldBeginEditing fieldEditor: NSText) -> Bool {
        tableView.deselectAll(nil)
        return true
    }
    
    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        return true
    }
    
    // MARK: - NSTableViewDataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let cell = tableView.make(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = searchResults[row].name
            return cell
        }
        
        return nil
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if tableView.selectedRowIndexes.count == 0 {
            statusTextField.stringValue = ""
        } else if tableView.selectedRowIndexes.count == 1 {
            self.statusTextField.stringValue = "Getting \"\(searchResults[tableView.selectedRow].name)\" download link..."
            
            if timer == nil {
                timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false, block: { (timer: Timer) in
                    let selectedRow = self.tableView.selectedRow
                    if selectedRow != -1 && self.searchResults.count > selectedRow {
                        let name = self.searchResults[selectedRow].name
                        let url = self.searchResults[selectedRow].url
                        self.updateButtonState()
                        self.download.getDownloadLocation(name: name, url: url)
                    }
                    self.timer = nil
                })
            }
        }
    }
    
    // MARK: - SearchDelegate
    
    func searchError(messageText: String, informativeText: String) {
        showAlert(messageText: messageText, informativeText: informativeText)
    }
    
    func resetSearchResults(statusText: String) {
        DispatchQueue.main.async {
            self.searchResults = []
            self.tableView.reloadData()
            self.searchStartedByButtonPress = false
            self.statusTextField.stringValue = statusText
        }
    }
    
    func display(searchResults: [SearchResult]) {
        DispatchQueue.main.async {
            self.searchResults = searchResults
            self.tableView.reloadData()
            self.button.isEnabled = true
            
            self.statusTextField.stringValue = "\(searchResults.count) result"
            if searchResults.count > 1 {
                self.statusTextField.stringValue = self.statusTextField.stringValue + "s"
            }
            
            if self.searchStartedByButtonPress {
                if searchResults.count > 0 {
                    self.tableView.window?.makeFirstResponder(self.tableView)
                    self.tableView.selectRowIndexes(NSIndexSet(index: 0) as IndexSet, byExtendingSelection: false)
                    self.updateButtonState()
                }
                self.searchStartedByButtonPress = false
            }
        }
    }
    
    // MARK: - DownloadDelegate
    
    func downloadLocationError(messageText: String, informativeText: String) {
        showAlert(messageText: messageText, informativeText: informativeText)
    }
    
    func downloadLocationFound(url: URL) {
        let font = NSFont.systemFont(ofSize: 13)
        let text = "Press URL to start download:<br /><a href=\"\(url.absoluteString)\">\(url.absoluteString)</a>"
        let html = "<span style=\"font-family:'\(font.fontName)'; font-size:\(font.pointSize);\">\(text)</span>"
        
        if let data = html.data(using: .utf8) {
            if let string = NSAttributedString(html: data, options: [:], documentAttributes: nil) {
                statusTextField.attributedStringValue = string
            }
        }
        
        // show pointing finger cursor when hovering over url by simulating a click into the text field
        statusTextField.selectText(nil)
        if let editor = statusTextField.currentEditor() {
            editor.selectedRange = NSMakeRange(0, 0)
        }
    }
}

