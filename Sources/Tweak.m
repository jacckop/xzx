#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "WGTranslations.h"

/*
 * WhitegramArabic Safe Runtime v3
 *
 * This build deliberately avoids:
 *   - scanning every Objective-C/Swift class in the app;
 *   - replacing arbitrary setters based only on their selector name;
 *   - hooking NSAttributedString class-cluster initializers.
 *
 * Those broad hooks can corrupt unrelated Telegram objects after login.
 * Only stable UIKit entry points and a small allow-list of Telegram text
 * classes are touched here.
 */

static NSMutableDictionary<NSString *, NSValue *> *WGOriginalIMPs(void) {
    static NSMutableDictionary<NSString *, NSValue *> *table;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        table = [NSMutableDictionary dictionary];
    });
    return table;
}

static NSMutableSet<NSString *> *WGInstalledHooks(void) {
    static NSMutableSet<NSString *> *set;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        set = [NSMutableSet set];
    });
    return set;
}

static NSString *WGHookKey(Class cls, SEL selector) {
    return [NSString stringWithFormat:@"%@::%@", NSStringFromClass(cls), NSStringFromSelector(selector)];
}

static IMP WGFindOriginalIMP(id object, SEL selector) {
    Class cursor = object_getClass(object);
    while (cursor) {
        NSValue *boxed = WGOriginalIMPs()[WGHookKey(cursor, selector)];
        if (boxed) {
            return boxed.pointerValue;
        }
        cursor = class_getSuperclass(cursor);
    }
    return NULL;
}

static BOOL WGMethodIsVoidObjectSetter(Method method) {
    if (!method || method_getNumberOfArguments(method) != 3) {
        return NO;
    }

    char returnType[32] = {0};
    char argumentType[32] = {0};
    method_getReturnType(method, returnType, sizeof(returnType));
    method_getArgumentType(method, 2, argumentType, sizeof(argumentType));

    return returnType[0] == 'v' && argumentType[0] == '@';
}

static BOOL WGReplaceSafeObjectSetter(Class cls, SEL selector, IMP replacement) {
    if (!cls || !selector || !replacement) {
        return NO;
    }

    Method method = class_getInstanceMethod(cls, selector);
    if (!WGMethodIsVoidObjectSetter(method)) {
        return NO;
    }

    NSString *key = WGHookKey(cls, selector);
    @synchronized (WGInstalledHooks()) {
        if ([WGInstalledHooks() containsObject:key]) {
            return YES;
        }

        IMP original = method_getImplementation(method);
        const char *types = method_getTypeEncoding(method);
        if (!original || !types) {
            return NO;
        }

        // Add an override when the method is inherited. Otherwise replace only
        // the implementation owned by this exact class.
        if (!class_addMethod(cls, selector, replacement, types)) {
            class_replaceMethod(cls, selector, replacement, types);
        }

        WGOriginalIMPs()[key] = [NSValue valueWithPointer:original];
        [WGInstalledHooks() addObject:key];
        return YES;
    }
}

static id WGTranslateObject(id value) {
    if ([value isKindOfClass:NSString.class]) {
        return WGArabicTranslateString((NSString *)value);
    }
    if ([value isKindOfClass:NSAttributedString.class]) {
        return WGArabicTranslateAttributedString((NSAttributedString *)value);
    }
    return value;
}

static void WGSafeObjectSetter(id self, SEL _cmd, id value) {
    IMP original = WGFindOriginalIMP(self, _cmd);
    if (!original) {
        return;
    }
    ((void (*)(id, SEL, id))original)(self, _cmd, WGTranslateObject(value));
}

#pragma mark - Stable UIKit hooks

@interface NSBundle (WGArabicSafe)
- (NSString *)wg_safe_localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)tableName;
@end

@implementation NSBundle (WGArabicSafe)
- (NSString *)wg_safe_localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)tableName {
    NSString *result = [self wg_safe_localizedStringForKey:key value:value table:tableName];
    return WGArabicTranslateString(result);
}
@end

@interface UILabel (WGArabicSafe)
- (void)wg_safe_setText:(NSString *)text;
- (void)wg_safe_setAttributedText:(NSAttributedString *)text;
@end

@implementation UILabel (WGArabicSafe)
- (void)wg_safe_setText:(NSString *)text {
    NSString *translated = WGArabicTranslateString(text);
    [self wg_safe_setText:translated];
    if (text && ![translated isEqualToString:text]) {
        self.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
        self.textAlignment = NSTextAlignmentNatural;
    }
}
- (void)wg_safe_setAttributedText:(NSAttributedString *)text {
    NSAttributedString *translated = WGArabicTranslateAttributedString(text);
    [self wg_safe_setAttributedText:translated];
    if (text && ![translated.string isEqualToString:text.string]) {
        self.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
        self.textAlignment = NSTextAlignmentNatural;
    }
}
@end

@interface UIButton (WGArabicSafe)
- (void)wg_safe_setTitle:(NSString *)title forState:(UIControlState)state;
- (void)wg_safe_setAttributedTitle:(NSAttributedString *)title forState:(UIControlState)state;
@end

@implementation UIButton (WGArabicSafe)
- (void)wg_safe_setTitle:(NSString *)title forState:(UIControlState)state {
    NSString *translated = WGArabicTranslateString(title);
    [self wg_safe_setTitle:translated forState:state];
    if (title && ![translated isEqualToString:title]) {
        self.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    }
}
- (void)wg_safe_setAttributedTitle:(NSAttributedString *)title forState:(UIControlState)state {
    NSAttributedString *translated = WGArabicTranslateAttributedString(title);
    [self wg_safe_setAttributedTitle:translated forState:state];
    if (title && ![translated.string isEqualToString:title.string]) {
        self.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    }
}
@end

@interface UITextField (WGArabicSafe)
- (void)wg_safe_setPlaceholder:(NSString *)placeholder;
@end

@implementation UITextField (WGArabicSafe)
- (void)wg_safe_setPlaceholder:(NSString *)placeholder {
    [self wg_safe_setPlaceholder:WGArabicTranslateString(placeholder)];
}
@end

@interface UITextView (WGArabicSafe)
- (void)wg_safe_setText:(NSString *)text;
- (void)wg_safe_setAttributedText:(NSAttributedString *)text;
@end

@implementation UITextView (WGArabicSafe)
- (void)wg_safe_setText:(NSString *)text {
    [self wg_safe_setText:WGArabicTranslateString(text)];
}
- (void)wg_safe_setAttributedText:(NSAttributedString *)text {
    [self wg_safe_setAttributedText:WGArabicTranslateAttributedString(text)];
}
@end

@interface UINavigationItem (WGArabicSafe)
- (void)wg_safe_setTitle:(NSString *)title;
@end

@implementation UINavigationItem (WGArabicSafe)
- (void)wg_safe_setTitle:(NSString *)title {
    [self wg_safe_setTitle:WGArabicTranslateString(title)];
}
@end

@interface UIViewController (WGArabicSafe)
- (void)wg_safe_setTitle:(NSString *)title;
@end

@implementation UIViewController (WGArabicSafe)
- (void)wg_safe_setTitle:(NSString *)title {
    [self wg_safe_setTitle:WGArabicTranslateString(title)];
}
@end

@interface UISearchBar (WGArabicSafe)
- (void)wg_safe_setPlaceholder:(NSString *)placeholder;
@end

@implementation UISearchBar (WGArabicSafe)
- (void)wg_safe_setPlaceholder:(NSString *)placeholder {
    [self wg_safe_setPlaceholder:WGArabicTranslateString(placeholder)];
}
@end

@interface UIAlertController (WGArabicSafe)
+ (instancetype)wg_safe_alertControllerWithTitle:(NSString *)title
                                          message:(NSString *)message
                                   preferredStyle:(UIAlertControllerStyle)preferredStyle;
@end

@implementation UIAlertController (WGArabicSafe)
+ (instancetype)wg_safe_alertControllerWithTitle:(NSString *)title
                                          message:(NSString *)message
                                   preferredStyle:(UIAlertControllerStyle)preferredStyle {
    return [self wg_safe_alertControllerWithTitle:WGArabicTranslateString(title)
                                          message:WGArabicTranslateString(message)
                                   preferredStyle:preferredStyle];
}
@end

@interface UIBarButtonItem (WGArabicSafe)
- (instancetype)wg_safe_initWithTitle:(NSString *)title
                                style:(UIBarButtonItemStyle)style
                               target:(id)target
                               action:(SEL)action;
@end

@implementation UIBarButtonItem (WGArabicSafe)
- (instancetype)wg_safe_initWithTitle:(NSString *)title
                                style:(UIBarButtonItemStyle)style
                               target:(id)target
                               action:(SEL)action {
    return [self wg_safe_initWithTitle:WGArabicTranslateString(title)
                                 style:style
                                target:target
                                action:action];
}
@end

static void WGSwizzle(Class cls, SEL original, SEL replacement) {
    Method originalMethod = class_getInstanceMethod(cls, original);
    Method replacementMethod = class_getInstanceMethod(cls, replacement);
    if (!originalMethod || !replacementMethod) {
        return;
    }

    BOOL added = class_addMethod(cls,
                                 original,
                                 method_getImplementation(replacementMethod),
                                 method_getTypeEncoding(replacementMethod));
    if (added) {
        class_replaceMethod(cls,
                            replacement,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, replacementMethod);
    }
}

static void WGSwizzleClass(Class cls, SEL original, SEL replacement) {
    WGSwizzle(object_getClass(cls), original, replacement);
}

static void WGInstallUIKitHooks(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        WGSwizzle(NSBundle.class,
                  @selector(localizedStringForKey:value:table:),
                  @selector(wg_safe_localizedStringForKey:value:table:));

        WGSwizzle(UILabel.class, @selector(setText:), @selector(wg_safe_setText:));
        WGSwizzle(UILabel.class, @selector(setAttributedText:), @selector(wg_safe_setAttributedText:));

        WGSwizzle(UIButton.class, @selector(setTitle:forState:), @selector(wg_safe_setTitle:forState:));
        WGSwizzle(UIButton.class,
                  @selector(setAttributedTitle:forState:),
                  @selector(wg_safe_setAttributedTitle:forState:));

        WGSwizzle(UITextField.class, @selector(setPlaceholder:), @selector(wg_safe_setPlaceholder:));
        WGSwizzle(UITextView.class, @selector(setText:), @selector(wg_safe_setText:));
        WGSwizzle(UITextView.class, @selector(setAttributedText:), @selector(wg_safe_setAttributedText:));
        WGSwizzle(UINavigationItem.class, @selector(setTitle:), @selector(wg_safe_setTitle:));
        WGSwizzle(UIViewController.class, @selector(setTitle:), @selector(wg_safe_setTitle:));
        WGSwizzle(UISearchBar.class, @selector(setPlaceholder:), @selector(wg_safe_setPlaceholder:));

        WGSwizzleClass(UIAlertController.class,
                       @selector(alertControllerWithTitle:message:preferredStyle:),
                       @selector(wg_safe_alertControllerWithTitle:message:preferredStyle:));

        WGSwizzle(UIBarButtonItem.class,
                  @selector(initWithTitle:style:target:action:),
                  @selector(wg_safe_initWithTitle:style:target:action:));
    });
}


#pragma mark - Targeted NSAttributedString class-cluster hooks

/*
 * Whitegram's settings screen stores most visible text directly in Swift
 * TextNode properties. Those properties do not expose Objective-C setters,
 * so UIKit hooks never see them. The stable interception point is the
 * concrete Foundation attributed-string initializer used before assignment.
 *
 * We hook only the concrete immutable/mutable classes returned by Foundation,
 * verify exact signatures, and translate only strings present in our map.
 */

static id WGAttributedInitString(id self, SEL _cmd, NSString *string) {
    IMP original = WGFindOriginalIMP(self, _cmd);
    if (!original) return nil;
    NSString *translated = WGArabicTranslateString(string);
    return ((id (*)(id, SEL, NSString *))original)(self, _cmd, translated);
}

static id WGAttributedInitStringAttributes(id self, SEL _cmd, NSString *string, NSDictionary *attributes) {
    IMP original = WGFindOriginalIMP(self, _cmd);
    if (!original) return nil;
    NSString *translated = WGArabicTranslateString(string);
    return ((id (*)(id, SEL, NSString *, NSDictionary *))original)(self, _cmd, translated, attributes);
}

static BOOL WGMethodMatchesAttributedInit(Method method, NSUInteger argumentCount) {
    if (!method || method_getNumberOfArguments(method) != argumentCount) return NO;
    char returnType[32] = {0};
    char argType[32] = {0};
    method_getReturnType(method, returnType, sizeof(returnType));
    method_getArgumentType(method, 2, argType, sizeof(argType));
    return returnType[0] == '@' && argType[0] == '@';
}

static BOOL WGReplaceAttributedInitializer(Class cls, SEL selector, IMP replacement, NSUInteger argumentCount) {
    if (!cls || !selector || !replacement) return NO;
    Method method = class_getInstanceMethod(cls, selector);
    if (!WGMethodMatchesAttributedInit(method, argumentCount)) return NO;

    NSString *key = WGHookKey(cls, selector);
    @synchronized (WGInstalledHooks()) {
        if ([WGInstalledHooks() containsObject:key]) return YES;
        IMP original = method_getImplementation(method);
        const char *types = method_getTypeEncoding(method);
        if (!original || !types) return NO;
        if (!class_addMethod(cls, selector, replacement, types)) {
            class_replaceMethod(cls, selector, replacement, types);
        }
        WGOriginalIMPs()[key] = [NSValue valueWithPointer:original];
        [WGInstalledHooks() addObject:key];
        return YES;
    }
}

static void WGInstallAttributedStringHooks(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSAttributedString *immutableA = [[NSAttributedString alloc] initWithString:@"WGProbe"];
        NSAttributedString *immutableB = [[NSAttributedString alloc] initWithString:@"WGProbe" attributes:@{}];
        NSMutableAttributedString *mutableA = [[NSMutableAttributedString alloc] initWithString:@"WGProbe"];
        NSMutableAttributedString *mutableB = [[NSMutableAttributedString alloc] initWithString:@"WGProbe" attributes:@{}];

        NSArray<Class> *classes = @[
            [immutableA class],
            [immutableB class],
            [mutableA class],
            [mutableB class]
        ];

        NSMutableSet<NSString *> *seen = [NSMutableSet set];
        for (Class cls in classes) {
            NSString *name = NSStringFromClass(cls);
            if (!cls || [seen containsObject:name]) continue;
            [seen addObject:name];
            WGReplaceAttributedInitializer(cls,
                                           @selector(initWithString:),
                                           (IMP)WGAttributedInitString,
                                           3);
            WGReplaceAttributedInitializer(cls,
                                           @selector(initWithString:attributes:),
                                           (IMP)WGAttributedInitStringAttributes,
                                           4);
        }
    });
}

#pragma mark - Allow-listed Telegram text classes

static void WGHookClassSetter(const char *className, const char *selectorName) {
    Class cls = objc_getClass(className);
    if (!cls) {
        return;
    }
    WGReplaceSafeObjectSetter(cls, sel_registerName(selectorName), (IMP)WGSafeObjectSetter);
}

static void WGInstallTelegramTextHooks(void) {
    // Exact Objective-C runtime names found in Telegram/Whitegram 12.8.
    // No generic class enumeration is performed.
    const char *classes[] = {
        "_TtC7Display17ImmediateTextNode",
        "_TtC20TextNodeWithEntities29ImmediateTextNodeWithEntities",
        "ASTextNode",
        "ASTextNode2",
    };

    const char *selectors[] = {
        "setAttributedText:",
        "setText:",
    };

    for (size_t i = 0; i < sizeof(classes) / sizeof(classes[0]); i++) {
        for (size_t j = 0; j < sizeof(selectors) / sizeof(selectors[0]); j++) {
            WGHookClassSetter(classes[i], selectors[j]);
        }
    }
}

static void WGInstallAllHooks(void) {
    WGInstallUIKitHooks();
    WGInstallAttributedStringHooks();
    WGInstallTelegramTextHooks();
}

__attribute__((constructor))
static void WGArabicSafeEntryPoint(void) {
    @autoreleasepool {
        WGInstallAllHooks();

        // Some Swift classes may be registered after the injected dylib's
        // constructor. Retry only the fixed allow-list; never scan the app.
        dispatch_async(dispatch_get_main_queue(), ^{
            WGInstallTelegramTextHooks();
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                WGInstallTelegramTextHooks();
            });
        });
    }
}
