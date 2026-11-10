#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>

@interface MLOverlayView : UIView
@property(nonatomic,strong) CAGradientLayer *gradient;
@property(nonatomic,strong) CAShapeLayer *ringMask;
@property(nonatomic,strong) UILabel *percentLabel;
@end

@implementation MLOverlayView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.userInteractionEnabled = NO;

    CGFloat side = 190;
    CGRect ringRect = CGRectMake(
        (frame.size.width-side)/2,
        (frame.size.height-side)/2,
        side, side
    );

    UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:
        CGRectInset(ringRect, 7, 7)];

    self.ringMask = [CAShapeLayer layer];
    self.ringMask.path = path.CGPath;
    self.ringMask.fillColor = UIColor.clearColor.CGColor;
    self.ringMask.strokeColor = UIColor.whiteColor.CGColor;
    self.ringMask.lineWidth = 5;

    self.gradient = [CAGradientLayer layer];
    self.gradient.frame = self.bounds;
    self.gradient.colors = @[
        (id)[UIColor colorWithRed:0.2 green:0.8 blue:1 alpha:1].CGColor,
        (id)[UIColor colorWithRed:0.55 green:0.3 blue:1 alpha:1].CGColor,
        (id)[UIColor colorWithRed:1 green:0.35 blue:0.65 alpha:1].CGColor
    ];
    self.gradient.startPoint = CGPointMake(0, 0);
    self.gradient.endPoint = CGPointMake(1, 1);
    self.gradient.mask = self.ringMask;
    [self.layer addSublayer:self.gradient];

    self.percentLabel = [[UILabel alloc] initWithFrame:
        CGRectMake(0, CGRectGetMidY(ringRect)-25,
                   frame.size.width, 50)];
    self.percentLabel.textAlignment = NSTextAlignmentCenter;
    self.percentLabel.textColor = UIColor.whiteColor;
    self.percentLabel.font = [UIFont systemFontOfSize:38
                                                weight:UIFontWeightLight];
    [self addSubview:self.percentLabel];

    return self;
}

- (void)setBatteryLevel:(float)level {
    NSInteger percent = (NSInteger)roundf(level * 100);
    self.percentLabel.text = [NSString stringWithFormat:@"%ld%%",
                              (long)percent];
}

@end

static UIWindow *mlWindow;
static MLOverlayView *mlView;

static BOOL MLIsLocked(void) {
    Class cls = NSClassFromString(@"SBLockScreenManager");
    if (!cls) return NO;

    SEL shared = NSSelectorFromString(@"sharedInstance");
    SEL locked = NSSelectorFromString(@"isUILocked");

    if (![cls respondsToSelector:shared]) return NO;

    id manager = ((id (*)(id, SEL))objc_msgSend)(cls, shared);
    if (![manager respondsToSelector:locked]) return NO;

    return ((BOOL (*)(id, SEL))objc_msgSend)(manager, locked);
}

static void MLShowAnimation(void) {
    if (!MLIsLocked()) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!mlWindow) {
            mlWindow = [[UIWindow alloc] initWithFrame:
                        UIScreen.mainScreen.bounds];
            mlWindow.windowLevel = UIWindowLevelAlert + 5;
            mlWindow.userInteractionEnabled = NO;

            UIViewController *controller =
                [UIViewController new];
            controller.view.backgroundColor = UIColor.clearColor;
            mlWindow.rootViewController = controller;

            mlView = [[MLOverlayView alloc]
                initWithFrame:controller.view.bounds];
            mlView.autoresizingMask =
                UIViewAutoresizingFlexibleWidth |
                UIViewAutoresizingFlexibleHeight;

            [controller.view addSubview:mlView];
        }

        [mlView setBatteryLevel:UIDevice.currentDevice.batteryLevel];
        mlWindow.hidden = NO;
        mlView.alpha = 0;
        mlView.transform = CGAffineTransformMakeScale(0.75, 0.75);

        [UIView animateWithDuration:0.65
                              delay:0
             usingSpringWithDamping:0.65
              initialSpringVelocity:0.4
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            mlView.alpha = 1;
            mlView.transform = CGAffineTransformIdentity;
        } completion:nil];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
            (int64_t)(3.5 * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.4 animations:^{
                    mlView.alpha = 0;
                    mlView.transform =
                        CGAffineTransformMakeScale(1.12, 1.12);
                } completion:^(BOOL finished) {
                    mlWindow.hidden = YES;
                }];
            });
    });
}

static void MLStart(void) {
    UIDevice *device = UIDevice.currentDevice;
    device.batteryMonitoringEnabled = YES;

    [[NSNotificationCenter defaultCenter]
        addObserverForName:UIDeviceBatteryStateDidChangeNotification
        object:nil queue:NSOperationQueue.mainQueue
        usingBlock:^(NSNotification *note) {
            if (device.batteryState == UIDeviceBatteryStateCharging) {
                MLShowAnimation();
            }
        }];
}

%ctor {
    if ([NSBundle.mainBundle.bundleIdentifier
         isEqualToString:@"com.apple.springboard"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
            (int64_t)(2 * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{
                MLStart();
            });
    }
}
