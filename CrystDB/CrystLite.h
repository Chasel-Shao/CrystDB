//
// CrystLite.h
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

#import <UIKit/UIKit.h>

/**
 CrystLite is a thread-safe Object Relational Mapping database that stores object based on SQLite.
 
 CrystLite has these features:
  * It can automatically transform the property type of an object to storage sqlite type  for each object 
 to get better performance.
  * Uses the class to sort object and is not affected by modifying the class structure.
  * Supports filtering by conditions.
 
 */
@protocol CrystLite;
NS_ASSUME_NONNULL_BEGIN
@interface CrystLite : NSObject
/**
 The current database name and is read only.
 */
@property (readonly,nonatomic,copy) NSString *dbName;

/**
 Prints the debug info if the value is `YES`,
 the default value is `NO`.
 */
@property (nonatomic,assign) BOOL isDebug;

/**
 If the object is updated, the database will send notification if the value is `YES`, 
 the  defalut value is `NO`. This property will be discarded later.
 */
@property (nonatomic,assign) BOOL isBindToObject;

///---------------------
/// @name Initialization
///---------------------

/**
 Creates and returns a `CrystLite` instance which have a default database name.
 */
+ (nonnull instancetype)defaultCrystLite;

/**
 Initializes a `CrystLite` instance with the specified database name.

 @param dbName The database name for the instance
 @return The newly-initiailized `CrystLite` instance
 */
- (nonnull instancetype)initWithName:(nullable NSString *)dbName __attribute__((nonnull));

/**
  Initializes a `CrystLite` instance with the same database with a existed object which has confirmed the
 'CrystLiteName' method, if the object does not confirmed the `CrystLiteName` method, it returns a default database.

 @param object The object has confirmed 'CrystLiteName' method
 @return The newly-initiailized `CrystLite` instance
 */
- (nonnull instancetype)initWithObject:(nullable id)object __attribute__((nonnull));

///-----------------------
/// @name Insert Operation
///-----------------------

/**
 Inserts an object in database, the object shoud confirm the `CrystLite` protocol,
 it is better to implement the `CrystLitePrimaryKey` to assign a property as a primary key.
 
 The table where the object be stored is according to the object of the class.If the table
 does not have the object, the object will be inserted to the table, whereas, if the table
 does have the object, the current object will update the former object anyway.
 
 @param object It is better for the `objet` to confirm the `CrystLite` protocol
 @return Whether insert or update success
 */
- (BOOL)addOrUpdateObject:(nonnull id<CrystLite>)object;

/**
 Inserts an object in database,it looks like the `addOrUpdateObject:` method, but if the 
 object has already in the table of this object class, the current object will not update the
 former object in this table.

 @param object It is better for the `objet` to confirm the `CrystLite` protocol
 @return Whether insert or update success
 */
- (BOOL)addOrIgnoreObject:(nonnull id<CrystLite>)object;

/**
 Inserts an object by the dictioanry, which have the keys corresponding to the properties 
 of object. If the talbe of this object class alreadly has had this object, the former object will
 be updated.

 @param objectClass The object class corresponding to the unique table
 @param dictionary The key-values that desired to be inserted or updated in the table.
 @return Whether insert or update success
 */
- (BOOL)addOrUpdateObject:(nonnull Class)objectClass withDict:(nonnull NSDictionary *)dictionary;

///----------------------
/// @name Query Operation
///----------------------

/**
 Returns an object associated with a given value of primary key.
 This method may blocks the calling thread until file read finished.

 @param objectClass This class only corresponding to the unique table
 @param primaryValue The value of its primary key
 @return An object with pecified primary value
 */
- (nullable id)queryWithClass:(nonnull Class)objectClass onPrimary:(nonnull id)primaryValue;

/**
 Querys the objects in the database with given object class and specific condition.
 The object class is used for `table` name, and the condition is used as `where` sentence.

 @param objectClass This class only corresponding to the unique table
 @param condition The restricted condition in the table
 @return An array of objects
 */
- (nonnull NSArray *)queryWithClass:(nonnull Class)objectClass condition:(nullable NSString *)condition;

/**
 Querys the objects in the database with given object class and specific condition.
 The object class is used for `table` name, and the condition is used as `where` sentence.
 In this method, multiple arguments can be passed by the `conditions`. but it is not supported 
 in Swift.

 @param objectClass This class only corresponding to the unique table
 @param conditionFormat The restricted conditions can be multiple arguments
 @return An array of objects
 */
- (nonnull NSArray *)queryWithClass:(nonnull Class)objectClass conditions:(nullable NSString *)conditionFormat,...;

/**
 Querys the objects in the databse with sql syntax.

 @param objectClass This class only corresponding to the unique table
 @param where The `where` sentence in sql syntax
 @param orderBy The `order by` sentence in sql syntax
 @param limit The `limit` sentence in sql syntax
 @return An array of objects
 */
- (nonnull NSArray *)queryWithClass:(nonnull Class)objectClass where:(nullable NSString *)where orderBy:(nullable NSString *)orderBy limit:(nullable NSString *)limit;

/**
 Querys the number of objects in the table of the objectClass.

 @param objectClass This class correspondint the unique table
 @return An Interger
 */
- (NSInteger)queryCount:(nonnull Class)objectClass;

/**
 Querys the update time of an object.

 @param object The object
 @return The timestamp of the object's update time
 */
- (NSInteger)queryUpdateTime:(nonnull id)object;

/**
 Querys the create time of an object.

 @param object The object
 @return The timestamp of the object's create time
 */
- (NSInteger)queryCreateTime:(nonnull id)object;


///-----------------------
/// @name Update Operation
///-----------------------

/**
 Deletes an object from table, the object should imaplement the method of `CrystLitePrimaryKey` 
 and have the primary value to appoint the specific object in the table of this object, 
 whereas the object can not be deleted from the table.

 @param object The object with the primary value.
 @return Whether delete success
 */
- (BOOL)deleteObject:(nonnull id)object;

/**
 Deletes the objects from table of object class with specific `where` sentence of sql syntax.

 @param objectClass The name of the class used to refer to objects of this type
 @param where The restricted condition
 @return Whether delete success
 */
- (BOOL)deleteClass:(nonnull Class)objectClass where:(nullable NSString *)where;

/**
 Updates the former object, if the object is not in the database, it will occur error.

 @param object The object to update the former one
 @return Whether update success
 */
- (BOOL)updateObject:(nonnull id)object;

///----------------------
/// @name Table Operation
///----------------------

/**
 Removes all the objects in the database.

 @return Whether delete success
 */
- (BOOL)dropAll;

/**
 Removes the objects refer to a given class.

 @param objectClass The object of the class to be deleted
 @return Whether drop success
 */
- (BOOL)dropClass:(nonnull Class)objectClass;

/**
 When adds a new object, there is a new table will be created, if the class of this object is 
 modified, the former class type will be not accessable. So the method is used to remove the 
 former useless tables.

 @return Whether opertate success
 */
- (BOOL)clearRedundancy;

///----------------------------
/// @name Transaction Operation
///----------------------------

/**
 Executes the operation in the transaction mode with a block.
 If the rollback is set to YES, the operation will be rollback, whereas after
 the block is finished the operation will be commit automatically.

 @param block The operations are operated in the block
 */
- (void)inTransaction:(nonnull void (^)( BOOL * _Nonnull rollback))block;

///---------------------------
/// @name Customized Operation
///---------------------------

/**
 Obtains the object_id of the object, it is the unique signature of an object.

 @param object The object is not necessary already in the database.
 @return A string of signature
 */
- (nullable NSString *)objectID:(nullable id)object;

/**
 If an object is been updated in the database, the database will send the notificaiton

 @param object The object that may be modified
 @return The Stirng of notification name
 */
- (nullable NSString *)objectNotificationName:(nullable id)object;

@end
NS_ASSUME_NONNULL_END

@protocol CrystLite <NSObject>
@optional

/**
 If a class has parent class which have other properties
 needed to be stored, this protocol can recurse the super class
 properties.
 
 @return Whether prase super class
 */
+ (BOOL) CrystLiteObjectIsHasSuperClass;

/**
 Creates an specific db to store this type object.
 
 @return A string of the database name
 */
+ (nonnull NSString *)CrystLiteName;

/**
 Assigns the primary key for the object, if this method is not implemented,
 the primary key will be assgin to `object_id`.
 
 @return A string of primary key
 */
+ (nonnull NSString *)CrystLitePrimaryKey;

/**
 If a property is not in the whitelist, it will be ignored in store process.
 Returns nil to ignore this feature.
 
 @return An array of property's name
 */
+ (nonnull NSArray<NSString *> *)CrystLiteWhitelistProperties;

/**
 All the properties in blacklist will be ignored in store process.
 Return nil to ignore this feature.
 
 @return An array of property's name
 */
+ (nonnull NSArray<NSString *> *)CrystLiteBlacklistProperties;
@end




