#import "DynamicIslandNotificationView.h"

@interface DynamicIslandNotificationView ()
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) CAShapeLayer *maskLayer;
@property (nonatomic, assign) CGRect originalFrame;
@property (nonatomic, assign) DynamicIslandStyle currentStyle;
@property (nonatomic, assign) CGPoint originalCenter;
@end

@implementation DynamicIslandNotificationView

+ (void)showWithTitle:(NSString *)title message:(NSString *)message {
    DynamicIslandNotificationView *notificationView = [[DynamicIslandNotificationView alloc] initWithTitle:title message:message];
    [notificationView show];
}

+ (void)showNotificationWithTitle:(NSString *)title message:(NSString *)message {
    [self showWithTitle:title message:message];
}

- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message {
    // 初始化为迷你样式大小
    self = [super initWithFrame:CGRectMake(0, 0, DYNAMIC_ISLAND_MINI_WIDTH, DYNAMIC_ISLAND_MINI_HEIGHT)];
    if (self) {
        // 设置初始位置为屏幕顶部中间
        self.center = CGPointMake([UIScreen mainScreen].bounds.size.width / 2, DYNAMIC_ISLAND_TOP_MARGIN + DYNAMIC_ISLAND_MINI_HEIGHT / 2);
        
        // 设置背景颜色和圆角
        self.backgroundColor = [UIColor blackColor];
        self.layer.cornerRadius = DYNAMIC_ISLAND_MINI_HEIGHT / 2;
        self.clipsToBounds = YES;
        
        // 设置模糊效果
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        self.blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        self.blurView.frame = self.bounds;
        self.blurView.layer.cornerRadius = self.layer.cornerRadius;
        self.blurView.clipsToBounds = YES;
        [self addSubview:self.blurView];
        
        // 设置标题
        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        self.titleLabel.textColor = [UIColor whiteColor];
        self.titleLabel.text = title;
        [self.blurView.contentView addSubview:self.titleLabel];
        
        // 设置消息内容
        self.messageLabel = [[UILabel alloc] init];
        self.messageLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        self.messageLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.8];
        self.messageLabel.text = message;
        [self.blurView.contentView addSubview:self.messageLabel];
        
        // 添加手势
        [self setupGestures];
        
        // 默认隐藏标题和消息
        self.titleLabel.hidden = YES;
        self.messageLabel.hidden = YES;
    }
    return self;
}

- (void)show {
    UIWindow *window = [self getKeyWindow];
    if (!window) return;
    
    [window addSubview:self];
    
    // 从迷你样式展开到紧凑样式的动画
    [UIView animateWithDuration:DYNAMIC_ISLAND_ANIMATION_DURATION 
                          delay:0 
         usingSpringWithDamping:DYNAMIC_ISLAND_ANIMATION_SPRING_DAMPING
          initialSpringVelocity:DYNAMIC_ISLAND_ANIMATION_INITIAL_VELOCITY
                        options:UIViewAnimationOptionCurveEaseOut 
                     animations:^{
        // 更新为紧凑样式的尺寸和布局
        self.frame = CGRectMake(([UIScreen mainScreen].bounds.size.width - DYNAMIC_ISLAND_COMPACT_WIDTH) / 2,
                               DYNAMIC_ISLAND_TOP_MARGIN,
                               DYNAMIC_ISLAND_COMPACT_WIDTH,
                               DYNAMIC_ISLAND_COMPACT_HEIGHT);
        self.layer.cornerRadius = DYNAMIC_ISLAND_COMPACT_HEIGHT / 2;
        
        // 更新模糊视图
        self.blurView.frame = self.bounds;
        self.blurView.layer.cornerRadius = self.layer.cornerRadius;
        
        // 显示并更新标题位置
        self.titleLabel.hidden = NO;
        self.titleLabel.frame = CGRectMake(DYNAMIC_ISLAND_CONTENT_PADDING_HORIZONTAL, 
                                         (DYNAMIC_ISLAND_COMPACT_HEIGHT - 17) / 2, 
                                         DYNAMIC_ISLAND_COMPACT_WIDTH - DYNAMIC_ISLAND_CONTENT_PADDING_HORIZONTAL * 2, 
                                         17);
    } completion:nil];
    
    // 3秒后自动消失
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(DYNAMIC_ISLAND_DISPLAY_DURATION * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self dismiss];
    });
}

- (void)dismiss {
    [UIView animateWithDuration:DYNAMIC_ISLAND_ANIMATION_DURATION * 0.8
                          delay:0
         usingSpringWithDamping:DYNAMIC_ISLAND_ANIMATION_SPRING_DAMPING
          initialSpringVelocity:DYNAMIC_ISLAND_ANIMATION_INITIAL_VELOCITY
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        // 恢复为迷你样式
        self.frame = CGRectMake(([UIScreen mainScreen].bounds.size.width - DYNAMIC_ISLAND_MINI_WIDTH) / 2,
                               DYNAMIC_ISLAND_TOP_MARGIN,
                               DYNAMIC_ISLAND_MINI_WIDTH,
                               DYNAMIC_ISLAND_MINI_HEIGHT);
        self.layer.cornerRadius = DYNAMIC_ISLAND_MINI_HEIGHT / 2;
        
        // 更新模糊视图
        self.blurView.frame = self.bounds;
        self.blurView.layer.cornerRadius = self.layer.cornerRadius;
        
        // 隐藏标题和消息
        self.titleLabel.hidden = YES;
        self.messageLabel.hidden = YES;
        
        // 淡出效果
        self.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

- (UIWindow *)getKeyWindow {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        NSSet *connectedScenes = [[UIApplication sharedApplication] connectedScenes];
        for (UIScene *scene in connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *window in windowScene.windows) {
                    if (window.isKeyWindow) {
                        keyWindow = window;
                        break;
                    }
                }
            }
        }
    }
    return keyWindow;
}

- (void)setupUIForStyle:(DynamicIslandStyle)style {
    self.currentStyle = style;
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    
    switch (style) {
        case DynamicIslandStyleExpanded: {
            // 展开样式（原生灵动岛尺寸）
            self.frame = CGRectMake((screenWidth - DYNAMIC_ISLAND_EXPANDED_WIDTH) / 2, 
                                  DYNAMIC_ISLAND_TOP_MARGIN, 
                                  DYNAMIC_ISLAND_EXPANDED_WIDTH, 
                                  DYNAMIC_ISLAND_EXPANDED_HEIGHT);
            self.layer.cornerRadius = DYNAMIC_ISLAND_CORNER_RADIUS;
            
            // 内容布局
            CGFloat contentX = DYNAMIC_ISLAND_CONTENT_PADDING_HORIZONTAL;
            CGFloat contentWidth = DYNAMIC_ISLAND_EXPANDED_WIDTH - contentX * 2;
            
            self.titleLabel.frame = CGRectMake(contentX, 16, contentWidth, 22);
            self.messageLabel.frame = CGRectMake(contentX, 42, contentWidth, 20);
            
            self.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
            self.messageLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
            
            self.titleLabel.hidden = NO;
            self.messageLabel.hidden = NO;
            break;
        }
        
        case DynamicIslandStyleCompact: {
            // 紧凑样式（原生灵动岛尺寸）
            self.frame = CGRectMake((screenWidth - DYNAMIC_ISLAND_COMPACT_WIDTH) / 2, 
                                  DYNAMIC_ISLAND_TOP_MARGIN, 
                                  DYNAMIC_ISLAND_COMPACT_WIDTH, 
                                  DYNAMIC_ISLAND_COMPACT_HEIGHT);
            self.layer.cornerRadius = DYNAMIC_ISLAND_COMPACT_HEIGHT / 2;
            
            // 标题设置
            self.titleLabel.frame = CGRectMake(DYNAMIC_ISLAND_CONTENT_PADDING_HORIZONTAL,
                                           (DYNAMIC_ISLAND_COMPACT_HEIGHT - 17) / 2,
                                           DYNAMIC_ISLAND_COMPACT_WIDTH - DYNAMIC_ISLAND_CONTENT_PADDING_HORIZONTAL * 2,
                                           17);
            self.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
            
            self.titleLabel.hidden = NO;
            self.messageLabel.hidden = YES;
            break;
        }
        
        case DynamicIslandStyleMini: {
            // 迷你样式（原生灵动岛尺寸）
            self.frame = CGRectMake((screenWidth - DYNAMIC_ISLAND_MINI_WIDTH) / 2, 
                                  DYNAMIC_ISLAND_TOP_MARGIN, 
                                  DYNAMIC_ISLAND_MINI_WIDTH, 
                                  DYNAMIC_ISLAND_MINI_HEIGHT);
            self.layer.cornerRadius = DYNAMIC_ISLAND_MINI_HEIGHT / 2;
            
            self.titleLabel.hidden = YES;
            self.messageLabel.hidden = YES;
            break;
        }
    }
    
    // 更新模糊背景
    self.blurView.frame = self.bounds;
    self.blurView.layer.cornerRadius = self.layer.cornerRadius;
    self.blurView.clipsToBounds = YES;
    
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    // 添加震动反馈
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [feedback prepare];
        [feedback impactOccurred];
    }
    
    // 获取当前窗口和顶层控制器
    UIWindow *window = [self getKeyWindow];
    if (!window) {
        [self dismissWithAnimation];
        return;
    }
    
    UIViewController *topVC = nil;
    UIViewController *rootVC = window.rootViewController;
    if (rootVC) {
        topVC = rootVC;
        while (topVC.presentedViewController) {
            topVC = topVC.presentedViewController;
        }
    }
    
    if (!topVC) {
        [self dismissWithAnimation];
        return;
    }
    
    // 安全地创建和显示 Alert
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *alertTitle = self.titleLabel.text ?: @"微信通知";
        NSString *alertMessage = self.messageLabel.text ?: @"";
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:alertTitle
                                                                     message:alertMessage
                                                              preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" 
                                                style:UIAlertActionStyleDefault 
                                              handler:nil]];
        
        [topVC presentViewController:alert animated:YES completion:nil];
    });
    
    [self dismissWithAnimation];
}

@end 