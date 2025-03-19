//
//  SettingsProAccount.swift
//  MyBabyMy
//
//  Created by Dmitry on 05.01.17.
//  Copyright © 2017 Code Inspiration. All rights reserved.
//

import UIKit
import StoreKit

let proDateFormatter : DateFormatter =
{
   let dateFormatter = DateFormatter()
   dateFormatter.timeStyle = .none
   dateFormatter.dateStyle = .long
   dateFormatter.locale = locale
   dateFormatter.timeZone = calendar.timeZone
   return dateFormatter
}()

class SettingsProAccount: UIViewController, UICollectionViewDelegate , UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, SKProductsRequestDelegate , SKPaymentTransactionObserver
{   
   @IBOutlet weak var proDateLabel: UILabel!
   
	@IBOutlet weak var failedRequestLabel: UILabel!
	@IBOutlet weak var retryRequestButton: UIButton!

	@IBOutlet weak var collectionView: UICollectionView!
   @IBOutlet weak var collectionFlowLayout: UICollectionViewFlowLayout!
	@IBOutlet weak var buttonsView: UIView!
	
   let cellSpacing = 12 * WidthRatio
   
   var products : [SKProduct] = []
   var productIdentifiers = Set<String> ()
   var productsRequest : SKProductsRequest?
   
   override func viewDidLoad()
   {
      super.viewDidLoad()
      
      collectionFlowLayout.minimumLineSpacing = cellSpacing
      collectionFlowLayout.minimumInteritemSpacing = cellSpacing
      
      setupUserProObserver()
      updateProLabel()
      loadProducts()		
   }
   
	override func viewWillAppear(_ animated: Bool)
   {
		super.viewWillAppear(animated)
      SKPaymentQueue.default().add(self)
      
		navigationController?.setNavigationBarHidden(false, animated: true)
		let navigationBar = navigationController?.navigationBar
		navigationBar?.isTranslucent = true
		navigationBar?.shadowImage = UIImage()
		navigationBar?.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
		navigationBar?.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.white,
		    NSFontAttributeName : UIFont.systemFont(ofSize: 12, weight: UIFontWeightMedium)]
	}
   
	override func viewWillDisappear(_ animated: Bool)
   {
		super.viewWillDisappear(animated)
		
      if let request = productsRequest {
         request.cancel()
         dlog("Products Request cancel")
      }
      
      SKPaymentQueue.default().remove(self)
	}

	 // MARK: - CollectionViewDelegate
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return products.count
	}

	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
   {
      let identifier = "PurchasesCell"
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath) as! PurchasesCell
      cell.product = products[indexPath.row]
		return cell
	}
   
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
	{
      showAppSpinner()
		buyProduct(products[indexPath.row])
	}
	
	
	func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
		let cell = collectionView.cellForItem(at: indexPath) as! PurchasesCell
		cell.highlightedView.isHidden	= false
		cell.normalView.isHidden = true
	}
	
	func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
		let cell = collectionView.cellForItem(at: indexPath) as! PurchasesCell
		cell.highlightedView.isHidden	= true
		cell.normalView.isHidden = false
		
	}
	 // MARK: - SKProducts Delegate
	
	func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse)
   {
      performOnMainThread
      {
         for product in response.products {
            print(product.productIdentifier)
            self.products.append(product)
         }
         
         hideAppSpinner(for: self.buttonsView, animated: true)
         
         if self.products.isEmpty
         {
            self.failedRequestLabel.isHidden = false
            self.retryRequestButton.isHidden = false
            self.failedRequestLabel.text = loc("No purchases available")
         }
         else
         {
            self.products.sort(by: { $0.price.intValue < $1.price.intValue})
            self.calculateCollectionItemSize()
            self.collectionView.reloadData()
         }
         
         if request == self.productsRequest { self.productsRequest = nil }
      }
	}
   
   public func request(_ request: SKRequest, didFailWithError error: Error)
   {
      performOnMainThread
      {
         if request is SKProductsRequest
         {
            dlog(error.localizedDescription)
            hideAppSpinner(for: self.buttonsView, animated: true)
            self.failedRequestLabel.isHidden = false
            self.retryRequestButton.isHidden = false
            self.failedRequestLabel.text = loc("Failed to get purchase list")
            
            if request == self.productsRequest { self.productsRequest = nil }
         }
      }
   }
   
	func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction])
   {
      performOnMainThread
      {
         for transaction in transactions
         {
            switch transaction.transactionState
            {
            case .purchasing:
               showAppSpinner()
               
            case .purchased:
               
               guard let user = User.current else {
                  queue.finishTransaction(transaction)
                  return
               }
               
               let purchaseDate = Date()
               
               guard let purchase = Purchase.purchase(timestamp: purchaseDate.timeIntervalSince1970,
                                                      transactionId: transaction.transactionIdentifier!,
                                                      productId: transaction.payment.productIdentifier)
               else {
                  AlertManager.showAlert("Wrong purchase format")
                  hideAppSpinner()
                  queue.finishTransaction(transaction)
                  return
               }
               
               let dateComponents = DateComponents(calendar: calendar, timeZone: calendar.timeZone, day: purchase.days + purchase.months * 30 + purchase.years * 365)
               let date = user.isPro ? user.proExpirationTime! : purchaseDate
               
               if let newExpirationDate = calendar.date(byAdding: dateComponents, to: date)
               {
                  //let str = String(format: loc("You got pro account till %@"), proDateFormatter.string(from: newExpirationDate))
                  //AlertManager.showAlert(str)
                  
                  user.modifyWithTransactionIfNeeded {
                     user.setPro(newExpirationDate)
                     user.purchasesQueue.append(purchase)
                  }
               }
               else
               {
                  user.modifyWithTransactionIfNeeded {
                     user.purchasesQueue.append(purchase)
                  }
               }
               
               AppDelegate.sendPendingPurchases()
               
               hideAppSpinner()
               queue.finishTransaction(transaction)
               
            case .failed:
               dlog(transaction.error?.localizedDescription ?? "buy error")
               hideAppSpinner()
               queue.finishTransaction(transaction)
               
            default: break
            }
         }
      }
	}
	
	// MARK: - Methods
	
   func calculateCollectionItemSize()
   {
      var width = collectionView.width
      var height = collectionView.height
      
      if products.count == 2 {
         width = (width - cellSpacing) / 2
      }
      else if products.count >= 3 {
         width = (width - 2 * cellSpacing) / 3
      }
      
      width = floor(width)
      height = floor(height)
      
      collectionFlowLayout.itemSize = CGSize(width: width, height: height)
   }
   
   func loadProducts()
   {
      if productIdentifiers.isEmpty
      {
         showAppSpinner(addedTo: buttonsView, animated: true, dimBackground: false)
         RequestManager.getProStatusPurchases(
         success:
         {
            [weak self]
            set in
            self?.productIdentifiers = set
            self?.sendRequestForProducts()
         },
         failure:
         {
            [weak self]
            errorDecription in
            dlog(errorDecription)
            if let strongSelf = self
            {
               hideAppSpinner(for: strongSelf.buttonsView, animated: true)
               strongSelf.failedRequestLabel.isHidden = false
               strongSelf.retryRequestButton.isHidden = false
               strongSelf.failedRequestLabel.text = loc("Failed to get purchase list")
            }
         })
      }
      else {
         self.sendRequestForProducts()
      }
   }
   
	func sendRequestForProducts()
   {
		if (SKPaymentQueue.canMakePayments())
      {
         showAppSpinner(addedTo: buttonsView, animated: true, dimBackground: false)
         failedRequestLabel.isHidden = true
         retryRequestButton.isHidden = true
         
			productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers )
			productsRequest?.delegate = self
			productsRequest?.start()
		}
		else
      {
			hideAppSpinner(for: buttonsView, animated: true)
			failedRequestLabel.isHidden = false
			retryRequestButton.isHidden = false
			failedRequestLabel.text = loc("Payments forbidden")
		}
	}
	
   func buyProduct(_ product : SKProduct)
   {
      let payment = SKPayment(product: product)
      SKPaymentQueue.default().add(payment)
	}
   
   func updateProLabel()
   {
      if let user = User.current, user.isPro, let proDate = user.proExpirationTime {
         proDateLabel.text = String(format: loc("Valid until %@"), proDateFormatter.string(from: proDate))
      }
      else {
         proDateLabel.text = nil
      }
   }
   
   //MARK: - Pro Observer
   
   private var userProObserver : NSObjectProtocol?
   
   private func setupUserProObserver()
   {
      userProObserver = NotificationCenter.default.addObserver(forName: .MBUserProChanged, object: nil, queue: OperationQueue.main)
      {
         [unowned self]
         notification in
         if let currentUser = User.current, let user = notification.object as? User, user.id == currentUser.id {
            self.updateProLabel()
         }
      }
   }
   
   deinit
   {
      if userProObserver != nil {
         NotificationCenter.default.removeObserver(userProObserver!)
      }
   }
   
   // MARK: - Actions
	
   @IBAction func backTapped(_ sender: Any)
   {
      if let navController = navigationController
      {
         if navController.viewControllers.count == 1 {
            navController.presentingViewController?.dismiss(animated: true, completion: nil)
         }
         else {
            _ = navigationController?.popViewController(animated: true)
         }
      }
   }
   
	@IBAction func retryRequest(_ sender: UIButton)
   {
      loadProducts()
	}
}



class PurchasesCell: UICollectionViewCell
{
	@IBOutlet weak var normalView: UIView!
	@IBOutlet weak var highlightedView: UIView!
   @IBOutlet weak var termLabel: UILabel!
   @IBOutlet weak var costLabel: UILabel!
	@IBOutlet weak var highlightedCostLabel: UILabel!
	@IBOutlet weak var highlightedTermLabel: UILabel!
   
   var product : SKProduct!
   {
      didSet {
         termLabel.text = product.localizedTitle
			highlightedTermLabel.text = product.localizedTitle
         
         let priceFormatter = NumberFormatter()
         priceFormatter.locale = product.priceLocale
         priceFormatter.numberStyle = .currency
         
         costLabel.text = priceFormatter.string(from: product.price)
         highlightedCostLabel.text = costLabel.text
         
//         let symbol = product.priceLocale.currencySymbol!
//         costLabel.text = "\(product.price.decimalValue)\(symbol)"
//			  highlightedCostLabel.text = costLabel.text
      }
   }
}

