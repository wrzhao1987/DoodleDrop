//
//  GameLayer.m
//  DoodleDrop
//
//  Created by Martin on 13-8-8.
//  Copyright 2013年 __MyCompanyName__. All rights reserved.
//

#import "GameLayer.h"
#import "SimpleAudioEngine.h"


@implementation GameLayer

+ (id) scene
{
    CCScene *scene = [CCScene node];
    CCLayer *layer = [GameLayer node];
    [scene addChild: layer];
    return scene;
}

- (id) init
{
    if (self = [super init])
    {
        CCLOG(@"%@: %@", NSStringFromSelector(_cmd), self);
        
        self.isAccelerometerEnabled = YES;
        
        player = [CCSprite spriteWithFile:@"alien.png"];
        [self addChild: player z: 0 tag: 1];
        
        CGSize screenSize = [CCDirector sharedDirector].winSize;
        float imageHeight = player.texture.contentSize.height;
        player.position   = CGPointMake(screenSize.width / 2, imageHeight / 2);
        
        // 设定 - (void) update: (ccTime) delta 方法每帧被调用一次
        [self scheduleUpdate];
        [self initSpiders];
        
        scoreLabel = [CCLabelTTF labelWithString:@"0" fontName: @"Arial" fontSize: 48];
//        scoreLabel = [CCLabelBMFont labelWithString: @"0" fntFile: @"bitmapfont.fnt"];
        scoreLabel.position = CGPointMake(screenSize.width /2, screenSize.height);
        
        // 调整标签的锚点y位置，来使其定位于顶部
        scoreLabel.anchorPoint = CGPointMake(0.5f, 1.0f);
        
        // 将计分板的z值设定为-1，这样它将被draw在所有东西下面
        [self addChild:scoreLabel z:-1];
        [[SimpleAudioEngine sharedEngine] playBackgroundMusic: @"blues.mp3" loop: YES];
        [[SimpleAudioEngine sharedEngine] preloadEffect: @"alien-sfx.caf"];
    }
    return self;
}

- (void) accelerometer:(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *)acceleration
{
    
    // 控制减速快慢，该值越小容易改变玩家方向
    float deceleration = 0.4f;
    // 决定加速器的灵敏度，该值越大越灵敏
    float sensitivity = 0.6f;
    // 速度最大值
    float maxVelocity = 100;
    
    // 根据当前加速器加速情况调整速度
    playerVelocity.x = playerVelocity.x * deceleration + acceleration.x * sensitivity;
    // 从两个方向限制玩家的最大速度
    if (playerVelocity.x > maxVelocity)
    {
        playerVelocity.x = maxVelocity;
    }
    else if (playerVelocity.x - maxVelocity)
    {
        playerVelocity.x = - maxVelocity;
    }
}

- (void) update: (ccTime) delta
{
    // 持续添加玩家速度矢量到玩家当前位置
    CGPoint pos = player.position;
    pos.x += playerVelocity.x;
    
    // 玩家在到达屏幕边缘处时应该停下
    CGSize screenSize = [CCDirector sharedDirector].winSize;
    float imageWidthHalved = player.texture.contentSize.width * 0.5f;
    float leftBorderLimit  = imageWidthHalved;
    float rightBorderLimit = screenSize.width - imageWidthHalved;
    
    // 防止玩家移动出屏幕外
    if (pos.x < leftBorderLimit)
    {
        pos.x = leftBorderLimit;
        playerVelocity = CGPointZero;
    }
    else if (pos.x > rightBorderLimit)
    {
        pos.x = rightBorderLimit;
        playerVelocity = CGPointZero;
    }
    
    // 将设定好的位置设定为玩家的新位置
    player.position = pos;
    
    [self checkForCollision];
    score = [CCDirector sharedDirector].totalFrames;
    [scoreLabel setString: [NSString stringWithFormat: @"%i", score]];
}

- (void) initSpiders
{
    CGSize screenSize = [CCDirector sharedDirector].winSize;
    
    // 使用一个临时的spider精灵使获得图片大小的最简单方式
    CCSprite *tempSpider = [CCSprite spriteWithFile: @"spider.png"];
    
    float imageWidth = tempSpider.texture.contentSize.width;
    
    // 在挤满整个屏幕宽度的情况下，尽可能多的塞spider进来(一个挨着一个，不重叠）
    int numberSpiders = screenSize.width / imageWidth;
    
    // 初始化spiders
    spiders = [NSMutableArray arrayWithCapacity: numberSpiders];
    for (int i = 0; i < numberSpiders; i++) {
        CCSprite *spider = [CCSprite spriteWithFile: @"spider.png"];
        [self addChild: spider z: 0 tag: 2];
        
        //并且把spider加到spider数组
        [spiders addObject: spider];
    }
    // 调用方法重新定位所有蜘蛛
    [self resetSpiders];
}

- (void) resetSpiders
{
    CGSize screenSize = [CCDirector sharedDirector].winSize;
    // 初始化已经在移动的spider个数和从top到bottom的初始时间长度
    numberSpiderMoved = 0;
    spiderMoveDuration = 4.0f;
    
    // 获得任意spider来获取纹理宽度
    CCSprite *tempSpider = [spiders lastObject];
    CGSize size = tempSpider.texture.contentSize;
    int numberSpiders = spiders.count;
    for (int i = 0; i < numberSpiders; i++) {
        // 将每个spider放置在指定位置的屏幕外（实现一个从屏幕上方掉落的效果）
        CCSprite *spider = [spiders objectAtIndex: i];
        spider.position = CGPointMake(size.width * i + size.width * 0.5f, screenSize.height + size.height * 0.5f);
        
        [spider stopAllActions];
    }
    
    // 设定根据给定间隔时间来更新spider的逻辑
    [self schedule: @selector(spiderUpdate:) interval: 0.7f];
    
}

- (void) spiderUpdate: (ccTime) delta
{
    // 试图获取一个没有在移动的spider
    for (int i = 0; i < 10; i++)
    {
        int randomSpiderIndex = CCRANDOM_0_1() * spiders.count;
        CCSprite *spider = [spiders objectAtIndex: randomSpiderIndex];
        
        // 如果一个spider没有移动，那么它应该没有任何action才对
        if (spider.numberOfRunningActions == 0)
        {
            // 以下是一个控制spider动作的操作序列
            [self runSpiderMoveSequence: spider];
            // 一次应该只有一个蜘蛛开始活动
            break;
        }
    }
}

- (void) runSpiderMoveSequence: (CCSprite *) spider
{
    // 慢慢加快spider的速度
    numberSpiderMoved++;
    if (numberSpiderMoved % 8 == 0 && spiderMoveDuration > 2.0f)
    {
        spiderMoveDuration -= 0.2f;
    }
    
    // 控制spider动作的序列
    CGPoint belowScreenPosition = CGPointMake(spider.position.x,  -spider.texture.contentSize.height);
    CCMoveTo *move = [CCMoveTo actionWithDuration: spiderMoveDuration position: belowScreenPosition];
    CCCallBlock *callDidDrop = [CCCallBlock actionWithBlock: ^void() {
       // 将掉落的蜘蛛重新放回屏幕顶部
        CGPoint pos = spider.position;
        CGSize screenSize = [CCDirector sharedDirector].winSize;
        pos.y = screenSize.height + spider.texture.contentSize.height * 0.5f;
        spider.position = pos;
    }];
    CCSequence *sequence = [CCSequence actions:move, callDidDrop, nil];
    [spider runAction:sequence];
}

- (void) checkForCollision
{
    // 假定：所有玩家和spider的图像都为正方形
    float playerImageSize = player.texture.contentSize.width;
    CCSprite *spider = [spiders lastObject];
    float spiderImageSize = spider.texture.contentSize.width;
    float playerCollisionRadius = playerImageSize * 0.4f;
    float spiderCollisionRadius = spiderImageSize * 0.4f;
    
    // 此碰撞距离将约等于图形形状？ (This collision distance will roughly equal the image shapes.)
    float maxCollisionDistance = playerCollisionRadius + spiderCollisionRadius;
    
    int numberSpiders = spiders.count;
    for (int i = 0 ; i < numberSpiders; i++) {
        spider = [spiders objectAtIndex: i];
        if (spider.numberOfRunningActions == 0) {
            // 已经移动到底的spider不需要碰撞检测
            continue;
        }
        
        // 获得玩家和spider之间的距离
        float actualDistance = ccpDistance(player.position, spider.position);
        
        // 两个物体是否太近了？
        if (actualDistance < maxCollisionDistance) {
            // Game Over, 目前只是重新开始游戏
            [self resetGame];
        }
    }
}

- (void) resetGame
{
    [self resetSpiders];
    score = 0;
    [scoreLabel setString:@"0"];
    [[SimpleAudioEngine sharedEngine] playEffect: @"alien-sfx.caf"];
}

#if DEBUG
- (void) draw
{
    [super draw];
    
    // 遍历所有layer的node
    for (CCNode *node in [self children]) {
        // 确保node是一个CCSprite并且有正确的tag
        if ([node isKindOfClass:[CCSprite class]] && (node.tag == 1 || node.tag == 2)){
            // 精灵的碰撞半径是其宽度的百分之X
            CCSprite *sprite = (CCSprite *) node;
            float radius = sprite.texture.contentSize.width * 0.4f;
            float angle  = 0;
            int numSegments = 10;
            bool drawLineToCenter = NO;
            ccDrawCircle(sprite.position, radius, angle, numSegments, drawLineToCenter);
        }
    }
}
#endif
- (void) dealloc
{
    CCLOG(@"%@: %@", NSStringFromSelector(_cmd), self);
}

@end
