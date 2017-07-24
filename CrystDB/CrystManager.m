//
// CrystManager.m
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

#import "CrystManager.h"
#import <objc/runtime.h>
#import <CommonCrypto/CommonDigest.h>
#if __has_include(<sqlite3.h>)
#import <sqlite3.h>
#else
#import "sqlite3.h"
#endif

#define kCrystDBPrefix @"Cryst"
#define kDefaultCrystDBName @"cryst.db"
#define CSLog(...) printf("%s\n", [[NSString stringWithFormat:__VA_ARGS__] UTF8String])

@interface CrystManager(){
    sqlite3 *_db;
    BOOL _inTransaction;
    NSMutableArray *_propAttrValueOfObjectArray;
    NSMutableDictionary *_columnNameToIndexMap;
    NSMutableDictionary *_tbNameToPKeyMap;
    NSMutableSet *_blacklistSet;
    NSMutableSet *_whitelistSet;
    NSMutableDictionary *_classWithBlackOrWhitePropertiesDict;
    NSMutableDictionary *_classFingerPrintDict;
    dispatch_queue_t _workQueue;
    dispatch_queue_t _cacheQueue;
}
@end

@implementation CrystManager
static NSMutableDictionary *_singletonDBDict = nil;

+ (void)load{
    NSString *basePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *dbDir = [basePath stringByAppendingPathComponent:kCrystDBPrefix];
    NSFileManager *mananger = [NSFileManager defaultManager];
    BOOL isDir = NO;
    BOOL isExist =  [mananger fileExistsAtPath:dbDir isDirectory:&isDir];
    if (!(isExist == YES && isDir == YES)) {
        [mananger createDirectoryAtPath:dbDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    CSLog(@"Default CrystDB Dir : %@",dbDir);
}

+ (instancetype)defaultCrystDB{
    static CrystManager *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache  = [[CrystManager alloc] initWithName:kDefaultCrystDBName];
    });
    return cache;
}

- (NSMutableDictionary *)singletonDBDict{
    if (_singletonDBDict == nil) {
        _singletonDBDict = [NSMutableDictionary dictionary];
    }
    return _singletonDBDict;
}

- (instancetype)initWithObject:(id)object{
    if ([[object class] respondsToSelector:@selector(CrystDBName)]) {
        _dbName = [[object class] CrystDBName];
    }else{
        _dbName = kDefaultCrystDBName;
    }
    return  [self initWithName:_dbName];
}

- (instancetype)initWithName:(NSString *)dbName {
    _dbName = dbName;
    return [self init];
}

- (instancetype)init{
    if (self = [super init]) {
        if (_dbName == nil) _dbName = kDefaultCrystDBName;
        NSMutableDictionary *dbDict = [self singletonDBDict];
        if (dbDict[_dbName]) {
            return dbDict[_dbName];
        }else{
            // open sqlite
            [self __openWithPath:_dbName];
            // queue
            _workQueue = dispatch_queue_create("cs_cryst_queue", DISPATCH_QUEUE_SERIAL);
            _cacheQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
            // cache db
            dbDict[_dbName] = self;
            [self _initSysTable]; // create sys table
        }
    }
    return self;
}

#pragma mark instance method
- (BOOL)addOrUpdateObject:(id<CrystDB>)object{
    if (object == nil) return NO;
    NSString *primaryKey = [self _primaryKeyWithObject:object];
    [self _initialParams:object];
    if (primaryKey == nil) {
        NSAssert(0, @"the primary key doesn't exist");
    }else{
        if(![self _createTable:[object class] OnKey:primaryKey]) return NO;
    }
    __block BOOL result ;
    dispatch_sync(_workQueue, ^{
        result =  [self _insertDataToTable:object isUpadate:YES];
    });
    
    if (_isBindToObject && result && primaryKey) {
        [self _pushNotificationWithObject:object];
    }
    return result;
}

- (BOOL)addOrIgnoreObject:(id<CrystDB>)object{
    if (object == nil) return NO;
    NSString *primaryKey = [self _primaryKeyWithObject:object];
    [self _initialParams:object];
    if (primaryKey == nil) {
        NSAssert(0, @"the primary key doesn't exist");
    }else{
        if(![self _createTable:[object class] OnKey:primaryKey]) return NO;
    }
    __block BOOL result ;
    dispatch_sync(_workQueue, ^{
        result =  [self _insertDataToTable:object isUpadate:NO];
    });
    
    if (_isBindToObject && result && primaryKey) {
        [self _pushNotificationWithObject:object];
    }
    return result;
}

- (BOOL)addOrUpdateWithClass:(Class)class withDict:(NSDictionary *)dict{
    NSParameterAssert(class);
    if (dict == nil)   return NO;
    NSString *primaryKey = [self _primaryKeyWithClass:class];
    id object = nil;
    for (NSString *key in dict.allKeys) {
        if ([key isEqualToString:primaryKey]) {
            id primaryValue = dict[primaryKey];
            if ([primaryValue isKindOfClass:[NSString class]]) {
                object = [[self queryWithClass:class conditions:@"where %@ = '%@'",primaryKey,dict[primaryKey]] firstObject];
            }else if([primaryValue isKindOfClass:[NSNumber class]]){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wformat"
                object = [[self queryWithClass:class conditions:@"where %@ = '%ld'",primaryKey,[dict[primaryKey] integerValue]] firstObject];
#pragma clang diagnostic pop
            }else{
                // the type of object is  neither NSString or NSNumber
                return NO;
            }
            if (object) {
                // through
            }else{
                // no primary key-value
                object = [class new];
            }
        }
    }
    NSMutableSet *propertySet = [NSMutableSet set];
    unsigned int count;
    objc_property_t *properties = class_copyPropertyList(class,&count);
    for (int i = 0; i < count ; i++) {
        objc_property_t property = properties[i];
        const char *cName = property_getName(property);
        NSString *name = [NSString stringWithCString:cName encoding:NSUTF8StringEncoding];
        [propertySet addObject:name];
    }
    for (NSString *key in dict.allKeys) {
        if([propertySet containsObject:key]){
            [object setValue:dict[key] forKey:key];
        }
    }
    free(properties);
    return [self addOrUpdateObject:object];
}

- (BOOL)updateObject:(id)object{
    [self _initialParams:object];
    __block BOOL result;
    dispatch_sync(_workQueue, ^{
        result  =  [self _updateDataToTable:object];
    });
    return result;
}

- (id)queryWithClass:(Class)class onPrimary:(id)primaryValue{
    NSParameterAssert(class);
    NSString *primaryKey =  [self _primaryKeyWithClass:class];
    NSString *where  = nil;
    if ([primaryKey isEqualToString:@"object_id"]) {
        where = [NSString stringWithFormat:@"where object_id = '%@'",primaryValue];
    }else{
        where = [NSString stringWithFormat:@"where %@ = '%@'",primaryKey,primaryValue];
    }
    return [[self _queryObjectWithClass:class condition:where] firstObject];
}

- (NSArray *)queryWithClass:(Class)class condition:(NSString *)condition{
    return [self queryWithClass:class conditions:condition];
}

- (NSArray *)queryWithClass:(Class)class conditions:(NSString *)conditionFormat,...{
    NSParameterAssert(class);
    if (conditionFormat != nil) {
        va_list ap;
        va_start(ap, conditionFormat);
        NSString *condition = [[NSString alloc] initWithFormat:conditionFormat arguments:ap];
        va_end(ap);
        return [self _queryObjectWithClass:class condition:condition];
    }else{
        return [self _queryObjectWithClass:class condition:nil];
    }
}

- (NSArray *)queryWithClass:(Class)class where:(NSString *)where orderBy:(NSString *)orderBy limit:(NSString *)limit{
    NSParameterAssert(class);
    NSMutableString *sql = [NSMutableString string];
    if (where && where.length > 0) {
        [sql appendFormat:@"where %@ ",where];
    }
    if (orderBy && orderBy.length > 0) {
        [sql appendFormat:@"order by %@ ",orderBy];
    }
    if (limit && limit.length > 0) {
        [sql appendFormat:@"limit %@",limit];
    }
    return [self _queryObjectWithClass:class condition:sql];
}


- (NSInteger)queryCount:(Class)class{
    if (class == nil)  return  0;
    // prepare
    NSString *tableName = [self _tableNameWithClass:class];
    NSString *primaryKey = [self _primaryKeyWithClass:class];
    [self _createTable:class OnKey:primaryKey];
    // execute
    NSString *sql = [NSString stringWithFormat:@"select count(*) from %@;",tableName];
    sqlite3_stmt *stmt = [self __prepareStmt:sql];
    [self __nextWithError:nil withStatement:stmt];
    int col_nums = sqlite3_column_count(stmt);
    NSInteger count = 0;
    if (col_nums > 0) {
        count = [[self __objectForColumnIndex:0 withStatement:stmt] integerValue];
        sqlite3_finalize(stmt);
    }
    return count;
}

- (NSInteger)queryUpdateTime:(id)object{
    return [self _queryObject:object internalWithField:@"modification_time"];
}
-(NSInteger)queryCreateTime:(id)object{
    return [self _queryObject:object internalWithField:@"create_time"];
}

- (NSInteger)_queryObject:(id)object internalWithField:(NSString *)field{
    if (object == nil) return  0;
    NSString *tableName = [self _tableNameWithObject:object];
    NSString *primaryKey = [self _primaryKeyWithObject:object];
    [self _createTable:[object class] OnKey:primaryKey];
    id primaryValue = [object valueForKey:primaryKey];
    // execute
    NSString *sql = [NSString stringWithFormat:@"select %@ from %@ where %@ = '%@';",field,tableName,primaryKey,primaryValue];
    sqlite3_stmt *stmt = [self __prepareStmt:sql];
    [self __nextWithError:nil withStatement:stmt];
    int col_nums = sqlite3_column_count(stmt);
    NSInteger time = 0;
    if (col_nums > 0) {
        time = [[self __objectForColumnIndex:0 withStatement:stmt] integerValue];
        sqlite3_finalize(stmt);
    }
    return time;
}


- (BOOL)deleteObject:(id)object{
    if (object == nil) return NO;
    NSString *tableName = [self _tableNameWithObject:object];
    NSString *primaryKey =  [self _primaryKeyWithObject:object];
    if (!tableName || !primaryKey ) {
        return NO;
    }
    NSString *sql = nil;
    if ([primaryKey isEqualToString:@"object_id"]) {
        sql =  [NSString stringWithFormat:@"delete from '%@' where object_id = '%@';",tableName,[self objectID:object]];
    }else{
        id value = [object valueForKey:primaryKey];
        if (!value) {
            return NO;
        }else{
            sql =  [NSString stringWithFormat:@"delete from '%@' where %@ = '%@';",tableName,primaryKey,value];
        }
    }
    __block BOOL result;
    dispatch_sync(_workQueue, ^{
        result =  [self __executeUpdate:sql];
    });
    // push notification
    if (_isBindToObject && result) {
        [self _pushNotificationWithObject:object];
    }
    return result;
}

- (BOOL)deleteClass:(Class)class where:(NSString *)where{
    if (class == nil) return NO;
    NSString *tableName = [self _tableNameWithClass:class];
    NSString *sql = nil;
    NSArray *resultArray = [self _queryObjectWithClass:class condition:where];
    if(where == nil || where.length == 0){
        sql =  [NSString stringWithFormat:@"delete from '%@';",tableName];
    }else{
        sql =  [NSString stringWithFormat:@"delete from '%@' where %@;",tableName,where];
    }
    BOOL result =   [self __executeUpdate:sql];
    //push notification
    if (_isBindToObject && result) {
        for (id obj in resultArray) {
            [self _pushNotificationWithObject:obj];
        }
    }
    return result;
}

- (void)inTransaction:(void (^)(BOOL *isRollback))block{
    BOOL shouldRollback = NO;
    dispatch_sync(_workQueue, ^{
        [self __beginTransaction];
    });
    block(&shouldRollback);
    dispatch_sync(_workQueue, ^{
        if (shouldRollback) {
            [self __rollback];
        }else {
            [self __commit];
        }
    });
}

- (NSString *)objectID:(id)object{
    if (object == nil) return nil;
    unsigned int numIvars;
    Ivar *vars = class_copyIvarList([object class], &numIvars);
    NSMutableString *var_params_string = [NSMutableString stringWithFormat:@"class=%@:",NSStringFromClass([object class])];
    [var_params_string appendFormat:@"&protocol=%@&", [self _protocolFingerPrint:[object class]]];
    for(int i = 0; i < numIvars; i++) {
        Ivar thisIvar = vars[i];
        NSString *name = [NSString stringWithUTF8String:ivar_getName(thisIvar)];
        NSString *type = [NSString stringWithUTF8String:ivar_getTypeEncoding(thisIvar)];
        [var_params_string appendFormat:@"%@",name];
        [var_params_string appendFormat:@"=%@&",[object valueForKey:name]];
        if (i == numIvars - 1) {
            [var_params_string appendFormat:@"%@",type];
        }else{
            [var_params_string appendFormat:@"%@,",type];
        }
    }
    free(vars);
    return [self _md5:var_params_string];
}

- (NSString *)objectNotificationName:(id)object{
    if (object == nil) return nil;
    NSString *tableName = [self _tableNameWithObject:object];
    NSString *primaryKey = [self _primaryKeyWithObject:object];
    id value = nil;
    if (primaryKey != nil) {
        if ( [primaryKey isEqualToString:@"object_id"]) {
            value = [self objectID:object];
        }else{
            value = [object valueForKey:primaryKey];
        }
    }
    return [NSString stringWithFormat:@"%@_%@",tableName,value];
}

- (BOOL)dropAll{
    sqlite3_stmt *stmt = [self __prepareStmt:@"select name from sqlite_master where type = 'table';"];
    NSMutableArray *tableArray = [NSMutableArray array];
    while ([self __nextWithError:nil withStatement:stmt]) {
        NSString *tableName =  [self __objectForColumnIndex:0 withStatement:stmt];
        if (![tableName isEqualToString:@"cryst_sys_class"]) {
            [tableArray addObject:tableName];
        }
    }
    sqlite3_finalize(stmt);
    [self __beginTransaction];
    BOOL isOk = YES;
    for (NSString *tableName in tableArray) {
        BOOL result =  [self __executeUpdate:[NSString stringWithFormat:@"drop table if exists '%@'",tableName]];
        if (!result) {
            isOk = NO;
        }
    }
    if (isOk) {
        [self __commit];
        [self __executeUpdate:@"delete from cryst_sys_class"];
        return YES;
    }else{
        [self __rollback];
        return NO;
    }
}

- (BOOL)dropClass:(Class)class{
    if (class == nil) return NO;
    NSString *tableName = [self _tableNameWithClass:class];
    if (tableName == nil)  return NO;
    BOOL result =  [self __executeUpdate:[NSString stringWithFormat:@"drop table if exists '%@'",tableName]];
    if (result) {
        return [self __executeUpdate:[NSString stringWithFormat:@"delete from cryst_sys_class where table_name = '%@'",tableName]];
    }
    return NO;
}

- (BOOL)clearRedundancy{
    sqlite3_stmt *stmt = [self __prepareStmt:@"select table_name from cryst_sys_class group by class_name having count(class_name) > 1 "];
    NSMutableArray *delTableArray = [NSMutableArray array];
    NSMutableArray *normalTableArray = [NSMutableArray array];
    while ([self __nextWithError:nil withStatement:stmt]) {
        NSString *tableName =  [self __objectForColumnIndex:0 withStatement:stmt];
        [normalTableArray addObject:tableName];
    }
    sqlite3_finalize(stmt);
    for (NSString *tableName in normalTableArray) {
        NSArray *componet = [tableName componentsSeparatedByString:@"_"];
        if (componet.count > 2) {
            NSString *className = [componet objectAtIndex:1];
            NSString *sql = [NSString stringWithFormat:@"select table_name from cryst_sys_class where table_name != '%@' and lower(class_name) = '%@'",tableName,className];
            sqlite3_stmt *stmt = [self __prepareStmt:sql];
            while ([self __nextWithError:nil withStatement:stmt]) {
                NSString *delTableName =   [self __objectForColumnIndex:0 withStatement:stmt];
                [delTableArray addObject:delTableName];
            }
            sqlite3_finalize(stmt);
        }
    }
    [self __beginTransaction];
    BOOL isOk = YES;
    for (NSString *tableName in delTableArray) {
        BOOL result =  [self __executeUpdate:[NSString stringWithFormat:@"drop table if exists '%@'",tableName]];
        if (!result) { isOk = NO; }
    }
    BOOL delSysResult = [self __executeUpdate:[NSString stringWithFormat:@"delete from cryst_sys_class where table_name in ('%@')",[delTableArray componentsJoinedByString:@"','"]]];
    if (isOk && delSysResult) {
        [self __commit];
        return YES;
    }else{
        [self __rollback];
        return NO;
    }
}

#pragma mark -- private method
- (BOOL)_createTable:(Class)class OnKey:(NSString *)key{
    if (!_propAttrValueOfObjectArray) return NO;
    NSString *tableName = [self _tableNameWithClass:class];
    NSMutableString *mutableSql = [NSMutableString stringWithFormat:@"create table if not exists '%@' (object_id text",tableName];
    for (NSDictionary *dict in _propAttrValueOfObjectArray) {
        [mutableSql appendFormat:@", %@ %@",dict[@"prop"],dict[@"attr"]];
    }
    [mutableSql appendString:[NSString stringWithFormat:@", modification_time integer,last_access_time integer,primary key(%@));",key]];
    dispatch_async(_cacheQueue, ^{
        [self _recordTableInfoWithClass:class];
    });
    return [self __executeUpdate:mutableSql];
}
- (void)_initSysTable{
    NSString *sql = @"pragma journal_mode = wal; pragma synchronous = normal;create table if not exists cryst_sys_class(table_name text primary key,class_name text,create_time integer);";
    [self __executeUpdate:sql];
}

- (void)_recordTableInfoWithClass:(Class)class{
    if (class == nil)   return;
    NSString *tableName = [self _tableNameWithClass:class];
    NSString *className = NSStringFromClass(class);
    NSInteger createTime = (NSInteger)time(NULL);
    NSString *sql = [NSString stringWithFormat:@"insert or replace into cryst_sys_class(table_name,class_name,create_time) values('%@','%@',%ld)",tableName,className,(long)createTime];
    [self __executeUpdate:sql];
}

- (NSArray *)_queryObjectWithClass:(Class)class condition:(NSString *)condition{
    NSString *tableName = [self _tableNameWithClass:class];
    __block NSMutableArray *result = [NSMutableArray array];
    __block NSMutableArray *accessedObjectIds = [NSMutableArray array];
    NSString *sql = nil;
    if (condition && condition.length > 0) {
        sql = [NSString stringWithFormat:@"select * from '%@' %@",tableName,condition];
    }else{
        sql = [NSString stringWithFormat:@"select * from '%@'",tableName];
    }
    dispatch_sync(_workQueue, ^{
        sqlite3_stmt *stmt = [self __prepareStmt:sql];
        if (!stmt) {
            // fail to query data
            if(self.isDebug) CSLog(@"fail to execute sql statement : %@",sql);
            return ;
        }
        int col_nums = sqlite3_column_count(stmt);
        if (!stmt) {
            // stmt is null
        }else{
            [self _columnNameToIndexMapWithStatement:stmt];
            while ([self __nextWithError:nil withStatement:stmt]) {
                id obj = [class new];
                if (!obj)  continue;
                NSDictionary *keysInClassDict = [self _keysLowerCaseInClass:class];
                for (int idx = 0; idx < col_nums; idx ++) {
                    NSString *key =  [_columnNameToIndexMap objectForKey:@(idx)];
                    if (key && keysInClassDict[key]) {
                        id value = [self __objectForColumnIndex:idx withStatement:stmt];
                        if (value != nil) {
                            [obj setValue:value forKey:keysInClassDict[key]];
                        }
                    }
                }/* end for */
                [result addObject:obj];
            }/* end while */
            sqlite3_finalize(stmt);
        }
    });
    dispatch_async(_cacheQueue, ^{
        [self _dbUpdateAccessTimeWithObject_ids:accessedObjectIds inTable:[self _tableNameWithClass:class]];
    });
    return result;
}

- (NSString *)_primaryKeyWithClass:(Class)className{
    return  [self _primaryKeyWithObject:[[className alloc] init]];
}

- (NSString *)_primaryKeyWithObject:(id<CrystDB>)object{
    if ([[self tbNameToPKeyMap] objectForKey:NSStringFromClass([object class])]) {
        return [[self tbNameToPKeyMap] objectForKey:NSStringFromClass([object class])];
    }
    if ([[object class] respondsToSelector:@selector(CrystDBPrimaryKey)]) {
        NSString *primaryKey =  [[object class] CrystDBPrimaryKey];
        if (primaryKey != nil && primaryKey.length > 0) {
            [[self tbNameToPKeyMap] setObject:primaryKey forKey:NSStringFromClass([object class])];
            return primaryKey;
        }else{
            return @"object_id";
        }
    }else{
        // default key
        return @"object_id";
    }
}

- (BOOL)_insertDataToTable:(id)object isUpadate:(BOOL)isupdate{
    NSInteger count = _propAttrValueOfObjectArray.count;
    NSMutableString *mutableSql;
    if (isupdate) {
        mutableSql = [NSMutableString stringWithFormat:@"insert or replace into '%@' (object_id,",[self _tableNameWithObject:object]];
    }else{
        mutableSql = [NSMutableString stringWithFormat:@"insert or ignore into '%@' (object_id,",[self _tableNameWithObject:object]];
    }
    
    for (NSInteger i = 0; i < count; i ++) {
        NSDictionary *dict = [_propAttrValueOfObjectArray objectAtIndex:i];
        [mutableSql appendFormat:@" %@,",dict[@"prop"]];
    }
    [mutableSql appendString:@" modification_time, last_access_time) values (:object_id,"];
    for (NSInteger i = 0; i < count; i++) {
        NSDictionary *dict = [_propAttrValueOfObjectArray objectAtIndex:i];
        [mutableSql appendFormat:@" :%@,",dict[@"prop"]];
    }
    [mutableSql appendString:@":modification_time, :last_access_time);"];
    sqlite3_stmt *pStmt =  [self __prepareStmt:mutableSql];
    if (pStmt == NULL) {
        if (_isDebug) {
            CSLog(@"prepare failure : %@",mutableSql);
        }
        return NO;
    }
    int queryCount = sqlite3_bind_parameter_count(pStmt);
    int idx = 0;
    for (NSDictionary *dict in _propAttrValueOfObjectArray) {
        // Prefix the key with a colon.
        NSString *parameterName = [[NSString alloc] initWithFormat:@":%@", dict[@"prop"]];
        // Get the index for the parameter name.
        int namedIdx = sqlite3_bind_parameter_index(pStmt, [parameterName UTF8String]);
        if (namedIdx > 0) {
            // Standard binding from here.
            [self __bindObject:dict[@"value"] toColumn:namedIdx inStatement:pStmt];
            // increment the binding count, so our check below works out
            idx++;
        }
        else {
            if(self.isDebug) CSLog(@"Could not find index for %@", parameterName);
        }
    }
    int  object_Idx = sqlite3_bind_parameter_index(pStmt, [@":object_id" UTF8String]);
    int  modification_time_Idx = sqlite3_bind_parameter_index(pStmt, [@":modification_time" UTF8String]);
    int  last_access_time_Idx = sqlite3_bind_parameter_index(pStmt, [@":last_access_time" UTF8String]);
    [self __bindObject:[self objectID:object] toColumn:object_Idx inStatement:pStmt];
    [self __bindObject:@((NSInteger)time(NULL)) toColumn:modification_time_Idx inStatement:pStmt];
    [self __bindObject:@((NSInteger)time(NULL)) toColumn:last_access_time_Idx inStatement:pStmt];
    if (idx != queryCount - 3) {
        if(self.isDebug) CSLog(@"Error -> \n%@",mutableSql);
        sqlite3_finalize(pStmt);
        return NO;
    }
    /// 3.excute sql
    int rc   = sqlite3_step(pStmt);
    sqlite3_finalize(pStmt);
    return rc;
}

- (void)_initialParams:(id)object{
    dispatch_sync(_workQueue, ^{
        BOOL isCompriseSuperClass = NO;
        if([[object class] respondsToSelector:@selector(CrystDBObjectIsHasSuperClass)]){
            isCompriseSuperClass = [[object class] CrystDBObjectIsHasSuperClass];
        }
        // Class objectClass = object_getClass(object); //kvo 之后的类发生变化
        Class objectClass = [object class];
        _propAttrValueOfObjectArray = nil;
        _propAttrValueOfObjectArray = [NSMutableArray array];
        // recursion parse properties of object
        while ([objectClass isSubclassOfClass:[NSObject class]] && objectClass != [NSObject class]) {
            unsigned int count;
            objc_property_t *properties = class_copyPropertyList(objectClass,&count);
            for (int i = 0; i < count ; i++) {
                objc_property_t property = properties[i];
                const char *cName = property_getName(property);
                NSString *name = [NSString stringWithCString:cName encoding:NSUTF8StringEncoding];
                const char *cAttr = property_getAttributes(property);
                NSString *attr = [NSString stringWithCString:cAttr encoding:NSUTF8StringEncoding];
                BOOL isGothrough = [self _isAcceptPropertyWithObject:object propertyName:name];
                if (!isGothrough) continue;
                // prase key-attr-value
                NSMutableDictionary *dict = [NSMutableDictionary dictionary];
                dict[@"prop"] = name;
                dict[@"attr"] = [self _parseModelTypeToSqliteType:attr];
                id value = [object valueForKey:name];
                // load value
                if ([dict[@"attr"] isEqualToString:@"blob"]) {
                    const char* _attribute = property_getAttributes(property);
                    NSString *attribute = [NSString stringWithUTF8String:_attribute];
                    if ([attribute hasPrefix:@"T#"] || [attribute hasPrefix:@"T@?"]) { // class struct //T@?,C,N,V_callback
                        NSData *data = [NSData dataWithBytes:&value length:sizeof(value)];
                        dict[@"value"] = data;
                    }else{
                        if ([value conformsToProtocol:@protocol(NSCoding)]
                            || [value conformsToProtocol:@protocol(NSSecureCoding)]) {
                            if ([value isKindOfClass:[NSArray class]]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-variable"
                                for (id object in value) {
                                    
                                    NSAssert([object conformsToProtocol:@protocol(NSCoding)],@"obect : %@, do not conform NSCoding",NSStringFromClass([object class]));
                                }
#pragma clang diagnostic pop
                            }
                            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:value];
                            dict[@"value"] = data;
                        }
                        else if(!value){
                            dict[@"value"] = [[NSData alloc] init];
                        }
                        else{
                            if(self.isDebug)  CSLog(@"This property %@ doesn't confirm to the protocol of NSCoding",name);
                            dict[@"value"] = [[NSData alloc] init];
                        }
                    } /* end if blob */
                }else{
                    dict[@"value"] = value;
                }
                // add dict to array
                [_propAttrValueOfObjectArray addObject:dict];
            }/* end for */
            free(properties);
            // whether contain the properties of superclass
            if (isCompriseSuperClass) {
                objectClass = [objectClass superclass];
            }else{
                break;
            }
        }/* end while */
    });/* end dispatch sync */
}


#pragma mark black or white list method
- (NSMutableSet *)_blacklist:(id)object{
    NSString *className = NSStringFromClass([object class]);
    _blacklistSet =  [[self classWithBlackOrWhitePropertiesDict] objectForKey:className];
    if (_blacklistSet == nil) {
        _blacklistSet = [NSMutableSet setWithArray:@[@"hash",@"superclass",@"description",@"debugDescription"]];
        if ([[object class] respondsToSelector:@selector(CrystDBBlacklistProperties)]) {
            NSArray *blacklist = [[object class] CrystDBBlacklistProperties];
            [_blacklistSet addObjectsFromArray:blacklist];
        }
        [[self classWithBlackOrWhitePropertiesDict] setObject:_blacklistSet forKey:className];
    }
    return _blacklistSet;
}

- (NSMutableSet *)_whitelist:(id)object{
    NSString *className = NSStringFromClass([object class]);
    _whitelistSet =  [[self classWithBlackOrWhitePropertiesDict] objectForKey:className];
    if (_whitelistSet == nil) {
        _whitelistSet = [NSMutableSet set];
        if ([[object class] respondsToSelector:@selector(CrystDBWhitelistProperties)]) {
            NSArray *whitelist = [[object class] CrystDBWhitelistProperties];
            [_whitelistSet addObjectsFromArray:whitelist];
        }
        [[self classWithBlackOrWhitePropertiesDict] setObject:_whitelistSet forKey:className];
    }
    return _whitelistSet;
}

- (NSMutableDictionary *)classWithBlackOrWhitePropertiesDict{
    if (_classWithBlackOrWhitePropertiesDict == nil) {
        _classWithBlackOrWhitePropertiesDict = [NSMutableDictionary dictionary];
    }
    return _classWithBlackOrWhitePropertiesDict;
}

- (BOOL)_isAcceptPropertyWithObject:(id)object propertyName:(NSString *)propertyName{
    if ([[object class] respondsToSelector:@selector(CrystDBWhitelistProperties)]) {// white list
        if([[self _whitelist:object] containsObject:propertyName]){
            // go through
        }else{
            return NO;
        }
    }else{   // black list
        if ([[self _blacklist:object] containsObject:propertyName]) {
            return NO;
        }else{
            // go through
        }
    }
    return YES;
}

#pragma mark sqlite method
- (BOOL)_updateDataToTable:(id)object{
    /// 0. init
    NSString *tableName = [self _tableNameWithObject:object];
    NSString *primaryKey = [self _primaryKeyWithObject:object];
    id keyValue = nil;
    if (!primaryKey && primaryKey.length == 0) {
        return NO;
    }
    NSInteger count = _propAttrValueOfObjectArray.count;
    
    /// 1. Generate the sql sentence
    NSMutableString *mutableSql = [NSMutableString stringWithFormat:@"update '%@' set object_id=:object_id,",tableName];
    for (NSInteger i = 0; i < count; i ++) {
        NSDictionary *dict = [_propAttrValueOfObjectArray objectAtIndex:i];
        if ([dict[@"prop"] isEqualToString:primaryKey]) { // skip the primary key
            keyValue = [object valueForKey:primaryKey];
            continue;
        }
        [mutableSql appendFormat:@"%@=:%@,",dict[@"prop"],dict[@"prop"]];
    }
    [mutableSql appendString:[NSString stringWithFormat:@" modification_time=:modification_time, last_access_time=:last_access_time where %@=:%@ ;",primaryKey,primaryKey]];
    sqlite3_stmt *pStmt =  [self __prepareStmt:mutableSql];
    
    /// 2. bind column params
    int queryCount = sqlite3_bind_parameter_count(pStmt);
    int idx = 0;
    for (NSDictionary *dict in _propAttrValueOfObjectArray) {
        // Prefix the key with a colon.
        NSString *parameterName = [[NSString alloc] initWithFormat:@":%@", dict[@"prop"]];
        // Get the index for the parameter name.
        int namedIdx = sqlite3_bind_parameter_index(pStmt, [parameterName UTF8String]);
        if (namedIdx > 0) {
            // Standard binding from here.
            [self __bindObject:dict[@"value"] toColumn:namedIdx inStatement:pStmt];
            // increment the binding count, so our check below works out
            idx++;
        }
        else {
            if(self.isDebug) CSLog(@"Could not find index for %@", parameterName);
        }
    }
    int  object_Idx = sqlite3_bind_parameter_index(pStmt, [@":object_id" UTF8String]);
    int  modification_time_Idx = sqlite3_bind_parameter_index(pStmt, [@":modification_time" UTF8String]);
    int  last_access_time_Idx = sqlite3_bind_parameter_index(pStmt, [@":last_access_time" UTF8String]);
    [self __bindObject:[self objectID:object] toColumn:object_Idx inStatement:pStmt];
    [self __bindObject:@((NSInteger)time(NULL)) toColumn:modification_time_Idx inStatement:pStmt];
    [self __bindObject:@((NSInteger)time(NULL)) toColumn:last_access_time_Idx inStatement:pStmt];
    if (idx != queryCount - 3) {
        if(self.isDebug) CSLog(@"Error -> \n%@",mutableSql);
        sqlite3_finalize(pStmt);
        return NO;
    }
    /// 3.excute sql
    int rc   = sqlite3_step(pStmt);
    if (SQLITE_DONE == rc && _isBindToObject) {
        [self _pushNotificationWithObject:object];
    }
    sqlite3_finalize(pStmt);
    return rc == SQLITE_DONE;
}

- (BOOL)_dbUpdateAccessTimeWithObject_ids:(NSArray *)objectIds inTable:(NSString *)tableName{
    if (!objectIds || objectIds.count == 0) {
        return YES;
    }
    int t = (int)time(NULL);
    NSString *sql = [NSString stringWithFormat:@"update '%@' set last_access_time = %d where object_id in (%@);",tableName, t, [self _dbJoinedKeys:objectIds]];
    sqlite3_stmt *stmt = [self __prepareStmt:sql];;
    if (!stmt) return NO;
    [self _dbBindJoinedKeys:objectIds stmt:stmt fromIndex:1];
    int result = sqlite3_step(stmt);
    sqlite3_finalize(stmt);
    if (result != SQLITE_DONE) {     // error
        return NO;
    }
    return YES;
}

- (NSString *)_dbJoinedKeys:(NSArray *)keys {
    NSMutableString *string = [NSMutableString new];
    for (NSUInteger i = 0,max = keys.count; i < max; i++) {
        [string appendString:@"?"];
        if (i + 1 != max) {
            [string appendString:@","];
        }
    }
    return string;
}

- (void)_dbBindJoinedKeys:(NSArray *)keys stmt:(sqlite3_stmt *)stmt fromIndex:(int)index{
    for (int i = 0, max = (int)keys.count; i < max; i++) {
        NSString *key = keys[i];
        sqlite3_bind_text(stmt, index + i, key.UTF8String, -1, NULL);
    }
}
- (NSMutableDictionary *)_columnNameToIndexMapWithStatement:(sqlite3_stmt*)stmt{
    int columnCount = sqlite3_column_count(stmt);
    if (_columnNameToIndexMap == nil) {
        _columnNameToIndexMap = [[NSMutableDictionary alloc] initWithCapacity:(NSUInteger)columnCount];
    }else{
        [_columnNameToIndexMap removeAllObjects];
    }
    int columnIdx = 0;
    for (columnIdx = 0; columnIdx < columnCount; columnIdx++) {
        [_columnNameToIndexMap setObject:[[NSString stringWithUTF8String:sqlite3_column_name(stmt, columnIdx)] lowercaseString]
                                  forKey:[NSNumber numberWithInt:columnIdx]];
    }
    return _columnNameToIndexMap;
}

/** create the unique table name **/
- (NSString*)_tableNameWithObject:(id)object{
    return [self _tableNameWithClass:[object class]];
}

- (NSString*)_tableNameWithClass:(Class)class{
    NSString *tableName = [[self classFingerPrintDict] objectForKey:NSStringFromClass(class)];
    if (tableName == nil) {
        NSString *objectFingerPrint = [NSString stringWithFormat:@"%@%@",[self _classFingerPrint:class],[self _protocolFingerPrint:class]];
        tableName =  [NSString stringWithFormat:@"%@_%@_%@",kCrystDBPrefix,[NSStringFromClass(class) lowercaseString],[self _md5:objectFingerPrint]];
        [[self classFingerPrintDict] setObject:tableName forKey:NSStringFromClass(class)];
    }
    return tableName;
}

- (NSString *)_classFingerPrint:(Class)class{
    unsigned int numIvars;
    Ivar *vars = class_copyIvarList(class, &numIvars);
    NSMutableString *var_params_string = [NSMutableString stringWithFormat:@"class=%@:",NSStringFromClass(class)];
    for(int i = 0; i < numIvars; i++) {
        Ivar thisIvar = vars[i];
        [var_params_string appendFormat:@"%@", [NSString stringWithUTF8String:ivar_getName(thisIvar)]];
        if (i == numIvars - 1) {
            [var_params_string appendFormat:@"%@",[NSString stringWithUTF8String:ivar_getTypeEncoding(thisIvar)]];
        }else{
            [var_params_string appendFormat:@"%@,",[NSString stringWithUTF8String:ivar_getTypeEncoding(thisIvar)]];
        }
    }
    free(vars);
    return var_params_string;
}

- (NSString *)_protocolFingerPrint:(Class)class{
    id object = [[class alloc] init];
    NSMutableString *protocolTypeStr = [NSMutableString string];
    // 1. is contain the super class proerties
    BOOL isCompriseSuperClass = NO;
    if ([[object class] respondsToSelector:@selector(CrystDBObjectIsHasSuperClass)]) {
        isCompriseSuperClass  = [[object class] CrystDBObjectIsHasSuperClass];
    }
    [protocolTypeStr appendFormat:@"isCompriseSuperClass=%d",isCompriseSuperClass];
    // 2. whether have primary key
    if ([[object class] respondsToSelector:@selector(CrystDBPrimaryKey)]) {
        NSString *primaryKey =  [[object class] CrystDBPrimaryKey];
        [protocolTypeStr appendFormat:@"CrystPrimaryKey=%@",primaryKey];
    }else{
        [protocolTypeStr appendFormat:@"CrystPrimaryKey=%@",@"object_id"]; // defalut primary key is object_id
    }
    // 3. whether have white list
    if ([[object class] respondsToSelector:@selector(CrystDBWhitelistProperties)]) {
        NSArray *whitelist = [[object class] CrystDBWhitelistProperties];
        [protocolTypeStr appendFormat:@"CrystWhitelistProperties=%@",whitelist];
    }
    // 4. whether have black list
    if ([[object class] respondsToSelector:@selector(CrystDBBlacklistProperties)]) {
        NSArray *blacklist = [[object class] CrystDBBlacklistProperties];
        [protocolTypeStr appendFormat:@"CrystBlacklistProperties=%@",blacklist];
    }
    return protocolTypeStr;
}

- (NSDictionary *)_keysLowerCaseInClass:(Class)class{
    NSMutableDictionary *keys = [NSMutableDictionary dictionary];
    unsigned int count;
    objc_property_t *properties = class_copyPropertyList(class,&count);
    
    for (int i = 0; i < count ; i++) {
        objc_property_t property = properties[i];
        const char *cName = property_getName(property);
        NSString *name = [NSString stringWithCString:cName encoding:NSUTF8StringEncoding];
        [keys setObject:name forKey:[name lowercaseString]];
    }
    free(properties);
    return keys;
}

- (NSString *)_md5:(NSString*)string{
    const char* original_str = [string UTF8String];
    unsigned char digist[CC_MD5_DIGEST_LENGTH]; //CC_MD5_DIGEST_LENGTH = 16
    CC_MD5(original_str, (uint)strlen(original_str), digist);
    NSMutableString* outPutStr = [NSMutableString stringWithCapacity:10];
    for(int  i = 0; i < CC_MD5_DIGEST_LENGTH; i++){
        [outPutStr appendFormat:@"%02x", digist[i]];
    }
    return [outPutStr lowercaseString];
}

- (void)_pushNotificationWithObject:(id)object{
    if (object == nil) return;
    NSString *notificationName = [self objectNotificationName:object];
    [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:object];
    if(self.isDebug) CSLog(@"send Cryst notification : %@",notificationName);
}

- (NSArray *)getProperties:(id)object{
    Class objectClass = object_getClass(object);
    unsigned int count;
    objc_property_t *properties = class_copyPropertyList(objectClass,&count);
    NSMutableArray *_prop_array = [NSMutableArray array];
    for (int i = 0; i < count ; i++) {
        objc_property_t property = properties[i];
        const char *cName = property_getName(property);
        NSString *name = [NSString stringWithCString:cName encoding:NSUTF8StringEncoding];
        if (![@[@"hash",@"superclass",@"description",@"debugDescription"] containsObject:name]) {
            [_prop_array addObject:name];
        }
    }
    free(properties);
    return _prop_array;
}


- (NSMutableDictionary *)classFingerPrintDict{
    if (_classFingerPrintDict == nil) {
        _classFingerPrintDict = [NSMutableDictionary dictionary];
    }
    return _classFingerPrintDict;
}

- (NSMutableDictionary *)tbNameToPKeyMap{
    if (_tbNameToPKeyMap == nil) {
        _tbNameToPKeyMap = [NSMutableDictionary dictionary];
    }
    return _tbNameToPKeyMap;
}

- (NSString *)_parseModelTypeToSqliteType:(NSString *)attr{
    NSArray *attrArray = [attr componentsSeparatedByString:@"\""];
    if (attrArray.count == 1) {
        NSArray *subAttrs = [attr componentsSeparatedByString:@","];
        NSString *initial = subAttrs.firstObject;
        initial = [initial substringFromIndex:1];
        const char type = *initial.UTF8String;
        switch (type) {
            case 'B':
                return @"integer";
                break;
            case 'c':
            case 'C':
                return @"integer";
                break;
            case 's':
            case 'S':
            case 'i':
            case 'I':
            case 'l':
            case 'L':
            case 'q':
            case 'Q':
                return @"integer";
                break;
            case 'f':
                return @"float";
                break;
            case 'd':
            case 'D':
                return @"double";
                break;
            case '{':
                return @"blob";
                break;
            default:
                return @"text";
                break;
        }
    }else{
        Class classType = NSClassFromString(attrArray[1]);
        if (classType == [NSNumber class]) {
            return @"integer";
        }else if (classType == [NSString class]) {
            return @"text";
        }else if (classType == [NSData class]) {
            return @"blob";
        }else if (classType == [NSArray class]) {
            return @"blob";
        }else if (classType == [NSDictionary class]) {
            return @"blob";
        }else if (classType == [NSDate class]) {
            return @"blob";
        }else {
            return @"blob";
        }
    }/* end if*/
    return @"text";
}

#pragma sqlite
- (BOOL)__openWithPath:(NSString *)dbName{
    if (_db) return YES;
    
    sqlite3_shutdown();
    sqlite3_config(SQLITE_CONFIG_SERIALIZED);
    
    NSString *dbPath =  [[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:kCrystDBPrefix] stringByAppendingPathComponent:dbName];
    
    int result = sqlite3_open(dbPath.UTF8String, &_db);
    if (result == SQLITE_OK) {
        return YES;
    } else {
        _db = NULL;
        return NO;
    }
}
- (BOOL)__close {
    if (!_db) return YES;
    int  result = 0;
    BOOL retry = NO;
    BOOL finished = NO;
    do {
        retry = NO;
        result = sqlite3_close(_db);
        if (result == SQLITE_BUSY || result == SQLITE_LOCKED) {
            if (!finished) {
                finished = YES;
                sqlite3_stmt *stmt;
                while ((stmt = sqlite3_next_stmt(_db, nil)) != 0) {
                    sqlite3_finalize(stmt);
                    retry = YES;
                }
            }
        } else if (result != SQLITE_OK) {
            // error
        }
    } while (retry);
    _db = NULL;
    return YES;
}


- (BOOL)__dbCheck {
    if (!_db) return [self __openWithPath:_dbName];
    return YES;
}

- (void)__dbCheckpoint {
    if (![self __dbCheck]) return;
    sqlite3_wal_checkpoint(_db, NULL);
}

- (BOOL)__executeUpdate:(NSString *)sql {
    if (sql.length == 0) return NO;
    if (![self __dbCheck]) return NO;
    
    int result = 0;
    char *error = NULL;
    result = sqlite3_exec(_db, sql.UTF8String, NULL, NULL, &error);
    
    if (error) {
        if(self.isDebug) CSLog(@"%s \n %@",sqlite3_errmsg(_db),sql);
    }
    if(self.isDebug) CSLog(@"%s : %@",__func__,sql);
    
    return result == SQLITE_OK;
}


- (id)__objectForColumnIndex:(int)columnIdx withStatement:(sqlite3_stmt*)stmt{
    int columnType = sqlite3_column_type(stmt, columnIdx);
    
    id returnValue = nil;
    
    if (columnType == SQLITE_INTEGER) {
        returnValue = [NSNumber numberWithLongLong:sqlite3_column_int64(stmt, columnIdx)];
    }
    else if (columnType == SQLITE_FLOAT) {
        returnValue = [NSNumber numberWithDouble:sqlite3_column_double(stmt, columnIdx)];
    }
    else if (columnType == SQLITE_TEXT){
        const char *c = (const char *)sqlite3_column_text(stmt, columnIdx);
        if (!c) {
            returnValue = nil;
        }
        returnValue = [NSString stringWithUTF8String:c];
        
    }
    else if (columnType == SQLITE_BLOB) {
        if (sqlite3_column_type(stmt, columnIdx) == SQLITE_NULL || (columnIdx < 0)) {
            returnValue = nil;
        }
        const char *dataBuffer = sqlite3_column_blob(stmt, columnIdx);
        int dataSize = sqlite3_column_bytes(stmt, columnIdx);
        
        if (dataBuffer == NULL) {
            returnValue = nil;
        }
        NSData *data =  [NSData dataWithBytes:(const void *)dataBuffer length:(NSUInteger)dataSize];
        if([data length] > 0)   returnValue = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        
        
        if (returnValue == nil) { // block
            //   [data getBytes:&returnValue length:dataSize];
        }
    }
    else {
        if (sqlite3_column_type(stmt, columnIdx) == SQLITE_NULL || (columnIdx < 0)) {
            returnValue = nil;
        }
    }
    return returnValue;
}

- (sqlite3_stmt *)__prepareStmt:(NSString *)sql {
    if (![self __dbCheck] || sql.length == 0 ) return NULL;
    sqlite3_stmt *stmt = NULL;
    if (!stmt) {
        int result;
        
        @try {
            result = sqlite3_prepare_v2(_db, sql.UTF8String, -1, &stmt, NULL);
        } @catch (NSException *exception) {
            CSLog(@"%s %@",__func__,exception);
        } @finally {
            
        }
        
        if (result != SQLITE_OK) {
            return NULL;
        }
    } else {
        sqlite3_reset(stmt);
    }
    if(self.isDebug) CSLog(@"%s : %@",__func__,sql);
    return stmt;
}

- (BOOL)__nextWithError:(NSError **)outErr withStatement:(sqlite3_stmt*)stmt{
    int rc = sqlite3_step(stmt);
    if (SQLITE_BUSY == rc || SQLITE_LOCKED == rc) {
        if(self.isDebug) CSLog(@"Database busy");
        if (outErr) {
            // error
        }
    }
    if (rc != SQLITE_ROW) {
        sqlite3_reset(stmt);
        stmt = NULL;
    }
    return (rc == SQLITE_ROW);
}

- (void)__bindObject:(id)obj toColumn:(int)idx inStatement:(sqlite3_stmt*)pStmt {
    if ((!obj) || ((NSNull *)obj == [NSNull null])) {
        sqlite3_bind_null(pStmt, idx);
    }else if ([obj isKindOfClass:[NSData class]]) {
        const void *bytes = [obj bytes];
        if (!bytes) {
            bytes = "";
        }
        sqlite3_bind_blob(pStmt, idx, bytes, (int)[obj length], SQLITE_STATIC);
    }
    else if ([obj isKindOfClass:[NSDate class]]) {
        sqlite3_bind_double(pStmt, idx, [obj timeIntervalSince1970]);
    }
    else if ([obj isKindOfClass:[NSNumber class]]) {
        
        if (strcmp([obj objCType], @encode(char)) == 0) {
            sqlite3_bind_int(pStmt, idx, [obj charValue]);
        }
        else if (strcmp([obj objCType], @encode(unsigned char)) == 0) {
            sqlite3_bind_int(pStmt, idx, [obj unsignedCharValue]);
        }
        else if (strcmp([obj objCType], @encode(short)) == 0) {
            sqlite3_bind_int(pStmt, idx, [obj shortValue]);
        }
        else if (strcmp([obj objCType], @encode(unsigned short)) == 0) {
            sqlite3_bind_int(pStmt, idx, [obj unsignedShortValue]);
        }
        else if (strcmp([obj objCType], @encode(int)) == 0) {
            sqlite3_bind_int(pStmt, idx, [obj intValue]);
        }
        else if (strcmp([obj objCType], @encode(unsigned int)) == 0) {
            sqlite3_bind_int64(pStmt, idx, (long long)[obj unsignedIntValue]);
        }
        else if (strcmp([obj objCType], @encode(long)) == 0) {
            sqlite3_bind_int64(pStmt, idx, [obj longValue]);
        }
        else if (strcmp([obj objCType], @encode(unsigned long)) == 0) {
            sqlite3_bind_int64(pStmt, idx, (long long)[obj unsignedLongValue]);
        }
        else if (strcmp([obj objCType], @encode(long long)) == 0) {
            sqlite3_bind_int64(pStmt, idx, [obj longLongValue]);
        }
        else if (strcmp([obj objCType], @encode(unsigned long long)) == 0) {
            sqlite3_bind_int64(pStmt, idx, (long long)[obj unsignedLongLongValue]);
        }
        else if (strcmp([obj objCType], @encode(float)) == 0) {
            sqlite3_bind_double(pStmt, idx, [obj floatValue]);
        }
        else if (strcmp([obj objCType], @encode(double)) == 0) {
            sqlite3_bind_double(pStmt, idx, [obj doubleValue]);
        }
        else if (strcmp([obj objCType], @encode(BOOL)) == 0) {
            sqlite3_bind_int(pStmt, idx, ([obj boolValue] ? 1 : 0));
        }
        else {
            sqlite3_bind_text(pStmt, idx, [[obj description] UTF8String], -1, SQLITE_STATIC);
        }
    }
    else if ([obj isKindOfClass:[NSString class]]){
        sqlite3_bind_text(pStmt, idx, [[obj description] UTF8String], -1, SQLITE_STATIC);
    }else{
        
        if ([obj isKindOfClass:[NSData class]]) {
            const void *bytes = [obj bytes];
            if (!bytes) bytes = "";
            sqlite3_bind_blob(pStmt, idx, bytes, (int)[obj length], SQLITE_STATIC);
        }else{
            NSData *data = [NSData dataWithBytes:&obj length:sizeof(obj)]; // CGSize
            const void *bytes = [data bytes];
            if (!bytes) bytes = "";
            sqlite3_bind_blob(pStmt, idx, bytes, sizeof(obj), SQLITE_STATIC);
        }
    }
}

- (BOOL)__databaseExists{
    return _db != NULL;
}

- (int)__changes {
    int ret = sqlite3_changes(_db);
    return ret;
}

#pragma mark Transactions
- (BOOL)__rollback {
    BOOL b = [self __executeUpdate:@"rollback transaction"];
    if (b)  _inTransaction = NO;
    return b;
}

- (BOOL)__commit {
    BOOL b =  [self __executeUpdate:@"commit transaction"];
    if (b) _inTransaction = NO;
    return b;
}

- (BOOL)__beginDeferredTransaction {
    BOOL b = [self __executeUpdate:@"begin deferred transaction"];
    if (b) _inTransaction = YES;
    return b;
}

- (BOOL)__beginTransaction {
    BOOL b = [self __executeUpdate:@"begin exclusive transaction"];
    if (b)  _inTransaction = YES;
    return b;
}

- (BOOL)__isInTransaction {
    return _inTransaction;
}

@end

