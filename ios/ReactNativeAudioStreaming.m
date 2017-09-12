#import "RCTBridgeModule.h"
#import "RCTEventDispatcher.h"

#import "ReactNativeAudioStreaming.h"

#define LPN_AUDIO_BUFFER_SEC 20 // Can't use this with shoutcast buffer meta data

@import AVFoundation;

@implementation ReactNativeAudioStreaming
{
   bool hasListeners;
}


@synthesize bridge = _bridge;

RCT_EXPORT_MODULE()
- (dispatch_queue_t)methodQueue
{
   return dispatch_get_main_queue();
}

- (ReactNativeAudioStreaming *)init
{
   self = [super init];
   if (self) {
      [self setSharedAudioSessionCategory];
      self.audioPlayers = [NSMutableDictionary new];
      self.interruptedPlayers = [NSMutableArray new];
      self.lastUrlString = @"";
      [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
      
      NSLog(@"AudioPlayer initialized");
   }
   
   return self;
}

- (NSArray<NSString *> *)supportedEvents
{
   return @[@"AudioBridgeEvent"];
}

// Will be called when this module's first listener is added.
-(void)startObserving {
   hasListeners = YES;
   // Set up any upstream listeners or background tasks as necessary
}

// Will be called when this module's last listener is removed, or on dealloc.
-(void)stopObserving {
   hasListeners = NO;
   // Remove upstream listeners, stop unnecessary background tasks
}

-(void) tick:(NSTimer*)timer
{
   if (!hasListeners || !self.audioPlayers || [self.audioPlayers count] == 0) {
      return;
   }
   
   
   for(NSString* playerName in self.audioPlayers) {
      STKAudioPlayer *audioPlayer = [self.audioPlayers objectForKey:playerName];
      if (audioPlayer && audioPlayer.currentlyPlayingQueueItemId != nil && audioPlayer.state == STKAudioPlayerStatePlaying){
         NSNumber *progress = [NSNumber numberWithFloat:audioPlayer.progress];
         NSNumber *duration = [NSNumber numberWithFloat:audioPlayer.duration];
         NSString *url = [NSString stringWithString:audioPlayer.currentlyPlayingQueueItemId];
         NSNumber *rightChannel = [NSNumber numberWithFloat: [audioPlayer averagePowerInDecibelsForChannel:0]];
         NSNumber *leftChannel = [NSNumber numberWithFloat: [audioPlayer averagePowerInDecibelsForChannel:1]];
         
         [self sendEventWithName:@"AudioBridgeEvent"  body:@{
                                                             @"status": @"STREAMING",
                                                             @"progress": progress,
                                                             @"duration": duration,
                                                             @"url": url,
                                                             @"rightChannel": rightChannel,
                                                             @"leftChannel": leftChannel,
                                                             @"playerName": playerName
                                                             }];
      }
   }
}


- (void)dealloc
{
   [self unregisterAudioInterruptionNotifications];
   [self.audioPlayers removeAllObjects];
}


#pragma mark - Pubic API

RCT_EXPORT_METHOD(initNewPlayer:(NSString *) playerName)
{
   STKAudioPlayer *audioPlayer = [self.audioPlayers objectForKey: playerName];
   if (audioPlayer) {
      audioPlayer = nil;
   }
   
   
   STKAudioPlayer *newAudioPlayer = [[STKAudioPlayer alloc] initWithOptions:(STKAudioPlayerOptions){ .flushQueueOnSeek = YES }];
   [newAudioPlayer setMeteringEnabled: YES];
   [newAudioPlayer setDelegate:self];
   
   [self.audioPlayers setValue:newAudioPlayer forKey:playerName];
}

RCT_EXPORT_METHOD(closePlayer:(NSString *) playerName)
{
   STKAudioPlayer *audioPlayer = [self.audioPlayers objectForKey: playerName];
   if (audioPlayer) {
      audioPlayer = nil;
   }
   [self.audioPlayers removeObjectForKey:playerName];
}

RCT_EXPORT_METHOD(play:(NSString *)playerName url:(NSString *) streamUrl options:(NSDictionary *)options)
{
   STKAudioPlayer *audioPlayer = [self.audioPlayers objectForKey: playerName];
   if (!audioPlayer) {
      return;
   }
   
   [self activate];
   
   if (audioPlayer.state == STKAudioPlayerStatePaused && [self.lastUrlString isEqualToString:streamUrl]) {
      [audioPlayer resume];
   } else {
      [audioPlayer play:streamUrl];
   }
   
   self.lastUrlString = streamUrl;
   self.showNowPlayingInfo = false;
   
   if ([options objectForKey:@"showIniOSMediaCenter"]) {
      self.showNowPlayingInfo = [[options objectForKey:@"showIniOSMediaCenter"] boolValue];
   }
   
   if (self.showNowPlayingInfo) {
      //unregister any existing registrations
      [self unregisterAudioInterruptionNotifications];
      //register
      [self registerAudioInterruptionNotifications];
   }
   
   [self setNowPlayingInfo:true];
}

RCT_EXPORT_METHOD(seek:(NSString *)playerName ToTime:(double) seconds)
{
   STKAudioPlayer *audioPlayer = [self.audioPlayers objectForKey: playerName];
   if (!audioPlayer) {
      return;
   }
   
   [audioPlayer seekToTime:seconds];
}

RCT_EXPORT_METHOD(goForward:(NSString *)playerName ByTime:(double) seconds)
{
   STKAudioPlayer *audioPlayer = [self.audioPlayers objectForKey: playerName];
   if (!audioPlayer) {
      return;
   }
   
   double newtime = audioPlayer.progress + seconds;
   
   if (audioPlayer.duration < newtime) {
      [audioPlayer stop];
      [self setNowPlayingInfo:false];
   } else {
      [audioPlayer seekToTime:newtime];
   }
}

RCT_EXPORT_METHOD(goBack:(NSString *)playerName ByTime:(double) seconds)
{
   STKAudioPlayer *audioPlayer = [self.audioPlayers objectForKey: playerName];
   if (!audioPlayer) {
      return;
   }
   
   double newtime = audioPlayer.progress - seconds;
   
   if (newtime < 0) {
      [audioPlayer seekToTime:0.0];
   } else {
      [audioPlayer seekToTime:newtime];
   }
}

RCT_EXPORT_METHOD(pause:(NSString *)playerName)
{
   STKAudioPlayer *audioPlayer = [self.audioPlayers objectForKey: playerName];
   if (!audioPlayer) {
      return;
   } else {
      [audioPlayer pause];
      [self setNowPlayingInfo:false];
      [self deactivate];
   }
}

RCT_EXPORT_METHOD(resume:(NSString *)playerName)
{
   STKAudioPlayer *audioPlayer = [self.audioPlayers objectForKey: playerName];
   if (!audioPlayer) {
      return;
   } else {
      [self activate];
      [audioPlayer resume];
      [self setNowPlayingInfo:true];
   }
}

RCT_EXPORT_METHOD(stop:(NSString *)playerName)
{
   STKAudioPlayer *audioPlayer = [self.audioPlayers objectForKey: playerName];
   if (!audioPlayer) {
      return;
   } else {
      [audioPlayer stop];
      [self setNowPlayingInfo:false];
      [self deactivate];
   }
}

RCT_EXPORT_METHOD(getStatus: (RCTResponseSenderBlock) callback OfPlayer:(NSString *)playerName)
{
   STKAudioPlayer *audioPlayer = [self.audioPlayers objectForKey: playerName];
   
   NSString *status = @"STOPPED";
   NSNumber *duration = [NSNumber numberWithFloat:audioPlayer.duration];
   NSNumber *progress = [NSNumber numberWithFloat:audioPlayer.progress];
   
   if (!audioPlayer) {
      status = @"ERROR";
   } else if ([audioPlayer state] == STKAudioPlayerStatePlaying) {
      status = @"PLAYING";
   } else if ([audioPlayer state] == STKAudioPlayerStatePaused) {
      status = @"PAUSED";
   } else if ([audioPlayer state] == STKAudioPlayerStateBuffering) {
      status = @"BUFFERING";
   }
   
   callback(@[[NSNull null], @{@"status": status, @"progress": progress, @"duration": duration, @"url": self.lastUrlString}]);
}

#pragma mark - StreamingKit Audio Player


- (void)audioPlayer:(STKAudioPlayer *)player didStartPlayingQueueItemId:(NSObject *)queueItemId
{
   NSLog(@"AudioPlayer is playing");
}

- (void)audioPlayer:(STKAudioPlayer *)player didFinishPlayingQueueItemId:(NSObject *)queueItemId withReason:(STKAudioPlayerStopReason)stopReason andProgress:(double)progress andDuration:(double)duration
{
   NSLog(@"AudioPlayer has stopped");
}

- (void)audioPlayer:(STKAudioPlayer *)player didFinishBufferingSourceWithQueueItemId:(NSObject *)queueItemId
{
   NSLog(@"AudioPlayer finished buffering");
}

- (void)audioPlayer:(STKAudioPlayer *)player unexpectedError:(STKAudioPlayerErrorCode)errorCode {
   NSLog(@"AudioPlayer unexpected Error with code %d", errorCode);
}

- (void)audioPlayer:(STKAudioPlayer *)audioPlayer didReadStreamMetadata:(NSDictionary *)dictionary {
   NSLog(@"AudioPlayer SONG NAME  %@", dictionary[@"StreamTitle"]);
   
   self.currentSong = dictionary[@"StreamTitle"] ? dictionary[@"StreamTitle"] : @"";
   [self.bridge.eventDispatcher sendDeviceEventWithName:@"AudioBridgeEvent" body:@{
                                                                                   @"status": @"METADATA_UPDATED",
                                                                                   @"key": @"StreamTitle",
                                                                                   @"value": self.currentSong
                                                                                   }];
   [self setNowPlayingInfo:true];
}

- (void)audioPlayer:(STKAudioPlayer *)player stateChanged:(STKAudioPlayerState)state previousState:(STKAudioPlayerState)previousState
{
   NSNumber *duration = [NSNumber numberWithFloat:player.duration];
   NSNumber *progress = [NSNumber numberWithFloat:player.progress];
   
   switch (state) {
         case STKAudioPlayerStatePlaying:
         [self.bridge.eventDispatcher sendDeviceEventWithName:@"AudioBridgeEvent"
                                                         body:@{@"status": @"PLAYING", @"progress": progress, @"duration": duration, @"url": self.lastUrlString}];
         break;
         
         case STKAudioPlayerStatePaused:
         [self.bridge.eventDispatcher sendDeviceEventWithName:@"AudioBridgeEvent"
                                                         body:@{@"status": @"PAUSED", @"progress": progress, @"duration": duration, @"url": self.lastUrlString}];
         break;
         
         case STKAudioPlayerStateStopped:
         [self.bridge.eventDispatcher sendDeviceEventWithName:@"AudioBridgeEvent"
                                                         body:@{@"status": @"STOPPED", @"progress": progress, @"duration": duration, @"url": self.lastUrlString}];
         break;
         
         case STKAudioPlayerStateBuffering:
         [self.bridge.eventDispatcher sendDeviceEventWithName:@"AudioBridgeEvent"
                                                         body:@{@"status": @"BUFFERING"}];
         break;
         
         case STKAudioPlayerStateError:
         [self.bridge.eventDispatcher sendDeviceEventWithName:@"AudioBridgeEvent"
                                                         body:@{@"status": @"ERROR"}];
         break;
         
      default:
         break;
   }
}


#pragma mark - Audio Session

- (void)activate
{
   NSError *categoryError = nil;
   
   [[AVAudioSession sharedInstance] setActive:YES error:&categoryError];
   [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&categoryError];
   
   if (categoryError) {
      NSLog(@"Error setting category! %@", [categoryError description]);
   }
}

- (void)deactivate
{
   NSError *categoryError = nil;
   
   [[AVAudioSession sharedInstance] setActive:NO error:&categoryError];
   
   if (categoryError) {
      NSLog(@"Error setting category! %@", [categoryError description]);
   }
}

- (void)setSharedAudioSessionCategory
{
   NSError *categoryError = nil;
   self.isPlayingWithOthers = [[AVAudioSession sharedInstance] isOtherAudioPlaying];
   
   [[AVAudioSession sharedInstance] setActive:NO error:&categoryError];
   [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:&categoryError];
   
   if (categoryError) {
      NSLog(@"Error setting category! %@", [categoryError description]);
   }
}

- (void)registerAudioInterruptionNotifications
{
   // Register for audio interrupt notifications
   [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(onAudioInterruption:)
                                                name:AVAudioSessionInterruptionNotification
                                              object:nil];
   // Register for route change notifications
   [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(onRouteChangeInterruption:)
                                                name:AVAudioSessionRouteChangeNotification
                                              object:nil];
}

- (void)unregisterAudioInterruptionNotifications
{
   [[NSNotificationCenter defaultCenter] removeObserver:self
                                                   name:AVAudioSessionRouteChangeNotification
                                                 object:nil];
   [[NSNotificationCenter defaultCenter] removeObserver:self
                                                   name:AVAudioSessionInterruptionNotification
                                                 object:nil];
}

- (void)onAudioInterruption:(NSNotification *)notification
{
   // Get the user info dictionary
   NSDictionary *interruptionDict = notification.userInfo;
   
   // Get the AVAudioSessionInterruptionTypeKey enum from the dictionary
   NSInteger interuptionType = [[interruptionDict valueForKey:AVAudioSessionInterruptionTypeKey] integerValue];
   
   // Decide what to do based on interruption type
   switch (interuptionType)
   {
         case AVAudioSessionInterruptionTypeBegan:
         NSLog(@"Audio Session Interruption case started.");
         for(NSString* key in self.audioPlayers) {
            STKAudioPlayer *audioPlayer = [self.audioPlayers objectForKey:key];
            if (audioPlayer && audioPlayer.state == STKAudioPlayerStatePlaying) {
               [self.interruptedPlayers addObject:key];
            }
            [audioPlayer pause];
         }
         break;
         
         case AVAudioSessionInterruptionTypeEnded:
         NSLog(@"Audio Session Interruption case ended.");
         self.isPlayingWithOthers = [[AVAudioSession sharedInstance] isOtherAudioPlaying];
         
         if (self.isPlayingWithOthers) {
            for(NSString* key in self.audioPlayers) {
               STKAudioPlayer *audioPlayer = [self.audioPlayers objectForKey:key];
               if (audioPlayer){
                  [audioPlayer stop];
               }
            }
            [self.interruptedPlayers removeAllObjects];
         } else {
            // Resume only interrupted players
            for(NSString* key in self.interruptedPlayers) {
               STKAudioPlayer *audioPlayer = [self.audioPlayers objectForKey:key];
               if (audioPlayer) {
                  [audioPlayer resume];
               }
            }
            [self.interruptedPlayers removeAllObjects];
         }
         break;
         
      default:
         NSLog(@"Audio Session Interruption Notification case default.");
         break;
   }
}

- (void)onRouteChangeInterruption:(NSNotification *)notification
{
   
   NSDictionary *interruptionDict = notification.userInfo;
   NSInteger routeChangeReason = [[interruptionDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
   
   switch (routeChangeReason)
   {
         case AVAudioSessionRouteChangeReasonUnknown:
         NSLog(@"routeChangeReason : AVAudioSessionRouteChangeReasonUnknown");
         break;
         
         case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
         // A user action (such as plugging in a headset) has made a preferred audio route available.
         NSLog(@"routeChangeReason : AVAudioSessionRouteChangeReasonNewDeviceAvailable");
         break;
         
         case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
         // The previous audio output path is no longer available.
         
         for(NSString* key in self.audioPlayers) {
            STKAudioPlayer *audioPlayer = [self.audioPlayers objectForKey:key];
            if (audioPlayer){
               [audioPlayer stop];
            }
         }
         break;
         
         case AVAudioSessionRouteChangeReasonCategoryChange:
         // The category of the session object changed. Also used when the session is first activated.
         NSLog(@"routeChangeReason : AVAudioSessionRouteChangeReasonCategoryChange"); //AVAudioSessionRouteChangeReasonCategoryChange
         break;
         
         case AVAudioSessionRouteChangeReasonOverride:
         // The output route was overridden by the app.
         NSLog(@"routeChangeReason : AVAudioSessionRouteChangeReasonOverride");
         break;
         
         case AVAudioSessionRouteChangeReasonWakeFromSleep:
         // The route changed when the device woke up from sleep.
         NSLog(@"routeChangeReason : AVAudioSessionRouteChangeReasonWakeFromSleep");
         break;
         
         case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
         // The route changed because no suitable route is now available for the specified category.
         NSLog(@"routeChangeReason : AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory");
         break;
   }
}

#pragma mark - Remote Control Events

- (void)setNowPlayingInfo:(bool)isPlaying
{
   if (self.showNowPlayingInfo) {
      // TODO Get artwork from stream
      // MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc]initWithImage:[UIImage imageNamed:@"webradio1"]];
      
      NSString* appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
      NSDictionary *nowPlayingInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      self.currentSong ? self.currentSong : @"", MPMediaItemPropertyAlbumTitle,
                                      @"", MPMediaItemPropertyAlbumArtist,
                                      appName ? appName : @"AppName", MPMediaItemPropertyTitle,
                                      [NSNumber numberWithFloat:isPlaying ? 1.0f : 0.0], MPNowPlayingInfoPropertyPlaybackRate, nil];
      [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nowPlayingInfo;
   }
}

@end
