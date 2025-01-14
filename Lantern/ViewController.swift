//
//	ViewController.swift
//	Hoverlytics for Mac
//
//	Created by Patrick Smith on 28/03/2015.
//	Copyright (c) 2015 Burnt Caramel. All rights reserved.
//

import Cocoa
import BurntFoundation
import LanternModel


class ViewController : NSViewController
{
	var modelManager: LanternModel.ModelManager!
	
	// MARK: Page Mapper
	
	var pageMapper: PageMapper?
	
	func clearPageMapper() {
		pageMapper?.cancel()
		pageMapper = nil
	}
	
	enum Change {
		case toggleableViews(shown: Set<ToggleableViewIdentifier>)
	}
	var changeCallback: ((_ change: Change) -> ())?
	
	var pageMapperCreatedCallbacks: [UUID: (PageMapper) -> ()] = [:]
	func createPageMapper(primaryURL: URL) -> PageMapper? {
		clearPageMapper()
		pageMapper = PageMapper(primaryURL: primaryURL)
		
		if let pageMapper = pageMapper {
			for (_, callback) in pageMapperCreatedCallbacks {
				callback(pageMapper)
			}
		}
		
		return pageMapper
	}
	
	subscript(pageMapperCreatedCallback uuid: UUID) -> ((PageMapper) -> ())? {
		get {
			return pageMapperCreatedCallbacks[uuid]
		}
		set(callback) {
			pageMapperCreatedCallbacks[uuid] = callback
		}
	}
	
	var activeURL: URL? {
		didSet {
			activeURLChanged()
		}
	}
	
	var activeURLChangedCallbacks: [UUID: (URL?) -> ()] = [:]
	func activeURLChanged() {
		for (_, callback) in activeURLChangedCallbacks {
			callback(activeURL)
		}
		
		guard let url = activeURL else { return }
		
		if self.mainState.chosenSite == nil {
			self.mainState.initialHost = url.host
		}
		
		self.view.window?.title = url.host ?? url.absoluteString
		
		if pageViewController.crawlWhileBrowsing {
			// Can only crawl the initial 'local' website.
			let isLocal: Bool = {
				if let initialHost = self.mainState.initialHost {
					return url.host == initialHost
				}
				
				return false
			}()
			
			#if DEBUG
				print("navigatedURLDidChangeCallback \(url)")
			#endif
			self.statsViewController.didNavigateToURL(url, crawl: isLocal)
		}
	}
	
	subscript(activeURLChangedCallback uuid: UUID) -> ((URL?) -> ())? {
		get {
			return activeURLChangedCallbacks[uuid]
		}
		set(callback) {
			activeURLChangedCallbacks[uuid] = callback
		}
	}
	
	// MARK: -
	
	var section: MainSection!
	
	var mainState: MainState! {
		didSet {
			startObservingModelManager()
			updateMainViewForState()
			startObservingBrowserPreferences()
			
			updatePreferredBrowserWidth()
		}
	}
	
	var mainStateNotificationObservers = [NSObjectProtocol]()
	var browserPreferencesObserver: NotificationObserver<BrowserPreferences.Notification>!
	
	func startObservingModelManager() {
		let nc = NotificationCenter.default
		let mainQueue = OperationQueue.main
		
		let observer = nc.addObserver(forName: MainState.chosenSiteDidChangeNotification, object: mainState, queue: mainQueue) { [weak self] _ in
			self?.updateMainViewForState()
		}
		mainStateNotificationObservers.append(observer)
	}
	
	func stopObservingModelManager() {
		let nc = NotificationCenter.default
		
		for observer in mainStateNotificationObservers {
			nc.removeObserver(observer)
		}
		mainStateNotificationObservers.removeAll()
	}
	
	func updatePreferredBrowserWidth() {
		pageViewController?.preferredBrowserWidth = mainState.browserPreferences.widthChoice.value
	}
	
	func startObservingBrowserPreferences() {
		browserPreferencesObserver = NotificationObserver<BrowserPreferences.Notification>(object: mainState.browserPreferences)
		
		browserPreferencesObserver.observe(.widthChoiceDidChange) { notification in
			self.updatePreferredBrowserWidth()
		}
	}
	
	func stopObservingBrowserPreferences() {
		browserPreferencesObserver.stopObserving()
		browserPreferencesObserver = nil
	}
	
	deinit {
		stopObservingModelManager()
		stopObservingBrowserPreferences()
	}
	
	
	lazy var pageStoryboard: NSStoryboard = {
		NSStoryboard(name: "Page", bundle: nil)
	}()
	var mainSplitViewController: NSSplitViewController!
	var pageViewController: PageViewController!
	var statsViewController: StatsViewController!
	
	var lastChosenSite: SiteValues?
	
	func updateMainViewForState() {
		let site = mainState?.chosenSite
		if site?.UUID == lastChosenSite?.UUID {
			return
		}
		lastChosenSite = site
		
		if let site = site {
			let initialURL = site.homePageURL
			mainState.initialHost = initialURL.host
			
			#if false
				pageViewController.GoogleOAuth2TokenJSONString = site.GoogleAPIOAuth2TokenJSONString
				pageViewController.hoverlyticsPanelDidReceiveGoogleOAuth2TokenCallback = { [unowned self] tokenJSONString in
				self.modelManager.setGoogleOAuth2TokenJSONString(tokenJSONString, forSite: site)
				}
			#endif
			
				
			pageViewController.loadURL(initialURL)
			
			
			statsViewController.primaryURL = site.homePageURL
		}
		else {
			statsViewController.primaryURL = nil
			mainState.initialHost = nil
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		mainSplitViewController = NSSplitViewController()
		mainSplitViewController.splitView.isVertical = false
		mainSplitViewController.splitView.dividerStyle = .thin
		
		let storyboard = self.pageStoryboard
		
		// The top web browser
		let pageViewController = storyboard.instantiateController(withIdentifier: "Page View Controller") as! PageViewController
		pageViewController.toggledViewsDidChangeCallback = { [weak self] shownViews in
			self?.changeCallback?(.toggleableViews(shown: shownViews))
		}
		
		// The bottom page crawler table
		let statsViewController = storyboard.instantiateController(withIdentifier: "Stats View Controller") as! StatsViewController
		statsViewController.didChooseURLCallback = { url, pageInfo in
			if pageInfo.baseContentType == .localHTMLPage {
				// FIXME: use active URL instead?
				self.pageViewController.loadURL(url)
			}
		}
		
		mainSplitViewController.addSplitViewItem({
			let item = NSSplitViewItem(viewController: pageViewController)
			//item.canCollapse = true
			return item
			}())
		self.pageViewController = pageViewController
		
		mainSplitViewController.addSplitViewItem({
			let item = NSSplitViewItem(viewController: statsViewController)
			//item.canCollapse = true
			return item
		}())
		self.statsViewController = statsViewController
		
		fill(withChildViewController: mainSplitViewController)
	}
	
	
	//lazy var siteSettingsStoryboard = NSStoryboard(name: "SiteSettings", bundle: nil)
	var siteSettingsStoryboard = NSStoryboard(name: "SiteSettings", bundle: nil)
	lazy var addSiteViewController: SiteSettingsViewController = {
		let vc = self.siteSettingsStoryboard.instantiateController(withIdentifier: "Add Site View Controller") as! SiteSettingsViewController
		vc.modelManager = self.modelManager
		vc.mainState = self.mainState
		return vc
	}()
	lazy var siteSettingsViewController: SiteSettingsViewController = {
		let vc = self.siteSettingsStoryboard.instantiateController(withIdentifier: "Site Settings View Controller") as! SiteSettingsViewController
		vc.modelManager = self.modelManager
		vc.mainState = self.mainState
		return vc
	}()
	
	
	@IBAction func showAddSiteRelativeToView(_ relativeView: NSView) {
		if addSiteViewController.presentingViewController != nil {
			dismiss(addSiteViewController)
		}
		else {
			present(addSiteViewController, asPopoverRelativeTo: relativeView.bounds, of: relativeView, preferredEdge: NSRectEdge.maxY, behavior: .semitransient)
		}
	}
	
	
	@IBAction func showURLSettings(_ button: NSButton) {
		let vc = self.siteSettingsViewController
		
		if vc.presentingViewController != nil {
			dismiss(vc)
		}
		else {
			let modelManager = self.modelManager!
			
			print("ACTIVE")
			let activeURL = self.activeURL
			print(activeURL)
			
			let activeSite = activeURL.flatMap { modelManager.siteWithURL(url: $0) }
			print(activeSite)
			
			if let activeSite = activeSite {
				vc.editFavorite(url: activeSite.homePageURL, name: activeSite.name)
			}
			else if let activeURL = activeURL {
				vc.editVisited(url: activeURL)
			}
			else {
				vc.reset()
			}
			
			vc.favoriteNameForURL = { url in
				guard let foundSite = modelManager.siteWithURL(url: url) else {
					return nil
				}
				return foundSite.name
			}
			
			vc.onSaveSite = { vc in
				do {
					if let output = try vc.read(siteUUID: activeSite?.UUID) {
						if output.saveInFavorites {
							modelManager.addOrUpdateSite(values: output.siteValues)
						}
						else {
							modelManager.removeSite(url: output.siteValues.homePageURL)
						}
						
						self.pageViewController.loadURL(output.siteValues.homePageURL)
					}
				}
				catch {
					NSApplication.shared.presentError(error as NSError, modalFor: self.view.window!, delegate: nil, didPresent: nil, contextInfo: nil)
				}
			}
			
			present(vc, asPopoverRelativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.maxY, behavior: .semitransient)
		}
	}
	
	@IBAction func toggleShownViews(_ sender: Any?) {
			pageViewController.toggleShownViews(sender)
	}
	
	@IBAction func exportCSV(_ sender: Any?) {
		guard let pageMapper = pageMapper else { return }
		
		let savePanel = NSSavePanel()
		savePanel.allowedFileTypes = [(kUTTypeCommaSeparatedText as String)]
		savePanel.nameFieldStringValue = "pages.csv"
		
		let window = self.view.window!
		savePanel.beginSheetModal(for: window) { [weak self] response in
			guard let self = self else { return }
			guard .OK == response, let url = savePanel.url else { return }
			
			var csvCreator = CrawledResultsCSVCreator()
			csvCreator.baseContentType = .localHTMLPage
			
			do {
				let data = try csvCreator.csvData(pageMapper: pageMapper)
				try data.write(to: url)
			}
			catch (let error) {
				self.presentError(error)
			}
		}
	}
	
	override func supplementalTarget(forAction action: Selector, sender: Any?) -> Any? {
		if statsViewController.responds(to: action) {
			return statsViewController
		}
		
		if pageViewController.responds(to: action) {
			return pageViewController
		}
		
		return super.supplementalTarget(forAction: action, sender: sender)
	}
	
	
	override var representedObject: Any? {
		didSet {
			
		}
	}
}

extension ViewController : PageMapperProvider {}
