//
//  ETA_SessionTests.m
//  ETA-SDKTests
//
//  Created by Laurie Hufford on 7/10/13.
//
//

#import "ETA_SessionTests.h"

#import "ETA_Session.h"

@implementation ETA_SessionTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void) testSessionToJSON
{
    ETA_Session* session = [[ETA_Session alloc] init];
    
    NSDateFormatter* df = [[NSDateFormatter alloc] init];
    df.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    df.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZ";
    
    NSDate* expires = [NSDate date];
    
    session.token = @"12345";
    session.expires = expires;
    
    NSDictionary* jsonDict = session.JSONDictionary;
    
    STAssertEqualObjects(jsonDict[@"token"], session.token, @"Token in JSON dictionary from a Session must be same");
    STAssertEqualObjects(jsonDict[@"expires"], [df stringFromDate: session.expires], @"Expires in JSON dictionary from a Session must be converted correctly");
}

- (void) testJSONToSession
{
    NSDateFormatter* df = [[NSDateFormatter alloc] init];
    df.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    df.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZ";
    
    ETA_Session* session;
    NSDictionary* jsonDict;
    
    // invalid jsonDict
    jsonDict = nil;
    session = [ETA_Session objectFromJSONDictionary:jsonDict];
    STAssertNil(session, @"Creating a session with a nil json dictionary must return nil");
    
    
    jsonDict = @{
                 @"token":@"12345",
                 @"expires": @"2012-04-16T22:00:00+0000",
                 };
    session = [ETA_Session objectFromJSONDictionary:jsonDict];
    STAssertEqualObjects(session.token, jsonDict[@"token"], @"A session's token must be the same as the json token");
    STAssertEqualObjects(session.expires, [df dateFromString:jsonDict[@"expires"]], @"A session's expires date must be converted correctly from the json string");
    
}

- (void)testSessionWillExpireSoon
{
    ETA_Session* session = [[ETA_Session alloc] init];
    
    // unset expiry
    STAssertTrue([session willExpireSoon], @"A session without an expiry must say that it expires soon");
    
    // distant future expiry
    session.expires = [NSDate distantFuture];
    STAssertFalse([session willExpireSoon], @"A session that will expire long in the future must not say that it expires soon");
    
    // distant past expiry
    session.expires = [NSDate distantPast];
    STAssertTrue([session willExpireSoon], @"A session that expired long ago must say that it expires soon");
    
    // now expiry
    session.expires = [NSDate date];
    STAssertTrue([session willExpireSoon], @"A session that expires right now must say that it expires soon");

    // 1 day offset expiry
    session.expires = [NSDate dateWithTimeIntervalSinceNow:60*60*24];
    STAssertTrue([session willExpireSoon], @"A session that expires in exactly 1 day must say that it expires soon");

    // slightly less than 1 day offset expiry
    session.expires = [NSDate dateWithTimeIntervalSinceNow:60*60*24-1];
    STAssertTrue([session willExpireSoon], @"A session that expires in a little less than 1 day must say that it expires soon");
    
    // slightly more than 1 day offset expiry
    session.expires = [NSDate dateWithTimeIntervalSinceNow:60*60*24+1];
    STAssertFalse([session willExpireSoon], @"A session that expires in a little more than 1 day must not say that it expires soon");
}


@end
