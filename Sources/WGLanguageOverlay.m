#import "WGLanguageOverlay.h"
#import "WGTranslations.h"
#import <UIKit/UIKit.h>

static NSString * const WGBubbleXDefaultsKey = @"WGOverlayBubbleX";
static NSString * const WGBubbleYDefaultsKey = @"WGOverlayBubbleY";

@interface WGNoTranslateLabel : UILabel
@end
@implementation WGNoTranslateLabel
@end

@interface WGNoTranslateButton : UIButton
@end
@implementation WGNoTranslateButton
@end

@interface WGPassThroughWindow : UIWindow
@end

@implementation WGPassThroughWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self || hit == self.rootViewController.view) {
        return nil;
    }
    return hit;
}
@end

@interface WGOverlayRootController : UIViewController
@end
@implementation WGOverlayRootController
- (BOOL)shouldAutorotate { return YES; }
- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleDefault; }
@end

@interface WGLanguageOverlayManager : NSObject
@property (nonatomic, strong) WGPassThroughWindow *window;
@property (nonatomic, strong) UIView *bubble;
@property (nonatomic, strong) UIImageView *bubbleIcon;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UIVisualEffectView *panelBlur;
@property (nonatomic, strong) UIStackView *languageStack;
@property (nonatomic, strong) WGNoTranslateLabel *panelTitle;
@property (nonatomic, strong) WGNoTranslateButton *creditButton;
@property (nonatomic, strong) NSMutableDictionary<NSString *, WGNoTranslateButton *> *languageButtons;
@property (nonatomic, assign) BOOL panelOpen;
@property (nonatomic, assign) BOOL installed;
@property (nonatomic, assign) CGPoint dragStartCenter;
+ (instancetype)shared;
- (void)install;
- (void)refresh;
@end

@implementation WGLanguageOverlayManager

+ (instancetype)shared {
    static WGLanguageOverlayManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [WGLanguageOverlayManager new];
        manager.languageButtons = [NSMutableDictionary dictionary];
    });
    return manager;
}

- (UIWindowScene *)activeWindowScene API_AVAILABLE(ios(13.0)) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class] &&
            scene.activationState == UISceneActivationStateForegroundActive) {
            return (UIWindowScene *)scene;
        }
    }
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class]) {
            return (UIWindowScene *)scene;
        }
    }
    return nil;
}

- (void)install {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self install]; });
        return;
    }

    if (self.installed && self.window) {
        self.window.hidden = NO;
        [self refresh];
        return;
    }

    CGRect bounds = UIScreen.mainScreen.bounds;
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = [self activeWindowScene];
        if (!scene) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ [self install]; });
            return;
        }
        self.window = [[WGPassThroughWindow alloc] initWithWindowScene:scene];
        self.window.frame = scene.coordinateSpace.bounds;
    } else {
        self.window = [[WGPassThroughWindow alloc] initWithFrame:bounds];
    }

    self.window.windowLevel = UIWindowLevelAlert + 35.0;
    self.window.backgroundColor = UIColor.clearColor;
    self.window.rootViewController = [WGOverlayRootController new];
    self.window.rootViewController.view.backgroundColor = UIColor.clearColor;
    self.window.hidden = NO;

    [self buildBubble];
    [self buildPanel];
    self.installed = YES;
    [self restoreBubblePosition];
    [self refresh];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(languageDidChange:)
                                               name:WGLanguageDidChangeNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(applicationDidBecomeActive:)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(orientationDidChange:)
                                               name:UIDeviceOrientationDidChangeNotification
                                             object:nil];
}

- (void)buildBubble {
    UIView *root = self.window.rootViewController.view;
    UIView *bubble = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 56, 56)];
    bubble.layer.cornerRadius = 28;
    bubble.layer.shadowColor = UIColor.blackColor.CGColor;
    bubble.layer.shadowOpacity = 0.24;
    bubble.layer.shadowRadius = 10;
    bubble.layer.shadowOffset = CGSizeMake(0, 4);
    bubble.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    bubble.clipsToBounds = NO;
    bubble.accessibilityLabel = @"Whitegram language selector";
    bubble.accessibilityTraits = UIAccessibilityTraitButton;

    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:23
                                                                                                  weight:UIImageSymbolWeightSemibold];
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"globe" withConfiguration:configuration]];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.userInteractionEnabled = NO;
    icon.frame = CGRectMake(14, 14, 28, 28);
    [bubble addSubview:icon];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(bubbleTapped:)];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(bubblePanned:)];
    [bubble addGestureRecognizer:tap];
    [bubble addGestureRecognizer:pan];

    [root addSubview:bubble];
    self.bubble = bubble;
    self.bubbleIcon = icon;
}

- (void)buildPanel {
    UIView *root = self.window.rootViewController.view;
    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 310, 398)];
    panel.layer.cornerRadius = 26;
    panel.layer.cornerCurve = kCACornerCurveContinuous;
    panel.layer.shadowColor = UIColor.blackColor.CGColor;
    panel.layer.shadowOpacity = 0.28;
    panel.layer.shadowRadius = 24;
    panel.layer.shadowOffset = CGSizeMake(0, 10);
    panel.clipsToBounds = NO;
    panel.alpha = 0;
    panel.hidden = YES;

    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blur.frame = panel.bounds;
    blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blur.layer.cornerRadius = 26;
    blur.layer.cornerCurve = kCACornerCurveContinuous;
    blur.clipsToBounds = YES;
    [panel addSubview:blur];
    self.panelBlur = blur;

    UIView *content = blur.contentView;

    WGNoTranslateLabel *title = [[WGNoTranslateLabel alloc] initWithFrame:CGRectMake(20, 14, 270, 32)];
    title.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    title.textAlignment = NSTextAlignmentCenter;
    [content addSubview:title];
    self.panelTitle = title;

    UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(16, 52, 278, 1.0 / UIScreen.mainScreen.scale)];
    separator.backgroundColor = [UIColor separatorColor];
    [content addSubview:separator];

    UIStackView *stack = [[UIStackView alloc] initWithFrame:CGRectMake(12, 60, 286, 270)];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.spacing = 2;
    [content addSubview:stack];
    self.languageStack = stack;

    NSArray<NSDictionary<NSString *, NSString *> *> *languages = @[
        @{@"code": @"ar", @"title": @"🇮🇶  العربية"},
        @{@"code": @"en", @"title": @"🇬🇧  English"},
        @{@"code": @"es", @"title": @"🇪🇸  Español"},
        @{@"code": @"fa", @"title": @"🇮🇷  فارسی"},
        @{@"code": @"fr", @"title": @"🇫🇷  Français"},
        @{@"code": @"pt", @"title": @"🇵🇹  Português"},
    ];

    for (NSDictionary<NSString *, NSString *> *language in languages) {
        WGNoTranslateButton *button = [WGNoTranslateButton buttonWithType:UIButtonTypeSystem];
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
        button.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        button.layer.cornerRadius = 14;
        button.layer.cornerCurve = kCACornerCurveContinuous;
        button.tag = languages.count;
        button.accessibilityIdentifier = language[@"code"];
        [button addTarget:self action:@selector(languageButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:button];
        self.languageButtons[language[@"code"]] = button;
        [self configureLanguageButton:button title:language[@"title"] selected:NO];
    }

    UIView *bottomSeparator = [[UIView alloc] initWithFrame:CGRectMake(16, 338, 278, 1.0 / UIScreen.mainScreen.scale)];
    bottomSeparator.backgroundColor = [UIColor separatorColor];
    [content addSubview:bottomSeparator];

    WGNoTranslateButton *credit = [WGNoTranslateButton buttonWithType:UIButtonTypeSystem];
    credit.frame = CGRectMake(20, 346, 270, 40);
    credit.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [credit setTitle:@"@iKiraPlus" forState:UIControlStateNormal];
    UIImageSymbolConfiguration *creditConfig = [UIImageSymbolConfiguration configurationWithPointSize:17
                                                                                                 weight:UIImageSymbolWeightSemibold];
    [credit setImage:[UIImage systemImageNamed:@"paperplane.fill" withConfiguration:creditConfig]
            forState:UIControlStateNormal];
    credit.imageEdgeInsets = UIEdgeInsetsMake(0, -6, 0, 6);
    credit.accessibilityLabel = @"Open @iKiraPlus on Telegram";
    [credit addTarget:self action:@selector(openTelegramCredit:) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:credit];
    self.creditButton = credit;

    [root addSubview:panel];
    self.panel = panel;
}

- (void)configureLanguageButton:(WGNoTranslateButton *)button
                          title:(NSString *)title
                       selected:(BOOL)selected {
    UIColor *foreground = selected ? UIColor.whiteColor : UIColor.labelColor;
    UIColor *background = selected ? [UIColor systemBlueColor] : UIColor.clearColor;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:foreground forState:UIControlStateNormal];
    button.backgroundColor = background;

    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:15
                                                                                                  weight:UIImageSymbolWeightBold];
    UIImage *image = selected ? [UIImage systemImageNamed:@"checkmark.circle.fill" withConfiguration:configuration] : nil;
    [button setImage:image forState:UIControlStateNormal];
    button.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    button.imageEdgeInsets = selected ? UIEdgeInsetsMake(0, 10, 0, -10) : UIEdgeInsetsZero;
    button.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
}

- (NSString *)localizedPanelTitle {
    NSDictionary<NSString *, NSString *> *titles = @{
        @"ar": @"لغة واجهة وايت كرام",
        @"en": @"Whitegram Interface Language",
        @"es": @"Idioma de la interfaz de Whitegram",
        @"fa": @"زبان رابط وایت‌گرام",
        @"fr": @"Langue de l’interface Whitegram",
        @"pt": @"Idioma da interface do Whitegram",
    };
    return titles[WGSelectedLanguageCode()] ?: titles[@"ar"];
}

- (void)refresh {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self refresh]; });
        return;
    }
    if (!self.installed) {
        [self install];
        return;
    }

    BOOL dark = self.window.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    self.bubble.backgroundColor = dark ? [UIColor colorWithWhite:0.12 alpha:0.94]
                                       : [UIColor colorWithWhite:1.0 alpha:0.96];
    self.bubble.layer.borderColor = [UIColor separatorColor].CGColor;
    self.bubbleIcon.tintColor = dark ? UIColor.whiteColor : UIColor.blackColor;
    self.panelTitle.text = [self localizedPanelTitle];
    self.panelTitle.textColor = UIColor.labelColor;
    self.creditButton.tintColor = [UIColor systemBlueColor];

    NSString *selectedCode = WGSelectedLanguageCode();
    NSDictionary<NSString *, NSString *> *titles = @{
        @"ar": @"🇮🇶  العربية",
        @"en": @"🇬🇧  English",
        @"es": @"🇪🇸  Español",
        @"fa": @"🇮🇷  فارسی",
        @"fr": @"🇫🇷  Français",
        @"pt": @"🇵🇹  Português",
    };
    [self.languageButtons enumerateKeysAndObjectsUsingBlock:^(NSString *code,
                                                               WGNoTranslateButton *button,
                                                               BOOL *stop) {
        [self configureLanguageButton:button
                                title:titles[code]
                             selected:[code isEqualToString:selectedCode]];
    }];
    [self constrainBubbleToSafeAreaAnimated:NO];
    if (self.panelOpen) {
        [self positionPanel];
    }
}

- (void)restoreBubblePosition {
    UIView *root = self.window.rootViewController.view;
    [root layoutIfNeeded];
    CGFloat width = CGRectGetWidth(root.bounds);
    CGFloat height = CGRectGetHeight(root.bounds);
    double storedX = [NSUserDefaults.standardUserDefaults doubleForKey:WGBubbleXDefaultsKey];
    double storedY = [NSUserDefaults.standardUserDefaults doubleForKey:WGBubbleYDefaultsKey];
    if (storedX <= 0.0 || storedY <= 0.0) {
        self.bubble.center = CGPointMake(width - 42.0, height * 0.62);
    } else {
        self.bubble.center = CGPointMake(width * storedX, height * storedY);
    }
    [self constrainBubbleToSafeAreaAnimated:NO];
}

- (UIEdgeInsets)currentSafeInsets {
    return self.window.safeAreaInsets;
}

- (CGRect)allowedBubbleRect {
    UIEdgeInsets safe = [self currentSafeInsets];
    CGFloat radius = CGRectGetWidth(self.bubble.bounds) / 2.0;
    CGFloat margin = 8.0;
    return CGRectMake(safe.left + radius + margin,
                      safe.top + radius + margin,
                      MAX(1.0, CGRectGetWidth(self.window.bounds) - safe.left - safe.right - 2.0 * (radius + margin)),
                      MAX(1.0, CGRectGetHeight(self.window.bounds) - safe.top - safe.bottom - 2.0 * (radius + margin)));
}

- (CGPoint)clampedCenter:(CGPoint)center {
    CGRect allowed = [self allowedBubbleRect];
    center.x = MIN(MAX(center.x, CGRectGetMinX(allowed)), CGRectGetMaxX(allowed));
    center.y = MIN(MAX(center.y, CGRectGetMinY(allowed)), CGRectGetMaxY(allowed));
    return center;
}

- (void)constrainBubbleToSafeAreaAnimated:(BOOL)animated {
    CGPoint center = [self clampedCenter:self.bubble.center];
    void (^changes)(void) = ^{
        self.bubble.center = center;
        if (self.panelOpen) {
            [self positionPanel];
        }
    };
    if (animated) {
        [UIView animateWithDuration:0.25
                              delay:0
             usingSpringWithDamping:0.78
              initialSpringVelocity:0.4
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}

- (void)persistBubblePosition {
    CGFloat width = MAX(1.0, CGRectGetWidth(self.window.bounds));
    CGFloat height = MAX(1.0, CGRectGetHeight(self.window.bounds));
    [NSUserDefaults.standardUserDefaults setDouble:self.bubble.center.x / width forKey:WGBubbleXDefaultsKey];
    [NSUserDefaults.standardUserDefaults setDouble:self.bubble.center.y / height forKey:WGBubbleYDefaultsKey];
}

- (void)bubbleTapped:(UITapGestureRecognizer *)recognizer {
    [self setPanelOpen:!self.panelOpen animated:YES];
}

- (void)bubblePanned:(UIPanGestureRecognizer *)recognizer {
    UIView *root = self.window.rootViewController.view;
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        self.dragStartCenter = self.bubble.center;
        [self setPanelOpen:NO animated:YES];
        [UIView animateWithDuration:0.15 animations:^{
            self.bubble.transform = CGAffineTransformMakeScale(1.08, 1.08);
        }];
    }

    CGPoint translation = [recognizer translationInView:root];
    if (recognizer.state == UIGestureRecognizerStateChanged) {
        self.bubble.center = [self clampedCenter:CGPointMake(self.dragStartCenter.x + translation.x,
                                                            self.dragStartCenter.y + translation.y)];
    }

    if (recognizer.state == UIGestureRecognizerStateEnded ||
        recognizer.state == UIGestureRecognizerStateCancelled) {
        CGRect allowed = [self allowedBubbleRect];
        CGPoint center = [self clampedCenter:self.bubble.center];
        CGFloat midpoint = CGRectGetMidX(self.window.bounds);
        center.x = center.x < midpoint ? CGRectGetMinX(allowed) : CGRectGetMaxX(allowed);
        [UIView animateWithDuration:0.28
                              delay:0
             usingSpringWithDamping:0.78
              initialSpringVelocity:0.6
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.bubble.center = center;
            self.bubble.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            [self persistBubblePosition];
        }];
    }
}

- (void)positionPanel {
    CGFloat panelWidth = CGRectGetWidth(self.panel.bounds);
    CGFloat panelHeight = CGRectGetHeight(self.panel.bounds);
    CGFloat margin = 12.0;
    UIEdgeInsets safe = [self currentSafeInsets];
    CGRect usable = UIEdgeInsetsInsetRect(self.window.bounds,
                                           UIEdgeInsetsMake(safe.top + 8,
                                                            safe.left + 8,
                                                            safe.bottom + 8,
                                                            safe.right + 8));

    BOOL bubbleOnLeft = self.bubble.center.x < CGRectGetMidX(self.window.bounds);
    CGFloat x = bubbleOnLeft
        ? CGRectGetMaxX(self.bubble.frame) + margin
        : CGRectGetMinX(self.bubble.frame) - margin - panelWidth;

    if (x < CGRectGetMinX(usable)) {
        x = CGRectGetMinX(usable);
    }
    if (x + panelWidth > CGRectGetMaxX(usable)) {
        x = CGRectGetMaxX(usable) - panelWidth;
    }

    CGFloat y = self.bubble.center.y - panelHeight / 2.0;
    y = MIN(MAX(y, CGRectGetMinY(usable)), CGRectGetMaxY(usable) - panelHeight);
    self.panel.frame = CGRectMake(x, y, panelWidth, panelHeight);
}

- (void)setPanelOpen:(BOOL)open animated:(BOOL)animated {
    if (self.panelOpen == open && self.panel.hidden == !open) {
        return;
    }
    self.panelOpen = open;
    if (open) {
        [self positionPanel];
        self.panel.hidden = NO;
        self.panel.alpha = 0;
        self.panel.transform = CGAffineTransformMakeScale(0.90, 0.90);
    }

    void (^changes)(void) = ^{
        self.panel.alpha = open ? 1.0 : 0.0;
        self.panel.transform = open ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.92, 0.92);
        self.bubble.transform = open ? CGAffineTransformMakeScale(0.94, 0.94) : CGAffineTransformIdentity;
    };
    void (^completion)(BOOL) = ^(BOOL finished) {
        if (!open) {
            self.panel.hidden = YES;
            self.panel.transform = CGAffineTransformIdentity;
        }
    };

    if (animated) {
        [UIView animateWithDuration:0.25
                              delay:0
             usingSpringWithDamping:0.86
              initialSpringVelocity:0.3
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:changes
                         completion:completion];
    } else {
        changes();
        completion(YES);
    }
}

- (void)languageButtonTapped:(WGNoTranslateButton *)button {
    NSString *code = button.accessibilityIdentifier;
    if (code.length == 0) {
        return;
    }
    WGSetSelectedLanguageCode(code);
    [self refresh];
    [self setPanelOpen:NO animated:YES];

    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
}

- (void)openTelegramCredit:(id)sender {
    NSURL *appURL = [NSURL URLWithString:@"tg://resolve?domain=iKiraPlus"];
    NSURL *webURL = [NSURL URLWithString:@"https://t.me/iKiraPlus"];
    UIApplication *application = UIApplication.sharedApplication;
    if ([application canOpenURL:appURL]) {
        [application openURL:appURL options:@{} completionHandler:nil];
    } else {
        [application openURL:webURL options:@{} completionHandler:nil];
    }
}

- (void)languageDidChange:(NSNotification *)notification {
    [self refresh];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    self.window.hidden = NO;
    [self refresh];
}

- (void)orientationDidChange:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (@available(iOS 13.0, *)) {
            UIWindowScene *scene = [self activeWindowScene];
            if (scene) {
                self.window.frame = scene.coordinateSpace.bounds;
            }
        } else {
            self.window.frame = UIScreen.mainScreen.bounds;
        }
        [self constrainBubbleToSafeAreaAnimated:YES];
    });
}

@end

void WGInstallLanguageOverlay(void) {
    [[WGLanguageOverlayManager shared] install];
}

void WGRefreshLanguageOverlay(void) {
    [[WGLanguageOverlayManager shared] refresh];
}
