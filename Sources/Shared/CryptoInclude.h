//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

#import <Foundation/Foundation.h>

/**
 This is an annoying workaround to allow the Swift code to access the ObjC CommonCrypto lib.
 */
@interface CryptoInclude: NSObject

/**
 Creates a MD5 hash of the provided NSData object.
 */
+ (nonnull NSData*) md5:(nonnull NSData*)data;

/**
 Creates a SHA256 hash of the provided string as hex NSString representation.
 */
+ (nonnull NSString*) sha256:(nonnull NSString*) string;

@end
