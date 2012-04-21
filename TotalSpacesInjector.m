#import <Cocoa/Cocoa.h>

#import "TSStandardVersionComparator.h"

#define TOTALSPACES_STANDARD_INSTALL_LOCATION "/Applications/TotalSpaces.app"
#define DOCK_MIN_TESTED_VERSION @"1040.7" // 10.7.2-11C43
#define DOCK_MAX_TESTED_VERSION @"1040.35" // 10.7.4-11E46

// SIMBL-compatible interface
@interface TotalSpacesPlugin: NSObject { 
}
- (void) install;
@end

// just a dummy class for locating our bundle
@interface TotalSpacesInjector: NSObject { 
}
@end

@implementation TotalSpacesInjector {
}
@end

static bool alreadyLoaded = false;

typedef struct {
    NSString* location;
} configuration;

OSErr AEPutParamString(AppleEvent *event, AEKeyword keyword, NSString* string) {
    UInt8 *textBuf;
    CFIndex length, maxBytes, actualBytes;
    length = CFStringGetLength((CFStringRef)string);
    maxBytes = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8);
    textBuf = malloc(maxBytes);
    if (textBuf) {
        CFStringGetBytes((CFStringRef)string, CFRangeMake(0, length), kCFStringEncodingUTF8, 0, true, (UInt8 *)textBuf, maxBytes, &actualBytes);
        OSErr err = AEPutParamPtr(event, keyword, typeUTF8Text, textBuf, actualBytes);
        free(textBuf);
        return err;
    } else {
        return memFullErr;
    }
}

static void reportError(AppleEvent *reply, NSString* msg) {
    NSLog(@"TotalSpacesInjector: %@", msg);
    AEPutParamString(reply, keyErrorString, msg);
}

OSErr HandleInitEvent(const AppleEvent *ev, AppleEvent *reply, long refcon) {
    NSBundle* injectorBundle = [NSBundle bundleForClass:[TotalSpacesInjector class]];
    NSString* injectorVersion = [injectorBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
    if (!injectorVersion || ![injectorVersion isKindOfClass:[NSString class]]) {
        reportError(reply, [NSString stringWithFormat:@"Unable to determine TotalSpacesInjector version!"]);
        return 7;
    }
    
    NSLog(@"TotalSpacesInjector v%@ received init event", injectorVersion);
    if (alreadyLoaded) {
        NSLog(@"TotalSpacesInjector: TotalSpaces has been already loaded. Ignoring this request.");
        return noErr;
    }
    @try {
        NSBundle* dockBundle = [NSBundle mainBundle];
        if (!dockBundle) {
            reportError(reply, [NSString stringWithFormat:@"Unable to locate main Dock bundle!"]);
            return 4;
        }
        
        NSString* dockVersion = [dockBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
        if (!dockVersion || ![dockVersion isKindOfClass:[NSString class]]) {
            reportError(reply, [NSString stringWithFormat:@"Unable to determine Spaces version!"]);
            return 5;
        }
        
        // future compatibility check
        NSString* supressKey = @"TotalSpacesSuppressDockVersionCheck";
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        if (![defaults boolForKey:supressKey]) {
            TSStandardVersionComparator* comparator = [TSStandardVersionComparator defaultComparator];
            if (([comparator compareVersion:dockVersion toVersion:DOCK_MAX_TESTED_VERSION]==NSOrderedDescending) || 
                ([comparator compareVersion:dockVersion toVersion:DOCK_MIN_TESTED_VERSION]==NSOrderedAscending)) {

                NSAlert* alert = [NSAlert new];
                [alert setMessageText: [NSString stringWithFormat:@"You have Dock version %@", dockVersion]];
                [alert setInformativeText: [NSString stringWithFormat:@"But TotalSpaces was properly tested only with Dock versions in range %@ - %@\n\nYou have probably updated your system and Dock version got bumped by Apple developers.\n\nYou may expect a new TotalSpaces release soon.", DOCK_MIN_TESTED_VERSION, DOCK_MAX_TESTED_VERSION]];
                [alert setShowsSuppressionButton:YES];
                [alert addButtonWithTitle:@"Launch TotalSpaces anyway"];
                [alert addButtonWithTitle:@"Cancel"];
                NSInteger res = [alert runModal];
                if ([[alert suppressionButton] state] == NSOnState) {
                    [defaults setBool:YES forKey:supressKey];
                }
                if (res!=NSAlertFirstButtonReturn) { // cancel
                    return noErr;
                }
            }
        }
        
        NSBundle* totalSpacesInjectorBundle = [NSBundle bundleForClass:[TotalSpacesInjector class]];
        NSString* totalSpacesLocation = [totalSpacesInjectorBundle pathForResource:@"TotalSpaces" ofType:@"bundle"];
        NSBundle* pluginBundle = [NSBundle bundleWithPath:totalSpacesLocation];
        if (!pluginBundle) {
            reportError(reply, [NSString stringWithFormat:@"Unable to create bundle from path: %@ [%@]", totalSpacesLocation, totalSpacesInjectorBundle]);
            return 2;
        }
        
        NSError* error;
        if (![pluginBundle loadAndReturnError:&error]) {
            reportError(reply, [NSString stringWithFormat:@"Unable to load bundle from path: %@ error: %@", totalSpacesLocation, [error localizedDescription]]);
            return 6;
        }
        
        TotalSpacesPlugin* principalClass = (TotalSpacesPlugin*)[pluginBundle principalClass];
        if (!principalClass) {
            reportError(reply, [NSString stringWithFormat:@"Unable to retrieve principalClass for bundle: %@", pluginBundle]);
            return 3;
        }
        if ([principalClass respondsToSelector:@selector(install)]) {
            NSLog(@"TotalSpacesInjector: Installing TotalSpaces ...");
            [principalClass install];
        }
        alreadyLoaded = true;
        return noErr;
    } @catch (NSException* exception) {
        reportError(reply, [NSString stringWithFormat:@"Failed to load TotalSpaces with exception: %@", exception]);
    }
    return 1;
}

OSErr HandleCheckEvent(const AppleEvent *ev, AppleEvent *reply, long refcon) {
    if (alreadyLoaded) {
        return noErr;
    }
    reportError(reply, @"TotalSpaces not loaded");
    return 1;
}