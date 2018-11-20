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

#import "RiotDesignValues.h"
#import "Tools.h"

#import "RiotNavigationController.h"

@interface AuthInputsView ()
{
    /**
     The current email validation
     */
    MXK3PID  *submittedEmail;
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
    
    self.userLoginTextField.placeholder = NSLocalizedStringFromTable(@"auth_user_id_placeholder", @"Vector", nil);
    self.repeatPasswordTextField.placeholder = NSLocalizedStringFromTable(@"auth_repeat_password_placeholder", @"Vector", nil);
    self.passWordTextField.placeholder = NSLocalizedStringFromTable(@"auth_password_placeholder", @"Vector", nil);
    
    if (kCaritasPlaceholderTextColor)
    {
        // Apply placeholder color
        [self customizeViewRendering];
    }
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
    
    self.repeatPasswordTextField.textColor = kCaritasPrimaryTextColor;
    self.userLoginTextField.textColor = kCaritasPrimaryTextColor;
    self.passWordTextField.textColor = kCaritasPrimaryTextColor;
    
    self.emailTextField.textColor = kCaritasPrimaryTextColor;
    
    self.messageLabel.textColor = kCaritasSecondaryTextColor;
    self.messageLabel.numberOfLines = 0;
    
    if (kCaritasPlaceholderTextColor)
    {
        if (self.userLoginTextField.placeholder)
        {
            self.userLoginTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                             initWithString:self.userLoginTextField.placeholder
                                                             attributes:@{NSForegroundColorAttributeName: kCaritasPlaceholderTextColor}];
        }
        
        if (self.repeatPasswordTextField.placeholder)
        {
            self.repeatPasswordTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                                  initWithString:self.repeatPasswordTextField.placeholder
                                                                  attributes:@{NSForegroundColorAttributeName: kCaritasPlaceholderTextColor}];
            
        }
        
        if (self.passWordTextField.placeholder)
        {
            self.passWordTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                            initWithString:self.passWordTextField.placeholder
                                                            attributes:@{NSForegroundColorAttributeName: kCaritasPlaceholderTextColor}];
        }
        
        if (self.emailTextField.placeholder)
        {
            self.emailTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                         initWithString:self.emailTextField.placeholder
                                                         attributes:@{NSForegroundColorAttributeName: kCaritasPlaceholderTextColor}];
        }
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
        
        // Reset UI by hidding all items
        [self hideInputsContainer];
        
        if ([super setAuthSession:validSession withAuthType:authType])
        {
            if (authType == MXKAuthenticationTypeLogin)
            {
                self.passWordTextField.returnKeyType = UIReturnKeyDone;
                
                self.userLoginTextField.placeholder = NSLocalizedStringFromTable(@"auth_user_id_placeholder", @"Vector", nil);
                
                if (kCaritasPlaceholderTextColor)
                {
                    self.userLoginTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                                     initWithString:self.userLoginTextField.placeholder
                                                                     attributes:@{NSForegroundColorAttributeName: kCaritasPlaceholderTextColor}];
                }
                
                self.userLoginContainer.hidden = NO;
                self.messageLabel.hidden = YES;
                self.passwordContainer.hidden = NO;
                
                self.messageLabelTopConstraint.constant = 59;
                self.passwordContainerTopConstraint.constant = 70;
                
                self.currentLastContainer = self.passwordContainer;
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
    // Check the validity of the parameters
    NSString *errorMsg = nil;
    
    // Remove whitespace in user login text field
    NSString *userLogin = self.userLoginTextField.text;
    self.userLoginTextField.text = [userLogin stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    if (type == MXKAuthenticationTypeLogin)
    {
        if (self.isPasswordBasedFlowSupported)
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
    
    return errorMsg;
}

- (void)prepareParameters:(void (^)(NSDictionary *parameters, NSError *error))callback
{
    if (callback)
    {
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
                if (self.isPasswordBasedFlowSupported)
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
            
            BOOL isMSISDNFlowCompleted = self.isMSISDNFlowCompleted;
            BOOL isEmailFlowCompleted = self.isEmailIdentityFlowCompleted;
            
            // Check the supported use cases
            if (isMSISDNFlowCompleted && self.isThirdPartyIdentifierPending)
            {
                NSLog(@"[AuthInputsView] Prepare a new third-party stage");
                
                // Here an email address is available, we add it to the authentication session.
                [self prepareParameters:callback];
                
                return;
            }
            else if ((isMSISDNFlowCompleted || isEmailFlowCompleted) && self.isRecaptchaFlowRequired)
            {
                NSLog(@"[AuthInputsView] Display reCaptcha stage");
                
                [self displayRecaptchaForm:^(NSString *response) {
                    
                    if (response.length)
                    {
                        // Update the parameters dict
                        NSDictionary *parameters = @{
                                                     @"auth": @{@"session": currentSession.session, @"response": response, @"type": kMXLoginFlowTypeRecaptcha},
                                                     @"username": self.userLoginTextField.text,
                                                     @"password": self.passWordTextField.text,
                                                     @"bind_msisdn": [NSNumber numberWithBool:isMSISDNFlowCompleted],
                                                     @"bind_email": [NSNumber numberWithBool:isEmailFlowCompleted]
                                                     };
                        
                        callback (parameters, nil);
                    }
                    else
                    {
                        NSLog(@"[AuthInputsView] reCaptcha stage failed");
                        callback (nil, [NSError errorWithDomain:MXKAuthErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:[NSBundle mxk_localizedStringForKey:@"not_supported_yet"]}]);
                    }
                    
                }];
                
                return;
            }
        }
        
        NSLog(@"[AuthInputsView] updateAuthSessionWithCompletedStages failed");
        callback (nil, [NSError errorWithDomain:MXKAuthErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:[NSBundle mxk_localizedStringForKey:@"not_supported_yet"]}]);
    }
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
    return (self.isEmailIdentityFlowSupported || self.isMSISDNFlowSupported);
}

- (BOOL)isThirdPartyIdentifierRequired
{
    // Check first whether some 3pids are supported
    if (!self.areThirdPartyIdentifiersSupported)
    {
        return NO;
    }
    
    // Check whether an account may be created without third-party identifiers.
    for (MXLoginFlow *loginFlow in currentSession.flows)
    {
        if ([loginFlow.stages indexOfObject:kMXLoginFlowTypeDummy] != NSNotFound || [loginFlow.type isEqualToString:kMXLoginFlowTypeDummy])
        {
            // The dummy flow is supported, the 3pid are then optional.
            return NO;
        }
        
        if ((loginFlow.stages.count == 1 && [loginFlow.stages[0] isEqualToString:kMXLoginFlowTypeRecaptcha]) || [loginFlow.type isEqualToString:kMXLoginFlowTypeRecaptcha])
        {
            // The recaptcha flow is supported alone, the 3pids are then optional.
            return NO;
        }
        
        if ((loginFlow.stages.count == 1 && [loginFlow.stages[0] isEqualToString:kMXLoginFlowTypePassword]) || [loginFlow.type isEqualToString:kMXLoginFlowTypePassword])
        {
            // The password flow is supported alone, the 3pids are then optional.
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)areAllThirdPartyIdentifiersRequired
{
    // Check first whether some 3pids are required
    if (!self.isThirdPartyIdentifierRequired)
    {
        return NO;
    }
    
    BOOL isEmailIdentityFlowSupported = self.isEmailIdentityFlowSupported;
    
    for (MXLoginFlow *loginFlow in currentSession.flows)
    {
        if (isEmailIdentityFlowSupported && [loginFlow.stages indexOfObject:kMXLoginFlowTypeEmailIdentity] == NSNotFound)
        {
            return NO;
        }
    }
    
    return YES;
}

- (void)setThirdPartyIdentifiersHidden:(BOOL)thirdPartyIdentifiersHidden
{
    [self hideInputsContainer];
    
    UIView *lastViewContainer;
    
    if (thirdPartyIdentifiersHidden)
    {
        self.passWordTextField.returnKeyType = UIReturnKeyNext;
        
        if (kCaritasPlaceholderTextColor)
        {
            self.userLoginTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                             initWithString:NSLocalizedStringFromTable(@"auth_user_name_placeholder", @"Vector", nil)
                                                             attributes:@{NSForegroundColorAttributeName: kCaritasPlaceholderTextColor}];
        }
        else
        {
            self.userLoginTextField.placeholder = NSLocalizedStringFromTable(@"auth_user_name_placeholder", @"Vector", nil);
        }
        
        self.userLoginContainer.hidden = NO;
        self.passwordContainer.hidden = NO;
        self.repeatPasswordContainer.hidden = NO;
        
        self.passwordContainerTopConstraint.constant = 50;
        
        lastViewContainer = self.repeatPasswordContainer;
    }
    else
    {
        if (self.isEmailIdentityFlowSupported)
        {
            if (self.isThirdPartyIdentifierRequired)
            {
                self.emailTextField.placeholder = NSLocalizedStringFromTable(@"auth_email_placeholder", @"Vector", nil);
            }
            else
            {
                self.emailTextField.placeholder = NSLocalizedStringFromTable(@"auth_optional_email_placeholder", @"Vector", nil);
            }
            
            if (kCaritasPlaceholderTextColor)
            {
                self.emailTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                             initWithString:self.emailTextField.placeholder
                                                             attributes:@{NSForegroundColorAttributeName: kCaritasPlaceholderTextColor}];
            }
            
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
    self.recaptchaWebView.hidden = YES;
    
    _currentLastContainer = nil;
}

- (BOOL)displayRecaptchaForm:(void (^)(NSString *response))callback
{
    // Retrieve the site key
    NSString *siteKey;
    
    id recaptchaParams = [currentSession.params objectForKey:kMXLoginFlowTypeRecaptcha];
    if (recaptchaParams && [recaptchaParams isKindOfClass:NSDictionary.class])
    {
        NSDictionary *recaptchaParamsDict = (NSDictionary*)recaptchaParams;
        siteKey = [recaptchaParamsDict objectForKey:@"public_key"];
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
        
        self.recaptchaWebView.hidden = NO;
        self.currentLastContainer = self.recaptchaWebView;
        
        [self.recaptchaWebView openRecaptchaWidgetWithSiteKey:siteKey fromHomeServer:restClient.homeserver callback:callback];
        
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
        return NO;
    }
    else if ([flowType isEqualToString:kMXLoginFlowTypeDummy])
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

- (BOOL)isPasswordBasedFlowSupported
{
    if (currentSession)
    {
        for (MXLoginFlow *loginFlow in currentSession.flows)
        {
            if ([loginFlow.type isEqualToString:kMXLoginFlowTypePassword] || [loginFlow.stages indexOfObject:kMXLoginFlowTypePassword] != NSNotFound)
            {
                return YES;
            }
        }
    }
    
    return NO;
}

- (BOOL)isEmailIdentityFlowSupported
{
    if (currentSession)
    {
        for (MXLoginFlow *loginFlow in currentSession.flows)
        {
            if ([loginFlow.stages indexOfObject:kMXLoginFlowTypeEmailIdentity] != NSNotFound || [loginFlow.type isEqualToString:kMXLoginFlowTypeEmailIdentity])
            {
                return YES;
            }
        }
    }
    
    return NO;
}

- (BOOL)isEmailIdentityFlowCompleted
{
    if (currentSession && currentSession.completed)
    {
        if ([currentSession.completed indexOfObject:kMXLoginFlowTypeEmailIdentity] != NSNotFound)
        {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)isMSISDNFlowSupported
{
    return NO;
}

- (BOOL)isMSISDNFlowCompleted
{
    if (currentSession && currentSession.completed)
    {
        if ([currentSession.completed indexOfObject:kMXLoginFlowTypeMSISDN] != NSNotFound)
        {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)isRecaptchaFlowRequired
{
    if (currentSession && currentSession.flows)
    {
        for (MXLoginFlow *loginFlow in currentSession.flows)
        {
            if ([loginFlow.stages indexOfObject:kMXLoginFlowTypeRecaptcha] == NSNotFound && ![loginFlow.type isEqualToString:kMXLoginFlowTypeRecaptcha])
            {
                return NO;
            }
        }
        
        return YES;
    }
    
    return NO;
}

- (BOOL)isDummyFlowSupported
{
    if (currentSession)
    {
        for (MXLoginFlow *loginFlow in currentSession.flows)
        {
            if ([loginFlow.stages indexOfObject:kMXLoginFlowTypeDummy] != NSNotFound || [loginFlow.type isEqualToString:kMXLoginFlowTypeDummy])
            {
                return YES;
            }
        }
    }
    
    return NO;
}

@end
