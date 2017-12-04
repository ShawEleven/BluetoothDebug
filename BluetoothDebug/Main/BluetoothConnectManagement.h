//
//  BluetoothConnectManagement.h
//  BluetoothDebug
//
//  Created by Shaw on 2017/11/28.
//  Copyright © 2017年 JdHealth. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

#define NotificationForBluetoothPowerStateUpdate @"PowerStateUpdate"
#define NotificationForBluetoothConnectStateUpdate @"ConnectStateUpdate"
#define NotificationForBluetoothConnectTimeOut @"ConnectTimeOut"

#define NotificationForBluetoothPeripheralInfoReadFinished @"peripheralInfoReadFinished"
#define NotificationForBluetoothPeripheralNotifyStateUpdate @"peripheralNotifyStateUpdate"

#define DEVICE_CONNECT_TIMER_OUT 15 //timeout

@protocol  BLEConnectDelegate;

@interface BluetoothConnectManagement : NSObject
@property (nonatomic,assign) id<BLEConnectDelegate> delegate;
@property (nonatomic,strong) CBCentralManager *centralManager;
@property (nonatomic,strong) NSString *filter;
@property (nonatomic,strong) NSMutableDictionary *peripheralsDetailInfoDict;
@property (nonatomic,strong) NSMutableDictionary *peripheralsDetailLogsDict;
+(BluetoothConnectManagement *)shareInstance;
- (void)startScan;
- (void)stopScan;

- (void)connectPeripheral:(CBPeripheral *)peripheral;
- (void)cancelPeripheralConnection:(CBPeripheral *)peripheral;
- (void)cancelAllPeripherals;
@end


@protocol BLEConnectDelegate<NSObject>
- (void)didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI;
@end;
