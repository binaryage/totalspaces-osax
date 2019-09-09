#import <Cocoa/Cocoa.h>

#import "TSStandardVersionComparator.h"

#define TOTALSPACES_STANDARD_INSTALL_LOCATION "/Applications/TotalSpaces2.app"

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
    NSLog(@"[TotalSpaces] TotalSpacesInjector: %@", msg);
    AEPutParamString(reply, keyErrorString, msg);
}

static NSString* checkSignature(CFURLRef bundleURL, CFStringRef requirementString) {
    CFErrorRef error = NULL;
    SecStaticCodeRef staticCode = NULL;
    SecStaticCodeCreateWithPath(bundleURL, kSecCSDefaultFlags, &staticCode);
    
    if (!staticCode) {
        return @"SecStaticCodeCreateWithPath returned no staticCode";
    }
    
    SecRequirementRef requirementRef  = NULL;
    OSStatus requirementCreateStatus = SecRequirementCreateWithStringAndErrors(requirementString, kSecCSDefaultFlags, &error, &requirementRef);
    if (error) {
        if (requirementRef) {
            CFRelease(requirementRef);
        }
        NSString* result = [NSString stringWithFormat:@"SecRequirementCreateWithStringAndErrors reported %@", error];
        CFRelease(error);
        return result;
    }
    
    if (requirementCreateStatus != errSecSuccess) {
        if (requirementRef) {
            CFRelease(requirementRef);
        }
        return [NSString stringWithFormat:@"SecRequirementCreateWithString returned error %d)", (int)requirementCreateStatus];
    }
    
    SecCSFlags flags = (SecCSFlags) (kSecCSDefaultFlags | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode);
    OSStatus signatureCheckResult = SecStaticCodeCheckValidityWithErrors(staticCode, flags, requirementRef, &error);
    CFRelease(requirementRef);
    CFRelease(staticCode);
    
    if (error) {
        NSString* result = [NSString stringWithFormat:@"SecStaticCodeCheckValidityWithErrors reported %@", error];
        CFRelease(error);
        return result;
    }
    
    if (signatureCheckResult != errSecSuccess) {
        return [NSString stringWithFormat:@"SecStaticCodeCheckValidityWithErrors returned %d", (int)signatureCheckResult];
    }
    
    return nil;
}

NSBundle *TSAddBundle(NSString *bundleName, AppleEvent *reply)
{
    NSString *path = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:@"com.binaryage.TotalSpaces2"];
    NSString *resource = [NSString stringWithFormat:@"%@/Contents/Plugins/%@.bundle", path, bundleName];
    
  NSBundle* pluginBundle = [NSBundle bundleWithPath:resource];
  if (!pluginBundle) {
    path = @TOTALSPACES_STANDARD_INSTALL_LOCATION; // try the default location
    NSString *resource = [NSString stringWithFormat:@"%@/Contents/Plugins/%@.bundle", path, bundleName];
    pluginBundle = [NSBundle bundleWithPath:resource];
      
    if (!pluginBundle) {
      reportError(reply, [NSString stringWithFormat:@"Unable to create bundle from path: %@ [%@]", resource, path]);
      return nil;
    }
  }
  
  NSString *errStr = checkSignature((CFURLRef)pluginBundle.bundleURL, CFSTR("anchor apple generic and certificate leaf[subject.O] = \"BinaryAge Limited\""));

  if (errStr) {
    reportError(reply, [NSString stringWithFormat:@"Bundle failed checks: %@ [%@]", errStr, path]);
    return nil;
  }

  NSError* error;
  if (![pluginBundle loadAndReturnError:&error]) {
    reportError(reply, [NSString stringWithFormat:@"Unable to load bundle from path: %@ error: %@", resource, [error localizedDescription]]);
    return nil;
  } else {
    NSLog(@"[TotalSpaces] Loaded bundle from path: %@", resource);
  }
  
  return pluginBundle;
}

OSErr HandleInitEvent(const AppleEvent *ev, AppleEvent *reply, long refcon) {
    NSBundle* injectorBundle = [NSBundle bundleForClass:[TotalSpacesInjector class]];
    NSString* injectorVersion = [injectorBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
    if (!injectorVersion || ![injectorVersion isKindOfClass:[NSString class]]) {
        reportError(reply, [NSString stringWithFormat:@"Unable to determine TotalSpacesInjector version!"]);
        return 7;
    }
    
    NSLog(@"[TotalSpaces] TotalSpacesInjector v%@ received init event", injectorVersion);
    if (alreadyLoaded) {
        NSLog(@"[TotalSpaces] TotalSpacesInjector: TotalSpaces has been already loaded. Ignoring this request.");
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
        reportError(reply, [NSString stringWithFormat:@"Unable to determine Dock version!"]);
        return 5;
      }
      
      NSBundle *tsBundle = TSAddBundle(@"TotalSpaces", reply);
      if (!tsBundle) return 2;
      
      TotalSpacesPlugin* principalClass = (TotalSpacesPlugin*)[tsBundle principalClass];
      if (!principalClass) {
        reportError(reply, [NSString stringWithFormat:@"Unable to retrieve principalClass for bundle: %@", tsBundle]);
        return 3;
      }
      if ([principalClass respondsToSelector:@selector(install)]) {
        NSLog(@"[TotalSpaces] TotalSpacesInjector: Installing TotalSpaces ...");
        [principalClass install];
      }
      
      TSAddBundle(@"GridZoom", reply);
      
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
