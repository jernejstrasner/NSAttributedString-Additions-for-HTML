//
//  CGUtils.m
//  CoreTextExtensions
//
//  Created by Oliver Drobnik on 1/16/11.
//  Copyright 2011 Drobnik.com. All rights reserved.
//

#import "CGUtils.h"


CGPathRef newPathForRoundedRect(CGRect rect, CGFloat cornerRadius, BOOL roundTopCorners, BOOL roundBottomCorners)
{
	UIRectCorner cornersToRound;
	if (roundTopCorners && roundBottomCorners) {
		cornersToRound = UIRectCornerAllCorners;
	} else if (roundTopCorners) {
		cornersToRound = UIRectCornerTopLeft | UIRectCornerTopRight;
	} else if (roundBottomCorners) {
		cornersToRound = UIRectCornerBottomLeft | UIRectCornerBottomRight;
	} else {
		return [[UIBezierPath bezierPathWithRect:rect] CGPath];
	}
	
	UIBezierPath *bezierPath = [UIBezierPath bezierPathWithRoundedRect:rect byRoundingCorners:cornersToRound cornerRadii:CGSizeMake(cornerRadius, cornerRadius)];
	
	return CGPathRetain([bezierPath CGPath]);
}

CGSize sizeThatFitsKeepingAspectRatio(CGSize originalSize, CGSize sizeToFit)
{
	CGFloat necessaryZoomWidth = sizeToFit.width / originalSize.width;
	CGFloat necessaryZoomHeight = sizeToFit.height / originalSize.height;
	
	CGFloat smallerZoom = MIN(necessaryZoomWidth, necessaryZoomHeight);
	
	CGSize scaledSize = CGSizeMake(roundf(originalSize.width*smallerZoom), roundf(originalSize.height*smallerZoom));
	return scaledSize;
}
