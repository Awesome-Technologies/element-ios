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

#import "RoomSettingsViewController.h"

#import "TableViewCellWithLabelAndLargeTextView.h"
#import "TableViewCellWithCheckBoxAndLabel.h"

#import "SegmentedViewController.h"

#import "AvatarGenerator.h"
#import "Tools.h"

#import "MXRoom+Riot.h"
#import "MXRoomSummary+Riot.h"

#import "AppDelegate.h"
#import "Riot-Swift.h"

#import "RoomMemberDetailsViewController.h"

#import <MobileCoreServices/MobileCoreServices.h>

enum
{
    ROOM_SETTINGS_MAIN_SECTION_INDEX = 0,
    ROOM_SETTINGS_ROOM_ACCESS_SECTION_INDEX,
    ROOM_SETTINGS_HISTORY_VISIBILITY_SECTION_INDEX,
    ROOM_SETTINGS_SECTION_COUNT
};

enum
{
    ROOM_SETTINGS_MAIN_SECTION_ROW_PHOTO = 0,
    ROOM_SETTINGS_MAIN_SECTION_ROW_NAME,
    ROOM_SETTINGS_MAIN_SECTION_ROW_TOPIC,
    ROOM_SETTINGS_MAIN_SECTION_ROW_MUTE_NOTIFICATIONS,
    ROOM_SETTINGS_MAIN_SECTION_ROW_LEAVE,
    ROOM_SETTINGS_MAIN_SECTION_ROW_COUNT
};

enum
{
    ROOM_SETTINGS_ROOM_ACCESS_SECTION_ROW_INVITED_ONLY = 0,
    ROOM_SETTINGS_ROOM_ACCESS_SECTION_ROW_ANYONE_APART_FROM_GUEST,
    ROOM_SETTINGS_ROOM_ACCESS_SECTION_ROW_ANYONE,
    ROOM_SETTINGS_ROOM_ACCESS_SECTION_ROW_SUB_COUNT
};

enum
{
    ROOM_SETTINGS_HISTORY_VISIBILITY_SECTION_ROW_ANYONE = 0,
    ROOM_SETTINGS_HISTORY_VISIBILITY_SECTION_ROW_MEMBERS_ONLY,
    ROOM_SETTINGS_HISTORY_VISIBILITY_SECTION_ROW_MEMBERS_ONLY_SINCE_INVITED,
    ROOM_SETTINGS_HISTORY_VISIBILITY_SECTION_ROW_MEMBERS_ONLY_SINCE_JOINED,
    ROOM_SETTINGS_HISTORY_VISIBILITY_SECTION_ROW_COUNT
};

#define ROOM_TOPIC_CELL_HEIGHT 124

#define SECTION_TITLE_PADDING_WHEN_HIDDEN 0.01f

NSString *const kRoomSettingsAvatarKey = @"kRoomSettingsAvatarKey";
NSString *const kRoomSettingsAvatarURLKey = @"kRoomSettingsAvatarURLKey";
NSString *const kRoomSettingsNameKey = @"kRoomSettingsNameKey";
NSString *const kRoomSettingsTopicKey = @"kRoomSettingsTopicKey";
NSString *const kRoomSettingsTagKey = @"kRoomSettingsTagKey";
NSString *const kRoomSettingsMuteNotifKey = @"kRoomSettingsMuteNotifKey";
NSString *const kRoomSettingsJoinRuleKey = @"kRoomSettingsJoinRuleKey";
NSString *const kRoomSettingsGuestAccessKey = @"kRoomSettingsGuestAccessKey";
NSString *const kRoomSettingsDirectoryKey = @"kRoomSettingsDirectoryKey";
NSString *const kRoomSettingsHistoryVisibilityKey = @"kRoomSettingsHistoryVisibilityKey";
NSString *const kRoomSettingsNewAliasesKey = @"kRoomSettingsNewAliasesKey";
NSString *const kRoomSettingsRemovedAliasesKey = @"kRoomSettingsRemovedAliasesKey";
NSString *const kRoomSettingsCanonicalAliasKey = @"kRoomSettingsCanonicalAliasKey";

NSString *const kRoomSettingsNameCellViewIdentifier = @"kRoomSettingsNameCellViewIdentifier";
NSString *const kRoomSettingsTopicCellViewIdentifier = @"kRoomSettingsTopicCellViewIdentifier";

@interface RoomSettingsViewController () <SingleImagePickerPresenterDelegate>
{
    // The updated user data
    NSMutableDictionary<NSString*, id> *updatedItemsDict;
    
    // The current table items
    UITextField* nameTextField;
    UITextView* topicTextView;
    
    // Room Access items
    TableViewCellWithCheckBoxAndLabel *accessInvitedOnlyTickCell;
    TableViewCellWithCheckBoxAndLabel *accessAnyoneApartGuestTickCell;
    TableViewCellWithCheckBoxAndLabel *accessAnyoneTickCell;
    
    // History Visibility items
    NSMutableDictionary<MXRoomHistoryVisibility, TableViewCellWithCheckBoxAndLabel*> *historyVisibilityTickCells;
    
    // Oder of setting in main section
    NSMutableArray *mainSectionSettingsOrder;
    
    // The potential image loader
    MXMediaLoader *uploader;
    
    // The pending http operation
    MXHTTPOperation* pendingOperation;
    
    // the updating spinner
    UIActivityIndicatorView* updatingSpinner;
    
    UIAlertController *currentAlert;
    
    // listen to more events than the mother class
    id extraEventsListener;
    
    // Observe kAppDelegateDidTapStatusBarNotification to handle tap on clock status bar.
    id appDelegateDidTapStatusBarNotificationObserver;
    
    // Observe kThemeServiceDidChangeThemeNotification to handle user interface theme change.
    id kThemeServiceDidChangeThemeNotificationObserver;
}

@property (nonatomic, strong) SingleImagePickerPresenter *imagePickerPresenter;

@end

@implementation RoomSettingsViewController

- (void)finalizeInit
{
    [super finalizeInit];
    
    _selectedRoomSettingsField = RoomSettingsViewControllerFieldNone;
    
    // Setup `MXKViewControllerHandling` properties
    self.enableBarTintColorStatusChange = NO;
    self.rageShakeManager = [RageShakeManager sharedManager];
}

- (void)initWithSession:(MXSession *)session andRoomId:(NSString *)roomId
{
    [super initWithSession:session andRoomId:roomId];
    
    // Add an additional listener to update banned users
    self->extraEventsListener = [mxRoom listenToEventsOfTypes:@[kMXEventTypeStringRoomMember] onEvent:^(MXEvent *event, MXTimelineDirection direction, MXRoomState *roomState) {

        if (direction == MXTimelineDirectionForwards)
        {
            [self updateRoomState:roomState];
        }
    }];
}

- (void)updateRoomState:(MXRoomState *)newRoomState
{
    [super updateRoomState:newRoomState];
}

- (UINavigationItem*)getNavigationItem
{
    // Check whether the view controller is currently displayed inside a segmented view controller or not.
    UIViewController* topViewController = ((self.parentViewController) ? self.parentViewController : self);
    
    return topViewController.navigationItem;
}

- (void)setNavBarButtons
{
    [self getNavigationItem].rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(onSave:)];
    [self getNavigationItem].rightBarButtonItem.enabled = (updatedItemsDict.count != 0);
    [self getNavigationItem].leftBarButtonItem  = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(onCancel:)];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    updatedItemsDict = [[NSMutableDictionary alloc] init];
    historyVisibilityTickCells = [[NSMutableDictionary alloc] initWithCapacity:4];
    
    [self.tableView registerClass:MXKTableViewCellWithLabelAndSwitch.class forCellReuseIdentifier:[MXKTableViewCellWithLabelAndSwitch defaultReuseIdentifier]];
    [self.tableView registerClass:MXKTableViewCellWithLabelAndMXKImageView.class forCellReuseIdentifier:[MXKTableViewCellWithLabelAndMXKImageView defaultReuseIdentifier]];
    
    // Use a specific cell identifier for the room name, the topic and the address in order to be able to keep reference
    // on the text input field without being disturbed by the cell dequeuing process.
    [self.tableView registerClass:MXKTableViewCellWithLabelAndTextField.class forCellReuseIdentifier:kRoomSettingsNameCellViewIdentifier];
    [self.tableView registerClass:TableViewCellWithLabelAndLargeTextView.class forCellReuseIdentifier:kRoomSettingsTopicCellViewIdentifier];
    
    [self.tableView registerClass:MXKTableViewCellWithButton.class forCellReuseIdentifier:[MXKTableViewCellWithButton defaultReuseIdentifier]];
    [self.tableView registerClass:TableViewCellWithCheckBoxes.class forCellReuseIdentifier:[TableViewCellWithCheckBoxes defaultReuseIdentifier]];
    [self.tableView registerClass:TableViewCellWithCheckBoxAndLabel.class forCellReuseIdentifier:[TableViewCellWithCheckBoxAndLabel defaultReuseIdentifier]];
    [self.tableView registerClass:MXKTableViewCell.class forCellReuseIdentifier:[MXKTableViewCell defaultReuseIdentifier]];
    
    // Enable self sizing cells
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 44;
    
    [self setNavBarButtons];
    
    // Observe user interface theme change.
    kThemeServiceDidChangeThemeNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kThemeServiceDidChangeThemeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        [self userInterfaceThemeDidChange];
        
    }];
    [self userInterfaceThemeDidChange];
}

- (void)userInterfaceThemeDidChange
{
    [ThemeService.shared.theme applyStyleOnNavigationBar:self.navigationController.navigationBar];

    self.activityIndicator.backgroundColor = ThemeService.shared.theme.overlayBackgroundColor;
    
    // Check the table view style to select its bg color.
    self.tableView.backgroundColor = ThemeService.shared.theme.backgroundColor;
    self.view.backgroundColor = self.tableView.backgroundColor;
    self.tableView.separatorColor = ThemeService.shared.theme.lineBreakColor;
    
    if (self.tableView.dataSource)
    {
        [self.tableView reloadData];
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return ThemeService.shared.theme.statusBarStyle;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // Screen tracking
    [[Analytics sharedInstance] trackScreen:@"RoomSettings"];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didUpdateRules:) name:kMXNotificationCenterDidUpdateRules object:nil];
    
    // Observe appDelegateDidTapStatusBarNotificationObserver.
    appDelegateDidTapStatusBarNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kAppDelegateDidTapStatusBarNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        [self.tableView setContentOffset:CGPointMake(-self.tableView.mxk_adjustedContentInset.left, -self.tableView.mxk_adjustedContentInset.top) animated:YES];
        
    }];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Edit the selected field if any
    if (_selectedRoomSettingsField != RoomSettingsViewControllerFieldNone)
    {
        self.selectedRoomSettingsField = _selectedRoomSettingsField;
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self dismissFirstResponder];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXNotificationCenterDidUpdateRules object:nil];
    
    if (appDelegateDidTapStatusBarNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:appDelegateDidTapStatusBarNotificationObserver];
        appDelegateDidTapStatusBarNotificationObserver = nil;
    }
}

// Those methods are called when the viewcontroller is added or removed from a container view controller.
- (void)willMoveToParentViewController:(nullable UIViewController *)parent
{
    // Check whether the view is removed from its parent.
    if (!parent)
    {
        [self dismissFirstResponder];
        
        // Prompt user to save changes (if any).
        if (updatedItemsDict.count)
        {
            [self promptUserToSaveChanges];
        }
    }
    
    [super willMoveToParentViewController:parent];
}
- (void)didMoveToParentViewController:(nullable UIViewController *)parent
{
    [super didMoveToParentViewController:parent];
    
    [self setNavBarButtons];
}

- (void)destroy
{
    self.navigationItem.rightBarButtonItem.enabled = NO;
    
    if (currentAlert)
    {
        [currentAlert dismissViewControllerAnimated:NO completion:nil];
        currentAlert = nil;
    }
    
    if (uploader)
    {
        [uploader cancel];
        uploader = nil;
    }
    
    if (pendingOperation)
    {
        [pendingOperation cancel];
        pendingOperation = nil;
    }
    
    if (kThemeServiceDidChangeThemeNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:kThemeServiceDidChangeThemeNotificationObserver];
        kThemeServiceDidChangeThemeNotificationObserver = nil;
    }
    
    if (appDelegateDidTapStatusBarNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:appDelegateDidTapStatusBarNotificationObserver];
        appDelegateDidTapStatusBarNotificationObserver = nil;
    }
    
    updatedItemsDict = nil;
    historyVisibilityTickCells = nil;
    
    if (extraEventsListener)
    {
        MXWeakify(self);
        [mxRoom liveTimeline:^(MXEventTimeline *liveTimeline) {
            MXStrongifyAndReturnIfNil(self);

            [liveTimeline removeListener:self->extraEventsListener];
            self->extraEventsListener = nil;
        }];
    }
    
    [super destroy];
}

- (void)withdrawViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion
{
    // Check whether the current view controller is displayed inside a segmented view controller in order to withdraw the right item
    if (self.parentViewController && [self.parentViewController isKindOfClass:SegmentedViewController.class])
    {
        [((SegmentedViewController*)self.parentViewController) withdrawViewControllerAnimated:animated completion:completion];
    }
    else
    {
        [super withdrawViewControllerAnimated:animated completion:completion];
    }
}

- (void)refreshRoomSettings
{
    mainSectionSettingsOrder = [NSMutableArray array];
    if (mxRoom.isDirect)
    {
        [mainSectionSettingsOrder addObject:@(ROOM_SETTINGS_MAIN_SECTION_ROW_MUTE_NOTIFICATIONS)];
    }
    else
    {
        [mainSectionSettingsOrder addObject:@(ROOM_SETTINGS_MAIN_SECTION_ROW_PHOTO)];
        [mainSectionSettingsOrder addObject:@(ROOM_SETTINGS_MAIN_SECTION_ROW_NAME)];
        [mainSectionSettingsOrder addObject:@(ROOM_SETTINGS_MAIN_SECTION_ROW_TOPIC)];
        [mainSectionSettingsOrder addObject:@(ROOM_SETTINGS_MAIN_SECTION_ROW_MUTE_NOTIFICATIONS)];
        [mainSectionSettingsOrder addObject:@(ROOM_SETTINGS_MAIN_SECTION_ROW_LEAVE)];
    }
    
    // Check whether a text input is currently edited
    BOOL isNameEdited = nameTextField ? nameTextField.isFirstResponder : NO;
    BOOL isTopicEdited = topicTextView ? topicTextView.isFirstResponder : NO;
    
    // Trigger a full table reloadData
    [super refreshRoomSettings];
    
    // Restore the previous edited field
    if (isNameEdited)
    {
        [self editRoomName];
    }
    else if (isTopicEdited)
    {
        [self editRoomTopic];
    }
}

#pragma mark -

- (void)setSelectedRoomSettingsField:(RoomSettingsViewControllerField)selectedRoomSettingsField
{
    // Check whether the view controller is already embedded inside a navigation controller
    if (self.navigationController)
    {
        [self dismissFirstResponder];
        
        // Check whether user allowed to change room info
        NSDictionary *eventTypes = @{
                                     @(RoomSettingsViewControllerFieldName): kMXEventTypeStringRoomName,
                                     @(RoomSettingsViewControllerFieldTopic): kMXEventTypeStringRoomTopic,
                                     @(RoomSettingsViewControllerFieldAvatar): kMXEventTypeStringRoomAvatar
                                     };
        
        NSString *eventTypeForSelectedField = eventTypes[@(selectedRoomSettingsField)];
        
        if (!eventTypeForSelectedField)
            return;
        
        MXRoomPowerLevels *powerLevels = [mxRoomState powerLevels];
        NSInteger oneSelfPowerLevel = [powerLevels powerLevelOfUserWithUserID:self.mainSession.myUser.userId];
        
        if (oneSelfPowerLevel < [powerLevels minimumPowerLevelForSendingEventAsStateEvent:eventTypeForSelectedField])
            return;
        
        switch (selectedRoomSettingsField)
        {
            case RoomSettingsViewControllerFieldName:
            {
                [self editRoomName];
                break;
            }
            case RoomSettingsViewControllerFieldTopic:
            {
                [self editRoomTopic];
                break;
            }
            case RoomSettingsViewControllerFieldAvatar:
            {
                [self onRoomAvatarTap:nil];
                break;
            }
                
            default:
                break;
        }
    }
    else
    {
        // This selection will be applied when the view controller will become active (see 'viewDidAppear')
        _selectedRoomSettingsField = selectedRoomSettingsField;
    }
}

#pragma mark - private

- (void)editRoomName
{
    if (![nameTextField becomeFirstResponder])
    {
        // Retry asynchronously
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self editRoomName];
            
        });
    }
}

- (void)editRoomTopic
{
    if (![topicTextView becomeFirstResponder])
    {
        // Retry asynchronously
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self editRoomTopic];
            
        });
    }
}

- (void)dismissFirstResponder
{
    if ([topicTextView isFirstResponder])
    {
        [topicTextView resignFirstResponder];
    }
    
    if ([nameTextField isFirstResponder])
    {
        [nameTextField resignFirstResponder];
    }
    
    _selectedRoomSettingsField = RoomSettingsViewControllerFieldNone;
}

- (void)startActivityIndicator
{
    // Lock user interaction
    self.tableView.userInteractionEnabled = NO;
    
    // Check whether the current view controller is displayed inside a segmented view controller in order to run the right activity view
    if (self.parentViewController && [self.parentViewController isKindOfClass:SegmentedViewController.class])
    {
        [((SegmentedViewController*)self.parentViewController) startActivityIndicator];
        
        // Force stop the activity view of the view controller
        [self.activityIndicator stopAnimating];
    }
    else
    {
        [super startActivityIndicator];
    }
}

- (void)stopActivityIndicator
{
    // Check local conditions before stop the activity indicator
    if (!pendingOperation && !uploader)
    {
        // Unlock user interaction
        self.tableView.userInteractionEnabled = YES;
        
        // Check whether the current view controller is displayed inside a segmented view controller in order to stop the right activity view
        if (self.parentViewController && [self.parentViewController isKindOfClass:SegmentedViewController.class])
        {
            [((SegmentedViewController*)self.parentViewController) stopActivityIndicator];
            
            // Force stop the activity view of the view controller
            [self.activityIndicator stopAnimating];
        }
        else
        {
            [super stopActivityIndicator];
        }
    }
}

- (void)promptUserToSaveChanges
{
    // ensure that the user understands that the updates will be lost if
    [currentAlert dismissViewControllerAnimated:NO completion:nil];
    
    __weak typeof(self) weakSelf = self;
    
    currentAlert = [UIAlertController alertControllerWithTitle:nil message:NSLocalizedStringFromTable(@"room_details_save_changes_prompt", @"Vector", nil) preferredStyle:UIAlertControllerStyleAlert];
    
    [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"no"]
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * action) {
                                                       
                                                       if (weakSelf)
                                                       {
                                                           typeof(self) self = weakSelf;
                                                           self->currentAlert = nil;
                                                           
                                                           [self->updatedItemsDict removeAllObjects];
                                                           
                                                           [self withdrawViewControllerAnimated:YES completion:nil];
                                                       }
                                                       
                                                   }]];
    
    [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"yes"]
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * action) {
                                                       
                                                       if (weakSelf)
                                                       {
                                                           typeof(self) self = weakSelf;
                                                           self->currentAlert = nil;
                                                           
                                                           [self onSave:nil];
                                                       }
                                                       
                                                   }]];
    
    [currentAlert mxk_setAccessibilityIdentifier:@"RoomSettingsVCSaveChangesAlert"];
    [self presentViewController:currentAlert animated:YES completion:nil];
}

#pragma mark - UITextViewDelegate

- (void)textViewDidBeginEditing:(UITextView *)textView;
{
    if (topicTextView == textView)
    {
        UIView *contentView = topicTextView.superview;
        if (contentView)
        {
            // refresh cell's layout
            [contentView.superview setNeedsLayout];
        }
    }
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    if (topicTextView == textView)
    {
        UIView *contentView = topicTextView.superview;
        if (contentView)
        {
            // refresh cell's layout
            [contentView.superview setNeedsLayout];
        }
    }
}

- (void)textViewDidChange:(UITextView *)textView
{
    if (topicTextView == textView)
    {
        NSString* currentTopic = mxRoomState.topic;
        
        // Remove white space from both ends
        NSString* topic = [textView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        // Check whether the topic has been actually changed
        if ((topic || currentTopic) && ([topic isEqualToString:currentTopic] == NO))
        {
            updatedItemsDict[kRoomSettingsTopicKey] = topic ? topic : @"";
        }
        else
        {
            [updatedItemsDict removeObjectForKey:kRoomSettingsTopicKey];
        }
        
        [self getNavigationItem].rightBarButtonItem.enabled = (updatedItemsDict.count != 0);
    }
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    if (textField == nameTextField)
    {
        nameTextField.textAlignment = NSTextAlignmentLeft;
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (textField == nameTextField)
    {
        nameTextField.textAlignment = NSTextAlignmentRight;
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == nameTextField)
    {
        // Dismiss the keyboard
        [nameTextField resignFirstResponder];
    }
    
    return YES;
}

#pragma mark - actions

- (IBAction)onTextFieldUpdate:(UITextField*)textField
{
    if (textField == nameTextField)
    {
        NSString *currentName = mxRoomState.name;
        
        // Remove white space from both ends
        NSString *displayName = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        // Check whether the name has been actually changed
        if ((displayName || currentName) && ([displayName isEqualToString:currentName] == NO))
        {
            updatedItemsDict[kRoomSettingsNameKey] = displayName ? displayName : @"";
        }
        else
        {
            [updatedItemsDict removeObjectForKey:kRoomSettingsNameKey];
        }
        
        [self getNavigationItem].rightBarButtonItem.enabled = (updatedItemsDict.count != 0);
    }
}

- (void)didUpdateRules:(NSNotification *)notif
{
    [self refreshRoomSettings];
}

- (IBAction)onCancel:(id)sender
{
    [self dismissFirstResponder];
    
    // Check whether some changes have been done
    if (updatedItemsDict.count)
    {
        [self promptUserToSaveChanges];
    }
    else
    {
        [self withdrawViewControllerAnimated:YES completion:nil];
    }
}

- (void)onSaveFailed:(NSString*)message withKeys:(NSArray<NSString *>*)keys
{
    __weak typeof(self) weakSelf = self;
    
    [currentAlert dismissViewControllerAnimated:NO completion:nil];
    
    currentAlert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    
    [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"]
                                                     style:UIAlertActionStyleCancel
                                                   handler:^(UIAlertAction * action) {
                                                       
                                                       if (weakSelf)
                                                       {
                                                           typeof(self) self = weakSelf;
                                                           self->currentAlert = nil;
                                                           
                                                           // Discard related change
                                                           for (NSString *key in keys)
                                                           {
                                                               [self->updatedItemsDict removeObjectForKey:key];
                                                           }
                                                           
                                                           // Save anything else
                                                           [self onSave:nil];
                                                       }
                                                       
                                                   }]];
    
    [currentAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"retry", @"Vector", nil)
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * action) {
                                                       
                                                       if (weakSelf)
                                                       {
                                                           typeof(self) self = weakSelf;
                                                           self->currentAlert = nil;
                                                           
                                                           [self onSave:nil];
                                                       }
                                                       
                                                   }]];
    
    [currentAlert mxk_setAccessibilityIdentifier:@"RoomSettingsVCSaveChangesFailedAlert"];
    [self presentViewController:currentAlert animated:YES completion:nil];
}

- (IBAction)onSave:(id)sender
{
    if (updatedItemsDict.count)
    {
        [self startActivityIndicator];
        
        __weak typeof(self) weakSelf = self;
        
        // check if there is some updates related to room state
        if (mxRoomState)
        {
            if (updatedItemsDict[kRoomSettingsAvatarKey])
            {
                // Retrieve the current picture and make sure its orientation is up
                UIImage *updatedPicture = [MXKTools forceImageOrientationUp:updatedItemsDict[kRoomSettingsAvatarKey]];
                
                // Upload picture
                uploader = [MXMediaManager prepareUploaderWithMatrixSession:mxRoom.mxSession initialRange:0 andRange:1.0];
                
                [uploader uploadData:UIImageJPEGRepresentation(updatedPicture, 0.5) filename:nil mimeType:@"image/jpeg" success:^(NSString *url) {
                    
                    if (weakSelf)
                    {
                        typeof(self) self = weakSelf;
                        
                        self->uploader = nil;
                        
                        [self->updatedItemsDict removeObjectForKey:kRoomSettingsAvatarKey];
                        self->updatedItemsDict[kRoomSettingsAvatarURLKey] = url;
                        
                        [self onSave:nil];
                    }
                    
                } failure:^(NSError *error) {
                    
                    NSLog(@"[RoomSettingsViewController] Image upload failed");
                    
                    if (weakSelf)
                    {
                        typeof(self) self = weakSelf;
                        
                        self->uploader = nil;
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            
                            NSString* message = error.localizedDescription;
                            if (!message.length)
                            {
                                message = NSLocalizedStringFromTable(@"room_details_fail_to_update_avatar", @"Vector", nil);
                            }
                            [self onSaveFailed:message withKeys:@[kRoomSettingsAvatarKey]];
                            
                        });
                    }
                    
                }];
                
                return;
            }
            
            NSString* photoUrl = updatedItemsDict[kRoomSettingsAvatarURLKey];
            if (photoUrl)
            {
                pendingOperation = [mxRoom setAvatar:photoUrl success:^{
                    
                    if (weakSelf)
                    {
                        typeof(self) self = weakSelf;
                        
                        self->pendingOperation = nil;
                        [self->updatedItemsDict removeObjectForKey:kRoomSettingsAvatarURLKey];
                        [self onSave:nil];
                    }
                    
                } failure:^(NSError *error) {
                    
                    NSLog(@"[RoomSettingsViewController] Failed to update the room avatar");
                    
                    if (weakSelf)
                    {
                        typeof(self) self = weakSelf;
                        
                        self->pendingOperation = nil;
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            
                            NSString* message = error.localizedDescription;
                            if (!message.length)
                            {
                                message = NSLocalizedStringFromTable(@"room_details_fail_to_update_avatar", @"Vector", nil);
                            }
                            [self onSaveFailed:message withKeys:@[kRoomSettingsAvatarURLKey]];
                            
                        });
                    }
                    
                }];
                
                return;
            }
            
            // has a new room name
            NSString* roomName = updatedItemsDict[kRoomSettingsNameKey];
            if (roomName)
            {
                pendingOperation = [mxRoom setName:roomName success:^{
                    
                    if (weakSelf)
                    {
                        typeof(self) self = weakSelf;
                        
                        self->pendingOperation = nil;
                        [self->updatedItemsDict removeObjectForKey:kRoomSettingsNameKey];
                        [self onSave:nil];
                    }
                    
                } failure:^(NSError *error) {
                    
                    NSLog(@"[RoomSettingsViewController] Rename room failed");
                    
                    if (weakSelf)
                    {
                        typeof(self) self = weakSelf;
                        
                        self->pendingOperation = nil;
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            
                            NSString* message = error.localizedDescription;
                            if (!message.length)
                            {
                                message = NSLocalizedStringFromTable(@"room_details_fail_to_update_room_name", @"Vector", nil);
                            }
                            [self onSaveFailed:message withKeys:@[kRoomSettingsNameKey]];
                            
                        });
                    }
                    
                }];
                
                return;
            }
            
            // has a new room topic
            NSString* roomTopic = updatedItemsDict[kRoomSettingsTopicKey];
            if (roomTopic)
            {
                pendingOperation = [mxRoom setTopic:roomTopic success:^{
                    
                    if (weakSelf)
                    {
                        typeof(self) self = weakSelf;
                        
                        self->pendingOperation = nil;
                        [self->updatedItemsDict removeObjectForKey:kRoomSettingsTopicKey];
                        [self onSave:nil];
                    }
                    
                } failure:^(NSError *error) {
                    
                    NSLog(@"[RoomSettingsViewController] Rename topic failed");
                    
                    if (weakSelf)
                    {
                        typeof(self) self = weakSelf;
                        
                        self->pendingOperation = nil;
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            
                            NSString* message = error.localizedDescription;
                            if (!message.length)
                            {
                                message = NSLocalizedStringFromTable(@"room_details_fail_to_update_topic", @"Vector", nil);
                            }
                            [self onSaveFailed:message withKeys:@[kRoomSettingsTopicKey]];
                            
                        });
                    }
                    
                }];
                
                return;
            }
            
            // Room guest access
            MXRoomGuestAccess guestAccess = updatedItemsDict[kRoomSettingsGuestAccessKey];
            if (guestAccess)
            {
                pendingOperation = [mxRoom setGuestAccess:guestAccess success:^{
                    
                    if (weakSelf)
                    {
                        typeof(self) self = weakSelf;
                        
                        self->pendingOperation = nil;
                        [self->updatedItemsDict removeObjectForKey:kRoomSettingsGuestAccessKey];
                        [self onSave:nil];
                    }
                    
                } failure:^(NSError *error) {
                    
                    NSLog(@"[RoomSettingsViewController] Update guest access failed");
                    
                    if (weakSelf)
                    {
                        typeof(self) self = weakSelf;
                        
                        self->pendingOperation = nil;
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            
                            NSString* message = error.localizedDescription;
                            if (!message.length)
                            {
                                message = NSLocalizedStringFromTable(@"room_details_fail_to_update_room_guest_access", @"Vector", nil);
                            }
                            [self onSaveFailed:message withKeys:@[kRoomSettingsGuestAccessKey]];
                            
                        });
                    }
                    
                }];
                
                return;
            }
            
            // Room join rule
            MXRoomJoinRule joinRule = updatedItemsDict[kRoomSettingsJoinRuleKey];
            if (joinRule)
            {
                pendingOperation = [mxRoom setJoinRule:joinRule success:^{
                    
                    if (weakSelf)
                    {
                        typeof(self) self = weakSelf;
                        
                        self->pendingOperation = nil;
                        [self->updatedItemsDict removeObjectForKey:kRoomSettingsJoinRuleKey];
                        [self onSave:nil];
                    }
                    
                } failure:^(NSError *error) {
                    
                    NSLog(@"[RoomSettingsViewController] Update join rule failed");
                    
                    if (weakSelf)
                    {
                        typeof(self) self = weakSelf;
                        
                        self->pendingOperation = nil;
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            
                            NSString* message = error.localizedDescription;
                            if (!message.length)
                            {
                                message = NSLocalizedStringFromTable(@"room_details_fail_to_update_room_join_rule", @"Vector", nil);
                            }
                            [self onSaveFailed:message withKeys:@[kRoomSettingsJoinRuleKey]];
                            
                        });
                    }
                    
                }];
                
                return;
            }
            
            // History visibility
            MXRoomHistoryVisibility visibility = updatedItemsDict[kRoomSettingsHistoryVisibilityKey];
            if (visibility)
            {
                pendingOperation = [mxRoom setHistoryVisibility:visibility success:^{
                    
                    if (weakSelf)
                    {
                        typeof(self) self = weakSelf;
                        
                        self->pendingOperation = nil;
                        [self->updatedItemsDict removeObjectForKey:kRoomSettingsHistoryVisibilityKey];
                        [self onSave:nil];
                    }
                    
                } failure:^(NSError *error) {
                    
                    NSLog(@"[RoomSettingsViewController] Update history visibility failed");
                    
                    if (weakSelf)
                    {
                        typeof(self) self = weakSelf;
                        
                        self->pendingOperation = nil;
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            
                            NSString* message = error.localizedDescription;
                            if (!message.length)
                            {
                                message = NSLocalizedStringFromTable(@"room_details_fail_to_update_history_visibility", @"Vector", nil);
                            }
                            [self onSaveFailed:message withKeys:@[kRoomSettingsHistoryVisibilityKey]];
                            
                        });
                    }
                    
                }];
                
                return;
            }
        }
        
        // Update here other room settings
        NSString *roomTag = updatedItemsDict[kRoomSettingsTagKey];
        if (roomTag)
        {
            if (!roomTag.length)
            {
                roomTag = nil;
            }
            
            [mxRoom setRoomTag:roomTag completion:^{
                
                if (weakSelf)
                {
                    typeof(self) self = weakSelf;
                    
                    [self->updatedItemsDict removeObjectForKey:kRoomSettingsTagKey];
                    [self onSave:nil];
                }
                
            }];
            
            return;
        }
        
        if (updatedItemsDict[kRoomSettingsMuteNotifKey])
        {
            if (((NSNumber*) updatedItemsDict[kRoomSettingsMuteNotifKey]).boolValue)
            {
                [mxRoom mentionsOnly:^{
                    
                    if (weakSelf)
                    {
                        typeof(self) self = weakSelf;
                        
                        [self->updatedItemsDict removeObjectForKey:kRoomSettingsMuteNotifKey];
                        [self onSave:nil];
                    }
                    
                }];
            }
            else
            {
                [mxRoom allMessages:^{
                    
                    if (weakSelf)
                    {
                        typeof(self) self = weakSelf;
                        
                        [self->updatedItemsDict removeObjectForKey:kRoomSettingsMuteNotifKey];
                        [self onSave:nil];
                    }
                    
                }];
            }
            return;
        }
        
        // Room directory visibility
        MXRoomDirectoryVisibility directoryVisibility = updatedItemsDict[kRoomSettingsDirectoryKey];
        if (directoryVisibility)
        {
            [mxRoom setDirectoryVisibility:directoryVisibility success:^{
                
                if (weakSelf)
                {
                    typeof(self) self = weakSelf;
                    
                    [self->updatedItemsDict removeObjectForKey:kRoomSettingsDirectoryKey];
                    [self onSave:nil];
                }
                
            } failure:^(NSError *error) {
                
                NSLog(@"[RoomSettingsViewController] Update room directory visibility failed");
                
                if (weakSelf)
                {
                    typeof(self) self = weakSelf;
                    
                    self->pendingOperation = nil;
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        NSString* message = error.localizedDescription;
                        if (!message.length)
                        {
                            message = NSLocalizedStringFromTable(@"room_details_fail_to_update_room_directory_visibility", @"Vector", nil);
                        }
                        [self onSaveFailed:message withKeys:@[kRoomSettingsDirectoryKey]];
                        
                    });
                }
                
            }];
            
            return;
        }
    }
    
    [self getNavigationItem].rightBarButtonItem.enabled = NO;
    
    [self stopActivityIndicator];
    
    [self withdrawViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the fixed number of sections
    return mxRoom.isDirect ? 1 : ROOM_SETTINGS_SECTION_COUNT;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger count = 0;
    
    if (section == ROOM_SETTINGS_MAIN_SECTION_INDEX)
    {
        count = mainSectionSettingsOrder.count;
    }
    else if (section == ROOM_SETTINGS_ROOM_ACCESS_SECTION_INDEX)
    {
        count = ROOM_SETTINGS_ROOM_ACCESS_SECTION_ROW_SUB_COUNT;
        
        // Check whether a room address is required for the current join rule
        NSString *joinRule = updatedItemsDict[kRoomSettingsJoinRuleKey];
        if (!joinRule)
        {
            // Use the actual values if no change is pending.
            joinRule = mxRoomState.joinRule;
        }
    }
    else if (section == ROOM_SETTINGS_HISTORY_VISIBILITY_SECTION_INDEX)
    {
        count = ROOM_SETTINGS_HISTORY_VISIBILITY_SECTION_ROW_COUNT;
    }
    
    return count;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == ROOM_SETTINGS_ROOM_ACCESS_SECTION_INDEX && !mxRoom.isDirect)
    {
        return NSLocalizedStringFromTable(@"room_details_access_section", @"Vector", nil);
    }
    else if (section == ROOM_SETTINGS_HISTORY_VISIBILITY_SECTION_INDEX - (mxRoom.isDirect ? 1 : 0))
    {
        return NSLocalizedStringFromTable(@"room_details_history_section", @"Vector", nil);
    }
    
    return nil;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
    if ([view isKindOfClass:UITableViewHeaderFooterView.class])
    {
        // Customize label style
        UITableViewHeaderFooterView *tableViewHeaderFooterView = (UITableViewHeaderFooterView*)view;
        tableViewHeaderFooterView.textLabel.textColor = ThemeService.shared.theme.textPrimaryColor;
        tableViewHeaderFooterView.textLabel.font = [UIFont systemFontOfSize:15];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return [super tableView:tableView heightForHeaderInSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return [super tableView:tableView heightForFooterInSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == ROOM_SETTINGS_MAIN_SECTION_INDEX && !mxRoom.isDirect)
    {
        if (indexPath.row == ROOM_SETTINGS_MAIN_SECTION_ROW_TOPIC)
        {
            return ROOM_TOPIC_CELL_HEIGHT;
        }
    }
    
    return [super tableView:tableView heightForRowAtIndexPath:indexPath];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger row = indexPath.row;
    UITableViewCell* cell;
    
    // Check user's power level to know which settings are editable.
    MXRoomPowerLevels *powerLevels = [mxRoomState powerLevels];
    NSInteger oneSelfPowerLevel = [powerLevels powerLevelOfUserWithUserID:self.mainSession.myUser.userId];
    
    // general settings
    if (indexPath.section == ROOM_SETTINGS_MAIN_SECTION_INDEX)
    {
        NSInteger rowEnum = [[mainSectionSettingsOrder objectAtIndex:row] integerValue];
        if (rowEnum == ROOM_SETTINGS_MAIN_SECTION_ROW_MUTE_NOTIFICATIONS)
        {
            MXKTableViewCellWithLabelAndSwitch *roomNotifCell = [self getLabelAndSwitchCell:tableView forIndexPath:indexPath];

            [roomNotifCell.mxkSwitch addTarget:self action:@selector(toggleRoomNotification:) forControlEvents:UIControlEventValueChanged];
            
            roomNotifCell.mxkLabel.text = NSLocalizedStringFromTable(@"room_details_mute_notifs", @"Vector", nil);
            roomNotifCell.mxkLabel.textColor = ThemeService.shared.theme.textPrimaryColor;
            
            if (updatedItemsDict[kRoomSettingsMuteNotifKey])
            {
                roomNotifCell.mxkSwitch.on = ((NSNumber*) updatedItemsDict[kRoomSettingsMuteNotifKey]).boolValue;
            }
            else
            {
                roomNotifCell.mxkSwitch.on = mxRoom.isMute || mxRoom.isMentionsOnly;
            }
            
            cell = roomNotifCell;
        }
        else if (rowEnum == ROOM_SETTINGS_MAIN_SECTION_ROW_PHOTO)
        {
            MXKTableViewCellWithLabelAndMXKImageView *roomPhotoCell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCellWithLabelAndMXKImageView defaultReuseIdentifier] forIndexPath:indexPath];
            
            roomPhotoCell.mxkLabelLeadingConstraint.constant = roomPhotoCell.vc_separatorInset.left;
            roomPhotoCell.mxkImageViewTrailingConstraint.constant = 10;
            
            roomPhotoCell.mxkImageViewWidthConstraint.constant = roomPhotoCell.mxkImageViewHeightConstraint.constant = 30;
            
            roomPhotoCell.mxkImageViewDisplayBoxType = MXKTableViewCellDisplayBoxTypeCircle;
            
            // Handle tap on avatar to update it
            if (!roomPhotoCell.mxkImageView.gestureRecognizers.count)
            {
                UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onRoomAvatarTap:)];
                [roomPhotoCell.mxkImageView addGestureRecognizer:tap];
            }
            
            roomPhotoCell.mxkImageView.defaultBackgroundColor = [UIColor clearColor];
            
            roomPhotoCell.mxkLabel.text = NSLocalizedStringFromTable(@"room_details_photo", @"Vector", nil);
            roomPhotoCell.mxkLabel.textColor = ThemeService.shared.theme.textPrimaryColor;
            
            if (updatedItemsDict[kRoomSettingsAvatarKey])
            {
                roomPhotoCell.mxkImageView.image = (UIImage*) updatedItemsDict[kRoomSettingsAvatarKey];
            }
            else
            {
                [mxRoom.summary setRoomAvatarImageIn:roomPhotoCell.mxkImageView];
                
                roomPhotoCell.userInteractionEnabled = (oneSelfPowerLevel >= [powerLevels minimumPowerLevelForSendingEventAsStateEvent:kMXEventTypeStringRoomAvatar]);
                roomPhotoCell.mxkImageView.alpha = roomPhotoCell.userInteractionEnabled ? 1.0f : 0.5f;
            }
            
            cell = roomPhotoCell;
        }
        else if (rowEnum == ROOM_SETTINGS_MAIN_SECTION_ROW_TOPIC)
        {
            TableViewCellWithLabelAndLargeTextView *roomTopicCell = [tableView dequeueReusableCellWithIdentifier:kRoomSettingsTopicCellViewIdentifier forIndexPath:indexPath];
            
            roomTopicCell.labelLeadingConstraint.constant = roomTopicCell.vc_separatorInset.left;
            
            roomTopicCell.label.text = NSLocalizedStringFromTable(@"room_details_topic", @"Vector", nil);
            
            topicTextView = roomTopicCell.textView;
            
            if (updatedItemsDict[kRoomSettingsTopicKey])
            {
                topicTextView.text = (NSString*) updatedItemsDict[kRoomSettingsTopicKey];
            }
            else
            {
                topicTextView.text = mxRoomState.topic;
            }
            
            topicTextView.tintColor = ThemeService.shared.theme.tintColor;
            topicTextView.font = [UIFont systemFontOfSize:15];
            topicTextView.bounces = NO;
            topicTextView.delegate = self;
            
            // disable the edition if the user cannot update it
            topicTextView.editable = (oneSelfPowerLevel >= [powerLevels minimumPowerLevelForSendingEventAsStateEvent:kMXEventTypeStringRoomTopic]);
            topicTextView.textColor = ThemeService.shared.theme.textSecondaryColor;
            
            topicTextView.keyboardAppearance = ThemeService.shared.theme.keyboardAppearance;
            
            cell = roomTopicCell;
        }
        else if (rowEnum == ROOM_SETTINGS_MAIN_SECTION_ROW_NAME)
        {
            MXKTableViewCellWithLabelAndTextField *roomNameCell = [tableView dequeueReusableCellWithIdentifier:kRoomSettingsNameCellViewIdentifier forIndexPath:indexPath];
            
            roomNameCell.mxkLabelLeadingConstraint.constant = roomNameCell.vc_separatorInset.left;
            roomNameCell.mxkTextFieldLeadingConstraint.constant = 16;
            roomNameCell.mxkTextFieldTrailingConstraint.constant = 15;
            
            roomNameCell.mxkLabel.text = NSLocalizedStringFromTable(@"room_details_room_name", @"Vector", nil);
            roomNameCell.mxkLabel.textColor = ThemeService.shared.theme.textPrimaryColor;
            
            roomNameCell.accessoryType = UITableViewCellAccessoryNone;
            roomNameCell.accessoryView = nil;
            
            nameTextField = roomNameCell.mxkTextField;
            
            nameTextField.tintColor = ThemeService.shared.theme.tintColor;
            nameTextField.font = [UIFont systemFontOfSize:17];
            nameTextField.borderStyle = UITextBorderStyleNone;
            nameTextField.textAlignment = NSTextAlignmentRight;
            nameTextField.delegate = self;
            
            if (updatedItemsDict[kRoomSettingsNameKey])
            {
                nameTextField.text = (NSString*) updatedItemsDict[kRoomSettingsNameKey];
            }
            else
            {
                nameTextField.text = mxRoomState.name;
            }
            
            // disable the edition if the user cannot update it
            nameTextField.userInteractionEnabled = (oneSelfPowerLevel >= [powerLevels minimumPowerLevelForSendingEventAsStateEvent:kMXEventTypeStringRoomName]);
            nameTextField.textColor = ThemeService.shared.theme.textSecondaryColor;
            
            // Add a "textFieldDidChange" notification method to the text field control.
            [nameTextField addTarget:self action:@selector(onTextFieldUpdate:) forControlEvents:UIControlEventEditingChanged];
            
            cell = roomNameCell;
        }
        else if (rowEnum == ROOM_SETTINGS_MAIN_SECTION_ROW_LEAVE)
        {
            MXKTableViewCellWithButton *leaveCell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCellWithButton defaultReuseIdentifier] forIndexPath:indexPath];
            
            NSString* title = NSLocalizedStringFromTable(@"leave", @"Vector", nil);
            
            [leaveCell.mxkButton setTitle:title forState:UIControlStateNormal];
            [leaveCell.mxkButton setTitle:title forState:UIControlStateHighlighted];
            leaveCell.mxkButton.titleLabel.font = [UIFont systemFontOfSize:17];
            leaveCell.mxkButton.tintColor = ThemeService.shared.theme.warningColor;
            
            [leaveCell.mxkButton  removeTarget:self action:nil forControlEvents:UIControlEventTouchUpInside];
            [leaveCell.mxkButton addTarget:self action:@selector(onLeave:) forControlEvents:UIControlEventTouchUpInside];
            
            cell = leaveCell;
        }
    }
    else if (indexPath.section == ROOM_SETTINGS_ROOM_ACCESS_SECTION_INDEX)
    {
        TableViewCellWithCheckBoxAndLabel *roomAccessCell = [tableView dequeueReusableCellWithIdentifier:[TableViewCellWithCheckBoxAndLabel defaultReuseIdentifier] forIndexPath:indexPath];
        
        roomAccessCell.checkBoxLeadingConstraint.constant = roomAccessCell.separatorInset.left;
        
        // Retrieve the potential updated values for joinRule and guestAccess
        NSString *joinRule = [updatedItemsDict objectForKey:kRoomSettingsJoinRuleKey];
        NSString *guestAccess = [updatedItemsDict objectForKey:kRoomSettingsGuestAccessKey];
        
        // Use the actual values if no change is pending
        if (!joinRule)
        {
            joinRule = mxRoomState.joinRule;
        }
        if (!guestAccess)
        {
            guestAccess = mxRoomState.guestAccess;
        }
        
        if (indexPath.row == ROOM_SETTINGS_ROOM_ACCESS_SECTION_ROW_INVITED_ONLY)
        {
            roomAccessCell.label.text = NSLocalizedStringFromTable(@"room_details_access_section_invited_only", @"Vector", nil);
            
            roomAccessCell.enabled = ([joinRule isEqualToString:kMXRoomJoinRuleInvite]);
            
            accessInvitedOnlyTickCell = roomAccessCell;
        }
        else if (indexPath.row == ROOM_SETTINGS_ROOM_ACCESS_SECTION_ROW_ANYONE_APART_FROM_GUEST)
        {
            roomAccessCell.label.text = NSLocalizedStringFromTable(@"room_details_access_section_anyone_apart_from_guest", @"Vector", nil);
            
            roomAccessCell.enabled = ([joinRule isEqualToString:kMXRoomJoinRulePublic] && [guestAccess isEqualToString:kMXRoomGuestAccessForbidden]);
            
            accessAnyoneApartGuestTickCell = roomAccessCell;
        }
        else if (indexPath.row == ROOM_SETTINGS_ROOM_ACCESS_SECTION_ROW_ANYONE)
        {
            roomAccessCell.label.text = NSLocalizedStringFromTable(@"room_details_access_section_anyone", @"Vector", nil);
            
            roomAccessCell.enabled = ([joinRule isEqualToString:kMXRoomJoinRulePublic] && [guestAccess isEqualToString:kMXRoomGuestAccessCanJoin]);
            
            accessAnyoneTickCell = roomAccessCell;
        }
        
        // Check whether the user can change this option
        roomAccessCell.userInteractionEnabled = (oneSelfPowerLevel >= [powerLevels minimumPowerLevelForSendingEventAsStateEvent:kMXEventTypeStringRoomJoinRules]);
        roomAccessCell.checkBox.alpha = roomAccessCell.userInteractionEnabled ? 1.0f : 0.5f;
        
        cell = roomAccessCell;
    }
    else if (indexPath.section == ROOM_SETTINGS_HISTORY_VISIBILITY_SECTION_INDEX)
    {
        TableViewCellWithCheckBoxAndLabel *historyVisibilityCell = [tableView dequeueReusableCellWithIdentifier:[TableViewCellWithCheckBoxAndLabel defaultReuseIdentifier] forIndexPath:indexPath];
        
        historyVisibilityCell.checkBoxLeadingConstraint.constant = historyVisibilityCell.vc_separatorInset.left;
        
        // Retrieve first the potential updated value for history visibility
        NSString *visibility = updatedItemsDict[kRoomSettingsHistoryVisibilityKey];
        
        // Use the actual value if no change is pending
        if (!visibility)
        {
            visibility = mxRoomState.historyVisibility;
        }
        
        if (indexPath.row == ROOM_SETTINGS_HISTORY_VISIBILITY_SECTION_ROW_ANYONE)
        {
            historyVisibilityCell.label.lineBreakMode = NSLineBreakByTruncatingMiddle;
            historyVisibilityCell.label.text = NSLocalizedStringFromTable(@"room_details_history_section_anyone", @"Vector", nil);
            
            historyVisibilityCell.enabled = ([visibility isEqualToString:kMXRoomHistoryVisibilityWorldReadable]);
            
            historyVisibilityTickCells[kMXRoomHistoryVisibilityWorldReadable] = historyVisibilityCell;
        }
        else if (indexPath.row == ROOM_SETTINGS_HISTORY_VISIBILITY_SECTION_ROW_MEMBERS_ONLY)
        {
            historyVisibilityCell.label.lineBreakMode = NSLineBreakByTruncatingMiddle;
            historyVisibilityCell.label.text = NSLocalizedStringFromTable(@"room_details_history_section_members_only", @"Vector", nil);
            
            historyVisibilityCell.enabled = ([visibility isEqualToString:kMXRoomHistoryVisibilityShared]);
            
            historyVisibilityTickCells[kMXRoomHistoryVisibilityShared] = historyVisibilityCell;
        }
        else if (indexPath.row == ROOM_SETTINGS_HISTORY_VISIBILITY_SECTION_ROW_MEMBERS_ONLY_SINCE_INVITED)
        {
            historyVisibilityCell.label.lineBreakMode = NSLineBreakByTruncatingMiddle;
            historyVisibilityCell.label.text = NSLocalizedStringFromTable(@"room_details_history_section_members_only_since_invited", @"Vector", nil);
            
            historyVisibilityCell.enabled = ([visibility isEqualToString:kMXRoomHistoryVisibilityInvited]);
            
            historyVisibilityTickCells[kMXRoomHistoryVisibilityInvited] = historyVisibilityCell;
        }
        else if (indexPath.row == ROOM_SETTINGS_HISTORY_VISIBILITY_SECTION_ROW_MEMBERS_ONLY_SINCE_JOINED)
        {
            historyVisibilityCell.label.lineBreakMode = NSLineBreakByTruncatingMiddle;
            historyVisibilityCell.label.text = NSLocalizedStringFromTable(@"room_details_history_section_members_only_since_joined", @"Vector", nil);
            
            historyVisibilityCell.enabled = ([visibility isEqualToString:kMXRoomHistoryVisibilityJoined]);
            
            historyVisibilityTickCells[kMXRoomHistoryVisibilityJoined] = historyVisibilityCell;
        }
        
        // Check whether the user can change this option
        historyVisibilityCell.userInteractionEnabled = false;
        historyVisibilityCell.checkBox.alpha = historyVisibilityCell.userInteractionEnabled ? 1.0f : 0.5f;
        
        cell = historyVisibilityCell;
    }
    
    // Sanity check
    if (!cell)
    {
        NSLog(@"[RoomSettingsViewController] cellForRowAtIndexPath: invalid indexPath");
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    }
    
    return cell;
}

- (MXKTableViewCellWithLabelAndSwitch*)getLabelAndSwitchCell:(UITableView*)tableview forIndexPath:(NSIndexPath *)indexPath
{
    MXKTableViewCellWithLabelAndSwitch *cell = [tableview dequeueReusableCellWithIdentifier:[MXKTableViewCellWithLabelAndSwitch defaultReuseIdentifier] forIndexPath:indexPath];
    
    cell.mxkLabelLeadingConstraint.constant = cell.vc_separatorInset.left;
    cell.mxkSwitchTrailingConstraint.constant = 15;
    
    [cell.mxkSwitch removeTarget:self action:nil forControlEvents:UIControlEventValueChanged];
    
    // Force layout before reusing a cell (fix switch displayed outside the screen)
    [cell layoutIfNeeded];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;
{
    cell.backgroundColor = ThemeService.shared.theme.backgroundColor;
    
    // Update the selected background view
    if (ThemeService.shared.theme.selectedBackgroundColor)
    {
        cell.selectedBackgroundView = [[UIView alloc] init];
        cell.selectedBackgroundView.backgroundColor = ThemeService.shared.theme.selectedBackgroundColor;
    }
    else
    {
        if (tableView.style == UITableViewStylePlain)
        {
            cell.selectedBackgroundView = nil;
        }
        else
        {
            cell.selectedBackgroundView.backgroundColor = nil;
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.tableView == tableView)
    {
        [self dismissFirstResponder];
        
        if (indexPath.section == ROOM_SETTINGS_MAIN_SECTION_INDEX)
        {
            if (indexPath.row == ROOM_SETTINGS_MAIN_SECTION_ROW_PHOTO)
            {
                [self onRoomAvatarTap:nil];
            }
            else if (indexPath.row == ROOM_SETTINGS_MAIN_SECTION_ROW_TOPIC)
            {
                if (topicTextView.editable)
                {
                    [self editRoomTopic];
                }
            }
        }
        else if (indexPath.section == ROOM_SETTINGS_ROOM_ACCESS_SECTION_INDEX)
        {
            BOOL isUpdated = NO;
            
            if (indexPath.row == ROOM_SETTINGS_ROOM_ACCESS_SECTION_ROW_INVITED_ONLY)
            {
                // Ignore the selection if the option is already enabled
                if (! accessInvitedOnlyTickCell.isEnabled)
                {
                    // Enable this option
                    accessInvitedOnlyTickCell.enabled = YES;
                    // Disable other options
                    accessAnyoneApartGuestTickCell.enabled = NO;
                    accessAnyoneTickCell.enabled = NO;
                    
                    // Check the actual option
                    if ([mxRoomState.joinRule isEqualToString:kMXRoomJoinRuleInvite])
                    {
                        // No change on room access
                        [updatedItemsDict removeObjectForKey:kRoomSettingsJoinRuleKey];
                        [updatedItemsDict removeObjectForKey:kRoomSettingsGuestAccessKey];
                    }
                    else
                    {
                        [updatedItemsDict setObject:kMXRoomJoinRuleInvite forKey:kRoomSettingsJoinRuleKey];
                        
                        // Update guest access to allow guest on invitation.
                        // Note: if guest_access is "forbidden" here, guests cannot join this room even if explicitly invited.
                        if ([mxRoomState.guestAccess isEqualToString:kMXRoomGuestAccessCanJoin])
                        {
                            [updatedItemsDict removeObjectForKey:kRoomSettingsGuestAccessKey];
                        }
                        else
                        {
                            [updatedItemsDict setObject:kMXRoomGuestAccessCanJoin forKey:kRoomSettingsGuestAccessKey];
                        }
                    }
                    
                    isUpdated = YES;
                }
            }
            else if (indexPath.row == ROOM_SETTINGS_ROOM_ACCESS_SECTION_ROW_ANYONE_APART_FROM_GUEST)
            {
                // Ignore the selection if the option is already enabled
                if (! accessAnyoneApartGuestTickCell.isEnabled)
                {
                    // Enable this option
                    accessAnyoneApartGuestTickCell.enabled = YES;
                    // Disable other options
                    accessInvitedOnlyTickCell.enabled = NO;
                    accessAnyoneTickCell.enabled = NO;
                    
                    // Check the actual option
                    if ([mxRoomState.joinRule isEqualToString:kMXRoomJoinRulePublic] && [mxRoomState.guestAccess isEqualToString:kMXRoomGuestAccessForbidden])
                    {
                        // No change on room access
                        [updatedItemsDict removeObjectForKey:kRoomSettingsJoinRuleKey];
                        [updatedItemsDict removeObjectForKey:kRoomSettingsGuestAccessKey];
                    }
                    else
                    {
                        if ([mxRoomState.joinRule isEqualToString:kMXRoomJoinRulePublic])
                        {
                            [updatedItemsDict removeObjectForKey:kRoomSettingsJoinRuleKey];
                        }
                        else
                        {
                            updatedItemsDict[kRoomSettingsJoinRuleKey] = kMXRoomJoinRulePublic;
                        }
                        
                        if ([mxRoomState.guestAccess isEqualToString:kMXRoomGuestAccessForbidden])
                        {
                            [updatedItemsDict removeObjectForKey:kRoomSettingsGuestAccessKey];
                        }
                        else
                        {
                            updatedItemsDict[kRoomSettingsGuestAccessKey] = kMXRoomGuestAccessForbidden;
                        }
                    }
                    
                    isUpdated = YES;
                }
            }
            else if (indexPath.row == ROOM_SETTINGS_ROOM_ACCESS_SECTION_ROW_ANYONE)
            {
                // Ignore the selection if the option is already enabled
                if (! accessAnyoneTickCell.isEnabled)
                {
                    // Enable this option
                    accessAnyoneTickCell.enabled = YES;
                    // Disable other options
                    accessInvitedOnlyTickCell.enabled = NO;
                    accessAnyoneApartGuestTickCell.enabled = NO;
                    
                    // Check the actual option
                    if ([mxRoomState.joinRule isEqualToString:kMXRoomJoinRulePublic] && [mxRoomState.guestAccess isEqualToString:kMXRoomGuestAccessCanJoin])
                    {
                        // No change on room access
                        [updatedItemsDict removeObjectForKey:kRoomSettingsJoinRuleKey];
                        [updatedItemsDict removeObjectForKey:kRoomSettingsGuestAccessKey];
                    }
                    else
                    {
                        if ([mxRoomState.joinRule isEqualToString:kMXRoomJoinRulePublic])
                        {
                            [updatedItemsDict removeObjectForKey:kRoomSettingsJoinRuleKey];
                        }
                        else
                        {
                            updatedItemsDict[kRoomSettingsJoinRuleKey] = kMXRoomJoinRulePublic;
                        }
                        
                        if ([mxRoomState.guestAccess isEqualToString:kMXRoomGuestAccessCanJoin])
                        {
                            [updatedItemsDict removeObjectForKey:kRoomSettingsGuestAccessKey];
                        }
                        else
                        {
                            updatedItemsDict[kRoomSettingsGuestAccessKey] = kMXRoomGuestAccessCanJoin;
                        }
                    }
                    
                    isUpdated = YES;
                }
            }
            
            if (isUpdated)
            {
                NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:ROOM_SETTINGS_ROOM_ACCESS_SECTION_INDEX];
                [self.tableView reloadSections:indexSet withRowAnimation:UITableViewRowAnimationNone];
                
                [self getNavigationItem].rightBarButtonItem.enabled = (updatedItemsDict.count != 0);
            }
        }
        
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

#pragma mark - MXKRoomMemberDetailsViewControllerDelegate

- (void)roomMemberDetailsViewController:(MXKRoomMemberDetailsViewController *)roomMemberDetailsViewController startChatWithMemberId:(NSString *)matrixId completion:(void (^)(void))completion
{
    [[AppDelegate theDelegate] createDirectChatWithUserId:matrixId completion:completion];
}

#pragma mark - actions

- (void)onLeave:(id)sender
{
    // Prompt user before leaving the room
    __weak typeof(self) weakSelf = self;
    
    [currentAlert dismissViewControllerAnimated:NO completion:nil];
    
    
    currentAlert = [UIAlertController alertControllerWithTitle:NSLocalizedStringFromTable(@"room_participants_leave_prompt_title", @"Vector", nil)
                                                       message:NSLocalizedStringFromTable(@"room_participants_leave_prompt_msg", @"Vector", nil)
                                                preferredStyle:UIAlertControllerStyleAlert];
    
    [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"]
                                                     style:UIAlertActionStyleCancel
                                                   handler:^(UIAlertAction * action) {
                                                       
                                                       if (weakSelf)
                                                       {
                                                           typeof(self) self = weakSelf;
                                                           self->currentAlert = nil;
                                                       }
                                                       
                                                   }]];
    
    [currentAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"leave", @"Vector", nil)
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * action) {
                                                       
                                                       if (weakSelf)
                                                       {
                                                           typeof(self) self = weakSelf;
                                                           self->currentAlert = nil;
                                                           
                                                           [self startActivityIndicator];
                                                           [self->mxRoom leave:^{
                                                               
                                                               [self withdrawViewControllerAnimated:YES completion:nil];
                                                               
                                                           } failure:^(NSError *error) {
                                                               
                                                               [self stopActivityIndicator];
                                                               
                                                               NSLog(@"[RoomSettingsViewController] Leave room failed");
                                                               // Alert user
                                                               [[AppDelegate theDelegate] showErrorAsAlert:error];
                                                               
                                                           }];
                                                       }
                                                       
                                                   }]];
    
    [currentAlert mxk_setAccessibilityIdentifier:@"RoomSettingsVCLeaveAlert"];
    [self presentViewController:currentAlert animated:YES completion:nil];
}

- (void)onRoomAvatarTap:(UITapGestureRecognizer *)recognizer
{
    SingleImagePickerPresenter *singleImagePickerPresenter = [[SingleImagePickerPresenter alloc] initWithSession:self.mainSession];
    singleImagePickerPresenter.delegate = self;
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:ROOM_SETTINGS_MAIN_SECTION_INDEX inSection:ROOM_SETTINGS_MAIN_SECTION_ROW_PHOTO];
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    UIView *sourceView = cell;
    
    [singleImagePickerPresenter presentFrom:self sourceView:sourceView sourceRect:sourceView.bounds animated:YES];
    
    self.imagePickerPresenter = singleImagePickerPresenter;
}

- (void)toggleRoomNotification:(UISwitch*)theSwitch
{
    if (theSwitch.on == (mxRoom.isMute || mxRoom.isMentionsOnly))
    {
        [updatedItemsDict removeObjectForKey:kRoomSettingsMuteNotifKey];
    }
    else
    {
        updatedItemsDict[kRoomSettingsMuteNotifKey] = @(theSwitch.on);
    }
    
    [self getNavigationItem].rightBarButtonItem.enabled = (updatedItemsDict.count != 0);
}

#pragma mark - SingleImagePickerPresenterDelegate

- (void)singleImagePickerPresenterDidCancel:(SingleImagePickerPresenter *)presenter
{
    [presenter dismissWithAnimated:YES completion:nil];
    self.imagePickerPresenter = nil;
}

- (void)singleImagePickerPresenter:(SingleImagePickerPresenter *)presenter didSelectImageData:(NSData *)imageData withUTI:(MXKUTI *)uti
{
    [presenter dismissWithAnimated:YES completion:nil];
    self.imagePickerPresenter = nil;
    
    UIImage *image = [UIImage imageWithData:imageData];
    if (image)
    {
        [self getNavigationItem].rightBarButtonItem.enabled = YES;
        
        updatedItemsDict[kRoomSettingsAvatarKey] = image;
        
        [self refreshRoomSettings];
    }
}

@end
