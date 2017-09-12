
import React, { Component } from 'react';
import {
    AppRegistry,
    StyleSheet,
    Text,
    View,
    ListView,
    NativeEventEmitter,
    Platform,
    TouchableOpacity
} from 'react-native';

import  { ReactNativeAudioStreaming } from 'react-native-audio-streaming';

export default class App extends Component {
    constructor() {
        super();
        this.ds = new ListView.DataSource({rowHasChanged: (r1, r2) => r1 !== r2});
        this.urls = [
            {
                name: 'Shoutcast stream',
                url: 'http://lacavewebradio.chickenkiller.com:8000/stream.mp3'
            },
            {
                name: 'M4A stream',
                url: 'http://web.ist.utl.pt/antonio.afonso/www.aadsm.net/libraries/id3/music/02_Viandanze.m4a'
            },
            {
                name: 'MP3 stream with ID3 meta data',
                url: 'http://web.ist.utl.pt/antonio.afonso/www.aadsm.net/libraries/id3/music/Bruno_Walter_-_01_-_Beethoven_Symphony_No_1_Menuetto.mp3'
            },
            {
                name: 'MP3 stream',
                url: 'http://www.stephaniequinn.com/Music/Canon.mp3'
            }
        ];

        this.state = {
            dataSource: this.ds.cloneWithRows(this.urls),
            selectedSource: this.urls[0].url
        };

        this.playersName = [];
    }

    componentDidMount() {
      this.subscription = new NativeEventEmitter(ReactNativeAudioStreaming).addListener(
            'AudioBridgeEvent', (evt) => {
              console.log('===============')
              console.log('Player changes ', evt.playerName)
              console.log('Left and Right channels ', evt.leftChannel, evt.rightChannel)
            }
        );
    }

    componentWillUnmount() {
      this.subscription.remove();
    }

    handleSeekForward() {
      ReactNativeAudioStreaming.getStatus(status=>{
        if (!err) {
        console.log('currentTime',status.progress)
          ReactNativeAudioStreaming.seekToTime("one",status.progress+10);
        }
      },"one")
    }

    render() {
        return (
            <View style={styles.container}>
            <Text onPress={this.handleSeekForward}>Seek forward</Text>
                <ListView
                    dataSource={this.state.dataSource}
                    renderRow={(rowData) =>
                        <TouchableOpacity onPress={() => {
                            this.setState({selectedSource: rowData.url, dataSource: this.ds.cloneWithRows(this.urls)});
                            const name = "player" + this.playersName.length;
                            this.playersName.push(name);
                            ReactNativeAudioStreaming.initNewPlayer(name);
                            ReactNativeAudioStreaming.play(name,rowData.url, {showIniOSMediaCenter: false});
                        }}>
                            <View style={StyleSheet.flatten([
                                styles.row,
                                {backgroundColor: rowData.url == this.state.selectedSource ? '#3fb5ff' : 'white'}
                            ])}>
                                <Text style={styles.icon}>▸</Text>
                                <View style={styles.column}>
                                    <Text style={styles.name}>{rowData.name}</Text>
                                    <Text style={styles.url}>{rowData.url}</Text>
                                </View>
                            </View>
                        </TouchableOpacity>
                    }
                />
                <Text onPress={()=>{
                  if (this.playersName.length>=0) {
                    const name = this.playersName.pop();
                    ReactNativeAudioStreaming.pause(name)
                  }
                }}>Pause</Text>
            </View>
        );
    }
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        justifyContent: 'center',
        alignItems: 'center',
        backgroundColor: '#F5FCFF',
        paddingTop: Platform.OS === 'ios' ? 30 : 0
    },
    row: {
        flex: 1,
        flexDirection: 'row',
        padding: 5,
        borderBottomColor: 'grey',
        borderBottomWidth: 1
    },
    column: {
        flexDirection: 'column'
    },
    icon: {
        fontSize: 26,
        width: 30,
        textAlign: 'center'
    },
    name: {
        color: '#000'
    },
    url: {
        color: '#CCC'
    }
});
