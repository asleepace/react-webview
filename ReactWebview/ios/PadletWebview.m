//
//  PadletWebview.m
//  ReactWebview
//
//  Created by Colin Teahan on 2/21/24.
//

#import "PadletWebview.h"
#import <React/RCTViewManager.h>
#import <React/RCTAutoInsetsProtocol.h>


// prviate interface
@interface PadletWebview() <UIWebViewDelegate, RCTAutoInsetsProtocol>
{
  WKWebViewConfiguration *configuration;
  WKUserContentController *controller;
  NSString *clientToken;
}

@property (nonatomic, copy) RCTDirectEventBlock onShouldStartLoadWithRequest;

@end

// implementation
@implementation PadletWebview

RCT_EXPORT_MODULE();

@synthesize clientToken, contentInset, automaticallyAdjustContentInsets;

// React native method
+ (BOOL)requiresMainQueueSetup
{
  return true;
}

- (id)init {
  WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
  WKUserContentController *userContentController = [[WKUserContentController alloc] init];
  [controller addScriptMessageHandler:self name:@"__iosAppMsgCenter"];
  configuration.userContentController = userContentController;
  if (self = [super initWithFrame:self.frame configuration:configuration]) {
    // Trigger the refresh each time the keyboard is dismissed, fixes a strange bug in iOS 12
    // that causes the WebView viewport not to be resized. https://github.com/apache/cordova-ios/issues/417
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide)
                                                 name:UIKeyboardWillHideNotification object:nil];
    UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped)];
    [gesture setDelegate:self];
    [self addGestureRecognizer:gesture];
    self.scrollView.backgroundColor = [UIColor clearColor];
    self.scrollView.contentInset = UIEdgeInsetsZero;
    self.scrollView.alwaysBounceVertical = false;
    self.scrollView.scrollEnabled = true;
    self.clipsToBounds = true;
    self.scrollView.bounces = false;
    self.navigationDelegate = self;
    self.clipsToBounds = false;
    self.UIDelegate = self;
    self.opaque = false;
    
#ifdef DEBUG
    if (@available(iOS 16.4, *)) {
      if ([self respondsToSelector:@selector(setInspectable:)]) {
        [self performSelector:@selector(setInspectable:) withObject:@YES];
      }
    }
#endif
  }
  return self;
}


// This allows us to have multiple gesture recognizers on the WKWebView
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
  return true;
}

// Notify JS when WebView is tapped
- (void)tapped
{
  self.onChange(@{ @"data":@"tap", @"type":@"tapped" });
}

// Handle javascript alert popups natively
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
  UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert" message:message preferredStyle:UIAlertControllerStyleAlert];
  UIAlertAction *alertAction = [UIAlertAction actionWithTitle:@"ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
    self.onChange(@{ @"button" : @"ok", @"type" : @"alert" });
  }];
  [alertController addAction:alertAction];
  [UIApplication.sharedApplication.keyWindow.rootViewController presentViewController:alertController animated:true completion:nil];
  completionHandler();
}

// Handle post message requests from Native Bridge
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
  //RCTLogInfo(@"Native bridge event: %@",message.body);
  self.onChange(@{ @"data":message.body, @"type":@"message" });
}

// Handle where the webview should navigate
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
  NSURLRequest *request = navigationAction.request;
  NSURL* url = request.URL;
  decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)removeListeners {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (WKNavigation *)loadRequest:(NSURLRequest *)request {
  NSMutableURLRequest *req = [request mutableCopy];
  if (clientToken) {
    [req setValue:clientToken forHTTPHeaderField:@"Authorization"];
  }
  
  // Set the application agent here, not neccesarily neccesary, but we do this on android so it's best to have it here too
  NSString *build = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
  NSString *agent = [NSString stringWithFormat:@"Padlet %@", build];
  [req setValue:agent forHTTPHeaderField:@"X-Application-Agent"];
  
  // Return the overridden request
  return [super loadRequest:req];
}

- (UIEdgeInsets)safeAreaInsets {
  return UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f);
}

- (void)setSource:(NSDictionary *)source {
}

- (void)keyboardWillHide {
  NSLog(@"[PadletWebview] keyboardWillHide!");
}

- (BOOL)automaticallyAdjustContentInsets {
  return true;
}
//
//- (void)refreshContentInset { 
//
//}
//
//- (void)encodeWithCoder:(nonnull NSCoder *)coder { 
//
//}
//
//+ (nonnull instancetype)appearance { 
//
//}
//
//+ (nonnull instancetype)appearanceForTraitCollection:(nonnull UITraitCollection *)trait { 
//
//}
//
//+ (nonnull instancetype)appearanceForTraitCollection:(nonnull UITraitCollection *)trait whenContainedIn:(nullable Class<UIAppearanceContainer>)ContainerClass, ... { 
//
//}
//
//+ (nonnull instancetype)appearanceForTraitCollection:(nonnull UITraitCollection *)trait whenContainedInInstancesOfClasses:(nonnull NSArray<Class<UIAppearanceContainer>> *)containerTypes { 
//
//}
//
//+ (nonnull instancetype)appearanceWhenContainedIn:(nullable Class<UIAppearanceContainer>)ContainerClass, ... { 
//
//}
//
//+ (nonnull instancetype)appearanceWhenContainedInInstancesOfClasses:(nonnull NSArray<Class<UIAppearanceContainer>> *)containerTypes { 
//
//}
//
//- (void)traitCollectionDidChange:(nullable UITraitCollection *)previousTraitCollection { 
//
//}
//
//- (CGPoint)convertPoint:(CGPoint)point fromCoordinateSpace:(nonnull id<UICoordinateSpace>)coordinateSpace { 
//
//}
//
//- (CGPoint)convertPoint:(CGPoint)point toCoordinateSpace:(nonnull id<UICoordinateSpace>)coordinateSpace { 
//
//}
//
//- (CGRect)convertRect:(CGRect)rect fromCoordinateSpace:(nonnull id<UICoordinateSpace>)coordinateSpace { 
//
//}
//
//- (CGRect)convertRect:(CGRect)rect toCoordinateSpace:(nonnull id<UICoordinateSpace>)coordinateSpace { 
//
//}
//
//- (void)didUpdateFocusInContext:(nonnull UIFocusUpdateContext *)context withAnimationCoordinator:(nonnull UIFocusAnimationCoordinator *)coordinator { 
//
//}
//
//- (void)setNeedsFocusUpdate { 
//
//}
//
//- (BOOL)shouldUpdateFocusInContext:(nonnull UIFocusUpdateContext *)context { 
//
//}
//
//- (void)updateFocusIfNeeded { 
//
//}
//
//- (nonnull NSArray<id<UIFocusItem>> *)focusItemsInRect:(CGRect)rect { 
//
//}

@end
