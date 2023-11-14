//
//  SVGAOptimizedPlayer.m
//  SVGAParsePlayer_Demo
//
//  Created by aa on 2023/11/6.
//

#import "SVGAOptimizedPlayer.h"
#import <SVGAPlayer/SVGAVideoSpriteEntity.h>
#import <SVGAPlayer/SVGAContentLayer.h>
#import <SVGAPlayer/SVGABitmapLayer.h>
#import <SVGAPlayer/SVGAAudioLayer.h>
#import <SVGAPlayer/SVGAAudioEntity.h>
#import <pthread.h>

#ifdef DEBUG
#define _JPLog(format, ...) printf("[%s] %s [第%d行] %s\n", [[[SVGAOptimizedPlayer dateFormatter] stringFromDate:[NSDate date]] UTF8String], __FUNCTION__, __LINE__, [[NSString stringWithFormat:format, ## __VA_ARGS__] UTF8String]);
#else
#define _JPLog(format, ...)
#endif

static inline void _jp_dispatch_sync_on_main_queue(void (^block)(void)) {
    if (pthread_main_np()) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

@interface _JPProxy : NSProxy
@property (nonatomic, weak, readonly) id target;
- (instancetype)initWithTarget:(id)target;
+ (instancetype)proxyWithTarget:(id)target;
@end

@implementation _JPProxy
- (instancetype)initWithTarget:(id)target {
    _target = target;
    return self;
}
+ (instancetype)proxyWithTarget:(id)target {
    return [[_JPProxy alloc] initWithTarget:target];
}
- (id)forwardingTargetForSelector:(SEL)selector {
    return _target;
}
- (void)forwardInvocation:(NSInvocation *)invocation {
    void *null = NULL;
    [invocation setReturnValue:&null];
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [NSObject instanceMethodSignatureForSelector:@selector(init)];
}
- (BOOL)respondsToSelector:(SEL)aSelector {
    return [_target respondsToSelector:aSelector];
}
- (BOOL)isEqual:(id)object {
    return [_target isEqual:object];
}
- (NSUInteger)hash {
    return [_target hash];
}
- (Class)superclass {
    return [_target superclass];
}
- (Class)class {
    return [_target class];
}
- (BOOL)isKindOfClass:(Class)aClass {
    return [_target isKindOfClass:aClass];
}
- (BOOL)isMemberOfClass:(Class)aClass {
    return [_target isMemberOfClass:aClass];
}
- (BOOL)conformsToProtocol:(Protocol *)aProtocol {
    return [_target conformsToProtocol:aProtocol];
}
- (BOOL)isProxy {
    return YES;
}
- (NSString *)description {
    return [_target description];
}
- (NSString *)debugDescription {
    return [_target debugDescription];
}
@end

@interface SVGAOptimizedPlayer ()
@property (nonatomic, strong) CALayer *drawLayer;
@property (nonatomic, copy) NSArray<SVGAContentLayer *> *contentLayers;
@property (nonatomic, copy) NSArray<SVGAAudioLayer *> *audioLayers;

@property (nonatomic, copy) NSDictionary<NSString *, UIImage *> *dynamicObjects;
@property (nonatomic, copy) NSDictionary<NSString *, NSAttributedString *> *dynamicTexts;
@property (nonatomic, copy) NSDictionary<NSString *, NSNumber *> *dynamicHiddens;

@property (nonatomic, strong) CADisplayLink *displayLink;
@end

@implementation SVGAOptimizedPlayer

#ifdef DEBUG
+ (NSDateFormatter *)dateFormatter {
    static NSDateFormatter *dateFormatter_ = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter_ = [[NSDateFormatter alloc] init];
        [dateFormatter_ setDateFormat:@"hh:mm:ss:SS"];
    });
    return dateFormatter_;
}
#endif

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self initPlayer];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        [self initPlayer];
    }
    return self;
}

- (void)initPlayer {
//    _JPLog(@"[%p] alloc", self);
    self.contentMode = UIViewContentModeTop;
    _mainRunLoopMode = NSRunLoopCommonModes;
    _clearsAfterStop = YES;
    _loops = 0;
    _loopCount = 0;
    _isReversing = NO;
    _isMute = NO;
    _startFrame = 0;
    _endFrame = 0;
    _currentFrame = 0;
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    [super willMoveToSuperview:newSuperview];
    if (newSuperview == nil) {
        [self stopAnimation:YES];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self __resize];
}

- (void)dealloc {
    [self stopAnimation:YES];
//    _JPLog(@"[%p] dealloc", self);
}

#pragma mark - Setter & Getter

- (void)setMainRunLoopMode:(NSRunLoopMode)mainRunLoopMode {
    if ([_mainRunLoopMode isEqual:mainRunLoopMode]) return;
    if (self.displayLink) {
        if (_mainRunLoopMode) {
            [self.displayLink removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:_mainRunLoopMode];
        }
        if (mainRunLoopMode.length) {
            [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:mainRunLoopMode];
        }
    }
    _mainRunLoopMode = mainRunLoopMode.copy;
}

- (void)setLoops:(NSInteger)loops {
    _loops = loops;
    _loopCount = 0;
}

- (void)setIsReversing:(BOOL)isReversing {
    if (_isReversing == isReversing) return;
    _isReversing = isReversing;
    
    _jp_dispatch_sync_on_main_queue(^{
        if (self.isAnimating || self.drawLayer == nil) return;
        if (self->_isReversing && self->_currentFrame == self->_startFrame) {
            self->_currentFrame = self->_endFrame;
            [self __update];
        } else if (!self->_isReversing && self->_currentFrame == self->_endFrame) {
            self->_currentFrame = self->_startFrame;
            [self __update];
        }
    });
}

- (void)setIsMute:(BOOL)isMute {
    if (_isMute == isMute) return;
    _isMute = isMute;
    
    float volume = isMute ? 0 : 1;
    for (SVGAAudioLayer *layer in self.audioLayers) {
        layer.audioPlayer.volume = volume;
    }
}

- (void)setVideoItem:(SVGAVideoEntity *)videoItem {
    [self setVideoItem:videoItem
            startFrame:0
              endFrame:(videoItem.frames > 0 ? (videoItem.frames - 1) : 0)];
}

- (NSInteger)frameCount {
    return _videoItem.frames;
}

- (NSInteger)minFrame {
    return 0;
}

- (NSInteger)maxFrame {
    NSInteger frameCount = self.frameCount;
    return frameCount > 0 ? (frameCount - 1) : 0;
}

- (NSInteger)leadingFrame {
    return _isReversing ? _endFrame : _startFrame;
}

- (NSInteger)trailingFrame {
    return _isReversing ? _startFrame : _endFrame;
}

- (NSTimeInterval)duration {
    if (_videoItem && _videoItem.frames > 0 && _videoItem.FPS > 0) {
        int frames = _videoItem.frames;
        int FPS = _videoItem.FPS;
        return (NSTimeInterval)frames / (NSTimeInterval)FPS;
    }
    return 0;
}

- (BOOL)isAnimating {
    return self.displayLink != nil;
}

- (BOOL)isFinishedAll {
    return _loops > 0 && _loopCount >= _loops;
}

#pragma mark - 公开方法

#pragma mark 检验SVGA资源
+ (SVGAVideoEntityError)checkVideoItem:(SVGAVideoEntity *)videoItem {
    if (videoItem.videoSize.width <= 0 || videoItem.videoSize.height <= 0) {
        _JPLog(@"[%p] SVGA资源有问题：videoSize是0！", self);
        return SVGAVideoEntityError_ZeroVideoSize;
    }
    else if (videoItem.FPS == 0) {
        _JPLog(@"[%p] SVGA资源有问题：FPS是0！", self);
        return SVGAVideoEntityError_ZeroFPS;
    }
    else if (videoItem.frames == 0) {
        _JPLog(@"[%p] SVGA资源有问题：frames是0！", self);
        return SVGAVideoEntityError_ZeroFrames;
    }
//    _JPLog(@"[%p] SVGA资源没问题！", self);
    return SVGAVideoEntityError_None;
}

#pragma mark 更换SVGA资源+设置播放区间
- (void)setVideoItem:(SVGAVideoEntity *)videoItem
        currentFrame:(NSInteger)currentFrame {
    [self setVideoItem:videoItem
            startFrame:0
              endFrame:(videoItem.frames > 0 ? (videoItem.frames - 1) : 0)
          currentFrame:currentFrame];
}
- (void)setVideoItem:(SVGAVideoEntity *)videoItem
          startFrame:(NSInteger)startFrame
            endFrame:(NSInteger)endFrame {
    [self setVideoItem:videoItem
            startFrame:startFrame
              endFrame:endFrame
          currentFrame:(_isReversing ? endFrame : startFrame)];
}
- (void)setVideoItem:(SVGAVideoEntity *)videoItem
          startFrame:(NSInteger)startFrame
            endFrame:(NSInteger)endFrame
        currentFrame:(NSInteger)currentFrame {
    if (_videoItem == nil && videoItem == nil) return;
    [self stopAnimation:YES];
    
    if (videoItem && [SVGAOptimizedPlayer checkVideoItem:videoItem] == SVGAVideoEntityError_None) {
        _videoItem = videoItem;
    } else {
        _videoItem = nil;
    }
    _loopCount = 0;
    
    [self setStartFrame:startFrame
               endFrame:endFrame
           currentFrame:currentFrame];
}

#pragma mark 设置播放区间
- (void)resetStartFrameAndEndFrame {
    [self setStartFrame:self.minFrame
               endFrame:self.maxFrame
           currentFrame:_currentFrame];
}
- (void)setStartFrameUntilTheEnd:(NSInteger)startFrame {
    [self setStartFrame:startFrame
               endFrame:self.maxFrame
           currentFrame:_currentFrame];
}
- (void)setEndFrameFromBeginning:(NSInteger)endFrame {
    [self setStartFrame:self.minFrame
               endFrame:endFrame
           currentFrame:_currentFrame];
}
- (void)setStartFrame:(NSInteger)startFrame endFrame:(NSInteger)endFrame {
    [self setStartFrame:startFrame
               endFrame:endFrame
           currentFrame:_currentFrame];
}
- (void)setStartFrame:(NSInteger)startFrame endFrame:(NSInteger)endFrame currentFrame:(NSInteger)currentFrame {
    NSInteger frameCount = _videoItem.frames;
    
    if (frameCount <= 1) {
        _startFrame = 0;
        _endFrame = 0;
        _currentFrame = 0;
        if (!self.isAnimating) {
            [self __resetDrawLayerIfNeed:YES];
        }
        return;
    }
    
    if (endFrame < 0) {
        endFrame = 0;
    } else if (endFrame >= frameCount) {
        endFrame = frameCount > 0 ? (frameCount - 1) : 0;
    }
    
    if (startFrame < 0) {
        startFrame = 0;
    } else if (startFrame > endFrame) {
        startFrame = endFrame;
    }
    
    if (currentFrame < startFrame) {
        currentFrame = startFrame;
    } else if (currentFrame > endFrame) {
        currentFrame = endFrame;
    }
    
    _startFrame = startFrame;
    _endFrame = endFrame;
    _currentFrame = currentFrame;
    
    if (!self.isAnimating) {
        [self __resetDrawLayerIfNeed:YES];
    }
}

#pragma mark 重置loopCount
- (void)resetLoopCount {
    _loopCount = 0;
}

#pragma mark 开始播放
- (BOOL)startAnimation {
    [self stopAnimation:NO];
    
    if (self.videoItem == nil) {
        _JPLog(@"[%p] videoItem是空的", self);
        return NO;
    }
    
    if (self.superview == nil) {
        _JPLog(@"[%p] superview是空的", self);
        return NO;
    }
    
    if (self.isFinishedAll) {
        _loopCount = 0;
    }
    
    NSInteger frame = _currentFrame;
    if (_isReversing) {
        if (frame <= _startFrame) {
            frame = _endFrame;
        }
    } else {
        if (frame >= _endFrame) {
            frame = _startFrame;
        }
    }
    
    BOOL isNeedUpdate = _currentFrame != frame;
    _currentFrame = frame;
    
    [self __resetDrawLayerIfNeed:isNeedUpdate];
    [self __addLink];
    
    return YES;
}

#pragma mark 跳至指定帧
- (BOOL)stepToFrame:(NSInteger)frame {
    return [self stepToFrame:frame andPlay:NO];
}
- (BOOL)stepToFrame:(NSInteger)frame andPlay:(BOOL)andPlay {
    [self stopAnimation:NO];
    
    if (self.videoItem == nil) {
        _JPLog(@"[%p] videoItem是空的", self);
        return NO;
    }
    
    if (self.superview == nil) {
        _JPLog(@"[%p] superview是空的", self);
        return NO;
    }
    
    if (self.isFinishedAll) {
        _loopCount = 0;
    }
    
    if (frame < self.minFrame) {
        _JPLog(@"[%p] 给的frame超出了总frames的范围！这里给你修正！", self);
        frame = self.minFrame;
    } else if (frame > self.maxFrame) {
        _JPLog(@"[%p] 给的frame超出了总frames的范围！这里给你修正！", self);
        frame = self.maxFrame;
    }
    
    BOOL isNeedUpdate = _currentFrame != frame;
    _currentFrame = frame;
    
    [self __resetDrawLayerIfNeed:isNeedUpdate];
    if (andPlay) {
        [self __addLink];
    }
    
    return YES;
}

#pragma mark 暂停播放
- (void)pauseAnimation {
    [self stopAnimation:NO];
}

#pragma mark 停止播放
- (void)stopAnimation {
    [self stopAnimation:self.clearsAfterStop];
}
- (void)stopAnimation:(BOOL)isClear {
    [self __removeLink];
    [self __stopAudios];
    if (isClear) {
        [self __clear];
    }
}

#pragma mark - 私有方法

/// 停止音频播放
- (void)__stopAudios {
    for (SVGAAudioLayer *layer in self.audioLayers) {
        if (layer.audioPlaying) {
            [layer.audioPlayer stop];
            layer.audioPlaying = NO;
        }
    }
}

/// 重置图层
- (void)__resetDrawLayerIfNeed:(BOOL)isNeedUpdate {
    _jp_dispatch_sync_on_main_queue(^{
        if (self.videoItem == nil) {
            [self __clear];
            return;
        }
        if (self.drawLayer == nil) {
            [self __clear];
            [self __draw];
        } else if (isNeedUpdate) {
            [self __update];
        }
    });
}

/// 清空图层
- (void)__clear {
//    _JPLog(@"[%p] __clear", self);
    self.audioLayers = nil;
    self.contentLayers = nil;
    [self.drawLayer removeFromSuperlayer];
    self.drawLayer = nil;
}

/// 绘制图层
- (void)__draw {
//    _JPLog(@"[%p] __draw", self);
    self.drawLayer = [[CALayer alloc] init];
    self.drawLayer.frame = CGRectMake(0, 0, self.videoItem.videoSize.width, self.videoItem.videoSize.height);
    self.drawLayer.masksToBounds = true;
    
    NSMutableDictionary *tempHostLayers = [NSMutableDictionary dictionary];
    NSMutableArray *tempContentLayers = [NSMutableArray array];
    [self.videoItem.sprites enumerateObjectsUsingBlock:^(SVGAVideoSpriteEntity * _Nonnull sprite, NSUInteger idx, BOOL * _Nonnull stop) {
        UIImage *bitmap;
        if (sprite.imageKey != nil) {
            NSString *bitmapKey = [sprite.imageKey stringByDeletingPathExtension];
            if (self.dynamicObjects[bitmapKey] != nil) {
                bitmap = self.dynamicObjects[bitmapKey];
            }
            else {
                bitmap = self.videoItem.images[bitmapKey];
            }
        }
        SVGAContentLayer *contentLayer = [sprite requestLayerWithBitmap:bitmap];
        contentLayer.imageKey = sprite.imageKey;
        [tempContentLayers addObject:contentLayer];
        if ([sprite.imageKey hasSuffix:@".matte"]) {
            CALayer *hostLayer = [[CALayer alloc] init];
            hostLayer.mask = contentLayer;
            tempHostLayers[sprite.imageKey] = hostLayer;
        } else {
            if (sprite.matteKey && sprite.matteKey.length > 0) {
                CALayer *hostLayer = tempHostLayers[sprite.matteKey];
                [hostLayer addSublayer:contentLayer];
                if (![sprite.matteKey isEqualToString:self.videoItem.sprites[idx - 1].matteKey]) {
                    [self.drawLayer addSublayer:hostLayer];
                }
            } else {
                [self.drawLayer addSublayer:contentLayer];
            }
        }
        if (sprite.imageKey != nil) {
            if (self.dynamicTexts[sprite.imageKey] != nil) {
                NSAttributedString *text = self.dynamicTexts[sprite.imageKey];
                CGSize bitmapSize = CGSizeMake(self.videoItem.images[sprite.imageKey].size.width * self.videoItem.images[sprite.imageKey].scale, self.videoItem.images[sprite.imageKey].size.height * self.videoItem.images[sprite.imageKey].scale);
                CGSize size = [text boundingRectWithSize:bitmapSize
                                                 options:NSStringDrawingUsesLineFragmentOrigin
                                                 context:NULL].size;
                CATextLayer *textLayer = [CATextLayer layer];
                textLayer.contentsScale = [[UIScreen mainScreen] scale];
                [textLayer setString:self.dynamicTexts[sprite.imageKey]];
                textLayer.frame = CGRectMake(0, 0, size.width, size.height);
                [contentLayer addSublayer:textLayer];
                contentLayer.textLayer = textLayer;
                [contentLayer resetTextLayerProperties:text];
            }
            if (self.dynamicHiddens[sprite.imageKey] != nil &&
                [self.dynamicHiddens[sprite.imageKey] boolValue] == YES) {
                contentLayer.dynamicHidden = YES;
            }
        }
    }];
    self.contentLayers = tempContentLayers.copy;
    
    [self.layer addSublayer:self.drawLayer];
    
    NSMutableArray *audioLayers = [NSMutableArray array];
    [self.videoItem.audios enumerateObjectsUsingBlock:^(SVGAAudioEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        SVGAAudioLayer *audioLayer = [[SVGAAudioLayer alloc] initWithAudioItem:obj videoItem:self.videoItem];
        [audioLayers addObject:audioLayer];
    }];
    self.audioLayers = audioLayers.copy;
    
    [self __update];
    [self __resize];
}

/// 更新图层+音频
- (void)__update {
    [CATransaction setDisableActions:YES];
    for (SVGAContentLayer *layer in self.contentLayers) {
        if ([layer isKindOfClass:[SVGAContentLayer class]]) {
            [layer stepToFrame:self.currentFrame];
        }
    }
    [CATransaction setDisableActions:NO];
    
    // 反转时、停止时 不播放音频
    if (!self.isReversing && self.isAnimating && self.audioLayers.count > 0) {
        for (SVGAAudioLayer *layer in self.audioLayers) {
            if (!layer.audioPlaying && layer.audioItem.startFrame <= self.currentFrame && self.currentFrame <= layer.audioItem.endFrame) {
                layer.audioPlayer.volume = self.isMute ? 0 : 1; // JP修改_设置是否静音
                [layer.audioPlayer setCurrentTime:(NSTimeInterval)(layer.audioItem.startTime / 1000)];
                [layer.audioPlayer play];
                layer.audioPlaying = YES;
            }
            if (layer.audioPlaying && layer.audioItem.endFrame <= self.currentFrame) {
                [layer.audioPlayer stop];
                layer.audioPlaying = NO;
            }
        }
    }
}

/// 适配图层
- (void)__resize {
    if (self.contentMode == UIViewContentModeScaleAspectFit) {
        CGFloat videoRatio = self.videoItem.videoSize.width / self.videoItem.videoSize.height;
        CGFloat layerRatio = self.bounds.size.width / self.bounds.size.height;
        if (videoRatio > layerRatio) {
            CGFloat ratio = self.bounds.size.width / self.videoItem.videoSize.width;
            CGPoint offset = CGPointMake(
                                         (1.0 - ratio) / 2.0 * self.videoItem.videoSize.width,
                                         (1.0 - ratio) / 2.0 * self.videoItem.videoSize.height
                                         - (self.bounds.size.height - self.videoItem.videoSize.height * ratio) / 2.0
                                         );
            self.drawLayer.transform = CATransform3DMakeAffineTransform(CGAffineTransformMake(ratio, 0, 0, ratio, -offset.x, -offset.y));
        }
        else {
            CGFloat ratio = self.bounds.size.height / self.videoItem.videoSize.height;
            CGPoint offset = CGPointMake(
                                         (1.0 - ratio) / 2.0 * self.videoItem.videoSize.width - (self.bounds.size.width - self.videoItem.videoSize.width * ratio) / 2.0,
                                         (1.0 - ratio) / 2.0 * self.videoItem.videoSize.height);
            self.drawLayer.transform = CATransform3DMakeAffineTransform(CGAffineTransformMake(ratio, 0, 0, ratio, -offset.x, -offset.y));
        }
    }
    else if (self.contentMode == UIViewContentModeScaleAspectFill) {
        CGFloat videoRatio = self.videoItem.videoSize.width / self.videoItem.videoSize.height;
        CGFloat layerRatio = self.bounds.size.width / self.bounds.size.height;
        if (videoRatio < layerRatio) {
            CGFloat ratio = self.bounds.size.width / self.videoItem.videoSize.width;
            CGPoint offset = CGPointMake(
                                         (1.0 - ratio) / 2.0 * self.videoItem.videoSize.width,
                                         (1.0 - ratio) / 2.0 * self.videoItem.videoSize.height
                                         - (self.bounds.size.height - self.videoItem.videoSize.height * ratio) / 2.0
                                         );
            self.drawLayer.transform = CATransform3DMakeAffineTransform(CGAffineTransformMake(ratio, 0, 0, ratio, -offset.x, -offset.y));
        }
        else {
            CGFloat ratio = self.bounds.size.height / self.videoItem.videoSize.height;
            CGPoint offset = CGPointMake(
                                         (1.0 - ratio) / 2.0 * self.videoItem.videoSize.width - (self.bounds.size.width - self.videoItem.videoSize.width * ratio) / 2.0,
                                         (1.0 - ratio) / 2.0 * self.videoItem.videoSize.height);
            self.drawLayer.transform = CATransform3DMakeAffineTransform(CGAffineTransformMake(ratio, 0, 0, ratio, -offset.x, -offset.y));
        }
    }
    else if (self.contentMode == UIViewContentModeTop) {
        CGFloat scaleX = self.frame.size.width / self.videoItem.videoSize.width;
        CGPoint offset = CGPointMake((1.0 - scaleX) / 2.0 * self.videoItem.videoSize.width, (1 - scaleX) / 2.0 * self.videoItem.videoSize.height);
        self.drawLayer.transform = CATransform3DMakeAffineTransform(CGAffineTransformMake(scaleX, 0, 0, scaleX, -offset.x, -offset.y));
    }
    else if (self.contentMode == UIViewContentModeBottom) {
        CGFloat scaleX = self.frame.size.width / self.videoItem.videoSize.width;
        CGPoint offset = CGPointMake(
                                     (1.0 - scaleX) / 2.0 * self.videoItem.videoSize.width,
                                     (1.0 - scaleX) / 2.0 * self.videoItem.videoSize.height);
        self.drawLayer.transform = CATransform3DMakeAffineTransform(CGAffineTransformMake(scaleX, 0, 0, scaleX, -offset.x, -offset.y + self.frame.size.height - self.videoItem.videoSize.height * scaleX));
    }
    else if (self.contentMode == UIViewContentModeLeft) {
        CGFloat scaleY = self.frame.size.height / self.videoItem.videoSize.height;
        CGPoint offset = CGPointMake((1.0 - scaleY) / 2.0 * self.videoItem.videoSize.width, (1 - scaleY) / 2.0 * self.videoItem.videoSize.height);
        self.drawLayer.transform = CATransform3DMakeAffineTransform(CGAffineTransformMake(scaleY, 0, 0, scaleY, -offset.x, -offset.y));
    }
    else if (self.contentMode == UIViewContentModeRight) {
        CGFloat scaleY = self.frame.size.height / self.videoItem.videoSize.height;
        CGPoint offset = CGPointMake(
                                     (1.0 - scaleY) / 2.0 * self.videoItem.videoSize.width,
                                     (1.0 - scaleY) / 2.0 * self.videoItem.videoSize.height);
        self.drawLayer.transform = CATransform3DMakeAffineTransform(CGAffineTransformMake(scaleY, 0, 0, scaleY, -offset.x + self.frame.size.width - self.videoItem.videoSize.width * scaleY, -offset.y));
    }
    else {
        CGFloat scaleX = self.frame.size.width / self.videoItem.videoSize.width;
        CGFloat scaleY = self.frame.size.height / self.videoItem.videoSize.height;
        CGPoint offset = CGPointMake((1.0 - scaleX) / 2.0 * self.videoItem.videoSize.width, (1 - scaleY) / 2.0 * self.videoItem.videoSize.height);
        self.drawLayer.transform = CATransform3DMakeAffineTransform(CGAffineTransformMake(scaleX, 0, 0, scaleY, -offset.x, -offset.y));
    }
}

#pragma mark - Display Link

- (void)__addLink {
    [self __removeLink];
//    _JPLog(@"[%p] 开启定时器，此时startFrame: %zd, endFrame: %zd, currentFrame: %zd, loopCount: %zd", self, self.startFrame, self.endFrame, self.currentFrame, self.loopCount);
    self.displayLink = [CADisplayLink displayLinkWithTarget:[_JPProxy proxyWithTarget:self] selector:@selector(__next)];
    self.displayLink.preferredFramesPerSecond = self.videoItem.FPS;
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:self.mainRunLoopMode];
}

- (void)__removeLink {
    if (self.displayLink) {
//        _JPLog(@"[%p] 关闭定时器，此时startFrame: %zd, endFrame: %zd, currentFrame: %zd, loopCount: %zd", self, self.startFrame, self.endFrame, self.currentFrame, self.loopCount);
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
}

- (void)__next {
    id delegate = self.delegate;
    
    BOOL isFinish = NO;
    if (_isReversing) {
        _currentFrame -= 1;
        if (_currentFrame < _startFrame) {
            _currentFrame = _startFrame;
            _loopCount += 1;
            isFinish = YES;
        }
    } else {
        _currentFrame += 1;
        if (_currentFrame > _endFrame) {
            _currentFrame = _endFrame;
            _loopCount += 1;
            isFinish = YES;
        }
    }
    
    if (self.isFinishedAll) {
        // 全部完成
        _loopCount = _loops;
        [self stopAnimation];
        
        if (delegate != nil && [delegate respondsToSelector:@selector(svgaPlayerDidFinishedAllAnimation:)]) {
            [delegate svgaPlayerDidFinishedAllAnimation:self];
        }
        return;
    }
    
    if (isFinish) {
        // 完成一次
        [self __stopAudios];
        
        if (delegate != nil && [delegate respondsToSelector:@selector(svgaPlayerDidFinishedOnceAnimation:)]) {
            [delegate svgaPlayerDidFinishedOnceAnimation:self];
        }
        
        // 要在回调之后才回去开头，因为有可能在回调时修改了新的startFrame和endFrame。
        _currentFrame = self.leadingFrame;
    }
    
    [self __update];
    
    if (delegate != nil && [delegate respondsToSelector:@selector(svgaPlayerDidAnimating:)]) {
        [delegate svgaPlayerDidAnimating:self];
    }
}

#pragma mark - Dynamic Object

- (void)setImage:(UIImage *)image forKey:(NSString *)aKey {
    if (image == nil) {
        return;
    }
    NSMutableDictionary *mutableDynamicObjects = [self.dynamicObjects mutableCopy];
    [mutableDynamicObjects setObject:image forKey:aKey];
    self.dynamicObjects = mutableDynamicObjects;
    if (self.contentLayers.count > 0) {
        for (SVGAContentLayer *layer in self.contentLayers) {
            if ([layer isKindOfClass:[SVGAContentLayer class]] && [layer.imageKey isEqualToString:aKey]) {
                layer.bitmapLayer.contents = (__bridge id _Nullable)([image CGImage]);
            }
        }
    }
}

- (void)setImageWithURL:(NSURL *)URL forKey:(NSString *)aKey {
    [[[NSURLSession sharedSession] dataTaskWithURL:URL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error == nil && data != nil) {
            UIImage *image = [UIImage imageWithData:data];
            if (image != nil) {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    [self setImage:image forKey:aKey];
                }];
            }
        }
    }] resume];
}

- (void)setImage:(UIImage *)image forKey:(NSString *)aKey referenceLayer:(CALayer *)referenceLayer {
    [self setImage:image forKey:aKey];
}

- (void)setAttributedText:(NSAttributedString *)attributedText forKey:(NSString *)aKey {
    if (attributedText == nil) {
        return;
    }
    NSMutableDictionary *mutableDynamicTexts = [self.dynamicTexts mutableCopy];
    [mutableDynamicTexts setObject:attributedText forKey:aKey];
    self.dynamicTexts = mutableDynamicTexts;
    if (self.contentLayers.count > 0) {
        CGSize bitmapSize = CGSizeMake(self.videoItem.images[aKey].size.width * self.videoItem.images[aKey].scale, self.videoItem.images[aKey].size.height * self.videoItem.images[aKey].scale);
        CGSize size = [attributedText boundingRectWithSize:bitmapSize
                                                   options:NSStringDrawingUsesLineFragmentOrigin context:NULL].size;
        CATextLayer *textLayer;
        for (SVGAContentLayer *layer in self.contentLayers) {
            if ([layer isKindOfClass:[SVGAContentLayer class]] && [layer.imageKey isEqualToString:aKey]) {
                textLayer = layer.textLayer;
                if (textLayer == nil) {
                    textLayer = [CATextLayer layer];
                    [layer addSublayer:textLayer];
                    layer.textLayer = textLayer;
                    [layer resetTextLayerProperties:attributedText];
                }
            }
        }
        if (textLayer != nil) {
            textLayer.contentsScale = [[UIScreen mainScreen] scale];
            [textLayer setString:attributedText];
            textLayer.frame = CGRectMake(0, 0, size.width, size.height);
        }
    }
}

- (void)setHidden:(BOOL)hidden forKey:(NSString *)aKey {
    NSMutableDictionary *mutableDynamicHiddens = [self.dynamicHiddens mutableCopy];
    [mutableDynamicHiddens setObject:@(hidden) forKey:aKey];
    self.dynamicHiddens = mutableDynamicHiddens;
    if (self.contentLayers.count > 0) {
        for (SVGAContentLayer *layer in self.contentLayers) {
            if ([layer isKindOfClass:[SVGAContentLayer class]] &&
                [layer.imageKey isEqualToString:aKey]) {
                layer.dynamicHidden = hidden;
            }
        }
    }
}

- (void)clearDynamicObjects {
    self.dynamicObjects = nil;
    self.dynamicTexts = nil;
    self.dynamicHiddens = nil;
}

- (NSDictionary *)dynamicObjects {
    if (_dynamicObjects == nil) {
        _dynamicObjects = @{};
    }
    return _dynamicObjects;
}

- (NSDictionary *)dynamicTexts {
    if (_dynamicTexts == nil) {
        _dynamicTexts = @{};
    }
    return _dynamicTexts;
}

- (NSDictionary *)dynamicHiddens {
    if (_dynamicHiddens == nil) {
        _dynamicHiddens = @{};
    }
    return _dynamicHiddens;
}

@end

