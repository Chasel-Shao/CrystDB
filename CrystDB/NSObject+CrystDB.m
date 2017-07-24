//
// NSObject+CrystDB.m
// Copyright (c) 2017年 Chasel. All rights reserved.
// https://github.com/Chasel-Shao/CrystDB.git
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "NSObject+CrystDB.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <CommonCrypto/CommonDigest.h>

@implementation NSObject (Cryst)

-(BOOL)cs_addOrUpdateToDB{
    CrystManager *cache = [[CrystManager alloc] initWithObject:self];
    return [cache addOrUpdateObject:self];
}

-(BOOL)cs_addOrIgnoreToDB{
    CrystManager *cache = [[CrystManager alloc] initWithObject:self];
    return [cache addOrIgnoreObject:self];
}

+(BOOL)cs_addOrUpdateToDBWithDict:(NSDictionary *)dict{
    CrystManager *cache = [[CrystManager alloc] initWithObject:[[[self class] alloc] init]];
    return [cache addOrUpdateWithClass:self withDict:dict];
}

-(BOOL)cs_deleteFromDB{
    CrystManager *cache = [[CrystManager alloc] initWithObject:self];
    BOOL result = [cache deleteObject:self];
    return result;
}
+(BOOL)cs_deleteFromDBWithCondition:(NSString *)condition{
    CrystManager *cache = [[CrystManager alloc] initWithObject:[[[self class] alloc] init]];
    BOOL result = [cache deleteClass:[self class] where:condition];
    return result;
}

+(void)cs_inTransaction:(void (^)(CrystManager *, BOOL *))block{
    CrystManager *cache = [[CrystManager alloc] initWithObject:[[[self class] alloc] init]];
    [cache inTransaction:^(BOOL *rollback) {
        block(cache,rollback);
    }];
}

+(id)cs_queryObjectOnPrimary:(id)primaryValue{
    CrystManager *cache = [[CrystManager alloc] initWithObject:[[[self class] alloc] init]];
    return [cache queryWithClass:[self class] onPrimary:primaryValue];
}

+(NSArray*)cs_queryObjectsWithCondition:(NSString *)condition{
    CrystManager *cache = [[CrystManager alloc] initWithObject:[[[self class] alloc] init]];
    return [cache queryWithClass:[self class] condition:condition];
}

+(NSArray*)cs_queryObjectsWithConditions:(NSString *)conditionFromat,...{
    CrystManager *cache = [[CrystManager alloc] initWithObject:[[[self class] alloc] init]];
    if(conditionFromat != nil){
        va_list ap;
        va_start(ap, conditionFromat);
        NSString *predicateSql = [[NSString alloc] initWithFormat:conditionFromat arguments:ap];
        va_end(ap);
        return  [cache queryWithClass:[self class] conditions:predicateSql];
    }else{
        return  [cache queryWithClass:[self class] conditions:nil];
    }
}

+(NSInteger)cs_queryObjectCount{
    CrystManager *cache = [[CrystManager alloc] initWithObject:[[[self class] alloc] init]];
    return [cache queryCount:[self class]];
}
-(NSInteger)cs_queryObjectUpdateTime{
    CrystManager *cache = [[CrystManager alloc] initWithObject:self];
    return [cache queryUpdateTime:self];
}

-(NSInteger)cs_queryObjectCreateTime{
    CrystManager *cache = [[CrystManager alloc] initWithObject:self];
    return [cache queryCreateTime:self];
}

@end
