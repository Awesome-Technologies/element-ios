//
//  MXKRoomDataSource+Audio.h
//  Riot
//
//  Created by Marco Festini on 15.06.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

#import <MatrixKit/MatrixKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MXKRoomDataSource (Audio)

/**
 Send an audio file to the room.
 
 While sending, a fake event will be echoed in the messages list.
 Once complete, this local echo will be replaced by the event saved by the homeserver.
 
 @param audioFileURL the local filesystem path of the file to send.
 @param mimeType the mime type of the file.
 @param success A block object called when the operation succeeds. It returns
 the event id of the event generated on the home server
 @param failure A block object called when the operation fails.
 */
- (void)sendAudioFile:(NSURL *)audioFileURL mimeType:(NSString*)mimeType success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure;

/**
 Resend a room audio message event.
 
 The echo message corresponding to the event will be removed and a new echo message
 will be added at the end of the room history.
 
 @param eventId of the event to resend.
 @param success A block object called when the operation succeeds. It returns
 the event id of the event generated on the home server
 @param failure A block object called when the operation fails.
 */
- (void)resendAudioEventWithEventId:(NSString *)eventId success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure;

@end

NS_ASSUME_NONNULL_END
