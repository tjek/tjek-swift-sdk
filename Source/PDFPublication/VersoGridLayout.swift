//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import UIKit


class VersoGridLayout : UICollectionViewFlowLayout {
    override init() {
        super.init()
        
        itemSize = CGSizeMake(150, 200)
        sectionInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}