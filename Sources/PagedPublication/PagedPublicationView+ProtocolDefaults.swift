//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

public extension PagedPublicationViewDelegate {
    func pageIndexesChanged(current currentPageIndexes: IndexSet, previous oldPageIndexes: IndexSet, in pagedPublicationView: PagedPublicationView) {}
    func pageIndexesFinishedChanging(current currentPageIndexes: IndexSet, previous oldPageIndexes: IndexSet, in pagedPublicationView: PagedPublicationView) {}
    func didFinishLoadingPageImage(imageURL: URL, pageIndex: Int, in pagedPublicationView: PagedPublicationView) {}
    
    // MARK: Hotspot events
    func didTap(pageIndex: Int, locationInPage: CGPoint, hittingHotspots: [PagedPublicationView.HotspotModel], in pagedPublicationView: PagedPublicationView) {}
    func didLongPress(pageIndex: Int, locationInPage: CGPoint, hittingHotspots: [PagedPublicationView.HotspotModel], in pagedPublicationView: PagedPublicationView) {}
    func didDoubleTap(pageIndex: Int, locationInPage: CGPoint, hittingHotspots: [PagedPublicationView.HotspotModel], in pagedPublicationView: PagedPublicationView) {}
    
    // MARK: Outro events
    func outroDidAppear(_ outroView: PagedPublicationView.OutroView, in pagedPublicationView: PagedPublicationView) {}
    func outroDidDisappear(_ outroView: PagedPublicationView.OutroView, in pagedPublicationView: PagedPublicationView) {}
    
    // MARK: Loading events
    func didStartReloading(in pagedPublicationView: PagedPublicationView) {}
    func didLoad(publication publicationModel: PagedPublicationView.PublicationModel, in pagedPublicationView: PagedPublicationView) {}
    func didLoad(pages pageModels: [PagedPublicationView.PageModel], in pagedPublicationView: PagedPublicationView) {}
    func didLoad(hotspots hotspotModels: [PagedPublicationView.HotspotModel], in pagedPublicationView: PagedPublicationView) {}
    
    func backgroundColor(publication: PagedPublicationView.PublicationModel, in pagedPublicationView: PagedPublicationView) -> UIColor? {
        return nil
    }
}

// MARK: -

public extension PagedPublicationViewDataSource {
    func outroViewProperties(for pagedPublicationView: PagedPublicationView) -> PagedPublicationView.OutroViewProperties? { return nil }
    func configure(outroView: PagedPublicationView.OutroView, for pagedPublicationView: PagedPublicationView) { }
    
    func textForPageNumberLabel(pageIndexes: IndexSet, pageCount: Int, for pagedPublicationView: PagedPublicationView) -> String? {
        guard let first = pageIndexes.first, let last = pageIndexes.last else {
            return nil
        }
        if first == last {
            return "\(first+1) / \(pageCount)"
        } else {
            return "\(first+1)-\(last+1) / \(pageCount)"
        }
    }
}

extension PagedPublicationView: PagedPublicationViewDataSource { }
