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

#import "AuthInputsView.h"

#import "ThemeService.h"
#import "Tools.h"

#import "RiotNavigationController.h"

@interface AuthInputsView ()
{
    /**
     The current email validation
     */
    MXK3PID  *submittedEmail;
    
    /**
     The set of parameters ready to use for a registration.
     */
    NSDictionary *externalRegistrationParameters;
}

/**
 The current view container displayed at last position.
 */
@property (nonatomic) UIView *currentLastContainer;

@end

@implementation AuthInputsView

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass(self)
                          bundle:[NSBundle bundleForClass:self]];
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    _thirdPartyIdentifiersHidden = YES;
    _isThirdPartyIdentifierPending = NO;
    _isSingleSignOnRequired = NO;
    
    self.userLoginTextField.placeholder = NSLocalizedStringFromTable(@"auth_user_id_placeholder", @"Vector", nil);
    self.repeatPasswordTextField.placeholder = NSLocalizedStringFromTable(@"auth_repeat_password_placeholder", @"Vector", nil);
    self.passWordTextField.placeholder = NSLocalizedStringFromTable(@"auth_password_placeholder", @"Vector", nil);

    // Apply placeholder color
    [self customizeViewRendering];
}

- (void)destroy
{
    [super destroy];
    
    submittedEmail = nil;
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    
    if (_currentLastContainer)
    {
        self.currentLastContainer = _currentLastContainer;
    }
}

#pragma mark - Override MXKView

-(void)customizeViewRendering
{
    [super customizeViewRendering];
    
    self.repeatPasswordTextField.textColor = ThemeService.shared.theme.textPrimaryColor;
    self.userLoginTextField.textColor = ThemeService.shared.theme.textPrimaryColor;
    self.passWordTextField.textColor = ThemeService.shared.theme.textPrimaryColor;
    
    self.emailTextField.textColor = ThemeService.shared.theme.textPrimaryColor;
    
    self.messageLabel.textColor = ThemeService.shared.theme.textSecondaryColor;
    self.messageLabel.numberOfLines = 0;
    
    [self.ssoButton.layer setCornerRadius:5];
    self.ssoButton.clipsToBounds = YES;
    [self.ssoButton setTitle:NSLocalizedStringFromTable(@"auth_login_single_sign_on", @"Vector", nil) forState:UIControlStateNormal];
    [self.ssoButton setTitle:NSLocalizedStringFromTable(@"auth_login_single_sign_on", @"Vector", nil) forState:UIControlStateHighlighted];
    self.ssoButton.backgroundColor = ThemeService.shared.theme.tintColor;

    if (self.userLoginTextField.placeholder)
    {
        self.userLoginTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                         initWithString:self.userLoginTextField.placeholder
                                                         attributes:@{NSForegroundColorAttributeName: ThemeService.shared.theme.placeholderTextColor}];
    }

    if (self.repeatPasswordTextField.placeholder)
    {
        self.repeatPasswordTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                              initWithString:self.repeatPasswordTextField.placeholder
                                                              attributes:@{NSForegroundColorAttributeName: ThemeService.shared.theme.placeholderTextColor}];

    }

    if (self.passWordTextField.placeholder)
    {
        self.passWordTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                        initWithString:self.passWordTextField.placeholder
                                                        attributes:@{NSForegroundColorAttributeName: ThemeService.shared.theme.placeholderTextColor}];
    }

    if (self.emailTextField.placeholder)
    {
        self.emailTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                     initWithString:self.emailTextField.placeholder
                                                     attributes:@{NSForegroundColorAttributeName: ThemeService.shared.theme.placeholderTextColor}];
    }
}

#pragma mark -

- (BOOL)setAuthSession:(MXAuthenticationSession *)authSession withAuthType:(MXKAuthenticationType)authType;
{
    if (type == MXKAuthenticationTypeLogin || type == MXKAuthenticationTypeRegister)
    {
        // Validate first the provided session
        MXAuthenticationSession *validSession = [self validateAuthenticationSession:authSession];
        
        // Cancel email validation if any
        if (submittedEmail)
        {
            [submittedEmail cancelCurrentRequest];
            submittedEmail = nil;
        }
        
        // Reset external registration parameters
        externalRegistrationParameters = nil;
        
        // Reset UI by hidding all items
        [self hideInputsContainer];
        
        if ([super setAuthSession:validSession withAuthType:authType])
        {
            if (authType == MXKAuthenticationTypeLogin)
            {
                _isSingleSignOnRequired = NO;

                if ([self isFlowSupported:kMXLoginFlowTypePassword])
                {
                    self.passWordTextField.returnKeyType = UIReturnKeyDone;
                    
                    self.userLoginTextField.placeholder = NSLocalizedStringFromTable(@"auth_user_id_placeholder", @"Vector", nil);
                    self.messageLabel.text = NSLocalizedStringFromTable(@"or", @"Vector", nil);
                    
                    self.userLoginTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                                     initWithString:self.userLoginTextField.placeholder
                                                                     attributes:@{NSForegroundColorAttributeName: ThemeService.shared.theme.placeholderTextColor}];
                    
                    self.userLoginContainer.hidden = NO;
                    self.messageLabel.hidden = YES;
                    self.passwordContainer.hidden = NO;

                    self.messageLabelTopConstraint.constant = 59;
                    self.passwordContainerTopConstraint.constant = 50;

                    self.currentLastContainer = self.passwordContainer;
                }
                else if ([self isFlowSupported:kMXLoginFlowTypeCAS]
                         || [self isFlowSupported:kMXLoginFlowTypeSSO])
                {

                    self.ssoButtonContainer.hidden = NO;
                    self.currentLastContainer = self.ssoButtonContainer;

                    _isSingleSignOnRequired = YES;
                }
            }
            else
            {
                // Update the registration inputs layout by hidding third-party ids fields.
                self.thirdPartyIdentifiersHidden = _thirdPartyIdentifiersHidden;
            }
            
            return YES;
        }
    }
    
    return NO;
}

- (NSString*)validateParameters
{
    // Consider everything is fine when external registration parameters are ready to use
    if (externalRegistrationParameters)
    {
        return nil;
    }
    
    // Check the validity of the parameters
    NSString *errorMsg = nil;
    
    // Remove whitespace in user login text field
    NSString *userLogin = self.userLoginTextField.text;
    self.userLoginTextField.text = [userLogin stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    if (type == MXKAuthenticationTypeLogin)
    {
        if ([self isFlowSupported:kMXLoginFlowTypePassword])
        {
            // Check required fields
            if (!self.userLoginTextField.text.length || !self.passWordTextField.text.length)
            {
                NSLog(@"[AuthInputsView] Invalid user/password");
                errorMsg = NSLocalizedStringFromTable(@"auth_invalid_login_param", @"Vector", nil);
            }
        }
        else
        {
            errorMsg = [NSBundle mxk_localizedStringForKey:@"not_supported_yet"];
        }
    }
    else if (type == MXKAuthenticationTypeRegister)
    {
        if (self.isThirdPartyIdentifiersHidden)
        {
            if (!self.userLoginTextField.text.length)
            {
                NSLog(@"[AuthInputsView] Invalid user name");
                errorMsg = NSLocalizedStringFromTable(@"auth_invalid_user_name", @"Vector", nil);
            }
            else if (!self.passWordTextField.text.length)
            {
                NSLog(@"[AuthInputsView] Missing Passwords");
                errorMsg = NSLocalizedStringFromTable(@"auth_missing_password", @"Vector", nil);
            }
            else if (self.passWordTextField.text.length < 6)
            {
                NSLog(@"[AuthInputsView] Invalid Passwords");
                errorMsg = NSLocalizedStringFromTable(@"auth_invalid_password", @"Vector", nil);
            }
            else if ([self.repeatPasswordTextField.text isEqualToString:self.passWordTextField.text] == NO)
            {
                NSLog(@"[AuthInputsView] Passwords don't match");
                errorMsg = NSLocalizedStringFromTable(@"auth_password_dont_match", @"Vector", nil);
            }
            else
            {
                // Check validity of the non empty user name
                NSString *user = self.userLoginTextField.text;
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^[a-z0-9.\\-_]+$" options:NSRegularExpressionCaseInsensitive error:nil];
                
                if ([regex firstMatchInString:user options:0 range:NSMakeRange(0, user.length)] == nil)
                {
                    NSLog(@"[AuthInputsView] Invalid user name");
                    errorMsg = NSLocalizedStringFromTable(@"auth_invalid_user_name", @"Vector", nil);
                }
            }
        }
        else
        {
            // Check email field
            if ([self isFlowSupported:kMXLoginFlowTypeEmailIdentity] && !self.emailTextField.text.length)
            {
                if (self.areAllThirdPartyIdentifiersRequired)
                {
                    NSLog(@"[AuthInputsView] Missing email");
                    errorMsg = NSLocalizedStringFromTable(@"auth_missing_email", @"Vector", nil);
                }
            }
            
            if (!errorMsg)
            {
                // Check email/phone validity
                if (self.emailTextField.text.length)
                {
                    // Check validity of the non empty email
                    if (![MXTools isEmailAddress:self.emailTextField.text])
                    {
                        NSLog(@"[AuthInputsView] Invalid email");
                        errorMsg = NSLocalizedStringFromTable(@"auth_invalid_email", @"Vector", nil);
                    }
                }
            }
        }
    }
    
    return errorMsg;
}

- (void)prepareParameters:(void (^)(NSDictionary *parameters, NSError *error))callback
{
    if (callback)
    {
        // Return external registration parameters if any
        if (externalRegistrationParameters)
        {
            // We trigger here a registration based on external inputs. All the required data are handled by the session id.
            NSLog(@"[AuthInputsView] prepareParameters: return external registration parameters");
            callback(externalRegistrationParameters, nil);
            
            // CAUTION: Do not reset this dictionary here, it is used later to handle this registration until the end (see [updateAuthSessionWithCompletedStages:didUpdateParameters:])
            
            return;
        }
        
        // Prepare here parameters dict by checking each required fields.
        NSDictionary *parameters = nil;
        
        // Check the validity of the parameters
        NSString *errorMsg = [self validateParameters];
        if (errorMsg)
        {
            if (inputsAlert)
            {
                [inputsAlert dismissViewControllerAnimated:NO completion:nil];
            }
            
            inputsAlert = [UIAlertController alertControllerWithTitle:[NSBundle mxk_localizedStringForKey:@"error"] message:errorMsg preferredStyle:UIAlertControllerStyleAlert];
            
            [inputsAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"]
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * action) {
                                                               
                                                               inputsAlert = nil;
                                                               
                                                           }]];
            
            [self.delegate authInputsView:self presentAlertController:inputsAlert];
        }
        else
        {
            // Handle here the supported login flow
            if (type == MXKAuthenticationTypeLogin)
            {
                if ([self isFlowSupported:kMXLoginFlowTypePassword])
                {
                    // Check whether the user login has been set.
                    NSString *user = self.userLoginTextField.text;
                    
                    if (user.length)
                    {
                        // Check whether user login is an email or a username.
                        if ([MXTools isEmailAddress:user])
                        {
                            parameters = @{
                                           @"type": kMXLoginFlowTypePassword,
                                           @"identifier": @{
                                                   @"type": kMXLoginIdentifierTypeThirdParty,
                                                   @"medium": kMX3PIDMediumEmail,
                                                   @"address": user
                                                   },
                                           @"password": self.passWordTextField.text,
                                           // Patch: add the old login api parameters for an email address (medium and address),
                                           // to keep logging in against old HS.
                                           @"medium": kMX3PIDMediumEmail,
                                           @"address": user
                                           };
                        }
                        else
                        {
                            parameters = @{
                                           @"type": kMXLoginFlowTypePassword,
                                           @"identifier": @{
                                                   @"type": kMXLoginIdentifierTypeUser,
                                                   @"user": user
                                                   },
                                           @"password": self.passWordTextField.text,
                                           // Patch: add the old login api parameters for a username (user),
                                           // to keep logging in against old HS.
                                           @"user": user
                                           };
                        }
                    }
                }
            }
            else if (type == MXKAuthenticationTypeRegister)
            {
                // Check whether an email has been set, and if it is not handled yet
                if (!self.emailContainer.isHidden && self.emailTextField.text.length && ![self isFlowCompleted:kMXLoginFlowTypeEmailIdentity])
                {
                    NSLog(@"[AuthInputsView] Prepare email identity stage");
                    
                    // Retrieve the REST client from delegate
                    MXRestClient *restClient;
                    
                    if (self.delegate && [self.delegate respondsToSelector:@selector(authInputsViewThirdPartyIdValidationRestClient:)])
                    {
                        restClient = [self.delegate authInputsViewThirdPartyIdValidationRestClient:self];
                    }
                    
                    if (restClient)
                    {
                        // Check whether a second 3pid is available
                        _isThirdPartyIdentifierPending = NO;
                        
                        // Launch email validation
                        submittedEmail = [[MXK3PID alloc] initWithMedium:kMX3PIDMediumEmail andAddress:self.emailTextField.text];
                        
                        // Create the next link that is common to all Vector.im clients
                        NSString *nextLink = [NSString stringWithFormat:@"%@/#/register?client_secret=%@&hs_url=%@&is_url=%@&session_id=%@",
                                              [Tools webAppUrl],
                                              [submittedEmail.clientSecret stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]],
                                              [restClient.homeserver stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]],
                                              [restClient.identityServer stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]],
                                              [currentSession.session stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]]];
                        
                        [submittedEmail requestValidationTokenWithMatrixRestClient:restClient
                                                              isDuringRegistration:YES
                                                                          nextLink:nextLink
                                                                           success:^
                         {
                             
                             NSURL *identServerURL = [NSURL URLWithString:restClient.identityServer];
                             NSDictionary *parameters;
                             parameters = @{
                                            @"auth": @{@"session":currentSession.session, @"threepid_creds": @{@"client_secret": submittedEmail.clientSecret, @"id_server": identServerURL.host, @"sid": submittedEmail.sid}, @"type": kMXLoginFlowTypeEmailIdentity},
                                            @"username": self.userLoginTextField.text,
                                            @"password": self.passWordTextField.text,
                                            @"bind_msisdn": @([self isFlowCompleted:kMXLoginFlowTypeMSISDN]),
                                            @"bind_email": @(YES)
                                            };
                             
                             [self hideInputsContainer];
                             
                             self.messageLabel.text = NSLocalizedStringFromTable(@"auth_email_validation_message", @"Vector", nil);
                             self.messageLabel.hidden = NO;
                             
                             callback(parameters, nil);
                             
                         }
                                                                           failure:^(NSError *error)
                         {
                             
                             NSLog(@"[AuthInputsView] Failed to request email token");
                             
                             // Ignore connection cancellation error
                             if (([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled))
                             {
                                 return;
                             }
                             
                             // Translate the potential MX error.
                             MXError *mxError = [[MXError alloc] initWithNSError:error];
                             if (mxError && ([mxError.errcode isEqualToString:kMXErrCodeStringThreePIDInUse] || [mxError.errcode isEqualToString:kMXErrCodeStringServerNotTrusted]))
                             {
                                 NSMutableDictionary *userInfo;
                                 if (error.userInfo)
                                 {
                                     userInfo = [NSMutableDictionary dictionaryWithDictionary:error.userInfo];
                                 }
                                 else
                                 {
                                     userInfo = [NSMutableDictionary dictionary];
                                 }
                                 
                                 userInfo[NSLocalizedFailureReasonErrorKey] = nil;
                                 
                                 if ([mxError.errcode isEqualToString:kMXErrCodeStringThreePIDInUse])
                                 {
                                     userInfo[NSLocalizedDescriptionKey] = NSLocalizedStringFromTable(@"auth_email_in_use", @"Vector", nil);
                                     userInfo[@"error"] = NSLocalizedStringFromTable(@"auth_email_in_use", @"Vector", nil);
                                 }
                                 else
                                 {
                                     userInfo[NSLocalizedDescriptionKey] = NSLocalizedStringFromTable(@"auth_untrusted_id_server", @"Vector", nil);
                                     userInfo[@"error"] = NSLocalizedStringFromTable(@"auth_untrusted_id_server", @"Vector", nil);
                                 }
                                 
                                 error = [NSError errorWithDomain:error.domain code:error.code userInfo:userInfo];
                             }
                             callback(nil, error);
                             
                         }];
                        
                        // Async response
                        return;
                    }
                    NSLog(@"[AuthInputsView] Authentication failed during the email identity stage");
                }
                else if ([self isFlowSupported:kMXLoginFlowTypeDummy] && ![self isFlowCompleted:kMXLoginFlowTypeDummy])
                {
                    parameters = @{
                                   @"auth": @{@"session":currentSession.session, @"type": kMXLoginFlowTypeDummy},
                                   @"username": self.userLoginTextField.text,
                                   @"password": self.passWordTextField.text,
                                   @"bind_msisdn": @(NO),
                                   @"bind_email": @(NO)
                                   };
                }
            }
        }
        
        callback(parameters, nil);
    }
}

- (void)updateAuthSessionWithCompletedStages:(NSArray *)completedStages didUpdateParameters:(void (^)(NSDictionary *parameters, NSError *error))callback
{
    if (callback)
    {
        if (currentSession)
        {
            currentSession.completed = completedStages;
            
            BOOL isMSISDNFlowCompleted = [self isFlowCompleted:kMXLoginFlowTypeMSISDN];
            BOOL isEmailFlowCompleted = [self isFlowCompleted:kMXLoginFlowTypeEmailIdentity];
            
            // Check the supported use cases
            if (isMSISDNFlowCompleted && self.isThirdPartyIdentifierPending)
            {
                NSLog(@"[AuthInputsView] Prepare a new third-party stage");
                
                // Here an email address is available, we add it to the authentication session.
                [self prepareParameters:callback];
                
                return;
            }
            else if ((isMSISDNFlowCompleted || isEmailFlowCompleted)
                     && [self isFlowSupported:kMXLoginFlowTypeRecaptcha] && ![self isFlowCompleted:kMXLoginFlowTypeRecaptcha])
            {
                NSLog(@"[AuthInputsView] Display reCaptcha stage");
                
                if (externalRegistrationParameters)
                {
                    [self displayRecaptchaForm:^(NSString *response) {
                        
                        if (response.length)
                        {
                            // We finalize here a registration triggered from external inputs. All the required data are handled by the session id
                            NSDictionary *parameters = @{
                                                         @"auth": @{@"session": currentSession.session, @"response": response, @"type": kMXLoginFlowTypeRecaptcha},
                                                         };
                            callback (parameters, nil);
                        }
                        else
                        {
                            NSLog(@"[AuthInputsView] reCaptcha stage failed");
                            callback (nil, [NSError errorWithDomain:MXKAuthErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:[NSBundle mxk_localizedStringForKey:@"not_supported_yet"]}]);
                        }
                    }];
                }
                else
                {
                    [self prepareParameters:callback];
                }
                
                return;
            }
            else if ([self isFlowSupported:kMXLoginFlowTypeTerms] && ![self isFlowCompleted:kMXLoginFlowTypeTerms])
            {
                NSLog(@"[AuthInputsView] Prepare a new terms stage");

                [self prepareParameters:callback];

                return;
            }
        }
        
        NSLog(@"[AuthInputsView] updateAuthSessionWithCompletedStages failed");
        callback (nil, [NSError errorWithDomain:MXKAuthErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:[NSBundle mxk_localizedStringForKey:@"not_supported_yet"]}]);
    }
}

- (BOOL)setExternalRegistrationParameters:(NSDictionary *)registrationParameters
{
    // Presently we only support a registration based on next_link associated to a successful email validation.
    NSString *homeserverURL;
    NSString *identityURL;
    
    // Check the current authentication type
    if (self.authType != MXKAuthenticationTypeRegister)
    {
        NSLog(@"[AuthInputsView] setExternalRegistrationParameters failed: wrong auth type");
        return NO;
    }
    
    // Retrieve the REST client from delegate
    MXRestClient *restClient;
    if (self.delegate && [self.delegate respondsToSelector:@selector(authInputsViewThirdPartyIdValidationRestClient:)])
    {
        restClient = [self.delegate authInputsViewThirdPartyIdValidationRestClient:self];
    }
    
    if (restClient)
    {
        // Sanity check on home server
        id hs_url = registrationParameters[@"hs_url"];
        if (hs_url && [hs_url isKindOfClass:NSString.class])
        {
            homeserverURL = hs_url;
            
            if ([homeserverURL isEqualToString:restClient.homeserver] == NO)
            {
                NSLog(@"[AuthInputsView] setExternalRegistrationParameters failed: wrong homeserver URL");
                return NO;
            }
        }
        
        // Sanity check on identity server
        id is_url = registrationParameters[@"is_url"];
        if (is_url && [is_url isKindOfClass:NSString.class])
        {
            identityURL = is_url;
            
            if ([identityURL isEqualToString:restClient.identityServer] == NO)
            {
                NSLog(@"[AuthInputsView] setExternalRegistrationParameters failed: wrong identity server URL");
                return NO;
            }
        }
    }
    else
    {
        NSLog(@"[AuthInputsView] setExternalRegistrationParameters failed: not supported");
        return NO;
    }
    
    // Retrieve other parameters
    NSString *clientSecret;
    NSString *sid;
    NSString *sessionId;
    
    id value = registrationParameters[@"client_secret"];
    if (value && [value isKindOfClass:NSString.class])
    {
        clientSecret = value;
    }
    value = registrationParameters[@"sid"];
    if (value && [value isKindOfClass:NSString.class])
    {
        sid = value;
    }
    value = registrationParameters[@"session_id"];
    if (value && [value isKindOfClass:NSString.class])
    {
        sessionId = value;
    }
    
    // Check validity of the required parameters
    if (!homeserverURL.length || !identityURL.length || !clientSecret.length || !sid.length || !sessionId.length)
    {
        NSLog(@"[AuthInputsView] setExternalRegistrationParameters failed: wrong parameters");
        return NO;
    }
    
    // Prepare the registration parameters (Ready to use)
    NSURL *identServerURL = [NSURL URLWithString:identityURL];
    externalRegistrationParameters = @{
                                       @"auth": @{@"session": sessionId, @"threepid_creds": @{@"client_secret": clientSecret, @"id_server": identServerURL.host, @"sid": sid}, @"type": kMXLoginFlowTypeEmailIdentity},
                                       };
    
    // Hide all inputs by default
    [self hideInputsContainer];
    
    return YES;
}

- (BOOL)areAllRequiredFieldsSet
{
    // Keep enable the submit button.
    return YES;
}

- (void)dismissKeyboard
{
    [self.userLoginTextField resignFirstResponder];
    [self.passWordTextField resignFirstResponder];
    [self.emailTextField resignFirstResponder];
    [self.repeatPasswordTextField resignFirstResponder];
    
    [super dismissKeyboard];
}

- (NSString*)userId
{
    return self.userLoginTextField.text;
}

- (NSString*)password
{
    return self.passWordTextField.text;
}

- (void)setCurrentLastContainer:(UIView*)currentLastContainer
{
    _currentLastContainer = currentLastContainer;
    
    CGRect frame = _currentLastContainer.frame;
    self.viewHeightConstraint.constant = frame.origin.y + frame.size.height;
}

#pragma mark -

- (BOOL)areThirdPartyIdentifiersSupported
{
    return NO;
}

- (BOOL)areAllThirdPartyIdentifiersRequired
{
    return NO;
}

- (void)setThirdPartyIdentifiersHidden:(BOOL)thirdPartyIdentifiersHidden
{
    [self hideInputsContainer];
    
    UIView *lastViewContainer;
    
    if (thirdPartyIdentifiersHidden)
    {
        self.passWordTextField.returnKeyType = UIReturnKeyNext;

        self.userLoginTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                         initWithString:NSLocalizedStringFromTable(@"auth_user_name_placeholder", @"Vector", nil)
                                                         attributes:@{NSForegroundColorAttributeName: ThemeService.shared.theme.placeholderTextColor}];
        
        self.userLoginContainer.hidden = NO;
        self.passwordContainer.hidden = NO;
        self.repeatPasswordContainer.hidden = NO;
        
        self.passwordContainerTopConstraint.constant = 50;
        
        lastViewContainer = self.repeatPasswordContainer;
    }
    else
    {
        if ([self isFlowSupported:kMXLoginFlowTypeEmailIdentity])
        {
            self.emailTextField.placeholder = NSLocalizedStringFromTable(@"auth_optional_email_placeholder", @"Vector", nil);
            
            self.emailTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                             initWithString:self.emailTextField.placeholder
                                                             attributes:@{NSForegroundColorAttributeName: ThemeService.shared.theme.placeholderTextColor}];
            
            self.emailContainer.hidden = NO;
            
            self.messageLabel.hidden = NO;
            self.messageLabel.text = NSLocalizedStringFromTable(@"auth_add_email_message", @"Vector", nil);
            
            lastViewContainer = self.emailContainer;
        }
        
        if (!self.messageLabel.isHidden)
        {
            [self.messageLabel sizeToFit];
            
            CGRect frame = self.messageLabel.frame;
            
            CGFloat offset = frame.origin.y + frame.size.height;
            
            self.emailContainerTopConstraint.constant = offset;
        }
    }
    
    self.currentLastContainer = lastViewContainer;
    
    _thirdPartyIdentifiersHidden = thirdPartyIdentifiersHidden;
}

- (void)resetThirdPartyIdentifiers
{
    [self dismissKeyboard];
    
    self.emailTextField.text = nil;
}

#pragma mark - UITextField delegate

- (BOOL)textFieldShouldReturn:(UITextField*)textField
{
    if (textField.returnKeyType == UIReturnKeyDone)
    {
        // "Done" key has been pressed
        [textField resignFirstResponder];
        
        // Launch authentication now
        [self.delegate authInputsViewDidPressDoneKey:self];
    }
    else
    {
        //"Next" key has been pressed
        if (textField == self.userLoginTextField)
        {
            [self.passWordTextField becomeFirstResponder];
        }
        else if (textField == self.passWordTextField)
        {
            [self.repeatPasswordTextField becomeFirstResponder];
        }
        else if (textField == self.emailTextField)
        {
            [self.passWordTextField becomeFirstResponder];
        }
    }
    
    return YES;
}

#pragma mark -

- (void)hideInputsContainer
{
    // Hide all inputs container
    self.userLoginContainer.hidden = YES;
    self.passwordContainer.hidden = YES;
    self.emailContainer.hidden = YES;
    self.repeatPasswordContainer.hidden = YES;
    
    // Hide other items
    self.messageLabelTopConstraint.constant = 8;
    self.messageLabel.hidden = YES;
    self.recaptchaContainer.hidden = YES;
    self.termsView.hidden = YES;
    self.ssoButtonContainer.hidden = YES;
    
    _currentLastContainer = nil;
}

- (BOOL)displayRecaptchaForm:(void (^)(NSString *response))callback
{
    // Retrieve the site key
    NSString *siteKey;
    
    id recaptchaParams = currentSession.params[kMXLoginFlowTypeRecaptcha];
    if (recaptchaParams && [recaptchaParams isKindOfClass:NSDictionary.class])
    {
        NSDictionary *recaptchaParamsDict = (NSDictionary*)recaptchaParams;
        siteKey = recaptchaParamsDict[@"public_key"];
    }
    
    // Retrieve the REST client from delegate
    MXRestClient *restClient;
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(authInputsViewThirdPartyIdValidationRestClient:)])
    {
        restClient = [self.delegate authInputsViewThirdPartyIdValidationRestClient:self];
    }
    
    // Sanity check
    if (siteKey.length && restClient && callback)
    {
        [self hideInputsContainer];
        
        self.messageLabel.hidden = NO;
        self.messageLabel.text = NSLocalizedStringFromTable(@"auth_recaptcha_message", @"Vector", nil);
        
        self.recaptchaContainer.hidden = NO;
        self.currentLastContainer = self.recaptchaContainer;

        // IB does not support WKWebview in a xib before iOS 11
        // So, add it by coding

        // Do some cleaning/reset before
        for (UIView *view in self.recaptchaContainer.subviews)
        {
            [view removeFromSuperview];
        }

        MXKAuthenticationRecaptchaWebView *reCaptchaWebView = [MXKAuthenticationRecaptchaWebView new];
        reCaptchaWebView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.recaptchaContainer addSubview:reCaptchaWebView];

        // Disable the webview scrollView to avoid 2 scrollviews on the same screen
        reCaptchaWebView.scrollView.scrollEnabled = NO;

        [self.recaptchaContainer addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"|-[view]-|"
                                                 options:0
                                                 metrics:0
                                                   views:@{
                                                           @"view": reCaptchaWebView
                                                           }
          ]
         ];
        [self.recaptchaContainer addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[view]-|"
                                                 options:0
                                                 metrics:0
                                                   views:@{
                                                           @"view": reCaptchaWebView
                                                           }
          ]
         ];


        [reCaptchaWebView openRecaptchaWidgetWithSiteKey:siteKey fromHomeServer:restClient.homeserver callback:callback];
        
        return YES;
    }
    
    return NO;
}

// Tell whether a flow type is supported or not by this view.
- (BOOL)isSupportedFlowType:(MXLoginFlowType)flowType
{
    if ([flowType isEqualToString:kMXLoginFlowTypePassword])
    {
        return YES;
    }
    else if ([flowType isEqualToString:kMXLoginFlowTypeEmailIdentity])
    {
        return YES;
    }
    else if ([flowType isEqualToString:kMXLoginFlowTypeRecaptcha])
    {
        return YES;
    }
    else if ([flowType isEqualToString:kMXLoginFlowTypeMSISDN])
    {
        return YES;
    }
    else if ([flowType isEqualToString:kMXLoginFlowTypeDummy])
    {
        return YES;
    }
    else if ([flowType isEqualToString:kMXLoginFlowTypeTerms])
    {
        return YES;
    }
    else if ([flowType isEqualToString:kMXLoginFlowTypeCAS] || [flowType isEqualToString:kMXLoginFlowTypeSSO])
    {
        return YES;
    }

    return NO;
}

- (MXAuthenticationSession*)validateAuthenticationSession:(MXAuthenticationSession*)authSession
{
    // Check whether the listed flows in this authentication session are supported
    NSMutableArray *supportedFlows = [NSMutableArray array];
    
    for (MXLoginFlow* flow in authSession.flows)
    {
        // Check whether flow type is defined
        if (flow.type)
        {
            if ([self isSupportedFlowType:flow.type])
            {
                // Check here all stages
                BOOL isSupported = YES;
                if (flow.stages.count)
                {
                    for (NSString *stage in flow.stages)
                    {
                        if ([self isSupportedFlowType:stage] == NO)
                        {
                            NSLog(@"[AuthInputsView] %@: %@ stage is not supported.", (type == MXKAuthenticationTypeLogin ? @"login" : @"register"), stage);
                            isSupported = NO;
                            break;
                        }
                    }
                }
                else
                {
                    flow.stages = @[flow.type];
                }
                
                if (isSupported)
                {
                    [supportedFlows addObject:flow];
                }
            }
            else
            {
                NSLog(@"[AuthInputsView] %@: %@ stage is not supported.", (type == MXKAuthenticationTypeLogin ? @"login" : @"register"), flow.type);
            }
        }
        else
        {
            // Check here all stages
            BOOL isSupported = YES;
            if (flow.stages.count)
            {
                for (NSString *stage in flow.stages)
                {
                    if ([self isSupportedFlowType:stage] == NO)
                    {
                        NSLog(@"[AuthInputsView] %@: %@ stage is not supported.", (type == MXKAuthenticationTypeLogin ? @"login" : @"register"), stage);
                        isSupported = NO;
                        break;
                    }
                }
            }
            
            if (isSupported)
            {
                [supportedFlows addObject:flow];
            }
        }
    }
    
    if (supportedFlows.count)
    {
        if (supportedFlows.count == authSession.flows.count)
        {
            // Return the original session.
            return authSession;
        }
        else
        {
            // Keep only the supported flow.
            MXAuthenticationSession *updatedAuthSession = [[MXAuthenticationSession alloc] init];
            updatedAuthSession.session = authSession.session;
            updatedAuthSession.params = authSession.params;
            updatedAuthSession.flows = supportedFlows;
            return updatedAuthSession;
        }
    }
    
    return nil;
}

- (BOOL)displayTermsView:(dispatch_block_t)onAcceptedCallback
{
    // Extract data
    NSDictionary *loginTermsData = currentSession.params[kMXLoginFlowTypeTerms];
    MXLoginTerms *loginTerms;
    MXJSONModelSetMXJSONModel(loginTerms, MXLoginTerms.class, loginTermsData);

    if (loginTerms)
    {
        [self hideInputsContainer];

        self.messageLabel.hidden = NO;
        self.messageLabel.text = NSLocalizedStringFromTable(@"auth_accept_policies", @"Vector", nil);

        self.termsView.hidden = NO;
        self.currentLastContainer = self.termsView;

        self.termsView.delegate = self.delegate;
        [self.termsView displayTermsWithTerms:loginTerms onAccepted:onAcceptedCallback];

        return YES;
    }

    return NO;
}

#pragma mark - Flow state

/**
 Check if a flow (kMXLoginFlowType*) is part of the required flows steps.

 @param flow the flow type to check.
 @return YES if the the flow must be implemented.
 */
- (BOOL)isFlowSupported:(NSString *)flow
{
    for (MXLoginFlow *loginFlow in currentSession.flows)
    {
        if ([loginFlow.type isEqualToString:flow] || [loginFlow.stages indexOfObject:flow] != NSNotFound)
        {
            return YES;
        }
    }

    return NO;
}

/**
 Check if a flow (kMXLoginFlowType*) has already been completed.

 @param flow the flow type to check.
 @return YES if the the flow has been completedd.
 */
- (BOOL)isFlowCompleted:(NSString *)flow
{
    if (currentSession.completed && [currentSession.completed indexOfObject:flow] != NSNotFound)
    {
        return YES;
    }

    return NO;
}

@end
