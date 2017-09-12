// AudioManager.h
// From https://github.com/jhabdas/lumpen-radio/blob/master/iOS/Classes/AudioManager.h

#import "RCTBridgeModule.h"
#import "STKAudioPlayer.h"
#import <React/RCTEventEmitter.h>

@interface ReactNativeAudioStreaming : RCTEventEmitter <RCTBridgeModule, STKAudioPlayerDelegate>

@property (nonatomic, strong) NSMutableDictionary *audioPlayers;
@property (nonatomic, strong) NSMutableArray *interruptedPlayers;
@property (nonatomic, readwrite) BOOL isPlayingWithOthers;
@property (nonatomic, readwrite) BOOL showNowPlayingInfo;
@property (nonatomic, readwrite) NSString *lastUrlString;
@property (nonatomic, retain) NSString *currentSong;

- (void)play:(NSString *) streamUrl options:(NSDictionary *)options;
- (void)pause;

@end
