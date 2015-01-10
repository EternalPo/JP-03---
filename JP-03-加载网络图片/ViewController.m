//
//  ViewController.m
//  JP-03-加载网络图片
//
//  Created by soulPo on 15/1/10.
//  Copyright (c) 2015年 soulPo. All rights reserved.
//

#import "ViewController.h"
#import "JPAppInfo.h"
#import "JPAppCell.h"

@interface ViewController ()
/**
 *  模型数组
 */
@property (nonatomic, strong) NSArray *appInfos;

/**
 *  全局队列
 */
@property (nonatomic, strong) NSOperationQueue *opQueue;
/**
 *  操作缓存池
 */
@property (nonatomic, strong) NSMutableDictionary *operationCaches;
@end

@implementation ViewController

/**
 *  懒加载数组
 */
- (NSArray *)appInfos {
    if (_appInfos== nil) {
        // 读取plist
        NSURL *url = [[NSBundle mainBundle] URLForResource:@"apps.plist" withExtension:nil];
        
        NSArray *dictA = [NSArray arrayWithContentsOfURL:url];
        NSMutableArray *arrayM= [NSMutableArray arrayWithCapacity:dictA.count];
        // 遍历数组中的每个字典，转模型
        // 用代码块比forin 效率更高
        [dictA enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            // 字典转模型
            JPAppInfo *appInfo = [JPAppInfo appInfoWithDict:obj];
            // 添加模型到数组
            [arrayM addObject:appInfo];
        }];
        _appInfos = [arrayM copy]; // 用copy 能够实现可变转不可变，而且不会相影响

    }
    return _appInfos;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}
/**
 *  懒加载全局队列
 */
- (NSOperationQueue *)opQueue {
    if (_opQueue== nil) {
        _opQueue = [[NSOperationQueue alloc]init];
    }
    return _opQueue;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
/**
 *  懒加载操作缓存池
 */
- (NSMutableDictionary *)operationCaches {
    if (_operationCaches== nil) {
        _operationCaches = [NSMutableDictionary dictionary];
    }
    return _operationCaches;
}

#pragma mark - 数据源方法
/**
 *  加载cell
 
 设置cell的imageView的图片 
 第一种 -- 同步加载 在主线程中直接加载
 问题： 
    -1 如果网络线程较慢，会出现卡顿，不会执行
    -2 每次刷新一行都会在次下载图片  
 所以 ： 异步下载图片 
 第二种 -- 异步加载图片，在后台加载
 */

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.appInfos.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // 创建cell
    JPAppCell *cell = [JPAppCell appCellWithTableView:tableView];
    
    JPAppInfo *app = self.appInfos[indexPath.row];
    
    cell.textLabel.text = app.name;
    
    cell.detailTextLabel.text = app.download;
    // 设置图片
    /**
     *
      第二种 -- 异步加载图片，在后台加载
     问题：页面出现时，没有imageView显示 - 只有点击这一行的时候才会有图片 
     原因分析：因为是异步执行 是在另一个线程中，在主线程中已经返回了cell而在另一个线程中，图片还没有下载完成，那么，当图片下载完成的时候，显示出的cell中此时imageView的大小为空，当点击cell时，有应为这个cell是系统的cell所以会调用 layoutSubviews方法 重新布局cell的子控件的位子 所以在 用一个占位图 来先分配到一个位子
     */
    // 占位图
    /**
     *  
     问题 ：使用占位图的问题，当用户交互的时候 图片的尺寸会变小，因为之前的占位图的尺寸过大，当用户交互的时候，会从新布局子控件的位置和大小，会根据当前图片的大小来设置
     
     解决思路 ：因为是系统用的cell，所以自定一个cell设置cell的位子即可 
     
     问题：如果图片下载速度不一样，用户又来回滚动cell，可能出现"图片错行"的问题
     分析：
     每一次都在直接给cell的图像设置数值，而cell是变化的，可以重用的，不固定的！
     
     谁是固定的？每一行的模型是固定的！
     
     MVC 设计模式，C(控制器) 让 V(视图) 显示 M(模型)
     
     目前的实际情况，C 让 (不固定的)V 显示不固定的 图像，忽略模型
     解决，让模型添加一个新的属性image 
     解决办法：使用 MVC 来在图像下载结束后，刷新指定的行
     
     新的问题：如果某张下载速度非常慢，用户快速来回滚动表格，会造成下载操作会重复创建！
     直接的结果：用户网络流量的浪费！
     思路：创建下载操作前，首先检查缓冲池中有没有下载操作
        -如果有，等待下载完成，什么都不做
        -如果没有，创建下载操作
     问题：缓存池的选取（容器： 数组、字典、set）
     数组：有序 --》indexPath
     字典： key --》URL
     set： 无序
     取舍思考： 
     如果下载的图片中有两张相同的图片，那么
     如果用数组 分布在不同的行，还会多次下载
     如果用字典， 不用多次下载，因为下载路径相同
     

     */
    
    if (app.image != nil) {
        NSLog(@"没有下载图片");
        
        cell.imageView.image = app.image;
    } else {
        cell.imageView.image = [UIImage imageNamed:@"user_default"];
        
        // 判断下载操作是不是存在
        if (self.operationCaches[app.icon] != nil) {
            NSLog(@"正在玩命加载");
        } else {
            // 定义下载操作
            NSBlockOperation *download = [NSBlockOperation blockOperationWithBlock:^{
                // 耗时操作
                // 模拟0行下载非常慢
                if (indexPath.row == 0) {
                    NSLog(@"-----");
                    [NSThread sleepForTimeInterval:10.0];
                }
                
                // 加载网络图片
                NSURL *url = [NSURL URLWithString:app.icon];
                
                NSData *data = [NSData dataWithContentsOfURL:url];
                
                UIImage *image = [UIImage imageWithData:data];
                
                app.image = image;
                // 通知主线程 设置图片
                [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                    
                    //                cell.imageView.image = image;
                    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                }];
            }];
            
            // 添加操作到队列
            [self.opQueue addOperation:download];
            [self.operationCaches setObject:download forKey:app.icon];
        }
    }
    // 打印操作队列中的操作数
    NSLog(@"===> 操作数： %lu", (unsigned long)self.opQueue.operationCount);
    
    // 返回cell
    return cell;
    
}
@end
