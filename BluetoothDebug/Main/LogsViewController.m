//
//  LogsViewController.m
//  BluetoothDebug
//
//  Created by Shaw on 2017/11/28.
//  Copyright © 2017年 JdHealth. All rights reserved.
//

#import "LogsViewController.h"

@interface LogsViewController ()
@property (nonatomic,strong)UIScrollView *scrollView;
@property (nonatomic,strong)UILabel *contentLabel;
@property (nonatomic,strong)NSString *logsContent;
@end

@implementation LogsViewController
- (LogsViewController *)initWithContent:(NSString *)content {
    self = [super init];
    if (self) {
        self.title = @"Logs";
        _logsContent = [[NSString alloc]initWithString:content];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIBarButtonItem *backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:self action:@selector(back)];
    self.navigationItem.leftBarButtonItem = backBarButtonItem;
    
    UIBarButtonItem *pasteboardBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Copy" style:UIBarButtonItemStylePlain target:self action:@selector(copyTextToPasteboard)];
    self.navigationItem.rightBarButtonItem = pasteboardBarButtonItem;
    
    _scrollView = [[UIScrollView alloc] init];
    [self.view addSubview:_scrollView];
    _scrollView.frame = self.view.frame;
    [_scrollView setContentSize:CGSizeMake(CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame))];
    
    
    _contentLabel = [[UILabel alloc] init];
    [_contentLabel setNumberOfLines:0];
    [_contentLabel setFrame:CGRectMake(10, 0, CGRectGetWidth(self.view.frame)-20, CGRectGetHeight(self.view.frame))];
    [_contentLabel setText:_logsContent];
    [_contentLabel setTextColor:[UIColor blackColor]];
    [_contentLabel setFont:[UIFont systemFontOfSize:12]];
    [_scrollView addSubview:_contentLabel];
    
    NSInteger labelHeight = [self getLabelHeight:_contentLabel];
    
    if (labelHeight > CGRectGetHeight(self.view.frame)) {
        [_contentLabel setFrame:CGRectMake(10, 0, CGRectGetWidth(self.view.frame)-20, labelHeight)];
        [_scrollView setContentSize:CGSizeMake(CGRectGetWidth(self.view.frame), labelHeight)];
    }
    
    [_scrollView scrollsToTop];
    
    [self.view setBackgroundColor:[UIColor whiteColor]];
    
}

- (void)copyTextToPasteboard {
    UIPasteboard* pasteboard = [UIPasteboard generalPasteboard];
    [pasteboard setString:_logsContent];
    
    [SVProgressHUD showSuccessWithStatus:@"copy success"];
}

- (CGFloat)getLabelHeight:(UILabel*)label
{
    CGSize constraint = CGSizeMake(label.frame.size.width, CGFLOAT_MAX);
    CGSize size;
    
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    CGSize boundingBox = [label.text boundingRectWithSize:constraint
                                                  options:NSStringDrawingUsesLineFragmentOrigin
                                               attributes:@{NSFontAttributeName:label.font}
                                                  context:context].size;
    
    size = CGSizeMake(ceil(boundingBox.width), ceil(boundingBox.height));
    
    return size.height;
}

- (void)back {
    [self.navigationController popViewControllerAnimated:YES];
}


@end
