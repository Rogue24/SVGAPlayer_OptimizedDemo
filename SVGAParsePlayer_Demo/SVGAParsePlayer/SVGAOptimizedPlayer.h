//
//  SVGAOptimizedPlayer.h
//  SVGAParsePlayer_Demo
//
//  Created by aa on 2023/11/6.
//

#import <UIKit/UIKit.h>
#import <SVGAPlayer/SVGAVideoEntity.h>

NS_ASSUME_NONNULL_BEGIN

@class SVGAOptimizedPlayer;

typedef NS_ENUM(NSUInteger, SVGAVideoEntityError) {
    SVGAVideoEntityError_None = 0,
    SVGAVideoEntityError_ZeroVideoSize = 1,
    SVGAVideoEntityError_ZeroFPS = 2,
    SVGAVideoEntityError_ZeroFrames = 3,
};

@protocol SVGAOptimizedPlayerDelegate <NSObject>
@optional
/// 正在播放的回调
- (void)svgaPlayerDidAnimating:(SVGAOptimizedPlayer *)player;
/// 完成一次播放的回调
- (void)svgaPlayerDidFinishedOnceAnimation:(SVGAOptimizedPlayer *)player;
/// 完成所有播放的回调（前提条件：loops > 0）
- (void)svgaPlayerDidFinishedAllAnimation:(SVGAOptimizedPlayer *)player;
@end

@interface SVGAOptimizedPlayer: UIView
/// 代理
@property (nonatomic, weak) id<SVGAOptimizedPlayerDelegate> delegate;

/// 播放所在RunLoop模式（默认为CommonMode）
@property (nonatomic, copy) NSRunLoopMode mainRunLoopMode;
/// 停止动画时是否清空图层（默认为YES）
@property (nonatomic, assign) BOOL clearsAfterStop;

/// 播放次数（大于0才会触发回调`svgaPlayerDidFinishedAllAnimation`）
@property (nonatomic, assign) NSInteger loops;
/// 当前播放次数
@property (nonatomic, assign, readonly) NSInteger loopCount;

/// 是否反转播放
@property (nonatomic, assign) BOOL isReversing;
/// 是否静音
@property (nonatomic, assign) BOOL isMute;

/// SVGA资源
@property (nonatomic, strong, nullable) SVGAVideoEntity *videoItem;
/// 起始帧数
@property (nonatomic, assign, readonly) NSInteger startFrame;
/// 结束帧数
@property (nonatomic, assign, readonly) NSInteger endFrame;
/// 当前帧数
@property (nonatomic, assign, readonly) NSInteger currentFrame;

/// 总帧数
@property (readonly) NSInteger frameCount;
/// 最小帧数
@property (readonly) NSInteger minFrame;
/// 最大帧数
@property (readonly) NSInteger maxFrame;
/// 头部帧数
@property (readonly) NSInteger leadingFrame;
/// 尾部帧数
@property (readonly) NSInteger trailingFrame;
/// SVGA时长
@property (readonly) NSTimeInterval duration;
/// 是否播放中
@property (readonly) BOOL isAnimating;
/// 是否完成所有播放（前提条件：loops > 0）
@property (readonly) BOOL isFinishedAll;

#pragma mark 检验SVGA资源
+ (SVGAVideoEntityError)checkVideoItem:(SVGAVideoEntity *)videoItem;

#pragma mark 更换SVGA资源+设置播放区间
- (void)setVideoItem:(nullable SVGAVideoEntity *)videoItem currentFrame:(NSInteger)currentFrame;
- (void)setVideoItem:(nullable SVGAVideoEntity *)videoItem startFrame:(NSInteger)startFrame endFrame:(NSInteger)endFrame;
- (void)setVideoItem:(nullable SVGAVideoEntity *)videoItem startFrame:(NSInteger)startFrame endFrame:(NSInteger)endFrame currentFrame:(NSInteger)currentFrame;

#pragma mark 设置播放区间
- (void)resetStartFrameAndEndFrame;
- (void)setStartFrameUntilTheEnd:(NSInteger)startFrame;
- (void)setEndFrameFromBeginning:(NSInteger)endFrame;
- (void)setStartFrame:(NSInteger)startFrame endFrame:(NSInteger)endFrame;
- (void)setStartFrame:(NSInteger)startFrame endFrame:(NSInteger)endFrame currentFrame:(NSInteger)currentFrame;

#pragma mark 重置loopCount
- (void)resetLoopCount;

#pragma mark 开始播放（如果已经完成所有播放，则重置loopCount）
- (BOOL)startAnimation;

#pragma mark 跳至指定帧（如果已经完成所有播放，则重置loopCount）
- (BOOL)stepToFrame:(NSInteger)frame;
- (BOOL)stepToFrame:(NSInteger)frame andPlay:(BOOL)andPlay;

#pragma mark 暂停播放
- (void)pauseAnimation;

#pragma mark 停止播放
- (void)stopAnimation;
- (void)stopAnimation:(BOOL)isClear;

#pragma mark - Dynamic Object
- (void)setImage:(UIImage *)image forKey:(NSString *)aKey;
- (void)setImageWithURL:(NSURL *)URL forKey:(NSString *)aKey;
- (void)setImage:(UIImage *)image forKey:(NSString *)aKey referenceLayer:(CALayer *)referenceLayer; // deprecated from 2.0.1
- (void)setAttributedText:(NSAttributedString *)attributedText forKey:(NSString *)aKey;
- (void)setHidden:(BOOL)hidden forKey:(NSString *)aKey;
- (void)clearDynamicObjects;
@end

NS_ASSUME_NONNULL_END
