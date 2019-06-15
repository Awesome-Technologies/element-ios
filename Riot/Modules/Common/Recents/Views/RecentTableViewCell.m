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

#import "RecentTableViewCell.h"

#import "AvatarGenerator.h"

#import "MXEvent.h"

#import "ThemeService.h"
#import "Riot-Swift.h"

#import "MXRoomSummary+Riot.h"

#pragma mark - Defines & Constants

static const CGFloat kDirectRoomBorderColorAlpha = 0.75;
static const CGFloat kDirectRoomBorderWidth = 3.0;

@implementation RecentTableViewCell

#pragma mark - Class methods

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    // Initialize unread count badge
    [_missedNotifAndUnreadBadgeBgView.layer setCornerRadius:10];
    _missedNotifAndUnreadBadgeBgViewWidthConstraint.constant = 0;
}

- (void)customizeTableViewCellRendering
{
    [super customizeTableViewCellRendering];
    
    self.roomTitle.textColor = ThemeService.shared.theme.textPrimaryColor;
    self.roomTitle.highlightedTextColor = ThemeService.shared.theme.textSecondaryColor;
    self.lastEventDescription.textColor = ThemeService.shared.theme.textSecondaryColor;
    self.lastEventDescription.highlightedTextColor = ThemeService.shared.theme.textSecondaryColor;
    self.lastEventDate.textColor = ThemeService.shared.theme.textSecondaryColor;
    self.missedNotifAndUnreadBadgeLabel.textColor = ThemeService.shared.theme.baseTextPrimaryColor;
    
    // Prepare direct room border
    CGColorRef directRoomBorderColor = CGColorCreateCopyWithAlpha(ThemeService.shared.theme.tintColor.CGColor, kDirectRoomBorderColorAlpha);
    
    [self.directRoomBorderView.layer setCornerRadius:self.directRoomBorderView.frame.size.width / 2];
    self.directRoomBorderView.clipsToBounds = YES;
    self.directRoomBorderView.layer.borderColor = directRoomBorderColor;
    self.directRoomBorderView.layer.borderWidth = kDirectRoomBorderWidth;
    
    CFRelease(directRoomBorderColor);
    
    self.roomAvatar.defaultBackgroundColor = [UIColor clearColor];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    // Round image view
    [_roomAvatar.layer setCornerRadius:_roomAvatar.frame.size.width / 2];
    _roomAvatar.clipsToBounds = YES;
}

- (void)render:(MXKCellData *)cellData
{
    // Hide by default missed notifications
    self.missedNotifAndUnreadIndicator.hidden = YES;
    self.missedNotifAndUnreadBadgeBgView.hidden = YES;
    self.missedNotifAndUnreadBadgeBgViewWidthConstraint.constant = 0;
    
    roomCellData = (id<MXKRecentCellDataStoring>)cellData;
    if (roomCellData)
    {
        // Report computed values as is
        self.roomTitle.text = roomCellData.roomDisplayname;
        self.lastEventDate.text = roomCellData.lastEventDate;
        
        // Manage lastEventAttributedTextMessage optional property
        if ([roomCellData respondsToSelector:@selector(lastEventAttributedTextMessage)])
        {
            NSString *descriptionText = nil;
            if (roomCellData.lastEvent.isMediaAttachment)
            {
                
                NSString *msgtype = roomCellData.lastEvent.content[@"msgtype"];
                if ([msgtype isEqualToString:kMXMessageTypeAudio])
                {
                    NSDictionary *contentInfo = roomCellData.lastEvent.content[@"info"];
                    if (contentInfo && contentInfo[@"duration"])
                    {
                        double duration = [contentInfo[@"duration"] doubleValue] / 1000;
                        
                        NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
                        formatter.allowedUnits = NSCalendarUnitMinute | NSCalendarUnitSecond;
                        formatter.unitsStyle = NSDateComponentsFormatterUnitsStylePositional;
                        formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorPad;
                        
                        descriptionText = [NSString stringWithFormat:@"%@ - %@", NSLocalizedStringFromTable(@"audio", @"Vector", nil), [formatter stringFromTimeInterval:duration]];
                    }
                    else
                    {
                        descriptionText = NSLocalizedStringFromTable(@"audio", @"Vector", nil);
                    }
                }
                else if ([msgtype isEqualToString:kMXMessageTypeVideo])
                {
                    NSDictionary *contentInfo = roomCellData.lastEvent.content[@"info"];
                    if (contentInfo && contentInfo[@"duration"])
                    {
                        double duration = [contentInfo[@"duration"] doubleValue] / 1000;
                        
                        NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
                        formatter.allowedUnits = NSCalendarUnitMinute | NSCalendarUnitSecond;
                        formatter.unitsStyle = NSDateComponentsFormatterUnitsStylePositional;
                        formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorPad;
                        
                        descriptionText = [NSString stringWithFormat:@"%@ - %@", NSLocalizedStringFromTable(@"video", @"Vector", nil), [formatter stringFromTimeInterval:duration]];
                    }
                    else
                    {
                        descriptionText = NSLocalizedStringFromTable(@"video", @"Vector", nil);
                    }
                }
                else if ([msgtype isEqualToString:kMXMessageTypeImage])
                {
                    descriptionText = NSLocalizedStringFromTable(@"image", @"Vector", nil);
                }
                else if ([msgtype isEqualToString:kMXMessageTypeFile])
                {
                    descriptionText = NSLocalizedStringFromTable(@"file", @"Vector", nil);
                }
            }
            
            // Replace filename with more abstract description
            NSMutableAttributedString *lastEventDescription = [[NSMutableAttributedString alloc] initWithAttributedString:roomCellData.lastEventAttributedTextMessage];
            if (descriptionText)
            {
                if (roomCellData.lastEventTextMessage)
                {
                    NSRange range = [lastEventDescription.string rangeOfString:roomCellData.lastEventTextMessage];
                    [lastEventDescription replaceCharactersInRange:range withString:descriptionText];
                }
                else
                {
                    [lastEventDescription appendAttributedString:[[NSMutableAttributedString alloc] initWithString:descriptionText]];
                }
            }
            
            // Force the default text color for the last message (cancel highlighted message color)
            [lastEventDescription addAttribute:NSForegroundColorAttributeName value:ThemeService.shared.theme.textSecondaryColor range:NSMakeRange(0, lastEventDescription.length)];
            self.lastEventDescription.attributedText = lastEventDescription;
        }
        else
        {
            self.lastEventDescription.text = roomCellData.lastEventTextMessage;
        }
        
        // Notify unreads and bing
        if (roomCellData.hasUnread)
        {
            self.missedNotifAndUnreadIndicator.hidden = NO;
            
            if (0 < roomCellData.notificationCount)
            {
                self.missedNotifAndUnreadIndicator.backgroundColor = roomCellData.highlightCount ? ThemeService.shared.theme.noticeColor : ThemeService.shared.theme.noticeSecondaryColor;
                
                self.missedNotifAndUnreadBadgeBgView.hidden = NO;
                self.missedNotifAndUnreadBadgeBgView.backgroundColor = self.missedNotifAndUnreadIndicator.backgroundColor;
                
                self.missedNotifAndUnreadBadgeLabel.text = roomCellData.notificationCountStringValue;
                [self.missedNotifAndUnreadBadgeLabel sizeToFit];
                
                self.missedNotifAndUnreadBadgeBgViewWidthConstraint.constant = self.missedNotifAndUnreadBadgeLabel.frame.size.width + 18;
            }
            else
            {
                self.missedNotifAndUnreadIndicator.backgroundColor = ThemeService.shared.theme.unreadRoomIndentColor;
            }
            
            // Use bold font for the room title
            if ([UIFont respondsToSelector:@selector(systemFontOfSize:weight:)])
            {
                self.roomTitle.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
            }
            else
            {
                self.roomTitle.font = [UIFont boldSystemFontOfSize:17];
            }
        }
        else
        {
            self.lastEventDate.textColor = ThemeService.shared.theme.textSecondaryColor;
            
            // The room title is not bold anymore
            if ([UIFont respondsToSelector:@selector(systemFontOfSize:weight:)])
            {
                self.roomTitle.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
            }
            else
            {
                self.roomTitle.font = [UIFont systemFontOfSize:17];
            }
        }
        
        self.directRoomBorderView.hidden = !roomCellData.roomSummary.room.isDirect;

        self.encryptedRoomIcon.hidden = !roomCellData.roomSummary.isEncrypted;

        [roomCellData.roomSummary setRoomAvatarImageIn:self.roomAvatar];
    }
    else
    {
        self.lastEventDescription.text = @"";
    }
}

+ (CGFloat)heightForCellData:(MXKCellData *)cellData withMaximumWidth:(CGFloat)maxWidth
{
    // The height is fixed
    return 74;
}

@end
