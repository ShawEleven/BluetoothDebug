//
//  PeripheralDetailViewController.m
//  BluetoothDebug
//
//  Created by Shaw on 2017/11/28.
//  Copyright © 2017年 JdHealth. All rights reserved.
//

#import "PeripheralDetailViewController.h"


@interface PeripheralDetailViewController ()<UITableViewDelegate,UITableViewDataSource,UIAlertViewDelegate>
@property (nonatomic,strong)CBPeripheral *peripheral;
@property (nonatomic,strong)UITableView *tableView;
@property (nonatomic,strong)NSMutableArray *services;
@property (nonatomic,strong)NSMutableArray *characteristics;
@property (nonatomic,strong)CBCharacteristic *characteristic;
@property (nonatomic,strong)UIAlertView *alertView;
@property (nonatomic,strong)NSMutableArray *startBytesArr;//相对于2017-01-01的毫秒数／1000；开始时间戳，处理后的字节数组
@property (nonatomic,strong)NSString *dateByteStr;//相对于2017-01-01的毫秒数／1000；开始时间戳，处理后的字节数组
@property (nonatomic,strong)dispatch_queue_t sendCmdQueue;
@end

@implementation PeripheralDetailViewController

- (PeripheralDetailViewController *)initWithPeripheral:(CBPeripheral *)peripheral {
    self = [super init];
    if (self) {
        _peripheral = peripheral;
        self.title = ([peripheral.name isKindOfClass:[NSString class]] && peripheral.name.length > 0 ? peripheral.name : @"Peripheral Detail");
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationForPeripheralInfoReadFinished:) name:NotificationForBluetoothPeripheralInfoReadFinished object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationForPeripheralNotifyStateUpdate:) name:NotificationForBluetoothPeripheralNotifyStateUpdate object:nil];

        _services = [[NSMutableArray alloc] init];
        _characteristics = [[NSMutableArray alloc] init];
        _startBytesArr = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    UIBarButtonItem *backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"<<" style:UIBarButtonItemStylePlain target:self action:@selector(back)];
    self.navigationItem.leftBarButtonItem = backBarButtonItem;
    
    UIBarButtonItem *logsBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Logs" style:UIBarButtonItemStylePlain target:self action:@selector(showLogs)];
    self.navigationItem.rightBarButtonItems = @[logsBarButtonItem];
    
    [self.view setBackgroundColor:[UIColor whiteColor]];
    [SVProgressHUD showInfoWithStatus:@"Reading Peripheral detail..."];
 
    
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    [self.view addSubview:_tableView];
    [_tableView setFrame:self.view.frame];
    
    
    _sendCmdQueue = dispatch_queue_create("BleSendCmd",DISPATCH_QUEUE_CONCURRENT);
    dispatch_set_target_queue(_sendCmdQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0));
}

- (void)back {
    BluetoothConnectManagement *bleConnect = [BluetoothConnectManagement shareInstance];
    [bleConnect cancelPeripheralConnection:_peripheral];
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)showLogs {
    
    NSArray *logs = [[[BluetoothConnectManagement shareInstance] peripheralsDetailLogsDict] objectForKey:_peripheral.name];
    
    LogsViewController *logsViewController = [[LogsViewController alloc] initWithContent:[logs componentsJoinedByString:@"\n"]];
    [self.navigationController pushViewController:logsViewController animated:YES];
//    NSLog(@" logs:  %@ ",logs);
    
}

- (void)showSendDataInputView{
        if (!_alertView) {
        _alertView = [[UIAlertView alloc] init];
        _alertView.delegate = self;
        [_alertView setAlertViewStyle:UIAlertViewStylePlainTextInput];
        [_alertView setTitle:@"Send Data"];
        [_alertView addButtonWithTitle:@"cancel"];
        [_alertView addButtonWithTitle:@"confirm"];
    }
    [self.view addSubview:_alertView];
    [_alertView show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    
    UITextField *textField = [alertView textFieldAtIndex:0];
    if ([textField isKindOfClass:[UITextField class]]) {
        if (buttonIndex == 1){
            NSString *originalText = textField.text;
            NSString *filterStr = [originalText stringByReplacingOccurrencesOfString:@" " withString:@""];
            if (filterStr.length > 0) {
                [textField setText:originalText];
                BluetoothConnectManagement *bleConnect = [BluetoothConnectManagement shareInstance];
                bleConnect.filter = originalText;
                
                if ([_peripheral isKindOfClass:[CBPeripheral class]] && [_characteristic isKindOfClass:[CBCharacteristic class]]) {
                    
                    NSMutableData *commandToSend= [[NSMutableData alloc] init];
                    unsigned char whole_byte;
                    char byte_chars[3] = {'\0','\0','\0'};
                    int i;
                    for (i=0; i < [filterStr length]/2; i++) {
                        byte_chars[0] = [filterStr characterAtIndex:i*2];
                        byte_chars[1] = [filterStr characterAtIndex:i*2+1];
                        whole_byte = strtol(byte_chars, NULL, 16);
                        [commandToSend appendBytes:&whole_byte length:1];
                    }
                  
                    [self sendByteData:commandToSend];
                }
            } else {
                [textField setText:nil];
            }
        }
    }
}

- (void)sendByteData:(NSData *)bytes {
    
    dispatch_async(_sendCmdQueue, ^{
        if ([_peripheral isKindOfClass:[CBPeripheral class]] && [_characteristic isKindOfClass:[CBCharacteristic class]]) {
            [_peripheral writeValue:bytes forCharacteristic:_characteristic type:CBCharacteristicWriteWithResponse];
            [self insertCmdString:[self convertDataToHex:bytes]];
//            NSLog(@"  commandToSend:  %@ ",bytes);
        }
    });
}

- (void)insertCmdString:(NSString *)content {
    NSMutableArray *logsArr = [[[BluetoothConnectManagement shareInstance] peripheralsDetailLogsDict] objectForKey:_peripheral.name];
    if ([logsArr isKindOfClass:[NSMutableArray class]]) {
        [logsArr insertObject:[NSString stringWithFormat:@"%@  <%@>",[self getCurrentDateToString],content] atIndex:0];
    }
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

#pragma mark -
#pragma mark - notitication
- (void)notificationForPeripheralInfoReadFinished:(NSNotification *)notification {
    NSDictionary *info = notification.userInfo;
    if ([info isKindOfClass:[NSDictionary class]]) {
        CBPeripheral *peripheral = info[@"peripheral"];
        if ([peripheral isEqual:_peripheral]) { //reload tableview
            
            [_services removeAllObjects];
            [_characteristics removeAllObjects];
            
            NSMutableDictionary *peripheralDict = [[[BluetoothConnectManagement shareInstance] peripheralsDetailInfoDict] objectForKey:_peripheral.name];
            
            [_services addObjectsFromArray:peripheralDict[@"services"]];
            [_characteristics addObjectsFromArray:peripheralDict[@"characteristics"]];

            [_tableView reloadData];
        }
    }
}

- (void)notificationForPeripheralNotifyStateUpdate:(NSNotification *)notification {
    NSDictionary *info = notification.userInfo;
    if ([info isKindOfClass:[NSDictionary class]]) {
        CBPeripheral *peripheral = info[@"peripheral"];
        BOOL isNotify = [info[@"state"] boolValue];
        if ([peripheral isEqual:_peripheral]) { //reload tableview
            NSLog(@" notificationForPeripheralNotifyStateUpdate   ");
            
            [SVProgressHUD showInfoWithStatus:(isNotify ? @"notifying = Yes" : @"notifying = NO")];
            
            [_tableView reloadData];
        }
    }
}

#pragma mark -tableview
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger number = 0;
    if (section ==0) {
        number = _services.count;
    } else if (section == 1){
        number = _characteristics.count;
    }
    return number;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger height = 0;
    if (indexPath.section ==0) {
        height = 30.0f;
    } else if (indexPath.section == 1){
        height = 69.0f;
    }
    return height;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 30.0f;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *title = @"";
    if (section == 0) {
        title = ([_dateByteStr isKindOfClass:[NSString class]] && _dateByteStr.length > 0) ? [NSString stringWithFormat:@"services:  %@",_dateByteStr] : @"services";
    } else if (section == 1) {
        title = @"characteristics";
    }
    return title;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = nil;
    if (indexPath.section == 0) {
         cell = [tableView dequeueReusableCellWithIdentifier:@"s"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"s"];
            
        }
        CBService *service = _services[indexPath.row];
        [cell.textLabel setText:service.UUID.UUIDString];
        [cell.textLabel setFont:[UIFont systemFontOfSize:13]];
    } else if (indexPath.section == 1) {
         cell = [tableView dequeueReusableCellWithIdentifier:@"c"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"c"];
            
            NSInteger width = CGRectGetWidth(self.view.frame);
            
            UISwitch *switchButton = [[UISwitch alloc] init];
            [switchButton setFrame:CGRectMake(width - 70, 35, 70, 20)];
            [switchButton addTarget:self action:@selector(switchOnButtonTouchUpInside:) forControlEvents:UIControlEventValueChanged];
            switchButton.hidden = YES;
            [switchButton setTag:1000];
            [cell.contentView addSubview:switchButton];
            
            UIButton *writeButton = [[UIButton alloc] init];
            [writeButton setFrame:CGRectMake(width - 70, 35, 50, 30)];
            [writeButton.titleLabel setFont:[UIFont systemFontOfSize:12]];
            [writeButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
            [writeButton setTitle:@"write" forState:UIControlStateNormal];
            [writeButton addTarget:self action:@selector(writeButtonTouchUpInside:) forControlEvents:UIControlEventTouchUpInside];
            writeButton.layer.cornerRadius = 5;
            writeButton.hidden = YES;
            [writeButton setTag:10001];
            writeButton.layer.borderWidth = 1;
            writeButton.layer.borderColor = [[UIColor grayColor] CGColor];
            [cell.contentView addSubview:writeButton];
            
        }
        UISwitch *switchBtn = [cell.contentView viewWithTag:1000];
        UIButton *writeBtn = [cell.contentView viewWithTag:10001];
        
        CBCharacteristic *characteristic = _characteristics[indexPath.row];
        [cell.textLabel setText:characteristic.UUID.UUIDString];
        [cell.textLabel setFont:[UIFont systemFontOfSize:13]];
        
        NSMutableString *detailContent = [NSMutableString string];
        [detailContent appendString: @"properties: "];
        if (characteristic.properties & CBCharacteristicPropertyRead) {
            [detailContent appendString:@" read"];
        }
        
        if (characteristic.properties & CBCharacteristicPropertyWrite) {
            [detailContent appendString:@" write"];
        }
        
        if (characteristic.properties & CBCharacteristicPropertyNotify) {
            [detailContent appendString:@" notify"];
        }
        [cell.detailTextLabel setText:detailContent];
        
        if (!(characteristic.properties & CBCharacteristicPropertyRead) && !(characteristic.properties &CBCharacteristicPropertyNotify) ) {
            writeBtn.hidden = NO;
        } else {
            writeBtn.hidden = YES;
        }
        if (!(characteristic.properties & CBCharacteristicPropertyRead) && !(characteristic.properties &CBCharacteristicPropertyWrite) ) {
            switchBtn.hidden = NO;
            [switchBtn setOn:characteristic.isNotifying];
        } else {
            switchBtn.hidden = YES;
        }
    }
    return cell;
}

#pragma mark button event
- (void)switchOnButtonTouchUpInside:(UISwitch *)button {
    CGPoint buttonPosition = [button convertPoint:CGPointZero toView:self.tableView];
    NSIndexPath *indexPath = [_tableView indexPathForRowAtPoint:buttonPosition];
    if (indexPath.section == 1 && indexPath.row < _characteristics.count) {
        CBCharacteristic *characteristic = _characteristics[indexPath.row];
        if ([_peripheral isKindOfClass:[CBPeripheral class]] && [characteristic isKindOfClass:[CBCharacteristic class]]) {
            
            [_peripheral setNotifyValue:button.isOn forCharacteristic:characteristic];
        }
    }
}

- (void)writeButtonTouchUpInside:(UIButton *)button {
    CGPoint buttonPosition = [button convertPoint:CGPointZero toView:self.tableView];
    NSIndexPath *indexPath = [_tableView indexPathForRowAtPoint:buttonPosition];
    if (indexPath.section == 1 && indexPath.row < _characteristics.count) {
        CBCharacteristic *characteristic = _characteristics[indexPath.row];
        if ([_peripheral isKindOfClass:[CBPeripheral class]] && [characteristic isKindOfClass:[CBCharacteristic class]]) {

            _characteristic = characteristic;
            [self showSendDataInputView];
        }
    }
}

static inline char itoh(int i) {
    if (i > 9) return 'A' + (i - 10);
    return '0' + i;
}

- (NSString *)convertDataToHex:(NSData *)data{
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

@end
