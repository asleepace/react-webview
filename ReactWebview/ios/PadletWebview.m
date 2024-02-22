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

@synthesize clientToken, contentInset, automaticallyAdjustContentInsets, customUserAgent;

// React native method
+ (BOOL)requiresMainQueueSetup
{
  return true;
}


- (void)setUserAgentWithAppVersion:(NSString *)appVersion {
  UIWebView *webView = [[UIWebView alloc] init];
  NSString *userAgent = [webView stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
  NSString *customUserAgent = [NSString stringWithFormat:@"%@ %@", userAgent, appVersion];
  RCTLogInfo(@"[Delegate] custom user agent: %@", customUserAgent);
  self.customUserAgent = customUserAgent;
}


- (id)init {
  WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
  
  configuration.applicationNameForUserAgent = @"Padlet_iOS_210.0.0";
  
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
    //self.scrollView.backgroundColor = [UIColor clearColor];
    self.scrollView.contentInset = UIEdgeInsetsZero;
    self.scrollView.alwaysBounceVertical = false;
    self.scrollView.scrollEnabled = true;
    self.clipsToBounds = true;
    self.scrollView.bounces = false;
    self.navigationDelegate = self;
    self.clipsToBounds = false;
    self.UIDelegate = self;
    self.opaque = false;
    
    self.allowsBackForwardNavigationGestures = true;
    self.allowsLinkPreview = true;
    self.userInteractionEnabled = true;
    
    [self setUserAgentWithAppVersion:@"Padlet_iOS_210.0.0"];
    
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

// Handle post message requests from Native Bridge
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
  RCTLogInfo(@"[PadletWebView] native bridge event: %@", message.body);
  self.onChange(@{ @"data":message.body, @"type":@"message" });
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


// Handle where the webview should navigate
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
  RCTLogInfo(@"[PadletWeview] decidePolicyForNavigationAction %@", navigationAction.request);
  NSURLRequest *request = navigationAction.request;
  NSURL* url = request.URL;
  
  if ([url.absoluteString containsString:@"ios-app/page-ready"]) {
    decisionHandler(WKNavigationActionPolicyCancel);
  }
  else if ([url.absoluteString isEqualToString:@"about:blank"]) {
    RCTLogInfo(@"[PadletWebview] cancelling navigation!");
    decisionHandler(WKNavigationActionPolicyCancel);
  } else {
    decisionHandler(WKNavigationActionPolicyAllow);
  }
}

- (void)removeListeners {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (WKNavigation *)loadRequest:(NSURLRequest *)request {
  RCTLogInfo(@"[PadletWebview] loadRequest triggered: %@", request.debugDescription);
  
  NSMutableURLRequest *req = [request mutableCopy];
  if (clientToken) {
    [req setValue:clientToken forHTTPHeaderField:@"Authorization"];
  }
  
  // Set the application agent here, not neccesarily neccesary, but we do this on android so it's best to have it here too
  // NSString *build = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
  NSString *agent = [NSString stringWithFormat:@"Padlet %@", @"210.0.0"];
  [req setValue:agent forHTTPHeaderField:@"X-Application-Agent"];
  
  // Return the overridden request
  return [super loadRequest:req];
}

- (UIEdgeInsets)safeAreaInsets {
  return UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f);
}

- (void)setSource:(NSDictionary *)source {
  if ([source objectForKey:@"userAgent"]) {
    NSString *userAgent = [source objectForKey:@"userAgent"];
    RCTLogInfo(@"[PadletWebview] setting user agent: %@", userAgent);
    [self setUserAgentWithAppVersion:userAgent];
  }
  
  if ([source objectForKey:@"uri"]) {
    RCTLogInfo(@"[PadletWebview] setting uri %@", source[@"uri"]);
    NSString *uri = [source objectForKey:@"uri"];
    NSURL *url = [NSURL URLWithString:uri];
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
    [self loadRequest:urlRequest];
  }
}

- (void)keyboardWillHide {
  NSLog(@"[PadletWebview] keyboardWillHide!");
}

-(void)menuWillShow:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIMenuController sharedMenuController] setMenuVisible:NO animated:NO];
    });
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  [[UIMenuController sharedMenuController] setMenuVisible:false];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [[UIMenuController sharedMenuController] setMenuVisible:false];
    UITouch *theTouch = [touches anyObject];
    if ([theTouch tapCount] == 2) {
      return;
    }
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
