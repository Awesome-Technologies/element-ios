/*
 Copyright 2015 OpenMarket Ltd
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

#import "RoomInputToolbarView.h"

#import "ThemeService.h"
#import "Riot-Swift.h"

#import "GBDeviceInfo_iOS.h"

#import "UINavigationController+Riot.h"

#import <MediaPlayer/MediaPlayer.h>

#import <Photos/Photos.h>

#import <MobileCoreServices/MobileCoreServices.h>

#import "WidgetManager.h"
#import "IntegrationManagerViewController.h"

@interface RoomInputToolbarView()
{
    // Image picker
    UIImagePickerController *mediaPicker;
    
    // The intermediate action sheet
    UIAlertController *actionSheet;
    
    // Timer to update placerholder when recording voice message
    CADisplayLink *placeholderTimer;
}

@end

@implementation RoomInputToolbarView
@dynamic delegate;

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([RoomInputToolbarView class])
                          bundle:[NSBundle bundleForClass:[RoomInputToolbarView class]]];
}

+ (instancetype)roomInputToolbarView
{
    if ([[self class] nib])
    {
        return [[[self class] nib] instantiateWithOwner:nil options:nil].firstObject;
    }
    else
    {
        return [[self alloc] init];
    }
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    _supportCallOption = YES;
    
    self.rightInputToolbarButton.hidden = YES;
    
    [self.rightInputToolbarButton setTitleColor:ThemeService.shared.theme.textPrimaryColor forState:UIControlStateNormal];
    [self.rightInputToolbarButton setTitleColor:ThemeService.shared.theme.textPrimaryColor forState:UIControlStateHighlighted];
    
    self.isEncryptionEnabled = _isEncryptionEnabled;
    
    self.attachMediaButton.imageView.tintColor = ThemeService.shared.theme.textPrimaryColor;
    [self.cancelAudioButton.imageView setTintColor:ThemeService.shared.theme.warningColor];
    
    [self.pauseAudioButton setHidden:YES];
    [self.cancelAudioButton setHidden:YES];
    
    placeholderTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(setVoiceRecordingPlaceholder)];
    [placeholderTimer addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    [placeholderTimer setPaused:YES];
    
    [AudioRecorder shared].delegate = self;
}

#pragma mark - Override MXKView

-(void)customizeViewRendering
{
    [super customizeViewRendering];
    
    // Remove default toolbar background color
    self.backgroundColor = [UIColor clearColor];
    
    self.separatorView.backgroundColor = ThemeService.shared.theme.lineBreakColor;
    
    // Custom the growingTextView display
    growingTextView.layer.cornerRadius = 0;
    growingTextView.layer.borderWidth = 0;
    growingTextView.backgroundColor = [UIColor clearColor];
    
    growingTextView.font = [UIFont systemFontOfSize:15];
    growingTextView.textColor = ThemeService.shared.theme.textPrimaryColor;
    growingTextView.tintColor = ThemeService.shared.theme.textTintColor;
    
    growingTextView.internalTextView.keyboardAppearance = ThemeService.shared.theme.keyboardAppearance;
}

#pragma mark -

- (void)setSupportCallOption:(BOOL)supportCallOption
{
    if (_supportCallOption != supportCallOption)
    {
        _supportCallOption = supportCallOption;
        
        [self updateVoiceCallInterfaceElements];
    }
}

- (void)setIsEncryptionEnabled:(BOOL)isEncryptionEnabled
{
    _isEncryptionEnabled = isEncryptionEnabled;
    
    // Consider the default placeholder
    NSString *placeholder= NSLocalizedStringFromTable(@"room_message_short_placeholder", @"Vector", nil);
    
    if (_isEncryptionEnabled)
    {
        self.encryptedRoomIcon.image = [UIImage imageNamed:@"e2e_verified"];
        
        // Check the device screen size before using large placeholder
        if ([GBDeviceInfo deviceInfo].family == GBDeviceFamilyiPad || [GBDeviceInfo deviceInfo].displayInfo.display >= GBDeviceDisplay4p7Inch)
        {
            placeholder = NSLocalizedStringFromTable(@"encrypted_room_message_placeholder", @"Vector", nil);
        }
    }
    else
    {
        self.encryptedRoomIcon.image = [UIImage imageNamed:@"e2e_unencrypted"];
        
        // Check the device screen size before using large placeholder
        if ([GBDeviceInfo deviceInfo].family == GBDeviceFamilyiPad || [GBDeviceInfo deviceInfo].displayInfo.display >= GBDeviceDisplay4p7Inch)
        {
            placeholder = NSLocalizedStringFromTable(@"room_message_placeholder", @"Vector", nil);
        }
    }
    
    if ([AudioRecorder shared].isRecordingOrPaused)
    {
        [self setVoiceRecordingPlaceholder];
    }
    else
    {
        self.placeholder = placeholder;
    }
}

- (void)setReplyToEnabled:(BOOL)isReplyToEnabled
{
    _replyToEnabled = isReplyToEnabled;
    
    [self updatePlaceholder];
}

- (void)updatePlaceholder
{
    // Consider the default placeholder
    
    NSString *placeholder;
    
    // Check the device screen size before using large placeholder
    BOOL shouldDisplayLargePlaceholder = [GBDeviceInfo deviceInfo].family == GBDeviceFamilyiPad || [GBDeviceInfo deviceInfo].displayInfo.display >= GBDeviceDisplay4p7Inch;
    
    if (!shouldDisplayLargePlaceholder)
    {
        placeholder = _replyToEnabled ? NSLocalizedStringFromTable(@"room_message_reply_to_short_placeholder", @"Vector", nil) : NSLocalizedStringFromTable(@"room_message_short_placeholder", @"Vector", nil);
    }
    else
    {
        if (_isEncryptionEnabled)
        {
            placeholder = _replyToEnabled ? NSLocalizedStringFromTable(@"encrypted_room_message_reply_to_placeholder", @"Vector", nil) : NSLocalizedStringFromTable(@"encrypted_room_message_placeholder", @"Vector", nil);
        }
        else
        {
            placeholder = _replyToEnabled ? NSLocalizedStringFromTable(@"room_message_reply_to_placeholder", @"Vector", nil) : NSLocalizedStringFromTable(@"room_message_placeholder", @"Vector", nil);
        }
    }
    
    if ([AudioRecorder shared].isRecordingOrPaused)
    {
        [self setVoiceRecordingPlaceholder];
    }
    else
    {
        self.placeholder = placeholder;
    }
}

- (void)setVoiceRecordingPlaceholder
{
    if ([AudioRecorder shared].isPaused)
    {
        self.placeholder = [NSString stringWithFormat:NSLocalizedStringFromTable(@"room_message_recording_voice_placeholder", @"Vector", nil), NSLocalizedStringFromTable(@"paused", @"Vector", nil)];
    }
    else if ([AudioRecorder shared].isRecordingOrPaused)
    {
        self.placeholder = [NSString stringWithFormat:NSLocalizedStringFromTable(@"room_message_recording_voice_placeholder", @"Vector", nil), [AudioRecorder shared].recordingTimeString];
    }
    else
    {
        [placeholderTimer setPaused:YES];
        [self updatePlaceholder];
    }
}

- (void)setActiveCall:(BOOL)activeCall
{
    if (_activeCall != activeCall)
    {
        _activeCall = activeCall;
        
        [self updateVoiceCallInterfaceElements];
    }
}

- (void)updateVoiceCallInterfaceElements
{
    if (_supportCallOption && ![AudioRecorder shared].isRecordingOrPaused)
    {
        self.voiceCallButtonWidthConstraint.constant = 46;
    }
    else
    {
        self.voiceCallButtonWidthConstraint.constant = 0;
    }
    
    [self setNeedsUpdateConstraints];
    
    self.attachMediaButton.hidden = _activeCall;
    self.voiceCallButton.hidden = (_activeCall || !self.rightInputToolbarButton.hidden) || [AudioRecorder shared].isRecordingOrPaused;
    self.hangupCallButton.hidden = (!_activeCall || !self.rightInputToolbarButton.hidden) || [AudioRecorder shared].isRecordingOrPaused;
    
    [self updatePlaceholder];
}

#pragma mark - HPGrowingTextView delegate

//- (BOOL)growingTextViewShouldReturn:(HPGrowingTextView *)hpGrowingTextView
//{
//    // The return sends the message rather than giving a carriage return.
//    [self onTouchUpInside:self.rightInputToolbarButton];
//    
//    return NO;
//}

- (void)growingTextViewDidChange:(HPGrowingTextView *)hpGrowingTextView
{
    // Clean the carriage return added on return press
    if ([self.textMessage isEqualToString:@"\n"])
    {
        self.textMessage = nil;
    }
    
    [super growingTextViewDidChange:hpGrowingTextView];
    
    if (self.rightInputToolbarButton.isEnabled && self.rightInputToolbarButton.isHidden)
    {
        self.rightInputToolbarButton.hidden = NO;
        self.attachMediaButton.hidden = YES;
        self.voiceCallButton.hidden = YES;
        self.hangupCallButton.hidden = YES;
        
        self.messageComposerContainerTrailingConstraint.constant = self.frame.size.width - self.rightInputToolbarButton.frame.origin.x + 4;
    }
    else if (!self.rightInputToolbarButton.isEnabled && !self.rightInputToolbarButton.isHidden)
    {
        self.rightInputToolbarButton.hidden = YES;
        self.attachMediaButton.hidden = _activeCall;
        self.voiceCallButton.hidden = _activeCall;
        self.hangupCallButton.hidden = !_activeCall;
        
        self.messageComposerContainerTrailingConstraint.constant = self.frame.size.width - self.attachMediaButton.frame.origin.x + 4;
    }
}

- (void)growingTextView:(HPGrowingTextView *)hpGrowingTextView willChangeHeight:(float)height
{
    // Update height of the main toolbar (message composer)
    CGFloat updatedHeight = height + (self.messageComposerContainerTopConstraint.constant + self.messageComposerContainerBottomConstraint.constant);
    
    if (updatedHeight < self.mainToolbarMinHeightConstraint.constant)
    {
        updatedHeight = self.mainToolbarMinHeightConstraint.constant;
    }
    
    self.mainToolbarHeightConstraint.constant = updatedHeight;
    
    // Update toolbar superview
    if ([self.delegate respondsToSelector:@selector(roomInputToolbarView:heightDidChanged:completion:)])
    {
        [self.delegate roomInputToolbarView:self heightDidChanged:updatedHeight completion:nil];
    }
}

#pragma mark - AudioRecorderDelegate

- (void)voiceRecordingDidStartRecording
{
    [placeholderTimer setPaused:NO];
    
    [self.attachMediaButton.imageView setTintColor:[UIColor colorWithRed:0.13 green:0.7 blue:0.52 alpha:1]];
    
    [self->growingTextView setEditable:NO];
    [self updateVoiceCallInterfaceElements];
    
    [self.cancelAudioButton setHidden:NO];
    [self.pauseAudioButton setHidden:NO];
    [self.pauseAudioButton setImage:[UIImage imageNamed:@"pause-audio"] forState:UIControlStateNormal];
    
    [self setReplyToEnabled:NO];
    
    [self setNeedsUpdateConstraints];
}

- (void)voiceRecordingDidPauseRecording
{
    [self.pauseAudioButton setImage:[UIImage imageNamed:@"play-audio"] forState:UIControlStateNormal];
    [placeholderTimer setPaused:YES];
    [self setVoiceRecordingPlaceholder];
}

- (void)presentAlertController:(UIAlertController *)alertController
{
    [self.window.rootViewController presentViewController:alertController animated:YES completion:nil];
}

- (void)voiceRecordingDidFinishRecordingWithURL:(NSURL *)audioFileURL
{
    [self.delegate roomInputToolbarView:self sendAudio:audioFileURL];
    [self resetFromVoiceRecording];
}

- (void)voiceRecordingDidStopRecording
{
    [self resetFromVoiceRecording];
}

- (void)resetFromVoiceRecording
{
    [placeholderTimer setPaused:YES];
    [self.attachMediaButton.imageView setTintColor:ThemeService.shared.theme.textPrimaryColor];
    
    [self->growingTextView setEditable:YES];
    [self.pauseAudioButton setHidden:YES];
    [self.cancelAudioButton setHidden:YES];
    [self updateVoiceCallInterfaceElements];
    
    [self setReplyToEnabled:YES];
}

- (void)reconstructAudioRecorderState {
    // Checking if a paused audio recorder exists
    if (![AudioRecorder shared].isPaused) {
        return;
    }
    [self voiceRecordingDidStartRecording];
    [self voiceRecordingDidPauseRecording];
}

#pragma mark - Override MXKRoomInputToolbarView

- (IBAction)onTouchUpInside:(UIButton*)button
{
    if (button == self.pauseAudioButton)
    {
        [[AudioRecorder shared] togglePauseRecording];
    }
    else if (button == self.cancelAudioButton)
    {
        [[AudioRecorder shared] cancelRecordingWithForceCancel:NO];
    }
    else if (button == self.attachMediaButton)
    {
        if ([AudioRecorder shared].isRecordingOrPaused)
        {
            [[AudioRecorder shared] stopRecording];
        }
        // Check whether media attachment is supported
        else if ([self.delegate respondsToSelector:@selector(roomInputToolbarView:presentViewController:)])
        {
            // Ask the user the kind of the call: voice or video?
            actionSheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
            
            [[AudioRecorder shared] prepareRecorder];
            
            __weak typeof(self) weakSelf = self;
            [actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"voice_message", @"Vector", nil)
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              
                                                              if (weakSelf)
                                                              {
                                                                  typeof(self) self = weakSelf;
                                                                  
                                                                  NSLog(@"[onTouchUpInside] Recording Audio");
                                                                  
                                                                  [[AudioRecorder shared] initRecorder];
                                                              }
                                                              
                                                          }]];
            
            [actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"camera", @"Vector", nil)
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              
                                                              if (weakSelf)
                                                              {
                                                                  typeof(self) self = weakSelf;
                                                                  
                                                                  [self showMediaPicker];
                                                              }
                                                              
                                                          }]];
            
            [actionSheet addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"]
                                                            style:UIAlertActionStyleCancel
                                                          handler:^(UIAlertAction * action) {
                                                              
                                                              if (weakSelf)
                                                              {
                                                                  typeof(self) self = weakSelf;
                                                                  self->actionSheet = nil;
                                                              }
                                                              
                                                          }]];
            
            [actionSheet popoverPresentationController].sourceView = self.voiceCallButton;
            [actionSheet popoverPresentationController].sourceRect = self.voiceCallButton.bounds;
            [self.window.rootViewController presentViewController:actionSheet animated:YES completion:nil];
        }
        else
        {
            NSLog(@"[RoomInputToolbarView] Attach media is not supported");
        }
    }
    else if (button == self.voiceCallButton)
    {
        if ([self.delegate respondsToSelector:@selector(roomInputToolbarView:placeCallWithVideo:)])
        {
            // Ask the user the kind of the call: voice or video?
            actionSheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
            
            __weak typeof(self) weakSelf = self;
            [actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"voice", @"Vector", nil)
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              
                                                              if (weakSelf)
                                                              {
                                                                  typeof(self) self = weakSelf;
                                                                  self->actionSheet = nil;
                                                                  
                                                                  [self.delegate roomInputToolbarView:self placeCallWithVideo:NO];
                                                              }
                                                              
                                                          }]];
            
            [actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"video", @"Vector", nil)
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              
                                                              if (weakSelf)
                                                              {
                                                                  typeof(self) self = weakSelf;
                                                                  self->actionSheet = nil;
                                                                  
                                                                  [self.delegate roomInputToolbarView:self placeCallWithVideo:YES];
                                                              }
                                                              
                                                          }]];
            
            [actionSheet addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"]
                                                            style:UIAlertActionStyleCancel
                                                          handler:^(UIAlertAction * action) {
                                                              
                                                              if (weakSelf)
                                                              {
                                                                  typeof(self) self = weakSelf;
                                                                  self->actionSheet = nil;
                                                              }
                                                              
                                                          }]];
            
            [actionSheet popoverPresentationController].sourceView = self.voiceCallButton;
            [actionSheet popoverPresentationController].sourceRect = self.voiceCallButton.bounds;
            [self.window.rootViewController presentViewController:actionSheet animated:YES completion:nil];
        }
    }
    else if (button == self.hangupCallButton && ![AudioRecorder shared].isRecordingOrPaused)
    {
        if ([self.delegate respondsToSelector:@selector(roomInputToolbarViewHangupCall:)])
        {
            [self.delegate roomInputToolbarViewHangupCall:self];
        }
    }

    [super onTouchUpInside:button];
}

- (void)showMediaPicker
{
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        // Open Camera
        mediaPicker = [[UIImagePickerController alloc] init];
        mediaPicker.delegate = self;
        mediaPicker.sourceType = UIImagePickerControllerSourceTypeCamera;
        mediaPicker.allowsEditing = NO;
        mediaPicker.mediaTypes = [NSArray arrayWithObjects:(NSString *)kUTTypeImage, (NSString *)kUTTypeMovie, nil];
        [self.delegate roomInputToolbarView:self presentViewController:mediaPicker];
    } else {
        NSLog(@"[RoomInputToolbarView] Camera not available");
    }
}

- (void)destroy
{
    [self dismissMediaPicker];
    
    if (actionSheet)
    {
        [actionSheet dismissViewControllerAnimated:NO completion:nil];
        actionSheet = nil;
    }
    
    [super destroy];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [self dismissMediaPicker];
    
    NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    if ([mediaType isEqualToString:(NSString *)kUTTypeImage])
    {
        UIImage *selectedImage = [info objectForKey:UIImagePickerControllerOriginalImage];
        if (selectedImage)
        {
            // Suggest compression before sending image
            NSData *imageData = UIImageJPEGRepresentation(selectedImage, 1.0);
            [self sendSelectedImage:imageData withMimeType:nil andCompressionMode:MXKRoomInputToolbarCompressionModeNone isPhotoLibraryAsset:NO];
        }
    }
    else if ([mediaType isEqualToString:(NSString *)kUTTypeMovie])
    {
        NSURL* selectedVideo = [info objectForKey:UIImagePickerControllerMediaURL];
        
        [self sendSelectedVideo:selectedVideo isPhotoLibraryAsset:NO];
    }
}

#pragma mark - Media picker handling

- (void)dismissMediaPicker
{
    if (mediaPicker)
    {
        mediaPicker.delegate = nil;
        
        if ([self.delegate respondsToSelector:@selector(roomInputToolbarView:dismissViewControllerAnimated:completion:)])
        {
            [self.delegate roomInputToolbarView:self dismissViewControllerAnimated:NO completion:^{
                mediaPicker = nil;
            }];
        }
    }
}

#pragma mark - Clipboard - Handle image/data paste from general pasteboard

- (void)paste:(id)sender
{
    
}

@end
