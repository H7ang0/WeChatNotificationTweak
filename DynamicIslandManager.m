#import "DynamicIslandManager.h"

@interface DynamicIslandManager ()
@property (nonatomic, strong) UIView *dynamicIslandView;
@property (nonatomic, strong) NSTimer *hideTimer;
@property (nonatomic, assign) BOOL isDeviceWithDynamicIsland;
@property (nonatomic, assign) DynamicIslandStyle currentStyle;
@end

@implementation DynamicIslandManager

+ (instancetype)sharedInstance {
    static DynamicIslandManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isDeviceWithDynamicIsland = [self checkDeviceSupport];
    }
    return self;
}

- (BOOL)checkDeviceSupport {
    if (@available(iOS 15.0, *)) {
        // 检查是否是带有灵动岛的设备（iPhone 14 Pro及以上）
        NSString *deviceModel = [[UIDevice currentDevice] model];
        if ([deviceModel containsString:@"iPhone"]) {
            // 获取设备机型标识符
            struct utsname systemInfo;
            uname(&systemInfo);
            NSString *deviceIdentifier = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
            
            // iPhone 14 Pro 和 Pro Max 的标识符
            NSArray *dynamicIslandDevices = @[@"iPhone15,2", @"iPhone15,3", @"iPhone16,1", @"iPhone16,2"];
            return [dynamicIslandDevices containsObject:deviceIdentifier];
        }
        return NO;
    }
    return NO;
}

- (CGRect)dynamicIslandFrameForDeviceType {
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    
    if (self.isDeviceWithDynamicIsland) {
        switch (self.currentStyle) {
            case DynamicIslandStyleMinimal:
                // 最小型样式尺寸
                return CGRectMake((screenBounds.size.width - 40) / 2, 11, 40, 37);
            case DynamicIslandStyleCompact:
                // 紧凑型样式尺寸
                return CGRectMake((screenBounds.size.width - 120) / 2, 11, 120, 37);
            case DynamicIslandStyleExpanded:
                // 展开型样式尺寸
                return CGRectMake((screenBounds.size.width - 350) / 2, 11, 350, 120);
        }
    } else {
        // 非灵动岛设备统一使用标准尺寸
        return CGRectMake((screenBounds.size.width - 350) / 2, 10, 350, 40);
    }
    
    return CGRectMake((screenBounds.size.width - 120) / 2, 11, 120, 37);
}

- (void)showNotificationWithTitle:(NSString *)title content:(NSString *)content {
    if (!title || !content) return;
    
    // 获取当前设置的样式
    self.currentStyle = (DynamicIslandStyle)[[NSUserDefaults standardUserDefaults] integerForKey:kDynamicIslandStyle];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // 移除现有的通知
        [self hideNotification];
        
        // 创建灵动岛视图
        CGRect frame = [self dynamicIslandFrameForDeviceType];
        self.dynamicIslandView = [[UIView alloc] initWithFrame:frame];
        self.dynamicIslandView.backgroundColor = [UIColor blackColor];
        self.dynamicIslandView.layer.cornerRadius = self.currentStyle == DynamicIslandStyleExpanded ? 20 : frame.size.height / 2;
        self.dynamicIslandView.clipsToBounds = YES;
        
        // 添加模糊效果
        if (@available(iOS 15.0, *)) {
            UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
            UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
            blurView.frame = self.dynamicIslandView.bounds;
            [self.dynamicIslandView addSubview:blurView];
        }
        
        // 根据不同样式创建UI
        switch (self.currentStyle) {
            case DynamicIslandStyleMinimal:
                [self setupMinimalStyleWithTitle:title];
                break;
            case DynamicIslandStyleCompact:
                [self setupCompactStyleWithTitle:title content:content];
                break;
            case DynamicIslandStyleExpanded:
                [self setupExpandedStyleWithTitle:title content:content];
                break;
        }
        
        // 添加点击手势
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self 
                                                                                    action:@selector(handleTapGesture:)];
        [self.dynamicIslandView addGestureRecognizer:tapGesture];
        
        // 显示动画
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        self.dynamicIslandView.alpha = 0;
        [window addSubview:self.dynamicIslandView];
        
        [UIView animateWithDuration:0.3 animations:^{
            self.dynamicIslandView.alpha = 1;
            if (self.isDeviceWithDynamicIsland) {
                // 灵动岛特有的弹性动画
                [UIView animateWithSpringDuration:0.5 
                                         bounce:0.2 
                                  initialSpringVelocity:0.5 
                                        animations:^{
                    self.dynamicIslandView.transform = CGAffineTransformIdentity;
                }];
            }
        }];
        
        // 3秒后自动隐藏
        self.hideTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 
                                                       target:self 
                                                     selector:@selector(hideNotification) 
                                                     userInfo:nil 
                                                      repeats:NO];
    });
}

- (void)setupMinimalStyleWithTitle:(NSString *)title {
    // 最小型样式：紧凑显示所有内容
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"AppIcon"]];
    iconView.frame = CGRectMake(5, 6, 25, 25);
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.layer.cornerRadius = 12.5;
    iconView.clipsToBounds = YES;
    [self.dynamicIslandView addSubview:iconView];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:10];
    titleLabel.frame = CGRectMake(35, 5, self.dynamicIslandView.frame.size.width - 40, 12);
    [self.dynamicIslandView addSubview:titleLabel];
    
    UILabel *contentLabel = [[UILabel alloc] init];
    contentLabel.text = content;
    contentLabel.textColor = [UIColor whiteColor];
    contentLabel.font = [UIFont systemFontOfSize:9];
    contentLabel.frame = CGRectMake(35, 20, self.dynamicIslandView.frame.size.width - 40, 12);
    [self.dynamicIslandView addSubview:contentLabel];
}

- (void)setupCompactStyleWithTitle:(NSString *)title content:(NSString *)content {
    // 紧凑型样式：标准布局
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"AppIcon"]];
    iconView.frame = CGRectMake(8, 6, 25, 25);
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.layer.cornerRadius = 12.5;
    iconView.clipsToBounds = YES;
    [self.dynamicIslandView addSubview:iconView];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:12];
    titleLabel.frame = CGRectMake(40, 5, self.dynamicIslandView.frame.size.width - 50, 13);
    [self.dynamicIslandView addSubview:titleLabel];
    
    UILabel *contentLabel = [[UILabel alloc] init];
    contentLabel.text = content;
    contentLabel.textColor = [UIColor whiteColor];
    contentLabel.font = [UIFont systemFontOfSize:11];
    contentLabel.frame = CGRectMake(40, 20, self.dynamicIslandView.frame.size.width - 50, 12);
    [self.dynamicIslandView addSubview:contentLabel];
    
    // 添加时间标签
    UILabel *timeLabel = [[UILabel alloc] init];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm";
    timeLabel.text = [formatter stringFromDate:[NSDate date]];
    timeLabel.textColor = [UIColor whiteColor];
    timeLabel.font = [UIFont systemFontOfSize:10];
    timeLabel.frame = CGRectMake(self.dynamicIslandView.frame.size.width - 35, 5, 30, 12);
    timeLabel.textAlignment = NSTextAlignmentRight;
    [self.dynamicIslandView addSubview:timeLabel];
}

- (void)setupExpandedStyleWithTitle:(NSString *)title content:(NSString *)content {
    // 展开型样式：更大更清晰的布局
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"AppIcon"]];
    iconView.frame = CGRectMake(15, 15, 40, 40);
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.layer.cornerRadius = 20;
    iconView.clipsToBounds = YES;
    [self.dynamicIslandView addSubview:iconView];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    titleLabel.frame = CGRectMake(70, 15, self.dynamicIslandView.frame.size.width - 130, 20);
    [self.dynamicIslandView addSubview:titleLabel];
    
    UILabel *contentLabel = [[UILabel alloc] init];
    contentLabel.text = content;
    contentLabel.textColor = [UIColor whiteColor];
    contentLabel.font = [UIFont systemFontOfSize:14];
    contentLabel.numberOfLines = 3;
    contentLabel.frame = CGRectMake(70, 40, self.dynamicIslandView.frame.size.width - 85, 65);
    [self.dynamicIslandView addSubview:contentLabel];
    
    // 添加时间标签
    UILabel *timeLabel = [[UILabel alloc] init];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm";
    timeLabel.text = [formatter stringFromDate:[NSDate date]];
    timeLabel.textColor = [UIColor whiteColor];
    timeLabel.font = [UIFont systemFontOfSize:12];
    timeLabel.frame = CGRectMake(self.dynamicIslandView.frame.size.width - 50, 15, 35, 15);
    timeLabel.textAlignment = NSTextAlignmentRight;
    [self.dynamicIslandView addSubview:timeLabel];
}

- (void)hideNotification {
    if (!self.dynamicIslandView) return;
    
    [UIView animateWithDuration:0.3 
                     animations:^{
        self.dynamicIslandView.alpha = 0;
    } completion:^(BOOL finished) {
        [self.dynamicIslandView removeFromSuperview];
        self.dynamicIslandView = nil;
    }];
    
    if (self.hideTimer) {
        [self.hideTimer invalidate];
        self.hideTimer = nil;
    }
}

- (void)handleTapGesture:(UITapGestureRecognizer *)gesture {
    [self hideNotification];
}

@end 