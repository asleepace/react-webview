//
//  WebviewManager.m
//  ReactWebview
//
//  Created by Colin Teahan on 2/21/24.
//

#import "WebviewManager.h"

#import <React/RCTBridge.h>
#import <React/RCTUIManager.h>
#import <WebKit/WKWebsiteDataStore.h>
#import <SafariServices/SafariServices.h>

@interface WebviewManager () <PadletWebviewDelegate>
{
  CGFloat previousYOffset;
  NSInteger previousDirection;
  NSInteger removedWebViewHelper;
}

@property (strong, nonatomic) PadletWebview *webView;

@end

@implementation WebviewManager
{
  NSConditionLock *_shouldStartLoadLock;
  BOOL _shouldStartLoad;
}

@synthesize webView;

RCT_EXPORT_MODULE(PadletWebviewManager)
// RCT_EXPORT_VIEW_PROPERTY(source, NSDictionary)
// RCT_EXPORT_VIEW_PROPERTY(backgroundColor, UIColor)
// RCT_EXPORT_VIEW_PROPERTY(onChange, RCTBubblingEventBlock)
// RCT_EXPORT_VIEW_PROPERTY(onShouldStartLoadWithRequest, RCTDirectEventBlock)

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
    // RCTLogInfo(@"[XCODE] Execute js token: %@",view.clientToken);
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


@end
