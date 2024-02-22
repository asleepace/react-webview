//
//  WebviewManager.m
//  ReactWebview
//
//  Created by Colin Teahan on 2/21/24.
//

#import "PadletWebviewManager.h"

#import <React/RCTBridge.h>
#import <React/RCTUIManager.h>
#import <WebKit/WKWebsiteDataStore.h>
#import <SafariServices/SafariServices.h>

@interface PadletWebviewManager () <PadletWebviewDelegate>
{
  CGFloat previousYOffset;
  NSInteger previousDirection;
  NSInteger removedWebViewHelper;
}

@property (strong, nonatomic) PadletWebview *webView;

@end

@implementation PadletWebviewManager
{
  NSConditionLock *_shouldStartLoadLock;
  BOOL _shouldStartLoad;
}

@synthesize webView;

RCT_EXPORT_MODULE(PadletWebviewManager)
RCT_EXPORT_VIEW_PROPERTY(source, NSDictionary)
RCT_EXPORT_VIEW_PROPERTY(backgroundColor, UIColor)
RCT_EXPORT_VIEW_PROPERTY(onChange, RCTBubblingEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onShouldStartLoadWithRequest, RCTDirectEventBlock)


+ (BOOL)requiresMainQueueSetup {
  return true;
}


- (instancetype)init {
    if (self = [super init]) {
      RCTLogInfo(@"[WebviewManager] init called!");
    }
    return self;
}


#pragma mark - RCTViewManager


- (UIView *)view {
  self.webView = [[PadletWebview alloc] init];
  removedWebViewHelper = 0;
  webView.delegate = self;
  return webView;
}


#pragma mark - Methods


// Execute javascript on the given WebView
RCT_EXPORT_METHOD(executeJavascript:(nonnull NSNumber *)reactTag with:(NSString *)js)
{
  //RCTLogInfo(@"executing javascript %@",js);
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, PadletWebview *> *viewRegistry) {
    PadletWebview *view = viewRegistry[reactTag];
    RCTLogInfo(@"[WebviewManager] execute js: %@", js);
    [view evaluateJavaScript:js completionHandler:^(id _Nullable result, NSError * _Nullable error) {
      if (result == nil) { result = @""; }
      id outputError = (error) ? error.description : @"";
      view.onChange(@{ @"result" : result, @"error": outputError, @"type" : @"javascript" });
    }];
  }];
}


// Allows execution of javascript that is returned as a promise to the sender. This allows us to do Async / Await calls
// to the sender, and wait on the variables that are passed back from the WebView.
RCT_EXPORT_METHOD(asyncJavascript:(nonnull NSNumber *)reactTag
                             with:(NSString *)js
                          resolve:(RCTPromiseResolveBlock)resolve
                           reject:(RCTPromiseRejectBlock)reject) {
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, PadletWebview *> *viewRegistry) {
    PadletWebview *view = viewRegistry[reactTag];
    [view evaluateJavaScript:js completionHandler:^(id _Nullable result, NSError * _Nullable error) {
      (result) ? resolve(result) : reject(@"no_result",@"There was no result",error);
    }];
  }];
}


#pragma mark - Delegate Methods


- (BOOL)webView:(__unused PadletWebview *)webView shouldStartLoadForRequest:(NSMutableDictionary<NSString *, id> *)request withCallback:(RCTDirectEventBlock)callback
{
  RCTLogInfo(@"[RNTWebViewManager] shouldStartLoadForRequest!");
  _shouldStartLoadLock = [[NSConditionLock alloc] initWithCondition:arc4random()]; // ???
  _shouldStartLoad = YES;
  request[@"lockIdentifier"] = @(_shouldStartLoadLock.condition);
  callback(request);
  
  // Block the main thread for a maximum of 250ms until the JS thread returns
  if ([_shouldStartLoadLock lockWhenCondition:0 beforeDate:[NSDate dateWithTimeIntervalSinceNow:.25]]) {
    BOOL returnValue = _shouldStartLoad;
    [_shouldStartLoadLock unlock];
    _shouldStartLoadLock = nil;
    return returnValue;
  } else {
    RCTLogWarn(@"[RNTWebViewManager] Did not receive response to shouldStartLoad in time, defaulting to YES");
    return YES;
  }
}

RCT_EXPORT_METHOD(startLoadWithResult:(BOOL)result lockIdentifier:(NSInteger)lockIdentifier)
{
  if ([_shouldStartLoadLock tryLockWhenCondition:lockIdentifier]) {
    _shouldStartLoad = result;
    [_shouldStartLoadLock unlockWithCondition:0];
  } else {
    RCTLogWarn(@"[RNTWebViewManager] startLoadWithResult invoked with invalid lockIdentifier: "
               "got %zd, expected %zd", lockIdentifier, _shouldStartLoadLock.condition);
  }
}


// Clear the WKWebView Cache
RCT_EXPORT_METHOD(clearCache:(RCTResponseSenderBlock)callback)
{
  RCTLogInfo(@"[RNTWebViewManager] Clearing cache...");
    printf("[RNWebViewManager] clearCache called!\n");
  [self clearOauthToken];

  NSSet *cachedData = [NSSet setWithArray:@[
    WKWebsiteDataTypeCookies,
    WKWebsiteDataTypeDiskCache,
    WKWebsiteDataTypeMemoryCache,
    WKWebsiteDataTypeLocalStorage,
    WKWebsiteDataTypeSessionStorage,
    WKWebsiteDataTypeWebSQLDatabases,
    WKWebsiteDataTypeIndexedDBDatabases,
    WKWebsiteDataTypeOfflineWebApplicationCache,
  ]];
  
  dispatch_async(dispatch_get_main_queue(), ^{
    [self clearCookies];
    NSDate *epoch = [NSDate dateWithTimeIntervalSince1970:0];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:cachedData modifiedSince:epoch completionHandler:^{}];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:cachedData modifiedSince:epoch completionHandler:^{
      callback(@[@{@"success":@YES}]);
    }];
  });
}

// Clear the shared oauth token for the file provider extension
- (void)clearOauthToken {
    RCTLogInfo(@"[RNTWebViewManager] clearOauthToken cache...");
    printf("[RNWebViewManager] clearOauthToken called!\n");
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:nil forKey:@"oauth_token"];
    [defaults setObject:nil forKey:@"oath_token"]; // Get rid of mispelled one (legacy)
    [defaults synchronize];
    NSError *error = nil;
    // [self.secureStorage setToken:nil error:&error];
    if (error) {
        RCTLogError(@"[RNTWebViewManager] Failed to clear token: %@", error.localizedDescription);
    }
}

- (void)clearCookies {
    RCTLogInfo(@"[RNTWebViewManager] clearCookies...");
    printf("[RNWebViewManager] clearCookies called!\n");

  NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
  for (NSHTTPCookie *c in cookieStorage.cookies) {
    [cookieStorage deleteCookie:c];
  }
}


@end
