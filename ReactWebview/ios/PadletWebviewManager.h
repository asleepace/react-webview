//
//  WebviewManager.h
//  ReactWebview
//
//  Created by Colin Teahan on 2/21/24.
//

#import <React/RCTViewManager.h>
#import "PadletWebview.h"
#import <React/RCTBridge.h>

@interface PadletWebviewManager : RCTViewManager <WKUIDelegate, WKNavigationDelegate, RCTBridgeModule>

- (instancetype)init;

@end
