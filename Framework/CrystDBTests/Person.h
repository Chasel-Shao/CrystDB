//
//  Person.h
//  CrystDB
//
//  Created by sweet on 2017/7/24.
//  Copyright © 2017年 chasel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CrystDB.h"

@interface Person : NSObject <CrystDB,NSCoding>
@property (nonatomic,assign) uint64_t uid;
@property (nonatomic,copy) NSString *name;
@property (nonatomic,assign) int age;
@property (nonatomic,assign) BOOL isRead;
@property (nonatomic,assign) char gender;
@property (nonatomic,strong) NSArray *books;
@property (nonatomic,strong) NSDictionary *dict;
@property (nonatomic,assign) CGSize size;
@property (nonatomic,strong) NSNumber *number;
@property (nonatomic,strong) NSData *data;
@property (nonatomic,strong) NSDate *birthday;
@property (nonatomic,strong) Person *child;
//@property (nonatomic,strong) UIImage *image;
@end
