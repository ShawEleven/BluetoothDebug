//
//  BluetoothConnectManagement.m
//  BluetoothDebug
//
//  Created by Shaw on 2017/11/28.
//  Copyright © 2017年 JdHealth. All rights reserved.
//

#import "BluetoothConnectManagement.h"

@interface BluetoothConnectManagement()<CBPeripheralDelegate,CBCentralManagerDelegate>
@property (nonatomic,strong) dispatch_queue_t connectQueue;
@property (nonatomic,strong) NSMutableArray *peripherals;
@end


@implementation BluetoothConnectManagement

static  BluetoothConnectManagement *_bluetoothConnect = nil;
+(BluetoothConnectManagement *)shareInstance{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!_bluetoothConnect) {
            _bluetoothConnect = [[self alloc] init];
            [_bluetoothConnect initwithPrivateMethod];
        }
    });
    return _bluetoothConnect;
}

- (void )initwithPrivateMethod {
    _connectQueue = dispatch_queue_create("BleConnect",DISPATCH_QUEUE_CONCURRENT);
    dispatch_set_target_queue(_connectQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH,0));
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:@{CBCentralManagerOptionShowPowerAlertKey:@(YES),  CBCentralManagerOptionRestoreIdentifierKey:@"BleConnectRestore"}];
    _peripherals = [[NSMutableArray alloc] init];
    _peripheralsDetailInfoDict = [[NSMutableDictionary alloc] init];
    _peripheralsDetailLogsDict = [[NSMutableDictionary alloc] init];
}

-(id)copyWithZone:(NSZone *)zone{
    return _bluetoothConnect;
}

-(id)mutableCopyWithZone:(NSZone *)zone{
    return _bluetoothConnect;
}


#pragma mark -
#pragma mark scan

#pragma mark- 设备连接 CBCentralManagerDelegate
#pragma mark required
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:NotificationForBluetoothPowerStateUpdate object:nil userInfo:@{@"state":@(central.state)}];
    });
}

#pragma mark optional
- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary<NSString *, id> *)dict {
    
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI {
    
    if ([peripheral.name isKindOfClass:[NSString class]] && peripheral.name.length > 0) {
        if (![_filter isKindOfClass:[NSString class]] || _filter.length == 0) {
            _filter = @"";
        }
        if ([peripheral.name hasPrefix:_filter] || [_filter isEqualToString:@""]) {
            if ([_delegate respondsToSelector:@selector(didDiscoverPeripheral:advertisementData:RSSI:)]) {
                [_delegate didDiscoverPeripheral:peripheral advertisementData:advertisementData RSSI:RSSI];
            }
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{
    
    if (![_peripherals containsObject:peripheral]) {
        [_peripherals addObject:peripheral];
        [peripheral setDelegate:self];
        [peripheral discoverServices:nil];//设置代理，读取服务
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:NotificationForBluetoothConnectStateUpdate object:nil userInfo:@{@"peripheral":peripheral}];
    });
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error{
    
    if ([_peripherals containsObject:peripheral]) {
        [_peripherals removeObject:peripheral];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:NotificationForBluetoothConnectStateUpdate object:nil userInfo:@{@"peripheral":peripheral}];
    });
}


- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error{
    
    if ([_peripherals containsObject:peripheral]) {
        [_peripherals removeObject:peripheral];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:NotificationForBluetoothConnectStateUpdate object:nil userInfo:@{@"peripheral":peripheral}];
    });
}

#pragma mark custom method
- (void)startScan{
    
    [_peripheralsDetailLogsDict removeAllObjects];
    [_peripheralsDetailInfoDict removeAllObjects];
    
    dispatch_async(_connectQueue, ^{
        if ([_centralManager respondsToSelector:@selector(isScanning)]) {
            if (![_centralManager isScanning]) {
                [_centralManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@(NO)}];
            }
        } else {
            [_centralManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@(NO)}];
        }
    });
}

- (void)stopScan {
    
    dispatch_async(_connectQueue, ^{
        if ([_centralManager respondsToSelector:@selector(isScanning)]) {
            if ([_centralManager isScanning]) {
                [_centralManager stopScan];
            }
        } else {
            [_centralManager stopScan];
        }
    });
}

- (void)connectPeripheral:(CBPeripheral *)peripheral {
    if (![peripheral isKindOfClass:[CBPeripheral class]]) {  return; }
    __weak typeof(self) weakSelf = self;
    
    dispatch_async(_connectQueue, ^{
        [_centralManager connectPeripheral:peripheral options: @{CBConnectPeripheralOptionNotifyOnConnectionKey:@(YES),
                                                                CBConnectPeripheralOptionNotifyOnDisconnectionKey:@(YES),
                                                                CBConnectPeripheralOptionNotifyOnNotificationKey:@(YES)}];
        //连接超时处理逻辑
        dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, DEVICE_CONNECT_TIMER_OUT * NSEC_PER_SEC);
        dispatch_after(delay, dispatch_get_main_queue(), ^{
            if (peripheral.state == CBPeripheralStateConnecting) {
                [[NSNotificationCenter defaultCenter] postNotificationName:NotificationForBluetoothConnectTimeOut object:nil userInfo:@{@"peripheral":peripheral}];
                [weakSelf cancelPeripheralConnection:peripheral];
            }
        });
    });
}

- (void)cancelPeripheralConnection:(CBPeripheral *)peripheral {
    
    dispatch_async(_connectQueue, ^{
        if (peripheral.state == CBPeripheralStateConnected || peripheral.state == CBPeripheralStateConnecting) {
            [_centralManager cancelPeripheralConnection:peripheral];
        }
    });
}

- (void)cancelAllPeripherals {
    dispatch_async(_connectQueue, ^{
        [_peripherals enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            CBPeripheral *peripheral = (CBPeripheral *)obj;
            if ([peripheral isKindOfClass:[CBPeripheral class]] && peripheral.state ==CBPeripheralStateConnected) {
                [_centralManager cancelPeripheralConnection:peripheral];
            }
        }];
    });
}

#pragma mark- 设备通讯 CBPeripheralDelegate
- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral NS_AVAILABLE(10_9, 6_0){}

- (void)peripheral:(CBPeripheral *)peripheral didModifyServices:(NSArray<CBService *> *)invalidatedServices NS_AVAILABLE(10_9, 7_0){}

- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(nullable NSError *)error NS_DEPRECATED(10_7, 10_13, 5_0, 8_0){}

- (void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(nullable NSError *)error NS_AVAILABLE(10_13, 8_0){}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(nullable NSError *)error{
    
    dispatch_async(_connectQueue, ^{
        if (peripheral.name.length > 0) {
            
            //record services info
            NSMutableDictionary *peripheralDict = [_peripheralsDetailInfoDict objectForKey:peripheral.name];
            if (![peripheralDict isKindOfClass:[NSMutableDictionary class]] || peripheralDict.allKeys.count == 0) {
                peripheralDict = [[NSMutableDictionary alloc] init];
            }
            NSMutableArray *serviceArr = [NSMutableArray array];
            for (CBService *service in peripheral.services) {
                [peripheral discoverCharacteristics:nil forService:service];
                [serviceArr addObject:service];
            }
            [peripheralDict setObject:serviceArr ? serviceArr :@[] forKey:@"services"];
            
            [_peripheralsDetailInfoDict setObject:peripheralDict ? peripheralDict :@{} forKey:peripheral.name];
        }
        
    });
}


- (void)peripheral:(CBPeripheral *)peripheral didDiscoverIncludedServicesForService:(CBService *)service error:(nullable NSError *)error{}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(nullable NSError *)error{
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(_connectQueue, ^{
        
        NSMutableDictionary *peripheralDict = [_peripheralsDetailInfoDict objectForKey:peripheral.name];
        if (![peripheralDict isKindOfClass:[NSMutableDictionary class]] || peripheralDict.allKeys.count == 0) {
            peripheralDict = [[NSMutableDictionary alloc] init];
        }
        
        NSMutableArray *characteristics = [NSMutableArray array];
        for (CBCharacteristic *characteristic in service.characteristics) {
            [peripheral readValueForCharacteristic:characteristic];
            [characteristics addObject:characteristic];
        }
        [peripheralDict setObject:characteristics ? characteristics :@[] forKey:@"characteristics"];

        
        for (CBCharacteristic *characteristic in service.characteristics) {
            [peripheral discoverDescriptorsForCharacteristic:characteristic];
        }

        [_peripheralsDetailInfoDict setObject:peripheralDict ? peripheralDict :@{} forKey:peripheral.name];
        
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:NotificationForBluetoothPeripheralInfoReadFinished object:nil userInfo:@{@"peripheral":peripheral}];
        });
    });
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error{
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(_connectQueue, ^{
        
        NSLog(@" characteristic.value:  %@  ",characteristic.value);
        
        if (peripheral.name.length > 0) {
            //record logs info
            NSMutableArray *logsArr = [_peripheralsDetailLogsDict objectForKey:peripheral.name];
            if (![logsArr isKindOfClass:[NSMutableArray class]] || logsArr.count == 0) {
                logsArr = [[NSMutableArray alloc] init];
            }
            
            if (logsArr.count >= 100) {
                [logsArr removeObjectAtIndex:logsArr.count-1];
            }
        
            [logsArr insertObject:[NSString stringWithFormat:@"%@  <%@>",[self getCurrentDateToString],convertDataToHex(characteristic.value)] atIndex:0];
            
            [_peripheralsDetailLogsDict setObject:logsArr ? logsArr : @[] forKey:peripheral.name];
        }
        
    });
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error{}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error{
    
    NSLog(@" didUpdateNotificationStateForCharacteristic:  %@  ",characteristic);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:NotificationForBluetoothPeripheralNotifyStateUpdate object:nil userInfo:@{@"peripheral":peripheral,@"state":@(characteristic.isNotifying)}];
    });
}


- (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error{
    
    dispatch_async(_connectQueue, ^{
        for (CBDescriptor *d in characteristic.descriptors) {
            [peripheral readValueForDescriptor:d];
        }
    });
}


- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(nullable NSError *)error{
    //    JDLog(@" didUpdateValueForDescriptor:  %@  ",descriptor);
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForDescriptor:(CBDescriptor *)descriptor error:(nullable NSError *)error {}

- (void)peripheralIsReadyToSendWriteWithoutResponse:(CBPeripheral *)peripheral {}

static inline char itoh(int i) {
    if (i > 9) return 'A' + (i - 10);
    return '0' + i;
}

NSString * convertDataToHex(NSData *data) {
    NSUInteger i, len;
    unsigned char *buf, *bytes;
    
    len = data.length;
    bytes = (unsigned char*)data.bytes;
    buf = malloc(len*2);
    
    for (i=0; i<len; i++) {
        buf[i*2] = itoh((bytes[i] >> 4) & 0xF);
        buf[i*2+1] = itoh(bytes[i] & 0xF);
    }
    
    return [[NSString alloc] initWithBytesNoCopy:buf
                                          length:len*2
                                        encoding:NSASCIIStringEncoding
                                    freeWhenDone:YES];
}

- (NSString *)getCurrentDateToString {
    //获取系统当前时间
    NSDate *currentDate = [NSDate date];
    //用于格式化NSDate对象
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    //设置格式：zzz表示时区
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
    //NSDate转NSString
    NSString *currentDateString = [dateFormatter stringFromDate:currentDate];
    //输出currentDateString
    return currentDateString;
}

@end
