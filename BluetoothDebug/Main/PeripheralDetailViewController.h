//
//  PeripheralDetailViewController.h
//  BluetoothDebug
//
//  Created by Shaw on 2017/11/28.
//  Copyright © 2017年 JdHealth. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SVProgressHUD/SVProgressHUD.h>
#import "BluetoothConnectManagement.h"
#import "LogsViewController.h"


@interface PeripheralDetailViewController : UIViewController
- (PeripheralDetailViewController *)initWithPeripheral:(CBPeripheral *)peripheral;
@end
