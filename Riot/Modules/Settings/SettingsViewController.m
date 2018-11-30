/*
 Copyright 2015 OpenMarket Ltd
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

#import "SettingsViewController.h"

#import <MatrixKit/MatrixKit.h>

#import <MediaPlayer/MediaPlayer.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <OLMKit/OLMKit.h>
#import <Photos/Photos.h>

#import "AppDelegate.h"
#import "AvatarGenerator.h"

#import "BugReportViewController.h"

#import "WebViewViewController.h"

#import "DeactivateAccountViewController.h"

#import "RageShakeManager.h"
#import "RiotDesignValues.h"

#import "GBDeviceInfo_iOS.h"

#import "Riot-Swift.h"

NSString* const kSettingsViewControllerPhoneBookCountryCellId = @"kSettingsViewControllerPhoneBookCountryCellId";

enum
{
    SETTINGS_SECTION_SIGN_OUT_INDEX = 0,
    SETTINGS_SECTION_USER_SETTINGS_INDEX,
    SETTINGS_SECTION_NOTIFICATIONS_SETTINGS_INDEX,
    SETTINGS_SECTION_USER_INTERFACE_INDEX,
    SETTINGS_SECTION_IGNORED_USERS_INDEX,
    SETTINGS_SECTION_OTHER_INDEX,
    SETTINGS_SECTION_LABS_INDEX,
    SETTINGS_SECTION_CRYPTOGRAPHY_INDEX,
    SETTINGS_SECTION_DEVICES_INDEX,
    SETTINGS_SECTION_DEACTIVATE_ACCOUNT_INDEX,
    SETTINGS_SECTION_COUNT
};

enum
{
    NOTIFICATION_SETTINGS_PIN_MISSED_NOTIFICATIONS_INDEX = 0,
    NOTIFICATION_SETTINGS_PIN_UNREAD_INDEX,
    NOTIFICATION_SETTINGS_COUNT
};

enum
{
    USER_INTERFACE_LANGUAGE_INDEX = 0,
    USER_INTERFACE_THEME_INDEX,
    USER_INTERFACE_COUNT
};

enum
{
    OTHER_VERSION_INDEX = 0,
    OTHER_OLM_VERSION_INDEX,
    OTHER_COPYRIGHT_INDEX,
    OTHER_TERM_CONDITIONS_INDEX,
    OTHER_PRIVACY_INDEX,
    OTHER_THIRD_PARTY_INDEX,
    OTHER_CRASH_REPORT_INDEX,
    OTHER_ENABLE_RAGESHAKE_INDEX,
    OTHER_MARK_ALL_AS_READ_INDEX,
    OTHER_CLEAR_CACHE_INDEX,
    OTHER_REPORT_BUG_INDEX,
    OTHER_COUNT
};

enum
{
    LABS_USE_ROOM_MEMBERS_LAZY_LOADING_INDEX = 0,
    LABS_CRYPTO_INDEX,
    LABS_COUNT
};

enum {
    CRYPTOGRAPHY_INFO_INDEX = 0,
    CRYPTOGRAPHY_BLACKLIST_UNVERIFIED_DEVICES_INDEX,
    CRYPTOGRAPHY_EXPORT_INDEX,
    CRYPTOGRAPHY_COUNT
};

#define SECTION_TITLE_PADDING_WHEN_HIDDEN 0.01f

typedef void (^blockSettingsViewController_onReadyToDestroy)();


@interface SettingsViewController () <DeactivateAccountViewControllerDelegate>
{
    // Current alert (if any).
    UIAlertController *currentAlert;

    // listener
    id removedAccountObserver;
    id accountUserInfoObserver;
    id pushInfoUpdateObserver;
    
    id notificationCenterWillUpdateObserver;
    id notificationCenterDidUpdateObserver;
    id notificationCenterDidFailObserver;
    
    // picker
    MediaPickerViewController* mediaPicker;
    
    // profile updates
    // avatar
    UIImage* newAvatarImage;
    // the avatar image has been uploaded
    NSString* uploadedAvatarURL;
    
    // new display name
    NSString* newDisplayName;
    
    // password update
    UITextField* currentPasswordTextField;
    UITextField* newPasswordTextField1;
    UITextField* newPasswordTextField2;
    UIAlertAction* savePasswordAction;
    
    // Dynamic rows in the user settings section
    NSInteger userSettingsProfilePictureIndex;
    NSInteger userSettingsDisplayNameIndex;
    NSInteger userSettingsFirstNameIndex;
    NSInteger userSettingsSurnameIndex;
    NSInteger userSettingsChangePasswordIndex;
    NSInteger userSettingsNightModeSepIndex;
    NSInteger userSettingsNightModeIndex;
    
    // Devices
    NSMutableArray<MXDevice *> *devicesArray;
    DeviceView *deviceView;
    
    // Observe kAppDelegateDidTapStatusBarNotification to handle tap on clock status bar.
    id kAppDelegateDidTapStatusBarNotificationObserver;
    
    // Observe kRiotDesignValuesDidChangeThemeNotification to handle user interface theme change.
    id kRiotDesignValuesDidChangeThemeNotificationObserver;
    
    // Postpone destroy operation when saving, pwd reset or email binding is in progress
    BOOL isSavingInProgress;
    BOOL isResetPwdInProgress;
    blockSettingsViewController_onReadyToDestroy onReadyToDestroyHandler;
    
    //
    UIAlertController *resetPwdAlertController;

    // The view used to export e2e keys
    MXKEncryptionKeysExportView *exportView;

    // The document interaction Controller used to export e2e keys
    UIDocumentInteractionController *documentInteractionController;
    NSURL *keyExportsFile;
    NSTimer *keyExportsFileDeletionTimer;
    
    // The current pushed view controller
    UIViewController *pushedViewController;
}

@property (weak, nonatomic) DeactivateAccountViewController *deactivateAccountViewController;

@end

@implementation SettingsViewController

- (void)finalizeInit
{
    [super finalizeInit];
    
    // Setup `MXKViewControllerHandling` properties
    self.enableBarTintColorStatusChange = NO;
    self.rageShakeManager = [RageShakeManager sharedManager];
    
    isSavingInProgress = NO;
    isResetPwdInProgress = NO;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.navigationItem.title = NSLocalizedStringFromTable(@"settings_title", @"Vector", nil);
    
    // Remove back bar button title when pushing a view controller
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    
    [self.tableView registerClass:MXKTableViewCellWithLabelAndTextField.class forCellReuseIdentifier:[MXKTableViewCellWithLabelAndTextField defaultReuseIdentifier]];
    [self.tableView registerClass:MXKTableViewCellWithLabelAndSwitch.class forCellReuseIdentifier:[MXKTableViewCellWithLabelAndSwitch defaultReuseIdentifier]];
    [self.tableView registerClass:MXKTableViewCellWithLabelAndMXKImageView.class forCellReuseIdentifier:[MXKTableViewCellWithLabelAndMXKImageView defaultReuseIdentifier]];
    [self.tableView registerNib:MXKTableViewCellWithTextView.nib forCellReuseIdentifier:[MXKTableViewCellWithTextView defaultReuseIdentifier]];
    
    // Enable self sizing cells
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 50;
    
    // Make view not extend under nav/tab bar
    self.edgesForExtendedLayout = UIRectEdgeNone;
    
    // Add observer to handle removed accounts
    removedAccountObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXKAccountManagerDidRemoveAccountNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        if ([MXKAccountManager sharedManager].accounts.count)
        {
            // Refresh table to remove this account
            [self refreshSettings];
        }
        
    }];
    
    // Add observer to handle accounts update
    accountUserInfoObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXKAccountUserInfoDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        [self stopActivityIndicator];
        
        [self refreshSettings];
        
    }];
    
    // Add observer to push settings
    pushInfoUpdateObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXKAccountPushKitActivityDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        [self stopActivityIndicator];
        
        [self refreshSettings];
        
    }];
    
    // Add each matrix session, to update the view controller appearance according to mx sessions state
    NSArray *sessions = [AppDelegate theDelegate].mxSessions;
    for (MXSession *mxSession in sessions)
    {
        [self addMatrixSession:mxSession];
    }

    
    // Observe user interface theme change.
    kRiotDesignValuesDidChangeThemeNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kRiotDesignValuesDidChangeThemeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        [self userInterfaceThemeDidChange];
        
    }];
    [self userInterfaceThemeDidChange];
}

- (void)userInterfaceThemeDidChange
{
    self.defaultBarTintColor = kCaritasNavigationBarBgColor;
    self.barTitleColor = kCaritasColorWhite;
    self.activityIndicator.backgroundColor = kCaritasOverlayColor;
    
    self.view.backgroundColor = kCaritasPrimaryBgColor;
    
    if (self.tableView.dataSource)
    {
        [self refreshSettings];
    }
    
    [[AppDelegate theDelegate].masterTabBarController userInterfaceThemeDidChange];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return kCaritasDesignStatusBarStyle;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)destroy
{
    // Release the potential pushed view controller
    [self releasePushedViewController];
    
    if (documentInteractionController)
    {
        [documentInteractionController dismissPreviewAnimated:NO];
        [documentInteractionController dismissMenuAnimated:NO];
        documentInteractionController = nil;
    }
    
    if (kRiotDesignValuesDidChangeThemeNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:kRiotDesignValuesDidChangeThemeNotificationObserver];
        kRiotDesignValuesDidChangeThemeNotificationObserver = nil;
    }

    if (isSavingInProgress || isResetPwdInProgress)
    {
        __weak typeof(self) weakSelf = self;
        onReadyToDestroyHandler = ^() {
            
            if (weakSelf)
            {
                typeof(self) self = weakSelf;
                [self destroy];
            }
            
        };
    }
    else
    {
        // Dispose all resources
        [self reset];
        
        [super destroy];
    }
}

- (void)onMatrixSessionStateDidChange:(NSNotification *)notif
{
    MXSession *mxSession = notif.object;
    
    // Check whether the concerned session is a new one which is not already associated with this view controller.
    if (mxSession.state == MXSessionStateInitialised && [self.mxSessions indexOfObject:mxSession] != NSNotFound)
    {
        // Store this new session
        [self addMatrixSession:mxSession];
    }
    else
    {
        [super onMatrixSessionStateDidChange:notif];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [AppDelegate theDelegate].masterTabBarController.navigationItem.title = NSLocalizedStringFromTable(@"settings_title", @"Vector", nil);
    [[AppDelegate theDelegate].masterTabBarController userInterfaceThemeDidChange];

    // Screen tracking
    [[Analytics sharedInstance] trackScreen:@"Settings"];
    
    // Release the potential pushed view controller
    [self releasePushedViewController];
    
    // Refresh display
    [self refreshSettings];
    
    // Refresh the current device information in parallel
    [self loadCurrentDeviceInformation];
    
    // Refresh devices in parallel
    [self loadDevices];
    
    // Observe kAppDelegateDidTapStatusBarNotificationObserver.
    kAppDelegateDidTapStatusBarNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kAppDelegateDidTapStatusBarNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        [self.tableView setContentOffset:CGPointMake(-self.tableView.mxk_adjustedContentInset.left, -self.tableView.mxk_adjustedContentInset.top) animated:YES];
        
    }];
    
    UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(onSave:)];
    [saveButton setEnabled:NO];
    [AppDelegate theDelegate].masterTabBarController.navigationItem.rightBarButtonItem = saveButton;
    [AppDelegate theDelegate].masterTabBarController.navigationItem.rightBarButtonItem.accessibilityIdentifier=@"SettingsVCNavBarSaveButton";
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    if (currentAlert)
    {
        [currentAlert dismissViewControllerAnimated:NO completion:nil];
        currentAlert = nil;
    }
    
    if (resetPwdAlertController)
    {
        [resetPwdAlertController dismissViewControllerAnimated:NO completion:nil];
        resetPwdAlertController = nil;
    }

    if (notificationCenterWillUpdateObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:notificationCenterWillUpdateObserver];
        notificationCenterWillUpdateObserver = nil;
    }
    
    if (notificationCenterDidUpdateObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:notificationCenterDidUpdateObserver];
        notificationCenterDidUpdateObserver = nil;
    }
    
    if (notificationCenterDidFailObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:notificationCenterDidFailObserver];
        notificationCenterDidFailObserver = nil;
    }
    
    if (kAppDelegateDidTapStatusBarNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:kAppDelegateDidTapStatusBarNotificationObserver];
        kAppDelegateDidTapStatusBarNotificationObserver = nil;
    }
    
    [AppDelegate theDelegate].masterTabBarController.navigationItem.rightBarButtonItem = nil;
}

#pragma mark - Internal methods

- (void)pushViewController:(UIViewController*)viewController
{
    // Keep ref on pushed view controller
    pushedViewController = viewController;
    
    // Hide back button title
    self.navigationItem.backBarButtonItem =[[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    
    [self.navigationController pushViewController:viewController animated:YES];
}

- (void)releasePushedViewController
{
    if (pushedViewController)
    {
        if ([pushedViewController isKindOfClass:[UINavigationController class]])
        {
            UINavigationController *navigationController = (UINavigationController*)pushedViewController;
            for (id subViewController in navigationController.viewControllers)
            {
                if ([subViewController respondsToSelector:@selector(destroy)])
                {
                    [subViewController destroy];
                }
            }
        }
        else if ([pushedViewController respondsToSelector:@selector(destroy)])
        {
            [(id)pushedViewController destroy];
        }
        
        pushedViewController = nil;
    }
}

- (void)dismissKeyboard
{
    [currentPasswordTextField resignFirstResponder];
    [newPasswordTextField1 resignFirstResponder];
    [newPasswordTextField2 resignFirstResponder];
}

- (void)reset
{
    // Remove observers
    if (removedAccountObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:removedAccountObserver];
        removedAccountObserver = nil;
    }
    
    if (accountUserInfoObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:accountUserInfoObserver];
        accountUserInfoObserver = nil;
    }
    
    if (pushInfoUpdateObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:pushInfoUpdateObserver];
        pushInfoUpdateObserver = nil;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    onReadyToDestroyHandler = nil;
    
    if (deviceView)
    {
        [deviceView removeFromSuperview];
        deviceView = nil;
    }
}

- (void)loadCurrentDeviceInformation
{
    // Refresh the current device information
    MXKAccount* account = [MXKAccountManager sharedManager].activeAccounts.firstObject;
    [account loadDeviceInformation:^{
        
        // Refresh all the table (A slide down animation is observed when we limit the refresh to the concerned section).
        // Note: The use of 'reloadData' handles the case where the account has been logged out.
        [self refreshSettings];
        
    } failure:nil];
}

- (NSAttributedString*)cryptographyInformation
{
    // TODO Handle multi accounts
    MXKAccount* account = [MXKAccountManager sharedManager].activeAccounts.firstObject;
    
    // Crypto information
    NSMutableAttributedString *cryptoInformationString = [[NSMutableAttributedString alloc]
                                                          initWithString:NSLocalizedStringFromTable(@"settings_crypto_device_name", @"Vector", nil)
                                                          attributes:@{NSForegroundColorAttributeName : kCaritasPrimaryTextColor,
                                                                       NSFontAttributeName: [UIFont systemFontOfSize:17]}];
    [cryptoInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                     initWithString:account.device.displayName ? account.device.displayName : @""
                                                     attributes:@{NSForegroundColorAttributeName : kCaritasPrimaryTextColor,
                                                                  NSFontAttributeName: [UIFont systemFontOfSize:17]}]];
    
    [cryptoInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                     initWithString:NSLocalizedStringFromTable(@"settings_crypto_device_id", @"Vector", nil)
                                                     attributes:@{NSForegroundColorAttributeName : kCaritasPrimaryTextColor,
                                                                  NSFontAttributeName: [UIFont systemFontOfSize:17]}]];
    [cryptoInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                     initWithString:account.device.deviceId ? account.device.deviceId : @""
                                                     attributes:@{NSForegroundColorAttributeName : kCaritasPrimaryTextColor,
                                                                  NSFontAttributeName: [UIFont systemFontOfSize:17]}]];
    
    [cryptoInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                     initWithString:NSLocalizedStringFromTable(@"settings_crypto_device_key", @"Vector", nil)
                                                     attributes:@{NSForegroundColorAttributeName : kCaritasPrimaryTextColor,
                                                                  NSFontAttributeName: [UIFont systemFontOfSize:17]}]];
    NSString *fingerprint = account.mxSession.crypto.deviceEd25519Key;
    [cryptoInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                     initWithString:fingerprint ? fingerprint : @""
                                                     attributes:@{NSForegroundColorAttributeName : kCaritasPrimaryTextColor,
                                                                  NSFontAttributeName: [UIFont boldSystemFontOfSize:17]}]];
    
    return cryptoInformationString;
}

- (void)loadDevices
{
    // Refresh the account devices list
    MXKAccount* account = [MXKAccountManager sharedManager].activeAccounts.firstObject;
    [account.mxRestClient devices:^(NSArray<MXDevice *> *devices) {
        
        if (devices)
        {
            devicesArray = [NSMutableArray arrayWithArray:devices];
            
            // Sort devices according to the last seen date.
            NSComparator comparator = ^NSComparisonResult(MXDevice *deviceA, MXDevice *deviceB) {
                
                if (deviceA.lastSeenTs > deviceB.lastSeenTs)
                {
                    return NSOrderedAscending;
                }
                if (deviceA.lastSeenTs < deviceB.lastSeenTs)
                {
                    return NSOrderedDescending;
                }
                
                return NSOrderedSame;
            };
            
            // Sort devices list
            [devicesArray sortUsingComparator:comparator];
        }
        else
        {
            devicesArray = nil;

        }
        
        // Refresh all the table (A slide down animation is observed when we limit the refresh to the concerned section).
        // Note: The use of 'reloadData' handles the case where the account has been logged out.
        [self refreshSettings];
        
    } failure:^(NSError *error) {
        
        // Display the data that has been loaded last time
        // Note: The use of 'reloadData' handles the case where the account has been logged out.
        [self refreshSettings];
        
    }];
}

- (void)showDeviceDetails:(MXDevice *)device
{
    [self dismissKeyboard];
    
    deviceView = [[DeviceView alloc] initWithDevice:device andMatrixSession:self.mainSession];
    deviceView.delegate = self;

    // Add the view and define edge constraints
    [self.tableView.superview addSubview:deviceView];
    [self.tableView.superview bringSubviewToFront:deviceView];
    
    NSLayoutConstraint *topConstraint = [NSLayoutConstraint constraintWithItem:deviceView
                                                                     attribute:NSLayoutAttributeTop
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:self.tableView
                                                                     attribute:NSLayoutAttributeTop
                                                                    multiplier:1.0f
                                                                      constant:0.0f];
    
    NSLayoutConstraint *leftConstraint = [NSLayoutConstraint constraintWithItem:deviceView
                                                                      attribute:NSLayoutAttributeLeft
                                                                      relatedBy:NSLayoutRelationEqual
                                                                         toItem:self.tableView
                                                                      attribute:NSLayoutAttributeLeft
                                                                     multiplier:1.0f
                                                                       constant:0.0f];
    
    NSLayoutConstraint *widthConstraint = [NSLayoutConstraint constraintWithItem:deviceView
                                                                       attribute:NSLayoutAttributeWidth
                                                                       relatedBy:NSLayoutRelationEqual
                                                                          toItem:self.tableView
                                                                       attribute:NSLayoutAttributeWidth
                                                                      multiplier:1.0f
                                                                        constant:0.0f];
    
    NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintWithItem:deviceView
                                                                        attribute:NSLayoutAttributeHeight
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:self.tableView
                                                                        attribute:NSLayoutAttributeHeight
                                                                       multiplier:1.0f
                                                                         constant:0.0f];
    
    [NSLayoutConstraint activateConstraints:@[topConstraint, leftConstraint, widthConstraint, heightConstraint]];
}

- (void)deviceView:(DeviceView*)theDeviceView presentAlertController:(UIAlertController *)alert
{
    [self dismissKeyboard];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)dismissDeviceView:(MXKDeviceView *)theDeviceView didUpdate:(BOOL)isUpdated
{
    [deviceView removeFromSuperview];
    deviceView = nil;
    
    if (isUpdated)
    {
        [self loadDevices];
    }
}

- (void)refreshSettings
{
    // Trigger a full table reloadData
    [self.tableView reloadData];
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Keep ref on destinationViewController
    [super prepareForSegue:segue sender:sender];
    
    // FIXME add night mode
}

#pragma mark - UITableView data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // update the save button if there is an update
    [self updateSaveButtonStatus];
    
    return SETTINGS_SECTION_COUNT;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger count = 0;
    
    if (section == SETTINGS_SECTION_SIGN_OUT_INDEX)
    {
        count = 1;
    }
    else if (section == SETTINGS_SECTION_USER_SETTINGS_INDEX)
    {
        userSettingsProfilePictureIndex = count++;
        userSettingsDisplayNameIndex = count++;
        userSettingsChangePasswordIndex = count++;

        // Hide some unsupported account settings
        userSettingsFirstNameIndex = -1;
        userSettingsSurnameIndex = -1;
        userSettingsNightModeSepIndex = -1;
        userSettingsNightModeIndex = -1;
    }
    else if (section == SETTINGS_SECTION_NOTIFICATIONS_SETTINGS_INDEX)
    {
        count = NOTIFICATION_SETTINGS_COUNT;
    }
    else if (section == SETTINGS_SECTION_USER_INTERFACE_INDEX)
    {
        count = USER_INTERFACE_COUNT;
    }
    else if (section == SETTINGS_SECTION_IGNORED_USERS_INDEX)
    {
        if ([AppDelegate theDelegate].mxSessions.count > 0)
        {
            MXSession* session = [[AppDelegate theDelegate].mxSessions objectAtIndex:0];
            count = session.ignoredUsers.count;
        }
        else
        {
            count = 0;
        }
    }
    else if (section == SETTINGS_SECTION_OTHER_INDEX)
    {
        count = OTHER_COUNT;
    }
    else if (section == SETTINGS_SECTION_LABS_INDEX)
    {
        count = LABS_COUNT;
    }
    else if (section == SETTINGS_SECTION_DEVICES_INDEX)
    {
        count = devicesArray.count;
    }
    else if (section == SETTINGS_SECTION_CRYPTOGRAPHY_INDEX)
    {
        // Check whether this section is visible.
        if (self.mainSession.crypto)
        {
            count = CRYPTOGRAPHY_COUNT;
        }
    }
    else if (section == SETTINGS_SECTION_DEACTIVATE_ACCOUNT_INDEX)
    {
        count = 1;
    }
    return count;
}

- (MXKTableViewCellWithLabelAndTextField*)getLabelAndTextFieldCell:(UITableView*)tableview forIndexPath:(NSIndexPath *)indexPath
{
    MXKTableViewCellWithLabelAndTextField *cell = [tableview dequeueReusableCellWithIdentifier:[MXKTableViewCellWithLabelAndTextField defaultReuseIdentifier] forIndexPath:indexPath];
    
    cell.mxkLabelLeadingConstraint.constant = cell.separatorInset.left;
    cell.mxkTextFieldLeadingConstraint.constant = 16;
    cell.mxkTextFieldTrailingConstraint.constant = 15;
    
    cell.mxkLabel.textColor = kCaritasPrimaryTextColor;
    
    cell.mxkTextField.userInteractionEnabled = YES;
    cell.mxkTextField.borderStyle = UITextBorderStyleNone;
    cell.mxkTextField.textAlignment = NSTextAlignmentRight;
    cell.mxkTextField.textColor = kCaritasSecondaryTextColor;
    cell.mxkTextField.font = [UIFont systemFontOfSize:16];
    cell.mxkTextField.placeholder = nil;
    
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    
    cell.alpha = 1.0f;
    cell.userInteractionEnabled = YES;
    
    [cell layoutIfNeeded];
    
    return cell;
}

- (MXKTableViewCellWithLabelAndSwitch*)getLabelAndSwitchCell:(UITableView*)tableview forIndexPath:(NSIndexPath *)indexPath
{
    MXKTableViewCellWithLabelAndSwitch *cell = [tableview dequeueReusableCellWithIdentifier:[MXKTableViewCellWithLabelAndSwitch defaultReuseIdentifier] forIndexPath:indexPath];
    
    cell.mxkLabelLeadingConstraint.constant = cell.separatorInset.left;
    cell.mxkSwitchTrailingConstraint.constant = 15;
    
    cell.mxkLabel.textColor = kCaritasPrimaryTextColor;
    
    [cell.mxkSwitch removeTarget:self action:nil forControlEvents:UIControlEventTouchUpInside];
    
    // Force layout before reusing a cell (fix switch displayed outside the screen)
    [cell layoutIfNeeded];
    
    return cell;
}

- (MXKTableViewCell*)getDefaultTableViewCell:(UITableView*)tableView
{
    MXKTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCell defaultReuseIdentifier]];
    if (!cell)
    {
        cell = [[MXKTableViewCell alloc] init];
    }
    else
    {
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.accessoryView = nil;
    }
    cell.textLabel.accessibilityIdentifier = nil;
    cell.textLabel.font = [UIFont systemFontOfSize:17];
    cell.textLabel.textColor = kCaritasPrimaryTextColor;
    
    return cell;
}

- (MXKTableViewCellWithTextView*)textViewCellForTableView:(UITableView*)tableView atIndexPath:(NSIndexPath *)indexPath
{
    MXKTableViewCellWithTextView *textViewCell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCellWithTextView defaultReuseIdentifier] forIndexPath:indexPath];
    
    textViewCell.mxkTextView.textColor = kCaritasPrimaryTextColor;
    textViewCell.mxkTextView.font = [UIFont systemFontOfSize:17];
    textViewCell.mxkTextView.backgroundColor = [UIColor clearColor];
    textViewCell.mxkTextViewLeadingConstraint.constant = tableView.separatorInset.left;
    textViewCell.mxkTextViewTrailingConstraint.constant = tableView.separatorInset.right;
    textViewCell.mxkTextView.accessibilityIdentifier = nil;
    
    return textViewCell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;

    // set the cell to a default value to avoid application crashes
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.backgroundColor = [UIColor redColor];
    
    // check if there is a valid session
    if (([AppDelegate theDelegate].mxSessions.count == 0) || ([MXKAccountManager sharedManager].activeAccounts.count == 0))
    {
        // else use a default cell
        return cell;
    }
    
    MXSession* session = [[AppDelegate theDelegate].mxSessions objectAtIndex:0];
    MXKAccount* account = [MXKAccountManager sharedManager].activeAccounts.firstObject;

    if (section == SETTINGS_SECTION_SIGN_OUT_INDEX)
    {
        MXKTableViewCellWithButton *signOutCell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCellWithButton defaultReuseIdentifier]];
        if (!signOutCell)
        {
            signOutCell = [[MXKTableViewCellWithButton alloc] init];
        }
        else
        {
            // Fix https://github.com/vector-im/riot-ios/issues/1354
            // Do not move this line in prepareForReuse because of https://github.com/vector-im/riot-ios/issues/1323
            signOutCell.mxkButton.titleLabel.text = nil;
        }
        
        NSString* title = NSLocalizedStringFromTable(@"settings_sign_out", @"Vector", nil);
        
        [signOutCell.mxkButton setTitle:title forState:UIControlStateNormal];
        [signOutCell.mxkButton setTitle:title forState:UIControlStateHighlighted];
        [signOutCell.mxkButton setTintColor:kCaritasColorLinkBlue];
        signOutCell.mxkButton.titleLabel.font = [UIFont systemFontOfSize:17];
        
        [signOutCell.mxkButton  removeTarget:self action:nil forControlEvents:UIControlEventTouchUpInside];
        [signOutCell.mxkButton addTarget:self action:@selector(onSignout:) forControlEvents:UIControlEventTouchUpInside];
        signOutCell.mxkButton.accessibilityIdentifier=@"SettingsVCSignOutButton";
        
        cell = signOutCell;
    }
    else if (section == SETTINGS_SECTION_USER_SETTINGS_INDEX)
    {
        MXMyUser* myUser = session.myUser;
        
        if (row == userSettingsProfilePictureIndex)
        {
            MXKTableViewCellWithLabelAndMXKImageView *profileCell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCellWithLabelAndMXKImageView defaultReuseIdentifier] forIndexPath:indexPath];
            
            profileCell.mxkLabelLeadingConstraint.constant = profileCell.separatorInset.left;
            profileCell.mxkImageViewTrailingConstraint.constant = 10;
            
            profileCell.mxkImageViewWidthConstraint.constant = profileCell.mxkImageViewHeightConstraint.constant = 30;
            profileCell.mxkImageViewDisplayBoxType = MXKTableViewCellDisplayBoxTypeCircle;
            
            if (!profileCell.mxkImageView.gestureRecognizers.count)
            {
                // tap on avatar to update it
                UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onProfileAvatarTap:)];
                [profileCell.mxkImageView addGestureRecognizer:tap];
            }
            
            profileCell.mxkLabel.text = NSLocalizedStringFromTable(@"settings_profile_picture", @"Vector", nil);
            profileCell.accessibilityIdentifier=@"SettingsVCProfilPictureStaticText";
            profileCell.mxkLabel.textColor = kCaritasPrimaryTextColor;
            
            // if the user defines a new avatar
            if (newAvatarImage)
            {
                profileCell.mxkImageView.image = newAvatarImage;
            }
            else
            {
                UIImage* avatarImage = [AvatarGenerator generateAvatarForMatrixItem:myUser.userId withDisplayName:myUser.displayname];
                
                if (myUser.avatarUrl)
                {
                    profileCell.mxkImageView.enableInMemoryCache = YES;
                    
                    [profileCell.mxkImageView setImageURL:[session.matrixRestClient urlOfContentThumbnail:myUser.avatarUrl toFitViewSize:profileCell.mxkImageView.frame.size withMethod:MXThumbnailingMethodCrop] withType:nil andImageOrientation:UIImageOrientationUp previewImage:avatarImage];
                }
                else
                {
                    profileCell.mxkImageView.image = avatarImage;
                }
            }
            
            cell = profileCell;
        }
        else if (row == userSettingsDisplayNameIndex)
        {
            MXKTableViewCellWithLabelAndTextField *displaynameCell = [self getLabelAndTextFieldCell:tableView forIndexPath:indexPath];
            
            displaynameCell.mxkLabel.text = NSLocalizedStringFromTable(@"settings_display_name", @"Vector", nil);
            displaynameCell.mxkTextField.text = myUser.displayname;
            
            displaynameCell.mxkTextField.tag = row;
            displaynameCell.mxkTextField.delegate = self;
            [displaynameCell.mxkTextField removeTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
            [displaynameCell.mxkTextField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
            displaynameCell.mxkTextField.accessibilityIdentifier=@"SettingsVCDisplayNameTextField";
            
            cell = displaynameCell;
        }
        else if (row == userSettingsFirstNameIndex)
        {
            MXKTableViewCellWithLabelAndTextField *firstCell = [self getLabelAndTextFieldCell:tableView forIndexPath:indexPath];
        
            firstCell.mxkLabel.text = NSLocalizedStringFromTable(@"settings_first_name", @"Vector", nil);
            firstCell.mxkTextField.userInteractionEnabled = NO;
            
            cell = firstCell;
        }
        else if (row == userSettingsSurnameIndex)
        {
            MXKTableViewCellWithLabelAndTextField *surnameCell = [self getLabelAndTextFieldCell:tableView forIndexPath:indexPath];
            
            surnameCell.mxkLabel.text = NSLocalizedStringFromTable(@"settings_surname", @"Vector", nil);
            surnameCell.mxkTextField.userInteractionEnabled = NO;
            
            cell = surnameCell;
        }
        else if (row == userSettingsChangePasswordIndex)
        {
            MXKTableViewCellWithLabelAndTextField *passwordCell = [self getLabelAndTextFieldCell:tableView forIndexPath:indexPath];
            
            passwordCell.mxkLabel.text = NSLocalizedStringFromTable(@"settings_change_password", @"Vector", nil);
            passwordCell.mxkTextField.text = @"*********";
            passwordCell.mxkTextField.userInteractionEnabled = NO;
            passwordCell.mxkLabel.accessibilityIdentifier=@"SettingsVCChangePwdStaticText";
            
            cell = passwordCell;
        }
        else if (row == userSettingsNightModeSepIndex)
        {
            UITableViewCell *sepCell = [[UITableViewCell alloc] init];
            sepCell.backgroundColor = kCaritasSecondaryBgColor;
            
            cell = sepCell;
        }
        else if (row == userSettingsNightModeIndex)
        {
            MXKTableViewCellWithLabelAndTextField *nightModeCell = [self getLabelAndTextFieldCell:tableView forIndexPath:indexPath];
                                                                    
            nightModeCell.mxkLabel.text = NSLocalizedStringFromTable(@"settings_night_mode", @"Vector", nil);
            nightModeCell.mxkTextField.userInteractionEnabled = NO;
            nightModeCell.mxkTextField.text = NSLocalizedStringFromTable(@"off", @"Vector", nil);
            nightModeCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell = nightModeCell;
        }
    }
    else if (section == SETTINGS_SECTION_NOTIFICATIONS_SETTINGS_INDEX)
    {
        if (row == NOTIFICATION_SETTINGS_PIN_MISSED_NOTIFICATIONS_INDEX)
        {
            MXKTableViewCellWithLabelAndSwitch* labelAndSwitchCell = [self getLabelAndSwitchCell:tableView forIndexPath:indexPath];
            
            labelAndSwitchCell.mxkLabel.text = NSLocalizedStringFromTable(@"settings_pin_rooms_with_missed_notif", @"Vector", nil);
            labelAndSwitchCell.mxkSwitch.on = RiotSettings.shared.pinRoomsWithMissedNotificationsOnHome;
            labelAndSwitchCell.mxkSwitch.enabled = YES;
            [labelAndSwitchCell.mxkSwitch addTarget:self action:@selector(togglePinRoomsWithMissedNotif:) forControlEvents:UIControlEventTouchUpInside];
            
            cell = labelAndSwitchCell;
        }
        else if (row == NOTIFICATION_SETTINGS_PIN_UNREAD_INDEX)
        {
            MXKTableViewCellWithLabelAndSwitch* labelAndSwitchCell = [self getLabelAndSwitchCell:tableView forIndexPath:indexPath];
            
            labelAndSwitchCell.mxkLabel.text = NSLocalizedStringFromTable(@"settings_pin_rooms_with_unread", @"Vector", nil);
            labelAndSwitchCell.mxkSwitch.on = RiotSettings.shared.pinRoomsWithUnreadMessagesOnHome;                        
            labelAndSwitchCell.mxkSwitch.enabled = YES;
            [labelAndSwitchCell.mxkSwitch addTarget:self action:@selector(togglePinRoomsWithUnread:) forControlEvents:UIControlEventTouchUpInside];
            
            cell = labelAndSwitchCell;
        }
    }
    else if (section == SETTINGS_SECTION_USER_INTERFACE_INDEX)
    {
        if (row == USER_INTERFACE_LANGUAGE_INDEX)
        {
            cell = [tableView dequeueReusableCellWithIdentifier:kSettingsViewControllerPhoneBookCountryCellId];
            if (!cell)
            {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kSettingsViewControllerPhoneBookCountryCellId];
            }

            NSString *language = [NSBundle mxk_language];
            if (!language)
            {
                language = [MXKLanguagePickerViewController defaultLanguage];
            }
            NSString *languageDescription = [MXKLanguagePickerViewController languageDescription:language];

            // Capitalise the description in the language locale
            NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:language];
            languageDescription = [languageDescription capitalizedStringWithLocale:locale];

            cell.textLabel.textColor = kCaritasPrimaryTextColor;

            cell.textLabel.text = NSLocalizedStringFromTable(@"settings_ui_language", @"Vector", nil);
            cell.detailTextLabel.text = languageDescription;

            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        }
        else if (row == USER_INTERFACE_THEME_INDEX)
        {
            cell = [tableView dequeueReusableCellWithIdentifier:kSettingsViewControllerPhoneBookCountryCellId];
            if (!cell)
            {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kSettingsViewControllerPhoneBookCountryCellId];
            }

            NSString *theme = RiotSettings.shared.userInterfaceTheme;
            
            if (!theme)
            {
                if (@available(iOS 11.0, *))
                {
                    // "auto" is used the default value from iOS 11
                    theme = @"auto";
                }
                else
                {
                    // Use "light" for older version
                    theme = @"light";
                }
            }

            theme = [NSString stringWithFormat:@"settings_ui_theme_%@", theme];
            NSString *i18nTheme = NSLocalizedStringFromTable(theme,
                                                              @"Vector",
                                                             nil);

            cell.textLabel.textColor = kCaritasPrimaryTextColor;

            cell.textLabel.text = NSLocalizedStringFromTable(@"settings_ui_theme", @"Vector", nil);
            cell.detailTextLabel.text = i18nTheme;

            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        }
    }
    else if (section == SETTINGS_SECTION_IGNORED_USERS_INDEX)
    {
        MXKTableViewCell *ignoredUserCell = [self getDefaultTableViewCell:tableView];

        NSString *ignoredUserId;
        if (indexPath.row < session.ignoredUsers.count)
        {
            ignoredUserId = session.ignoredUsers[indexPath.row];
        }
        ignoredUserCell.textLabel.text = ignoredUserId;

        cell = ignoredUserCell;
    }
    else if (section == SETTINGS_SECTION_OTHER_INDEX)
    {
        if (row == OTHER_VERSION_INDEX)
        {
            MXKTableViewCell *versionCell = [self getDefaultTableViewCell:tableView];
            
            NSString* appVersion = [AppDelegate theDelegate].appVersion;
            NSString* build = [AppDelegate theDelegate].build;
            
            versionCell.textLabel.text = [NSString stringWithFormat:NSLocalizedStringFromTable(@"settings_version", @"Vector", nil), [NSString stringWithFormat:@"%@ %@", appVersion, build]];
            
            versionCell.selectionStyle = UITableViewCellSelectionStyleNone;
            
            cell = versionCell;
        }
        else if (row == OTHER_OLM_VERSION_INDEX)
        {
            MXKTableViewCell *versionCell = [self getDefaultTableViewCell:tableView];
            
            versionCell.textLabel.text = [NSString stringWithFormat:NSLocalizedStringFromTable(@"settings_olm_version", @"Vector", nil), [OLMKit versionString]];
            
            versionCell.selectionStyle = UITableViewCellSelectionStyleNone;
            
            cell = versionCell;
        }
        else if (row == OTHER_TERM_CONDITIONS_INDEX)
        {
            MXKTableViewCell *termAndConditionCell = [self getDefaultTableViewCell:tableView];

            termAndConditionCell.textLabel.text = NSLocalizedStringFromTable(@"settings_term_conditions", @"Vector", nil);
            
            termAndConditionCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            
            cell = termAndConditionCell;
        }
        else if (row == OTHER_COPYRIGHT_INDEX)
        {
            MXKTableViewCell *copyrightCell = [self getDefaultTableViewCell:tableView];

            copyrightCell.textLabel.text = NSLocalizedStringFromTable(@"settings_copyright", @"Vector", nil);
            
            copyrightCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            
            cell = copyrightCell;
        }
        else if (row == OTHER_PRIVACY_INDEX)
        {
            MXKTableViewCell *privacyPolicyCell = [self getDefaultTableViewCell:tableView];
            
            privacyPolicyCell.textLabel.text = NSLocalizedStringFromTable(@"settings_privacy_policy", @"Vector", nil);
            
            privacyPolicyCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            
            cell = privacyPolicyCell;
        }
        else if (row == OTHER_THIRD_PARTY_INDEX)
        {
            MXKTableViewCell *thirdPartyCell = [self getDefaultTableViewCell:tableView];
            
            thirdPartyCell.textLabel.text = NSLocalizedStringFromTable(@"settings_third_party_notices", @"Vector", nil);
            
            thirdPartyCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            
            cell = thirdPartyCell;
        }
        else if (row == OTHER_CRASH_REPORT_INDEX)
        {
            MXKTableViewCellWithLabelAndSwitch* sendCrashReportCell = [self getLabelAndSwitchCell:tableView forIndexPath:indexPath];
            
            sendCrashReportCell.mxkLabel.text = NSLocalizedStringFromTable(@"settings_send_crash_report", @"Vector", nil);
            sendCrashReportCell.mxkSwitch.on = RiotSettings.shared.enableCrashReport;
            sendCrashReportCell.mxkSwitch.enabled = YES;
            [sendCrashReportCell.mxkSwitch addTarget:self action:@selector(toggleSendCrashReport:) forControlEvents:UIControlEventTouchUpInside];
            
            cell = sendCrashReportCell;
        }
        else if (row == OTHER_ENABLE_RAGESHAKE_INDEX)
        {
            MXKTableViewCellWithLabelAndSwitch* enableRageShakeCell = [self getLabelAndSwitchCell:tableView forIndexPath:indexPath];

            enableRageShakeCell.mxkLabel.text = NSLocalizedStringFromTable(@"settings_enable_rageshake", @"Vector", nil);
            enableRageShakeCell.mxkSwitch.on = RiotSettings.shared.enableRageShake;
            enableRageShakeCell.mxkSwitch.enabled = YES;
            [enableRageShakeCell.mxkSwitch addTarget:self action:@selector(toggleEnableRageShake:) forControlEvents:UIControlEventTouchUpInside];

            cell = enableRageShakeCell;
        }
        else if (row == OTHER_MARK_ALL_AS_READ_INDEX)
        {
            MXKTableViewCellWithButton *markAllBtnCell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCellWithButton defaultReuseIdentifier]];
            if (!markAllBtnCell)
            {
                markAllBtnCell = [[MXKTableViewCellWithButton alloc] init];
            }
            else
            {
                // Fix https://github.com/vector-im/riot-ios/issues/1354
                markAllBtnCell.mxkButton.titleLabel.text = nil;
            }
            
            NSString *btnTitle = NSLocalizedStringFromTable(@"settings_mark_all_as_read", @"Vector", nil);
            [markAllBtnCell.mxkButton setTitle:btnTitle forState:UIControlStateNormal];
            [markAllBtnCell.mxkButton setTitle:btnTitle forState:UIControlStateHighlighted];
            [markAllBtnCell.mxkButton setTintColor:kCaritasColorLinkBlue];
            markAllBtnCell.mxkButton.titleLabel.font = [UIFont systemFontOfSize:17];
            
            [markAllBtnCell.mxkButton removeTarget:self action:nil forControlEvents:UIControlEventTouchUpInside];
            [markAllBtnCell.mxkButton addTarget:self action:@selector(markAllAsRead:) forControlEvents:UIControlEventTouchUpInside];
            markAllBtnCell.mxkButton.accessibilityIdentifier = nil;
            
            cell = markAllBtnCell;
        }
        else if (row == OTHER_CLEAR_CACHE_INDEX)
        {
            MXKTableViewCellWithButton *clearCacheBtnCell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCellWithButton defaultReuseIdentifier]];
            if (!clearCacheBtnCell)
            {
                clearCacheBtnCell = [[MXKTableViewCellWithButton alloc] init];
            }
            else
            {
                // Fix https://github.com/vector-im/riot-ios/issues/1354
                clearCacheBtnCell.mxkButton.titleLabel.text = nil;
            }
            
            NSString *btnTitle = NSLocalizedStringFromTable(@"settings_clear_cache", @"Vector", nil);
            [clearCacheBtnCell.mxkButton setTitle:btnTitle forState:UIControlStateNormal];
            [clearCacheBtnCell.mxkButton setTitle:btnTitle forState:UIControlStateHighlighted];
            [clearCacheBtnCell.mxkButton setTintColor:kCaritasColorLinkBlue];
            clearCacheBtnCell.mxkButton.titleLabel.font = [UIFont systemFontOfSize:17];
            
            [clearCacheBtnCell.mxkButton removeTarget:self action:nil forControlEvents:UIControlEventTouchUpInside];
            [clearCacheBtnCell.mxkButton addTarget:self action:@selector(clearCache:) forControlEvents:UIControlEventTouchUpInside];
            clearCacheBtnCell.mxkButton.accessibilityIdentifier = nil;
            
            cell = clearCacheBtnCell;
        }
        else if (row == OTHER_REPORT_BUG_INDEX)
        {
            MXKTableViewCellWithButton *reportBugBtnCell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCellWithButton defaultReuseIdentifier]];
            if (!reportBugBtnCell)
            {
                reportBugBtnCell = [[MXKTableViewCellWithButton alloc] init];
            }
            else
            {
                // Fix https://github.com/vector-im/riot-ios/issues/1354
                reportBugBtnCell.mxkButton.titleLabel.text = nil;
            }

            NSString *btnTitle = NSLocalizedStringFromTable(@"settings_report_bug", @"Vector", nil);
            [reportBugBtnCell.mxkButton setTitle:btnTitle forState:UIControlStateNormal];
            [reportBugBtnCell.mxkButton setTitle:btnTitle forState:UIControlStateHighlighted];
            [reportBugBtnCell.mxkButton setTintColor:kCaritasColorLinkBlue];
            reportBugBtnCell.mxkButton.titleLabel.font = [UIFont systemFontOfSize:17];

            [reportBugBtnCell.mxkButton removeTarget:self action:nil forControlEvents:UIControlEventTouchUpInside];
            [reportBugBtnCell.mxkButton addTarget:self action:@selector(reportBug:) forControlEvents:UIControlEventTouchUpInside];
            reportBugBtnCell.mxkButton.accessibilityIdentifier = nil;

            cell = reportBugBtnCell;
        }
    }
    else if (section == SETTINGS_SECTION_LABS_INDEX)
    {
        if (row == LABS_USE_ROOM_MEMBERS_LAZY_LOADING_INDEX)
        {
            MXKTableViewCellWithLabelAndSwitch* labelAndSwitchCell = [self getLabelAndSwitchCell:tableView forIndexPath:indexPath];

            labelAndSwitchCell.mxkLabel.text = NSLocalizedStringFromTable(@"settings_labs_room_members_lazy_loading", @"Vector", nil);

            MXKAccount* account = [MXKAccountManager sharedManager].activeAccounts.firstObject;
            labelAndSwitchCell.mxkSwitch.on = account.mxSession.syncWithLazyLoadOfRoomMembers;

            [labelAndSwitchCell.mxkSwitch addTarget:self action:@selector(toggleSyncWithLazyLoadOfRoomMembers:) forControlEvents:UIControlEventTouchUpInside];

            cell = labelAndSwitchCell;
        }
        else if (row == LABS_CRYPTO_INDEX)
        {
            MXSession* session = [[AppDelegate theDelegate].mxSessions objectAtIndex:0];

            MXKTableViewCellWithLabelAndSwitch* labelAndSwitchCell = [self getLabelAndSwitchCell:tableView forIndexPath:indexPath];

            labelAndSwitchCell.mxkLabel.text = NSLocalizedStringFromTable(@"settings_labs_e2e_encryption", @"Vector", nil);
            labelAndSwitchCell.mxkSwitch.on = (nil != session.crypto);

            [labelAndSwitchCell.mxkSwitch addTarget:self action:@selector(toggleLabsEndToEndEncryption:) forControlEvents:UIControlEventTouchUpInside];

            if (session.crypto)
            {
                // Once crypto is enabled, it is enabled
                labelAndSwitchCell.mxkSwitch.enabled = NO;
            }

            cell = labelAndSwitchCell;
        }
    }
    else if (section == SETTINGS_SECTION_DEVICES_INDEX)
    {
        MXKTableViewCell *deviceCell = [self getDefaultTableViewCell:tableView];
        
        if (row < devicesArray.count)
        {
            NSString *name = devicesArray[row].displayName;
            NSString *deviceId = devicesArray[row].deviceId;
            deviceCell.textLabel.text = (name.length ? [NSString stringWithFormat:@"%@ (%@)", name, deviceId] : [NSString stringWithFormat:@"(%@)", deviceId]);
            deviceCell.textLabel.numberOfLines = 0;
            
            if ([deviceId isEqualToString:self.mainSession.matrixRestClient.credentials.deviceId])
            {
                deviceCell.textLabel.font = [UIFont boldSystemFontOfSize:17];
            }
        }
        
        cell = deviceCell;
    }
    else if (section == SETTINGS_SECTION_CRYPTOGRAPHY_INDEX)
    {
        if (row == CRYPTOGRAPHY_INFO_INDEX)
        {
            MXKTableViewCellWithTextView *cryptoCell = [self textViewCellForTableView:tableView atIndexPath:indexPath];
            
            cryptoCell.mxkTextView.attributedText = [self cryptographyInformation];

            cell = cryptoCell;
        }
        else if (row == CRYPTOGRAPHY_BLACKLIST_UNVERIFIED_DEVICES_INDEX)
        {
            MXKTableViewCellWithLabelAndSwitch* labelAndSwitchCell = [self getLabelAndSwitchCell:tableView forIndexPath:indexPath];

            labelAndSwitchCell.mxkLabel.text = NSLocalizedStringFromTable(@"settings_crypto_blacklist_unverified_devices", @"Vector", nil);
            labelAndSwitchCell.mxkSwitch.on = account.mxSession.crypto.globalBlacklistUnverifiedDevices;
            labelAndSwitchCell.mxkSwitch.enabled = YES;
            [labelAndSwitchCell.mxkSwitch addTarget:self action:@selector(toggleBlacklistUnverifiedDevices:) forControlEvents:UIControlEventTouchUpInside];

            cell = labelAndSwitchCell;
        }
        else if (row == CRYPTOGRAPHY_EXPORT_INDEX)
        {
            MXKTableViewCellWithButton *exportKeysBtnCell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCellWithButton defaultReuseIdentifier]];
            if (!exportKeysBtnCell)
            {
                exportKeysBtnCell = [[MXKTableViewCellWithButton alloc] init];
            }
            else
            {
                // Fix https://github.com/vector-im/riot-ios/issues/1354
                exportKeysBtnCell.mxkButton.titleLabel.text = nil;
            }

            NSString *btnTitle = NSLocalizedStringFromTable(@"settings_crypto_export", @"Vector", nil);
            [exportKeysBtnCell.mxkButton setTitle:btnTitle forState:UIControlStateNormal];
            [exportKeysBtnCell.mxkButton setTitle:btnTitle forState:UIControlStateHighlighted];
            [exportKeysBtnCell.mxkButton setTintColor:kCaritasColorLinkBlue];
            exportKeysBtnCell.mxkButton.titleLabel.font = [UIFont systemFontOfSize:17];

            [exportKeysBtnCell.mxkButton removeTarget:self action:nil forControlEvents:UIControlEventTouchUpInside];
            [exportKeysBtnCell.mxkButton addTarget:self action:@selector(exportEncryptionKeys:) forControlEvents:UIControlEventTouchUpInside];
            exportKeysBtnCell.mxkButton.accessibilityIdentifier = nil;

            cell = exportKeysBtnCell;
        }
    }
    else if (section == SETTINGS_SECTION_DEACTIVATE_ACCOUNT_INDEX)
    {
        MXKTableViewCellWithButton *deactivateAccountBtnCell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCellWithButton defaultReuseIdentifier]];
        
        if (!deactivateAccountBtnCell)
        {
            deactivateAccountBtnCell = [[MXKTableViewCellWithButton alloc] init];
        }
        else
        {
            // Fix https://github.com/vector-im/riot-ios/issues/1354
            deactivateAccountBtnCell.mxkButton.titleLabel.text = nil;
        }
        
        NSString *btnTitle = NSLocalizedStringFromTable(@"settings_deactivate_my_account", @"Vector", nil);
        [deactivateAccountBtnCell.mxkButton setTitle:btnTitle forState:UIControlStateNormal];
        [deactivateAccountBtnCell.mxkButton setTitle:btnTitle forState:UIControlStateHighlighted];
        [deactivateAccountBtnCell.mxkButton setTintColor:kCaritasColorRed];
        deactivateAccountBtnCell.mxkButton.titleLabel.font = [UIFont systemFontOfSize:17];
        
        [deactivateAccountBtnCell.mxkButton removeTarget:self action:nil forControlEvents:UIControlEventTouchUpInside];
        [deactivateAccountBtnCell.mxkButton addTarget:self action:@selector(deactivateAccountAction) forControlEvents:UIControlEventTouchUpInside];
        deactivateAccountBtnCell.mxkButton.accessibilityIdentifier = nil;
        
        cell = deactivateAccountBtnCell;
    }

    return cell;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == SETTINGS_SECTION_USER_SETTINGS_INDEX)
    {
        return NSLocalizedStringFromTable(@"settings_user_settings", @"Vector", nil);
    }
    else if (section == SETTINGS_SECTION_NOTIFICATIONS_SETTINGS_INDEX)
    {
        return NSLocalizedStringFromTable(@"settings_notifications_settings", @"Vector", nil);
    }
    else if (section == SETTINGS_SECTION_USER_INTERFACE_INDEX)
    {
        return NSLocalizedStringFromTable(@"settings_user_interface", @"Vector", nil);
    }
    else if (section == SETTINGS_SECTION_IGNORED_USERS_INDEX)
    {
        // Check whether this section is visible
        if ([AppDelegate theDelegate].mxSessions.count > 0)
        {
            MXSession* session = [[AppDelegate theDelegate].mxSessions objectAtIndex:0];
            if (session.ignoredUsers.count)
            {
                return NSLocalizedStringFromTable(@"settings_ignored_users", @"Vector", nil);
            }
        }
    }
    else if (section == SETTINGS_SECTION_OTHER_INDEX)
    {
        return NSLocalizedStringFromTable(@"settings_other", @"Vector", nil);
    }
    else if (section == SETTINGS_SECTION_LABS_INDEX)
    {
        return NSLocalizedStringFromTable(@"settings_labs", @"Vector", nil);
    }
    else if (section == SETTINGS_SECTION_DEVICES_INDEX)
    {
        // Check whether this section is visible
        if (devicesArray.count > 0)
        {
            return NSLocalizedStringFromTable(@"settings_devices", @"Vector", nil);
        }
    }
    else if (section == SETTINGS_SECTION_CRYPTOGRAPHY_INDEX)
    {
        // Check whether this section is visible
        if (self.mainSession.crypto)
        {
            return NSLocalizedStringFromTable(@"settings_cryptography", @"Vector", nil);
        }
    }
    else if (section == SETTINGS_SECTION_CRYPTOGRAPHY_INDEX)
    {
        // Check whether this section is visible
        if (self.mainSession.crypto)
        {
            return NSLocalizedStringFromTable(@"settings_cryptography", @"Vector", nil);
        }
    }
    else if (section == SETTINGS_SECTION_DEACTIVATE_ACCOUNT_INDEX)
    {
        return NSLocalizedStringFromTable(@"settings_deactivate_my_account", @"Vector", nil);
    }
    
    return nil;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
    if ([view isKindOfClass:UITableViewHeaderFooterView.class])
    {
        // Customize label style
        UITableViewHeaderFooterView *tableViewHeaderFooterView = (UITableViewHeaderFooterView*)view;
        tableViewHeaderFooterView.textLabel.textColor = kCaritasPrimaryTextColor;
        tableViewHeaderFooterView.textLabel.font = [UIFont systemFontOfSize:15];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

- (void)tableView:(UITableView*)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath*)indexPath
{
    // iOS8 requires this method to enable editing (see editActionsForRowAtIndexPath).
}

#pragma mark - UITableView delegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;
{
    cell.backgroundColor = kCaritasPrimaryBgColor;
    
    if (cell.selectionStyle != UITableViewCellSelectionStyleNone)
    {        
        // Update the selected background view
        if (kCaritasSelectedBgColor)
        {
            cell.selectedBackgroundView = [[UIView alloc] init];
            cell.selectedBackgroundView.backgroundColor = kCaritasSelectedBgColor;
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
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == SETTINGS_SECTION_IGNORED_USERS_INDEX)
    {
        if ([AppDelegate theDelegate].mxSessions.count > 0)
        {
            MXSession* session = [[AppDelegate theDelegate].mxSessions objectAtIndex:0];
            if (session.ignoredUsers.count == 0)
            {
                // Hide this section
                return SECTION_TITLE_PADDING_WHEN_HIDDEN;
            }
        }
    }
    
    return 24;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if (section == SETTINGS_SECTION_IGNORED_USERS_INDEX)
    {
        if ([AppDelegate theDelegate].mxSessions.count > 0)
        {
            MXSession* session = [[AppDelegate theDelegate].mxSessions objectAtIndex:0];
            if (session.ignoredUsers.count == 0)
            {
                // Hide this section
                return SECTION_TITLE_PADDING_WHEN_HIDDEN;
            }
        }
    }
    
    return 24;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.tableView == tableView)
    {
        NSInteger section = indexPath.section;
        NSInteger row = indexPath.row;

        if (section == SETTINGS_SECTION_USER_INTERFACE_INDEX)
        {
            if (row == USER_INTERFACE_LANGUAGE_INDEX)
            {
                [self showLanguagePicker];
            }
            else if (row == USER_INTERFACE_THEME_INDEX)
            {
                [self showThemePicker];
            }
        }
        else if (section == SETTINGS_SECTION_IGNORED_USERS_INDEX)
        {
            MXSession* session = [[AppDelegate theDelegate].mxSessions objectAtIndex:0];

            NSString *ignoredUserId;
            if (indexPath.row < session.ignoredUsers.count)
            {
                ignoredUserId = session.ignoredUsers[indexPath.row];
            }

            if (ignoredUserId)
            {
                [currentAlert dismissViewControllerAnimated:NO completion:nil];

                __weak typeof(self) weakSelf = self;
                
                currentAlert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:NSLocalizedStringFromTable(@"settings_unignore_user", @"Vector", nil), ignoredUserId] message:nil preferredStyle:UIAlertControllerStyleAlert];

                [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"yes"]
                                                                 style:UIAlertActionStyleDefault
                                                               handler:^(UIAlertAction * action) {
                                                                   
                                                                   if (weakSelf)
                                                                   {
                                                                       typeof(self) self = weakSelf;
                                                                       self->currentAlert = nil;
                                                                       
                                                                       MXSession* session = [[AppDelegate theDelegate].mxSessions objectAtIndex:0];
                                                                       
                                                                       // Remove the member from the ignored user list
                                                                       [self startActivityIndicator];
                                                                       [session unIgnoreUsers:@[ignoredUserId] success:^{
                                                                           
                                                                           [self stopActivityIndicator];
                                                                           
                                                                       } failure:^(NSError *error) {
                                                                           
                                                                           [self stopActivityIndicator];
                                                                           
                                                                           NSLog(@"[SettingsViewController] Unignore %@ failed", ignoredUserId);
                                                                           
                                                                           NSString *myUserId = session.myUser.userId;
                                                                           [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error userInfo:myUserId ? @{kMXKErrorUserIdKey: myUserId} : nil];
                                                                           
                                                                       }];
                                                                   }
                                                                   
                                                               }]];
                
                [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"no"]
                                                                 style:UIAlertActionStyleDefault
                                                               handler:^(UIAlertAction * action) {
                                                                   
                                                                   if (weakSelf)
                                                                   {
                                                                       typeof(self) self = weakSelf;
                                                                       self->currentAlert = nil;
                                                                   }
                                                                   
                                                               }]];
                
                [currentAlert mxk_setAccessibilityIdentifier: @"SettingsVCUnignoreAlert"];
                [self presentViewController:currentAlert animated:YES completion:nil];
            }
        }
        else if (section == SETTINGS_SECTION_OTHER_INDEX)
        {
            if (row == OTHER_COPYRIGHT_INDEX)
            {
                WebViewViewController *webViewViewController = [[WebViewViewController alloc] initWithURL:NSLocalizedStringFromTable(@"settings_copyright_url", @"Vector", nil)];
                
                webViewViewController.title = NSLocalizedStringFromTable(@"settings_copyright", @"Vector", nil);
                
                [self pushViewController:webViewViewController];
            }
            else if (row == OTHER_TERM_CONDITIONS_INDEX)
            {
                WebViewViewController *webViewViewController = [[WebViewViewController alloc] initWithURL:NSLocalizedStringFromTable(@"settings_term_conditions_url", @"Vector", nil)];
                
                webViewViewController.title = NSLocalizedStringFromTable(@"settings_term_conditions", @"Vector", nil);
                
                [self pushViewController:webViewViewController];
            }
            else if (row == OTHER_PRIVACY_INDEX)
            {
                WebViewViewController *webViewViewController = [[WebViewViewController alloc] initWithURL:NSLocalizedStringFromTable(@"settings_privacy_policy_url", @"Vector", nil)];
                
                webViewViewController.title = NSLocalizedStringFromTable(@"settings_privacy_policy", @"Vector", nil);
                
                [self pushViewController:webViewViewController];
            }
            else if (row == OTHER_THIRD_PARTY_INDEX)
            {
                NSString *htmlFile = [[NSBundle mainBundle] pathForResource:@"third_party_licenses" ofType:@"html" inDirectory:nil];

                WebViewViewController *webViewViewController = [[WebViewViewController alloc] initWithLocalHTMLFile:htmlFile];
                
                webViewViewController.title = NSLocalizedStringFromTable(@"settings_third_party_notices", @"Vector", nil);
                
                [self pushViewController:webViewViewController];
            }
        }
        else if (section == SETTINGS_SECTION_USER_SETTINGS_INDEX)
        {
            if (row == userSettingsProfilePictureIndex)
            {
                [self onProfileAvatarTap:nil];
            }
            else if (row == userSettingsChangePasswordIndex)
            {
                [self displayPasswordAlert];
            }
        }
        else if (section == SETTINGS_SECTION_DEVICES_INDEX)
        {
            if (row < devicesArray.count)
            {
                [self showDeviceDetails:devicesArray[row]];
            }
        }
        
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

#pragma mark - actions


- (void)onSignout:(id)sender
{
    // Feedback: disable button and run activity indicator
    UIButton *button = (UIButton*)sender;
    button.enabled = NO;
    [self startActivityIndicator];
    
     __weak typeof(self) weakSelf = self;
    
    [[AppDelegate theDelegate] logoutWithConfirmation:YES completion:^(BOOL isLoggedOut) {
        
        if (!isLoggedOut && weakSelf)
        {
            typeof(self) self = weakSelf;
            
            // Enable the button and stop activity indicator
            button.enabled = YES;
            [self stopActivityIndicator];
        }
    }];
}

- (void)toggleSendCrashReport:(id)sender
{
    BOOL enable = RiotSettings.shared.enableCrashReport;
    if (enable)
    {
        NSLog(@"[SettingsViewController] disable automatic crash report and analytics sending");
        
        RiotSettings.shared.enableCrashReport = NO;
        
        [[Analytics sharedInstance] stop];
        
        // Remove potential crash file.
        [MXLogger deleteCrashLog];
    }
    else
    {
        NSLog(@"[SettingsViewController] enable automatic crash report and analytics sending");
        
        RiotSettings.shared.enableCrashReport = YES;
        
        [[Analytics sharedInstance] start];
    }
}

- (void)toggleEnableRageShake:(id)sender
{
    if (sender && [sender isKindOfClass:UISwitch.class])
    {
        UISwitch *switchButton = (UISwitch*)sender;

        RiotSettings.shared.enableRageShake = switchButton.isOn;

        [self.tableView reloadData];
    }
}

- (void)toggleSyncWithLazyLoadOfRoomMembers:(id)sender
{
    if (sender && [sender isKindOfClass:UISwitch.class])
    {
        UISwitch *switchButton = (UISwitch*)sender;

        if (!switchButton.isOn)
        {
            // Disable LL and reload
            [MXKAppSettings standardAppSettings].syncWithLazyLoadOfRoomMembers = NO;
            [self launchClearCache];
        }
        else
        {
            switchButton.enabled = NO;
            [self startActivityIndicator];

            // Check the user homeserver supports lazy-loading
            MXKAccount* account = [MXKAccountManager sharedManager].activeAccounts.firstObject;

            MXWeakify(self);
            [account supportLazyLoadOfRoomMembers:^(BOOL supportLazyLoadOfRoomMembers) {
                MXStrongifyAndReturnIfNil(self);

                if (supportLazyLoadOfRoomMembers)
                {
                    // Lazy-loading is fully supported, enable it
                    [MXKAppSettings standardAppSettings].syncWithLazyLoadOfRoomMembers = YES;
                    [self launchClearCache];
                }
                else
                {
                    [switchButton setOn:NO animated:YES];
                    switchButton.enabled = YES;
                    [self stopActivityIndicator];

                    // No support of lazy-loading, do not engage it and warn the user
                    [self->currentAlert dismissViewControllerAnimated:NO completion:nil];

                    self->currentAlert = [UIAlertController alertControllerWithTitle:nil
                                                                             message:NSLocalizedStringFromTable(@"settings_labs_room_members_lazy_loading_error_message", @"Vector", nil)
                                                                      preferredStyle:UIAlertControllerStyleAlert];

                    MXWeakify(self);
                    [self->currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"]
                                                                           style:UIAlertActionStyleDefault
                                                                         handler:^(UIAlertAction * action) {
                                                                             MXStrongifyAndReturnIfNil(self);
                                                                             self->currentAlert = nil;
                                                                         }]];

                    [self->currentAlert mxk_setAccessibilityIdentifier: @"SettingsVCNoHSSupportOfLazyLoading"];
                    [self presentViewController:self->currentAlert animated:YES completion:nil];
                }
            }];
        }
    }
}

- (void)toggleLabsEndToEndEncryption:(id)sender
{
    if (sender && [sender isKindOfClass:UISwitch.class])
    {
        UISwitch *switchButton = (UISwitch*)sender;
        MXKAccount* account = [MXKAccountManager sharedManager].activeAccounts.firstObject;
        
        if (switchButton.isOn && !account.mxCredentials.deviceId.length)
        {
            // Prompt the user to log in again when no device id is available.
            __weak typeof(self) weakSelf = self;
            
            // Prompt user
            NSString *msg = NSLocalizedStringFromTable(@"settings_labs_e2e_encryption_prompt_message", @"Vector", nil);
            
            [currentAlert dismissViewControllerAnimated:NO completion:nil];
            
            currentAlert = [UIAlertController alertControllerWithTitle:nil message:msg preferredStyle:UIAlertControllerStyleAlert];
            
            [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"later"]
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * action) {
                                                               
                                                               if (weakSelf)
                                                               {
                                                                   typeof(self) self = weakSelf;
                                                                   self->currentAlert = nil;
                                                               }
                                                               
                                                               // Reset toggle button
                                                               [switchButton setOn:NO animated:YES];
                                                               
                                                           }]];
            
            [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"]
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * action) {
                                                               
                                                               if (weakSelf)
                                                               {
                                                                   typeof(self) self = weakSelf;
                                                                   self->currentAlert = nil;
                                                                   
                                                                   switchButton.enabled = NO;
                                                                   [self startActivityIndicator];
                                                                   
                                                                   dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                                                                       
                                                                       [[AppDelegate theDelegate] logoutWithConfirmation:NO completion:nil];
                                                                       
                                                                   });
                                                               }
                                                               
                                                           }]];
            
            [currentAlert mxk_setAccessibilityIdentifier:@"SettingsVCEnableEncryptionAlert"];
            [self presentViewController:currentAlert animated:YES completion:nil];
        }
        else
        {
            [self startActivityIndicator];
            
            MXSession* session = [[AppDelegate theDelegate].mxSessions objectAtIndex:0];
            [session enableCrypto:switchButton.isOn success:^{

                // When disabling crypto, reset the current device id as it cannot be reused.
                // This means that the user will need to log in again if he wants to re-enable e2e.
                if (!switchButton.isOn)
                {
                    [account resetDeviceId];
                }
                
                // Reload all data source of encrypted rooms
                MXKRoomDataSourceManager *roomDataSourceManager = [MXKRoomDataSourceManager sharedManagerForMatrixSession:session];
                
                for (MXRoom *room in session.rooms)
                {
                    if (room.summary.isEncrypted)
                    {
                        [roomDataSourceManager roomDataSourceForRoom:room.roomId create:NO onComplete:^(MXKRoomDataSource *roomDataSource) {
                            [roomDataSource reload];
                        }];
                    }
                }
                
                // Once crypto is enabled, it is enabled
                switchButton.enabled = NO;
                
                [self stopActivityIndicator];
                
                // Refresh table view to add cryptography information.
                [self.tableView reloadData];
                
            } failure:^(NSError *error) {
                
                [self stopActivityIndicator];
                
                // Come back to previous state button
                [switchButton setOn:!switchButton.isOn animated:YES];
            }];
        }
    }
}

- (void)toggleBlacklistUnverifiedDevices:(id)sender
{
    UISwitch *switchButton = (UISwitch*)sender;

    MXKAccount* account = [MXKAccountManager sharedManager].activeAccounts.firstObject;
    account.mxSession.crypto.globalBlacklistUnverifiedDevices = switchButton.on;

    [self.tableView reloadData];
}

- (void)togglePinRoomsWithMissedNotif:(id)sender
{
    UISwitch *switchButton = (UISwitch*)sender;
    
    RiotSettings.shared.pinRoomsWithMissedNotificationsOnHome = switchButton.on;
}

- (void)togglePinRoomsWithUnread:(id)sender
{
    UISwitch *switchButton = (UISwitch*)sender;

    RiotSettings.shared.pinRoomsWithUnreadMessagesOnHome = switchButton.on;
}

- (void)markAllAsRead:(id)sender
{
    // Feedback: disable button and run activity indicator
    UIButton *button = (UIButton*)sender;
    button.enabled = NO;
    [self startActivityIndicator];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        [[AppDelegate theDelegate] markAllMessagesAsRead];
        
        [self stopActivityIndicator];
        button.enabled = YES;
        
    });
}

- (void)clearCache:(id)sender
{
    // Feedback: disable button and run activity indicator
    UIButton *button = (UIButton*)sender;
    button.enabled = NO;

    [self launchClearCache];
}

- (void)launchClearCache
{
    [self startActivityIndicator];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{

        [[AppDelegate theDelegate] reloadMatrixSessions:YES];

    });
}

- (void)reportBug:(id)sender
{
    BugReportViewController *bugReportViewController = [BugReportViewController bugReportViewController];
    [bugReportViewController showInViewController:self];
}

//- (void)onRuleUpdate:(id)sender
//{
//    MXPushRule* pushRule = nil;
//    MXSession* session = [[AppDelegate theDelegate].mxSessions objectAtIndex:0];
//    
//    NSInteger row = ((UIView*)sender).tag;
//    
//    if (row == NOTIFICATION_SETTINGS_CONTAINING_MY_DISPLAY_NAME_INDEX)
//    {
//        pushRule = [session.notificationCenter ruleById:kMXNotificationCenterContainDisplayNameRuleID];
//    }
//    else if (row == NOTIFICATION_SETTINGS_CONTAINING_MY_USER_NAME_INDEX)
//    {
//        pushRule = [session.notificationCenter ruleById:kMXNotificationCenterContainUserNameRuleID];
//    }
//    else if (row == NOTIFICATION_SETTINGS_SENT_TO_ME_INDEX)
//    {
//        pushRule = [session.notificationCenter ruleById:kMXNotificationCenterOneToOneRoomRuleID];
//    }
//    else if (row == NOTIFICATION_SETTINGS_INVITED_TO_ROOM_INDEX)
//    {
//        pushRule = [session.notificationCenter ruleById:kMXNotificationCenterInviteMeRuleID];
//    }
//    else if (row == NOTIFICATION_SETTINGS_PEOPLE_LEAVE_JOIN_INDEX)
//    {
//        pushRule = [session.notificationCenter ruleById:kMXNotificationCenterMemberEventRuleID];
//    }
//    else if (row == NOTIFICATION_SETTINGS_CALL_INVITATION_INDEX)
//    {
//        pushRule = [session.notificationCenter ruleById:kMXNotificationCenterCallRuleID];
//    }
//    
//    if (pushRule)
//    {
//        // toggle the rule
//        [session.notificationCenter enableRule:pushRule isEnabled:!pushRule.enabled];
//    }
//}


- (void)onSave:(id)sender
{
    // sanity check
    if ([MXKAccountManager sharedManager].activeAccounts.count == 0)
    {
        return;
    }
    
    [AppDelegate theDelegate].masterTabBarController.navigationItem.rightBarButtonItem.enabled = NO;
    [self startActivityIndicator];
    isSavingInProgress = YES;
    __weak typeof(self) weakSelf = self;
    
    MXKAccount* account = [MXKAccountManager sharedManager].activeAccounts.firstObject;
    MXMyUser* myUser = account.mxSession.myUser;
    
    if (newDisplayName && ![myUser.displayname isEqualToString:newDisplayName])
    {
        // Save display name
        [account setUserDisplayName:newDisplayName success:^{
            
            if (weakSelf)
            {
                // Update the current displayname
                typeof(self) self = weakSelf;
                self->newDisplayName = nil;
                
                // Go to the next change saving step
                [self onSave:nil];
            }
            
        } failure:^(NSError *error) {
            
            NSLog(@"[SettingsViewController] Failed to set displayName");
            
            if (weakSelf)
            {
                typeof(self) self = weakSelf;
                [self handleErrorDuringProfileChangeSaving:error];
            }
            
        }];
        
        return;
    }
    
    if (newAvatarImage)
    {
        // Retrieve the current picture and make sure its orientation is up
        UIImage *updatedPicture = [MXKTools forceImageOrientationUp:newAvatarImage];
        
        // Upload picture
        MXMediaLoader *uploader = [MXMediaManager prepareUploaderWithMatrixSession:account.mxSession initialRange:0 andRange:1.0];
        
        [uploader uploadData:UIImageJPEGRepresentation(updatedPicture, 0.5) filename:nil mimeType:@"image/jpeg" success:^(NSString *url) {
            
            if (weakSelf)
            {
                typeof(self) self = weakSelf;
                
                // Store uploaded picture url and trigger picture saving
                self->uploadedAvatarURL = url;
                self->newAvatarImage = nil;
                [self onSave:nil];
            }
            
            
        } failure:^(NSError *error) {
            
            NSLog(@"[SettingsViewController] Failed to upload image");
            
            if (weakSelf)
            {
                typeof(self) self = weakSelf;
                [self handleErrorDuringProfileChangeSaving:error];
            }
            
        }];
        
        return;
    }
    else if (uploadedAvatarURL)
    {
        [account setUserAvatarUrl:uploadedAvatarURL
                          success:^{
                              
                              if (weakSelf)
                              {
                                  typeof(self) self = weakSelf;
                                  self->uploadedAvatarURL = nil;
                                  [self onSave:nil];
                              }
                              
                          }
                          failure:^(NSError *error) {
                              
                              NSLog(@"[SettingsViewController] Failed to set avatar url");
                              
                              if (weakSelf)
                              {
                                  typeof(self) self = weakSelf;
                                  [self handleErrorDuringProfileChangeSaving:error];
                              }
                              
                          }];
        
        return;
    }
    
    // Backup is complete
    isSavingInProgress = NO;
    [self stopActivityIndicator];
    
    // Check whether destroy has been called durign saving
    if (onReadyToDestroyHandler)
    {
        // Ready to destroy
        onReadyToDestroyHandler();
        onReadyToDestroyHandler = nil;
    }
    else
    {
        [self.tableView reloadData];
    }
}

- (void)handleErrorDuringProfileChangeSaving:(NSError*)error
{
    // Sanity check: retrieve the current root view controller
    UIViewController *rootViewController = [AppDelegate theDelegate].window.rootViewController;
    if (rootViewController)
    {
        __weak typeof(self) weakSelf = self;
        
        // Alert user
        NSString *title = [error.userInfo valueForKey:NSLocalizedFailureReasonErrorKey];
        if (!title)
        {
            title = [NSBundle mxk_localizedStringForKey:@"settings_fail_to_update_profile"];
        }
        NSString *msg = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
        
        [currentAlert dismissViewControllerAnimated:NO completion:nil];
        
        currentAlert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
        
        [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"abort"]
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * action) {
                                                           
                                                           if (weakSelf)
                                                           {
                                                               typeof(self) self = weakSelf;
                                                               
                                                               self->currentAlert = nil;
                                                               
                                                               // Reset the updated displayname
                                                               self->newDisplayName = nil;
                                                               
                                                               // Discard picture change
                                                               self->uploadedAvatarURL = nil;
                                                               self->newAvatarImage = nil;
                                                               
                                                               // Loop to end saving
                                                               [self onSave:nil];
                                                           }
                                                           
                                                       }]];
        
        [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"retry"]
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * action) {
                                                           
                                                           if (weakSelf)
                                                           {
                                                               typeof(self) self = weakSelf;
                                                               
                                                               self->currentAlert = nil;
                                                               
                                                               // Loop to retry saving
                                                               [self onSave:nil];
                                                           }
                                                           
                                                       }]];
        
        [currentAlert mxk_setAccessibilityIdentifier: @"SettingsVCSaveChangesFailedAlert"];
        [rootViewController presentViewController:currentAlert animated:YES completion:nil];
    }
}

- (void)updateSaveButtonStatus
{
    if ([AppDelegate theDelegate].mxSessions.count > 0)
    {
        MXSession* session = [[AppDelegate theDelegate].mxSessions objectAtIndex:0];
        MXMyUser* myUser = session.myUser;
        
        BOOL saveButtonEnabled = (nil != newAvatarImage);
        
        if (!saveButtonEnabled)
        {
            if (newDisplayName)
            {
                saveButtonEnabled = ![myUser.displayname isEqualToString:newDisplayName];
            }
        }
        
        [AppDelegate theDelegate].masterTabBarController.navigationItem.rightBarButtonItem.enabled = saveButtonEnabled;
    }
}

- (void)onProfileAvatarTap:(UITapGestureRecognizer *)recognizer
{
    mediaPicker = [MediaPickerViewController mediaPickerViewController];
    mediaPicker.mediaTypes = @[(NSString *)kUTTypeImage];
    mediaPicker.delegate = self;
    UINavigationController *navigationController = [UINavigationController new];
    [navigationController pushViewController:mediaPicker animated:NO];
    
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)exportEncryptionKeys:(UITapGestureRecognizer *)recognizer
{
    [currentAlert dismissViewControllerAnimated:NO completion:nil];

    exportView = [[MXKEncryptionKeysExportView alloc] initWithMatrixSession:self.mainSession];
    currentAlert = exportView.alertController;

    // Use a temporary file for the export
    keyExportsFile = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"riot-keys.txt"]];

    // Make sure the file is empty
    [self deleteKeyExportFile];

    // Show the export dialog
    __weak typeof(self) weakSelf = self;
    [exportView showInViewController:self toExportKeysToFile:keyExportsFile onComplete:^(BOOL success) {

        if (weakSelf)
        {
             typeof(self) self = weakSelf;
            self->currentAlert = nil;
            self->exportView = nil;

            if (success)
            {
                // Let another app handling this file
                self->documentInteractionController = [UIDocumentInteractionController interactionControllerWithURL:keyExportsFile];
                [self->documentInteractionController setDelegate:self];

                if ([self->documentInteractionController presentOptionsMenuFromRect:self.view.bounds inView:self.view animated:YES])
                {
                    // We want to delete the temp keys file after it has been processed by the other app.
                    // We use [UIDocumentInteractionControllerDelegate didEndSendingToApplication] for that
                    // but it is not reliable for all cases (see http://stackoverflow.com/a/21867096).
                    // So, arm a timer to auto delete the file after 10mins.
                    keyExportsFileDeletionTimer = [NSTimer scheduledTimerWithTimeInterval:600 target:self selector:@selector(deleteKeyExportFile) userInfo:self repeats:NO];
                }
                else
                {
                    self->documentInteractionController = nil;
                    [self deleteKeyExportFile];
                }
            }
        }
    }];
}

- (void)deleteKeyExportFile
{
    // Cancel the deletion timer if it is still here
    if (keyExportsFileDeletionTimer)
    {
        [keyExportsFileDeletionTimer invalidate];
        keyExportsFileDeletionTimer = nil;
    }

    // And delete the file
    if (keyExportsFile && [[NSFileManager defaultManager] fileExistsAtPath:keyExportsFile.path])
    {
        [[NSFileManager defaultManager] removeItemAtPath:keyExportsFile.path error:nil];
    }
}

- (void)showLanguagePicker
{
    __weak typeof(self) weakSelf = self;
    
    // Screen tracking
    [[Analytics sharedInstance] trackScreen:@"LanguagePicker"];
    
    UIAlertController *languagePicker = [UIAlertController alertControllerWithTitle:[NSBundle mxk_localizedStringForKey:@"language_picker_title"]
                                                                         message:nil
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];
    
    // Start by the default language chosen by the OS
    __block NSString *defaultLanguage = [MXKLanguagePickerViewController defaultLanguage];
    NSString *languageDescription = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"language_picker_default_language"], [MXKLanguagePickerViewController languageDescription:defaultLanguage]];
    
    UIAlertAction *defaultLanguageAction = [UIAlertAction actionWithTitle:languageDescription style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action)
    {
        if (weakSelf)
        {
            typeof(self) self = weakSelf;
            
            [self didSelectLangugage:defaultLanguage];
        }
    }];
    
    [languagePicker addAction:defaultLanguageAction];
    
    // Then, add languages available in the app bundle
    NSArray<NSString *> *localizations = [[NSBundle mainBundle] localizations];
    for (NSString *language in localizations)
    {
        // Do not duplicate the default lang
        if (![language isEqualToString:defaultLanguage])
        {
            languageDescription = [MXKLanguagePickerViewController languageDescription:language];
            NSString *localisedLanguageDescription = [MXKLanguagePickerViewController languageLocalisedDescription:language];
            
            // Capitalise the description in the language locale
            NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:language];
            languageDescription = [languageDescription capitalizedStringWithLocale:locale];
            localisedLanguageDescription = [localisedLanguageDescription capitalizedStringWithLocale:locale];
            
            if (languageDescription)
            {
                UIAlertAction *languageAction = [UIAlertAction actionWithTitle:languageDescription style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action)
                {
                    if (weakSelf)
                    {
                        typeof(self) self = weakSelf;
                        
                        [self didSelectLangugage:language];
                    }
                }];
                
                [languagePicker addAction:languageAction];
            }
        }
    }
    
    // Cancel button
    [languagePicker addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"]
                                                    style:UIAlertActionStyleCancel
                                                  handler:nil]];
    
    UIView *fromCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:USER_INTERFACE_LANGUAGE_INDEX inSection:SETTINGS_SECTION_USER_INTERFACE_INDEX]];
    [languagePicker popoverPresentationController].sourceView = fromCell;
    [languagePicker popoverPresentationController].sourceRect = fromCell.bounds;
    
    [self presentViewController:languagePicker animated:YES completion:nil];
}

- (void)showThemePicker
{
    __weak typeof(self) weakSelf = self;

    __block UIAlertAction *autoAction, *caritasAction, *darkAction;
    NSString *themePickerMessage;

    void (^actionBlock)(UIAlertAction *action) = ^(UIAlertAction * action) {

        if (weakSelf)
        {
            typeof(self) self = weakSelf;

            NSString *newTheme;
            if (action == autoAction)
            {
                newTheme = @"auto";
            }
            if (action == darkAction)
            {
                newTheme = @"dark";
            }
            else if (action == caritasAction)
            {
                newTheme = @"caritas";
            }

            NSString *theme = RiotSettings.shared.userInterfaceTheme;
            if (newTheme && ![newTheme isEqualToString:theme])
            {
                // Clear fake Riot Avatars based on the previous theme.
                [AvatarGenerator clear];

                // The user wants to select this theme
                RiotSettings.shared.userInterfaceTheme = newTheme;

                [self.tableView reloadData];
            }
        }
    };

    if (@available(iOS 11.0, *))
    {
        // Show "auto" only from iOS 11
        autoAction = [UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"settings_ui_theme_auto", @"Vector", nil)
                                              style:UIAlertActionStyleDefault
                                            handler:actionBlock];

        // Explain what is "auto"
        themePickerMessage = NSLocalizedStringFromTable(@"settings_ui_theme_picker_message", @"Vector", nil);
    }
    
    darkAction = [UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"settings_ui_theme_dark", @"Vector", nil)
                                             style:UIAlertActionStyleDefault
                                           handler:actionBlock];
    
    caritasAction = [UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"settings_ui_theme_caritas", @"Vector", nil)
                                             style:UIAlertActionStyleDefault
                                           handler:actionBlock];


    UIAlertController *themePicker = [UIAlertController alertControllerWithTitle:NSLocalizedStringFromTable(@"settings_ui_theme_picker_title", @"Vector", nil)
                                                                         message:themePickerMessage
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];

    if (autoAction)
    {
        [themePicker addAction:autoAction];
    }
    [themePicker addAction:caritasAction];
    [themePicker addAction:darkAction];

    // Cancel button
    [themePicker addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"]
                                                        style:UIAlertActionStyleCancel
                                                      handler:nil]];

    UIView *fromCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:USER_INTERFACE_THEME_INDEX inSection:SETTINGS_SECTION_USER_INTERFACE_INDEX]];
    [themePicker popoverPresentationController].sourceView = fromCell;
    [themePicker popoverPresentationController].sourceRect = fromCell.bounds;

    [self presentViewController:themePicker animated:YES completion:nil];
}

- (void)deactivateAccountAction
{
    DeactivateAccountViewController *deactivateAccountViewController = [DeactivateAccountViewController instantiateWithMatrixSession:self.mainSession];
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:deactivateAccountViewController];
    navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    
    [self presentViewController:navigationController animated:YES completion:nil];
    
    deactivateAccountViewController.delegate = self;
    
    self.deactivateAccountViewController = deactivateAccountViewController;
}

#pragma mark - MediaPickerViewController Delegate

- (void)dismissMediaPicker
{
    if (mediaPicker)
    {
        [mediaPicker withdrawViewControllerAnimated:YES completion:nil];
        mediaPicker = nil;
    }
}

- (void)mediaPickerController:(MediaPickerViewController *)mediaPickerController didSelectImage:(NSData*)imageData withMimeType:(NSString *)mimetype isPhotoLibraryAsset:(BOOL)isPhotoLibraryAsset
{
    [self dismissMediaPicker];
    
    newAvatarImage = [UIImage imageWithData:imageData];
    
    [self.tableView reloadData];
}

- (void)mediaPickerController:(MediaPickerViewController *)mediaPickerController didSelectVideo:(NSURL*)videoURL
{
    // this method should not be called
    [self dismissMediaPicker];
}

#pragma mark - TextField listener

- (IBAction)textFieldDidChange:(id)sender
{
    UITextField* textField = (UITextField*)sender;
    
    if (textField.tag == userSettingsDisplayNameIndex)
    {
        // Remove white space from both ends
        newDisplayName = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        [self updateSaveButtonStatus];
    }
}

#pragma mark - UITextField delegate

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    if (textField.tag == userSettingsDisplayNameIndex)
    {
        textField.textAlignment = NSTextAlignmentLeft;
    }
}
- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (textField.tag == userSettingsDisplayNameIndex)
    {
        textField.textAlignment = NSTextAlignmentRight;
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField.tag == userSettingsDisplayNameIndex)
    {
        [textField resignFirstResponder];
    }
    
    return YES;
}

#pragma password update management

- (IBAction)passwordTextFieldDidChange:(id)sender
{
    savePasswordAction.enabled = (currentPasswordTextField.text.length > 0) && (newPasswordTextField1.text.length > 2) && [newPasswordTextField1.text isEqualToString:newPasswordTextField2.text];
}

- (void)displayPasswordAlert
{
    __weak typeof(self) weakSelf = self;
    [resetPwdAlertController dismissViewControllerAnimated:NO completion:nil];
    
    resetPwdAlertController = [UIAlertController alertControllerWithTitle:NSLocalizedStringFromTable(@"settings_change_password", @"Vector", nil) message:nil preferredStyle:UIAlertControllerStyleAlert];
    resetPwdAlertController.accessibilityLabel=@"ChangePasswordAlertController";
    savePasswordAction = [UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"save", @"Vector", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        
        if (weakSelf)
        {
            typeof(self) self = weakSelf;
            
            self->resetPwdAlertController = nil;
            
            if ([MXKAccountManager sharedManager].activeAccounts.count > 0)
            {
                [self startActivityIndicator];
                self->isResetPwdInProgress = YES;
                
                MXKAccount* account = [MXKAccountManager sharedManager].activeAccounts.firstObject;
                
                [account changePassword:currentPasswordTextField.text with:newPasswordTextField1.text success:^{
                    
                    if (weakSelf)
                    {
                        typeof(self) self = weakSelf;
                        
                        self->isResetPwdInProgress = NO;
                        [self stopActivityIndicator];
                        
                        // Display a successful message only if the settings screen is still visible (destroy is not called yet)
                        if (!self->onReadyToDestroyHandler)
                        {
                            [self->currentAlert dismissViewControllerAnimated:NO completion:nil];
                            
                            self->currentAlert = [UIAlertController alertControllerWithTitle:nil message:NSLocalizedStringFromTable(@"settings_password_updated", @"Vector", nil) preferredStyle:UIAlertControllerStyleAlert];
                            
                            [self->currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"]
                                                                                   style:UIAlertActionStyleDefault
                                                                                 handler:^(UIAlertAction * action) {
                                                                                     
                                                                                     if (weakSelf)
                                                                                     {
                                                                                         typeof(self) self = weakSelf;
                                                                                         self->currentAlert = nil;
                                                                                         
                                                                                         // Check whether destroy has been called durign pwd change
                                                                                         if (self->onReadyToDestroyHandler)
                                                                                         {
                                                                                             // Ready to destroy
                                                                                             self->onReadyToDestroyHandler();
                                                                                             self->onReadyToDestroyHandler = nil;
                                                                                         }
                                                                                     }
                                                                                     
                                                                                 }]];
                            
                            [self->currentAlert mxk_setAccessibilityIdentifier:@"SettingsVCOnPasswordUpdatedAlert"];
                            [self presentViewController:self->currentAlert animated:YES completion:nil];
                        }
                        else
                        {
                            // Ready to destroy
                            self->onReadyToDestroyHandler();
                            self->onReadyToDestroyHandler = nil;
                        }
                    }
                    
                } failure:^(NSError *error) {
                    
                    if (weakSelf)
                    {
                        typeof(self) self = weakSelf;
                        
                        self->isResetPwdInProgress = NO;
                        [self stopActivityIndicator];
                        
                        // Display a failure message on the current screen
                        UIViewController *rootViewController = [AppDelegate theDelegate].window.rootViewController;
                        if (rootViewController)
                        {
                            [self->currentAlert dismissViewControllerAnimated:NO completion:nil];
                            
                            self->currentAlert = [UIAlertController alertControllerWithTitle:nil message:NSLocalizedStringFromTable(@"settings_fail_to_update_password", @"Vector", nil) preferredStyle:UIAlertControllerStyleAlert];
                            
                            [self->currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"]
                                                                                   style:UIAlertActionStyleDefault
                                                                                 handler:^(UIAlertAction * action) {
                                                                                     
                                                                                     if (weakSelf)
                                                                                     {
                                                                                         typeof(self) self = weakSelf;
                                                                                         
                                                                                         self->currentAlert = nil;
                                                                                         
                                                                                         // Check whether destroy has been called durign pwd change
                                                                                         if (self->onReadyToDestroyHandler)
                                                                                         {
                                                                                             // Ready to destroy
                                                                                             self->onReadyToDestroyHandler();
                                                                                             self->onReadyToDestroyHandler = nil;
                                                                                         }
                                                                                     }
                                                                                     
                                                                                 }]];
                            
                            [self->currentAlert mxk_setAccessibilityIdentifier:@"SettingsVCPasswordChangeFailedAlert"];
                            [rootViewController presentViewController:self->currentAlert animated:YES completion:nil];
                        }
                    }
                    
                }];
            }
        }
        
    }];
    
    // disable by default
    // check if the textfields have the right value
    savePasswordAction.enabled = NO;
    
    UIAlertAction* cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        
        if (weakSelf)
        {
            typeof(self) self = weakSelf;
            
            self->resetPwdAlertController = nil;
        }
        
    }];
    
    [resetPwdAlertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        
        if (weakSelf)
        {
            typeof(self) self = weakSelf;
            
            self->currentPasswordTextField = textField;
            self->currentPasswordTextField.placeholder = NSLocalizedStringFromTable(@"settings_old_password", @"Vector", nil);
            self->currentPasswordTextField.secureTextEntry = YES;
            [self->currentPasswordTextField addTarget:self action:@selector(passwordTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        }
         
     }];
    
    [resetPwdAlertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        
        if (weakSelf)
        {
            typeof(self) self = weakSelf;
            
            self->newPasswordTextField1 = textField;
            self->newPasswordTextField1.placeholder = NSLocalizedStringFromTable(@"settings_new_password", @"Vector", nil);
            self->newPasswordTextField1.secureTextEntry = YES;
            [self->newPasswordTextField1 addTarget:self action:@selector(passwordTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        }
        
    }];
    
    [resetPwdAlertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        
        if (weakSelf)
        {
            typeof(self) self = weakSelf;
            
            self->newPasswordTextField2 = textField;
            self->newPasswordTextField2.placeholder = NSLocalizedStringFromTable(@"settings_confirm_password", @"Vector", nil);
            self->newPasswordTextField2.secureTextEntry = YES;
            [self->newPasswordTextField2 addTarget:self action:@selector(passwordTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        }
    }];

    
    [resetPwdAlertController addAction:cancel];
    [resetPwdAlertController addAction:savePasswordAction];
    [self presentViewController:resetPwdAlertController animated:YES completion:nil];
}

#pragma mark - UIDocumentInteractionControllerDelegate

- (void)documentInteractionController:(UIDocumentInteractionController *)controller didEndSendingToApplication:(NSString *)application
{
    // If iOS wants to call this method, this is the right time to remove the file
    [self deleteKeyExportFile];
}

- (void)documentInteractionControllerDidDismissOptionsMenu:(UIDocumentInteractionController *)controller
{
    documentInteractionController = nil;
}

- (void)didSelectLangugage:(NSString *)language
{
    if (![language isEqualToString:[NSBundle mxk_language]]
        || (language == nil && [NSBundle mxk_language]))
    {
        [NSBundle mxk_setLanguage:language];

        // Store user settings
        NSUserDefaults *sharedUserDefaults = [MXKAppSettings standardAppSettings].sharedUserDefaults;
        [sharedUserDefaults setObject:language forKey:@"appLanguage"];

        // Do a reload in order to recompute strings in the new language
        // Note that "reloadMatrixSessions:NO" will reset room summaries
        [self startActivityIndicator];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{

            [[AppDelegate theDelegate] reloadMatrixSessions:NO];
        });
    }
}

#pragma mark - DeactivateAccountViewControllerDelegate

- (void)deactivateAccountViewControllerDidDeactivateWithSuccess:(DeactivateAccountViewController *)deactivateAccountViewController
{
    NSLog(@"[SettingsViewController] Deactivate account with success");

    
    [[AppDelegate theDelegate] logoutSendingRequestServer:NO completion:^(BOOL isLoggedOut) {
        NSLog(@"[SettingsViewController] Complete clear user data after account deactivation");
    }];
}

- (void)deactivateAccountViewControllerDidCancel:(DeactivateAccountViewController *)deactivateAccountViewController
{
    [deactivateAccountViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
