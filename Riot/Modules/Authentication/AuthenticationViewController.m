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

#import "AuthenticationViewController.h"

#import "AppDelegate.h"

#import "AuthInputsView.h"

@interface AuthenticationViewController ()
{
    /**
     Store the potential login error received by using a default homeserver different from matrix.org
     while we retry a login process against the matrix.org HS.
     */
    NSError *loginError;
    
    /**
     The default country code used to initialize the mobile phone number input.
     */
    NSString *defaultCountryCode;
    
    /**
     Observe kRiotDesignValuesDidChangeThemeNotification to handle user interface theme change.
     */
    id kRiotDesignValuesDidChangeThemeNotificationObserver;
}

@end

@implementation AuthenticationViewController

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass(self)
                          bundle:[NSBundle bundleForClass:self]];
}

+ (instancetype)authenticationViewController
{
    return [[[self class] alloc] initWithNibName:NSStringFromClass(self)
                                          bundle:[NSBundle bundleForClass:self]];
}

#pragma mark -

- (void)finalizeInit
{
    [super finalizeInit];
    
    // Setup `MXKViewControllerHandling` properties
    self.enableBarTintColorStatusChange = NO;
    self.rageShakeManager = [RageShakeManager sharedManager];
    
    // Set a default country code
    // Note: this value is used only when no MCC and no local country code is available.
    defaultCountryCode = @"GB";
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.mainNavigationItem.title = nil;
    self.rightBarButtonItem.title = nil;
    
    self.defaultHomeServerUrl = @"https://caritas.amp.care";
    self.defaultIdentityServerUrl = @"https://caritas.amp.care";
    
    self.welcomeImageView.image = [UIImage imageNamed:@"Caritas_Logo"];
    
    [self.submitButton.layer setCornerRadius:5];
    self.submitButton.clipsToBounds = YES;
    [self.submitButton setTitle:NSLocalizedStringFromTable(@"auth_login", @"Vector", nil) forState:UIControlStateNormal];
    [self.submitButton setTitle:NSLocalizedStringFromTable(@"auth_login", @"Vector", nil) forState:UIControlStateHighlighted];
    self.submitButton.enabled = YES;
    
    [self.skipButton.layer setCornerRadius:5];
    self.skipButton.clipsToBounds = YES;
    [self.skipButton setTitle:NSLocalizedStringFromTable(@"auth_skip", @"Vector", nil) forState:UIControlStateNormal];
    [self.skipButton setTitle:NSLocalizedStringFromTable(@"auth_skip", @"Vector", nil) forState:UIControlStateHighlighted];
    self.skipButton.enabled = YES;
    
    // The view controller dismiss itself on successful login.
    self.delegate = self;
    
    // Custom used authInputsView
    [self registerAuthInputsViewClass:AuthInputsView.class forAuthType:MXKAuthenticationTypeLogin];
    [self registerAuthInputsViewClass:AuthInputsView.class forAuthType:MXKAuthenticationTypeRegister];
    
    // Initialize the auth inputs display
    AuthInputsView *authInputsView = [AuthInputsView authInputsView];
    MXAuthenticationSession *authSession = [MXAuthenticationSession modelFromJSON:@{@"flows":@[@{@"stages":@[kMXLoginFlowTypePassword]}]}];
    [authInputsView setAuthSession:authSession withAuthType:MXKAuthenticationTypeLogin];
    self.authInputsView = authInputsView;
    
    // Observe user interface theme change.
    kRiotDesignValuesDidChangeThemeNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kRiotDesignValuesDidChangeThemeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        [self userInterfaceThemeDidChange];
        
    }];
    [self userInterfaceThemeDidChange];
}

- (void)userInterfaceThemeDidChange
{
    self.view.backgroundColor = kCaritasSecondaryBgColor;
    
    self.navigationBar.barTintColor = kCaritasSecondaryBgColor;
    self.authenticationScrollView.backgroundColor = kCaritasPrimaryBgColor;
    self.authFallbackContentView.backgroundColor = kCaritasPrimaryBgColor;
    
    self.submitButton.backgroundColor = kCaritasColorRed;
    self.skipButton.backgroundColor = kCaritasColorRed;
    
    self.noFlowLabel.textColor = kCaritasColorRed;
    
    self.defaultBarTintColor = kCaritasNavigationBarBgColor;
    self.barTitleColor = kCaritasColorWhite;
    self.activityIndicator.backgroundColor = kCaritasOverlayColor;
    
    [self.authInputsView customizeViewRendering];
    
    [self setNeedsStatusBarAppearanceUpdate];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return kCaritasDesignStatusBarStyle;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // Screen tracking
    [[Analytics sharedInstance] trackScreen:@"Authentication"];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    // Verify that the app does not show the authentification screean whereas
    // the user has already logged in.
    // This bug rarely happens (https://github.com/vector-im/riot-ios/issues/1643)
    // but it invites the user to log in again. They will then lose all their
    // e2e messages.
    NSLog(@"[AuthenticationVC] viewDidAppear: Checking false logout");
    [[MXKAccountManager sharedManager] forceReloadAccounts];
    if ([MXKAccountManager sharedManager].activeAccounts.count)
    {
        // For now, we do not have better solution than forcing the user to restart the app
        [NSException raise:@"False logout. Kill the app" format:@"AuthenticationViewController has been displayed whereas there is an existing account"];
    }
}

- (void)destroy
{
    [super destroy];
    
    if (kRiotDesignValuesDidChangeThemeNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:kRiotDesignValuesDidChangeThemeNotificationObserver];
        kRiotDesignValuesDidChangeThemeNotificationObserver = nil;
    }
}

- (void)setAuthType:(MXKAuthenticationType)authType
{
    if (self.authType == MXKAuthenticationTypeRegister)
    {
        // Restore the default registration screen
        [self updateRegistrationScreenWithThirdPartyIdentifiersHidden:YES];
    }
    
    super.authType = authType;
    
    if (authType == MXKAuthenticationTypeLogin)
    {
        [self.submitButton setTitle:NSLocalizedStringFromTable(@"auth_login", @"Vector", nil) forState:UIControlStateNormal];
        [self.submitButton setTitle:NSLocalizedStringFromTable(@"auth_login", @"Vector", nil) forState:UIControlStateHighlighted];
    }
    else if (authType == MXKAuthenticationTypeForgotPassword)
    {
        if (isPasswordReseted)
        {
            [self.submitButton setTitle:NSLocalizedStringFromTable(@"auth_return_to_login", @"Vector", nil) forState:UIControlStateNormal];
            [self.submitButton setTitle:NSLocalizedStringFromTable(@"auth_return_to_login", @"Vector", nil) forState:UIControlStateHighlighted];
        }
        else
        {
            [self.submitButton setTitle:NSLocalizedStringFromTable(@"auth_send_reset_email", @"Vector", nil) forState:UIControlStateNormal];
            [self.submitButton setTitle:NSLocalizedStringFromTable(@"auth_send_reset_email", @"Vector", nil) forState:UIControlStateHighlighted];
        }
    }
}

- (void)setAuthInputsView:(MXKAuthInputsView *)authInputsView
{
    // Finalize the new auth inputs view
    if ([authInputsView isKindOfClass:AuthInputsView.class])
    {
        AuthInputsView *authInputsview = (AuthInputsView*)authInputsView;
        
        authInputsview.delegate = self;
    }
    
    [super setAuthInputsView:authInputsView];
    
    // Restore here the actual content view height.
    // Indeed this height has been modified according to the authInputsView height in the default implementation of MXKAuthenticationViewController.
    [self refreshContentViewHeightConstraint];
}

- (void)setUserInteractionEnabled:(BOOL)userInteractionEnabled
{
    super.userInteractionEnabled = userInteractionEnabled;
    
    // Show/Hide server options
    if (_optionsContainer.hidden == userInteractionEnabled)
    {
        _optionsContainer.hidden = !userInteractionEnabled;
        
        [self refreshContentViewHeightConstraint];
    }
    
    // Update the label of the right bar button according to its actual action.
    if (!userInteractionEnabled)
    {
        // The right bar button is used to cancel the running request.
        self.rightBarButtonItem.title = NSLocalizedStringFromTable(@"cancel", @"Vector", nil);

        // Remove the potential back button.
        self.mainNavigationItem.leftBarButtonItem = nil;
    }
    else
    {
        // The right bar button is used to switch the authentication type.
        if (self.authType == MXKAuthenticationTypeLogin)
        {
            self.rightBarButtonItem.title = nil;
        }
        else if (self.authType == MXKAuthenticationTypeForgotPassword)
        {
            // The right bar button is used to return to login.
            self.rightBarButtonItem.title = NSLocalizedStringFromTable(@"cancel", @"Vector", nil);
        }
    }
}

- (IBAction)onButtonPressed:(id)sender
{
    if (sender == self.rightBarButtonItem)
    {
        // Check whether a request is in progress
        if (!self.userInteractionEnabled)
        {
            // Cancel the current operation
            [self cancel];
        }
        else
        {
            self.authType = MXKAuthenticationTypeLogin;
        }
    }
    else if (sender == self.mainNavigationItem.leftBarButtonItem)
    {
        if ([self.authInputsView isKindOfClass:AuthInputsView.class])
        {
            AuthInputsView *authInputsview = (AuthInputsView*)self.authInputsView;
            
            // Hide the supported 3rd party ids which may be added to the account
            authInputsview.thirdPartyIdentifiersHidden = YES;
            
            [self updateRegistrationScreenWithThirdPartyIdentifiersHidden:YES];
        }
    }
    else if (sender == self.submitButton)
    {
        // Handle here the second screen used to manage the 3rd party ids during the registration.
        // Except if there is an external set of parameters defined to perform a registration.
        if (self.authType == MXKAuthenticationTypeRegister && !self.externalRegistrationParameters)
        {
            // Sanity check
            if ([self.authInputsView isKindOfClass:AuthInputsView.class])
            {
                AuthInputsView *authInputsview = (AuthInputsView*)self.authInputsView;
                
                // Show the 3rd party ids screen if it is not shown yet
                if (authInputsview.areThirdPartyIdentifiersSupported && authInputsview.isThirdPartyIdentifiersHidden)
                {
                    [self dismissKeyboard];
                    
                    [self.authenticationActivityIndicator startAnimating];
                    
                    // Check parameters validity
                    NSString *errorMsg = [self.authInputsView validateParameters];
                    if (errorMsg)
                    {
                        [self onFailureDuringAuthRequest:[NSError errorWithDomain:MXKAuthErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:errorMsg}]];
                    }
                    else
                    {
                        [self testUserRegistration:^(MXError *mxError) {
                            // We consider that a user can be registered if:
                            //   - the username is not already in use
                            if ([mxError.errcode isEqualToString:kMXErrCodeStringUserInUse])
                            {
                                NSLog(@"[AuthenticationVC] User name is already use");
                                [self onFailureDuringAuthRequest:[NSError errorWithDomain:MXKAuthErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:[NSBundle mxk_localizedStringForKey:@"auth_username_in_use"]}]];
                            }
                            //   - the server quota limits is not reached
                            else if ([mxError.errcode isEqualToString:kMXErrCodeStringResourceLimitExceeded])
                            {
                                [self showResourceLimitExceededError:mxError.userInfo];
                            }
                            else
                            {
                                [self.authenticationActivityIndicator stopAnimating];

                                // Show the supported 3rd party ids which may be added to the account
                                authInputsview.thirdPartyIdentifiersHidden = NO;

                                [self updateRegistrationScreenWithThirdPartyIdentifiersHidden:NO];
                            }
                        }];
                    }
                    
                    return;
                }
            }
        }
        
        [super onButtonPressed:sender];
    }
    else if (sender == self.skipButton)
    {
        // Reset the potential email or phone values
        if ([self.authInputsView isKindOfClass:AuthInputsView.class])
        {
            AuthInputsView *authInputsview = (AuthInputsView*)self.authInputsView;
            
            [authInputsview resetThirdPartyIdentifiers];
        }
        
        [super onButtonPressed:self.submitButton];
    }
    else
    {
        [super onButtonPressed:sender];
    }
}

- (void)onFailureDuringAuthRequest:(NSError *)error
{
    if (!loginError)
    {
        MXError *mxError = [[MXError alloc] initWithNSError:error];
        
        if (self.authType == MXKAuthenticationTypeLogin)
        {
            if (mxError && [mxError.errcode isEqualToString:kMXErrCodeStringForbidden])
            {
                NSLog(@"[AuthenticationVC] Retry login");
                
                // Store the current error
                loginError = error;
                
                // Trigger a new request
                [self onButtonPressed:self.submitButton];
                return;
            }
        }
    }
    
    // Check whether we were trying to login again
    if (loginError)
    {
        NSLog(@"[AuthenticationVC] Still no success");
        
        // Consider the original login error
        [super onFailureDuringAuthRequest:loginError];
        loginError = nil;
    }
    else
    {
        MXError *mxError = [[MXError alloc] initWithNSError:error];
        if ([mxError.errcode isEqualToString:kMXErrCodeStringResourceLimitExceeded])
        {
            [self showResourceLimitExceededError:mxError.userInfo];
        }
        else
        {
            [super onFailureDuringAuthRequest:error];
        }
    }
}

- (void)onSuccessfulLogin:(MXCredentials*)credentials
{
    // Check whether a third party identifiers has not been used
    if ([self.authInputsView isKindOfClass:AuthInputsView.class])
    {
        AuthInputsView *authInputsview = (AuthInputsView*)self.authInputsView;
        if (authInputsview.isThirdPartyIdentifierPending)
        {
            // Alert user
            if (alert)
            {
                [alert dismissViewControllerAnimated:NO completion:nil];
            }
            
            alert = [UIAlertController alertControllerWithTitle:NSLocalizedStringFromTable(@"warning", @"Vector", nil) message:NSLocalizedStringFromTable(@"auth_add_email_and_phone_warning", @"Vector", nil) preferredStyle:UIAlertControllerStyleAlert];
            
            [alert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"]
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * action) {
                                                               
                                                               [super onSuccessfulLogin:credentials];
                                                               
                                                           }]];
            
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }
    }
    
    [super onSuccessfulLogin:credentials];
}

#pragma mark -

- (void)updateRegistrationScreenWithThirdPartyIdentifiersHidden:(BOOL)thirdPartyIdentifiersHidden
{
    self.skipButton.hidden = thirdPartyIdentifiersHidden;
    
    [self refreshContentViewHeightConstraint];
    
    if (thirdPartyIdentifiersHidden)
    {
        
        self.mainNavigationItem.leftBarButtonItem = nil;
    }
    else
    {
        [self.submitButton setTitle:NSLocalizedStringFromTable(@"auth_submit", @"Vector", nil) forState:UIControlStateNormal];
        [self.submitButton setTitle:NSLocalizedStringFromTable(@"auth_submit", @"Vector", nil) forState:UIControlStateHighlighted];
        
        UIBarButtonItem *leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"back_icon"] style:UIBarButtonItemStylePlain target:self action:@selector(onButtonPressed:)];
        self.mainNavigationItem.leftBarButtonItem = leftBarButtonItem;
    }
}

- (void)refreshContentViewHeightConstraint
{
    // Refresh content view height by considering the options container display.
    CGFloat constant = self.optionsContainer.frame.origin.y + 100;
    
    self.contentViewHeightConstraint.constant = constant;
}

- (void)showResourceLimitExceededError:(NSDictionary *)errorDict
{
    NSLog(@"[AuthenticationVC] showResourceLimitExceededError");

    [self showResourceLimitExceededError:errorDict onAdminContactTapped:^(NSURL *adminContact) {

        if ([[UIApplication sharedApplication] canOpenURL:adminContact])
        {
            [[UIApplication sharedApplication] openURL:adminContact];
        }
        else
        {
            NSLog(@"[AuthenticationVC] adminContact(%@) cannot be opened", adminContact);
        }
    }];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    // Override here the handling of the authInputsView height change.
    if ([@"viewHeightConstraint.constant" isEqualToString:keyPath])
    {
        self.authInputContainerViewHeightConstraint.constant = self.authInputsView.viewHeightConstraint.constant;
        
        // Force to render the view
        [self.view layoutIfNeeded];
        
        // Refresh content view height by considering the updated frame of the options container.
        [self refreshContentViewHeightConstraint];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - MXKAuthenticationViewControllerDelegate

- (void)authenticationViewController:(MXKAuthenticationViewController *)authenticationViewController didLogWithUserId:(NSString *)userId
{
    // Create DM with Riot-bot on new account creation.
    if (self.authType == MXKAuthenticationTypeRegister)
    {
        MXKAccount *account = [[MXKAccountManager sharedManager] accountForUserId:userId];
        
        [account.mxSession createRoom:nil
                           visibility:kMXRoomDirectoryVisibilityPrivate
                            roomAlias:nil
                                topic:nil
                               invite:@[@"@riot-bot:matrix.org"]
                           invite3PID:nil
                             isDirect:YES
                               preset:kMXRoomPresetTrustedPrivateChat
                              success:nil
                              failure:^(NSError *error) {
                                  
                                  NSLog(@"[AuthenticationVC] Create chat with riot-bot failed");
                                  
                              }];
    }
    
    // Remove auth view controller on successful login
    if (self.navigationController)
    {
        // Pop the view controller
        [self.navigationController popViewControllerAnimated:YES];
    }
    else
    {
        // Dismiss on successful login
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - MXKAuthInputsViewDelegate

- (void)authInputsView:(MXKAuthInputsView *)authInputsView presentViewController:(UIViewController*)viewControllerToPresent animated:(BOOL)animated
{
    [self dismissKeyboard];
    [self presentViewController:viewControllerToPresent animated:animated completion:nil];
}

- (void)authInputsViewDidCancelOperation:(MXKAuthInputsView *)authInputsView
{
    [self cancel];
}

@end
