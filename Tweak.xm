#import "Tweak.h"
#import "DynamicIslandNotificationView.h"
#import "DynamicIslandSettingViewController.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <sys/utsname.h>
#import "substrate.h"
#import <UserNotifications/UserNotifications.h>

UIWindow* getCurrentWindow(void) {
    UIWindow *window = nil;
    if (@available(iOS 15.0, *)) {
        NSSet<UIScene *> *scenes = [[UIApplication sharedApplication] connectedScenes];
        for (UIScene *scene in scenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                NSArray<UIWindow *> *windows = [windowScene windows];
                for (UIWindow *w in windows) {
                    if (w.isKeyWindow) {
                        window = w;
                        break;
                    }
                }
                if (!window) {
                    window = windows.firstObject;
                }
                if (window) break;
            }
        }
    } else if (@available(iOS 13.0, *)) {
        NSSet<UIScene *> *scenes = [[UIApplication sharedApplication] connectedScenes];
        for (UIScene *scene in scenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                window = windowScene.windows.firstObject;
                break;
            }
        }
    }
    
    if (!window) {
        window = [UIApplication sharedApplication].delegate.window;
    }
    return window;
}

// 前台通知窗口
@interface QuickReplyMsgWindow : UIWindow
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *contentLabel;
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UIView *backgroundView;
- (void)showWithAnimation;
- (void)dismissWithAnimation;
@end

// 微信相关类声明
@interface WCTableViewManager : NSObject
@property (nonatomic, strong) NSArray *sections;
- (UITableView *)getTableView;
@end

@interface WCTableViewSectionManager : NSObject
@property (nonatomic, strong) NSMutableArray *cells;
- (void)addCell:(id)cell;
@end

@interface WCTableViewNormalCellManager : NSObject
+ (instancetype)normalCellForSel:(SEL)sel target:(id)target title:(NSString *)title detail:(NSString *)detail;
@end

@interface NewSettingViewController : UIViewController
- (void)reloadTableData;
@end

@implementation DynamicIslandNotificationView

+ (void)showWithTitle:(NSString *)title message:(NSString *)message {
    DynamicIslandNotificationView *notificationView = [[DynamicIslandNotificationView alloc] initWithTitle:title message:message];
    [notificationView show];
}

+ (void)showNotificationWithTitle:(NSString *)title message:(NSString *)message {
    [self showWithTitle:title message:message];
}

+ (void)showWithIcon:(UIImage *)icon title:(NSString *)title message:(NSString *)message extraInfo:(NSDictionary *)extraInfo {
    DynamicIslandNotificationView *notificationView = [[DynamicIslandNotificationView alloc] initWithTitle:title message:message icon:icon];
    [notificationView show];
}

- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message icon:(UIImage *)icon {
    self = [self initWithTitle:title message:message];
    if (self) {
        if (icon) {
            self.iconImageView.image = icon;
        }
    }
    return self;
}

- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message {
    // 初始化为迷你样式大小
    self = [super initWithFrame:CGRectMake(0, 0, DYNAMIC_ISLAND_MINI_WIDTH, DYNAMIC_ISLAND_MINI_HEIGHT)];
    if (self) {
        // 设置初始位置为屏幕顶部中间
        self.center = CGPointMake([UIScreen mainScreen].bounds.size.width / 2, DYNAMIC_ISLAND_TOP_MARGIN + DYNAMIC_ISLAND_MINI_HEIGHT / 2);
        self.originalCenter = self.center;
        
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
        
        // 设置容器视图
        self.containerView = [[UIView alloc] initWithFrame:self.bounds];
        [self addSubview:self.containerView];
        
        // 设置图标
        self.iconImageView = [[UIImageView alloc] initWithFrame:CGRectMake(DYNAMIC_ISLAND_CONTENT_PADDING_HORIZONTAL,
                                                                          (DYNAMIC_ISLAND_MINI_HEIGHT - DYNAMIC_ISLAND_ICON_SIZE) / 2,
                                                                          DYNAMIC_ISLAND_ICON_SIZE,
                                                                          DYNAMIC_ISLAND_ICON_SIZE)];
        self.iconImageView.layer.cornerRadius = DYNAMIC_ISLAND_ICON_SIZE / 2;
        self.iconImageView.clipsToBounds = YES;
        [self.containerView addSubview:self.iconImageView];
        
        // 设置标题
        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        self.titleLabel.textColor = [UIColor whiteColor];
        self.titleLabel.text = title;
        [self.containerView addSubview:self.titleLabel];
        
        // 设置消息内容
        self.messageLabel = [[UILabel alloc] init];
        self.messageLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        self.messageLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.8];
        self.messageLabel.text = message;
        [self.containerView addSubview:self.messageLabel];
        
        // 添加手势
        [self setupGestures];
        
        // 默认隐藏标题和消息
        self.titleLabel.hidden = YES;
        self.messageLabel.hidden = YES;
    }
    return self;
}

- (void)setupGestures {
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [self addGestureRecognizer:tapGesture];
    
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self addGestureRecognizer:panGesture];
}

- (void)show {
    [self showWithAnimation];
}

- (void)dismiss {
    [self dismissWithAnimation];
}

- (void)setupUIForStyle:(DynamicIslandStyle)style {
    self.currentStyle = style;
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    
    // 设置基础属性
    self.backgroundColor = [UIColor blackColor];
    self.layer.masksToBounds = YES;
    
    // 设置主视图尺寸和位置
    switch (style) {
        case DynamicIslandStyleExpanded: {
            // 展开样式（原生灵动岛尺寸）
            self.frame = CGRectMake((screenWidth - DYNAMIC_ISLAND_EXPANDED_WIDTH) / 2, 
                                  DYNAMIC_ISLAND_TOP_MARGIN, 
                                  DYNAMIC_ISLAND_EXPANDED_WIDTH, 
                                  DYNAMIC_ISLAND_EXPANDED_HEIGHT);
            self.layer.cornerRadius = DYNAMIC_ISLAND_CORNER_RADIUS;
            
            // 图标设置
            self.iconImageView.frame = CGRectMake(DYNAMIC_ISLAND_CONTENT_PADDING_HORIZONTAL,
                                                DYNAMIC_ISLAND_CONTENT_PADDING_VERTICAL,
                                                DYNAMIC_ISLAND_ICON_SIZE,
                                                DYNAMIC_ISLAND_ICON_SIZE);
            self.iconImageView.layer.cornerRadius = DYNAMIC_ISLAND_ICON_SIZE / 2;
            
            // 内容布局
            CGFloat contentX = CGRectGetMaxX(self.iconImageView.frame) + 12;
            CGFloat contentWidth = DYNAMIC_ISLAND_EXPANDED_WIDTH - contentX - 12;
            
            self.titleLabel.frame = CGRectMake(contentX, 16, contentWidth, 22);
            self.messageLabel.frame = CGRectMake(contentX, 42, contentWidth, 20);
            
            self.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
            self.messageLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
            break;
        }
        
        case DynamicIslandStyleCompact: {
            // 紧凑样式（原生灵动岛尺寸）
            self.frame = CGRectMake((screenWidth - DYNAMIC_ISLAND_COMPACT_WIDTH) / 2, 
                                  DYNAMIC_ISLAND_TOP_MARGIN, 
                                  DYNAMIC_ISLAND_COMPACT_WIDTH, 
                                  DYNAMIC_ISLAND_COMPACT_HEIGHT);
            self.layer.cornerRadius = DYNAMIC_ISLAND_COMPACT_HEIGHT / 2;
            
            // 图标设置
            self.iconImageView.frame = CGRectMake(DYNAMIC_ISLAND_CONTENT_PADDING_HORIZONTAL,
                                                (DYNAMIC_ISLAND_COMPACT_HEIGHT - DYNAMIC_ISLAND_ICON_SIZE) / 2,
                                                DYNAMIC_ISLAND_ICON_SIZE,
                                                DYNAMIC_ISLAND_ICON_SIZE);
            self.iconImageView.layer.cornerRadius = DYNAMIC_ISLAND_ICON_SIZE / 2;
            
            // 标题设置
            CGFloat titleX = CGRectGetMaxX(self.iconImageView.frame) + 8;
            self.titleLabel.frame = CGRectMake(titleX,
                                           (DYNAMIC_ISLAND_COMPACT_HEIGHT - 16) / 2,
                                           DYNAMIC_ISLAND_COMPACT_WIDTH - titleX - 8,
                                           16);
            self.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
            
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
            
            // 图标设置 - 完全居中
            CGFloat iconPadding = (DYNAMIC_ISLAND_MINI_HEIGHT - DYNAMIC_ISLAND_ICON_SIZE) / 2;
            self.iconImageView.frame = CGRectMake(iconPadding,
                                                iconPadding,
                                                DYNAMIC_ISLAND_ICON_SIZE,
                                                DYNAMIC_ISLAND_ICON_SIZE);
            self.iconImageView.layer.cornerRadius = DYNAMIC_ISLAND_ICON_SIZE / 2;
            
            self.titleLabel.hidden = YES;
            self.messageLabel.hidden = YES;
            break;
        }
    }
    
    // 通用设置
    self.iconImageView.clipsToBounds = YES;
    self.layer.masksToBounds = YES;
    
    // 更新模糊背景
    self.blurView.frame = self.bounds;
    self.blurView.layer.cornerRadius = self.layer.cornerRadius;
    self.blurView.clipsToBounds = YES;
    
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)showWithAnimation {
    // 设置初始状态
    self.alpha = 0;
    self.transform = CGAffineTransformMakeScale(0.5, 0.5);
    
    // 主动画
    [UIView animateWithDuration:DYNAMIC_ISLAND_ANIMATION_DURATION 
                          delay:0 
         usingSpringWithDamping:DYNAMIC_ISLAND_ANIMATION_SPRING_DAMPING
          initialSpringVelocity:DYNAMIC_ISLAND_ANIMATION_INITIAL_VELOCITY
                        options:UIViewAnimationOptionCurveEaseOut 
                     animations:^{
        self.alpha = 1;
        self.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        // 添加轻微的弹性效果
        [UIView animateWithDuration:0.15
                              delay:0 
                            options:UIViewAnimationOptionCurveEaseInOut 
                         animations:^{
            self.transform = CGAffineTransformMakeScale(1.02, 1.02);
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.1 animations:^{
                self.transform = CGAffineTransformIdentity;
            }];
        }];
    }];
    
    // 延迟消失
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(DYNAMIC_ISLAND_DISPLAY_DURATION * NSEC_PER_SEC)), 
                  dispatch_get_main_queue(), ^{
        [self dismissWithAnimation];
    });
}

- (void)dismissWithAnimation {
    [UIView animateWithDuration:DYNAMIC_ISLAND_ANIMATION_DURATION * 0.75
                          delay:0 
                        options:UIViewAnimationOptionCurveEaseIn 
                     animations:^{
        self.alpha = 0;
        self.transform = CGAffineTransformMakeScale(0.8, 0.8);
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [feedback impactOccurred];
    }
    
    // 修复 UIAlertController 的创建
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:self.titleLabel.text
                                                                 message:self.messageLabel.text
                                                          preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" 
                                            style:UIAlertActionStyleDefault 
                                          handler:nil]];
    
    UIViewController *topVC = [self topViewController];
    [topVC presentViewController:alert animated:YES completion:nil];
    
    [self dismissWithAnimation];
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self];
    CGPoint velocity = [gesture velocityInView:self];
    
    switch (gesture.state) {
        case UIGestureRecognizerStateChanged: {
            CGPoint center = self.center;
            center.y += translation.y;
            self.center = center;
            [gesture setTranslation:CGPointZero inView:self];
            break;
        }
        case UIGestureRecognizerStateEnded: {
            if (fabs(velocity.y) > 1000 || fabs(self.center.y - self.originalCenter.y) > 100) {
                CGFloat direction = velocity.y > 0 ? 1 : -1;
                [self dismissWithDirection:direction];
            } else {
                [UIView animateWithDuration:0.3 
                                     delay:0 
                                   options:UIViewAnimationOptionCurveEaseOut 
                                animations:^{
                    self.center = self.originalCenter;
                } completion:nil];
            }
            break;
        }
        default:
            break;
    }
}

- (void)dismissWithDirection:(CGFloat)direction {
    [UIView animateWithDuration:0.2 
                          delay:0 
                        options:UIViewAnimationOptionCurveEaseIn 
                     animations:^{
        CGRect frame = self.frame;
        frame.origin.y = direction > 0 ? self.superview.bounds.size.height : -frame.size.height;
        self.frame = frame;
        self.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

- (UIViewController *)topViewController {
    UIViewController *topController = nil;
    UIWindow *window = getCurrentWindow();
    if (window) {
        topController = window.rootViewController;
        while (topController.presentedViewController) {
            topController = topController.presentedViewController;
        }
    }
    return topController;
}

@end

// Hook 前台通知
%hook QuickReplyMsgWindow

%property (nonatomic, strong) UIView *contentView;
%property (nonatomic, strong) UILabel *titleLabel;
%property (nonatomic, strong) UILabel *contentLabel;
%property (nonatomic, strong) UIImageView *avatarImageView;
%property (nonatomic, strong) UIView *backgroundView;

- (id)initWithFrame:(CGRect)frame {
    self = %orig;
    if (self) {
        // 记录原始视图引用
        self.contentView = [self valueForKey:@"m_contentView"];
        self.titleLabel = [self.contentView valueForKey:@"m_titleLabel"];
        self.contentLabel = [self.contentView valueForKey:@"m_contentLabel"];
        self.avatarImageView = [self.contentView valueForKey:@"m_avatarImageView"];
        self.backgroundView = [self.contentView valueForKey:@"m_backgroundView"];
    }
    return self;
}

- (void)showWithTitle:(NSString *)title message:(NSString *)message {
    @try {
        // 检查是否启用了灵动岛通知
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kDynamicIslandEnabled]) {
        %orig;
        return;
    }
    
        // 检查是否是输入弹窗
        if ([self isKindOfClass:%c(QuickReplyMsgWindow)] && 
            ([self.superview isKindOfClass:%c(UIInputView)] || 
             [NSStringFromClass([self.superview class]) containsString:@"Input"])) {
            %orig;
            return;
        }

        // 其他情况使用灵动岛通知
        dispatch_async(dispatch_get_main_queue(), ^{
            [DynamicIslandNotificationView showWithTitle:title message:message];
            
            // 添加震动反馈
            if (@available(iOS 10.0, *)) {
                UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
                [generator prepare];
                [generator impactOccurred];
            }
        });
    } @catch (NSException *exception) {
        NSLog(@"[WeChatNotificationTweak] 显示通知失败: %@", exception);
        %orig;  // 如果失败，使用原始通知
    }
}

- (void)dismissWithAnimation {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kDynamicIslandEnabled]) {
        %orig;
        return;
    }

    // 使用自定义消失动画
    [UIView animateWithDuration:0.3 
                          delay:0 
                        options:UIViewAnimationOptionCurveEaseIn 
                     animations:^{
        self.alpha = 0;
        self.transform = CGAffineTransformMakeTranslation(0, -100);
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

// 阻止原始布局
- (void)layoutSubviews {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kDynamicIslandEnabled]) {
        %orig;
    }
}

%end

// Hook 后台消息
%hook CMessageMgr

- (void)MessageReturn:(id)arg1 Event:(unsigned int)arg2 {
    %orig;
    // 处理消息返回事件
    @try {
        CMessageWrap *msgWrap = (CMessageWrap *)arg1;
        if (!msgWrap) {
            return;
        }
        
        // 获取消息内容和发送者
        NSString *content = msgWrap.m_nsContent;
        NSString *fromUser = msgWrap.m_nsFromUsr;
        
        // 过滤系统消息
        if ([fromUser isEqualToString:@"newsapp"] || 
            [fromUser isEqualToString:@"notification_messages"] ||
            msgWrap.m_uiMessageType == 10000) {
            return;
        }
        
        if (content && fromUser) {
            // 获取发送者信息
            MMServiceCenter *serviceCenter = [%c(MMServiceCenter) defaultCenter];
            CContactMgr *contactMgr = [serviceCenter getService:%c(CContactMgr)];
            CContact *contact = [contactMgr getContactByName:fromUser];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                // 显示灵动岛通知
                NSString *title = contact.m_nsNickName ?: fromUser;
                UIImage *avatar = [contact valueForKey:@"m_avatarImage"];
                [DynamicIslandNotificationView showWithIcon:avatar
                                                    title:title 
                                                  message:content 
                                                extraInfo:nil];
                
                // 添加震动反馈
                if (@available(iOS 10.0, *)) {
                    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
                    [generator prepare];
                    [generator impactOccurred];
                }
            });
        }
    } @catch (NSException *exception) {
        NSLog(@"[WeChatNotificationTweak] 处理消息返回事件失败: %@", exception);
    }
}

%end

// 设备检测宏
#define IS_IPHONE_14_PRO ({\
    static BOOL isIPhone14Pro = NO; \
    static dispatch_once_t onceToken; \
    dispatch_once(&onceToken, ^{ \
        if (@available(iOS 16.0, *)) { \
            UIWindow *window = getCurrentWindow(); \
            isIPhone14Pro = window.safeAreaInsets.top >= 54; \
        } \
    }); \
    isIPhone14Pro; \
})

#define NOTCH_HEIGHT (IS_IPHONE_14_PRO ? 44.0 : 20.0)
#define DYNAMIC_ISLAND_WIDTH 350.0
#define DYNAMIC_ISLAND_HEIGHT 80.0

// 获取设备型号
static NSString* __attribute__((unused)) getDeviceModel() {
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
}

// 完整的类声明
@interface WCContactData : NSObject
- (void)setM_nsUsrName:(NSString *)userName;
@end

@interface WCContactController : UIViewController
- (void)addContactWithWCContactData:(WCContactData *)contactData;
@end

@interface WCUIAlertView : UIView
@property (nonatomic, strong) UIView *contentView;
- (void)findLabelsInView:(UIView *)view intoArray:(NSMutableArray *)labels;
@end

// 修改通知服务处理
%hook MMNotificationService

- (void)notificationWillShow:(id)notification {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kDynamicIslandEnabled]) {
        // 获取通知内容
        NSString *title = [notification valueForKey:@"title"] ?: @"微信";
        NSString *content = [notification valueForKey:@"content"] ?: @"";
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // 使用灵动岛显示通知
            [DynamicIslandNotificationView showWithTitle:title message:content];
        });
        
        return;  // 阻止原生通知
    }
    
    %orig;
}

%end

// 后台通知处理
%hook WCNotificationManager

- (void)handleBackgroundNotification:(NSDictionary *)userInfo {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kDynamicIslandEnabled]) {
        %orig;
        return;
    }
    
    @try {
        // 解析通知内容
        NSDictionary *aps = userInfo[@"aps"];
        if (!aps) {
            %orig;
            return;
        }
        
        NSString *title = nil;
        NSString *message = nil;
        
        if ([aps[@"alert"] isKindOfClass:[NSDictionary class]]) {
            NSDictionary *alert = aps[@"alert"];
            title = alert[@"title"] ?: @"微信";
            message = alert[@"body"];
        } else {
            title = @"微信";
            message = aps[@"alert"];
        }
        
        if (message) {
            dispatch_async(dispatch_get_main_queue(), ^{
                // 显示通知
                [DynamicIslandNotificationView showWithTitle:title message:message];
                
                // 添加震动反馈
                if (@available(iOS 10.0, *)) {
                    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
                    [generator prepare];
                    [generator impactOccurred];
                }
            });
        }
    } @catch (NSException *exception) {
        NSLog(@"[WeChatNotificationTweak] 处理后台通知失败: %@", exception);
        %orig;  // 如果失败，使用原始通知
    }
}

%end

%hook NewSettingViewController

- (void)reloadTableData {
    %orig;
    
    @try {
        if (@available(iOS 15.0, *)) {
            // 获取 TableView 管理器
            WCTableViewManager *tableViewMgr = MSHookIvar<id>(self, "m_tableViewMgr");
            if (!tableViewMgr) return;
            
            // 获取 TableView
            id tableView = [tableViewMgr getTableView];
            if (!tableView) return;
            
            // 检查是否已经添加过
            for (WCTableViewSectionManager *section in tableViewMgr.sections) {
                for (WCTableViewNormalCellManager *cell in section.cells) {
                    if ([[cell valueForKey:@"title"] isEqualToString:@"灵动岛通知"]) {
                        return;
                    }
                }
            }
            
            // 创建新的设置项
            WCTableViewNormalCellManager *dynamicIslandCell = [%c(WCTableViewNormalCellManager) normalCellForSel:@selector(openDynamicIslandSettings) 
                                                                                                     target:self 
                                                                                                      title:@"灵动岛通知"
                                                                                                     detail:@""];
            
            // 添加到第一个 section
            if (tableViewMgr.sections.count > 0) {
                WCTableViewSectionManager *firstSection = tableViewMgr.sections[0];
                [firstSection addCell:dynamicIslandCell];
                [tableView reloadData];
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"[WeChatNotificationTweak] 添加设置项失败: %@", exception);
    }
}

%new
- (void)openDynamicIslandSettings {
    @try {
        if (@available(iOS 15.0, *)) {
            DynamicIslandSettingViewController *settingVC = [[DynamicIslandSettingViewController alloc] init];
            if (settingVC) {
                [self.navigationController pushViewController:settingVC animated:YES];
            }
        } else {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" 
                                                                         message:@"灵动岛通知需要 iOS 15.0 或更高版本" 
                                                                  preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"确定" 
                                                    style:UIAlertActionStyleDefault 
                                                  handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    } @catch (NSException *exception) {
        NSLog(@"[WeChatNotificationTweak] 打开设置页面失败: %@", exception);
    }
}

%end

%ctor {
    %init;
} 