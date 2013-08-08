//
//  GameLayer.h
//  DoodleDrop
//
//  Created by Martin on 13-8-8.
//  Copyright 2013年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "cocos2d.h"

@interface GameLayer : CCLayer {
    CCSprite *player;
    CGPoint  playerVelocity;
    
    NSMutableArray *spiders;
    float spiderMoveDuration;
    int numberSpiderMoved;
}
+ (id) scene;
@end
