/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 */

import React from 'react';
import {SafeAreaView, StatusBar, StyleSheet} from 'react-native';

import ReactWebview from './src/ReactWebview';

function App(): React.JSX.Element {
  return (
    <SafeAreaView style={styles.background}>
      <StatusBar barStyle={'dark-content'} backgroundColor={'transparent'} />
      <ReactWebview uri="https://padlet.com" />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  background: {
    backgroundColor: 'red',
  },
  translucent: {
    backgroundColor: 'transparent',
  },
});

export default App;
