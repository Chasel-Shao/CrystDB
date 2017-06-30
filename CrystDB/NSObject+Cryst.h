//
// NSObject+Cryst.h
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

#import <Foundation/Foundation.h>
#import "CrystLite.h"

@class CrystLite;
@interface NSObject (Cryst) <CrystLite>

///----------------------------------
/// @name Insert and Update Operation
///----------------------------------

/**
 Add the current object to database. if the object has been alreadly in
 the database, then update the former one.

 @return Whether operate success
 */
- (BOOL)cs_addOrUpdateToDB;

/**
 Add the current object to database. if the object has been alreadly in
 the database, then ignore this operation, and return `YES`.

 @return Whether adoperated success
 */
- (BOOL)cs_addOrIgnoreToDB;

/**
 Uses an dictioanry to add an object to the  database, the dictioanry must
 contain the primary key, otherwise it will fail. if the object has been in 
 the database, then update the former one.

 @param dictioanry The dictioanry to be add or update
 @return Whether operate success
 */
+ (BOOL)cs_addOrUpdateToDBWithDict:(NSDictionary *)dictioanry;

///----------------------
/// @name query Operation
///----------------------

/**
 Querys the object associated with the primary value.

 @param primaryValue The value of the primary key
 @return An object
 */
+ (id)cs_queryObjectOnPrimary:(id)primaryValue;

/**
 Querys all the objects with the conditions.

 @param condition The restricted condition
 @return An array of this kind of object
 */
+ (NSArray*)cs_queryObjectsWithCondition:(NSString *)condition;

/**
 Querys all the objects with the format conditions, this method is 
 not supported in Swift.
 
 @param conditionFromat The restricted condition
 @return An array of this kind of object
 */
+ (NSArray*)cs_queryObjectsWithConditions:(NSString *)conditionFromat,...;

/**
 Querys the number of objects of this kind of object.

 @return An integer
 */
+ (NSInteger)cs_queryObjectCount;

/**
 Querys the update time of this object.

 @return An integer timestamp
 */
- (NSInteger)cs_queryObjectUpdateTime;

/**
  Querys the create time of this object.

 @return An integer timestamp
 */
- (NSInteger)cs_queryObjectCreateTime;

///-----------------------
/// @name delete Operation
///-----------------------

/**
 Deletes the object from database according to the primary key.

 @return Whether delete success
 */
- (BOOL)cs_deleteFromDB;

/**
 Deletes all objects of this kind object with a given condition.

 @param condition restricted condition
 @return Whether delete success
 */
+ (BOOL)cs_deleteFromDBWithCondition:(NSString *)condition;

///----------------------------
/// @name transaction Operation
///----------------------------

/**
 Operates the transaction in a block, and commit after the block is finished.
 If the value of `rollback` is set to `YES`, then rollback the transaction.

 @param block The operations are operated in the block
 */
+ (void)cs_inTransaction:(void (^)(CrystLite *db, BOOL *rollback))block;


@end




