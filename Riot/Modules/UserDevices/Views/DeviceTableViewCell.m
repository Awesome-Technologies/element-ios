/*
 Copyright 2016 OpenMarket Ltd
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

#import "DeviceTableViewCell.h"

#import "RiotDesignValues.h"
#import "MXRoom+Riot.h"

#define DEVICE_TABLEVIEW_ROW_CELL_HEIGHT_WITHOUT_LABEL_HEIGHT 33

@implementation DeviceTableViewCell

#pragma mark - Class methods

- (void)customizeTableViewCellRendering
{
    [super customizeTableViewCellRendering];
    
    self.deviceName.textColor = kCaritasPrimaryTextColor;
}

- (void)render:(MXDeviceInfo *)deviceInfo
{
    _deviceInfo = deviceInfo;
    
    self.deviceName.numberOfLines = 0;
    self.deviceName.text = (deviceInfo.displayName.length ? [NSString stringWithFormat:@"%@ (%@)", deviceInfo.displayName, deviceInfo.deviceId] : [NSString stringWithFormat:@"(%@)", deviceInfo.deviceId]);
}

+ (CGFloat)cellHeightWithDeviceInfo:(MXDeviceInfo*)deviceInfo andCellWidth:(CGFloat)width
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, width, 24)];
    label.numberOfLines = 0;
    label.text = (deviceInfo.displayName.length ? [NSString stringWithFormat:@"%@ (%@)", deviceInfo.displayName, deviceInfo.deviceId] : [NSString stringWithFormat:@"(%@)", deviceInfo.deviceId]);
    [label sizeToFit];
    
    return label.frame.size.height + DEVICE_TABLEVIEW_ROW_CELL_HEIGHT_WITHOUT_LABEL_HEIGHT;
}

@end
