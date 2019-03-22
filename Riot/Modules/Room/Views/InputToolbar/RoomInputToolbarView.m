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

@interface RoomInputToolbarView()
{
    // Image picker
    UIImagePickerController *mediaPicker;
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
    
    self.rightInputToolbarButton.hidden = YES;
    
    [self.rightInputToolbarButton setTitleColor:ThemeService.shared.theme.textPrimaryColor forState:UIControlStateNormal];
    [self.rightInputToolbarButton setTitleColor:ThemeService.shared.theme.textPrimaryColor forState:UIControlStateHighlighted];
    
    self.isEncryptionEnabled = _isEncryptionEnabled;
    
    self.attachMediaButton.imageView.tintColor = ThemeService.shared.theme.textPrimaryColor;
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
    growingTextView.tintColor = ThemeService.shared.theme.tintColor;
    
    growingTextView.internalTextView.keyboardAppearance = ThemeService.shared.theme.keyboardAppearance;
}

#pragma mark -

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
    
    
    self.placeholder = placeholder;
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
    
    self.placeholder = placeholder;
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
        
        self.messageComposerContainerTrailingConstraint.constant = self.frame.size.width - self.rightInputToolbarButton.frame.origin.x + 4;
    }
    else if (!self.rightInputToolbarButton.isEnabled && !self.rightInputToolbarButton.isHidden)
    {
        self.rightInputToolbarButton.hidden = YES;
        self.attachMediaButton.hidden = NO;
        
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

#pragma mark - Override MXKRoomInputToolbarView

- (IBAction)onTouchUpInside:(UIButton*)button
{
    if (button == self.attachMediaButton)
    {
        // Check whether media attachment is supported
        if ([self.delegate respondsToSelector:@selector(roomInputToolbarView:presentViewController:)])
        {
            [self showMediaPicker];
        }
        else
        {
            NSLog(@"[RoomInputToolbarView] Attach media is not supported");
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
