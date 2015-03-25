//
//  MMPhysicsView.m
//  physics-2D-Verlet
//
//  Created by Adam Wulf on 3/22/15.
//  Copyright (c) 2015 Milestone made. All rights reserved.
//

#import "MMPhysicsView.h"
#import "MMPointPropsView.h"
#import "MMPoint.h"
#import "MMStick.h"
#import "MMPiston.h"

@implementation MMPhysicsView{
    CGFloat bounce;
    CGFloat gravity;
    CGFloat friction;
    
    NSMutableArray* points;
    NSMutableArray* sticks;
    
    MMPoint* grabbedPoint;
    
    UIPanGestureRecognizer* grabPointGesture;
    UIPanGestureRecognizer* createStickGesture;
    UIPanGestureRecognizer* createPistonGesture;
    
    UISwitch* animationOnOffSwitch;
    
    
    MMStick* currentEditedStick;
    
    
    MMPointPropsView* propertiesView;
    MMPoint* selectedPoint;
}

-(id) initWithFrame:(CGRect)frame{
    if(self = [super initWithFrame:frame]){
        self.backgroundColor = [UIColor whiteColor];
        
        bounce = 0.9;
        gravity = 0.5;
        friction = 0.999;
        
        points = [NSMutableArray array];
        sticks = [NSMutableArray array];
        
        propertiesView = [[MMPointPropsView alloc] initWithFrame:CGRectMake(20, 20, 200, 250)];
        [self addSubview:propertiesView];
        
        [self initializeData];
        
        CADisplayLink* displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkPresentRenderBuffer:)];
        displayLink.frameInterval = 2;
        [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        
        
        grabPointGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(movePointGesture:)];
        createStickGesture.enabled = NO;
        [self addGestureRecognizer:grabPointGesture];
        
        createStickGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(createStickGesture:)];
        [self addGestureRecognizer:createStickGesture];
        
        createPistonGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(createPistonGesture:)];
        createPistonGesture.enabled = NO;
        [self addGestureRecognizer:createPistonGesture];
        
        
        
        UITapGestureRecognizer* tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(screenTapped:)];
        [self addGestureRecognizer:tapGesture];
        
        
        
        animationOnOffSwitch = [[UISwitch alloc] init];
        animationOnOffSwitch.on = YES;
        animationOnOffSwitch.center = CGPointMake(self.bounds.size.width - 80, 40);
        
        UILabel* onOff = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 150, animationOnOffSwitch.bounds.size.height)];
        onOff.text = @"on/off";
        onOff.textAlignment = NSTextAlignmentRight;
        onOff.center = CGPointMake(animationOnOffSwitch.center.x - onOff.bounds.size.width, animationOnOffSwitch.center.y);
        [self addSubview:onOff];

        
        UISegmentedControl* createMode = [[UISegmentedControl alloc] initWithItems:@[@"make stick",@"make piston",@"move point"]];
        createMode.selectedSegmentIndex = 0;
        createMode.center = CGPointMake(self.bounds.size.width - 160, 80);
        [createMode addTarget:self  action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
        [self addSubview:createMode];
        [self addSubview:animationOnOffSwitch];
        
        
        UIButton* clearButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [clearButton setTitle:@"Clear" forState:UIControlStateNormal];
        [clearButton sizeToFit];
        [clearButton addTarget:self action:@selector(clearObjects) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:clearButton];
        clearButton.center = CGPointMake(self.bounds.size.width - 50, 200);
        
    }
    return self;
}

#pragma mark - Gesture


-(void) screenTapped:(UITapGestureRecognizer*)tapGesture{
    selectedPoint = [self getPointNear:[tapGesture locationInView:self]];
    [propertiesView showPointProperties:selectedPoint];
    
}

-(void) clearObjects{
    [points removeAllObjects];
    [sticks removeAllObjects];
}

-(void) modeChanged:(UISegmentedControl*)modeSegmentControl{
    grabPointGesture.enabled = modeSegmentControl.selectedSegmentIndex == 2;
    createStickGesture.enabled = modeSegmentControl.selectedSegmentIndex == 0;
    createPistonGesture.enabled = modeSegmentControl.selectedSegmentIndex == 1;
}

-(void) createStickGesture:(UIPanGestureRecognizer*)panGester{
    CGPoint currLoc = [panGester locationInView:self];
    if(panGester.state == UIGestureRecognizerStateBegan){

        MMPoint* startPoint = [self getPointNear:currLoc];
        
        if(!startPoint){
            startPoint = [MMPoint pointWithCGPoint:currLoc];
        }

        currentEditedStick = [MMStick stickWithP0:startPoint
                                            andP1:[MMPoint pointWithCGPoint:currLoc]];
    }else if(panGester.state == UIGestureRecognizerStateEnded ||
             panGester.state == UIGestureRecognizerStateFailed ||
             panGester.state == UIGestureRecognizerStateCancelled){
        
        MMPoint* startPoint = currentEditedStick.p0;
        MMPoint* endPoint = [self getPointNear:currLoc];
        if(!endPoint){
            endPoint = currentEditedStick.p1;
        }
        if(![points containsObject:startPoint]){
            [points addObject:startPoint];
        }
        if(![points containsObject:endPoint]){
            [points addObject:endPoint];
        }
        currentEditedStick = nil;

        [sticks addObject:[MMStick stickWithP0:startPoint andP1:endPoint]];
    }else if(currentEditedStick){
        currentEditedStick = [MMStick stickWithP0:currentEditedStick.p0
                                            andP1:[MMPoint pointWithCGPoint:currLoc]];
    }
}


-(void) createPistonGesture:(UIPanGestureRecognizer*)panGester{
    CGPoint currLoc = [panGester locationInView:self];
    if(panGester.state == UIGestureRecognizerStateBegan){
        
        MMPoint* startPoint = [self getPointNear:currLoc];
        
        if(!startPoint){
            startPoint = [MMPoint pointWithCGPoint:currLoc];
        }
        
        currentEditedStick = [MMStick stickWithP0:startPoint
                                            andP1:[MMPoint pointWithCGPoint:currLoc]];
    }else if(panGester.state == UIGestureRecognizerStateEnded ||
             panGester.state == UIGestureRecognizerStateFailed ||
             panGester.state == UIGestureRecognizerStateCancelled){
        
        MMPoint* startPoint = currentEditedStick.p0;
        MMPoint* endPoint = [self getPointNear:currLoc];
        if(!endPoint){
            endPoint = currentEditedStick.p1;
        }
        if(![points containsObject:startPoint]){
            [points addObject:startPoint];
        }
        if(![points containsObject:endPoint]){
            [points addObject:endPoint];
        }
        currentEditedStick = nil;
        
        [sticks addObject:[MMPiston pistonWithP0:startPoint andP1:endPoint]];
    }else if(currentEditedStick){
        currentEditedStick = [MMStick stickWithP0:currentEditedStick.p0
                                            andP1:[MMPoint pointWithCGPoint:currLoc]];
    }
}

-(void) movePointGesture:(UIPanGestureRecognizer*)panGester{
    CGPoint currLoc = [panGester locationInView:self];
    if(panGester.state == UIGestureRecognizerStateBegan){
        // find the point to grab
        grabbedPoint = [self getPointNear:currLoc];
    }
    
    if(panGester.state == UIGestureRecognizerStateEnded){
        MMPoint* pointToReplace = [[points filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
            return evaluatedObject != grabbedPoint && [evaluatedObject distanceFromPoint:grabbedPoint.asCGPoint] < 30;
        }]] firstObject];
        if(pointToReplace){
            for(int i=0;i<[sticks count];i++){
                MMStick* stick = [sticks objectAtIndex:i];
                if(stick.p0 == pointToReplace){
                    stick = [MMStick stickWithP0:grabbedPoint andP1:stick.p1];
                }else if(stick.p1 == pointToReplace){
                    stick = [MMStick stickWithP0:stick.p0 andP1:grabbedPoint];
                }
                [sticks replaceObjectAtIndex:i withObject:stick];
            }
            [points removeObject:pointToReplace];
        }
    }
}


#pragma mark - Data

-(void) initializeData{
    [points addObject:[MMPoint pointWithX:100 andY:100]];
    [points addObject:[MMPoint pointWithX:200 andY:100]];
    [points addObject:[MMPoint pointWithX:200 andY:200]];
    [points addObject:[MMPoint pointWithX:100 andY:200]];
    
    [sticks addObject:[MMStick stickWithP0:[points objectAtIndex:0]
                                     andP1:[points objectAtIndex:1]]];
    [sticks addObject:[MMStick stickWithP0:[points objectAtIndex:1]
                                     andP1:[points objectAtIndex:2]]];
    [sticks addObject:[MMStick stickWithP0:[points objectAtIndex:2]
                                     andP1:[points objectAtIndex:3]]];
    [sticks addObject:[MMStick stickWithP0:[points objectAtIndex:3]
                                     andP1:[points objectAtIndex:0]]];
    [sticks addObject:[MMStick stickWithP0:[points objectAtIndex:0]
                                     andP1:[points objectAtIndex:2]]];
    [sticks addObject:[MMStick stickWithP0:[points objectAtIndex:1]
                                     andP1:[points objectAtIndex:3]]];
    
    [points makeObjectsPerformSelector:@selector(bump)];
}


-(void) displayLinkPresentRenderBuffer:(CADisplayLink*)link{
    [self setNeedsDisplay];
}

#pragma mark - Animation Loop

-(void) drawRect:(CGRect)rect{
    // draw
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    
    // clear
    [[UIColor whiteColor] setFill];
    CGContextFillRect(context, rect);
    

    if(animationOnOffSwitch.on){
        // gravity + velocity etc
        [self updatePoints];
        [self tickMachines];
    }
    
    // constrain everything
    for(int i = 0; i < 5; i++) {
        [self enforceGesture];
        [self updateSticks];
        [self constrainPoints];
    }
    
    // remove stressed objects
    [self cullSticks];
    
    // render everything
    [self renderSticks];
    
    // render edit
    [currentEditedStick render];


    CGContextRestoreGState(context);
}


#pragma mark - Update Methods

-(void) tickMachines{
    for(MMStick* stick in sticks){
        if([stick isKindOfClass:[MMPiston class]]){
            [stick tick];
        }
    }
}

-(void) enforceGesture{
    if(grabbedPoint){
        if(grabPointGesture.state == UIGestureRecognizerStateBegan ||
           grabPointGesture.state == UIGestureRecognizerStateChanged){
            grabbedPoint.x = [grabPointGesture locationInView:self].x;
            grabbedPoint.y = [grabPointGesture locationInView:self].y;
        }
        if(!animationOnOffSwitch.on){
            for (MMPoint* p in points) {
                [p nullVelocity];
            }
        }
    }
}

-(void) updatePoints{
    for(int i = 0; i < [points count]; i++) {
        MMPoint* p = [points objectAtIndex:i];
        if(!p.immovable){
            CGFloat vx = (p.x - p.oldx) * friction;
            CGFloat vy = (p.y - p.oldy) * friction;
            
            p.oldx = p.x;
            p.oldy = p.y;
            p.x += vx;
            p.y += vy;
            p.y += gravity;
        }
    }
}

-(void) updateSticks{
    for(int i = 0; i < [sticks count]; i++) {
        MMStick* s = [sticks objectAtIndex:i];
        [s constrain];
    }
}

-(void) constrainPoints{
    for(int i = 0; i < [points count]; i++) {
        MMPoint* p = [points objectAtIndex:i];
        if(!p.immovable){
            CGFloat vx = (p.x - p.oldx) * friction;
            CGFloat vy = (p.y - p.oldy) * friction;
            
            if(p.x > self.bounds.size.width) {
                p.x = self.bounds.size.width;
                p.oldx = p.x + vx * bounce;
            }
            else if(p.x < 0) {
                p.x = 0;
                p.oldx = p.x + vx * bounce;
            }
            if(p.y > self.bounds.size.height) {
                p.y = self.bounds.size.height;
                p.oldy = p.y + vy * bounce;
            }
            else if(p.y < 0) {
                p.y = 0;
                p.oldy = p.y + vy * bounce;
            }
        }
    }
}

#pragma mark - Remove Stressed Objects

-(void) cullSticks{
    for(int i = 0; i < [sticks count]; i++) {
        MMStick* s = [sticks objectAtIndex:i];
        if(s.stress >= 1.0){
            // break stick
            [sticks removeObject:s];
            // clean up unused points
            // remove s.p0, s.p1 if needed
            // later. TODO!
            i--;
        }
    }
}

#pragma mark - Render

-(void) renderSticks{
    for(MMStick* stick in sticks){
        [stick render];
    }
}



#pragma mark - Helper

-(MMPoint*) getPointNear:(CGPoint)point{
    return [[points filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return [evaluatedObject distanceFromPoint:point] < 30;
    }]] firstObject];
}

@end
