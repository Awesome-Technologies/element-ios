//
//  ImagePaintViewController.h
//  Riot
//
//  Created by Michael Rojkov on 28.01.20.
//  Copyright © 2020 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>




@interface ImagePaintViewController : UIViewController

//Image file from RoomInputToolbarView
@property (nonatomic,strong,nullable) UIImage * image;

//UIImageView for showing the picture
@property (nonatomic, retain,nullable) UIImageView *photoImageView;

//UIImageView for drawing in the picture
@property (nonatomic, retain,nullable) UIImageView *drawImageView;

//UI elements for picking the stroke width
@property (nonatomic, retain,nullable) IBOutlet UISlider *strokeWidthSlider;
@property (nonatomic, retain,nullable) IBOutlet UIButton *strokeWidthButton;

//Button to open the color picker
@property (nonatomic, retain,nullable) IBOutlet UIButton *strokeColorButton;

//UIStackView for choosing a stroke color
@property (nonatomic, retain,nullable) IBOutlet UIStackView *colorPickerView;

//UIButtons that are displayed in the colorPicker
@property (nonatomic, retain,nullable) IBOutlet UIButton *redColorButton;
@property (nonatomic, retain,nullable) IBOutlet UIButton *greenColorButton;
@property (nonatomic, retain,nullable) IBOutlet UIButton *blueColorButton;
@property (nonatomic, retain,nullable) IBOutlet UIButton *blackColorButton;

/**
Scale the  drawing image to the same size as the displayed image

@param image image file of the drawings
@param scaleToSize size of the displayed image
*/
-(UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize;

/**
Callback to RoomInputToolbarView, to trigger the posting of the image

@param image image file of the new image
*/
@property (nonatomic, copy, nullable) void (^callback)(UIImage *image);


@end


