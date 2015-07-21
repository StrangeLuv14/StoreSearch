//
//  DimmingPresentationController.swift
//  StoreSearch
//
//  Created by 赵雨 on 7/21/15.
//  Copyright (c) 2015 Hippocn. All rights reserved.
//

import UIKit

class DimmingPresentationController: UIPresentationController {
    override func shouldRemovePresentersView() -> Bool {
        return false
    }
}
