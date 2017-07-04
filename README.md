CrystDB
==============
![Language](https://img.shields.io/badge/language-Objective--C-orange.svg)
[![License MIT](https://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://raw.githubusercontent.com/Chasel-Shao/CrystDB/master/LICENSE)&nbsp;
[![CocoaPods](http://img.shields.io/cocoapods/v/CrystDB.svg?style=flat)](http://cocoapods.org/pods/CrystDB)&nbsp;

:book: English Documentation | [:book: 中文文档](README-CN.md)


Introduce
==============
A thread-safe Object Relational Mapping database that stores objects based on SQLite. However it's lightweight but high performance. Futhermore, when dealing with simple data object, it displays rapid processing rate in regard of the execution of both querying and adding, so it's an alternertive to Realm and Core Data.

Features
==============

- **Lightwight**: Less soruce files，easily and conveniently to use
- **Noninvasive**: No need to inherit other base class or use other auxiliary class
- **Supported Type**: Supported almost all of the types of Objective-C and C
- **Safe Mapping**: Checks every object types and can be safe in conversion between the SQLite and Objective-C.
- **High Performance**: Fast storage speed, and the stroage speed of the simple object is 2-4 times fast than Realm, as well as the query speed is also fast than Realm.

Performance
==============
The time cost of disposing 2000 times GithubUser objects (iPhone 6s).

![Benchmark result](https://raw.githubusercontent.com/Chasel-Shao/CrystDB/master/Benchmark/result.png
)


Getting Started
==============

### Creating and Opening the database
```objc
// 1. creating an default database:
CrystLite *db = [CrystLite defaultCrystLite];

// 2. creating an database with the name of `Person`:
CrystLite *db = [[CrystLite alloc] initWithName:@"Person"];
```
### Adding and Updating objects
```objc
// Person Model
@interface Person : NSObject <CrystLite>
@property (nonatomic,assign) UInt64 uid;
@property (nonatomic,copy) NSString *name;
@property (nonatomic,assign) NSInteger age;
@end
@implementation Person
@end

// 0. Creating an Person object:
Person *p =  [[Person alloc] init];
p.uid = 8082;
p.name = @"Ares";
p.age = 27;

// 1. Adding an object，if there have been the object，then update the object:
BOOL result = [db addOrUpdateObject:p];

// 2. Adding an object, if there have benn the object, then return with no processing:
BOOL result = [db addOrIgnoreObject:p];

// 3. If the object is already in the database and the object also have implemented the method of `CrystLitePrimaryKey`, then you can update the object directly(otherwise it's recommended to use `addOrUpdateObject：` method instead):
BOOL result = [db updateObject:p];

// 4. Use Transaction:
[db inTransaction:^(BOOL * _Nonnull rollback) {
   BOOL result = [db addOrUpdateObject:p];
   if (result == NO) {
      *rollback = YES;
   }
}];  
```
### Querying objects
```objc
// 1. Querying objects with the Class of this object:
NSArray *persons = [db queryWithClass:[Person class] condition:nil];

// 2. Querying objects with conditions:
NSArray *persons = [db queryWithClass:[Person class] condition:@"age > 25 or name == 'Ares' "];

// 3. Querying objects with format conditions:
NSArray *persons = [db queryWithClass:[Person class] conditions:@"age > %d or name == '%@' ",25,@"Ares"];

// 4. Querying with sql sentence syntax:
NSArray *persons = [db queryWithClass:[Person class] where:@"age > 8082" orderBy:@"uid desc" limit:@"1,10"];
```
### Deleting objects
```objc
// 1. Deleting objects with conditions:
BOOL result = [db deleteClass:[Person class] where:@"name = 'Ares' "];

// 2. Deleting all the object related to the class:
BOOL result = [db dropClass:[Person class]];

// 3. Deleting all the objects in this database:
BOOL result = [db dropAll];

// 4. Deleting the object which implement the method of `CrystLitePrimaryKey` and the object has the vlaue of primary key, otherwise it will fail:
BOOL result = [db deleteObject:p];
```
### How to use Protocol
```objc
// 1. Assigning the primary key
+ (NSString *)CrystLitePrimaryKey{
    return @"uid";
}

// 2. Appointing the default database of this object
+ (NSString *)CrystLiteName{
    return @"child.db";
}

// 3. Setting the property whitelist of this object
+ (NSArray *)CrystLiteBlacklistProperties{
    return @[@"uid"，@"name"，@"age"];
}

// 4. Setting the property blacklist of this object
+ (NSArray<NSString *> *)CrystLiteBlacklistProperties{
    return @[@"age"];
}

// 5. If the object has parent class which have properties involved
+ (BOOL)CrystLiteObjectIsHasSuperClass{
    return YES;
}

// 6. If there are objects nested in this object, it needs to implement the Coding method, or it's strongly recommended to use `CSModel` to implement the following method:
- (void)encodeWithCoder:(NSCoder *)aCoder{
    [self cs_encode:aCoder];
}
- (instancetype)initWithCoder:(NSCoder *)aDecoder{
    return [self cs_decoder:aDecoder];
}
```
### Simpily use the Category method
```objc
// 1. Adding an object，if there have been the object，then update the object:
BOOL result = [p cs_addOrUpdateToDB];

// 2. Adding an object with no processing if there have benn the object:
BOOL result = [p cs_addOrIgnoreToDB];

// 3. Querying objects with conditions:
Person *p = [Person cs_queryObjectsWithCondition:@"age > 25"];

// 4. Querying the object by primary key which must implement the `CrystLitePrimaryKey` method:
Person *p = [Person cs_queryObjectOnPrimary:@"8082"];

// 5. Querying the number of all the objects:
NSInteger count = [Person cs_queryObjectCount];

// 6. Querying the create time of an object:
NSInteger createTime = [p cs_queryObjectCreateTime];

// 7. Querying the update time of an object:
NSInteger updateTime = [p cs_queryObjectUpdateTime];

// 8. Deleting objects with the conditions:
[Person cs_deleteFromDBWithCondition:@"name = 'Ares' "];

// 9. Deleting all the objects in the database:
BOOL result = [p cs_deleteFromDB];
  
// 10. Executing the transaction in a block
[Person cs_inTransaction:^(CrystLite *db, BOOL *rollback) {
   BOOL result = [db addOrUpdateObject:p];
   if (result == NO) {
      *rollback = YES;
    }
}];
```

Installation
==============

### Installation with CocoaPods

1. Specify the  `pod 'CrystDB'` in your Podfile
2. Then run the `pod install` or `pod update`
3. Import the header file \<CrystDB/CrystDB.h\>


### Manual Installation

1. Download the `CrystDB`
2. Import the CrystDB.h and the relevent source files


Author
==============
- [Chasel-Shao](https://github.com/Chasel-Shao) 753080265@qq.com

License
==============
CrystDB is released under the MIT license. See LICENSE for details.


