import React, {useCallback, useEffect, useRef, useState} from 'react';
import {
  NativeModules,
  StyleSheet,
  requireNativeComponent,
  findNodeHandle,
  UIManager,
  View,
} from 'react-native';
import PropTypes from 'prop-types';

// Use the manager to set properties
const {PadletWebviewManager} = NativeModules;

console.log('[react] NativeModules', {NativeModules});

// Load Native iOS Components
const Webview = requireNativeComponent('PadletWebview');

// Set the prop types for the Webview
Webview.propTypes = {
  source: PropTypes.shape({
    uri: PropTypes.string,
  }),
};

export type ReactWebviewProps = {
  uri: string;
};

export default function ReactWebview({uri}: ReactWebviewProps) {
  const [isReady, setIsReady] = useState(false);

  const userAgent = 'Padlet_iOS_210.0.0';

  const webviewRef = useRef<any>(null);

  const executeJavascript = React.useCallback(
    (javascript: string) => {
      console.log('[RichTextEditor] dispatch called: ', javascript);
      UIManager.dispatchViewManagerCommand(
        findNodeHandle(webviewRef.current),
        UIManager.getViewManagerConfig('PadletWebview').Commands
          .executeJavascript,
        [javascript],
      );
    },
    [webviewRef],
  );

  const dispatch = React.useCallback(
    (name: string, data: any) => {
      console.log('[RichTextEditor] dispatch called: ', {name, data});
      const statement = `ww.nativeBridge.dispatch("${name}", ${data});`;
      UIManager.dispatchViewManagerCommand(
        findNodeHandle(webviewRef.current),
        UIManager.getViewManagerConfig('PadletWebview').Commands
          .executeJavascript,
        [statement],
      );
    },
    [webviewRef],
  );

  useEffect(() => {
    setTimeout(() => {
      executeJavascript('alert(window.navigator.userAgent);');
    }, 1000);
  }, [executeJavascript]);

  return (
    <View style={styles.container}>
      <Webview
        ref={(nodeHandle: any) => {
          // console.log('[react] ref', nodeHandle);
          webviewRef.current = nodeHandle;
          setIsReady(true);
        }}
        style={styles.webview}
        source={{uri, userAgent}}
        onChange={(event: any) => {
          console.log('[react] onChange', event.nativeEvent);
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  webview: {
    backgroundColor: 'black',
    flex: 1,
  },
});
