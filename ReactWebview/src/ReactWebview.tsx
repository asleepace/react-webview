import React, {useRef} from 'react';
import {NativeModules, StyleSheet, requireNativeComponent} from 'react-native';

const {WebviewManager} = NativeModules;

console.log('[react] WebviewManager', WebviewManager);
console.log('[react] NativeModules', {NativeModules});

for (const key in NativeModules) {
  console.log('[react] found:', {key});
}

// Load Native iOS Components
const Webview = requireNativeComponent('PadletWebview');

console.log('[react] Webview', Webview);

export type ReactWebviewProps = {
  uri: string;
};

export default function ReactWebview({uri}: ReactWebviewProps) {
  const webviewRef = useRef(null);

  return (
    <Webview
      ref={webviewRef}
      style={styles.container}
      uri={uri}
      onMessage={(event: any) => {
        console.log('[react] onMessage', event.nativeEvent);
      }}
      onNavigationStateChange={(event: any) => {
        console.log('[react] onNavigationStateChange', event.nativeEvent);
      }}
    />
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: 'white',
  },
  webview: {
    flex: 1,
  },
});
