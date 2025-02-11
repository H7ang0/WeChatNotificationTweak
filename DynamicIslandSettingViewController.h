#ifndef DYNAMIC_ISLAND_SETTING_VIEW_CONTROLLER_H
#define DYNAMIC_ISLAND_SETTING_VIEW_CONTROLLER_H

#import <UIKit/UIKit.h>
#import "Tweak.h"

@interface DynamicIslandSettingViewController : UIViewController

@property (nonatomic, strong, readwrite) CContact *currentUser;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *settingItems;

+ (BOOL)isDynamicIslandDevice;
- (void)showToast:(NSString *)message;
- (void)updatePreviewPosition:(CGFloat)position;

@end

#endif /* DYNAMIC_ISLAND_SETTING_VIEW_CONTROLLER_H */ 