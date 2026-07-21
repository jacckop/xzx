#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const WGLanguageDidChangeNotification;

FOUNDATION_EXPORT BOOL WGLocalizationEnabled(void);
FOUNDATION_EXPORT NSString *WGSelectedLanguageCode(void);
FOUNDATION_EXPORT void WGSetSelectedLanguageCode(NSString *languageCode);
FOUNDATION_EXPORT BOOL WGSelectedLanguageIsRTL(void);
FOUNDATION_EXPORT UISemanticContentAttribute WGSelectedSemanticContentAttribute(void);
FOUNDATION_EXPORT NSTextAlignment WGSelectedTextAlignment(void);
FOUNDATION_EXPORT NSString *WGTranslateString(NSString *input);
FOUNDATION_EXPORT NSAttributedString *WGTranslateAttributedString(NSAttributedString *input);

/* Compatibility aliases retained for the v3 scanner. */
FOUNDATION_EXPORT BOOL WGArabicLocalizationEnabled(void);
FOUNDATION_EXPORT NSString *WGArabicTranslateString(NSString *input);
FOUNDATION_EXPORT NSAttributedString *WGArabicTranslateAttributedString(NSAttributedString *input);

NS_ASSUME_NONNULL_END
