//
//  MMAnimatingImageView.m
//  Magic Mouse
//
//  Created by Alex Zielenski on 2/25/12.
//  Copyright (c) 2012 Alex Zielenski. All rights reserved.
//

#import "MMAnimatingImageView.h"
#import "MCSpriteLayer.h"

const char MCInvalidateContext;

@interface MMAnimatingImageView ()
@property (weak) MCSpriteLayer *spriteLayer;
@property (weak) CALayer *hotSpotLayer;
- (void)_initialize;
- (void)_invalidateFrame;
- (void)_invalidateAnimation;
- (void)registerTypes;
- (void)_dragAnimationEnded:(id)sender;
@end

@implementation MMAnimatingImageView
@dynamic shouldShowHotSpot;

- (id)init {
	if ((self = [super init])) {
		[self _initialize];
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) {
        [self _initialize];
    }
    return self;
}

- (id)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self _initialize];
    }
    
    return self;
}

- (void)_initialize {
    self.shouldAnimate = YES;

    [self registerTypes];
    
    self.layer = [[MCSpriteLayer alloc] init];
    self.wantsLayer = YES;
    self.layer.contentsGravity = kCAGravityCenter;
    self.layer.bounds = self.bounds;
    self.layer.autoresizingMask = kCALayerHeightSizable | kCALayerWidthSizable | kCALayerMinXMargin | kCALayerMinYMargin;
    self.layer.delegate = self;
    
    CALayer *hotSpotLayer = [CALayer layer];
    hotSpotLayer.bounds = CGRectMake(0, 0, 4, 4);
    hotSpotLayer.backgroundColor = [[NSColor redColor] CGColor];
    hotSpotLayer.autoresizingMask = kCALayerNotSizable;
    hotSpotLayer.anchorPoint = CGPointMake(0, 0);
    hotSpotLayer.borderColor = [[NSColor blackColor] CGColor];
    hotSpotLayer.borderWidth = 0.5;
    [self.layer addSublayer:hotSpotLayer];
    
    self.hotSpotLayer = hotSpotLayer;
    self.spriteLayer = (MCSpriteLayer *)self.layer;

    self.shouldShowHotSpot = NO;
    self.shouldAllowDragging = NO;
    
    self.frameCount    = 1;
    self.frameDuration = 1;
    
    [self addObserver:self forKeyPath:@"image" options:0 context:(void *)&MCInvalidateContext];
    [self addObserver:self forKeyPath:@"hotSpot" options:0 context:(void *)&MCInvalidateContext];
    [self addObserver:self forKeyPath:@"placeholderImage" options:0 context:(void *)&MCInvalidateContext];
    [self addObserver:self forKeyPath:@"frameCount" options:0 context:(void *)&MCInvalidateContext];
    [self addObserver:self forKeyPath:@"frameDuration" options:0 context:(void *)&MCInvalidateContext];
    [self addObserver:self forKeyPath:@"shouldAnimate" options:0 context:NULL];
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:@"image"];
    [self removeObserver:self forKeyPath:@"hotSpot"];
    [self removeObserver:self forKeyPath:@"placeholderImage"];
    [self removeObserver:self forKeyPath:@"frameCount"];
    [self removeObserver:self forKeyPath:@"frameDuration"];
    [self removeObserver:self forKeyPath:@"shouldAnimate"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &MCInvalidateContext) {
        if ([keyPath isEqualToString:@"image"] || [keyPath isEqualToString:@"placeholderImage"]) {
            self.spriteLayer.contents = self.image ?: self.placeholderImage;
        }
        [self _invalidateFrame];
        [self _invalidateAnimation];
    } else if ([keyPath isEqualToString:@"shouldAnimate"]) {
        [self _invalidateAnimation];
    }
}

- (BOOL)layer:(CALayer *)layer shouldInheritContentsScale:(CGFloat)newScale fromWindow:(NSWindow *)window {
    return NO;
}

// Tell OSX that our view can accept images to be dragged in
- (void)registerTypes {
	[self registerForDraggedTypes:[NSArray arrayWithObjects:NSPasteboardTypeTIFF, NSPasteboardTypePNG, NSFilenamesPboardType, nil]];
}

- (void)viewDidMoveToWindow {
    [self _invalidateFrame];
}

+ (NSSet *)keyPathsForValuesAffectingShouldShowHotSpot {
    return [NSSet setWithObject:@"hotSpotLayer.hidden"];
}

- (BOOL)shouldShowHotSpot {
    return !self.hotSpotLayer.isHidden;
}

- (void)setShouldShowHotSpot:(BOOL)shouldShowHotSpot {
    self.hotSpotLayer.hidden = !shouldShowHotSpot;
}

#pragma mark - Invalidators

- (void)_invalidateFrame {
    CGFloat scale = self.scale;
    if (!self.scale || !self.image) {
        scale = self.window.backingScaleFactor;
    }

    if (scale == 0.0)
        scale = 1.0;

    if (self.scale && self.image)
        scale = self.scale;
    else if (!self.scale && self.image)
        scale = [self.image recommendedLayerContentsScale:self.window.backingScaleFactor];
    else
        scale = [self.placeholderImage recommendedLayerContentsScale:self.window.backingScaleFactor];

    self.layer.contentsScale       = scale;
    self.spriteLayer.contentsScale = self.layer.contentsScale;

    if (self.image) {
        CGSize effectiveSize = CGSizeMake(self.image.size.width, self.image.size.height / self.frameCount);
        CGRect effectiveRect = CGRectIntegral(CGRectMake(self.layer.frame.size.width / 2.0 - effectiveSize.width / 2.0, self.layer.frame.size.height / 2.0 + effectiveSize.height / 2.0, effectiveSize.width, effectiveSize.height));

        self.hotSpotLayer.position = CGPointMake(ceil(CGRectGetMinX(effectiveRect) + self.hotSpot.x - self.hotSpotLayer.frame.size.width / 2), ceil(CGRectGetMinY(effectiveRect) - self.hotSpot.y - self.hotSpotLayer.frame.size.height / 2));
        self.hotSpotLayer.opacity = 1.0;
    } else {
        self.hotSpotLayer.opacity = 0.0;
    }
}

- (void)_invalidateAnimation {
    [self.spriteLayer removeAllAnimations];
        
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"sampleIndex"];
    BOOL none = (self.frameCount == 1 || !self.shouldAnimate);
    NSUInteger frameCount = none || !self.image ? 0 : self.frameCount;
    self.spriteLayer.frameCount = frameCount;

    anim.fromValue    = @(frameCount + 1);
    anim.toValue      = @(1);
    anim.byValue      = @(-1);
    anim.duration     = self.frameDuration * frameCount;
    anim.repeatCount  = none ? 0 : HUGE_VALF; // just keep repeating it
    anim.autoreverses = NO; // do 1, 2, 3, 4, 5, 1, 2, 3, 4, 5
    anim.removedOnCompletion = none;
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    [self.spriteLayer addAnimation:anim forKey:@"sampleIndex"]; // start
}

- (id <CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)event {
    return (id <CAAction>)[NSNull null];
}

#pragma mark - NSDraggingSource

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context {
    if (context == NSDraggingContextWithinApplication && self.shouldAllowDragging)
        return NSDragOperationCopy;
    return NSDragOperationNone;
}

- (void)draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {
    if (self.delegate && [self.delegate respondsToSelector:@selector(imageView:didDragOutImage:)] && operation == NSDragOperationNone && !NSPointInRect(screenPoint, self.window.frame)) {
        [[NSCursor currentCursor] pop];
        NSShowAnimationEffect(NSAnimationEffectPoof, screenPoint, NSZeroSize, self, @selector(_dragAnimationEnded:), nil);
        [self.delegate imageView:self didDragOutImage:self.image];
    }
}

- (void)_dragAnimationEnded:(id)sender {
    [[NSCursor arrowCursor] push];
}

- (void)draggingSession:(NSDraggingSession *)session movedToPoint:(NSPoint)screenPoint {
    if (!NSPointInRect(screenPoint, self.window.frame)) {
        [[NSCursor disappearingItemCursor] push];
    } else if ([NSCursor currentCursor] == [NSCursor disappearingItemCursor]) {
        [[NSCursor currentCursor] pop];
    }
}

- (BOOL)ignoreModifierKeysForDraggingSession:(NSDraggingSession *)session {
    return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent {
    return self.shouldAllowDragging;
}

- (void)mouseDown:(NSEvent *)event {
    if (!self.image || !self.shouldAllowDragging)
        return;

    NSPasteboardItem *pbItem = [NSPasteboardItem new];
    [pbItem setDataProvider:self forTypes:@[ NSPasteboardTypePNG, NSPasteboardTypeTIFF, @"public.image" ]];

    NSDraggingItem *dragItem = [[NSDraggingItem alloc] initWithPasteboardWriter:pbItem];
    
    __weak typeof (self) weakSelf = self;
    NSImage *previewImage = [NSImage imageWithSize:self.frame.size flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        CGFloat opacity = weakSelf.hotSpotLayer.opacity;
        weakSelf.hotSpotLayer.opacity = 0.0;
        [weakSelf displayRectIgnoringOpacity:dstRect inContext:[NSGraphicsContext currentContext]];
        weakSelf.hotSpotLayer.opacity = opacity;
        return YES;
    }];
    
    [dragItem setDraggingFrame:self.bounds contents:previewImage];

    NSDraggingSession *draggingSession = [self beginDraggingSessionWithItems:@[ dragItem ] event:event source:self];
    draggingSession.animatesToStartingPositionsOnCancelOrFail = NO;
    draggingSession.draggingFormation = NSDraggingFormationNone;
}

- (void)pasteboard:(NSPasteboard *)sender item:(NSPasteboardItem *)item provideDataForType:(NSString *)type {
    if ([type compare: NSPasteboardTypeTIFF] == NSOrderedSame) {
        [sender setData:[self.image TIFFRepresentation] forType:NSPasteboardTypeTIFF];
        
    } else if ([type compare: NSPasteboardTypePNG] == NSOrderedSame) {
        [sender setData:[self.image.representations.lastObject representationUsingType:NSPNGFileType properties:nil] forType:NSPasteboardTypePNG];
    } else if ([type compare:@"public.image"] == NSOrderedSame) {
        [sender writeObjects:@[ self.image ]];
    }
}

#pragma mark - NSDragDestination

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    if (sender.draggingSource == self)
        return NSDragOperationNone;
    
	// Only thing we have to do here is confirm that the dragged file is an image. We use NSImage's +canInitWithPasteboard: and we also check to see there is only one item being dragged
	if ([self.delegate conformsToProtocol:@protocol(MMAnimatingImageViewDelegate)] &&  // No point in accepting the drop if the delegate doesn't support it/exist
		[NSImage canInitWithPasteboard:sender.draggingPasteboard] &&                   // Only Accept Images
		sender.draggingPasteboard.pasteboardItems.count == 1 &&
        self.shouldAllowDragging) {                        // Only accept one item
		return [self.delegate imageView:self draggingEntered:sender];
	}
	return NSDragOperationNone;
}

// Give the delegate some more control
- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender {
	if ([self.delegate conformsToProtocol:@protocol(MMAnimatingImageViewDelegate)] && self.shouldAllowDragging) {
		return [self.delegate imageView:self shouldPrepareForDragOperation:sender];
	}
	return NO;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
	if ([self.delegate conformsToProtocol:@protocol(MMAnimatingImageViewDelegate)] &&  // Only do the operation if a delegate exists to actually set the image.
		[self.delegate imageView:self shouldPerformDragOperation:sender]) {            // Only do the operation if a delegate wants us to do the operation.
		
		// Get the image from the pasteboard
		NSImage *im = [[NSImage alloc] initWithPasteboard:sender.draggingPasteboard];
		
		// Make an array of the valid drops (NSBitmapImageRep)
		NSMutableArray *acceptedDrops = [NSMutableArray arrayWithCapacity:im.representations.count];
		for (NSImageRep *rep in im.representations) {
			if (![rep isKindOfClass:[NSBitmapImageRep class]]) // We don't want PDFs
				continue;
			
			[acceptedDrops addObject:rep];
			
		}
		
		if (acceptedDrops.count > 0) {
			// We already confirmed that the delegate conforms to the protocol above. Now we can let the delegate
			// decide what to do with the dropped images.
			[self.delegate imageView:self didAcceptDroppedImages:acceptedDrops];
		}
		
		return YES;
	}
	
	return NO;
}

@end