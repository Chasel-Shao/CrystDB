//
//  QueryTest.m
//  CrystDB
//
//  Created by sweet on 2017/7/24.
//  Copyright © 2017年 chasel. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "Person.h"

@interface QueryTest : XCTestCase

@end

@implementation QueryTest

- (void)setUp {
    [super setUp];
    
    // Prepare
    CrystManager *mananger = [CrystManager defaultCrystDB];
    mananger.isDebug = YES;
    [mananger dropAll];
    int count = [mananger queryCount:[Person class]];
    XCTAssert(count == 0);
    
}

- (void)tearDown {
    
    // Prepare
    CrystManager *mananger = [CrystManager defaultCrystDB];
    mananger.isDebug = YES;
    [mananger dropAll];
    int count = [mananger queryCount:[Person class]];
    XCTAssert(count == 0);
    
    [super tearDown];
}

- (void)testExample {
    CrystManager *mananger = [CrystManager defaultCrystDB];
    mananger.isDebug = YES;
    Person *p = [[Person alloc] init];
    p.uid = 201;
    p.name = @"Zeus";
    p.age = 123;
    p.isRead = YES;
    p.gender = 1;
    p.books = @[@"book1",@"book2"];
    p.dict = @{@"isbn":@123456789,
               @"info":@"Zeus is the sky and thunder god in ancient Greek religion, who ruled as king of the gods of Mount Olympus. His name is cognate with the first element of his Roman equivalent Jupiter. His mythologies and powers are similar, though not identical, to those of Indo-European deities such as Indra, Jupiter, Perun, Thor, and Odin."};
    p.size = CGSizeMake(199, 299);
    p.number = @(211);
    p.data = [@"hello world!" dataUsingEncoding:NSUTF8StringEncoding];
    NSDate *birthday = [NSDate date];
    p.birthday = birthday;
    
    Person *child = [[Person alloc] init];
    child.uid = 101;
    child.name = @"Ares";
    child.age = 102;
    child.isRead = NO;
    child.gender = 1;
    child.books = @[@"book3",@"book4",@"book5"];
    child.dict = @{@"isbn":@987654321,
                   @"info":@"Ares is the Greek god of war. He is one of the Twelve Olympians, and the son of Zeus and Hera.[1] In Greek literature, he often represents the physical or violent and untamed aspect of war, in contrast to his sister the armored Athena, whose functions as a goddess of intelligence include military strategy and generalship."};
    child.data = [@"Expecto Patronum" dataUsingEncoding:NSUTF8StringEncoding];
    NSDate *birthday2 = [NSDate dateWithTimeIntervalSinceNow:-10000];
    child.birthday   = birthday2;
    p.child = child;

    BOOL result = [mananger addOrUpdateObject:p];
    XCTAssert(result);
    
    NSArray *persons = [mananger queryWithClass:[Person class] condition:nil];
    XCTAssert(persons.count == 1);
    
    Person *newp =[persons firstObject];
    XCTAssert(newp.uid == 201);
    XCTAssert([newp.name isEqualToString:@"Zeus"]);
    XCTAssert(newp.age == 123);
    XCTAssert(newp.isRead);
    XCTAssert(newp.gender == 1);
    XCTAssert(newp.books.count == 2);
    XCTAssert([newp.dict[@"isbn"] isEqualToNumber:@(123456789)]);
    
    XCTAssert([newp.data isEqualToData:[@"hello world!" dataUsingEncoding:NSUTF8StringEncoding]]);
    XCTAssert([newp.birthday isEqualToDate:birthday]);
    
    XCTAssert([newp.child.name isEqualToString:@"Ares"]);
    XCTAssert(newp.child.uid == 101);
    XCTAssert(newp.child.age == 102);
    XCTAssert(!newp.child.isRead);
    XCTAssert(newp.child.gender == 1);
    XCTAssert(newp.child.books.count == 3);
    XCTAssert([newp.child.dict[@"info"] isEqualToString:@"Ares is the Greek god of war. He is one of the Twelve Olympians, and the son of Zeus and Hera.[1] In Greek literature, he often represents the physical or violent and untamed aspect of war, in contrast to his sister the armored Athena, whose functions as a goddess of intelligence include military strategy and generalship."]);
    XCTAssert([newp.child.data isEqualToData:[@"Expecto Patronum" dataUsingEncoding:NSUTF8StringEncoding]]);
    XCTAssert([newp.child.birthday isEqualToDate:birthday2]);
    
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
