//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonHMAC.h>

NS_ASSUME_NONNULL_BEGIN

/**
 This class exists as a rather annoying work around for the fact that ObjC Bridging Headers arent allowed in Frameworks.
 So this is here simply to include the CommonCrypto libs.
 */
@interface CryptoInclude : NSObject

@end

NS_ASSUME_NONNULL_END
