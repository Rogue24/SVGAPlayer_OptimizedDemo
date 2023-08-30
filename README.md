# SVGAParsePlayer

Convenient SVGA Player, is a secondary encapsulation of [SVGAPlayer](https://github.com/svga/SVGAPlayer-iOS).

[中文](https://juejin.cn/post/7270698918286147620)

    Feature:
        ✅ Built-in SVGA parser;
        ✅ With playback status and controllable;
        ✅ Customizable downloader;
        ✅ Prevent duplicate loading;
        ✅ Compatible with OC & Swift;
        ✅ The API is simple and easy to use.

![example](https://github.com/Rogue24/JPCover/raw/master/SVGAParsePlayer_Demo/example.gif)

## Basic Use

Original usage:

```swift
let player = SVGAPlayer()

override func viewDidLoad() {
    super.viewDidLoad()
    
    player.frame = CGRect(x: 100, y: 100, width: 100, height: 100)
    view.addSubview(player)

    // Creating an SVGA animation parser
    let parser = SVGAParser()
    
    // Load SVGA animation file
    parser.parse(withNamed: "your_animation_file", in: nil) { [weak self] videoItem in
        guard let self, videoItem else { return }
        
        // Load SVGA animation into the player
        self.player.videoItem = videoItem
        
        // Start playing animation
        self.player.startAnimation()
    }
}
```

`SVGAParsePlayer` itself inherits from `SVGAPlayer`, and the basic setup remains the same as before. The main difference lies in the usage of the API, which has become more user-friendly:

```swift
/// Play SVGA
/// - Parameters:
///   - fromFrame: Starting from frame
///   - isAutoPlay: Automatically start playing after loading
player.play("your_animation_path", fromFrame: 0, isAutoPlay: true)

/// Play SVGA directly through SVGAVideoEntity
/// - Parameters:
///   - fromFrame: Starting from frame
///   - isAutoPlay: Automatically start playing after loading
/// If played using this method, the `svgaSource` would be the memory address of the `entity` object.
let entity: SVGAVideoEntity = ...
player.play(with: entity, fromFrame: 0, isAutoPlay: true)

/// Play the current SVGA (starting from the current frame)
player.play()

/// Play current SVGA
/// - Parameters:
///  - fromFrame: Starting from frame
///  - isAutoPlay: Automatically start playing after loading
player.play(fromFrame: 0, isAutoPlay: true)

/// Pause playback
player.pause()

/// Reset current SVGA (return to beginning)
/// - Parameters:
///   - isAutoPlay: Automatically start playing after loading
player.reset(isAutoPlay: false)

/// Stop playing
/// - Parameters:
///  - isClear: is clear SVGA resources (if cleared, resources will need to be reloaded for next playback)
player.stop(isClear: false)
```

### Customizable settings

```swift
/// Is there an animated transition
/// - If it is' true ', it will have a fading effect in and out in the scene of' replacing SVGA 'and' playing/stopping '
var isAnimated = false

/// Whether to hide oneself in idle/stopped state
var isHidesWhenStopped = false

/// (SVGAParser)Enable Memory Caching 
var isEnabledMemoryCache = false
```

## Load optimization

Just to clarify, if you're playing the same resource path and the resource is either in the process of loading or has already been loaded, it won't reload redundantly. Internally, it determines whether the SVGA resource is the same based on the resource path. Only when a new resource path is provided will the previous resource be cleared to load the new one. This is to ensure that the same resource is not loaded repeatedly.

Loading remote SVGA resources involves utilizing the built-in downloading method of the `SVGAParser`. If you require a customized downloading approach, such as loading cached resources, you can define your own downloader:

```swift
SVGAParsePlayer.downloader = { svgaSource, success, failure in
    guard let url = URL(string: svgaSource) else {
        failure(NSError(domain: "SVGAParsePlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Error SVGA Path"]))
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
- Simply implement the closure `SVGAParsePlayer.downloader`.

Note: Internally, the downloader is invoked for downloading by determining whether the resource path includes the `http://` and `https://` prefixes; otherwise, the local resource loading method will be used.

If you want to have full control over the loading process, you can implement the closure `SVGAParsePlayer.loader` yourself:
```swift
SVGAParsePlayer.loader = { svgaSource, success, failure, forwardDownload, forwardLoadAsset in
    // Determine if the SVGA is from the disk.
    guard FileManager.default.fileExists(atPath: svgaSource) else {
        if svgaSource.hasPrefix("http://") || svgaSource.hasPrefix("https://") {
            forwardDownload(svgaSource)
        } else {
            forwardLoadAsset(svgaSource)
        }
        return
    }
    
    // Load the SVGA from the disk.
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: svgaSource))
        success(data)
    } catch {
        failure(error)
    }
}
```
- forwardDownload: The original remote loading method within `SVGAParsePlayer` (if `SVGAParsePlayer.downloader` is implemented, this closure is called).
- forwardLoadAsset: The original local resource loading method within `SVGAParsePlayer`.

## Mutually exclusive API

Since `SVGAParsePlayer` inherently inherits from `SVGAPlayer`, in order to prevent errors, refrain from invoking the original APIs of `SVGAPlayer`:

```objc
@property (nonatomic, weak) id<SVGAPlayerDelegate> delegate;

- (void)startAnimation;
- (void)startAnimationWithRange:(NSRange)range reverse:(BOOL)reverse;
- (void)pauseAnimation;
- (void)stopAnimation;
- (void)clear;
- (void)stepToFrame:(NSInteger)frame andPlay:(BOOL)andPlay;
- (void)stepToPercentage:(CGFloat)percentage andPlay:(BOOL)andPlay;
```
- The original `delegate` has been assigned to conform to itself. If you need to listen to the previous delegate methods, use `myDelegate`, which is the `SVGAParsePlayerDelegate`. This includes both the methods from the original delegate and additional callback methods (refer to the declaration for specifics).
