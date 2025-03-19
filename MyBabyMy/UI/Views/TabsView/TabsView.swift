//
//  TabsView.swift
//  MyBabyMy
//
//  Created by Blaze Mac on 12/7/16.
//  Copyright © 2016 Code Inspiration. All rights reserved.
//

import UIKit

protocol TabsViewSynchronizedScrolling : AnyObject
{
   var currentPage : CGFloat { get set}
   var leadsScrolling : Bool { get set}
   var dragging : Bool { get }
   var scrollingEnabled : Bool { get set}
   weak var syncScrollPartner: TabsViewSynchronizedScrolling? { get }
   func returnToCenterOfLoop()
}

extension TabsViewSynchronizedScrolling
{
   var pagesCount : Int { return TabsView.loopCount * 3 }
   
   func didScroll()
   {
      if dragging {
         leadsScrolling = true
      }
      else {
         syncScrollPartner?.scrollingEnabled = true
      }
      
      if leadsScrolling {
         syncScrollPartner?.currentPage = currentPage
      }
   }
   
   func didEndScrolling()
   {
      if leadsScrolling {
         syncScrollPartner?.returnToCenterOfLoop()
      }
      
      leadsScrolling = false
      returnToCenterOfLoop()
   }
}

protocol TabsViewDelegate : AnyObject
{
   func tabsViewShouldSelect(_ mediaType : BabyMediaType) -> Bool
   func tabsViewDidSelect(_ mediaType : BabyMediaType, animated : Bool)
}

class TabsView: UIView, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource, TabCellDelegate, TabsViewSynchronizedScrolling
{
   static let loopCount = 10000
   static let tabWidth : CGFloat =
   {
      let tabFont = UIFont.systemFont(ofSize: 13.24 * WidthRatio, weight: UIFontWeightMedium)
      let tabNames = [loc("PHOTO EVERYDAY"), loc("VIDEO EVERYDAY"), loc("PHOTO IN DYNAMICS")]
      
      var typeWidths : [CGFloat] = []
      
      for tabName in tabNames
      {
         let tabWidth = textSize(tabName, font: tabFont).width + 66 * WidthRatio
         typeWidths.append(tabWidth)
      }
      
      let totalWidth = typeWidths.reduce(0, +)
      
      var maxWidth : CGFloat = typeWidths.max()!
      var averageWidth = totalWidth / 3
      
      var width = max(averageWidth, maxWidth - 12 * WidthRatio)
      
      let diff = (ScreenWidth - totalWidth) / 3
      if diff > 0
      {
         width += diff
      }
      
      return width
   }()
   var tabSize : CGSize {
      return CGSize(width: TabsView.tabWidth, height: bounds.height)
   }
   
   
   @IBOutlet weak var collectionView: UICollectionView!
   @IBOutlet weak var collectionFlowLayout: UICollectionViewFlowLayout!
   
   weak var delegate : TabsViewDelegate?
   
   required init?(coder aDecoder: NSCoder)
   {
      super.init(coder: aDecoder)
      
      let view = Bundle.main.loadNibNamed("TabsView", owner: self, options: nil)![0] as! UIView
      
      collectionView.register(UINib(nibName: "TabCell", bundle: nil), forCellWithReuseIdentifier: "TabCell")
      collectionFlowLayout.itemSize = tabSize
      
      view.frame = self.bounds
      view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      self.addSubview(view)
   }
   
   override func layoutSubviews()
   {
      //collectionFlowLayout.invalidateLayout()
      collectionFlowLayout.itemSize = tabSize
      super.layoutSubviews()
   }
   
   private var needsUpdateSelectedType = false
   public func setStartType(_ startType : BabyMediaType)
   {
      let typeValue = CGFloat(startType.rawValue)
      let offsetX = TabsView.tabWidth * CGFloat(pagesCount) / 2 - collectionView.width / 2 + TabsView.tabWidth * (typeValue + 0.5)
      
      collectionView.setContentOffset(CGPoint(x : offsetX, y : 0), animated: false)
      
      if !needsUpdateSelectedType {
         needsUpdateSelectedType = true
         MainQueue.async { self.updateSelectedType() }
      }
   }
   
   func updateSelectedType()
   {
      let offsetCenter = collectionView.contentOffset.x + collectionView.width / 2
      
      for indexPath in collectionView.indexPathsForVisibleItems
      {
         if let cell = collectionView.cellForItem(at: indexPath) as? TabCell
         {
            let cellOffsetCenter = (CGFloat(indexPath.item) + 0.5) * TabsView.tabWidth
            cell.selection = 1 - abs(offsetCenter - cellOffsetCenter) / TabsView.tabWidth
         }
      }
      
      needsUpdateSelectedType = false
   }
   
   //MARK: - CollectionView

   public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
   {
      return pagesCount
   }
   
   public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
   {
      let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TabCell", for: indexPath) as! TabCell
      cell.mediaType = BabyMediaType(rawValue: indexPath.row % 3)!
      cell.delegate = self
      return cell
   }
   
   //MARK: - Cell delegate
   func tabCellSelectMediaType(_ cell : TabCell, _ mediaType : BabyMediaType)
   {
      guard scrollingEnabled || (syncScrollPartner == nil) else { return }
      guard let indexPath = collectionView.indexPath(for: cell) else { return }
      
      let shoudSelect = delegate?.tabsViewShouldSelect(mediaType) ?? true
      guard shoudSelect else { return }
      
      let offsetX = TabsView.tabWidth * (CGFloat(indexPath.item) + 0.5) - collectionView.width / 2
      
      if (abs(collectionView.contentOffset.x - offsetX) > 1)
      {
         leadsScrolling = true
         collectionView.setContentOffset(CGPoint(x : offsetX, y : 0), animated: true)
         delegate?.tabsViewDidSelect(mediaType, animated: true)
      }
   }
   
   //MARK: - Collection scrollview
   
   public func scrollViewDidScroll(_ scrollView: UIScrollView) {
      didScroll()
      updateSelectedType()
   }
   
   public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
      didEndScrolling()
   }
   
   public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
      didEndScrolling()
   }
   
   //paging
   public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>)
   {
      let targetX = targetContentOffset.pointee.x
      let targetCenter = targetX + scrollView.width / 2
      let targetCellNum = round(targetCenter / TabsView.tabWidth - 0.5)
      
      let cellOffsetCenter = (targetCellNum + 0.5) * TabsView.tabWidth

      targetContentOffset.pointee.x += (cellOffsetCenter - targetCenter)
      
      syncScrollPartner?.scrollingEnabled = true
   }
   
   //MARK: - TabsViewSynchronizedScrolling
   
   weak var syncScrollPartner: TabsViewSynchronizedScrolling?
   
   var dragging : Bool {
      return collectionView.isTracking
   }
   
   var leadsScrolling : Bool = false
   {
      didSet {
         syncScrollPartner?.scrollingEnabled = !leadsScrolling
      }
   }
   
   var scrollingEnabled : Bool
   {
      get {
         return collectionView.isScrollEnabled
      }
      set {
         collectionView.isScrollEnabled = newValue
         if !newValue {
            collectionView.setContentOffset(collectionView.contentOffset, animated: false)
         }
      }
   }
   
   var currentPage : CGFloat
   {
      get
      {
         let offsetCenter = collectionView.contentOffset.x + collectionView.width / 2
         let cellNum = offsetCenter / TabsView.tabWidth - 0.5
         return cellNum
      }
      set
      {
         let offsetX = (newValue + 0.5) * TabsView.tabWidth - collectionView.width / 2
         collectionView.contentOffset = CGPoint(x: offsetX, y: 0)
         updateSelectedType()
      }
   }
   
   func returnToCenterOfLoop()
   {
      if abs(0.5 - (collectionView.contentOffset.x / collectionView.contentSize.width)) > 0.25
      {
         let offsetCenter = collectionView.contentOffset.x + collectionView.width / 2
         let cellNum = offsetCenter / TabsView.tabWidth - 0.5
         let newCellNum = cellNum.truncatingRemainder(dividingBy: 3) + CGFloat(pagesCount) / 2
         
         let offsetX = (newCellNum + 0.5) * TabsView.tabWidth - collectionView.width / 2
         collectionView.contentOffset = CGPoint(x: offsetX, y: 0)
         
         if !needsUpdateSelectedType {
            needsUpdateSelectedType = true
            MainQueue.async { self.updateSelectedType() }
         }
      }
   }
}
