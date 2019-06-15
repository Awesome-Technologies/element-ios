/*
 Copyright 2016 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 Copyright 2018 New Vector Ltd

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

#import "FilesSearchTableViewCell.h"

#import "ThemeService.h"
#import "Riot-Swift.h"

@implementation FilesSearchTableViewCell
@synthesize delegate, mxkCellData;

- (void)customizeTableViewCellRendering
{
    [super customizeTableViewCellRendering];
    
    self.title.textColor = ThemeService.shared.theme.textPrimaryColor;
    
    self.message.textColor = ThemeService.shared.theme.textSecondaryColor;
    
    self.date.tintColor = ThemeService.shared.theme.textSecondaryColor;
}

+ (CGFloat)heightForCellData:(MXKCellData *)cellData withMaximumWidth:(CGFloat)maxWidth
{
    // The height is fixed
    return 74;
}

- (void)render:(MXKCellData*)cellData
{    
    self.attachmentImageView.contentMode = UIViewContentModeScaleAspectFill;
    
    if ([cellData conformsToProtocol:@protocol(MXKSearchCellDataStoring)])
    {
        [super render:cellData];
    }
    else if ([cellData isKindOfClass:[MXKRoomBubbleCellData class]])
    {
        MXKRoomBubbleCellData *bubbleData = (MXKRoomBubbleCellData*)cellData;
        mxkCellData = cellData;
        
        if (bubbleData.attachment)
        {
            self.title.text = [self titleForAttachment:bubbleData.attachment];
            
            // In case of attachment, the bubble data is composed by only one component.
            if (bubbleData.bubbleComponents.count)
            {
                MXKRoomBubbleComponent *component = bubbleData.bubbleComponents.firstObject;
                self.date.text = [bubbleData.eventFormatter dateStringFromEvent:component.event withTime:NO];
            }
            else
            {
                self.date.text = nil;
            }
            
            self.message.text = bubbleData.senderDisplayName;
            
            self.attachmentImageView.image = nil;
            self.attachmentImageView.backgroundColor = [UIColor clearColor];
            
            if (bubbleData.isAttachmentWithThumbnail)
            {
                self.attachmentImageView.backgroundColor = ThemeService.shared.theme.backgroundColor;
                [self.attachmentImageView setAttachmentThumb:bubbleData.attachment];
            }
            
            self.iconImage.image = [self attachmentIcon:bubbleData.attachment.type];
            
            // Disable any interactions defined in the cell
            // because we want [tableView didSelectRowAtIndexPath:] to be called
            self.contentView.userInteractionEnabled = NO;
        }
        else
        {
            self.title.text = nil;
            self.date.text = nil;
            self.message.text = @"";
            
            self.attachmentImageView.image = nil;
            self.iconImage.image = nil;
        }
    }
}

- (NSString *)titleForAttachment:(MXKAttachment *)attachment {
    MXKAttachmentType attachmentType = attachment.type;
    
    if (attachmentType == MXKAttachmentTypeAudio)
    {
        if (attachment.contentInfo && attachment.contentInfo[@"duration"])
        {
            double duration = [attachment.contentInfo[@"duration"] doubleValue] / 1000;
            
            NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
            formatter.allowedUnits = NSCalendarUnitMinute | NSCalendarUnitSecond;
            formatter.unitsStyle = NSDateComponentsFormatterUnitsStylePositional;
            formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorPad;
            
            return [NSString stringWithFormat:@"%@ - %@", NSLocalizedStringFromTable(@"audio", @"Vector", nil), [formatter stringFromTimeInterval:duration]];
        }
        else
        {
            return NSLocalizedStringFromTable(@"audio", @"Vector", nil);
        }
    }
    else if (attachmentType == MXKAttachmentTypeVideo)
    {
        if (attachment.contentInfo && attachment.contentInfo[@"duration"])
        {
            double duration = [attachment.contentInfo[@"duration"] doubleValue] / 1000;
            
            NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
            formatter.allowedUnits = NSCalendarUnitMinute | NSCalendarUnitSecond;
            formatter.unitsStyle = NSDateComponentsFormatterUnitsStylePositional;
            formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorPad;
            
            return [NSString stringWithFormat:@"%@ - %@", NSLocalizedStringFromTable(@"video", @"Vector", nil), [formatter stringFromTimeInterval:duration]];
        }
        else
        {
            return NSLocalizedStringFromTable(@"video", @"Vector", nil);
        }
    }
    else if (attachmentType == MXKAttachmentTypeImage)
    {
        return NSLocalizedStringFromTable(@"image", @"Vector", nil);
    }
    else if (attachmentType == MXKAttachmentTypeFile)
    {
        return NSLocalizedStringFromTable(@"file", @"Vector", nil);
    }
    
    return attachment.originalFileName;
}

#pragma mark -

- (UIImage*)attachmentIcon: (MXKAttachmentType)type
{
    UIImage *image = nil;
    
    switch (type)
    {
        case MXKAttachmentTypeImage:
            image = [UIImage imageNamed:@"file_photo_icon"];
            break;
        case MXKAttachmentTypeAudio:
            image = [UIImage imageNamed:@"file_music_icon"];
            break;
        case MXKAttachmentTypeVideo:
            image = [UIImage imageNamed:@"file_video_icon"];
            break;
        case MXKAttachmentTypeFile:
            image = [UIImage imageNamed:@"file_doc_icon"];
            break;
        default:
            break;
    }
    
    return image;
}


@end
