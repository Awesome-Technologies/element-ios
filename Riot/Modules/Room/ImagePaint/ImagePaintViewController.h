//
//  ImagePaintViewController.h
//  Riot
//
//  Created by Michael Rojkov on 28.01.20.
//  Copyright © 2020 Awesome Technologies Innovationslabor GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>




@interface ImagePaintViewController : UIViewController
/**
 Image file from RoomInputToolbarView
 */
@property (nonatomic,strong,nullable) UIImage *image;

/**
Scale the  drawing image to the same size as the displayed image

@param image image file of the drawings
@param scaleToSize size of the displayed image
*/
- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize;

/**
Callback to RoomInputToolbarView, to trigger the posting of the image

@param image image file of the new image
*/
@property (nonatomic, copy, nullable) void (^callback)(UIImage *image);


@end


