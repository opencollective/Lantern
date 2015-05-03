//
//  StatsViewController.swift
//  Hoverlytics
//
//  Created by Patrick Smith on 24/04/2015.
//  Copyright (c) 2015 Burnt Caramel. All rights reserved.
//

import Cocoa
import HoverlyticsModel
import Quartz


enum BaseContentTypeChoice: Int {
	case LocalHTMLPages = 1
	case Images = 2
	case Feeds = 3
	
	var baseContentType: BaseContentType {
		switch self {
		case .LocalHTMLPages:
			return .LocalHTMLPage
		case .Images:
			return .Image
		case .Feeds:
			return .Feed
		}
	}
}

extension BaseContentTypeChoice: MenuItemRepresentative {
	var title: String {
		switch self {
		case .LocalHTMLPages:
			return "Local Pages"
		case .Images:
			return "Images"
		case .Feeds:
			return "Feeds"
		}
	}
	var tag: Int? { return rawValue }
	
	typealias UniqueIdentifier = BaseContentTypeChoice
	var uniqueIdentifier: UniqueIdentifier { return self }
}


enum StatsFilterResponseChoice: Int {
	case All = 0
	
	case Successful = 2
	case Redirects = 3
	case RequestErrors = 4
	case ResponseErrors = 5
	
	case ValidInformation = 100
	case ProblematicMIMEType = 101
	case ProblematicPageTitle = 102
	case ProblematicHeading = 103
	case ProblematicMetaDescription = 104
	
	case IsLinkedByBrowsedPage = 200
	case ContainsLinkToBrowsedPage = 201
	
	
	var responseType: PageResponseType? {
		switch self {
		case .Successful:
			return .Successful
		case .Redirects:
			return .Redirects
		case .RequestErrors:
			return .RequestErrors
		case .ResponseErrors:
			return .ResponseErrors
		default:
			return nil
		}
	}
	
	var validationArea: PageInfoValidationArea? {
		switch self {
		case .ProblematicMIMEType:
			return .MIMEType
		case .ProblematicHeading:
			return .H1
		case .ProblematicPageTitle:
			return .Title
		case .ProblematicMetaDescription:
			return .MetaDescription
		default:
			return nil
		}
	}
	
	func pageLinkFilterWithURL(URL: NSURL) -> PageLinkFilter? {
		switch self {
		case .IsLinkedByBrowsedPage:
			return .IsLinkedByURL(URL)
		case .ContainsLinkToBrowsedPage:
			return .ContainsLinkToURL(URL)
		default:
			return nil
		}
	}
}

extension StatsFilterResponseChoice: MenuItemRepresentative {
	var title: String {
		switch self {
		case .All:
			return "All"
			
		case .Successful:
			return "[2xx] Successful"
		case .Redirects:
			return "[3xx] Redirects"
		case .RequestErrors:
			return "[4xx] Request Errors"
		case .ResponseErrors:
			return "[5xx] Response Errors"
			
		case .ValidInformation:
			return "Valid Information"
			
		case .ProblematicMIMEType:
			return "Invalid MIME Types"
		case .ProblematicHeading:
			return "Invalid Headings"
		case .ProblematicPageTitle:
			return "Invalid Page Titles"
		case .ProblematicMetaDescription:
			return "Invalid Meta Description"
			
		case .IsLinkedByBrowsedPage:
			return "Is Linked by Browsed Page"
		case .ContainsLinkToBrowsedPage:
			return "Contains Link to Browsed Page"
		}
	}
	
	var tag: Int? { return rawValue }
	
	typealias UniqueIdentifier = StatsFilterResponseChoice
	var uniqueIdentifier: UniqueIdentifier { return self }
}

enum StatsColumnsMode: Int {
	case Titles = 1
	case Descriptions = 2
	case Types = 3
	case DownloadSizes = 4
	case Links = 5
	
	func columnIdentifiersForBaseContentType(baseContentType: BaseContentType) -> [PagePresentedInfoIdentifier] {
		switch self {
		case .Titles:
			return [.pageTitle, .h1]
		case .Descriptions:
			return [.metaDescription, .pageTitle]
		case .Types:
			return [.statusCode, .MIMEType]
		case .DownloadSizes:
			switch baseContentType {
			case .LocalHTMLPage:
				return [.pageByteCount, .pageByteCountBeforeBodyTag, .pageByteCountAfterBodyTag]
			default:
				return [.pageByteCount]
			}
		case .Links:
			return [.internalLinkCount, .externalLinkCount]
		}
	}
	
	var title: String {
		switch self {
		case .Titles:
			return "Titles"
		case .Descriptions:
			return "Descriptions"
		case .Types:
			return "Types"
		case .DownloadSizes:
			return "Sizes"
		case .Links:
			return "Links"
		}
	}
}

extension StatsColumnsMode: SegmentedItemRepresentative {
	var tag: Int? { return rawValue }
	
	typealias UniqueIdentifier = StatsColumnsMode
	var uniqueIdentifier: UniqueIdentifier { return self }
}

extension StatsColumnsMode: Printable {
	var description: String {
		return title
	}
}

extension StatsFilterResponseChoice {
	var preferredColumnsMode: StatsColumnsMode? {
		switch self {
		case .ProblematicMIMEType:
			return .Types
		case .ProblematicPageTitle, .ProblematicHeading:
			return .Titles
		case .ProblematicMetaDescription:
			return .Descriptions
		default:
			return nil
		}
	}
}

extension BaseContentTypeChoice {
	var allowedColumnsModes: [StatsColumnsMode] {
		switch self {
		case .LocalHTMLPages:
			return [.Titles, .Descriptions, .Types, .DownloadSizes, .Links]
		default:
			return [.Types, .DownloadSizes]
		}
	}
}

extension PageResponseType {
	var cocoaColor: NSColor {
		switch self {
		case .RequestErrors, .ResponseErrors:
			return NSColor(SRGBRed: 233.0/255.0, green: 36.0/255.0, blue: 0.0, alpha: 1.0)
		default:
			return NSColor.textColor()
		}
	}
}


class StatsViewController: NSViewController {

	@IBOutlet var outlineView: NSOutlineView!
	
	@IBOutlet var columnsModeSegmentedControl: NSSegmentedControl!
	var columnsModeSegmentedControlAssistant: SegmentedControlAssistant<StatsColumnsMode>?
	
	@IBOutlet var filterResponseChoicePopUpButton: NSPopUpButton!
	var filterResponseChoicePopUpButtonAssistant: PopUpButtonAssistant<StatsFilterResponseChoice>?
	
	@IBOutlet var baseContentTypeChoicePopUpButton: NSPopUpButton!
	var baseContentTypeChoicePopUpButtonAssistant: PopUpButtonAssistant<BaseContentTypeChoice>?
	
	var rowMenu: NSMenu!
	
	
	var pageMapper: PageMapper?
	
	var browsedURL: NSURL?
	
	var chosenBaseContentChoice: BaseContentTypeChoice = .LocalHTMLPages
	var filterToBaseContentType: BaseContentType {
		return chosenBaseContentChoice.baseContentType
	}
	var filterResponseChoice: StatsFilterResponseChoice = .All
	var selectedColumnsMode: StatsColumnsMode = .Titles
	var allowedColumnsModes: [StatsColumnsMode] {
		return chosenBaseContentChoice.allowedColumnsModes
	}
	
	var filteredURLs = [NSURL]()
	
	var didChooseURLCallback: ((URL: NSURL, pageInfo: PageInfo) -> Void)?
	
	
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
		
		outlineView.removeTableColumn(outlineView.tableColumnWithIdentifier("text")!)
		
		//updateColumnsToOnlyShow(selectedColumnsMode.columnIdentifiersForBaseContentType(filterToBaseContentType))
		
		outlineView.setDataSource(self)
		outlineView.setDelegate(self)
		
		outlineView.target = self
		outlineView.doubleAction = "doubleClickSelectedRow:"
		
		createRowMenu()
		
		updateUI()
    }
	
	var primaryURL: NSURL! {
		didSet {
			browsedURL = primaryURL
			crawl()
		}
	}
	
	func didNavigateToURL(URL: NSURL, crawl: Bool) {
		if let pageMapper = pageMapper {
			browsedURL = URL
			updateListOfURLs()
			
			if crawl {
				pageMapper.addAdditionalURL(URL)
			}
		}
		else {
			primaryURL = URL
		}
	}
	
	var selectedURLs: [NSURL] {
		get {
			let outlineView = self.outlineView!
			var selectedRowIndexes = outlineView.selectedRowIndexes
			var result = [NSURL]()
			selectedRowIndexes.enumerateIndexesUsingBlock { (row, stopPointer) in
				if let item = outlineView.itemAtRow(row) as? NSURL {
					result.append(item)
				}
			}
			return result
		}
		set {
			let outlineView = self.outlineView!
			var newRowIndexes = NSMutableIndexSet()
			for URL in newValue {
				let row = outlineView.rowForItem(URL)
				if row != -1 {
					newRowIndexes.addIndex(row)
				}
			}
			outlineView.selectRowIndexes(newRowIndexes, byExtendingSelection: false)
		}
	}
	
	var previouslySelectedURLs = [NSURL]()
	
	func updateListOfURLs() {
		if let pageMapper = pageMapper {
			let baseContentType = filterToBaseContentType
			if filterResponseChoice == .All {
				filteredURLs = pageMapper.copyURLsWithBaseContentType(baseContentType)
			}
			else if let responseType = filterResponseChoice.responseType {
				filteredURLs = pageMapper.copyURLsWithBaseContentType(baseContentType, withResponseType: responseType)
			}
			else if filterResponseChoice == .ValidInformation {
				filteredURLs = pageMapper.copyHTMLPageURLsWhichCompletelyValidateForType(baseContentType)
			}
			else if let validationArea = filterResponseChoice.validationArea {
				filteredURLs = pageMapper.copyHTMLPageURLsForType(baseContentType, failingToValidateInArea: validationArea)
			}
			else if
				let browsedURL = browsedURL,
				let pageLinkFilter = filterResponseChoice.pageLinkFilterWithURL(browsedURL)
			{
				#if DEBUG
					println("filtering to browsedURL \(browsedURL)")
				#endif
				filteredURLs = pageMapper.copyHTMLPageURLsFilteredBy(pageLinkFilter)
			}
			else {
				fatalError("filterResponseChoice must be set to something valid")
			}
		}
		else {
			filteredURLs = []
		}
		
		outlineView.reloadData()
		
		self.selectedURLs = previouslySelectedURLs
	}
	
	func updateUI(
		baseContentType: Bool = true,
		filterResponseChoice: Bool = true,
		columnsMode: Bool = true
		)
	{
		if baseContentType {
			updateBaseContentTypeChoiceUI()
		}
		if filterResponseChoice {
			updateFilterResponseChoiceUI()
		}
		if columnsMode {
			updateColumnsModeUI()
		}
		
		updateListOfURLs()
	}
	
	func clearPageMapper() {
		if let oldPageMapper = pageMapper {
			oldPageMapper.cancel()
			pageMapper = nil
		}
	}
	
	func crawl() {
		clearPageMapper()
		
		if
			let primaryURL = self.primaryURL,
			let mappableURL = MappableURL(primaryURL: primaryURL)
		{
			let pageMapper = PageMapper(mappableURL: mappableURL)
			pageMapper.didUpdateCallback = { loadedPageURL in
				self.pageURLDidUpdate(loadedPageURL)
			}
			
			pageMapper.reload()
			
			self.pageMapper = pageMapper
		}
		else {
			updateListOfURLs()
			updateUI()
		}
	}
	
	var updateUIWithProgressOperation: NSBlockOperation!
	
	private func pageURLDidUpdate(pageURL: NSURL) {
		// Update the UI with a background quality of service using an operation.
		if updateUIWithProgressOperation == nil {
			let updateUIWithProgressOperation = NSBlockOperation(block: {
				self.updateUI()
				self.updateUIWithProgressOperation = nil
			})
			NSOperationQueue.mainQueue().addOperation(updateUIWithProgressOperation)
			self.updateUIWithProgressOperation = updateUIWithProgressOperation
		}
	}
	
	private func updateColumnsToOnlyShow(columnIdentifiers: [PagePresentedInfoIdentifier]) {
		func updateHeaderOfColumn(column: NSTableColumn, withTitleFromIdentifier identifier: PagePresentedInfoIdentifier) {
			(column.headerCell as! NSTableHeaderCell).stringValue = identifier.titleForBaseContentType(filterToBaseContentType)
		}
		
		let minColumnWidth: CGFloat = 130.0
		
		outlineView.beginUpdates()
		
		let uniqueColumnIdentifiers = Set(columnIdentifiers)
		let existingTableColumnIdentifierStrings = outlineView.tableColumns.map { return $0.identifier }
		for identifierString in existingTableColumnIdentifierStrings {
			if let identifier = PagePresentedInfoIdentifier(rawValue: identifierString) where !uniqueColumnIdentifiers.contains(identifier) && identifier != .requestedURL {
				outlineView.removeTableColumn(outlineView.tableColumnWithIdentifier(identifierString)!)
			}
		}
		
		let columnsRemainingWidth = outlineView.enclosingScrollView!.documentVisibleRect.width - outlineView.outlineTableColumn!.width - 12.0
		let columnWidth = max(columnsRemainingWidth / CGFloat(columnIdentifiers.count), minColumnWidth)
		
		var columnIndex = 1 // After outline column
		for identifier in columnIdentifiers {
			let existingColumnIndex = outlineView.columnWithIdentifier(identifier.rawValue)
			var tableColumn: NSTableColumn
			if existingColumnIndex >= 0 {
				tableColumn = outlineView.tableColumnWithIdentifier(identifier.rawValue)!
				outlineView.moveColumn(existingColumnIndex, toColumn: columnIndex)
			}
			else {
				tableColumn = NSTableColumn(identifier: identifier.rawValue)
				outlineView.addTableColumn(tableColumn)
			}
			
			tableColumn.minWidth = 60.0
			tableColumn.width = columnWidth
			updateHeaderOfColumn(tableColumn, withTitleFromIdentifier: identifier)
			
			columnIndex++
		}
		
		updateHeaderOfColumn(outlineView.outlineTableColumn!, withTitleFromIdentifier: .requestedURL)
		
		outlineView.endUpdates()
		
		//outlineView.resizeSubviewsWithOldSize(outlineView.bounds.rectByInsetting(dx: 1.0, dy: 0.0).size)
		//outlineView.resizeWithOldSuperviewSize(outlineView.bounds.size)
		outlineView.reloadData()
	}
	
	func changeColumnsMode(columnsMode: StatsColumnsMode, updateUI: Bool = true) {
		selectedColumnsMode = columnsMode
		
		if updateUI {
			updateColumnsModeUI()
			
			//columnsModeSegmentedControlAssistant?.selectedItemRepresentative = columnsMode
			
			//updateColumnsToOnlyShow(columnsMode.columnIdentifiersForBaseContentType(filterToBaseContentType))
		}
	}
	
	@IBAction func changeBaseContentTypeFilter(sender: NSPopUpButton) {
		let menuItem = sender.selectedItem!
		let tag = menuItem.tag
		
		let contentChoice = BaseContentTypeChoice(rawValue: tag)!
		chosenBaseContentChoice = contentChoice
		
		updateUI(baseContentType: false)
	}
	
	@IBAction func changeResponseTypeFilter(sender: NSPopUpButton) {
		let menuItem = sender.selectedItem!
		let tag = menuItem.tag
		
		filterResponseChoice = StatsFilterResponseChoice(rawValue: tag)!
		if let preferredColumnsMode = filterResponseChoice.preferredColumnsMode {
			changeColumnsMode(preferredColumnsMode)
		}
		
		updateUI(filterResponseChoice: false)
	}
	
	#if false
	
	@IBAction func showTitleColumns(sender: AnyObject?) {
		changeColumnsMode(StatsColumnsMode.Titles)
	}
	
	@IBAction func showDescriptionColumns(sender: AnyObject?) {
		changeColumnsMode(StatsColumnsMode.Descriptions)
	}
	
	@IBAction func showDownloadSizesColumns(sender: AnyObject?) {
		changeColumnsMode(StatsColumnsMode.DownloadSizes)
	}
	
	#endif
	
	@IBAction func changeColumnsMode(sender: NSSegmentedControl) {
		let tag = sender.tagOfSelectedSegment()
		if let columnsMode = StatsColumnsMode(rawValue: tag) {
			changeColumnsMode(columnsMode)
		}
	}
	
	@IBAction func doubleClickSelectedRow(sender: AnyObject?) {
		let row = outlineView.clickedRow
		let column = outlineView.clickedColumn
		if row != -1 {
			if
				let URL = outlineView.itemAtRow(row) as? NSURL,
				let pageInfo = pageMapper?.pageInfoForRequestedURL(URL)
			{
				// Double clicking requested URL chooses that URL.
				if column == 0 {
					didChooseURLCallback?(URL: URL, pageInfo: pageInfo)
				}
				else {
					showStringValuePreviewForResourceAtRow(row, column: column)
				}
			}
		}
	}
	
	@IBAction func pauseCrawling(sender: AnyObject?) {
		pageMapper?.pauseCrawling()
	}
	
	override func respondsToSelector(selector: Selector) -> Bool {
		switch selector {
		case "pauseCrawling:":
			return pageMapper?.isCrawling ?? false
		default:
			return super.respondsToSelector(selector)
		}
	}
}

// TODO: finish quicklook support, needs a local file cache
extension StatsViewController: QLPreviewPanelDataSource, QLPreviewPanelDelegate {
	override func keyDown(theEvent: NSEvent) {
		if let charactersIgnoringModifiers = theEvent.charactersIgnoringModifiers {
			let u = charactersIgnoringModifiers[charactersIgnoringModifiers.startIndex]
			
			if u == Character(" ") {
				// TODO: enable again
				//quickLookPreviewItems(self)
			}
		}
	}
	
	override func quickLookPreviewItems(sender: AnyObject?)
	{
		if let pageMapper = pageMapper {
			let selectedRowIndexes = outlineView.selectedRowIndexes
			if selectedRowIndexes.count == 1 {
				let row = selectedRowIndexes.firstIndex
				if let pageURL = outlineView.itemAtRow(row) as? NSURL where pageMapper.hasFinishedRequestingURL(pageURL)
				{
					
				}
			}
		}
	}
	
	func numberOfPreviewItemsInPreviewPanel(panel: QLPreviewPanel!) -> Int {
		return selectedURLs.count
	}
	
	func previewPanel(panel: QLPreviewPanel!, previewItemAtIndex index: Int) -> QLPreviewItem! {
		return selectedURLs[index]
	}
	
	override func acceptsPreviewPanelControl(panel: QLPreviewPanel!) -> Bool {
		return true
	}
	
	override func beginPreviewPanelControl(panel: QLPreviewPanel!) {
		panel.delegate = self
	}
	
	override func endPreviewPanelControl(panel: QLPreviewPanel!) {
		panel.delegate = nil
	}
}

extension StatsViewController {
	func createRowMenu() {
		// Row Menu
		rowMenu = NSMenu(title: "Row Menu")
		
		let showSourceItem = rowMenu.addItemWithTitle("Show Source", action: "showSourcePreviewForPageAtSelectedRow:", keyEquivalent: "")!
		showSourceItem.target = self
		
		let showStringValueItem = rowMenu.addItemWithTitle("Show This Value", action: "showStringValuePreviewForResourceAtSelectedRow:", keyEquivalent: "")!
		showStringValueItem.target = self
		
		rowMenu.addItem(NSMenuItem.separatorItem())
		
		let copyURLItem = rowMenu.addItemWithTitle("Copy URL", action: "copyURLForSelectedRow:", keyEquivalent: "")!
		copyURLItem.target = self
		
		//outlineView.menu = rowMenu
	}
	
	@IBAction func showSourcePreviewForPageAtSelectedRow(menuItem: NSMenuItem) {
		let row = outlineView.clickedRow
		if row != -1 {
			showSourcePreviewForPageAtRow(row)
		}
	}
	
	@IBAction func copyURLForSelectedRow(menuItem: NSMenuItem) {
		let row = outlineView.clickedRow
		if row != -1 {
			performCopyURLForURLAtRow(row)
		}
	}
	
	@IBAction func showStringValuePreviewForResourceAtSelectedRow(menuItem: NSMenuItem) {
		let row = outlineView.clickedRow
		let column = outlineView.clickedColumn
		if row != -1 && column != -1 {
			showStringValuePreviewForResourceAtRow(row, column: column)
		}
	}
	
	func presentedInfoIdentifierForTableColumn(tableColumn: NSTableColumn) -> PagePresentedInfoIdentifier? {
		return PagePresentedInfoIdentifier(rawValue: tableColumn.identifier)
	}
	
	func showStringValuePreviewForResourceAtRow(row: Int, column: Int) {
		let tableColumn = outlineView.tableColumns[column] as! NSTableColumn
		
		if
			let presentedInfoIdentifier = presentedInfoIdentifierForTableColumn(tableColumn),
			let pageURL = outlineView.itemAtRow(row) as? NSURL,
			let pageMapper = pageMapper
		{
			let presentedInfoIdentifier = presentedInfoIdentifier.longerFormInformation ?? presentedInfoIdentifier
			
			if let pageInfo = pageMapper.pageInfoForRequestedURL(pageURL) {
				let validatedStringValue = presentedInfoIdentifier.validatedStringValueInPageInfo(pageInfo, pageMapper: pageMapper)
				
				let previewViewController = MultipleStringPreviewViewController.instantiateFromStoryboard()
				switch validatedStringValue {
				case .Multiple(let values):
					previewViewController.validatedStringValues = values
				default:
					previewViewController.validatedStringValues = [validatedStringValue]
				}
				
				let rowRect = outlineView.frameOfCellAtColumn(column, row: row)
				presentViewController(previewViewController, asPopoverRelativeToRect: rowRect, ofView: outlineView, preferredEdge: NSMinYEdge, behavior: .Semitransient)
			}
		}
	}
	
	func showSourcePreviewForPageAtRow(row: Int) {
		if
			let pageURL = outlineView.itemAtRow(row) as? NSURL,
			let pageMapper = pageMapper where pageMapper.hasFinishedRequestingURL(pageURL)
		{
			if let pageInfo = pageMapper.pageInfoForRequestedURL(pageURL) {
				let sourcePreviewTabViewController = SourcePreviewTabViewController()
				sourcePreviewTabViewController.pageInfo = pageInfo
				
				let rowRect = outlineView.rectOfRow(row)
				presentViewController(sourcePreviewTabViewController, asPopoverRelativeToRect: rowRect, ofView: outlineView, preferredEdge: NSMinYEdge, behavior: .Semitransient)
			}
		}
	}
	
	func performCopyURLForURLAtRow(row: Int) {
		if let URL = outlineView.itemAtRow(row) as? NSURL
		{
			let pasteboard = NSPasteboard.generalPasteboard()
			pasteboard.clearContents()
			// This does not copy the URL as a string though
			//let success = pasteboard.writeObjects([URL])
			//println("Copying \(success) \(pasteboard) \(URL)")
			pasteboard.declareTypes([NSURLPboardType, NSStringPboardType], owner: nil)
			URL.writeToPasteboard(pasteboard)
			pasteboard.setString(URL.absoluteString!, forType: NSStringPboardType)
		}
	}
}

extension StatsViewController {
	func menuItemRepresentativesForFilterResponseChoice() -> [StatsFilterResponseChoice?] {
		switch filterToBaseContentType {
		case .LocalHTMLPage:
			return [
				.All,
				nil,
				.Successful,
				//.Redirects,
				.RequestErrors,
				.ResponseErrors,
				nil,
				.ValidInformation,
				//.ProblematicMIMEType,
				.ProblematicPageTitle,
				.ProblematicHeading,
				.ProblematicMetaDescription,
				nil,
				.IsLinkedByBrowsedPage,
				.ContainsLinkToBrowsedPage
			]
		default:
			return [
				.All,
				nil,
				.Successful,
				//.Redirects,
				.RequestErrors,
				.ResponseErrors,
				//nil,
				//.ValidInformation,
				//.ProblematicMIMEType,
			]
		}
	}
	
	func updateFilterResponseChoiceUI() {
		let popUpButton = filterResponseChoicePopUpButton
		
		if pageMapper == nil {
			popUpButton.hidden = true
			return
		}
		else {
			popUpButton.hidden = false
		}
		
		var popUpButtonAssistant = filterResponseChoicePopUpButtonAssistant ?? {
			let popUpButtonAssistant = PopUpButtonAssistant<StatsFilterResponseChoice>(popUpButton: popUpButton)
			
			let menuAssistant = popUpButtonAssistant.menuAssistant
			menuAssistant.titleReturner = { choice in
				switch choice {
				case .All:
					let baseContentType = self.filterToBaseContentType
					switch baseContentType {
					case .LocalHTMLPage:
						return "All Local Pages"
					case .Image:
						return "All Images"
					case .Feed:
						return "All Feeds"
					default:
						fatalError("Unimplemented base content type")
					}
				case .Successful, .Redirects, .RequestErrors, .ResponseErrors:
					let baseContentType = self.filterToBaseContentType
					let responseType = choice.responseType!
					let URLCount = self.pageMapper?.numberOfLoadedURLsWithBaseContentType(baseContentType, responseType: responseType) ?? 0
					return "\(choice.title) (\(URLCount))"
				default:
					return choice.title
				}
			}
			
			self.filterResponseChoicePopUpButtonAssistant = popUpButtonAssistant
			
			return popUpButtonAssistant
		}()
		
		popUpButtonAssistant.menuItemRepresentatives = menuItemRepresentativesForFilterResponseChoice()
		popUpButtonAssistant.update()
	}
}

extension StatsViewController {
	var baseContentTypeChoiceMenuItemRepresentatives: [BaseContentTypeChoice?] {
		return [
			.LocalHTMLPages,
			.Images,
			.Feeds
		]
	}
	
	func updateBaseContentTypeChoiceUI() {
		let popUpButton = baseContentTypeChoicePopUpButton
		
		if pageMapper == nil {
			popUpButton.hidden = true
			return
		}
		
		popUpButton.hidden = false
		
		let popUpButtonAssistant = baseContentTypeChoicePopUpButtonAssistant ?? {
			let popUpButtonAssistant = PopUpButtonAssistant<BaseContentTypeChoice>(popUpButton: popUpButton)
			
			let menuAssistant = popUpButtonAssistant.menuAssistant
			menuAssistant.titleReturner = { choice in
				let baseContentType = choice.baseContentType
				/*if false {
					let requestedURLCount = self.pageMapper.numberOfRequestedURLsWithBaseContentType(baseContentType)
					let loadedURLCount = self.pageMapper.numberOfLoadedURLsWithBaseContentType(baseContentType)
					return "\(choice.title) (\(loadedURLCount)/\(requestedURLCount))"
				}
				else {*/
					let loadedURLCount = self.pageMapper?.numberOfLoadedURLsWithBaseContentType(baseContentType) ?? 0
					return "\(choice.title) (\(loadedURLCount))"
				//}
			}
			
			self.baseContentTypeChoicePopUpButtonAssistant = popUpButtonAssistant
			return popUpButtonAssistant
		}()
		
		popUpButtonAssistant.menuItemRepresentatives = baseContentTypeChoiceMenuItemRepresentatives
		popUpButtonAssistant.update()
	}
}

extension StatsViewController {
	func updateColumnsModeUI() {
		let allowedColumnsModes = self.allowedColumnsModes
		let segmentedControl = columnsModeSegmentedControl
		
		if pageMapper != nil {
			segmentedControl.hidden = false
			
			let segmentedControlAssistant = columnsModeSegmentedControlAssistant ?? {
				let segmentedControlAssistant = SegmentedControlAssistant<StatsColumnsMode>(segmentedControl: segmentedControl)
				
				self.columnsModeSegmentedControlAssistant = segmentedControlAssistant
				return segmentedControlAssistant
				}()
			
			segmentedControlAssistant.segmentedItemRepresentatives = allowedColumnsModes
			segmentedControlAssistant.update()
			
			if segmentedControlAssistant.selectedUniqueIdentifier == nil {
				// If previous is not allowed, choose the first columns mode.
				changeColumnsMode(allowedColumnsModes[0], updateUI: false)
			}
			
			segmentedControlAssistant.selectedItemRepresentative = selectedColumnsMode
		}
		else {
			segmentedControl.hidden = true
		}
	
		updateColumnsToOnlyShow(selectedColumnsMode.columnIdentifiersForBaseContentType(filterToBaseContentType))
	}

}

extension StatsViewController: NSOutlineViewDataSource, NSOutlineViewDelegate {
	func outlineView(outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
		if item == nil {
			return filteredURLs.count
		}
		
		return 0
	}
	
	func outlineView(outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
		if item == nil {
			return filteredURLs[index]
		}
		
		fatalError("Outline view is only currently one level deep")
	}
	
	func outlineView(outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
		return false
	}
	
	func outlineView(outlineView: NSOutlineView, objectValueForTableColumn tableColumn: NSTableColumn?, byItem item: AnyObject?) -> AnyObject? {
		return item
	}
	
	func outlineView(outlineView: NSOutlineView, viewForTableColumn tableColumn: NSTableColumn?, item: AnyObject) -> NSView? {
		
		if
			let pageURL = item as? NSURL,
			let identifierString = tableColumn?.identifier,
			let identifier = PagePresentedInfoIdentifier(rawValue: identifierString)
		{
			var cellIdentifier = (identifier == .requestedURL ? "requestedURL" : "text")
			
			var stringValue: String
			var suffixString: String?
			var opacity: CGFloat = 1.0
			var textColor: NSColor = NSColor.textColor()
			
			if let pageMapper = pageMapper where pageMapper.hasFinishedRequestingURL(pageURL)
			{
				var validatedStringValue: ValidatedStringValue = .Missing
				
				if let pageInfo = pageMapper.pageInfoForRequestedURL(pageURL) {
					validatedStringValue = identifier.validatedStringValueInPageInfo(pageInfo, pageMapper: pageMapper)
					
					if
						let finalURL = pageInfo.finalURL,
						let redirectionInfo = pageMapper.redirectedDestinationURLToInfo[finalURL] {
							if identifier == .statusCode {
								suffixString = String(redirectionInfo.statusCode)
							}
					}
					
					textColor = PageResponseType(statusCode: pageInfo.statusCode).cocoaColor
				}
				
				switch validatedStringValue {
				case .ValidString(let string):
					stringValue = string
					if let suffixString = suffixString {
						stringValue += " " + suffixString
					}
				case .Missing:
					stringValue = "(none)"
					opacity = 0.3
				case .Empty:
					stringValue = "(empty)"
					opacity = 0.3
				case .Multiple:
					stringValue = "(multiple)"
					opacity = 0.3
				case .Invalid:
					stringValue = "(invalid)"
					opacity = 0.3
				}
			}
			else {
				let validatedStringValue = identifier.validatedStringValueForPendingURL(pageURL)
				
				switch validatedStringValue {
				case .ValidString(let string):
					stringValue = string
				default:
					stringValue = "(loading)"
					opacity = 0.2
				}
			}
			
			if let view = outlineView.makeViewWithIdentifier(cellIdentifier, owner: self) as? NSTableCellView {
				if let textField = view.textField {
					textField.stringValue = stringValue
					textField.textColor = textColor
				}
				view.alphaValue = opacity
				
				view.menu = rowMenu

				return view
			}
		}
		
		return nil
	}
	
	/* Seem to need both outlineViewSelectionIsChanging and outlineViewSelectionDidChange to correctly get the selection as the outline view updates quickly, either after selecting by mouse clicking or using the up/down arrow keys.
	*/
	func outlineViewSelectionIsChanging(notification: NSNotification)
	{
		previouslySelectedURLs = selectedURLs
	}
	
	func outlineViewSelectionDidChange(notification: NSNotification)
	{
		previouslySelectedURLs = selectedURLs
	}
}
