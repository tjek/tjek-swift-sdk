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
}
- (void) testJSONToSession
{
    
}

- (void)testSessionExpiryQueries
{
    
    
//    NSString* validDateString = @"2013-03-03T13:37:00+0000";
//    NSString* invalidDateString = @"xxx";
//    
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

- (void)testSessionTokenSetting
{
    
}

@end
