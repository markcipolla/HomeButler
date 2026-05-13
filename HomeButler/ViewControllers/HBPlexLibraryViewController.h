#import <UIKit/UIKit.h>
#import "HBRefreshable.h"

@interface HBPlexLibraryViewController : UIViewController <HBRefreshable>

- (instancetype)initWithSectionID:(NSString *)sectionID title:(NSString *)title;

@end
