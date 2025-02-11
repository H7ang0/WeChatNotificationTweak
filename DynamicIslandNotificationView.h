#ifndef DYNAMIC_ISLAND_NOTIFICATION_VIEW_H
#define DYNAMIC_ISLAND_NOTIFICATION_VIEW_H

#import <UIKit/UIKit.h>
#import "Tweak.h"

// 灵动岛尺寸常量
#define DYNAMIC_ISLAND_CORNER_RADIUS 20.0
#define DYNAMIC_ISLAND_TOP_MARGIN 11.0

// 迷你样式尺寸（原生灵动岛尺寸）
#define DYNAMIC_ISLAND_MINI_WIDTH 36.5
#define DYNAMIC_ISLAND_MINI_HEIGHT 36.5

// 紧凑样式尺寸（原生灵动岛尺寸）
#define DYNAMIC_ISLAND_COMPACT_WIDTH 126.0
#define DYNAMIC_ISLAND_COMPACT_HEIGHT 37.0

// 展开样式尺寸（原生灵动岛尺寸）
#define DYNAMIC_ISLAND_EXPANDED_WIDTH 350.0
#define DYNAMIC_ISLAND_EXPANDED_HEIGHT 120.0

// 标准样式尺寸（最大尺寸，显示完整内容）
#define DYNAMIC_ISLAND_STANDARD_WIDTH 250.0
#define DYNAMIC_ISLAND_STANDARD_HEIGHT 68.0
#define DYNAMIC_ISLAND_AVATAR_SIZE_STANDARD 40.0

// 简约样式尺寸（中等尺寸，显示头像和标题）
#define DYNAMIC_ISLAND_AVATAR_SIZE_COMPACT 28.0

// 图标尺寸（原生灵动岛尺寸）
#define DYNAMIC_ISLAND_ICON_SIZE 10.0
#define DYNAMIC_ISLAND_ICON_CORNER_RADIUS 5.0

// 动画时间（原生灵动岛动画）
#define DYNAMIC_ISLAND_ANIMATION_DURATION 0.35
#define DYNAMIC_ISLAND_DISPLAY_DURATION 3.0
#define DYNAMIC_ISLAND_ANIMATION_SPRING_DAMPING 0.85
#define DYNAMIC_ISLAND_ANIMATION_INITIAL_VELOCITY 0.2

// 内容边距（原生灵动岛布局）
#define DYNAMIC_ISLAND_CONTENT_PADDING_HORIZONTAL 13.5
#define DYNAMIC_ISLAND_CONTENT_PADDING_VERTICAL 13.5
#define DYNAMIC_ISLAND_CONTENT_SPACING 8.0

@interface DynamicIslandNotificationView : UIView

@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, assign) DynamicIslandStyle currentStyle;
@property (nonatomic, assign) CGPoint originalCenter;

+ (void)showWithTitle:(NSString *)title message:(NSString *)message;
+ (void)showNotificationWithTitle:(NSString *)title message:(NSString *)message;
+ (void)showWithIcon:(UIImage *)icon title:(NSString *)title message:(NSString *)message extraInfo:(NSDictionary *)extraInfo;

- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message;
- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message icon:(UIImage *)icon;
- (void)show;
- (void)dismiss;
- (void)setupUIForStyle:(DynamicIslandStyle)style;
- (void)setupGestures;
- (void)handleTap:(UITapGestureRecognizer *)gesture;
- (void)handlePan:(UIPanGestureRecognizer *)gesture;
- (void)dismissWithAnimation;
- (void)dismissWithDirection:(CGFloat)direction;

@end

#endif /* DYNAMIC_ISLAND_NOTIFICATION_VIEW_H */ 