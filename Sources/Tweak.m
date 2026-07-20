#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "WGTranslations.h"

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
    Class cls = object_getClass(object);
    if (!cls) {
        return NULL;
    }

    BOOL isMeta = class_isMetaClass(cls);
    Class cursor = cls;
    while (cursor) {
        NSValue *boxed = WGOriginalIMPs()[WGHookKey(cursor, selector)];
        if (boxed) {
            return boxed.pointerValue;
        }
        cursor = class_getSuperclass(cursor);
    }

    if (!isMeta) {
        cursor = [object class];
        while (cursor) {
            NSValue *boxed = WGOriginalIMPs()[WGHookKey(cursor, selector)];
            if (boxed) {
                return boxed.pointerValue;
            }
            cursor = class_getSuperclass(cursor);
        }
    }

    return NULL;
}

static BOOL WGMethodAcceptsObject(Method method, NSUInteger expectedArguments) {
    if (!method || method_getNumberOfArguments(method) != expectedArguments) {
        return NO;
    }

    char type[64] = {0};
    method_getArgumentType(method, 2, type, sizeof(type));
    return type[0] == '@';
}

static BOOL WGReplaceInstanceMethod(Class cls, SEL selector, IMP replacement, NSUInteger expectedArguments) {
    if (!cls || !selector || !replacement) {
        return NO;
    }

    NSString *key = WGHookKey(cls, selector);
    @synchronized (WGInstalledHooks()) {
        if ([WGInstalledHooks() containsObject:key]) {
            return YES;
        }

        Method method = class_getInstanceMethod(cls, selector);
        if (!WGMethodAcceptsObject(method, expectedArguments)) {
            return NO;
        }

        IMP original = method_getImplementation(method);
        const char *types = method_getTypeEncoding(method);
        if (!original || !types) {
            return NO;
        }

        if (!class_addMethod(cls, selector, replacement, types)) {
            class_replaceMethod(cls, selector, replacement, types);
        }

        WGOriginalIMPs()[key] = [NSValue valueWithPointer:original];
        [WGInstalledHooks() addObject:key];
        return YES;
    }
}

static BOOL WGReplaceClassMethod(Class cls, SEL selector, IMP replacement, NSUInteger expectedArguments) {
    return WGReplaceInstanceMethod(object_getClass(cls), selector, replacement, expectedArguments);
}

static id WGTranslateObject(id value) {
    if ([value isKindOfClass:NSString.class]) {
        return WGArabicTranslateString(value);
    }
    if ([value isKindOfClass:NSAttributedString.class]) {
        return WGArabicTranslateAttributedString(value);
    }
    return value;
}

static void WGGenericObjectSetter(id self, SEL _cmd, id value) {
    IMP original = WGFindOriginalIMP(self, _cmd);
    if (!original) {
        return;
    }
    ((void (*)(id, SEL, id))original)(self, _cmd, WGTranslateObject(value));
}

static id WGGenericInitWithString(id self, SEL _cmd, NSString *string) {
    IMP original = WGFindOriginalIMP(self, _cmd);
    if (!original) {
        return nil;
    }
    return ((id (*)(id, SEL, NSString *))original)(self, _cmd, WGArabicTranslateString(string));
}

static id WGGenericInitWithStringAttributes(id self, SEL _cmd, NSString *string, NSDictionary *attributes) {
    IMP original = WGFindOriginalIMP(self, _cmd);
    if (!original) {
        return nil;
    }
    return ((id (*)(id, SEL, NSString *, NSDictionary *))original)(
        self,
        _cmd,
        WGArabicTranslateString(string),
        attributes
    );
}

static void WGGenericReplaceCharacters(id self, SEL _cmd, NSRange range, NSString *string) {
    IMP original = WGFindOriginalIMP(self, _cmd);
    if (!original) {
        return;
    }
    ((void (*)(id, SEL, NSRange, NSString *))original)(self, _cmd, range, WGArabicTranslateString(string));
}

#pragma mark - UIKit hooks

@interface NSBundle (WGArabic)
- (NSString *)wg_localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)tableName;
@end

@implementation NSBundle (WGArabic)
- (NSString *)wg_localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)tableName {
    NSString *result = [self wg_localizedStringForKey:key value:value table:tableName];
    return WGArabicTranslateString(result);
}
@end

@interface UILabel (WGArabic)
- (void)wg_setText:(NSString *)text;
- (void)wg_setAttributedText:(NSAttributedString *)text;
@end

@implementation UILabel (WGArabic)
- (void)wg_setText:(NSString *)text {
    NSString *translated = WGArabicTranslateString(text);
    [self wg_setText:translated];
    if (![translated isEqualToString:text]) {
        self.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    }
}
- (void)wg_setAttributedText:(NSAttributedString *)text {
    NSAttributedString *translated = WGArabicTranslateAttributedString(text);
    [self wg_setAttributedText:translated];
    if (![translated.string isEqualToString:text.string]) {
        self.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    }
}
@end

@interface UIButton (WGArabic)
- (void)wg_setTitle:(NSString *)title forState:(UIControlState)state;
- (void)wg_setAttributedTitle:(NSAttributedString *)title forState:(UIControlState)state;
@end

@implementation UIButton (WGArabic)
- (void)wg_setTitle:(NSString *)title forState:(UIControlState)state {
    NSString *translated = WGArabicTranslateString(title);
    [self wg_setTitle:translated forState:state];
    if (![translated isEqualToString:title]) {
        self.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    }
}
- (void)wg_setAttributedTitle:(NSAttributedString *)title forState:(UIControlState)state {
    NSAttributedString *translated = WGArabicTranslateAttributedString(title);
    [self wg_setAttributedTitle:translated forState:state];
    if (![translated.string isEqualToString:title.string]) {
        self.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    }
}
@end

@interface UITextField (WGArabic)
- (void)wg_setPlaceholder:(NSString *)placeholder;
- (void)wg_setText:(NSString *)text;
- (void)wg_setAttributedText:(NSAttributedString *)text;
@end

@implementation UITextField (WGArabic)
- (void)wg_setPlaceholder:(NSString *)placeholder {
    [self wg_setPlaceholder:WGArabicTranslateString(placeholder)];
}
- (void)wg_setText:(NSString *)text {
    [self wg_setText:WGArabicTranslateString(text)];
}
- (void)wg_setAttributedText:(NSAttributedString *)text {
    [self wg_setAttributedText:WGArabicTranslateAttributedString(text)];
}
@end

@interface UITextView (WGArabic)
- (void)wg_setText:(NSString *)text;
- (void)wg_setAttributedText:(NSAttributedString *)text;
@end

@implementation UITextView (WGArabic)
- (void)wg_setText:(NSString *)text {
    [self wg_setText:WGArabicTranslateString(text)];
}
- (void)wg_setAttributedText:(NSAttributedString *)text {
    [self wg_setAttributedText:WGArabicTranslateAttributedString(text)];
}
@end

@interface UINavigationItem (WGArabic)
- (void)wg_setTitle:(NSString *)title;
@end

@implementation UINavigationItem (WGArabic)
- (void)wg_setTitle:(NSString *)title {
    [self wg_setTitle:WGArabicTranslateString(title)];
}
@end

@interface UIViewController (WGArabic)
- (void)wg_setTitle:(NSString *)title;
@end

@implementation UIViewController (WGArabic)
- (void)wg_setTitle:(NSString *)title {
    [self wg_setTitle:WGArabicTranslateString(title)];
}
@end

@interface UISearchBar (WGArabic)
- (void)wg_setPlaceholder:(NSString *)placeholder;
@end

@implementation UISearchBar (WGArabic)
- (void)wg_setPlaceholder:(NSString *)placeholder {
    [self wg_setPlaceholder:WGArabicTranslateString(placeholder)];
}
@end

@interface UIAlertController (WGArabic)
+ (instancetype)wg_alertControllerWithTitle:(NSString *)title
                                    message:(NSString *)message
                             preferredStyle:(UIAlertControllerStyle)preferredStyle;
@end

@implementation UIAlertController (WGArabic)
+ (instancetype)wg_alertControllerWithTitle:(NSString *)title
                                    message:(NSString *)message
                             preferredStyle:(UIAlertControllerStyle)preferredStyle {
    return [self wg_alertControllerWithTitle:WGArabicTranslateString(title)
                                     message:WGArabicTranslateString(message)
                              preferredStyle:preferredStyle];
}
@end

@interface UIBarButtonItem (WGArabic)
- (instancetype)wg_initWithTitle:(NSString *)title
                           style:(UIBarButtonItemStyle)style
                          target:(id)target
                          action:(SEL)action;
@end

@implementation UIBarButtonItem (WGArabic)
- (instancetype)wg_initWithTitle:(NSString *)title
                           style:(UIBarButtonItemStyle)style
                          target:(id)target
                          action:(SEL)action {
    return [self wg_initWithTitle:WGArabicTranslateString(title) style:style target:target action:action];
}
@end

static void WGSwizzle(Class cls, SEL original, SEL replacement) {
    Method originalMethod = class_getInstanceMethod(cls, original);
    Method replacementMethod = class_getInstanceMethod(cls, replacement);
    if (!originalMethod || !replacementMethod) {
        return;
    }

    BOOL added = class_addMethod(
        cls,
        original,
        method_getImplementation(replacementMethod),
        method_getTypeEncoding(replacementMethod)
    );

    if (added) {
        class_replaceMethod(
            cls,
            replacement,
            method_getImplementation(originalMethod),
            method_getTypeEncoding(originalMethod)
        );
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
                  @selector(wg_localizedStringForKey:value:table:));

        WGSwizzle(UILabel.class, @selector(setText:), @selector(wg_setText:));
        WGSwizzle(UILabel.class, @selector(setAttributedText:), @selector(wg_setAttributedText:));

        WGSwizzle(UIButton.class, @selector(setTitle:forState:), @selector(wg_setTitle:forState:));
        WGSwizzle(UIButton.class,
                  @selector(setAttributedTitle:forState:),
                  @selector(wg_setAttributedTitle:forState:));

        WGSwizzle(UITextField.class, @selector(setPlaceholder:), @selector(wg_setPlaceholder:));
        WGSwizzle(UITextField.class, @selector(setText:), @selector(wg_setText:));
        WGSwizzle(UITextField.class, @selector(setAttributedText:), @selector(wg_setAttributedText:));

        WGSwizzle(UITextView.class, @selector(setText:), @selector(wg_setText:));
        WGSwizzle(UITextView.class, @selector(setAttributedText:), @selector(wg_setAttributedText:));

        WGSwizzle(UINavigationItem.class, @selector(setTitle:), @selector(wg_setTitle:));
        WGSwizzle(UIViewController.class, @selector(setTitle:), @selector(wg_setTitle:));
        WGSwizzle(UISearchBar.class, @selector(setPlaceholder:), @selector(wg_setPlaceholder:));

        WGSwizzleClass(UIAlertController.class,
                       @selector(alertControllerWithTitle:message:preferredStyle:),
                       @selector(wg_alertControllerWithTitle:message:preferredStyle:));

        WGSwizzle(UIBarButtonItem.class,
                  @selector(initWithTitle:style:target:action:),
                  @selector(wg_initWithTitle:style:target:action:));
    });
}

#pragma mark - NSAttributedString hooks

static void WGInstallAttributedStringHooks(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        id immutableAllocation = [NSAttributedString alloc];
        Class immutableAllocationClass = [immutableAllocation class];
        NSAttributedString *immutable = [immutableAllocation initWithString:@"x"];

        id mutableAllocation = [NSMutableAttributedString alloc];
        Class mutableAllocationClass = [mutableAllocation class];
        NSMutableAttributedString *mutable = [mutableAllocation initWithString:@"x"];

        NSMutableArray *classes = [NSMutableArray array];
        NSArray *candidateClasses = @[
            immutableAllocationClass ?: NSAttributedString.class,
            [immutable class] ?: NSAttributedString.class,
            mutableAllocationClass ?: NSMutableAttributedString.class,
            [mutable class] ?: NSMutableAttributedString.class,
        ];
        for (Class candidate in candidateClasses) {
            if (candidate && ![classes containsObject:candidate]) {
                [classes addObject:candidate];
            }
        }

        Class mutableClass = [mutable class];

        NSArray<NSString *> *selectorNames = @[
            NSStringFromSelector(@selector(initWithString:)),
            NSStringFromSelector(@selector(initWithString:attributes:)),
        ];
        NSArray<NSValue *> *replacementValues = @[
            [NSValue valueWithPointer:(IMP)WGGenericInitWithString],
            [NSValue valueWithPointer:(IMP)WGGenericInitWithStringAttributes],
        ];
        NSArray<NSNumber *> *argumentCounts = @[@3, @4];

        NSMutableArray<NSDictionary *> *captured = [NSMutableArray array];
        for (Class cls in classes) {
            for (NSUInteger index = 0; index < selectorNames.count; index++) {
                SEL selector = NSSelectorFromString(selectorNames[index]);
                Method method = class_getInstanceMethod(cls, selector);
                NSUInteger expectedArguments = argumentCounts[index].unsignedIntegerValue;
                if (!WGMethodAcceptsObject(method, expectedArguments)) {
                    continue;
                }

                IMP original = method_getImplementation(method);
                const char *types = method_getTypeEncoding(method);
                if (!original || !types) {
                    continue;
                }

                [captured addObject:@{
                    @"class": cls,
                    @"selector": selectorNames[index],
                    @"replacement": replacementValues[index],
                    @"original": [NSValue valueWithPointer:original],
                    @"types": [NSString stringWithUTF8String:types],
                }];
            }
        }

        for (NSDictionary *entry in captured) {
            Class cls = entry[@"class"];
            SEL selector = NSSelectorFromString(entry[@"selector"]);
            IMP replacement = [entry[@"replacement"] pointerValue];
            IMP original = [entry[@"original"] pointerValue];
            const char *types = [entry[@"types"] UTF8String];
            NSString *key = WGHookKey(cls, selector);

            @synchronized (WGInstalledHooks()) {
                if ([WGInstalledHooks() containsObject:key]) {
                    continue;
                }

                if (!class_addMethod(cls, selector, replacement, types)) {
                    class_replaceMethod(cls, selector, replacement, types);
                }
                WGOriginalIMPs()[key] = [NSValue valueWithPointer:original];
                [WGInstalledHooks() addObject:key];
            }
        }

        SEL replaceSelector = @selector(replaceCharactersInRange:withString:);
        Method replaceMethod = class_getInstanceMethod(mutableClass, replaceSelector);
        if (replaceMethod && method_getNumberOfArguments(replaceMethod) == 4) {
            NSString *key = WGHookKey(mutableClass, replaceSelector);
            @synchronized (WGInstalledHooks()) {
                if (![WGInstalledHooks() containsObject:key]) {
                    IMP original = method_getImplementation(replaceMethod);
                    const char *types = method_getTypeEncoding(replaceMethod);
                    class_replaceMethod(mutableClass, replaceSelector, (IMP)WGGenericReplaceCharacters, types);
                    WGOriginalIMPs()[key] = [NSValue valueWithPointer:original];
                    [WGInstalledHooks() addObject:key];
                }
            }
        }
    });
}

#pragma mark - Telegram / Whitegram custom text-node hooks

static BOOL WGClassBelongsToApp(Class cls) {
    const char *imageName = class_getImageName(cls);
    if (!imageName) {
        return NO;
    }

    NSString *path = [NSString stringWithUTF8String:imageName];
    if (![path containsString:@".app/"]) {
        return NO;
    }

    NSString *className = NSStringFromClass(cls);
    if ([className hasPrefix:@"WGArabic"] ||
        [className containsString:@"WhitegramArabic"]) {
        return NO;
    }

    return YES;
}

static void WGInstallCustomTextHooks(void) {
    int count = objc_getClassList(NULL, 0);
    if (count <= 0) {
        return;
    }

    Class *classes = (__unsafe_unretained Class *)calloc((size_t)count, sizeof(Class));
    count = objc_getClassList(classes, count);

    SEL selectors[] = {
        NSSelectorFromString(@"setText:"),
        NSSelectorFromString(@"setTitle:"),
        NSSelectorFromString(@"setSubtitle:"),
        NSSelectorFromString(@"setPlaceholder:"),
        NSSelectorFromString(@"setAttributedText:"),
        NSSelectorFromString(@"setDetailText:"),
        NSSelectorFromString(@"setNavigationTitle:"),
    };

    size_t selectorCount = sizeof(selectors) / sizeof(selectors[0]);

    for (int index = 0; index < count; index++) {
        Class cls = classes[index];
        if (!WGClassBelongsToApp(cls)) {
            continue;
        }

        NSString *name = NSStringFromClass(cls);
        BOOL likelyTextClass =
            [name localizedCaseInsensitiveContainsString:@"Text"] ||
            [name localizedCaseInsensitiveContainsString:@"Label"] ||
            [name localizedCaseInsensitiveContainsString:@"Title"] ||
            [name localizedCaseInsensitiveContainsString:@"Item"] ||
            [name localizedCaseInsensitiveContainsString:@"Node"] ||
            [name localizedCaseInsensitiveContainsString:@"Controller"] ||
            [name localizedCaseInsensitiveContainsString:@"View"];

        if (!likelyTextClass) {
            continue;
        }

        for (size_t selectorIndex = 0; selectorIndex < selectorCount; selectorIndex++) {
            WGReplaceInstanceMethod(cls,
                                    selectors[selectorIndex],
                                    (IMP)WGGenericObjectSetter,
                                    3);
        }
    }

    free(classes);
}

static void WGInstallAllHooks(void) {
    WGInstallUIKitHooks();
    WGInstallAttributedStringHooks();
    WGInstallCustomTextHooks();
}

__attribute__((constructor))
static void WGArabicEntryPoint(void) {
    @autoreleasepool {
        WGInstallAllHooks();

        dispatch_async(dispatch_get_main_queue(), ^{
            WGInstallCustomTextHooks();

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                WGInstallCustomTextHooks();
            });
        });
    }
}
