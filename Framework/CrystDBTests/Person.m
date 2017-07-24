

//
//  Person.m
//  CrystDB
//
//  Created by sweet on 2017/7/24.
//  Copyright © 2017年 chasel. All rights reserved.
//

#import "Person.h"

@implementation Person

+(NSString *)CrystDBPrimaryKey{
    return @"uid";
}

-(instancetype)initWithCoder:(NSCoder *)aDecoder
{
    
    if (self = [super init]) {
        
        self.uid = [aDecoder decodeInt64ForKey:@"uid"];
        self.name = [aDecoder decodeObjectForKey:@"name"];
        self.age = [aDecoder decodeIntegerForKey:@"age"];
        self.isRead = [aDecoder decodeBoolForKey:@"isRead"];
        self.gender = [aDecoder decodeIntegerForKey:@"gender"];
        self.books = [aDecoder decodeObjectForKey:@"books"];
        self.dict = [aDecoder decodeObjectForKey:@"dict"];
        self.size = [aDecoder decodeCGSizeForKey:@"size"];
        self.number = [aDecoder decodeObjectForKey:@"number"];
        self.data = [aDecoder decodeObjectForKey:@"data"];
        self.birthday = [aDecoder decodeObjectForKey:@"birthday"];
        self.child = [aDecoder decodeObjectForKey:@"child"];
        
    }
    return self;
}


-(void)encodeWithCoder:(NSCoder *)aCoder{
    [aCoder encodeInt64:self.uid forKey:@"uid"];
    [aCoder encodeObject:self.name forKey:@"name"];
    [aCoder encodeInt:self.age forKey:@"age"];
    [aCoder encodeBool:self.isRead forKey:@"isRead"];
    [aCoder encodeInt:self.gender forKey:@"gender"];
    [aCoder encodeObject:self.books forKey:@"books"];
    [aCoder encodeObject:self.dict forKey:@"dict"];
    [aCoder encodeCGSize:self.size forKey:@"size"];
    [aCoder encodeObject:self.number forKey:@"number"];
    [aCoder encodeObject:self.data forKey:@"data"];
    [aCoder encodeObject:self.birthday forKey:@"birthday"];
    [aCoder encodeObject:self.child forKey:@"child"];
}
@end
