//
//  ViewController.swift
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

import Cocoa

struct SearchResult {
    let name: String
    let description: String
    let homepage: String
    let url: URL
    let sha256: String
}

class ViewController: NSViewController, NSTableViewDelegate {
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var statusTextField: NSTextField!
    @IBOutlet weak var button: NSButton!
    
    private let cellIdentifier = "searchResultCellIdentifier"
    private let defaultStatusString = "Enter app name and press \"Search\" button."
    private let search = Search()
    private var searchResults: [SearchResult] = []
    private var searchStartedByButtonPress = false
    private var timer: Timer?
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        search.delegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        searchField.delegate = self
        statusTextField.allowsEditingTextAttributes = true
        statusTextField.stringValue = defaultStatusString
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
                        self.search.startSearch(searchString: searchString.lowercased())
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
    
    private func resetSearchResults(statusText: String) {
        self.searchResults = []
        self.tableView.reloadData()
        self.searchStartedByButtonPress = false
        self.statusTextField.stringValue = statusText
    }
}

// MARK: - NSSearchFieldDelegate

extension ViewController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        textFieldChanged()
    }
}

// MARK: - NSControlTextEditingDelegate

extension ViewController: NSControlTextEditingDelegate {
    func control(_ control: NSControl, textShouldBeginEditing fieldEditor: NSText) -> Bool {
        tableView.deselectAll(nil)
        return true
    }
    
    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        return true
    }
}

// MARK: - NSTableViewDataSource

extension ViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = searchResults[row].name
            return cell
        }
        
        return nil
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if tableView.selectedRowIndexes.count == 0 {
            statusTextField.stringValue = ""
        } else if tableView.selectedRowIndexes.count == 1 && tableView.selectedRow < searchResults.count {
            display(searchResult: searchResults[tableView.selectedRow])
        }
    }

    fileprivate func display(searchResult: SearchResult) {
        var text = ""
        text += "\(searchResult.name)<br />"
        text += "\(searchResult.description)<br />"
        text += "Homepage: \(url(searchResult.homepage))<br />"
        text += "<br />Press URL to start download:<br />\(url(searchResult.url.absoluteString))"
        
        let html = "<span style=\"font-family: -apple-system; font-size: 13; color:\(NSColor.labelColorHexString);\">\(text)</span>"
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue]
        
        if let data = html.data(using: .utf8),
            let string = NSAttributedString(html: data, options: options, documentAttributes: nil)
        {
            statusTextField.attributedStringValue = string
        }
    }
    
    fileprivate func url(_ href: String) -> String {
        var href = href // mutable copy
        if href.last == "/" {
            href.removeLast()
        }
        return "<a href=\"\(href)\" style=\"text-decoration:none;\">\(href)</a>"
    }
}

// MARK: - SearchDelegate

extension ViewController: SearchDelegate {
    func searchError(messageText: String, informativeText: String) {
        showAlert(messageText: messageText, informativeText: informativeText)
    }
    
    func display(searchResults: [SearchResult]) {
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
