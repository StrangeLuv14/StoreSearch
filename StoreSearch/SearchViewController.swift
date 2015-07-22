//
//  ViewController.swift
//  StoreSearch
//
//  Created by 赵雨 on 7/18/15.
//  Copyright (c) 2015 Hippocn. All rights reserved.
//

import UIKit

class SearchViewController: UIViewController {
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    @IBAction func segmentChanged(sender: UISegmentedControl) {
        println("Segment changed: \(sender.selectedSegmentIndex)")
        PerformSearch()
    }
    
    var searchResults = [SearchResult]()
    var dataTask: NSURLSessionDataTask?
    
    var hasSearched = false
    var isLoading = false
    
    var landscapeViewController: LandscapeViewController?
    
    struct TableViewCellIdentifiers {
        static let searchResultCell = "SearchResultCell"
        static let nothingFoundCell = "NothingFoundCell"
        static let loadingCell = "LoadingCell"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        searchBar.becomeFirstResponder()
        
        tableView.contentInset = UIEdgeInsets(top: 108, left: 0, bottom: 0, right: 0)
        
        var cellNib = UINib(nibName: TableViewCellIdentifiers.searchResultCell, bundle: nil)
        tableView.registerNib(cellNib, forCellReuseIdentifier: TableViewCellIdentifiers.searchResultCell)
        tableView.rowHeight = 80
        
        cellNib = UINib(nibName: TableViewCellIdentifiers.nothingFoundCell, bundle: nil)
        tableView.registerNib(cellNib, forCellReuseIdentifier: TableViewCellIdentifiers.nothingFoundCell)
        
        cellNib = UINib(nibName: TableViewCellIdentifiers.loadingCell, bundle: nil)
        tableView.registerNib(cellNib, forCellReuseIdentifier: TableViewCellIdentifiers.loadingCell)
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ShowDetail" {
            let detailViewController = segue.destinationViewController as! DetailViewController
            let indexPath = sender as! NSIndexPath
            let searchResult = searchResults[indexPath.row]
            detailViewController.searchResult = searchResult
        }
    }
    
    override func willTransitionToTraitCollection(newCollection: UITraitCollection, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransitionToTraitCollection(newCollection, withTransitionCoordinator: coordinator)
        
        switch newCollection.verticalSizeClass {
        case .Compact:
            showLandscapeViewWithCoordinator(coordinator)
        case .Regular, .Unspecified:
            hideLandscapeViewWithCoordinator(coordinator)
        }
    }
    
    func showLandscapeViewWithCoordinator(coordinator: UIViewControllerTransitionCoordinator) {
        precondition(landscapeViewController == nil)
        
        landscapeViewController = storyboard!.instantiateViewControllerWithIdentifier("LandscapeViewController") as? LandscapeViewController
        if let controller = landscapeViewController {
            controller.searchResults = searchResults
            controller.view.frame = view.bounds
            controller.view.alpha = 0
            
            view.addSubview(controller.view)
            addChildViewController(controller)
            
            coordinator.animateAlongsideTransition({
                _ in
                controller.view.alpha = 1
                self.searchBar.resignFirstResponder()
                if self.presentedViewController != nil {
                    self.dismissViewControllerAnimated(true, completion: nil)
                }
                }, completion: {
                    _ in
                    controller.didMoveToParentViewController(self)
            })
        }
    }
    
    func hideLandscapeViewWithCoordinator(coordinatior: UIViewControllerTransitionCoordinator) {
        if let controller = landscapeViewController {
            controller.willMoveToParentViewController(nil)
            
            coordinatior.animateAlongsideTransition({
                _ in
                controller.view.alpha = 0
                }, completion: {
                    _ in
                    controller.view.removeFromSuperview()
                    controller.removeFromParentViewController()
                    self.landscapeViewController = nil
            })
        }
    }
    
    func urlWithSearchText(searchText: String, category: Int) -> NSURL {
        var entityName: String
        switch category {
        case 1: entityName = "musicTrack"
        case 2: entityName = "software"
        case 3: entityName = "ebook"
        default: entityName = ""
        }
        
        let escapedSearchText = searchBar.text.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!
        let urlString = String(format: "http://itunes.apple.com/search?term=%@&limit=200&entity=%@", escapedSearchText, entityName)
        let url = NSURL(string: urlString)
        return url!
    }
    
    func parseJSON(data: NSData) -> [String: AnyObject]? {
        var error: NSError?
        if let json = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(0), error: &error) as? [String: AnyObject] {
            println("\(json)")
            return json
        } else if let error = error {
            println("JSON Error: \(error)")
        } else {
            println("Unknown JSON Error")
        }
        return nil
    }
    
    func showNetworkError() {
        let alert = UIAlertController(title: "Whoops...", message: "There was an error reading from the iTunes Store. Please try again.", preferredStyle: .Alert)
        let action = UIAlertAction(title: "OK", style: .Default, handler: nil)
        alert.addAction(action)
        
        presentViewController(alert, animated: true, completion: nil)
    }
    
    func parseDictionary(dictionary: [String: AnyObject]) -> [SearchResult] {
        println("parseDictionary")
        var searchResults = [SearchResult]()
        
        if let array: AnyObject = dictionary["results"] {
            for resultDict in array as! [AnyObject] {
                if let resultDict = resultDict as? [String: AnyObject] {
                    var searchResult: SearchResult?
                    
                    if let wrappedType = resultDict["wrapperType"] as? NSString {
                        switch wrappedType {
                            case "track":
                                searchResult = parseTrack(resultDict)
                            case "audiobook":
                                searchResult = parseAudioBook(resultDict)
                            case "software":
                                searchResult = parseSoftware(resultDict)
                        default:break
                        }
                    } else if let kind = resultDict["kind"] as? String {
                        if kind == "ebook" {
                            searchResult = parseEBook(resultDict)
                        }
                    }
                        
                    if let result = searchResult {
                        searchResults.append(result)
                    }
                } else {
                    println("Expected a dictionary")
                }
            }
        } else {
            println("Expected 'results' array")
        }
        return searchResults
    }
    
    func parseTrack(dictionary: [String: AnyObject]) -> SearchResult {
        let searchResult = SearchResult()
        
        searchResult.name = dictionary["trackName"] as! String
        searchResult.artistName = dictionary["artistName"] as! String
        searchResult.artworkURL60 = dictionary["artworkUrl60"] as! String
        searchResult.artworkURL100 = dictionary["artworkUrl100"] as! String
        searchResult.storeURL = dictionary["trackViewUrl"] as! String
        searchResult.kind = dictionary["kind"] as! String
        searchResult.currency = dictionary["currency"] as! String
        
        if let price = dictionary["trackPrice"] as? Double {
            searchResult.price = price
        }
        if let genre = dictionary["primaryGenreName"] as? String {
            searchResult.genre = genre
        }
        
        return searchResult
    }
    
    func parseAudioBook(dictionary: [String: AnyObject]) -> SearchResult {
        let searchResult = SearchResult()
        
        searchResult.name = dictionary["collectionName"] as! String
        searchResult.artistName = dictionary["artistName"] as! String
        searchResult.artworkURL60 = dictionary["artworkUrl60"] as! String
        searchResult.artworkURL100 = dictionary["artworkUrl100"] as! String
        searchResult.storeURL = dictionary["collectionViewUrl"] as! String
        searchResult.kind = "audiobook"
        searchResult.currency = dictionary["currency"] as! String
        
        if let price = dictionary["collectionPrice"] as? Double {
            searchResult.price = price
        }
        if let genre = dictionary["primaryGenreName"] as? String {
            searchResult.genre = genre
        }
        
        return searchResult
    }
    
    func parseSoftware(dictionary: [String: AnyObject]) -> SearchResult {
        let searchResult = SearchResult()
        
        searchResult.name = dictionary["trackName"] as! String
        searchResult.artistName = dictionary["artistName"] as! String
        searchResult.artworkURL60 = dictionary["artworkUrl60"] as! String
        searchResult.artworkURL100 = dictionary["artworkUrl100"] as! String
        searchResult.storeURL = dictionary["trackViewUrl"] as! String
        searchResult.kind = dictionary["kind"] as! String
        searchResult.currency = dictionary["currency"] as! String
        
        if let price = dictionary["price"] as? Double {
            searchResult.price = price
        }
        if let genre = dictionary["primaryGenreName"] as? String {
            searchResult.genre = genre
        }
        
        return searchResult
    }
    
    func parseEBook(dictionary: [String: AnyObject]) -> SearchResult {
        let searchResult = SearchResult()
        
        searchResult.name = dictionary["trackName"] as! String
        searchResult.artistName = dictionary["artistName"] as! String
        searchResult.artworkURL60 = dictionary["artworkUrl60"] as! String
        searchResult.artworkURL100 = dictionary["artworkUrl100"] as! String
        searchResult.storeURL = dictionary["trackViewUrl"] as! String
        searchResult.kind = dictionary["kind"] as! String
        searchResult.currency = dictionary["currency"] as! String
        
        if let price = dictionary["price"] as? Double {
            searchResult.price = price
        }
        if let genres: AnyObject = dictionary["genres"] {
            searchResult.genre = ", ".join(genres as! [String])
        }
        
        return searchResult
    }
}

// MARK: - Extension UISearchBarDelegate

extension SearchViewController: UISearchBarDelegate {
    func PerformSearch() {
        if !searchBar.text.isEmpty {
            searchBar.resignFirstResponder()
            
            dataTask?.cancel()
            
            isLoading = true
            tableView.reloadData()
            
            searchResults = [SearchResult]()
            hasSearched = true
            
            let url = self.urlWithSearchText(searchBar.text, category: segmentedControl.selectedSegmentIndex)
            
            let session = NSURLSession.sharedSession()
            
            dataTask = session.dataTaskWithURL(url, completionHandler: {
                data, response, error in
                
                if let error = error {
                    println("Failure! \(error)")
                    if error.code == -999 {return}
                } else if let httpResponse = response as? NSHTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        if let dictionary = self.parseJSON(data) {
                            println("On the main thread? " + (NSThread.currentThread().isMainThread ? "Yes" : "No"))
                            
                            self.searchResults = self.parseDictionary(dictionary)
                            self.searchResults.sort(<)
                            
                            dispatch_async(dispatch_get_main_queue()) {
                                self.isLoading = false
                                self.tableView.reloadData()
                            }
                            return
                        }
                    } else {
                        println("Failure! \(response)")
                    }
                }
                
                dispatch_async(dispatch_get_main_queue()) {
                    self.hasSearched = false
                    self.isLoading = false
                    self.tableView.reloadData()
                    self.showNetworkError()
                }
            })
            dataTask?.resume()
        }
    }
    
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        PerformSearch()
    }

    func positionForBar(bar: UIBarPositioning) -> UIBarPosition {
        return .TopAttached
    }
}

// MARK: - Extension UITableViewDataSource

extension SearchViewController: UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isLoading {
            return 1
        } else if !hasSearched {
            return 0
        } else if searchResults.count == 0 {
            return 1
        } else {
            return searchResults.count
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if isLoading {
            let cell = tableView.dequeueReusableCellWithIdentifier(TableViewCellIdentifiers.loadingCell, forIndexPath: indexPath) as! UITableViewCell
            
            let spinner = cell.viewWithTag(100) as! UIActivityIndicatorView
            spinner.startAnimating()
            
            return cell
        } else if searchResults.count == 0 {
            return tableView.dequeueReusableCellWithIdentifier(TableViewCellIdentifiers.nothingFoundCell, forIndexPath: indexPath) as! UITableViewCell
        } else {
            let cell = tableView.dequeueReusableCellWithIdentifier(TableViewCellIdentifiers.searchResultCell, forIndexPath: indexPath) as! SearchResultCell
            
            let searchResult = searchResults[indexPath.row]
            cell.configureForSearchResult(searchResult)
            return cell
        }
    }
    
    func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
        if searchResults.count == 0 || isLoading {
            return nil
        } else {
            return indexPath
        }
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        performSegueWithIdentifier("ShowDetail", sender: indexPath)
    }
}


// MARK: - Extension UITableViewDelegate

extension SearchViewController: UITableViewDelegate {

}
