#ifndef TWEAK_H
#define TWEAK_H

#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#import <objc/runtime.h>

// 前向声明
@class DynamicIslandSettingViewController;
@class DynamicIslandNotificationView;

// 灵动岛样式枚举
typedef NS_ENUM(NSInteger, DynamicIslandStyle) {
    DynamicIslandStyleMini = 0,      // 迷你样式
    DynamicIslandStyleCompact = 1,    // 紧凑样式
    DynamicIslandStyleExpanded = 2    // 展开样式
};

// 修改工具函数声明
UIWindow* getCurrentWindow(void);

// 常量定义
static NSString *const kDynamicIslandEnabled = @"DynamicIslandEnabled";
static NSString *const kDynamicIslandStyle = @"DynamicIslandStyle";
static NSString *const kDynamicIslandPositionY = @"DynamicIslandPositionY";
static NSString *const kDynamicIslandDuration = @"DynamicIslandDuration";

// 工具函数声明
static inline CGFloat GetNotchHeight(void) {
    if (@available(iOS 11.0, *)) {
        UIWindow *window = getCurrentWindow();
        return window.safeAreaInsets.top;
    }
    return 20;
}

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

// 通知视图尺寸
#define NOTIFICATION_WIDTH (IS_IPHONE_14_PRO ? 350 : 300)
#define NOTIFICATION_HEIGHT (IS_IPHONE_14_PRO ? 80 : 70)
#define NOTIFICATION_TOP_MARGIN (IS_IPHONE_14_PRO ? GetNotchHeight() : 10)

// 微信相关类声明
@interface MMServiceCenter : NSObject
+ (instancetype)defaultCenter;
- (id)getService:(Class)service;
@end

@interface CContact : NSObject
@property(nonatomic, copy) NSString *m_nsNickName;
@property(nonatomic, strong) UIImage *m_avatarImage;
@end

@interface CContactMgr : NSObject
- (id)getContactByName:(id)name;
@end

@interface CMessageWrap : NSObject
@property(nonatomic, copy) NSString *m_nsContent;
@property(nonatomic, copy) NSString *m_nsFromUsr;
@property(nonatomic, assign) unsigned int m_uiMessageType;
@end

// 微信支付相关类声明
@interface WCPayTransferControlData : NSObject
@property(nonatomic, copy) NSString *m_nsReceiveUser;
@property(nonatomic, strong) NSNumber *m_uiAmount;
@end

// 支付转账视图控制器声明
@interface WCPayTransferViewController : UIViewController
@property(nonatomic, strong) WCPayTransferControlData *m_oTransferData;
@end

// 工具函数声明
void addFriendByWxId(NSString *wxId);
void transferMoneyToUser(NSString *wxId, CGFloat amount);
void showAppreciationCode(UIViewController *viewController);

// Toast 视图
@interface CustomToastView : UIView
+ (void)showToast:(NSString *)message;
@end

// 通知视图类声明
@interface WCNotificationView : UIView
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UILabel *contentLabel;
@property(nonatomic, strong) UIView *containerView;
@property(nonatomic, strong) UIVisualEffectView *blurView;

- (void)showWithAnimation;
- (void)dismissWithAnimation;
- (UIViewController *)topViewController;
@end

#endif /* TWEAK_H */