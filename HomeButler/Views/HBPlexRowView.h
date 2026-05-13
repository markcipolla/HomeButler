#import <UIKit/UIKit.h>

@class HBPlexItem;
@class HBPlexRowView;

@protocol HBPlexRowViewDelegate <NSObject>
- (void)plexRowView:(HBPlexRowView *)row didTapItem:(HBPlexItem *)item;
@optional
- (void)plexRowViewDidTapHeader:(HBPlexRowView *)row;
@end

@interface HBPlexRowView : UIView

@property (nonatomic, copy)   NSString *title;
@property (nonatomic, copy)   NSString *sectionID; // for library-section rows
@property (nonatomic, strong) NSArray *items;
@property (nonatomic, weak)   id<HBPlexRowViewDelegate> delegate;

- (instancetype)initWithFrame:(CGRect)frame;
- (void)setItems:(NSArray *)items;

@end
