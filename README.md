# SVGARePlayer & SVGAExPlayer

`SVGARePlayer` is a new SVGA player refactored based on `SVGAPlayer`. Initially, the code was completely copied from `SVGAPlayer`, and then refactored on top of it. It was also written in Objective-C. The external interface remains basically consistent with `SVGAPlayer`, while internally it has been refactored, adjusted, enhanced, and encapsulated according to my own style. This was done to gradually replace the original `SVGAPlayer` in the project while maintaining compatibility.

`SVGAExPlayer`, on the other hand, is an enhanced version of `SVGARePlayer` upgraded to Swift. The following is mainly about the introduction of `SVGAExPlayer`.

[中文](https://juejin.cn/post/7270698918286147620)

    Features:
        ✅ Built-in SVGA parser.
        ✅ Play state with control.
        ✅ Customizable downloader & loader.
        ✅ Prevent duplicate loading.
        ✅ Mute at any time.
        ✅ Reverse playback at any time.
        ✅ Set playback range at any time.
        ✅ Compatible with both Objective-C and Swift.
        ✅ Simple and easy-to-use API.

![example](https://github.com/Rogue24/JPCover/raw/master/SVGAParsePlayer_Demo/example.gif)

`SVGAPlayer` is an old third-party library, and the author hasn't updated it for a long time. It's quite cumbersome to use. The original usage:

```swift
let player = SVGAPlayer()

override func viewDidLoad() {
    super.viewDidLoad()
    
    player.frame = CGRect(x: 100, y: 100, width: 100, height: 100)
    view.addSubview(player)

    // Create SVGA animation parser
    let parser = SVGAParser()
    
    // Load SVGA animation file
    parser.parse(withNamed: "your_animation_file", in: nil) { [weak self] videoItem in
        guard let self, videoItem else { return }
        
        // Load SVGA animation into player
        self.player.videoItem = videoItem
        
        // Start playing animation
        self.player.startAnimation()
    }
}
```

To be honest, its performance is not as good as [Lottie](https://github.com/airbnb/lottie-ios), but I have to use it for the project. To make it more convenient to use, I decided to refactor it.

## Basic Usage

`SVGAExPlayer` inherits from `SVGARePlayer` (which is a completely rewritten new player based on the original `SVGAPlayer` with almost identical API, but internally optimized). Basic setup is the same as the parent class, but the usage of API is different, making it easier to use.

To load and play:

```swift
player.play("your_animation_path", fromFrame: 0, isAutoPlay: true)
```

- `fromFrame`: Start from which frame.
- `isAutoPlay`: Whether to start playing automatically after loading.

The `SVGAParser` will be automatically invoked internally to load "remote/local" SVGA resources, so calling this method will not play immediately, as there will be a loading process.

After loading, you can choose whether to play automatically. Specific states can be observed by conforming to `SVGAExPlayerDelegate`, where you can receive callbacks when the status changes:

```swift
/// Status changes [Status update]
@objc optional
func svgaExPlayer(_ player: SVGAExPlayer,
                  statusDidChanged status: SVGAExPlayerStatus,
                  oldStatus: SVGAExPlayerStatus)
```

Additionally, there are corresponding callbacks for loading failure and completion in `SVGAExPlayerDelegate`:

```swift
/// Unknown source of SVGA [Unable to play]
@objc optional
func svgaExPlayer(_ player: SVGAExPlayer,
                  unknownSvga source: String)

/// Failed to load SVGA resource [Unable to play]
@objc optional
func svgaExPlayer(_ player: SVGAExPlayer,
                  svga source: String,
                  dataLoadFailed error: Error)

/// Failed to parse loaded SVGA resource [Unable to play]
@objc optional
func svgaExPlayer(_ player: SVGAExPlayer,
                  svga source: String,
                  dataParseFailed error: Error)

/// Failed to parse local SVGA resource [Unable to play]
@objc optional
func svgaExPlayer(_ player: SVGAExPlayer,
                  svga source: String,
                  assetParseFailed error: Error)

/// Invalid SVGA resource [Unable to play]
@objc optional
func svgaExPlayer(_ player: SVGAExPlayer,
                  svga source: String,
                  entity: SVGAVideoEntity,
                  invalid error: SVGAVideoEntityError)

/// Successfully parsed SVGA resource [Can play]
@objc optional
func svgaExPlayer(_ player: SVGAExPlayer,
                  svga source: String,
                  parseDone entity: SVGAVideoEntity)
```

Of course, there are also callbacks related to playback:

```swift
/// SVGA animation (local/remote resource) is ready to play [About to play]
/// - Parameters:
///   - isNewSource: Whether it is a new resource (if the resource needs to be loaded for playback, or if a different `entity` is switched, this value is `true`)
///   - fromFrame: Starting from which frame
///   - isWillPlay: Whether it is about to start playing
///   - resetHandler: Used to reset "from which frame to start" and "whether to start playing". Call this closure and pass in new values if changes are needed.
@objc optional
func svgaExPlayer(_ player: SVGAExPlayer,
                  svga source: String,
                  readyForPlay isNewSource: Bool,
                  fromFrame: Int,
                  isWillPlay: Bool,
                  resetHandler: @escaping (_ newFrame: Int, _ isPlay: Bool) -> Void)

/// Callback when SVGA animation is being played [Playing]
@objc optional
func svgaExPlayer(_ player: SVGAExPlayer,
                  svga source: String,
                  animationPlaying currentFrame: Int)

/// SVGA animation completes one playback [Playing]
/// - Note: Each completion of animation (regardless of whether it is looped) will trigger a callback; it will not be called if "manually stopped" by the user.
@objc optional
func svgaExPlayer(_ player: SVGAExPlayer,
                  svga source: String,
                  animationDidFinishedOnce loopCount: Int)

/// SVGA animation completes all playback [Playback ends]
/// - Note: It will be called only if `loops > 0` and the specified number of loops is reached; it will not be called if "manually stopped" by the user or `loops = 0`.
@objc optional
func svgaExPlayer(_ player: SVGAExPlayer,
                  svga source: String,
                  animationDidFinishedAll loopCount: Int)

/// Callback for SVGA animation playback failure [Playback failed]
/// - Note: This callback is triggered when attempting to play if there is "no SVGA resource" or "no parent view", or if the SVGA resource has only one playable frame (unable to form an animation).
@objc optional
func svgaExPlayer(_ player: SVGAExPlayer,
                  svga source: String,
                  animationPlayFailed error: SVGARePlayerPlayError)
```

* Methods of `SVGAExPlayerDelegate` are all optional. For specific usage, refer this demo.

If there is already an existing `SVGAVideoEntity` object, you can directly use it for playback:

```swift
let entity: SVGAVideoEntity = ...
player.play(with: entity, fromFrame: 0, isAutoPlay: true)
```

* When using this method for playback, `svgaSource` is the memory address of the `SVGAVideoEntity` object.

## Loading Optimization

#### Custom Remote Resource Downloader

For loading remote SVGA resources, internally it uses the built-in download method of `SVGAParser`. If you need to define your own downloading method (e.g., loading cached resources), you can define a downloader:

```swift
SVGAExPlayer.downloader = { svgaSource, success, failure in
    guard let url = URL(string: svgaSource) else {
        failure(NSError(domain: "SVGAExPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid path"]))
        return
    }
    
    Task {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            await MainActor.run { success(data) }
        } catch {
            await MainActor.run { failure(error) }
        }
    }
}
```

* Implement the `SVGAExPlayer.downloader` closure.

Note that if the same resource path is being played or has already been loaded, it won't be reloaded. Internally, it checks whether the resource path is the same to avoid duplicate loading operations. However, if a new resource path is provided, it will clear the previous resource and load the new one to ensure that the same resource won't be loaded repeatedly.

**📢 Note**: Internally, it determines whether to call the downloader for download by checking whether the resource path has the prefixes `http://` and `https://`. Otherwise, it will use the local resource loading method.

#### Custom Resource Loader

If you want complete control over the loading process, you can implement `SVGAExPlayer.loader`:

```swift
SVGAExPlayer.loader = { svgaSource, success, failure, forwardDownload, forwardLoadAsset in
    // Check if it's a disk SVGA
    guard FileManager.default.fileExists(atPath: svgaSource) else {
        if svgaSource.hasPrefix("http://") || svgaSource.hasPrefix("https://") {
            forwardDownload(svgaSource) // Call the internal remote loading method
        } else {
            forwardLoadAsset(svgaSource) // Call the internal local resource loading method
        }
        return
    }
            
    // Load disk SVGA
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: svgaSource))
        success(data)
    } catch {
        failure(error)
    }
}
```

* `forwardDownload`: The original remote loading method within `SVGAExPlayer` (if `SVGAExPlayer.downloader` is implemented, this closure will be called).
* `forwardLoadAsset`: The original local resource loading method within `SVGAExPlayer`.

#### Custom Cache Key Generator

After successful loading, it will use the default caching method (`NSCache`) for caching, with the SVGA path as the key. If you need a custom cache key, you can implement `SVGAExPlayer.cacheKeyGenerator`:

```swift
SVGAExPlayer.cacheKeyGenerator = { svgaSource in
    return svgaSource.md5 // Encrypt using MD5
}
```

## Other APIs and Settings

```swift
/// Play the current SVGA (from the current frame)
func play()

/// Play the current SVGA
/// - Parameters:
///   - fromFrame: From which frame to start
///   - isAutoPlay: Whether to start playing automatically
func play(fromFrame: Int, isAutoPlay: Bool) 

/// Reset the current SVGA (back to the beginning, reset completion count)
/// If `startFrame` or `endFrame` is set, it starts from `leadingFrame`
/// - Parameters:
///   - isAutoPlay: Whether to start playing automatically
func reset(isAutoPlay: Bool = true) 

/// Pause
func pause() 

/// Stop
/// - Parameters:
///   - scene: Stopped scene
///     - clearLayers: Clear layers
///     - stepToTrailing: Go to the trailing frame
///     - stepToLeading: Back to the leading frame
func stop(then scene: SVGARePlayerStoppedScene, completion: UserStopCompletion? = nil)
    
/// Stop
/// - Equivalent to:`stop(then: userStoppedScene, completion: completion)`
func stop(completion: UserStopCompletion? = nil)
    
/// Clean
func clean(completion: UserStopCompletion? = nil)
```

* As calling play methods won't start playing immediately, if you call the play method again while loading and the `fromFrame` and `isAutoPlay` are different, `fromFrame` and `isAutoPlay` will be used for subsequent operations according to the latest settings.

Customizable settings:

```swift
/// Whether to use animated transitions (default is `false`)
/// - If `true`, there will be fade in/out effect in "changing SVGA" and "play/stop" scenes
public var isAnimated = false

/// Whether to hide itself when in a "stopped" state (default is `false`)
public var isHidesWhenStopped = false

/// Whether to reset `loopCount` when in a "stopped" state (default is `true`)
public var isResetLoopCountWhenStopped = true

/// Whether to enable memory cache (mainly for `SVGAParser`, default is `false`)
public var isEnabledMemoryCache = false

/// Whether to print debug logs (only in `DEBUG` environment, default is `false`)
public var isDebugLog = false
```

## Mutually Exclusive APIs

As `SVGAExPlayer` inherits from `SVGARePlayer`, to avoid errors, do not call the following APIs of `SVGARePlayer`:

```objc
/// The original delegate is now implemented by `self`; please use `exDelegate` for listening.
@property (nonatomic, weak) id<SVGAOptimizedPlayerDelegate> delegate;

/// The `alpha` property will be modified internally to control "show" and "hide," as well as to achieve fade-in and fade-out effects. Therefore, please avoid modifying `alpha` externally.
@property (nonatomic) CGFloat alpha;

/// External setting of `videoItem` is not allowed; it has been set internally.
- (void)setVideoItem:(nullable SVGAVideoEntity *)videoItem
        currentFrame:(NSInteger)currentFrame;
- (void)setVideoItem:(nullable SVGAVideoEntity *)videoItem
          startFrame:(NSInteger)startFrame
            endFrame:(NSInteger)endFrame;
- (void)setVideoItem:(nullable SVGAVideoEntity *)videoItem
          startFrame:(NSInteger)startFrame 
            endFrame:(NSInteger)endFrame
        currentFrame:(NSInteger)currentFrame;

/// This conflicts with the original playback logic; please use APIs that start with `play` for loading and playback.
- (BOOL)startAnimation;
- (BOOL)stepToFrame:(NSInteger)frame;
- (BOOL)stepToFrame:(NSInteger)frame andPlay:(BOOL)andPlay;

/// This conflicts with the original playback logic; please use `pause()` to pause.
- (void)pauseAnimation;

/// This conflicts with the original playback logic; please use `stop(with scene: SVGARePlayerStoppedScene)` to stop.
- (void)stopAnimation;
- (void)stopAnimation:(SVGARePlayerStoppedScene)scene;
```

* `delegate`: The original delegate is implemented by `self`. If you need to listen to the previous `delegate` methods, use `exDelegate`.

    * This refers to `SVGAExPlayerDelegate`, which includes the methods from the original delegate as well as the additional callback methods listed above.
    
* `alpha`: Please avoid modifying this externally, as it will be modified internally to control "show" and "hide," and to achieve fade-in and fade-out effects.

    * Note: After SVGA stops playback, if `isHideWhenStopped` is false, `alpha` will be set to 1; otherwise, it will be set to 0 (which may not match the value modified externally).
    
    * If modification is necessary, ensure that `isAnimated` is false.

Since we don't want to use the original APIs, why did we use inheritance from `SVGARePlayer`?

1. For consistent basic setup with the previous version.
2. To use it as a UIView without an extra layer, minimizing the number of layers as much as possible.

## Conclusion

That's all for the introduction. Generally speaking, [SVGAPlayer](https://github.com/svga/SVGAPlayer-iOS) is lighter than `Lottie`, suitable for scenarios with fewer animations. But if you need many and complex animations, I personally recommend [Lottie](https://github.com/airbnb/lottie-ios). Its architecture and performance are much better than `SVGAPlayer`, and most importantly, `Lottie` has been maintained and updated, while `SVGAPlayer` is no longer updated.

My `SVGARePlayer` is a refactored version based on `SVGAPlayer`, and `SVGAExPlayer` is an enhanced version of `SVGARePlayer`. Besides retaining the original functionality, I mainly optimized "loading prevention" and "API simplification".

If you need to use it, you can directly copy these files from the `SVGAPlayer_Optimized` folder in this demo to your project:

![main_files](https://github.com/Rogue24/JPCover/raw/master/SVGAParsePlayer_Demo/main_files.jpg)
