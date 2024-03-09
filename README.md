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

Internally, `SVGAParser` will be automatically called for loading "remote/local" SVGA resources. So, calling this method will not start playing immediately; there will be a loading process.

After loading, you can choose whether to play automatically. You can receive callbacks for status changes by conforming to `SVGAExPlayerDelegate`.

If you already have an existing `SVGAVideoEntity` object, you can play directly using that object:

```swift
let entity: SVGAVideoEntity = ...
player.play(with: entity, fromFrame: 0, isAutoPlay: true)
```

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
@property (nonatomic, weak) id<SVGAPlayerDelegate> delegate;

- (void)setVideoItem:(nullable SVGAVideoEntity *)videoItem
        currentFrame:(NSInteger)currentFrame;
- (void)setVideoItem:(nullable SVGAVideoEntity *)videoItem
          startFrame:(NSInteger)startFrame
            endFrame:(NSInteger)endFrame;
- (void)setVideoItem:(nullable SVGAVideoEntity *)videoItem
          startFrame:(NSInteger)startFrame 
            endFrame:(NSInteger)endFrame
        currentFrame:(NSInteger)currentFrame;
        
- (BOOL)startAnimation;
- (BOOL)stepToFrame:(NSInteger)frame;
- (BOOL)stepToFrame:(NSInteger)frame andPlay:(BOOL)andPlay;
- (void)pauseAnimation;
- (void)stopAnimation;
- (void)stopAnimation:(SVGARePlayerStoppedScene)scene;
```

* The original `delegate` is retained by conforming to `exDelegate`. All methods of the original `delegate` and the above callbacks are included.

Since we don't want to use the original APIs, why did we use inheritance from `SVGARePlayer`?

1. For consistent basic setup with the previous version.
2. To use it as a UIView without an extra layer, minimizing the number of layers as much as possible.

## Conclusion

That's all for the introduction. Generally speaking, [SVGAPlayer](https://github.com/svga/SVGAPlayer-iOS) is lighter than `Lottie`, suitable for scenarios with fewer animations. But if you need many and complex animations, I personally recommend [Lottie](https://github.com/airbnb/lottie-ios). Its architecture and performance are much better than `SVGAPlayer`, and most importantly, `Lottie` has been maintained and updated, while `SVGAPlayer` is no longer updated.

My `SVGARePlayer` is a refactored version based on `SVGAPlayer`, and `SVGAExPlayer` is an enhanced version of `SVGARePlayer`. Besides retaining the original functionality, I mainly optimized "loading prevention" and "API simplification".

If you need to use it, you can directly copy these files from the `SVGAPlayer_Optimized` folder in this demo to your project:

![main_files](https://github.com/Rogue24/JPCover/raw/master/SVGAParsePlayer_Demo/main_files.jpg)
