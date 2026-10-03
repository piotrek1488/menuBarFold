#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^MBFVisibilityCompletion)(id _Nullable assertion, NSError * _Nullable error);

FOUNDATION_EXPORT BOOL MBFNativeVisibilityIsAvailable(void);

FOUNDATION_EXPORT void MBFNativeVisibilityActivate(
    NSArray<NSNumber *> *allowedSystemItems,
    NSArray<NSString *> *allowedBundleIdentifiers,
    MBFVisibilityCompletion completion
);

FOUNDATION_EXPORT void MBFNativeVisibilityInvalidate(id assertion);

NS_ASSUME_NONNULL_END
