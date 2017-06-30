CrystDB
==============

[![License MIT](https://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://raw.githubusercontent.com/Chasel-Shao/CrystDB/master/LICENSE)&nbsp;
[![CocoaPods](http://img.shields.io/cocoapods/v/CrystDB.svg?style=flat)](http://cocoapods.org/pods/CrystDB)&nbsp;

基础简介
==============
CrystDB 是一个线程安全的对象映射（ORM）数据库，并基于SQLite实现，框架轻量简便、性能高，对于简单模型数据的操作速度要比Realm快很多，是Realm以及CoreData的替代之选。<br/>


性能比较
==============
处理 GithubUser 数据 2000 次耗时统计 (iPhone 6s):

![Benchmark result](https://raw.githubusercontent.com/Chasel-Shao/CrystDB/master/Benchmark/result.png
)



功能特性
==============

- **简洁轻量**: 源码文件少，操作方法简单方便
- **无侵入性**: 无需继承自其他基类和使用其他辅助类
- **存储支持**: 存储类型支持大多数Objective-C类型和C类型
- **类型安全**: 检查每个对象类型，能安全的在SQlite类型之间转换
- **高性能**: 存储速度快，对简单模型对象的存储速度是Realm的2-4倍；2000次的对象查询速度也比Realm快

使用方法
==============

### 创建或打开数据库
```objc
// 初始化一个默认的数据库:
CrystLite *db = [CrystLite defaultCrystLite];

// 初始化一个名字为`Person`数据库:
CrystLite *db = [[CrystLite alloc] initWithName:@"Person"];
```
### 插入和更新对象
```objc
// Person Model
@interface Person : NSObject <CrystLite>
@property (nonatomic,assign) UInt64 uid;
@property (nonatomic,copy) NSString *name;
@property (nonatomic,assign) NSInteger age;
@end
@implementation Person
@end

// 生成Person 对象:
Person *p =  [[Person alloc] init];
p.uid = 8082;
p.name = @"Ares";
p.age = 27;

// 存储Person对象，如果已经存在该Person对象，则执行更新操作:
BOOL result = [db addOrUpdateObject:p];

// 存储Person对象，如果已经存在该Person对象，则不做处理:
BOOL result = [db addOrIgnoreObject:p];

// 如果已知该对象已存在于数据库中，并且Person对象实现了`CrystLitePrimaryKey`方法，可以直接更新对象（否则建议使用addOrUpdateObject：方法）:
BOOL result = [db updateObject:p];

// 使用事务
[db inTransaction:^(BOOL * _Nonnull rollback) {
   BOOL result = [db addOrUpdateObject:p];
   if (result == NO) {
      *rollback = YES;
   }
}];  
```
### 查询对象操作
```objc
// 查询Person类对象:
NSArray *persons = [db queryWithClass:[Person class] condition:nil];

// 使用条件检索，查询Person类对象组:
NSArray *persons = [db queryWithClass:[Person class] condition:@"age > 25 or name == 'Ares' "];

// 或者使用格式化参数检索，查询Person类对象组:
NSArray *persons = [db queryWithClass:[Person class] conditions:@"age > %d or name == '%@' ",25,@"Ares"];

// 或者使用SQL的提哦按建检索，查询Person类对象数组:
NSArray *persons = [db queryWithClass:[Person class] where:@"age > 8082" orderBy:@"uid desc" limit:@"1,10"];
```
### 删除对象操作
```objc
// 使用条件检索，删除Person类中的对象:
BOOL result = [db deleteClass:[Person class] where:@"name = 'Ares' "];

// 删除Person类中所有的对象:
BOOL result = [db dropClass:[Person class]];

// 删除数据库中所有的对象:
BOOL result = [db dropAll];

// 删除的对象，需要实现了`CrystLitePrimaryKey`方法，否则p对象的所有属性值都和数据库中的对象完全相同，否则无法找到并删除该对象:
BOOL result = [db deleteObject:p];
```
### 协议方法的使用
```objc
// 设置主键，用于标识对象的唯一性:
+ (NSString *)CrystLitePrimaryKey{
    return @"uid";
}

// 在对象中实现下面方法，操作对象时采用默认该数据库:
+ (NSString *)CrystLiteName{
    return @"child.db";
}

// 设置执行数据库操作的字段白名单:
+ (NSArray *)CrystLiteBlacklistProperties{
    return @[@"uid"，@"name"，@"age"];
}

// 设置执行数据库操作的字段黑名单:
+ (NSArray<NSString *> *)CrystLiteBlacklistProperties{
    return @[@"age"];
}

// 如果对象是继承关系，需要解析并操作父类的元素，实现以下方法:
+ (BOOL)CrystLiteObjectIsHasSuperClass{
    return YES;
}

// 如果存储的对象中，嵌套子对象属性，推荐使用`CSModel`，并实现以下Coding方法:
- (void)encodeWithCoder:(NSCoder *)aCoder{
    [self cs_encode:aCoder];
}
- (instancetype)initWithCoder:(NSCoder *)aDecoder{
    return [self cs_decoder:aDecoder];
}
```
### 使用方便简洁的分类方法
```objc
// 存储对象，如果已存在该对象则执行更新操作
BOOL result = [p cs_addOrUpdateToDB];

// 存储对象，如果已存在该对象则不处理
BOOL result = [p cs_addOrIgnoreToDB];

// 按条件检索，查询该类的对象
Person *p = [Person cs_queryObjectsWithCondition:@"age > 25"];

// 根据主键来查询对象，对象必须实现了`CrystLitePrimaryKey`方法
Person *p = [Person cs_queryObjectOnPrimary:@"8082"];

// 查询该类对象在数据库的总数
NSInteger count = [Person cs_queryObjectCount];

// 查询对象在数据库中创建时间
NSInteger createTime = [p cs_queryObjectCreateTime];

// 查询对象在数据库中更新时间
NSInteger updateTime = [p cs_queryObjectUpdateTime];

// 根据条件检索，删除该类的所有对象
[Person cs_deleteFromDBWithCondition:@"name = 'Ares' "];

// 从数据库中删除所有对象
BOOL result = [p cs_deleteFromDB];
  
// 使用事务方法，操作数据库
[Person cs_inTransaction:^(CrystLite *db, BOOL *rollback) {
   BOOL result = [db addOrUpdateObject:p];
   if (result == NO) {
      *rollback = YES;
    }
}];
```
集成
==============

### CocoaPods

1. 在 Podfile 中添加 `pod 'CrystDB'`
2. 执行 `pod install` 或 `pod update`
3. 导入 \<CrystDB/CrystDB.h\>


### 手动安装

1. 下载 CrystDB 
2. 手动导入 CrystDB.h 及其源码文件


作者
==============
- [Chasel-Shao](https://github.com/Chasel-Shao) 753080265@qq.com
- 欢迎咨询以及问题反馈 

许可证
==============
CrystDB 使用 MIT 许可证，详情见 LICENSE 文件。


