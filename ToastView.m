#import "ToastView.h"

@implementation AlertWindow

- (instancetype)init {
    self = [super init];
    if (self) {
        self.windowLevel = UIWindowLevelAlert;
        self.backgroundColor = [UIColor clearColor];
        self.hidden = NO;
    }
    return self;
}

@end

@interface CustomToastView ()
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) AlertWindow *alertWindow;
@end

@implementation CustomToastView

+ (void)showToast:(NSString *)message {
    CustomToastView *toast = [[CustomToastView alloc] initWithMessage:message];
    [toast show];
}

- (instancetype)initWithMessage:(NSString *)message {
    CGFloat width = 200;
    CGFloat height = 50;
    CGRect frame = CGRectMake(0, 0, width, height);
    
    self = [super initWithFrame:frame];
    if (self) {
        self.center = CGPointMake([UIScreen mainScreen].bounds.size.width / 2, 100);
        self.layer.cornerRadius = height / 2;
        self.layer.masksToBounds = YES;
        
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark];
        UIVisualEffectView *effectView = [[UIVisualEffectView alloc] initWithEffect:blur];
        effectView.frame = self.bounds;
        effectView.layer.cornerRadius = height / 2;
        effectView.layer.masksToBounds = YES;
        
        UIView *overlayView = [[UIView alloc] initWithFrame:self.bounds];
        overlayView.backgroundColor = [UIColor colorWithWhite:0.3 alpha:0.3];
        overlayView.layer.cornerRadius = height / 2;
        [self addSubview:overlayView];
        
        [self addSubview:effectView];
        
        _messageLabel = [[UILabel alloc] initWithFrame:self.bounds];
        _messageLabel.text = message;
        _messageLabel.textColor = [UIColor whiteColor];
        _messageLabel.font = [UIFont boldSystemFontOfSize:16];
        _messageLabel.textAlignment = NSTextAlignmentCenter;
        [effectView.contentView addSubview:_messageLabel];
        
        self.layer.borderWidth = 0.5;
        self.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.2].CGColor;
        
        _alertWindow = [[AlertWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }
    return self;
}

- (void)show {
    [self.alertWindow addSubview:self];
    [self.alertWindow makeKeyAndVisible];
    
    self.alpha = 0;
    self.transform = CGAffineTransformMakeScale(0.8, 0.8);
    
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 1;
        self.transform = CGAffineTransformIdentity;
    }];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self dismiss];
    });
}

- (void)dismiss {
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 0;
        self.transform = CGAffineTransformMakeScale(0.8, 0.8);
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
        self.alertWindow.hidden = YES;
        self.alertWindow = nil;
    }];
}

@end 