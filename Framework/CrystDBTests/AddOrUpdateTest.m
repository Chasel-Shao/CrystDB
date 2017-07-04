//
//  AddOrUpdateTest.m
//  CrystDB
//
//  Created by sweet on 2017/7/4.
//  Copyright © 2017年 chasel. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "CrystDB.h"

@interface Person : NSObject
@property (nonatomic,assign) NSInteger uid;
@property (nonatomic,copy) NSString *name;
@end
@implementation Person
@end

@interface AddOrUpdateTest : XCTestCase
@end

@implementation AddOrUpdateTest

-(void)test{
    Person *p = [[Person alloc] init];
    p.uid = 123;
    p.name = @"Ares";
    
    BOOL result = [p cs_addOrUpdateToDB];
    XCTAssert(result);
    
    NSArray *array = [Person cs_queryObjectsWithCondition:nil];
    NSLog(@"%@",array);
    
}


@end
