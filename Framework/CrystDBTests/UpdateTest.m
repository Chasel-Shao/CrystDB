//
//  AddOrUpdateTest.m
//  CrystDB
//
//  Created by sweet on 2017/7/4.
//  Copyright © 2017年 chasel. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "CrystDB.h"
#import "GithubUser.h"

@interface AddOrUpdateTest : XCTestCase
@end

@implementation AddOrUpdateTest

- (void)setUp {
    [super setUp];
    
    // Prepare
    CrystManager *mananger = [CrystManager defaultCrystDB];
    mananger.isDebug = YES;
    [mananger dropAll];
    int count = [mananger queryCount:[GithubUser class]];
    XCTAssert(count == 0);
}

- (void)tearDown {
    
    // clear up
    CrystManager *mananger = [CrystManager defaultCrystDB];
    mananger.isDebug = YES;
    [mananger dropAll];
    int count = [mananger queryCount:[GithubUser class]];
    XCTAssert(count == 0);
    
    [super tearDown];
}

- (void)testExample {
    
    // Generate model
    CrystManager *mananger = [CrystManager defaultCrystDB];
    mananger.isDebug = YES;
    GithubUser *user = [[GithubUser alloc] init];
    user.userID = 123;
    user.avatarURL = @"http://img3.3lian.com/2014/f1/4/d/38.jpg";
    user.name = @"Ares";
    user.followers = 211;
    user.following = 110;
    user.createdAt = [NSDate date];
    user.test = [NSValue valueWithCGSize:CGSizeMake(199, 299)];
    
    // 1. AddOrUpdateObject
    BOOL result = [mananger addOrUpdateObject:user];
    XCTAssert(result);
    NSArray *array = [mananger queryWithClass:[GithubUser class] condition:nil];
    XCTAssert(array.count > 0);
    
    // 2. AddOrIgnoreObject
    BOOL result2 = [mananger addOrIgnoreObject:user];
    XCTAssert(result2);
    NSArray *array2 = [mananger queryWithClass:[GithubUser class] condition:nil];
    XCTAssert(array2.count ==  1);
    
    
    // 3. AddOrUpdateObject:withDict:
    NSDictionary *userDict = @{
                               @"userID":@123,
                               @"name":@"Eric",
                               @"followers":@99,
                               @"following":@100
                               };
    BOOL result3 =  [mananger addOrUpdateWithClass:[GithubUser class] withDict:userDict];
    XCTAssert(result3);
    NSArray *array3 = [mananger queryWithClass:[GithubUser class] condition:nil];
    XCTAssert(array3.count == 1);
    GithubUser *newUser = [array3 firstObject];
    XCTAssert([newUser.name isEqualToString:@"Eric"]);
    XCTAssert([newUser.name isEqualToString:@"Eric"]);
    XCTAssert(newUser.followers == 99);
    XCTAssert(newUser.following == 100);
    
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}


@end
