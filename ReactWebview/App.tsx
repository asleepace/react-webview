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
      <ReactWebview uri="https://padlet.com/starkindustries/my-brilliant-padlet-w7o77m5e43a6d78j" />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  background: {
    backgroundColor: 'red',
    flex: 1,
  },
  translucent: {
    backgroundColor: 'transparent',
  },
});

export default App;
