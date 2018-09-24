//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

#import "CryptoInclude.h"
#import <CommonCrypto/CommonDigest.h>

@implementation CryptoInclude

+ (nonnull NSData*) md5:(nonnull NSData*) data {
    unsigned int outputLength = CC_MD5_DIGEST_LENGTH;
    unsigned char output[outputLength];
    
    CC_MD5(data.bytes, (unsigned int) data.length, output);
    return [NSData dataWithBytes:output length:outputLength];
}

+ (nonnull NSString*) sha256:(nonnull NSString*) string {
    unsigned int outputLength = CC_SHA256_DIGEST_LENGTH;
    unsigned char output[outputLength];
    
    unsigned int utf8Len = (unsigned int) [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    
    CC_SHA256(string.UTF8String, utf8Len, output);
    
    NSMutableString* hash = [NSMutableString stringWithCapacity:outputLength * 2];
    for (unsigned int i = 0; i < outputLength; i++) {
        [hash appendFormat:@"%02x", output[i]];
        output[i] = 0;
    }
    return [hash copy];
}

@end
