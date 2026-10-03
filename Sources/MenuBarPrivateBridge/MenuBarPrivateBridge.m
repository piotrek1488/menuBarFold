#import "MenuBarPrivateBridge.h"

#import <dlfcn.h>
#import <objc/message.h>

static NSString *const MBFErrorDomain = @"MenuBarFold.NativeVisibility";
static NSString *const MBFFrameworkPath = @"/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore";
static NSString *const MBFConfigurationClassName = @"MBAssessmentModeConfiguration";
static NSString *const MBFAssertionClassName = @"MBAssessmentModeAssertion";

static SEL MBFConfigurationInitializer(void) {
    return NSSelectorFromString(@"initWithAllowedSystemItems:allowedBundleIdentifiers:");
}

static SEL MBFActivationSelector(void) {
    return NSSelectorFromString(@"activateWithConfiguration:completionHandler:");
}

static NSError *MBFError(NSString *reason) {
    return [NSError errorWithDomain:MBFErrorDomain
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey: reason}];
}

BOOL MBFNativeVisibilityIsAvailable(void) {
    if (dlopen(MBFFrameworkPath.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL) == NULL) {
        return NO;
    }

    Class configurationClass = NSClassFromString(MBFConfigurationClassName);
    Class assertionClass = NSClassFromString(MBFAssertionClassName);

    return configurationClass != Nil
        && assertionClass != Nil
        && [configurationClass instancesRespondToSelector:MBFConfigurationInitializer()]
        && [assertionClass instancesRespondToSelector:MBFActivationSelector()]
        && [assertionClass instancesRespondToSelector:@selector(invalidate)];
}

void MBFNativeVisibilityActivate(NSArray<NSNumber *> *allowedSystemItems,
                                 NSArray<NSString *> *allowedBundleIdentifiers,
                                 MBFVisibilityCompletion completion) {
    void (^finish)(id, NSError *) = ^(id assertion, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(assertion, error);
        });
    };

    if (!MBFNativeVisibilityIsAvailable()) {
        finish(nil, MBFError(@"MenuBarClientCore is unavailable on this version of macOS."));
        return;
    }

    @try {
        Class configurationClass = NSClassFromString(MBFConfigurationClassName);
        Class assertionClass = NSClassFromString(MBFAssertionClassName);

        id configuration = ((id (*)(id, SEL, NSArray *, NSArray *))objc_msgSend)(
            [configurationClass alloc],
            MBFConfigurationInitializer(),
            [allowedSystemItems copy],
            [allowedBundleIdentifiers copy]
        );
        id assertion = [[assertionClass alloc] init];

        if (configuration == nil || assertion == nil) {
            finish(nil, MBFError(@"The menu bar visibility configuration could not be created."));
            return;
        }

        ((void (*)(id, SEL, id, void (^)(NSError *)))objc_msgSend)(
            assertion,
            MBFActivationSelector(),
            configuration,
            ^(NSError *error) {
                finish(error == nil ? assertion : nil, error);
            }
        );
    } @catch (NSException *exception) {
        NSString *reason = [NSString stringWithFormat:@"%@: %@",
                            exception.name,
                            exception.reason ?: @"Unknown private framework error"];
        finish(nil, MBFError(reason));
    }
}

void MBFNativeVisibilityInvalidate(id assertion) {
    @try {
        if ([assertion respondsToSelector:@selector(invalidate)]) {
            ((void (*)(id, SEL))objc_msgSend)(assertion, @selector(invalidate));
        }
    } @catch (NSException *exception) {
        NSLog(@"MenuBarFold: visibility invalidation raised %@: %@",
              exception.name,
              exception.reason);
    }
}
