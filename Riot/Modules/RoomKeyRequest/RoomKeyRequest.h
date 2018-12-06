/*
 Copyright 2017 Vector Creations Ltd

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import <UIKit/UIKit.h>

#import <MatrixSDK/MatrixSDK.h>
#import <MatrixKit/MatrixKit.h>

/**
 `RoomKeyRequest` allows to accept all pending keys without verifying the devices.
 */
@interface RoomKeyRequest : NSObject

@property (nonatomic, readonly) MXSession *mxSession;
@property (nonatomic, readonly) MXDeviceInfo *device;

/**
 Initialise an `RoomKeyRequest` instance.

 @param deviceInfo the device to share keys to.
 @param session the related matrix session.
 @param onComplete a block called when the the dialog is closed.
 @return the newly created instance.
 */
- (instancetype)initWithDeviceInfo:(MXDeviceInfo*)deviceInfo andMatrixSession:(MXSession*)session onComplete:(void (^)())onComplete;

/**
 Accept all pending keys but not verify devices.
 */
- (void)acceptAllKeys;

@end
