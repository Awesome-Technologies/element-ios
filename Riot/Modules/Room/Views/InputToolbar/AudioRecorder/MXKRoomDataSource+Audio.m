//
//  MXKRoomDataSource+Audio.m
//  Riot
//
//  Created by Marco Festini on 15.06.19.
//  Copyright © 2019 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

#import "MXKRoomDataSource+Audio.h"

@interface MXKRoomDataSource ()

// Make private methods available
- (void)queueEventForProcessing:(MXEvent*)event withRoomState:(MXRoomState*)roomState direction:(MXTimelineDirection)direction;
- (void)processQueuedEvents:(void (^)(NSUInteger addedHistoryCellNb, NSUInteger addedLiveCellNb))onComplete;

@end

@implementation MXKRoomDataSource (Audio)

- (void)sendAudioFile:(NSURL *)audioFileURL mimeType:(NSString*)mimeType success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure
{
    __block MXEvent *localEchoEvent = nil;
    
    [self.room sendAudioFile:audioFileURL mimeType:mimeType localEcho:&localEchoEvent success:success failure:failure keepActualFilename:YES];
    
    if (localEchoEvent)
    {
        // Make the data source digest this fake local echo message
        [self queueEventForProcessing:localEchoEvent withRoomState:self.roomState direction:MXTimelineDirectionForwards];
        [self processQueuedEvents:nil];
    }
}

- (void)resendAudioEventWithEventId:(NSString *)eventId success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure
{
    MXEvent *event = [self eventWithEventId:eventId];
    
    // Sanity check
    if (!event)
    {
        return;
    }
    
    NSLog(@"[MXKRoomDataSource+Audio] resendAudioEventWithEventId. Event: %@", event);
    
    bool isAudioEvent = false;
    
    if ([event.type isEqualToString:kMXEventTypeStringRoomMessage])
    {
        // And retry the send the message according to its type
        NSString *msgType = event.content[@"msgtype"];
        if ([msgType isEqualToString:kMXMessageTypeAudio])
        {
            isAudioEvent = true;
            
            // Check whether the sending failed while uploading the data.
            // If the content url corresponds to a upload id, the upload was not complete.
            NSString *contentURL = event.content[@"url"];
            if (contentURL && [contentURL hasPrefix:kMXMediaUploadIdPrefix])
            {
                NSString *mimetype = nil;
                if (event.content[@"info"])
                {
                    mimetype = event.content[@"info"][@"mimetype"];
                }
                
                if (mimetype)
                {
                    // Restart sending the image from the beginning.
                    
                    // Remove the local echo
                    [self removeEventWithEventId:eventId];
                    
                    NSString *localFilePath = [MXMediaManager cachePathForMatrixContentURI:contentURL andType:mimetype inFolder:self.roomId];
                    
                    [self sendAudioFile:[NSURL fileURLWithPath:localFilePath isDirectory:NO] mimeType:mimetype success:success failure:failure];
                }
                else
                {
                    NSLog(@"[MXKRoomDataSource+Audio] resendEventWithEventId: Warning - Unable to resend room message of type: %@", msgType);
                }
            }
            else
            {
                // Resend the Matrix event by reusing the existing echo
                [self.room sendMessageWithContent:event.content localEcho:&event success:success failure:failure];
            }
        }
    }
    
    // Event is not an audio event
    // Let base class handle event
    if (!isAudioEvent) {
        [self resendEventWithEventId:eventId success:success failure:failure];
    }
}

@end
