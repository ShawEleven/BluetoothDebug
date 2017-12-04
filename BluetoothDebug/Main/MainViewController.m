//
//  MainViewController.m
//  BluetoothDebug
//
//  Created by Shaw on 2017/11/28.
//  Copyright © 2017年 JdHealth. All rights reserved.
//

#import "MainViewController.h"
#import "BluetoothConnectManagement.h"
#import "PeripheralDetailViewController.h"

@interface MainViewController ()<UIAlertViewDelegate,
                                BLEConnectDelegate,
                                UITableViewDelegate,
                                UITableViewDataSource>
@property (nonatomic,strong)UIAlertView *alertView;
@property (nonatomic,strong)UITableView *tableView;
@property (nonatomic,strong)NSMutableArray *deviceArr;
@property (nonatomic,strong)CBPeripheral *connectPeripheral;
@end

@implementation MainViewController

- (MainViewController *)init {
    self = [super init];
    if (self) {
        self.title = @"Ble Debug";
        
        _deviceArr = [[NSMutableArray alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationForBluetoothPowerState) name:NotificationForBluetoothPowerStateUpdate object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationForBluetoothConnectStateUpdate:) name:NotificationForBluetoothConnectStateUpdate object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationForBluetoothConnectTimeout:) name:NotificationForBluetoothConnectTimeOut object:nil];

    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.view setBackgroundColor:[UIColor whiteColor]];
    
    [SVProgressHUD setMaximumDismissTimeInterval:1.0];
    
    //filter btn
    UIBarButtonItem *leftBarButton1 = [[UIBarButtonItem alloc] initWithTitle:@"Filter" style:UIBarButtonItemStylePlain target:self action:@selector(filterSetting)];
    UIBarButtonItem *leftBarButton2 = [[UIBarButtonItem alloc] initWithTitle:@"Clear" style:UIBarButtonItemStylePlain target:self action:@selector(cancelAllConnect)];
    self.navigationItem.leftBarButtonItems = @[leftBarButton1,leftBarButton2];
    
    //search btn
    UIBarButtonItem *rightBarButton1 = [[UIBarButtonItem alloc] initWithTitle:@"Start" style:UIBarButtonItemStylePlain target:self action:@selector(startSearchDevice)];
    UIBarButtonItem *rightBarButton2 = [[UIBarButtonItem alloc] initWithTitle:@"Stop" style:UIBarButtonItemStylePlain target:self action:@selector(stopSearchDevice)];
    self.navigationItem.rightBarButtonItems = @[rightBarButton1,rightBarButton2];
    
    [BluetoothConnectManagement shareInstance].delegate  = self;
    
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    [self.view addSubview:_tableView];
    [_tableView setFrame:self.view.frame];
    
}

-(void)showBluetoothPowerOffAlert {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Tips" message:@"Bluetooth is power off" delegate:self cancelButtonTitle:@"Got it" otherButtonTitles:nil, nil];
    [self.view addSubview:alertView];
    [alertView show];
}

- (void)filterSetting {
    
    if (!_alertView) {
        _alertView = [[UIAlertView alloc] init];
        _alertView.delegate = self;
        [_alertView setAlertViewStyle:UIAlertViewStylePlainTextInput];
        [_alertView setTitle:@"Filter Setting"];
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
                
            } else {
                [textField setText:nil];
            }
        }
    }
    
}

- (void)startSearchDevice {
    
    BluetoothConnectManagement *bleConnect = [BluetoothConnectManagement shareInstance];
    if (bleConnect.centralManager.state != CBCentralManagerStatePoweredOn) {
        [self showBluetoothPowerOffAlert];
    } else {
        [_deviceArr removeAllObjects];
        [_tableView reloadData];
        [bleConnect startScan];
    }
}

- (void)stopSearchDevice {
    [[BluetoothConnectManagement shareInstance] stopScan];
}

- (void)cancelAllConnect {
    [[BluetoothConnectManagement shareInstance] cancelAllPeripherals];
}

#pragma mark notfication
- (void)notificationForBluetoothPowerState{
    if (self.view.window && self.isViewLoaded) {
        
        BluetoothConnectManagement *bleConnect = [BluetoothConnectManagement shareInstance];
        CBCentralManagerState state = (CBCentralManagerState)bleConnect.centralManager.state;
        
        if (state == CBCentralManagerStatePoweredOn) {
            [bleConnect startScan];
        } else {// show bluetooth power off alert
            [self showBluetoothPowerOffAlert];
        }
    }
}

- (void)notificationForBluetoothConnectStateUpdate:(NSNotification *)notification {
    NSDictionary *info = notification.userInfo;
    if ([info isKindOfClass:[NSDictionary class]]) {
        CBPeripheral *peripheral = info[@"peripheral"];
        if ([peripheral isEqual:_connectPeripheral] && [peripheral isKindOfClass:[CBPeripheral class]]) {
            if (peripheral.state == CBPeripheralStateConnected) {
                [SVProgressHUD showSuccessWithStatus:@"connect Success"];
                
                PeripheralDetailViewController *peripheralDetail = [[PeripheralDetailViewController alloc] initWithPeripheral:peripheral];
                [self.navigationController pushViewController:peripheralDetail animated:YES];
            }
        }
    }
}

-(void)notificationForBluetoothConnectTimeout:(NSNotification *)notification {
    NSDictionary *info = notification.userInfo;
    if ([info isKindOfClass:[NSDictionary class]]) {
        CBPeripheral *peripheral = info[@"peripheral"];
        if ([peripheral isEqual:_connectPeripheral]) {
            [SVProgressHUD showErrorWithStatus:@"connect failed"];
        }
    }
}

#pragma mark delegate
- (void)didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI {
    NSLog(@" find peripheral: %@  ",peripheral.name);
    if (![_deviceArr containsObject:peripheral]) {
        if (self.view.window && self.isViewLoaded) {
            [_deviceArr addObject:peripheral];
            [_tableView reloadData];
        }
    }
}


#pragma mark TableView
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return  1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _deviceArr.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 49.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"d"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"d"];
    }
    if (_deviceArr.count > indexPath.row) {
        CBPeripheral *peripheral = _deviceArr[indexPath.row];
        [cell.textLabel setText:peripheral.name];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (_deviceArr.count > indexPath.row) {
        _connectPeripheral = _deviceArr[indexPath.row];
        if ([_connectPeripheral isKindOfClass:[CBPeripheral class]]) {
            BluetoothConnectManagement *bleConnect = [BluetoothConnectManagement shareInstance];
            [bleConnect stopScan];
            
            [bleConnect connectPeripheral:_connectPeripheral];
            [SVProgressHUD showInfoWithStatus:@"connecting"];

        }
    }
}

@end
