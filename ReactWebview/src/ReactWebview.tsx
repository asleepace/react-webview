import React, {useRef} from 'react';
import {
  NativeModules,
  StyleSheet,
  requireNativeComponent,
  View,
} from 'react-native';
import PropTypes from 'prop-types';

// Use the manager to set properties
const {WebviewManager} = NativeModules;

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
  const webviewRef = useRef(null);

  return (
    <View style={styles.container}>
      <Webview
        ref={webviewRef}
        style={styles.webview}
        source={{uri}}
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
