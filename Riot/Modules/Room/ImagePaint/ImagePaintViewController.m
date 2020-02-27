//
//  ImagePaintViewController.m
//  Riot
//
//  Created by Michael Rojkov on 28.01.20.
//  Copyright © 2020 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

#import "ImagePaintViewController.h"
#import "RoomInputToolbarView.h"
#import <CoreGraphics/CGBase.h>

@interface ImagePaintViewController ()
{
    /**
     Variable for saving movement status
     */
    bool isMoving;
    
    /**
     Variable for saving touch location
     */
    CGPoint lastTouchLocation;
    
    /**
     Variable for saving stroke width
     */
    float strokeWidth;
    
    /**
     Variable for saving stroke color
     */
    UIColor *strokeColor;
    
    /**
     UIImageView for showing the picture
    */
    UIImageView *photoImageView;
    
    /**
     UIImageView for drawing in the picture
    */
    UIImageView *drawImageView;
    
    /**
     UI elements for picking the stroke width
    */
    UISlider *strokeWidthSlider;
    UIButton *strokeWidthButton;
    
    /**
     Button to open the color picker
    */
    UIButton *strokeColorButton;
    
    /**
     UIStackView for choosing a stroke color
    */
    UIStackView *colorPickerView;
    
    /**
     UIButtons that are displayed in the colorPicker
    */
    UIButton *redColorButton;
    UIButton *whiteColorButton;
    UIButton *blueColorButton;
    UIButton *blackColorButton;
}

@end

@implementation ImagePaintViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Hide status bar for thise view controller
    [self setNeedsStatusBarAppearanceUpdate];
    
    //save the stroke color
    strokeColor = [self whiteStrokeColor];
    
    self.view.backgroundColor = [UIColor blackColor];
    
    CGRect aspectRect = AVMakeRectWithAspectRatioInsideRect(self.image.size, self.view.frame);
    
    photoImageView =[[UIImageView alloc] initWithFrame:aspectRect];
    photoImageView.contentMode = UIViewContentModeScaleAspectFit;
    photoImageView.image = self.image;
    photoImageView.userInteractionEnabled = NO;
    [self.view addSubview:photoImageView];
    
    drawImageView = [[UIImageView alloc] initWithFrame:photoImageView.bounds];
    
    drawImageView.userInteractionEnabled = NO;
    [photoImageView addSubview:drawImageView];
    isMoving = NO;
    
    //Clear Button to erase the painted lines
    UIButton *clearButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [clearButton addTarget:self action:@selector(clearDraw:) forControlEvents:UIControlEventTouchUpInside];
    NSString *clearTitle = NSLocalizedStringFromTable(@"paint_image_clear", @"Vector", nil);
    [clearButton setTitle:clearTitle forState:UIControlStateNormal];
    [self.view addSubview:clearButton];
    [self setUpButton:clearButton backgroundColor:[UIColor blackColor] cornerRadius:6.0 buttonTag:-1];
    [[clearButton.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-20.0] setActive:true];
    [[clearButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:10.0] setActive:true];
    [[clearButton.widthAnchor constraintEqualToConstant:100.0] setActive:true];
    
    //StrokeColorButton
    strokeColorButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [strokeColorButton addTarget:self action:@selector(toggleColorPicker:) forControlEvents:UIControlEventTouchUpInside];
    [self setUpButton:strokeColorButton backgroundColor:[UIColor colorWithWhite:.3f alpha:1] cornerRadius:6.0 buttonTag: -1];
    [self.view addSubview:strokeColorButton];
    UIImage *strokeColorImage = [[UIImage imageNamed:@"pickColor.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [strokeColorButton setImage:strokeColorImage forState:UIControlStateNormal];
    [[strokeColorButton.bottomAnchor constraintEqualToAnchor:clearButton.topAnchor constant:-50.0] setActive:true];
    [[strokeColorButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:10.0] setActive:true];
    [[strokeColorButton.widthAnchor constraintEqualToConstant:60.0] setActive:true];
    [[strokeColorButton.heightAnchor constraintEqualToConstant:60.0] setActive:true];
    
    //StrokeColorButton for red color
    redColorButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self setUpButton:redColorButton backgroundColor:[self redStrokeColor] cornerRadius:6.0 buttonTag: 4];
    [redColorButton addTarget:self action:@selector(changeStrokeColor:) forControlEvents:UIControlEventTouchUpInside];
    [redColorButton.heightAnchor constraintEqualToConstant:40].active = true;
    [redColorButton.widthAnchor constraintEqualToConstant:40].active = true;
    
    //StrokeColorButton for white color
    whiteColorButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self setUpButton:whiteColorButton backgroundColor:[self whiteStrokeColor] cornerRadius:6.0 buttonTag: 2];
    [whiteColorButton addTarget:self action:@selector(changeStrokeColor:) forControlEvents:UIControlEventTouchUpInside];
    [whiteColorButton.heightAnchor constraintEqualToConstant:40].active = true;
    [whiteColorButton.widthAnchor constraintEqualToConstant:40].active = true;
    
    //StrokeColorButton for blue color
    blueColorButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self setUpButton:blueColorButton backgroundColor:[self blueStrokeColor] cornerRadius:6.0 buttonTag: 3];
    [blueColorButton addTarget:self action:@selector(changeStrokeColor:) forControlEvents:UIControlEventTouchUpInside];
    [blueColorButton.heightAnchor constraintEqualToConstant:40].active = true;
    [blueColorButton.widthAnchor constraintEqualToConstant:40].active = true;
    
    //StrokeColorButton for black color
    blackColorButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self setUpButton:blackColorButton backgroundColor:[self blackStrokeColor] cornerRadius:6.0 buttonTag: 1];
    [blackColorButton addTarget:self action:@selector(changeStrokeColor:) forControlEvents:UIControlEventTouchUpInside];
    [blackColorButton.heightAnchor constraintEqualToConstant:40].active = true;
    [blackColorButton.widthAnchor constraintEqualToConstant:40].active = true;
    
    //Stack View for the color buttons
    colorPickerView = [[UIStackView alloc] init];
    
    colorPickerView.axis = UILayoutConstraintAxisVertical;
    colorPickerView.distribution = UIStackViewDistributionEqualSpacing;
    colorPickerView.alignment = UIStackViewAlignmentCenter;
    colorPickerView.spacing = 10;
    colorPickerView.backgroundColor = [UIColor colorWithWhite:.3f alpha:1];
    [colorPickerView addArrangedSubview:redColorButton];
    [colorPickerView addArrangedSubview:whiteColorButton];
    [colorPickerView addArrangedSubview:blueColorButton];
    [colorPickerView addArrangedSubview:blackColorButton];
    colorPickerView.translatesAutoresizingMaskIntoConstraints = false;
    [self.view addSubview:colorPickerView];
    
    //Layout for Stack View
    [colorPickerView.centerXAnchor constraintEqualToAnchor:strokeColorButton.centerXAnchor].active = true;
    [[colorPickerView.bottomAnchor constraintEqualToAnchor:strokeColorButton.topAnchor constant:-10.0] setActive:true];
    
    //StrokeWidthButton
    strokeWidthButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [strokeWidthButton addTarget:self action:@selector(toggleStrokeSlider:) forControlEvents:UIControlEventTouchUpInside];
    [self setUpButton:strokeWidthButton backgroundColor:[UIColor colorWithWhite:.3f alpha:1] cornerRadius:30 buttonTag: -1];
    [self.view addSubview:strokeWidthButton];
    UIImage *strokeWidthImage = [UIImage imageNamed:@"paintStroke.png"];
    [strokeWidthButton setImage:strokeWidthImage forState:UIControlStateNormal];
    [[strokeWidthButton.bottomAnchor constraintEqualToAnchor:colorPickerView.topAnchor constant:-35.0] setActive:true];
    [[strokeWidthButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:10.0] setActive:true];
    [[strokeWidthButton.widthAnchor constraintEqualToConstant:60.0] setActive:true];
    [[strokeWidthButton.heightAnchor constraintEqualToConstant:60.0] setActive:true];
    
    //Stroke width Slider
    CGRect frame = CGRectMake(0.0, 0.0, 200.0, 100.0);
    strokeWidthSlider = [[UISlider alloc] initWithFrame:frame];
    [strokeWidthSlider addTarget:self action:@selector(sliderAction:) forControlEvents:UIControlEventValueChanged];
    [strokeWidthSlider setBackgroundColor:[UIColor colorWithRed:128.0/255.0 green:128.0/255.0 blue:128.0/255.0 alpha:0.7]];
    strokeWidthSlider.minimumValue = 5.0;
    strokeWidthSlider.maximumValue = 25.0;
    strokeWidthSlider.continuous = YES;
    strokeWidthSlider.value = 15.0;
    strokeWidthSlider.layer.cornerRadius = 5;
    strokeWidthSlider.hidden = true;
    [self.view addSubview:strokeWidthSlider];
    strokeWidth = strokeWidthSlider.value;
    
    strokeWidthSlider.translatesAutoresizingMaskIntoConstraints = false;
    [[strokeWidthSlider.leadingAnchor constraintEqualToAnchor:strokeWidthButton.trailingAnchor constant:20.0] setActive:true];
    [[strokeWidthSlider.centerYAnchor constraintEqualToAnchor:strokeWidthButton.centerYAnchor constant:0.0] setActive:true];
    [[strokeWidthSlider.widthAnchor constraintEqualToConstant:150.0] setActive:true];
    [[strokeWidthSlider.heightAnchor constraintEqualToConstant:35.0] setActive:true];
    
    //Save Button
    UIButton *saveButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [saveButton addTarget:self action:@selector(saveDraw:) forControlEvents:UIControlEventTouchUpInside];
    NSString *saveTitle = NSLocalizedStringFromTable(@"paint_image_send", @"Vector", nil);
    [saveButton setTitle:saveTitle forState:UIControlStateNormal];
    [self setUpButton:saveButton backgroundColor:[UIColor blackColor] cornerRadius:6.0 buttonTag: -1];
    [self.view addSubview:saveButton];
    [[saveButton.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-20.0] setActive:true];
    [[saveButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-10.0] setActive:true];
    [[saveButton.widthAnchor constraintEqualToConstant:100.0] setActive:true];
    
    //Cancel Button
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [cancelButton addTarget:self action:@selector(cancelDraw:) forControlEvents:UIControlEventTouchUpInside];
    NSString *cancelTitle = NSLocalizedStringFromTable(@"paint_image_cancel", @"Vector", nil);
    [cancelButton setTitle:cancelTitle forState:UIControlStateNormal];
    [self setUpButton:cancelButton backgroundColor:[UIColor blackColor] cornerRadius:6.0 buttonTag: -1];
    [self.view addSubview:cancelButton];
    [[cancelButton.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:20.0] setActive:true];
    [[cancelButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:10.0] setActive:true];
    [[cancelButton.widthAnchor constraintEqualToConstant:100.0] setActive:true];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint currentLocation = [touch locationInView:drawImageView];
    isMoving = NO;
    lastTouchLocation = currentLocation;
    [self drawLine:&currentLocation];
    
    NSLog(@"[ImagePaintViewController] user has started to touch screen %@.", NSStringFromCGPoint(lastTouchLocation));
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    
    UITouch *touch = [touches anyObject];
    CGPoint currentLocation = [touch locationInView:drawImageView];
    
    if (YES == isMoving)
    {
        NSLog(@"[ImagePaintViewController] user finished moving from  %@ to %@.", NSStringFromCGPoint(lastTouchLocation), NSStringFromCGPoint(currentLocation));
    }
    else
    {
        NSLog(@"[ImagePaintViewController] user just tapped the screen without moving at %@.", NSStringFromCGPoint(lastTouchLocation));
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    isMoving = YES;
    
    UITouch *touch = [touches anyObject];
    CGPoint currentLocation = [touch locationInView:drawImageView];
    [self drawLine:&currentLocation];
    
    lastTouchLocation = currentLocation;
}

- (IBAction)clearDraw:(id)sender
{ NSLog(@"[ImagePaintViewController] Clear Drawings");
    drawImageView.image = nil;
}

- (IBAction)saveDraw:(id)sender
{
    NSLog(@"[ImagePaintViewController] SaveDrawings");
    
    // Return the original image when the user didn't draw anything
    if (drawImageView.image == nil)
    {
        [self dismissViewControllerAnimated:YES completion:nil];
        if (self.callback != nil)
        {
            self.callback(photoImageView.image);
        }
    }
    
    UIImage *image1 = photoImageView.image;
    UIImage *image2 = [self imageWithImage:drawImageView.image scaledToSize:CGSizeMake(image1.size.width, image1.size.height)];
    
    CGSize size = CGSizeMake(image1.size.width, image1.size.height);
    
    UIGraphicsBeginImageContext(size);
    
    [image1 drawInRect:CGRectMake(0,0,size.width, image1.size.height)];
    [image2 drawInRect:CGRectMake(0,0,size.width, image2.size.height)];
    
    UIImage *finalImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    //Add image to view
    photoImageView.image = finalImage;
    drawImageView.image = nil;
    
    [self dismissViewControllerAnimated:YES completion:nil];
    if (self.callback != nil)
    {
        self.callback(finalImage);
    }
    
}

- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize
{
    //UIGraphicsBeginImageContext(newSize);
    // In next line, pass 0.0 to use the current device's pixel scaling factor (and thus account for Retina resolution).
    // Pass 1.0 to force exact pixel size.
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

- (IBAction)toggleColorPicker:(id)sender
{
    NSLog(@"[ImagePaintViewController] togglePicker Drawings");
    if(colorPickerView.arrangedSubviews.count>3)
    {
        [colorPickerView removeArrangedSubview:redColorButton];
        [colorPickerView removeArrangedSubview:whiteColorButton];
        [colorPickerView removeArrangedSubview:blueColorButton];
        [colorPickerView removeArrangedSubview:blackColorButton];
        
        // animate the layoutIfNeeded so we can get a smooth animation transition
        [UIView animateWithDuration:0.3f animations:^{
            [self.view setNeedsLayout];
            [self.view layoutIfNeeded];
            [self->blackColorButton removeFromSuperview];
            [self->blueColorButton removeFromSuperview];
            [self->whiteColorButton removeFromSuperview];
            [self->redColorButton removeFromSuperview];
        }];
    }
    else
    {
        [colorPickerView addArrangedSubview:redColorButton];
        [colorPickerView addArrangedSubview:blueColorButton];
        [colorPickerView addArrangedSubview:whiteColorButton];
        [colorPickerView addArrangedSubview:blackColorButton];
        [UIView animateWithDuration:0.3f animations:^{
            [self.view setNeedsLayout];
            [self.view layoutIfNeeded];
        }];
    }
}

- (IBAction)toggleStrokeSlider:(id)sender
{
    if(!strokeWidthSlider.isHidden)
    {
        NSLog(@"[ImagePaintViewController] toggle on");
        strokeWidthSlider.hidden = true;
    }
    else
    {
        NSLog(@"[ImagePaintViewController] toggle off");
        strokeWidthSlider.hidden = false;
    }
}

- (IBAction)sliderAction:(id)sender
{
    strokeWidth = strokeWidthSlider.value;
}

- (void)changeStrokeColor:(UIButton*)sender
{
    if (sender.tag == 1)
    {
        strokeColor = [self blackStrokeColor];
    }
    else if (sender.tag == 2)
    {
        strokeColor = [self whiteStrokeColor];
    }
    else if (sender.tag == 3)
    {
        strokeColor = [self blueStrokeColor];
    }
    else if (sender.tag == 4)
    {
        strokeColor = [self redStrokeColor];
    }
    [strokeColorButton setTintColor:strokeColor];
    [self toggleColorPicker:nil];
}

- (UIColor *)blackStrokeColor
{
    return [UIColor colorWithRed:0.02 green:0.03 blue:0.03 alpha:1.0];
}

- (UIColor *)whiteStrokeColor
{
    return [UIColor colorWithRed:0.97 green:0.98 blue:0.98 alpha:1.0];
}

- (UIColor *)blueStrokeColor
{
    return [UIColor colorWithRed:0.00 green:0.58 blue:0.82 alpha:1.0];
}

- (UIColor *)redStrokeColor
{
    return [UIColor colorWithRed:1.00 green:0.29 blue:0.33 alpha:1.0];
}

- (IBAction)cancelDraw:(id)sender
{
    NSLog(@"[ImagePaintViewController] Cancel drawing");
    
    [self dismissViewControllerAnimated:YES completion:nil];
    if (self.callback != nil)
    {
        self.callback(nil);
    }
}

- (void)drawLine:(CGPoint*)touchLocation
{
    UIGraphicsBeginImageContext(drawImageView.bounds.size);
    
    CGContextRef currentContext = UIGraphicsGetCurrentContext();
    [drawImageView.image drawAtPoint:CGPointZero];
    CGContextSetLineCap(currentContext, kCGLineCapRound);
    CGContextSetLineWidth(currentContext, strokeWidth);
    CGContextSetStrokeColorWithColor(currentContext, strokeColor.CGColor);
    CGContextBeginPath(currentContext);
    CGContextMoveToPoint(currentContext, lastTouchLocation.x, lastTouchLocation.y);
    CGContextAddLineToPoint(currentContext, touchLocation->x, touchLocation->y);
    CGContextStrokePath(currentContext);
    drawImageView.image = UIGraphicsGetImageFromCurrentImageContext();
    
}

- (void)setUpButton:(UIButton*)button backgroundColor:(UIColor *)color cornerRadius:(CGFloat)corner buttonTag:(NSInteger)tag
{
    [ThemeService.shared.theme applyStyleOnButton:button];
    button.frame = CGRectMake(0, 0, 0, 0);
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.view addSubview:button];
    button.clipsToBounds = YES;
    [button setBackgroundColor:color];
    button.translatesAutoresizingMaskIntoConstraints = false;
    [button.layer setCornerRadius:corner];
    if(tag >= 0)
    {
        button.tag = tag;
    }
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

@end
