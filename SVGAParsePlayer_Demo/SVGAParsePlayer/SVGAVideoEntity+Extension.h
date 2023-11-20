//
//  SVGAVideoEntity+Extension.h
//  SVGAParsePlayer_Demo
//
//  Created by aa on 2023/11/20.
//

#import <SVGAPlayer/SVGAVideoEntity.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, SVGAVideoEntityError) {
    SVGAVideoEntityError_None = 0,
    SVGAVideoEntityError_ZeroVideoSize = 1,
    SVGAVideoEntityError_ZeroFPS = 2,
    SVGAVideoEntityError_ZeroFrames = 3,
};

@interface SVGAVideoEntity (Extension)
/// 最小帧数
@property (readonly) NSInteger minFrame;
/// 最大帧数
@property (readonly) NSInteger maxFrame;
/// 总时长
@property (readonly) NSTimeInterval duration;
/// 资源错误
@property (readonly) SVGAVideoEntityError entityError;
@end

NS_ASSUME_NONNULL_END
