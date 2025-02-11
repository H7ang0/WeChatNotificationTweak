#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "substrate.h"
#import "DynamicIslandSettingViewController.h"
#import <UserNotifications/UserNotifications.h>
#import <sys/sysctl.h>
#import "Tweak.h"
#import "DynamicIslandNotificationView.h"

// 添加微信相关类声明
@interface MMServiceCenter : NSObject
+ (instancetype)defaultCenter;
- (id)getService:(Class)serviceClass;
@end

@interface CContact : NSObject
@property(nonatomic, copy) NSString *m_nsUsrName;  // 原始wxid
@property(nonatomic, copy) NSString *m_nsNickName; // 昵称
@property(nonatomic, copy) NSString *m_nsAliasName; // 微信号
@end

@interface CContactMgr : NSObject
- (CContact *)getSelfContact;
- (CContact *)getContactByName:(NSString *)name;
@end

// 实现 getCurrentWindow 函数
UIWindow* getCurrentWindow(void) {
    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]] && 
                scene.activationState == UISceneActivationStateForegroundActive) {
                window = scene.windows.firstObject;
                for (UIWindow *w in scene.windows) {
                    if (w.isKeyWindow) {
                        window = w;
                        break;
                    }
                }
                break;
            }
        }
    }
    
    if (!window) {
        window = [UIApplication sharedApplication].delegate.window;
    }
    return window;
}

// 定义颜色
#define PINK_COLOR [UIColor colorWithRed:255/255.0 green:105/255.0 blue:180/255.0 alpha:1.0]
#define BG_COLOR [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull trait) { \
    if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) { \
        return [UIColor blackColor]; \
    } else { \
        return [UIColor colorWithRed:0.94 green:0.94 blue:0.96 alpha:1.0]; \
    } \
}]

#define CELL_BG_COLOR [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull trait) { \
    if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) { \
        return [UIColor colorWithRed:0.17 green:0.17 blue:0.18 alpha:1.0]; \
    } else { \
        return [UIColor whiteColor]; \
    } \
}]

#define TEXT_COLOR [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull trait) { \
    if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) { \
        return [UIColor whiteColor]; \
    } else { \
        return [UIColor blackColor]; \
    } \
}]

#define SECONDARY_TEXT_COLOR [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull trait) { \
    if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) { \
        return [UIColor colorWithWhite:0.6 alpha:1.0]; \
    } else { \
        return [UIColor grayColor]; \
    } \
}]

// 定义颜色常量
#define WC_SETTING_COLOR_BACKGROUND [UIColor colorWithRed:0.96 green:0.96 blue:0.96 alpha:1]
#define WC_SETTING_COLOR_CELL [UIColor whiteColor]
#define WC_SETTING_COLOR_TITLE [UIColor blackColor]
#define WC_SETTING_COLOR_DETAIL [UIColor grayColor]
#define WC_SETTING_COLOR_SEPARATOR [UIColor colorWithWhite:0.9 alpha:1]

#define SECTION_HEADER_COLOR [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull trait) { \
    if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) { \
        return [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0]; \
    } else { \
        return [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0]; \
    } \
}]

// 添加通知动画相关的常量
#define ANIMATION_DURATION 0.3
#define ANIMATION_SPRING_DAMPING 0.8
#define ANIMATION_INITIAL_VELOCITY 0.5
#define ANIMATION_SCALE_INITIAL 0.8
#define ANIMATION_SCALE_BOUNCE 1.05

// 添加应用状态相关的常量
#define APP_STATE_CHANGE_ANIMATION_DURATION 0.2

// 灵动岛尺寸常量
#define DYNAMIC_ISLAND_EXPANDED_WIDTH 350
#define DYNAMIC_ISLAND_EXPANDED_HEIGHT 90
#define DYNAMIC_ISLAND_COMPACT_WIDTH 250
#define DYNAMIC_ISLAND_COMPACT_HEIGHT 36
#define DYNAMIC_ISLAND_MINI_WIDTH 36
#define DYNAMIC_ISLAND_MINI_HEIGHT 36

// 内容布局常量
#define DYNAMIC_ISLAND_CORNER_RADIUS 18
#define DYNAMIC_ISLAND_CONTENT_PADDING 12
#define DYNAMIC_ISLAND_ICON_SIZE 32
#define DYNAMIC_ISLAND_TOP_MARGIN 11

// 动画常量
#define DYNAMIC_ISLAND_ANIMATION_DURATION 0.4
#define DYNAMIC_ISLAND_SPRING_DAMPING 0.7

@interface DynamicIslandSettingViewController () <UITableViewDelegate, UITableViewDataSource, UNUserNotificationCenterDelegate>
@property (nonatomic, strong) UISlider *positionSlider;
@property (nonatomic, strong) UILabel *positionLabel;
@property (nonatomic, strong) DynamicIslandNotificationView *previewView;
@property (nonatomic, strong) UISwitch *enableSwitch;
@property (nonatomic, strong) UISegmentedControl *styleSegmentedControl;
@property (nonatomic, copy) NSString *currentWxid;
@property (nonatomic, assign) BOOL isAuthorized;
@property (nonatomic, strong) NSMutableArray *notificationArray;  // 修改名称
@property (nonatomic, strong) dispatch_queue_t notificationQueue;
@property (nonatomic, strong) DynamicIslandNotificationView *currentNotificationView;
@property (nonatomic, assign) BOOL isShowingNotification;
@end

@implementation DynamicIslandSettingViewController

// 修改设备检测方法
+ (BOOL)isDynamicIslandDevice {
    return YES;  // 让所有设备都返回YES，以启用灵动岛效果
}

// 修改为类方法
+ (NSString *)getMachineModel {
    static dispatch_once_t one;
    static NSString *model;
    dispatch_once(&one, ^{
        size_t size;
        sysctlbyname("hw.machine", NULL, &size, NULL, 0);
        char *machine = malloc(size);
        sysctlbyname("hw.machine", machine, &size, NULL, 0);
        model = [NSString stringWithUTF8String:machine];
        free(machine);
    });
    return model;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 初始化通知队列
    self.notificationArray = [NSMutableArray array];
    self.notificationQueue = dispatch_queue_create("com.wechat.notification.queue", DISPATCH_QUEUE_SERIAL);
    
    // 注册通知观察者
    [self registerNotificationObservers];
    
    // 请求通知权限
    [self requestNotificationPermission];
    
    // 获取当前用户的wxid
    self.currentWxid = [self getCurrentWxid];
    
    // 验证授权
    [self checkAuthorization];
    
    self.title = @"灵动岛通知设置";
    
    // 设置背景色
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    }
    
    // 初始化设置项
    [self setupSettingItems];
    
    // 创建UI组件
    [self setupTableView];
    [self setupPreviewView];
    [self setupPositionSlider];
    
    // 移除重复的页脚设置，因为已经在 viewForFooterInSection 中处理了
    self.tableView.tableFooterView = nil;
}

// 获取当前用户的wxid
- (NSString *)getCurrentWxid {
    @try {
        // 获取服务中心
        MMServiceCenter *serviceCenter = [objc_getClass("MMServiceCenter") defaultCenter];
        // 获取联系人管理器 
        CContactMgr *contactMgr = [serviceCenter getService:objc_getClass("CContactMgr")];
        // 获取当前用户的 Contact 对象
        CContact *selfContact = [contactMgr getSelfContact];
        // 返回原始 wxid
        return selfContact.m_nsUsrName;
    } @catch (NSException *exception) {
        NSLog(@"[WeChatNotificationTweak] 获取wxid失败: %@", exception);
        // 如果获取失败,回退到使用 NSUserDefaults
        return [[NSUserDefaults standardUserDefaults] objectForKey:@"CurrentUserWxid"];
    }
}

// 验证授权
- (void)checkAuthorization {
    // 从远程服务器获取授权配置
    NSURL *url = [NSURL URLWithString:@"https://youkebing.com/auth.json"];
    NSURLSession *session = [NSURLSession sharedSession];
    
    [[session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isAuthorized = NO;
                [self showAuthorizationStatus];
            });
            return;
        }
        
        NSError *jsonError;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        
        if (jsonError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isAuthorized = NO;
                [self showAuthorizationStatus];
            });
            return;
        }
        
        // 检查授权列表
        NSArray *authorizedWxids = json[@"authorized_wxids"];
        NSArray *blacklistedWxids = json[@"blacklisted_wxids"];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([blacklistedWxids containsObject:self.currentWxid]) {
                self.isAuthorized = NO;
                [self showAlert:@"提示" message:@"您的账号已被拉黑，请卸载该插件"];
                return;
            }
            
            self.isAuthorized = [authorizedWxids containsObject:self.currentWxid];
            [self showAuthorizationStatus];
        });
    }] resume];
}

// 显示授权状态
- (void)showAuthorizationStatus {
    if (!self.isAuthorized) {
        self.enableSwitch.enabled = NO;
        [self showAlert:@"未授权" message:[NSString stringWithFormat:@"当前微信号(%@)未授权使用此插件", self.currentWxid]];
    }
}

- (void)setupSettingItems {
    NSMutableArray *displaySettings = [@[
        @{
            @"title": @"当前微信wxid",
            @"type": @"wxid",
            @"detail": self.currentWxid
        },
        @{
            @"title": @"授权状态",
            @"type": @"auth",
            @"detail": self.isAuthorized ? @"已授权" : @"未授权"
        },
        @{
            @"title": @"通知显示时长",
            @"type": @"duration",
            @"key": kDynamicIslandDuration
        },
        @{
            @"title": @"通知显示位置",
            @"type": @"position",
            @"key": kDynamicIslandPositionY,
            @"detail": @"调整通知显示位置"
        }
    ] mutableCopy];
    
    self.settingItems = @[
        @{
            @"title": @"基本设置",
            @"items": @[
                @{
                    @"title": @"2",
                    @"key": kDynamicIslandEnabled,
                    @"type": @"switch",
                    @"icon": @"bell.badge.fill"
                }
            ]
        },
        @{
            @"title": @"通知样式",
            @"items": @[
                @{
                    @"title": @"选择样式",
                    @"type": @"style",
                    @"options": @[
                        @{@"title": @"展开", @"style": @(DynamicIslandStyleExpanded)},
                        @{@"title": @"紧凑", @"style": @(DynamicIslandStyleCompact)},
                        @{@"title": @"最小", @"style": @(DynamicIslandStyleMini)}
                    ]
                }
            ]
        },
        @{
            @"title": @"显示设置",
            @"items": displaySettings
        },
        @{
            @"title": @"关于我们",
            @"items": @[
                @{
                    @"title": @"Telegram 交流组",
                    @"detail": @"点击加入讨论",
                    @"type": @"link",
                    @"action": @"joinTelegramGroup"
                }
            ]
        }
    ];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = BG_COLOR;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0;
    }
    
    [self.view addSubview:self.tableView];
}

- (void)setupPreviewView {
    self.previewView = [[DynamicIslandNotificationView alloc] init];
    self.previewView.titleLabel.text = @"预览效果";
    self.previewView.messageLabel.text = @"拖动下方滑块调整位置";
    self.previewView.alpha = 0.8;
    [self.view addSubview:self.previewView];
}

- (void)setupPositionSlider {
    // 创建滑块容器视图
    UIView *sliderContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 100)];
    sliderContainer.backgroundColor = [UIColor clearColor];
    
    // 创建滑块
    self.positionSlider = [[UISlider alloc] initWithFrame:CGRectMake(20, 50, self.view.bounds.size.width - 40, 30)];
    self.positionSlider.minimumValue = 20;  // 最小位置
    self.positionSlider.maximumValue = 100; // 最大位置
    self.positionSlider.value = [[[NSUserDefaults standardUserDefaults] objectForKey:kDynamicIslandPositionY] floatValue] ?: 44.0;
    [self.positionSlider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.positionSlider addTarget:self action:@selector(sliderTouchEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    
    // 创建位置标签
    self.positionLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 10, self.view.bounds.size.width - 40, 30)];
    self.positionLabel.text = [NSString stringWithFormat:@"当前位置: %.0f", self.positionSlider.value];
    self.positionLabel.textAlignment = NSTextAlignmentCenter;
    self.positionLabel.textColor = [UIColor grayColor];
    
    [sliderContainer addSubview:self.positionLabel];
    [sliderContainer addSubview:self.positionSlider];
    
    // 将滑块容器添加到表格的页脚
    self.tableView.tableFooterView = sliderContainer;
}

- (void)sliderValueChanged:(UISlider *)slider {
    // 更新预览视图位置
    CGPoint center = self.previewView.center;
    center.y = slider.value;
    self.previewView.center = center;
    
    // 更新位置标签
    self.positionLabel.text = [NSString stringWithFormat:@"当前位置: %.0f", slider.value];
}

- (void)sliderTouchEnded:(UISlider *)slider {
    // 保存位置设置
    [[NSUserDefaults standardUserDefaults] setFloat:slider.value forKey:kDynamicIslandPositionY];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 显示保存提示
    [self showToast:@"位置已保存"];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.settingItems.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.settingItems[section][@"items"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.settingItems[section][@"title"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.settingItems[indexPath.section][@"items"][indexPath.row];
    NSString *type = item[@"type"];
    
    if ([type isEqualToString:@"wxid"] || [type isEqualToString:@"auth"]) {
        static NSString *cellId = @"InfoCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        
        cell.textLabel.text = item[@"title"];
        cell.detailTextLabel.text = item[@"detail"];
        cell.textLabel.textColor = TEXT_COLOR;
        cell.detailTextLabel.textColor = SECONDARY_TEXT_COLOR;
        cell.backgroundColor = CELL_BG_COLOR;
        return cell;
    }
    
    UITableViewCell *cell = nil;
    
    if ([type isEqualToString:@"style"]) {
        static NSString *styleCell = @"StyleCell";
        cell = [tableView dequeueReusableCellWithIdentifier:styleCell];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:styleCell];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
            // 创建样式选择器
            UISegmentedControl *styleControl = [[UISegmentedControl alloc] initWithItems:@[@"展开", @"紧凑", @"最小"]];
            styleControl.frame = CGRectMake(15, 10, cell.contentView.bounds.size.width - 30, 35);
            
            // 获取保存的样式
            DynamicIslandStyle savedStyle = (DynamicIslandStyle)[[NSUserDefaults standardUserDefaults] integerForKey:kDynamicIslandStyle];
            switch (savedStyle) {
                case DynamicIslandStyleExpanded:
                    styleControl.selectedSegmentIndex = 0;
                    break;
                case DynamicIslandStyleCompact:
                    styleControl.selectedSegmentIndex = 1;
                    break;
                case DynamicIslandStyleMini:
                    styleControl.selectedSegmentIndex = 2;
                    break;
                default:
                    styleControl.selectedSegmentIndex = 0;
                    break;
            }
            
            [styleControl addTarget:self action:@selector(styleChanged:) forControlEvents:UIControlEventValueChanged];
            styleControl.tag = 1001;
            
            // 设置样式
            if (@available(iOS 13.0, *)) {
                styleControl.selectedSegmentTintColor = [UIColor systemBlueColor];
                [styleControl setTitleTextAttributes:@{NSForegroundColorAttributeName: TEXT_COLOR} forState:UIControlStateNormal];
                [styleControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateSelected];
            }
            
            [cell.contentView addSubview:styleControl];
            
            // 添加自动布局约束
            styleControl.translatesAutoresizingMaskIntoConstraints = NO;
            [NSLayoutConstraint activateConstraints:@[
                [styleControl.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:15],
                [styleControl.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-15],
                [styleControl.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:10],
                [styleControl.heightAnchor constraintEqualToConstant:35]
            ]];
        }
    } else if ([type isEqualToString:@"duration"]) {
        static NSString *durationCell = @"DurationCell";
        cell = [tableView dequeueReusableCellWithIdentifier:durationCell];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:durationCell];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
            // 创建滑块
            UISlider *durationSlider = [[UISlider alloc] init];
            durationSlider.minimumValue = 1.0;  // 最短1秒
            durationSlider.maximumValue = 10.0; // 最长10秒
            durationSlider.value = [[[NSUserDefaults standardUserDefaults] objectForKey:kDynamicIslandDuration] floatValue] ?: 3.0;
            [durationSlider addTarget:self action:@selector(durationSliderChanged:) forControlEvents:UIControlEventValueChanged];
            durationSlider.tag = 2001;
            
            // 创建数值标签
            UILabel *valueLabel = [[UILabel alloc] init];
            valueLabel.text = [NSString stringWithFormat:@"%.1fs", durationSlider.value];
            valueLabel.textAlignment = NSTextAlignmentRight;
            valueLabel.textColor = TEXT_COLOR;
            valueLabel.font = [UIFont systemFontOfSize:14];
            valueLabel.tag = 2002;
            
            [cell.contentView addSubview:durationSlider];
            [cell.contentView addSubview:valueLabel];
            
            // 添加自动布局约束
            durationSlider.translatesAutoresizingMaskIntoConstraints = NO;
            valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
            
            [NSLayoutConstraint activateConstraints:@[
                // 滑块左边缘与cell的titleLabel右边缘对齐（与开关位置对齐）
                [durationSlider.leadingAnchor constraintEqualToAnchor:cell.textLabel.trailingAnchor constant:15],
                [durationSlider.trailingAnchor constraintEqualToAnchor:valueLabel.leadingAnchor constant:-10],
                [durationSlider.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
                
                [valueLabel.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-15],
                [valueLabel.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
                [valueLabel.widthAnchor constraintEqualToConstant:50]
            ]];
        }
        
        cell.textLabel.text = item[@"title"];
        cell.textLabel.textColor = TEXT_COLOR;
        
    } else if ([type isEqualToString:@"position"]) {
        static NSString *positionCell = @"PositionCell";
        cell = [tableView dequeueReusableCellWithIdentifier:positionCell];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:positionCell];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
            // 创建滑块
            UISlider *positionSlider = [[UISlider alloc] init];
            positionSlider.minimumValue = 20;   // 最小位置
            positionSlider.maximumValue = 100;  // 最大位置
            positionSlider.value = [[[NSUserDefaults standardUserDefaults] objectForKey:kDynamicIslandPositionY] floatValue] ?: 44.0;
            [positionSlider addTarget:self action:@selector(positionSliderChanged:) forControlEvents:UIControlEventValueChanged];
            positionSlider.tag = 3001;
            
            // 创建数值标签
            UILabel *valueLabel = [[UILabel alloc] init];
            valueLabel.text = [NSString stringWithFormat:@"%dpx", (int)positionSlider.value];
            valueLabel.textAlignment = NSTextAlignmentRight;
            valueLabel.textColor = TEXT_COLOR;
            valueLabel.font = [UIFont systemFontOfSize:14];
            valueLabel.tag = 3002;
            
            [cell.contentView addSubview:positionSlider];
            [cell.contentView addSubview:valueLabel];
            
            // 添加自动布局约束
            positionSlider.translatesAutoresizingMaskIntoConstraints = NO;
            valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
            
            [NSLayoutConstraint activateConstraints:@[
                // 滑块左边缘与cell的titleLabel右边缘对齐（与开关位置对齐）
                [positionSlider.leadingAnchor constraintEqualToAnchor:cell.textLabel.trailingAnchor constant:15],
                [positionSlider.trailingAnchor constraintEqualToAnchor:valueLabel.leadingAnchor constant:-10],
                [positionSlider.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
                
                [valueLabel.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-15],
                [valueLabel.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
                [valueLabel.widthAnchor constraintEqualToConstant:50]
            ]];
        }
        
        cell.textLabel.text = item[@"title"];
        cell.textLabel.textColor = TEXT_COLOR;
        cell.detailTextLabel.text = item[@"detail"];
        cell.detailTextLabel.textColor = SECONDARY_TEXT_COLOR;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    } else {
        static NSString *cellId = @"Cell";
        cell = [tableView dequeueReusableCellWithIdentifier:cellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        
        cell.textLabel.text = item[@"title"];
        cell.textLabel.textColor = TEXT_COLOR;
        
        if ([type isEqualToString:@"switch"]) {
            UISwitch *switchView = [[UISwitch alloc] init];
            switchView.on = [[NSUserDefaults standardUserDefaults] boolForKey:item[@"key"]];
            [switchView addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = switchView;
        } else if ([type isEqualToString:@"link"]) {
            cell.detailTextLabel.text = item[@"detail"];
            cell.detailTextLabel.textColor = [UIColor systemBlueColor];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    }
    
    // 设置cell样式
    cell.backgroundColor = CELL_BG_COLOR;
    cell.layer.cornerRadius = 10;
    cell.clipsToBounds = YES;
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *item = self.settingItems[indexPath.section][@"items"][indexPath.row];
    if ([item[@"type"] isEqualToString:@"style"]) {
        // 检查必要参数
        NSNumber *styleValue = item[@"style"];
        if (!styleValue) {
            NSLog(@"[WeChatNotificationTweak] 样式值不能为空");
            return;
        }
        
        // 先显示预览
        [self showPreviewForStyle:[styleValue integerValue] withTitle:item[@"title"]];
        
        // 延迟更新选中状态，让用户先看到预览效果
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @try {
                // 更新选中状态
                NSMutableArray *sections = [self.settingItems mutableCopy];
                NSMutableDictionary *styleSection = [sections[1] mutableCopy];
                NSMutableArray *items = [styleSection[@"items"] mutableCopy];
                
                // 重置所有选中状态
                for (NSMutableDictionary *styleItem in items) {
                    [styleItem setObject:@NO forKey:@"selected"];
                }
                
                // 设置新的选中状态
                if (indexPath.row < items.count) {
                    NSMutableDictionary *selectedItem = [items[indexPath.row] mutableCopy];
                    [selectedItem setObject:@YES forKey:@"selected"];
                    items[indexPath.row] = selectedItem;
                }
                
                // 更新数据源
                styleSection[@"items"] = items;
                sections[1] = styleSection;
                self.settingItems = sections;
                
                // 保存样式设置
                [[NSUserDefaults standardUserDefaults] setInteger:[styleValue integerValue] 
                                                         forKey:kDynamicIslandStyle];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                // 刷新表格
                [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] 
                            withRowAnimation:UITableViewRowAnimationNone];
                
            } @catch (NSException *exception) {
                NSLog(@"[WeChatNotificationTweak] 更新样式失败: %@", exception);
                [self showToast:@"更新样式失败，请稍后重试"];
            }
        });
    } else if ([item[@"type"] isEqualToString:@"link"]) {
        NSString *action = item[@"action"];
        if ([action isEqualToString:@"joinTelegramGroup"]) {
            [self joinTelegramGroup];
        }
    }
}

// 修改预览方法
- (void)showPreviewForStyle:(DynamicIslandStyle)style withTitle:(NSString *)title {
    @try {
        if (![[NSUserDefaults standardUserDefaults] boolForKey:kDynamicIslandEnabled]) {
            [self showToast:@"请先启用灵动岛通知"];
            return;
        }

        // 创建预览视图
        DynamicIslandNotificationView *previewView = [[DynamicIslandNotificationView alloc] init];
        
        // 根据不同样式设置不同的内容和布局
        switch (style) {
            case DynamicIslandStyleExpanded: {
                // 展开样式 - 完整的通知内容
                previewView.frame = CGRectMake(0, 0, DYNAMIC_ISLAND_EXPANDED_WIDTH, DYNAMIC_ISLAND_EXPANDED_HEIGHT);
                previewView.center = CGPointMake([UIScreen mainScreen].bounds.size.width / 2, DYNAMIC_ISLAND_TOP_MARGIN + DYNAMIC_ISLAND_EXPANDED_HEIGHT / 2);
                previewView.layer.cornerRadius = DYNAMIC_ISLAND_CORNER_RADIUS;
                
                // 设置头像
                UIImage *avatar = [UIImage imageNamed:@"DefaultProfileHead_phone"];
                previewView.iconImageView.image = avatar;
                previewView.iconImageView.frame = CGRectMake(DYNAMIC_ISLAND_CONTENT_PADDING,
                                                           DYNAMIC_ISLAND_CONTENT_PADDING,
                                                           DYNAMIC_ISLAND_ICON_SIZE,
                                                           DYNAMIC_ISLAND_ICON_SIZE);
                
                // 设置标题和内容
                previewView.titleLabel.text = @"张三";
                previewView.titleLabel.hidden = NO;
                previewView.messageLabel.text = @"[图片] 今天天气真不错！这是一条展开样式的消息，可以显示更多内容。";
                previewView.messageLabel.hidden = NO;
                
                // 更新标签布局
                CGFloat contentX = CGRectGetMaxX(previewView.iconImageView.frame) + 12;
                CGFloat contentWidth = DYNAMIC_ISLAND_EXPANDED_WIDTH - contentX - 12;
                previewView.titleLabel.frame = CGRectMake(contentX, 16, contentWidth, 22);
                previewView.messageLabel.frame = CGRectMake(contentX, 42, contentWidth, 20);
                break;
            }
            
            case DynamicIslandStyleCompact: {
                // 紧凑样式 - 只显示头像和简短内容
                previewView.frame = CGRectMake(0, 0, DYNAMIC_ISLAND_COMPACT_WIDTH, DYNAMIC_ISLAND_COMPACT_HEIGHT);
                previewView.center = CGPointMake([UIScreen mainScreen].bounds.size.width / 2, DYNAMIC_ISLAND_TOP_MARGIN + DYNAMIC_ISLAND_COMPACT_HEIGHT / 2);
                previewView.layer.cornerRadius = DYNAMIC_ISLAND_COMPACT_HEIGHT / 2;
                
                // 设置头像
                UIImage *avatar = [UIImage imageNamed:@"DefaultProfileHead_phone"];
                previewView.iconImageView.image = avatar;
                previewView.iconImageView.frame = CGRectMake(DYNAMIC_ISLAND_CONTENT_PADDING,
                                                           (DYNAMIC_ISLAND_COMPACT_HEIGHT - DYNAMIC_ISLAND_ICON_SIZE) / 2,
                                                           DYNAMIC_ISLAND_ICON_SIZE,
                                                           DYNAMIC_ISLAND_ICON_SIZE);
                
                // 设置标题
                previewView.titleLabel.text = @"张三";
                previewView.titleLabel.hidden = NO;
                previewView.messageLabel.hidden = YES;
                
                // 更新标题布局
                CGFloat titleX = CGRectGetMaxX(previewView.iconImageView.frame) + 8;
                previewView.titleLabel.frame = CGRectMake(titleX,
                                                        (DYNAMIC_ISLAND_COMPACT_HEIGHT - 16) / 2,
                                                        DYNAMIC_ISLAND_COMPACT_WIDTH - titleX - 8,
                                                        16);
                break;
            }
            
            case DynamicIslandStyleMini: {
                // 迷你样式 - 只显示小图标
                previewView.frame = CGRectMake(0, 0, DYNAMIC_ISLAND_MINI_WIDTH, DYNAMIC_ISLAND_MINI_HEIGHT);
                previewView.center = CGPointMake([UIScreen mainScreen].bounds.size.width / 2, DYNAMIC_ISLAND_TOP_MARGIN + DYNAMIC_ISLAND_MINI_HEIGHT / 2);
                previewView.layer.cornerRadius = DYNAMIC_ISLAND_MINI_HEIGHT / 2;
                
                // 设置微信图标
                UIImage *wechatIcon = [UIImage imageNamed:@"AppIcon"];
                previewView.iconImageView.image = wechatIcon;
                
                // 居中显示图标
                CGFloat iconPadding = (DYNAMIC_ISLAND_MINI_HEIGHT - DYNAMIC_ISLAND_ICON_SIZE) / 2;
                previewView.iconImageView.frame = CGRectMake(iconPadding,
                                                           iconPadding,
                                                           DYNAMIC_ISLAND_ICON_SIZE,
                                                           DYNAMIC_ISLAND_ICON_SIZE);
                
                previewView.titleLabel.hidden = YES;
                previewView.messageLabel.hidden = YES;
                break;
            }
        }
        
        // 设置模糊效果
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.frame = previewView.bounds;
        blurView.layer.cornerRadius = previewView.layer.cornerRadius;
        blurView.clipsToBounds = YES;
        [previewView insertSubview:blurView atIndex:0];
        
        // 添加到当前窗口并显示动画
        UIWindow *window = [self getCurrentWindow];
        [window addSubview:previewView];
        
        // 添加显示动画
        previewView.alpha = 0;
        previewView.transform = CGAffineTransformMakeScale(0.5, 0.5);
        
        [UIView animateWithDuration:0.3 
                              delay:0 
             usingSpringWithDamping:0.8
              initialSpringVelocity:0.5 
                            options:UIViewAnimationOptionCurveEaseOut 
                         animations:^{
            previewView.alpha = 1;
            previewView.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            // 添加轻微的弹性效果
            [UIView animateWithDuration:0.15 animations:^{
                previewView.transform = CGAffineTransformMakeScale(1.02, 1.02);
            } completion:^(BOOL finished) {
                [UIView animateWithDuration:0.1 animations:^{
                    previewView.transform = CGAffineTransformIdentity;
                }];
            }];
            
            // 2秒后自动消失
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.3 
                                    delay:0 
                                  options:UIViewAnimationOptionCurveEaseIn 
                               animations:^{
                    previewView.alpha = 0;
                    previewView.transform = CGAffineTransformMakeScale(0.8, 0.8);
                } completion:^(BOOL finished) {
                    [previewView removeFromSuperview];
                }];
            });
        }];
        
        // 添加震动反馈
        if (@available(iOS 10.0, *)) {
            UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
            [generator prepare];
            [generator impactOccurred];
        }
        
    } @catch (NSException *exception) {
        NSLog(@"[WeChatNotificationTweak] 显示预览失败: %@", exception);
        [self showToast:@"预览失败，请稍后重试"];
    }
}

#pragma mark - Actions

- (void)switchChanged:(UISwitch *)sender {
    NSDictionary *item = self.settingItems[0][@"items"][sender.tag];
    NSString *key = item[@"key"];
    
    // 保存开关状态
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 打印日志确认设置已保存
    NSLog(@"[WeChatNotificationTweak] 设置已保存: %@ = %d", key, sender.isOn);
    
    if ([key isEqualToString:kDynamicIslandEnabled]) {
        if (sender.isOn) {
            [self checkNotificationPermission:sender];
            [self showToast:@"已开启灵动岛通知"];
            
            // 延迟显示重启提示
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" 
                                                                           message:@"请重启微信以完全应用更改"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
                
                [alert addAction:[UIAlertAction actionWithTitle:@"稍后重启"
                                                        style:UIAlertActionStyleCancel
                                                      handler:nil]];
                
                [alert addAction:[UIAlertAction actionWithTitle:@"立即重启"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
                    // 退出微信
                    exit(0);
                }]];
                
                [self presentViewController:alert animated:YES completion:nil];
            });
        } else {
            [self showToast:@"已关闭灵动岛通知"];
            
            // 延迟显示重启提示
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self showToast:@"请重启微信以完全应用更改"];
            });
        }
    }
}

#pragma mark - Helper Methods

- (void)checkNotificationPermission:(UISwitch *)sender {
    if (@available(iOS 10.0, *)) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (settings.authorizationStatus == UNAuthorizationStatusDenied) {
                    sender.on = NO;
                    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kDynamicIslandEnabled];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    
                    [self showAlert:@"需要通知权限" message:@"请在系统设置中允许微信发送通知，否则无法使用灵动岛通知功能"];
                }
            });
        }];
    }
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                     message:message
                                                              preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定"
                                                style:UIAlertActionStyleDefault
                                              handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.settingItems[indexPath.section][@"items"][indexPath.row];
    NSString *type = item[@"type"];
    
    if ([type isEqualToString:@"style"]) {
        return 55;
    } else if ([type isEqualToString:@"duration"]) {
        return 50;
    } else if ([type isEqualToString:@"position"]) {
        return 60;  // 增加高度以容纳说明文字
    }
    return 44;
}

// 替换原有的 followOfficialAccount 方法为 joinTelegramGroup
- (void)joinTelegramGroup {
    @try {
        NSURL *telegramURL = [NSURL URLWithString:@"https://t.me/HyanguChat"];
        
        if ([[UIApplication sharedApplication] canOpenURL:telegramURL]) {
            if (@available(iOS 10.0, *)) {
                [[UIApplication sharedApplication] openURL:telegramURL options:@{} completionHandler:nil];
            } else {
                [[UIApplication sharedApplication] openURL:telegramURL options:@{} completionHandler:nil];
            }
        } else {
            // 如果未安装 Telegram，显示提示
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"未安装 Telegram"
                                                                 message:@"请先安装 Telegram 后再加入交流组"
                                                          preferredStyle:UIAlertControllerStyleAlert];
            
            [alert addAction:[UIAlertAction actionWithTitle:@"取消"
                                                    style:UIAlertActionStyleCancel
                                                  handler:nil]];
            
            [alert addAction:[UIAlertAction actionWithTitle:@"去安装"
                                                    style:UIAlertActionStyleDefault
                                                  handler:^(UIAlertAction * _Nonnull action) {
                NSURL *appStoreURL = [NSURL URLWithString:@"https://apps.apple.com/app/telegram-messenger/id686449807"];
                if (@available(iOS 10.0, *)) {
                    [[UIApplication sharedApplication] openURL:appStoreURL options:@{} completionHandler:nil];
                } else {
                    [[UIApplication sharedApplication] openURL:appStoreURL options:@{} completionHandler:nil];
                }
            }]];
            
            [self presentViewController:alert animated:YES completion:nil];
        }
        
    } @catch (NSException *exception) {
        NSLog(@"[WeChatNotificationTweak] 打开 Telegram 链接失败: %@", exception);
        [self showToast:@"打开失败，请稍后重试"];
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (section == self.settingItems.count - 1) {  // 最后一个分组（免责声明）
        // 创建容器视图
        UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 180)];
        footerView.backgroundColor = [UIColor clearColor];
        
        // 创建标题标签
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 10, tableView.frame.size.width - 30, 20)];
        titleLabel.text = @"免责声明";
        titleLabel.font = [UIFont boldSystemFontOfSize:14];
        titleLabel.textColor = SECONDARY_TEXT_COLOR;
        [footerView addSubview:titleLabel];
        
        // 创建内容标签
        UILabel *disclaimerLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 35, tableView.frame.size.width - 30, 140)];
        disclaimerLabel.text = @"本插件仅供个人学习研究使用，是出于对灵动岛通知功能的兴趣而开发的，不能用于商业用途。使用本插件所产生的任何直接或间接问题（包括但不限于账号安全、系统稳定性、数据丢失等）均与开发者无关，后果由使用者自行承担。请勿对插件进行反编译、修改或二次打包。使用本插件时请遵守相关法律法规，不得用于任何违法用途。如不同意上述声明，请立即卸载本插件。继续使用则视为完全接受本免责声明的所有内容。感谢您的理解和支持，希望这个小插件能给您带来便利，祝您使用愉快！❤️";
        disclaimerLabel.numberOfLines = 0;
        disclaimerLabel.textColor = SECONDARY_TEXT_COLOR;
        disclaimerLabel.font = [UIFont systemFontOfSize:12];
        disclaimerLabel.textAlignment = NSTextAlignmentLeft;
        [footerView addSubview:disclaimerLabel];
        
        return footerView;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section == self.settingItems.count - 1) {
        return 180;  // 免责声明的高度
    }
    return 10;  // 其他分组的底部间距
}

// 修改 section header 样式
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 50)];
    headerView.backgroundColor = [UIColor clearColor];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 25, tableView.frame.size.width - 40, 20)];
    titleLabel.text = self.settingItems[section][@"title"];
    titleLabel.font = [UIFont systemFontOfSize:13];
    titleLabel.textColor = SECTION_HEADER_COLOR;
    [headerView addSubview:titleLabel];
    
    return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 50;  // 增加头部高度以提供更多空间
}

- (void)styleChanged:(UISegmentedControl *)sender {
    DynamicIslandStyle selectedStyle;
    switch (sender.selectedSegmentIndex) {
        case 0:
            selectedStyle = DynamicIslandStyleExpanded;
            break;
        case 1:
            selectedStyle = DynamicIslandStyleCompact;
            break;
        case 2:
            selectedStyle = DynamicIslandStyleMini;
            break;
        default:
            selectedStyle = DynamicIslandStyleExpanded;
            break;
    }
    
    [[NSUserDefaults standardUserDefaults] setInteger:selectedStyle forKey:kDynamicIslandStyle];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 显示提示
    NSString *styleName = @[@"展开", @"紧凑", @"最小"][sender.selectedSegmentIndex];
    [self showToast:[NSString stringWithFormat:@"已切换到%@样式", styleName]];
    
    // 显示预览
    [self showPreviewForStyle:selectedStyle withTitle:nil];
}

- (void)showToast:(NSString *)message {
    UIWindow *window = [self getCurrentWindow];
    
    UILabel *toastLabel = [[UILabel alloc] init];
    toastLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
    toastLabel.textColor = [UIColor whiteColor];
    toastLabel.textAlignment = NSTextAlignmentCenter;
    toastLabel.font = [UIFont systemFontOfSize:14];
    toastLabel.text = message;
    toastLabel.alpha = 0;
    toastLabel.layer.cornerRadius = 10;
    toastLabel.clipsToBounds = YES;
    
    // 计算大小
    CGSize textSize = [message boundingRectWithSize:CGSizeMake(280, CGFLOAT_MAX)
                                          options:NSStringDrawingUsesLineFragmentOrigin
                                       attributes:@{NSFontAttributeName: toastLabel.font}
                                          context:nil].size;
    
    CGFloat toastWidth = textSize.width + 40;
    CGFloat toastHeight = textSize.height + 20;
    toastLabel.frame = CGRectMake((window.frame.size.width - toastWidth) / 2,
                                 window.frame.size.height - toastHeight - 100,
                                 toastWidth,
                                 toastHeight);
    
    [window addSubview:toastLabel];
    
    [UIView animateWithDuration:0.3 animations:^{
        toastLabel.alpha = 1;
    } completion:^(BOOL finished) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.3 animations:^{
                toastLabel.alpha = 0;
            } completion:^(BOOL finished) {
                [toastLabel removeFromSuperview];
            }];
        });
    }];
}

// 添加获取窗口的辅助方法
- (UIWindow *)getCurrentWindow {
    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]] && 
                scene.activationState == UISceneActivationStateForegroundActive) {
                window = scene.windows.firstObject;
                for (UIWindow *w in scene.windows) {
                    if (w.isKeyWindow) {
                        window = w;
                        break;
                    }
                }
                break;
            }
        }
    }
    
    if (!window) {
        window = [UIApplication sharedApplication].delegate.window;
    }
    return window;
}

// 添加滑块事件处理方法
- (void)durationSliderChanged:(UISlider *)slider {
    UITableViewCell *cell = (UITableViewCell *)slider.superview.superview;
    UILabel *valueLabel = [cell.contentView viewWithTag:2002];
    valueLabel.text = [NSString stringWithFormat:@"%.1fs", slider.value];
    
    // 保存设置
    [[NSUserDefaults standardUserDefaults] setFloat:slider.value forKey:kDynamicIslandDuration];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)positionSliderChanged:(UISlider *)slider {
    UITableViewCell *cell = (UITableViewCell *)slider.superview.superview;
    UILabel *valueLabel = [cell.contentView viewWithTag:3002];
    valueLabel.text = [NSString stringWithFormat:@"%dpx", (int)slider.value];
    
    // 保存设置
    [[NSUserDefaults standardUserDefaults] setFloat:slider.value forKey:kDynamicIslandPositionY];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 更新预览视图位置
    [self updatePreviewPosition:slider.value];
}

- (void)updatePreviewPosition:(CGFloat)position {
    if (!self.previewView) {
        self.previewView = [[DynamicIslandNotificationView alloc] initWithTitle:@"预览效果" message:@"拖动下方滑块调整位置"];
        [self.view addSubview:self.previewView];
    }
    
    self.previewView.titleLabel.text = @"预览效果";
    self.previewView.messageLabel.text = @"拖动下方滑块调整位置";
    
    // 移除设备类型检查，让所有设备都能显示预览
    self.previewView.center = CGPointMake(self.previewView.center.x, position);
    [[NSUserDefaults standardUserDefaults] setFloat:position forKey:kDynamicIslandPositionY];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// 1. 添加前台通知处理
- (void)handleWeChatMessage:(NSNotification *)notification {
    @try {
        if (![[NSUserDefaults standardUserDefaults] boolForKey:kDynamicIslandEnabled]) {
            return;
        }
        
        // 将通知加入队列
        dispatch_async(self.notificationQueue, ^{
            [self.notificationArray addObject:notification];
            [self processNextNotification];
        });
    } @catch (NSException *exception) {
        NSLog(@"[WeChatNotificationTweak] 处理微信消息异常: %@", exception);
    }
}

- (void)processNextNotification {
    @try {
        if (self.isShowingNotification || self.notificationArray.count == 0) {
            return;
        }
        
        self.isShowingNotification = YES;
        NSNotification *notification = self.notificationArray.firstObject;
        [self.notificationArray removeObjectAtIndex:0];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showNotificationWithInfo:notification.userInfo];
        });
    } @catch (NSException *exception) {
        NSLog(@"[WeChatNotificationTweak] 处理通知队列异常: %@", exception);
        self.isShowingNotification = NO;
    }
}

// 2. 添加后台通知处理
- (void)handleBackgroundNotification:(UNNotification *)notification {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kDynamicIslandEnabled]) {
        return;
    }
    
    // 获取通知内容
    UNNotificationContent *content = notification.request.content;
    
    // 创建灵动岛通知
    DynamicIslandNotificationView *notificationView = [[DynamicIslandNotificationView alloc] init];
    notificationView.titleLabel.text = content.title;
    notificationView.messageLabel.text = content.body;
    
    // 获取当前设置的样式
    DynamicIslandStyle style = (DynamicIslandStyle)[[NSUserDefaults standardUserDefaults] integerForKey:kDynamicIslandStyle];
    
    // 配置通知样式
    [self configureNotificationView:notificationView withStyle:style];
    
    // 显示通知
    [self showNotificationView:notificationView];
}

// 3. 注册通知观察者
- (void)registerNotificationObservers {
    @try {
        // 注册前台消息通知
        [[NSNotificationCenter defaultCenter] addObserver:self
                                               selector:@selector(handleWeChatMessage:)
                                                   name:@"WeChat.Message.Received"
                                                 object:nil];
        
        // 注册应用状态变化通知
        [[NSNotificationCenter defaultCenter] addObserver:self
                                               selector:@selector(handleAppStateChange:)
                                                   name:UIApplicationDidBecomeActiveNotification
                                                 object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                               selector:@selector(handleAppStateChange:)
                                                   name:UIApplicationDidEnterBackgroundNotification
                                                 object:nil];
    } @catch (NSException *exception) {
        NSLog(@"[WeChatNotificationTweak] 注册通知观察者异常: %@", exception);
    }
}

// 4. 实现后台通知代理方法
- (void)userNotificationCenter:(UNUserNotificationCenter *)center 
       willPresentNotification:(UNNotification *)notification 
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    // 处理后台通知
    [self handleBackgroundNotification:notification];
    
    // 允许系统显示通知
    if (@available(iOS 14.0, *)) {
        completionHandler(UNNotificationPresentationOptionList | UNNotificationPresentationOptionBanner);
    } else {
        completionHandler(UNNotificationPresentationOptionList);
    }
}

- (void)requestNotificationPermission {
    @try {
        if (@available(iOS 10.0, *)) {
            UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
            [center requestAuthorizationWithOptions:(UNAuthorizationOptionBadge | UNAuthorizationOptionSound | UNAuthorizationOptionAlert)
                                  completionHandler:^(BOOL granted, NSError * _Nullable error) {
                if (error) {
                    NSLog(@"[WeChatNotificationTweak] 请求通知权限失败: %@", error);
                }
            }];
            center.delegate = self;
        }
    } @catch (NSException *exception) {
        NSLog(@"[WeChatNotificationTweak] 请求通知权限异常: %@", exception);
    }
}

- (void)showNotificationWithInfo:(NSDictionary *)info {
    @try {
        DynamicIslandStyle style = (DynamicIslandStyle)[[NSUserDefaults standardUserDefaults] integerForKey:kDynamicIslandStyle];
        DynamicIslandNotificationView *notificationView = [[DynamicIslandNotificationView alloc] init];
        
        // 配置通知视图
        [self configureNotificationView:notificationView withStyle:style];
        
        // 显示通知
        [self animateNotificationView:notificationView];
        
    } @catch (NSException *exception) {
        NSLog(@"[WeChatNotificationTweak] 显示通知异常: %@", exception);
        self.isShowingNotification = NO;
    }
}

- (void)configureNotificationView:(DynamicIslandNotificationView *)view withStyle:(DynamicIslandStyle)style {
    switch (style) {
        case DynamicIslandStyleExpanded:
            [self configureExpandedStyle:view withInfo:nil];
            break;
        case DynamicIslandStyleCompact:
            [self configureCompactStyle:view withInfo:nil];
            break;
        case DynamicIslandStyleMini:
            [self configureMiniStyle:view withInfo:nil];
            break;
    }
}

- (void)configureExpandedStyle:(DynamicIslandNotificationView *)view withInfo:(NSDictionary *)info {
    @try {
        // 展开样式 - 完整显示内容
        view.frame = CGRectMake(0, 0, DYNAMIC_ISLAND_EXPANDED_WIDTH, DYNAMIC_ISLAND_EXPANDED_HEIGHT);
        view.center = CGPointMake([UIScreen mainScreen].bounds.size.width / 2, 
                                DYNAMIC_ISLAND_TOP_MARGIN + DYNAMIC_ISLAND_EXPANDED_HEIGHT / 2);
        
        // 设置背景
        view.backgroundColor = [UIColor blackColor];
        view.layer.cornerRadius = DYNAMIC_ISLAND_CORNER_RADIUS;
        
        // 添加模糊效果
        if (!view.blurView) {
            UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
            UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
            blurView.frame = view.bounds;
            blurView.layer.cornerRadius = DYNAMIC_ISLAND_CORNER_RADIUS;
            blurView.clipsToBounds = YES;
            [view insertSubview:blurView atIndex:0];
            view.blurView = blurView;
        }
        
        // 配置头像
        view.iconImageView.frame = CGRectMake(DYNAMIC_ISLAND_CONTENT_PADDING, 
                                            DYNAMIC_ISLAND_CONTENT_PADDING,
                                            DYNAMIC_ISLAND_ICON_SIZE, 
                                            DYNAMIC_ISLAND_ICON_SIZE);
        view.iconImageView.layer.cornerRadius = DYNAMIC_ISLAND_ICON_SIZE / 2;
        view.iconImageView.clipsToBounds = YES;
        view.iconImageView.hidden = NO;
        
        // 配置标题
        CGFloat titleX = CGRectGetMaxX(view.iconImageView.frame) + 10;
        view.titleLabel.frame = CGRectMake(titleX,
                                         DYNAMIC_ISLAND_CONTENT_PADDING,
                                         view.frame.size.width - titleX - DYNAMIC_ISLAND_CONTENT_PADDING,
                                         20);
        view.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        view.titleLabel.textColor = [UIColor whiteColor];
        view.titleLabel.hidden = NO;
        
        // 配置消息内容
        view.messageLabel.frame = CGRectMake(titleX,
                                          CGRectGetMaxY(view.titleLabel.frame) + 4,
                                          view.frame.size.width - titleX - DYNAMIC_ISLAND_CONTENT_PADDING,
                                          36);
        view.messageLabel.font = [UIFont systemFontOfSize:13];
        view.messageLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.8];
        view.messageLabel.numberOfLines = 2;
        view.messageLabel.hidden = NO;
    } @catch (NSException *exception) {
        NSLog(@"[WeChatNotificationTweak] 配置展开样式异常: %@", exception);
    }
}

- (void)configureCompactStyle:(DynamicIslandNotificationView *)view withInfo:(NSDictionary *)info {
    @try {
        // 紧凑样式 - 显示头像和标题
        view.frame = CGRectMake(0, 0, DYNAMIC_ISLAND_COMPACT_WIDTH, DYNAMIC_ISLAND_COMPACT_HEIGHT);
        view.center = CGPointMake([UIScreen mainScreen].bounds.size.width / 2, 
                                DYNAMIC_ISLAND_TOP_MARGIN + DYNAMIC_ISLAND_COMPACT_HEIGHT / 2);
        
        // 设置背景
        view.backgroundColor = [UIColor blackColor];
        view.layer.cornerRadius = DYNAMIC_ISLAND_COMPACT_HEIGHT / 2;
        
        // 添加模糊效果
        if (!view.blurView) {
            UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
            UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
            blurView.frame = view.bounds;
            blurView.layer.cornerRadius = view.layer.cornerRadius;
            blurView.clipsToBounds = YES;
            [view insertSubview:blurView atIndex:0];
            view.blurView = blurView;
        }
        
        // 配置头像
        CGFloat iconY = (DYNAMIC_ISLAND_COMPACT_HEIGHT - DYNAMIC_ISLAND_ICON_SIZE) / 2;
        view.iconImageView.frame = CGRectMake(8, iconY, DYNAMIC_ISLAND_ICON_SIZE, DYNAMIC_ISLAND_ICON_SIZE);
        view.iconImageView.layer.cornerRadius = DYNAMIC_ISLAND_ICON_SIZE / 2;
        view.iconImageView.clipsToBounds = YES;
        view.iconImageView.hidden = NO;
        
        // 配置标题
        CGFloat titleX = CGRectGetMaxX(view.iconImageView.frame) + 8;
        view.titleLabel.frame = CGRectMake(titleX,
                                         0,
                                         view.frame.size.width - titleX - 12,
                                         DYNAMIC_ISLAND_COMPACT_HEIGHT);
        view.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        view.titleLabel.textColor = [UIColor whiteColor];
        view.titleLabel.hidden = NO;
        
        // 隐藏消息内容
        view.messageLabel.hidden = YES;
    } @catch (NSException *exception) {
        NSLog(@"[WeChatNotificationTweak] 配置紧凑样式异常: %@", exception);
    }
}

- (void)configureMiniStyle:(DynamicIslandNotificationView *)view withInfo:(NSDictionary *)info {
    @try {
        // 迷你样式 - 只显示小图标
        view.frame = CGRectMake(0, 0, DYNAMIC_ISLAND_MINI_WIDTH, DYNAMIC_ISLAND_MINI_HEIGHT);
        view.center = CGPointMake([UIScreen mainScreen].bounds.size.width / 2, 
                                DYNAMIC_ISLAND_TOP_MARGIN + DYNAMIC_ISLAND_MINI_HEIGHT / 2);
        
        // 设置背景
        view.backgroundColor = [UIColor blackColor];
        view.layer.cornerRadius = DYNAMIC_ISLAND_MINI_HEIGHT / 2;
        
        // 添加模糊效果
        if (!view.blurView) {
            UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
            UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
            blurView.frame = view.bounds;
            blurView.layer.cornerRadius = view.layer.cornerRadius;
            blurView.clipsToBounds = YES;
            [view insertSubview:blurView atIndex:0];
            view.blurView = blurView;
        }
        
        // 配置小图标
        CGFloat iconSize = 20;
        CGFloat iconY = (DYNAMIC_ISLAND_MINI_HEIGHT - iconSize) / 2;
        view.iconImageView.frame = CGRectMake((DYNAMIC_ISLAND_MINI_WIDTH - iconSize) / 2,
                                            iconY,
                                            iconSize,
                                            iconSize);
        view.iconImageView.layer.cornerRadius = iconSize / 2;
        view.iconImageView.clipsToBounds = YES;
        view.iconImageView.hidden = NO;
        
        // 使用微信图标
        view.iconImageView.image = [UIImage imageNamed:@"AppIcon"];
        
        // 隐藏文本
        view.titleLabel.hidden = YES;
        view.messageLabel.hidden = YES;
    } @catch (NSException *exception) {
        NSLog(@"[WeChatNotificationTweak] 配置迷你样式异常: %@", exception);
    }
}

- (void)animateNotificationView:(DynamicIslandNotificationView *)view {
    @try {
        // 移除当前显示的通知
        [self.currentNotificationView removeFromSuperview];
        
        // 设置新通知
        self.currentNotificationView = view;
        UIWindow *window = [self getCurrentWindow];
        [window addSubview:view];
        
        // 设置初始状态
        view.alpha = 0;
        view.transform = CGAffineTransformMakeScale(0.8, 0.8);
        
        // 主动画
        [UIView animateWithDuration:DYNAMIC_ISLAND_ANIMATION_DURATION 
                              delay:0 
             usingSpringWithDamping:DYNAMIC_ISLAND_SPRING_DAMPING
              initialSpringVelocity:0.5 
                            options:UIViewAnimationOptionCurveEaseOut 
                         animations:^{
            view.alpha = 1;
            view.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            // 添加轻微的弹性效果
            [UIView animateWithDuration:0.2 animations:^{
                view.transform = CGAffineTransformMakeScale(1.03, 1.03);
            } completion:^(BOOL finished) {
                [UIView animateWithDuration:0.1 animations:^{
                    view.transform = CGAffineTransformIdentity;
                }];
            }];
        }];
        
        // 添加震动反馈
        if (@available(iOS 10.0, *)) {
            UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] 
                initWithStyle:UIImpactFeedbackStyleMedium];
            [generator prepare];
            [generator impactOccurred];
        }
    } @catch (NSException *exception) {
        NSLog(@"[WeChatNotificationTweak] 通知动画异常: %@", exception);
        self.isShowingNotification = NO;
    }
}

// 处理通知点击事件
- (void)handleNotificationTap:(UITapGestureRecognizer *)gesture {
    @try {
        DynamicIslandNotificationView *view = (DynamicIslandNotificationView *)gesture.view;
        // 添加点击动画效果
        [UIView animateWithDuration:0.1 animations:^{
            view.transform = CGAffineTransformMakeScale(0.95, 0.95);
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.1 animations:^{
                view.transform = CGAffineTransformIdentity;
            } completion:^(BOOL finished) {
                [self dismissNotificationView:view];
            }];
        }];
        
        // 添加点击反馈
        if (@available(iOS 10.0, *)) {
            UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] 
                initWithStyle:UIImpactFeedbackStyleLight];
            [generator prepare];
            [generator impactOccurred];
        }
    } @catch (NSException *exception) {
        NSLog(@"[WeChatNotificationTweak] 处理通知点击异常: %@", exception);
    }
}

// 关闭通知动画
- (void)dismissNotificationView:(DynamicIslandNotificationView *)view {
    @try {
        [UIView animateWithDuration:ANIMATION_DURATION 
                              delay:0 
                            options:UIViewAnimationOptionCurveEaseIn 
                         animations:^{
            view.alpha = 0;
            view.transform = CGAffineTransformMakeScale(ANIMATION_SCALE_INITIAL, ANIMATION_SCALE_INITIAL);
        } completion:^(BOOL finished) {
            [view removeFromSuperview];
            if (view == self.currentNotificationView) {
                self.currentNotificationView = nil;
            }
            self.isShowingNotification = NO;
            
            // 处理下一个通知
            dispatch_async(self.notificationQueue, ^{
                [self processNextNotification];
            });
        }];
    } @catch (NSException *exception) {
        NSLog(@"[WeChatNotificationTweak] 关闭通知异常: %@", exception);
        self.isShowingNotification = NO;
    }
}

- (void)handleAppStateChange:(NSNotification *)notification {
    @try {
        if ([notification.name isEqualToString:UIApplicationDidEnterBackgroundNotification]) {
            // 1. 应用进入后台
            [self handleEnterBackground];
        } else if ([notification.name isEqualToString:UIApplicationDidBecomeActiveNotification]) {
            // 2. 应用进入前台
            [self handleBecomeActive];
        } else if ([notification.name isEqualToString:UIApplicationWillResignActiveNotification]) {
            // 3. 应用即将进入非活动状态
            [self handleWillResignActive];
        }
    } @catch (NSException *exception) {
        NSLog(@"[WeChatNotificationTweak] 处理应用状态变化异常: %@", exception);
    }
}

- (void)handleEnterBackground {
    @try {
        // 1. 优雅地关闭当前显示的通知
        if (self.currentNotificationView) {
            [UIView animateWithDuration:APP_STATE_CHANGE_ANIMATION_DURATION 
                             animations:^{
                self.currentNotificationView.alpha = 0;
            } completion:^(BOOL finished) {
                [self.currentNotificationView removeFromSuperview];
                self.currentNotificationView = nil;
            }];
        }
        
        // 2. 清理通知队列
        self.isShowingNotification = NO;
        [self.notificationArray removeAllObjects];
        
        // 3. 保存当前状态
        [[NSUserDefaults standardUserDefaults] synchronize];
        
    } @catch (NSException *exception) {
        NSLog(@"[WeChatNotificationTweak] 处理进入后台异常: %@", exception);
    }
}

- (void)handleBecomeActive {
    @try {
        // 1. 恢复通知系统
        self.isShowingNotification = NO;
        
        // 2. 检查并更新通知权限
        [self checkNotificationAuthorization];
        
        // 3. 处理可能的挂起通知
        [self processNextNotification];
        
    } @catch (NSException *exception) {
        NSLog(@"[WeChatNotificationTweak] 处理进入前台异常: %@", exception);
    }
}

- (void)handleWillResignActive {
    @try {
        // 1. 暂停当前通知的自动消失计时器
        if (self.currentNotificationView) {
            [NSObject cancelPreviousPerformRequestsWithTarget:self 
                selector:@selector(dismissNotificationView:) 
                  object:self.currentNotificationView];
        }
        
    } @catch (NSException *exception) {
        NSLog(@"[WeChatNotificationTweak] 处理即将进入非活动状态异常: %@", exception);
    }
}

- (void)checkNotificationAuthorization {
    if (@available(iOS 10.0, *)) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (settings.authorizationStatus == UNAuthorizationStatusDenied) {
                    // 通知权限被拒绝，显示提示
                    [self showNotificationPermissionAlert];
                }
            });
        }];
    }
}

- (void)showNotificationPermissionAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"通知权限已关闭"
                                                                 message:@"请在设置中开启通知权限，以便接收灵动岛通知"
                                                          preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消"
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"去设置"
                                            style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction * _Nonnull action) {
        NSURL *settingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
        if ([[UIApplication sharedApplication] canOpenURL:settingsURL]) {
            [[UIApplication sharedApplication] openURL:settingsURL options:@{} completionHandler:nil];
        }
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end 