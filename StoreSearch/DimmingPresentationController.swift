//
//  DimmingPresentationController.swift
//  StoreSearch
//
//  Created by 赵雨 on 7/21/15.
//  Copyright (c) 2015 Hippocn. All rights reserved.
//

import UIKit

class DimmingPresentationController: UIPresentationController {
    
    lazy var dimmingView = GradientView(frame: CGRect.zeroRect)
    
    override func shouldRemovePresentersView() -> Bool {
        return false
    }
    
    override func presentationTransitionWillBegin() {
        dimmingView.frame = containerView.bounds
        containerView.insertSubview(dimmingView, atIndex: 0)
        
        dimmingView.alpha = 0
        
        if let transitionCoordinator = presentedViewController.transitionCoordinator() {
            transitionCoordinator.animateAlongsideTransition({
                _ in
                    self.dimmingView.alpha = 1
            }, completion: nil)
        }
    }
    
    override func dismissalTransitionWillBegin() {
        if let transitionCoordinator = presentedViewController.transitionCoordinator() {
            transitionCoordinator.animateAlongsideTransition({
                _ in
                    self.dimmingView.alpha = 0
            }, completion: nil)
        }
    }
}
