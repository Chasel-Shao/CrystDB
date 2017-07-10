//
//  ViewController.m
//  Benchmark
//
//  Created by sweet on 2017/7/10.
//  Copyright © 2017年 chasel. All rights reserved.
//

#import "ViewController.h"
#import "CrystDB.h"
#import "Person.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    Person *p = [[Person alloc] init];
    p.uid = 123;
    p.name = @"Ares";
    
    CrystManager *db =[CrystManager defaultCrystDB];
    [db addOrUpdateObject:p];
    
    NSArray *array = [db queryWithClass:[Person class] condition:nil];
    NSLog(@"%@",array);
    
    
}



@end
