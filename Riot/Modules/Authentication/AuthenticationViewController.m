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
#import "Riot-Swift.h"

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
     Observe kThemeServiceDidChangeThemeNotification to handle user interface theme change.
     */
    id kThemeServiceDidChangeThemeNotificationObserver;
    
    /**
     Last used AuthInputClass. Used to show correct login when cancelling registration
     */
    Class lastUsedAuthInputClass;
    
    /**
     Custom homeserver so we can restore when coming back from regsitration
     */
    NSString *customHomeServer;
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
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    self.mainNavigationItem.title = nil;
    self.rightBarButtonItem.title = [defaults boolForKey:@"enableRegistration"] ? NSLocalizedStringFromTable(@"auth_register", @"Vector", nil) : nil;
    
    self.defaultHomeServerUrl = [defaults stringForKey:@"homeserverurl"];
    self.defaultIdentityServerUrl = [defaults stringForKey:@"identityserverurl"];
    
    self.welcomeImageView.image = [UIImage imageNamed:@"Logo"];
    
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
    
    self.homeServerTextField.placeholder = NSLocalizedStringFromTable(@"auth_home_server_placeholder", @"Vector", nil);
    self.homeServerLabel.text = NSLocalizedStringFromTable(@"auth_home_server_label", @"Vector", nil);
    // Show homeserver textfield if enabled
    self.homeServerContainer.hidden = ![defaults boolForKey:@"enableCustomHomeserver"];
    
    // The view controller dismiss itself on successful login.
    self.delegate = self;
    
    // Initialize the auth inputs display
    
    // Show QR Reader if enabled
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"enableQRCodeLogin"])
    {
        [self showQRAuthInput];
        
        // Show alternative login
        self.alternativeLoginButton.hidden = NO;
        [self.alternativeLoginButton.layer setCornerRadius:5];
        self.alternativeLoginButton.clipsToBounds = YES;
        
        self.alternativeLoginButton.backgroundColor = ThemeService.shared.theme.baseColor;
        [self.alternativeLoginButton setTitleColor:ThemeService.shared.theme.baseTextPrimaryColor forState:UIControlStateNormal];
        
        [self.alternativeLoginButton setTitle:NSLocalizedStringFromTable(@"auth_alternative_login", @"Vector", nil) forState:UIControlStateNormal];
        [self.alternativeLoginButton setTitle:NSLocalizedStringFromTable(@"auth_alternative_login", @"Vector", nil) forState:UIControlStateHighlighted];
    }
    else
    {
        [self showRegularAuthInput];
    }

    // Observe user interface theme change.
    kThemeServiceDidChangeThemeNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kThemeServiceDidChangeThemeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        [self userInterfaceThemeDidChange];
        
    }];
    [self userInterfaceThemeDidChange];
}

- (void)userInterfaceThemeDidChange
{
    [ThemeService.shared.theme applyStyleOnNavigationBar:self.navigationBar];
    self.navigationBarSeparatorView.backgroundColor = ThemeService.shared.theme.lineBreakColor;

    // This view controller is not part of a navigation controller
    // so that applyStyleOnNavigationBar does not fully work.
    // In order to have the right status bar color, use the expected status bar color
    // as the main view background color.
    // Hopefully, subviews define their own background color with `theme.backgroundColor`,
    // which makes all work together.
    self.view.backgroundColor = self.navigationBar.barTintColor;

    self.authenticationScrollView.backgroundColor = ThemeService.shared.theme.backgroundColor;

    // Style the authentication fallback webview screen so that its header matches to navigation bar style
    self.authFallbackContentView.backgroundColor = ThemeService.shared.theme.baseColor;
    self.cancelAuthFallbackButton.tintColor = ThemeService.shared.theme.baseTextPrimaryColor;

    if (self.homeServerTextField.placeholder)
    {
        self.homeServerTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                          initWithString:self.homeServerTextField.placeholder
                                                          attributes:@{NSForegroundColorAttributeName: ThemeService.shared.theme.placeholderTextColor}];
    }
    if (self.identityServerTextField.placeholder)
    {
        self.identityServerTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                              initWithString:self.identityServerTextField.placeholder
                                                              attributes:@{NSForegroundColorAttributeName: ThemeService.shared.theme.placeholderTextColor}];
    }
    
    self.submitButton.backgroundColor = ThemeService.shared.theme.baseColor;
    self.skipButton.backgroundColor = ThemeService.shared.theme.baseColor;
    
    [self.submitButton setTitleColor:ThemeService.shared.theme.baseTextPrimaryColor forState:UIControlStateNormal];
    [self.skipButton setTitleColor:ThemeService.shared.theme.baseTextPrimaryColor forState:UIControlStateNormal];
    
    self.homeServerTextField.textColor = ThemeService.shared.theme.textPrimaryColor;
    
    self.noFlowLabel.textColor = ThemeService.shared.theme.warningColor;
    
    self.activityIndicator.backgroundColor = ThemeService.shared.theme.overlayBackgroundColor;
    
    [self.authInputsView customizeViewRendering];
    
    [self setNeedsStatusBarAppearanceUpdate];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return ThemeService.shared.theme.statusBarStyle;
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

- (void)onFoundLoginParametersWithUsername:(NSString *)username password:(NSString *)password homeServerUrl:(NSString *)homeServerUrl
{
    NSLog(@"[AuthenticationVC] onFoundLoginParameters: QR Reader found login parameters");
    
    if ([self.authInputsView isKindOfClass:QRReaderView.class])
    {
        [self setHomeServerTextFieldText:homeServerUrl];
        [super onButtonPressed:self.submitButton];
    }
}

- (void)destroy
{
    [super destroy];
    
    if (kThemeServiceDidChangeThemeNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:kThemeServiceDidChangeThemeNotificationObserver];
        kThemeServiceDidChangeThemeNotificationObserver = nil;
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
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if (authType == MXKAuthenticationTypeLogin)
    {
        [self.submitButton setTitle:NSLocalizedStringFromTable(@"auth_login", @"Vector", nil) forState:UIControlStateNormal];
        [self.submitButton setTitle:NSLocalizedStringFromTable(@"auth_login", @"Vector", nil) forState:UIControlStateHighlighted];
        
        if ([defaults boolForKey:@"enableCustomHomeserver"] && customHomeServer != nil)
        {
            [self setHomeServerTextFieldText:customHomeServer];
            customHomeServer = nil;
            self.homeServerTextField.enabled = YES;
        }
    }
    else if (authType == MXKAuthenticationTypeRegister)
    {
        [self.submitButton setTitle:NSLocalizedStringFromTable(@"auth_register", @"Vector", nil) forState:UIControlStateNormal];
        [self.submitButton setTitle:NSLocalizedStringFromTable(@"auth_register", @"Vector", nil) forState:UIControlStateHighlighted];
        
        if ([defaults boolForKey:@"enableCustomHomeserver"] && customHomeServer == nil)
        {
            customHomeServer = self.homeServerTextField.text;
        }
        [self setHomeServerTextFieldText:self.defaultHomeServerUrl];
        self.homeServerTextField.enabled = NO;
        [self.homeServerTextField resignFirstResponder];
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
    [super setAuthInputsView:authInputsView];
    
    [self updateButtonVisibility];
    
    // Restore here the actual content view height.
    // Indeed this height has been modified according to the authInputsView height in the default implementation of MXKAuthenticationViewController.
    [self refreshContentViewHeightConstraint];
}

- (void)setUserInteractionEnabled:(BOOL)userInteractionEnabled
{
    super.userInteractionEnabled = userInteractionEnabled;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
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
        AuthInputsView *authInputsview;
        if ([self.authInputsView isKindOfClass:AuthInputsView.class])
        {
            authInputsview = (AuthInputsView*)self.authInputsView;
        }

        // The right bar button is used to switch the authentication type.
        if (self.authType == MXKAuthenticationTypeLogin && [defaults boolForKey:@"enableRegistration"])
        {
            self.rightBarButtonItem.title = NSLocalizedStringFromTable(@"auth_register", @"Vector", nil);
        }
        else if (self.authType == MXKAuthenticationTypeRegister)
        {
            self.rightBarButtonItem.title = NSLocalizedStringFromTable(@"auth_login", @"Vector", nil);
            
            // Restore the back button
            if (authInputsview)
            {
                [self updateRegistrationScreenWithThirdPartyIdentifiersHidden:authInputsview.thirdPartyIdentifiersHidden];
            }
        }
        else if (self.authType == MXKAuthenticationTypeForgotPassword)
        {
            // The right bar button is used to return to login.
            self.rightBarButtonItem.title = NSLocalizedStringFromTable(@"cancel", @"Vector", nil);
        }
        else
        {
            self.rightBarButtonItem.title = nil;
        }
    }
}

- (void)handleAuthenticationSession:(MXAuthenticationSession *)authSession
{
    [super handleAuthenticationSession:authSession];
    
    [self updateButtonVisibility];
}

- (void)updateButtonVisibility
{
    AuthInputsView *authInputsview;
    if ([self.authInputsView isKindOfClass:AuthInputsView.class])
    {
        authInputsview = (AuthInputsView*)self.authInputsView;
    }
    
    self.submitButton.hidden = authInputsview.isSingleSignOnRequired || [self.authInputsView isKindOfClass:QRReaderView.class];
}

- (void)showRegistrationRequestAuthInput
{
    RegistrationRequestViewController *requestView = [[RegistrationRequestViewController alloc] init];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:requestView];
    [[ThemeService shared].theme applyStyleOnNavigationBar:navController.navigationBar];
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)showQRAuthInput
{
    QRReaderView *qrView = [QRReaderView fromNib];
    qrView.qrReaderDelegate = self;
    qrView.delegate = self;
    MXAuthenticationSession *authSession = [MXAuthenticationSession modelFromJSON:@{@"flows":@[@{@"stages":@[kMXLoginFlowTypePassword]}]}];
    [qrView setAuthSession:authSession withAuthType:MXKAuthenticationTypeLogin];
    self.authInputsView = qrView;
    
    // Custom used authInputsView
    [self registerAuthInputsViewClass:QRReaderView.class forAuthType:MXKAuthenticationTypeLogin];
    
    // Hide homeserver textfield
    self.homeServerContainer.hidden = YES;
}

- (void)showRegularAuthInput
{
    if ([self.authInputsView isKindOfClass:QRReaderView.class])
    {
        QRReaderView *qrView = (QRReaderView *)self.authInputsView;
        [qrView willHide];
    }
    
    AuthInputsView *regularAuthInputsView = [AuthInputsView authInputsView];
    MXAuthenticationSession *authSession = [MXAuthenticationSession modelFromJSON:@{@"flows":@[@{@"stages":@[kMXLoginFlowTypePassword]}]}];
    [regularAuthInputsView setAuthSession:authSession withAuthType:MXKAuthenticationTypeLogin];
    regularAuthInputsView.delegate = self;
    
    // Listen to action within the child view
    [regularAuthInputsView.ssoButton addTarget:self action:@selector(onButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    
    // Custom used authInputsView
    [self registerAuthInputsViewClass:AuthInputsView.class forAuthType:MXKAuthenticationTypeLogin];
    [self registerAuthInputsViewClass:AuthInputsView.class forAuthType:MXKAuthenticationTypeRegister];
    
    self.authInputsView = regularAuthInputsView;
    
    // Show homeserver textfield when showing login
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:@"enableCustomHomeserver"]) {
        self.homeServerContainer.hidden = NO;
    }
}

- (IBAction)onAlternativeLoginPressed:(id)sender
{
    if ([self.authInputsView isKindOfClass:QRReaderView.class])
    {
        [self showRegularAuthInput];
    }
    else
    {
        [self showQRAuthInput];
    }
}

- (IBAction)onButtonPressed:(id)sender
{
    if (sender == self.rightBarButtonItem)
    {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        // Check whether a request is in progress
        if (!self.userInteractionEnabled)
        {
            // Cancel the current operation
            [self cancel];
        }
        else if (self.authType == MXKAuthenticationTypeLogin && [defaults boolForKey:@"enableRegistration"])
        {
            if ([defaults boolForKey:@"registrationAsRequest"])
            {
                [self showRegistrationRequestAuthInput];
            }
            else
            {
                lastUsedAuthInputClass = self.authInputsView.class;
                [self showRegularAuthInput];
                
                self.authType = MXKAuthenticationTypeRegister;
                self.rightBarButtonItem.title = NSLocalizedStringFromTable(@"auth_login", @"Vector", nil);
                self.homeServerContainer.hidden = YES;
            }
        }
        else if ([defaults boolForKey:@"enableRegistration"])
        {
            self.authType = MXKAuthenticationTypeLogin;
            self.rightBarButtonItem.title = NSLocalizedStringFromTable(@"auth_register", @"Vector", nil);
            
            if ([lastUsedAuthInputClass isEqual:QRReaderView.class])
            {
                [self showQRAuthInput];
            } else {
                self.homeServerContainer.hidden = NO;
            }
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
        // Check if the provided username for login contains the homeserver and use that instead of the default one
        if (self.authType == MXKAuthenticationTypeLogin)
        {
            AuthInputsView *authInputsview = (AuthInputsView*)self.authInputsView;
            if ([MXTools isMatrixUserIdentifier:authInputsview.userId])
            {
                NSString *homeserver = [[authInputsview.userId componentsSeparatedByString:@":"] objectAtIndex:1];
                NSString *homeserverWithProtocol = [NSString stringWithFormat:@"https://%@", homeserver];
                [self setHomeServerTextFieldText:homeserverWithProtocol];
            }
        }
        
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
    else if (sender == ((AuthInputsView*)self.authInputsView).ssoButton)
    {
        // Do SSO using the fallback URL
        [self showAuthenticationFallBackView];

        [ThemeService.shared.theme applyStyleOnNavigationBar:self.navigationController.navigationBar];
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
    
    if ([self.authInputsView isKindOfClass:QRReaderView.class])
    {
        QRReaderView *qrView = (QRReaderView *)self.authInputsView;
        [qrView loginFailed];
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
    
    if ([self.authInputsView isKindOfClass:QRReaderView.class]) {
        QRReaderView *qrView = (QRReaderView *)self.authInputsView;
        [qrView loginSuccessful];
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
        [self.submitButton setTitle:NSLocalizedStringFromTable(@"auth_register", @"Vector", nil) forState:UIControlStateNormal];
        [self.submitButton setTitle:NSLocalizedStringFromTable(@"auth_register", @"Vector", nil) forState:UIControlStateHighlighted];
        
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
    CGFloat constant = self.optionsContainer.frame.origin.y + self.homeServerContainer.frame.size.height + 100;
    
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
