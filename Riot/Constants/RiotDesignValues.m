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

#import "RiotDesignValues.h"

#ifdef IS_SHARE_EXTENSION
#import "RiotShareExtension-Swift.h"
#else
#import "Riot-Swift.h"
#endif


NSString *const kRiotDesignValuesDidChangeThemeNotification = @"kRiotDesignValuesDidChangeThemeNotification";

UIColor *kCaritasNavigationBarBgColor;
UIColor *kCaritasPrimaryBgColor;
UIColor *kCaritasSecondaryBgColor;
UIColor *kCaritasPrimaryTextColor;
UIColor *kCaritasSecondaryTextColor;
UIColor *kCaritasPlaceholderTextColor;
UIColor *kCaritasTopicTextColor;
UIColor *kCaritasSelectedBgColor;
UIColor *kCaritasAuxiliaryColor;
UIColor *kCaritasOverlayColor;
UIColor *kCaritasKeyboardColor;
UIColor *kCaritasTabBarSelectionColor;

// Riot Background Colors
UIColor *kCaritasBgColorWhite;
UIColor *kCaritasBgColorBlack;
UIColor *kCaritasBgColorOLEDBlack;
UIColor *kCaritasColorLightGrey;
UIColor *kCaritasColorLightBlack;
UIColor *kCaritasColorLightKeyboard;
UIColor *kCaritasColorDarkKeyboard;

// Caritas Text Colors
UIColor *kCaritasTextColorBlack;
UIColor *kCaritasTextColorDarkGray;
UIColor *kCaritasTextColorGray;
UIColor *kCaritasTextColorWhite;
UIColor *kCaritasTextColorDarkWhite;

UIColor *kCaritasColorRed;
UIColor *kCaritasColorWhite;
UIColor *kCaritasColorGrey;
UIColor *kCaritasColorLinkBlue;
UIColor *kCaritasColorSilver;
UIColor *kCaritasColorPinkRed;
UIColor *kCaritasColorCuriousBlue;

NSInteger const kRiotRoomModeratorLevel = 50;
NSInteger const kRiotRoomAdminLevel = 100;

UIStatusBarStyle kCaritasDesignStatusBarStyle = UIStatusBarStyleDefault;
UIBarStyle kCaritasDesignSearchBarStyle = UIBarStyleDefault;
UIColor *kCaritasDesignSearchBarTintColor = nil;

UIKeyboardAppearance kCaritasKeyboard;

@implementation RiotDesignValues

+ (RiotDesignValues *)sharedInstance
{
    static RiotDesignValues *sharedOnceInstance;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedOnceInstance = [[RiotDesignValues alloc] init];
    });
    
    return sharedOnceInstance;
}

+ (void)load
{
    [super load];

    // Load colors at the app load time for the life of the app

    // Colors as defined by the design
    kCaritasBgColorWhite = [UIColor whiteColor];
    kCaritasBgColorBlack = UIColorFromRGB(0x2D2D2D);
    kCaritasBgColorOLEDBlack = [UIColor blackColor];
    
    kCaritasColorLightGrey = UIColorFromRGB(0xF2F2F2);
    kCaritasColorLightBlack = UIColorFromRGB(0x353535);
    
    kCaritasColorLightKeyboard = UIColorFromRGB(0xE7E7E7);
    kCaritasColorDarkKeyboard = UIColorFromRGB(0x7E7E7E);

    kCaritasTextColorBlack = UIColorFromRGB(0x3C3C3C);
    kCaritasTextColorDarkGray = UIColorFromRGB(0x4A4A4A);
    kCaritasTextColorGray = UIColorFromRGB(0x9D9D9D);
    kCaritasTextColorWhite = UIColorFromRGB(0xDDDDDD);
    kCaritasTextColorDarkWhite = UIColorFromRGB(0xD9D9D9);
    
    kCaritasColorRed = UIColorFromRGB(0xCC1E1C);
    kCaritasColorWhite = UIColorFromRGB(0xFFFFFF);
    kCaritasColorGrey = UIColorFromRGB(0xBFBFBF);
    kCaritasColorLinkBlue = [UIColor colorWithRed:0 green:0.478431 blue:1 alpha:1];
    kCaritasColorSilver = UIColorFromRGB(0xC7C7CC);
    kCaritasColorPinkRed = UIColorFromRGB(0xFF0064);
    kCaritasColorCuriousBlue = UIColorFromRGB(0x2A9EDB);

    // Observe user interface theme change.
    [[NSUserDefaults standardUserDefaults] addObserver:[RiotDesignValues sharedInstance] forKeyPath:@"userInterfaceTheme" options:0 context:nil];
    [[RiotDesignValues sharedInstance] userInterfaceThemeDidChange];

    // Observe "Invert Colours" settings changes (available since iOS 11)
    [[NSNotificationCenter defaultCenter] addObserver:[RiotDesignValues sharedInstance] selector:@selector(accessibilityInvertColorsStatusDidChange) name:UIAccessibilityInvertColorsStatusDidChangeNotification object:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([@"userInterfaceTheme" isEqualToString:keyPath])
    {
        [self userInterfaceThemeDidChange];
    }
}

- (void)accessibilityInvertColorsStatusDidChange
{
    // Refresh the theme only for "auto"
    NSString *theme = RiotSettings.shared.userInterfaceTheme;
    if (!theme || [theme isEqualToString:@"auto"])
    {
        [self userInterfaceThemeDidChange];
    }
}

- (void)userInterfaceThemeDidChange
{
    // Retrieve the current selected theme ("light" if none. "auto" is used as default from iOS 11).
    NSString *theme = RiotSettings.shared.userInterfaceTheme;

    if (!theme || [theme isEqualToString:@"auto"])
    {
        if (UIAccessibilityIsInvertColorsEnabled())
        {
            theme = @"dark";
        } else
        {
            theme = @"caritas";
        }
    }
    if ([theme isEqualToString:@"dark"])
    {
        // Set dark theme colors
        kCaritasPrimaryBgColor = kCaritasBgColorBlack;
        kCaritasSecondaryBgColor = kCaritasColorLightBlack;
        kCaritasPrimaryTextColor = kCaritasTextColorWhite;
        kCaritasSecondaryTextColor = kCaritasTextColorGray;
        kCaritasPlaceholderTextColor = [UIColor colorWithWhite:1.0 alpha:0.3];
        kCaritasTopicTextColor = kCaritasTextColorWhite;
        kCaritasSelectedBgColor = kCaritasTextColorGray;
        kCaritasTabBarSelectionColor = kCaritasColorRed;
        
        kCaritasDesignStatusBarStyle = UIStatusBarStyleLightContent;
        kCaritasDesignSearchBarStyle = UIBarStyleBlack;
        kCaritasDesignSearchBarTintColor = kCaritasBgColorBlack;
        
        kCaritasAuxiliaryColor = kCaritasTextColorGray;
        kCaritasOverlayColor = [UIColor colorWithWhite:0.3 alpha:0.5];
        kCaritasKeyboardColor = kCaritasColorDarkKeyboard;
        
        [UITextField appearance].keyboardAppearance = UIKeyboardAppearanceDark;
        kCaritasKeyboard = UIKeyboardAppearanceDark;
    }
    else
    {
        // Set caritas theme colors.
        kCaritasPrimaryBgColor = kCaritasColorWhite;
        kCaritasSecondaryBgColor = kCaritasColorRed;
        kCaritasPrimaryTextColor = kCaritasTextColorBlack;
        kCaritasSecondaryTextColor = kCaritasTextColorGray;
        kCaritasPlaceholderTextColor = nil; // Use default 70% gray color.
        kCaritasTopicTextColor = kCaritasTextColorWhite;
        kCaritasSelectedBgColor = kCaritasColorLinkBlue; // Use the default selection color.
        kCaritasTabBarSelectionColor = kCaritasColorRed;
        
        kCaritasDesignStatusBarStyle = UIStatusBarStyleLightContent;
        kCaritasDesignSearchBarStyle = UIBarStyleDefault;
        kCaritasDesignSearchBarTintColor = kCaritasColorRed; // Default tint color.
        
        kCaritasAuxiliaryColor = kCaritasColorSilver;
        kCaritasOverlayColor = [UIColor colorWithWhite:0.7 alpha:0.5];
        kCaritasKeyboardColor = kCaritasColorLightKeyboard;
        
        [UITextField appearance].keyboardAppearance = UIKeyboardAppearanceLight;
        kCaritasKeyboard = UIKeyboardAppearanceLight;
    }
    
    // UINavigationBar adds translucency / adds grey
    // Background has to account for that for the bar to have the correct color
    // Apple: https://developer.apple.com/library/archive/qa/qa1808/_index.html
    CGFloat red, green, blue, alpha;
    [kCaritasSecondaryBgColor getRed:&red green:&green blue:&blue alpha:&alpha];
    
    if ([theme isEqualToString:@"dark"])
    {
        red -= .06;
        green -= .06;
        blue -= .06;
    }
    else
    {
        green = 0;
        blue = 0;
    }
    kCaritasNavigationBarBgColor = [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kRiotDesignValuesDidChangeThemeNotification object:nil];
}

@end
