//
//  PadletWebview.h
//  ReactWebview
//
//  Created by Colin Teahan on 2/21/24.
//

#import <WebKit/WebKit.h>
#import <React/RCTBridge.h>
#import <React/RCTComponent.h>

@class PadletWebview;

@protocol PadletWebviewDelegate <NSObject>

- (BOOL)webView:(PadletWebview *)webView
shouldStartLoadForRequest:(NSMutableDictionary<NSString *, id> *)request
   withCallback:(RCTDirectEventBlock)callback;

@end

@interface PadletWebview : WKWebView <UIScrollViewDelegate, RCTBridgeModule, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler, UIGestureRecognizerDelegate>

@property (nonatomic, weak) id<PadletWebviewDelegate> delegate;
@property (nonatomic, copy) RCTBubblingEventBlock onChange;

@property (strong, nonatomic) NSString *clientToken;


@property (nonatomic) CGFloat headerOffset;

- (void)setSource:(NSDictionary *)source;
- (void)removeListeners;

- (UIEdgeInsets)safeAreaInsets;

- (instancetype)init;
+ (instancetype)new NS_UNAVAILABLE;

@end
