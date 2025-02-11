#import <UIKit/UIKit.h>

@interface AlertWindow : UIWindow
@end

@interface CustomToastView : UIView
+ (void)showToast:(NSString *)message;
@end 