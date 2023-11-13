//
//  SVGAParsePlayer.swift
//  SVGAParsePlayer_Demo
//
//  Created by aa on 2023/8/23.
//

import UIKit

@objc public
protocol SVGAParsePlayerDelegate: NSObjectProtocol {
    @objc optional
    /// 状态发生改变
    func svgaParsePlayer(_ player: SVGAParsePlayer,
                         statusDidChanged status: SVGAParsePlayerStatus,
                         oldStatus: SVGAParsePlayerStatus)
    
    @objc optional
    /// SVGA未知来源
    func svgaParsePlayer(_ player: SVGAParsePlayer,
                         unknownSvga source: String)
    
    @objc optional
    /// SVGA资源加载失败
    func svgaParsePlayer(_ player: SVGAParsePlayer,
                         svga source: String,
                         dataLoadFailed error: Error)
    
    @objc optional
    /// 加载的SVGA资源解析失败
    func svgaParsePlayer(_ player: SVGAParsePlayer,
                         svga source: String,
                         dataParseFailed error: Error)
    
    @objc optional
    /// 本地SVGA资源解析失败
    func svgaParsePlayer(_ player: SVGAParsePlayer,
                         svga source: String,
                         assetParseFailed error: Error)
    
    @objc optional
    /// SVGA资源无效
    func svgaParsePlayer(_ player: SVGAParsePlayer,
                         svga source: String,
                         entity: SVGAVideoEntity,
                         invalid error: Error)
    
    @objc optional
    /// SVGA资源解析成功
    func svgaParsePlayer(_ player: SVGAParsePlayer,
                         svga source: String,
                         parseDone entity: SVGAVideoEntity)
    
    @objc optional
    /// SVGA动画已准备好可播放
    func svgaParsePlayer(_ player: SVGAParsePlayer,
                         svga source: String,
                         readyForPlay isPlay: Bool)
    
    @objc optional
    /// SVGA动画执行回调
    func svgaParsePlayer(_ player: SVGAParsePlayer,
                         svga source: String,
                         didAnimatingToFrame frame: Int)
    
    @objc optional
    /// SVGA动画完成一次播放
    func svgaParsePlayer(_ player: SVGAParsePlayer,
                         svga source: String,
                         didFinishedOnceAnimation loopCount: Int)
    
    @objc optional
    /// SVGA动画结束（用户手动停止 or 设置了loops并且达到次数）
    func svgaParsePlayer(_ player: SVGAParsePlayer,
                         svga source: String,
                         didFinishedAllAnimation isUserStop: Bool)
}

@objc public
enum SVGAParsePlayerStatus: Int {
    case idle
    case loading
    case playing
    case paused
    case stopped
}

public 
enum SVGAParsePlayerError: Swift.Error, LocalizedError {
    case unknownSource(_ svgaSource: String)
    case dataLoadFailed(_ svgaSource: String, _ error: Swift.Error)
    case dataParseFailed(_ svgaSource: String, _ error: Swift.Error)
    case assetParseFailed(_ svgaSource: String, _ error: Swift.Error)
    case entityInvalid(_ svgaSource: String, _ entity: SVGAVideoEntity, _ error: Swift.Error)
    
    public var errorDescription: String? {
        switch self {
        case .unknownSource:
            return "未知来源"
        case let .dataLoadFailed(_, error): fallthrough
        case let .dataParseFailed(_, error): fallthrough
        case let .assetParseFailed(_, error):
            return (error as NSError).localizedDescription
        case let .entityInvalid(_, _, error):
            return (error as NSError).localizedDescription
        }
    }
}

@objcMembers public
class SVGAParsePlayer: SVGAOptimizedPlayer {
    public typealias LoadSuccess = (_ data: Data) -> Void
    public typealias LoadFailure = (_ error: Error) -> Void
    public typealias ForwardLoad = (_ svgaSource: String) -> Void
    
    /// 自定义加载器
    public static var loader: Loader? = nil
    public typealias Loader = (_ svgaSource: String,
                               _ success: @escaping LoadSuccess,
                               _ failure: @escaping LoadFailure,
                               _ forwardDownload: @escaping ForwardLoad,
                               _ forwardLoadAsset: @escaping ForwardLoad) -> Void
    
    /// 自定义下载器
    public static var downloader: Downloader? = nil
    public typealias Downloader = (_ svgaSource: String,
                                   _ success: @escaping LoadSuccess,
                                   _ failure: @escaping LoadFailure) -> Void
    
    /// 自定义缓存键生成器
    public static var cacheKeyGenerator: CacheKeyGenerator? = nil
    public typealias CacheKeyGenerator = (_ svgaSource: String) -> String
    
    private var asyncTag: UUID?
    private var isWillAutoPlay = false
    
    /// SVGA资源路径
    public private(set) var svgaSource: String = ""
    
    /// SVGA资源
    public private(set) var entity: SVGAVideoEntity?
    
    /// 当前状态
    public private(set) var status: SVGAParsePlayerStatus = .idle {
        didSet {
            guard let myDelegate, status != oldValue else { return }
            myDelegate.svgaParsePlayer?(self, statusDidChanged: status, oldStatus: oldValue)
        }
    }
    
    /// 是否正在空闲
    public var isIdle: Bool { status == .idle }
    /// 是否正在加载
    public var isLoading: Bool { status == .loading }
    /// 是否正在播放
    public var isPlaying: Bool { status == .playing }
    /// 是否已暂停
    public var isPaused: Bool { status == .paused }
    /// 是否已停止
    public var isStopped: Bool { status == .stopped }
    
    /// 是否带动画过渡（默认为false）
    /// - 为`true`则会在「更换SVGA」和「播放/停止」的场景中带有淡入淡出的效果
    public var isAnimated = false
    
    /// 是否在【空闲 / 停止】状态时隐藏自身（默认不隐藏）
    public var isHidesWhenStopped = false {
        didSet {
            if status == .idle || status == .loading || status == .stopped {
                alpha = isHidesWhenStopped ? 0 : 1
            } else {
                alpha = 1
            }
        }
    }
    
    /// 是否在【停止】时跳至最后一帧（默认跳至起始第一帧）
    public var isStepToTrailingWhenStopped = false {
        didSet {
            guard status == .stopped else { return }
            step(toFrame: isStepToTrailingWhenStopped ? trailingFrame : leadingFrame)
        }
    }
    
    /// 是否在【空闲 / 停止】状态时重置`loopCount`（默认为true）
    public var isResetLoopCountWhenStopped = true
    
    /// 是否启用内存缓存（给到SVGAParser使用，默认为false）
    public var isEnabledMemoryCache = false
    
    /// 代理
    public weak var myDelegate: (any SVGAParsePlayerDelegate)? = nil
    
    /// 是否打印调试日志（仅限DEBUG环境）
    public var isDebugLog = false
    
    /// 调试信息（仅限DEBUG环境）
    public var debugInfo: String {
#if DEBUG
        "[SVGAParsePlayer_Print] svgaSource: \(svgaSource), status: \(status), startFrame: \(startFrame), endFrame: \(endFrame), currentFrame: \(currentFrame), loops: \(loops), loopCount:\(loopCount)"
#else
        ""
#endif
    }
    
    // MARK: - 初始化
    public override init(frame: CGRect) {
        super.init(frame: frame)
        baseSetup()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        baseSetup()
    }
    
    public override func willMove(toSuperview newSuperview: UIView?) {
        let isClear = newSuperview == nil
        if isClear { asyncTag = nil }
        
        super.willMove(toSuperview: newSuperview)
        
        if isClear {
            svgaSource = ""
            entity = nil
            videoItem = nil
            clearDynamicObjects()
            
            _debugLog("停止 - 没有父视图了，清空")
            status = .idle
        }
    }
    
    deinit {
        _debugLog("死亡 - \(self)")
    }
    
    // MARK: - 私有方法
    private func baseSetup() {
        _debugLog("出生 - \(self)")
        delegate = self
        clearsAfterStop = false
    }
    
    /// 打印调试日志（仅限DEBUG环境）
    private func _debugLog(_ str: String) {
#if DEBUG
        guard isDebugLog else { return }
        print("[SVGAParsePlayer_Print] \(str)")
#endif
    }
}

// MARK: - 与父类互斥的属性和方法
/**
 * 原代理已被`self`遵守，请使用`myDelegate`来进行监听
 *  `@property (nonatomic, weak) id<SVGAOptimizedPlayerDelegate> delegate;`
 *
 * 无需设置，可在`stop(isClear: Bool)`控制是否清空
 *  `@property (nonatomic, assign) BOOL clearsAfterStop;`
 *
 * 不允许外部设置`videoItem`，内部已为其设置
 *  `@property (nonatomic, strong, nullable) SVGAVideoEntity *videoItem;`
 *  `- (void)setVideoItem:(nullable SVGAVideoEntity *)videoItem currentFrame:(NSInteger)currentFrame;`
 *  `- (void)setVideoItem:(nullable SVGAVideoEntity *)videoItem startFrame:(NSInteger)startFrame endFrame:(NSInteger)endFrame;`
 *  `- (void)setVideoItem:(nullable SVGAVideoEntity *)videoItem startFrame:(NSInteger)startFrame endFrame:(NSInteger)endFrame currentFrame:(NSInteger)currentFrame;`
 *
 * 与原播放逻辑互斥，请使用`play`开头的API进行加载和播放
 *  `- (BOOL)startAnimation;`
 *  `- (BOOL)stepToFrame:(NSInteger)frame;`
 *  `- (BOOL)stepToFrame:(NSInteger)frame andPlay:(BOOL)andPlay;`
 *
 * 与原播放逻辑互斥，请使用`pause()`进行暂停
 *  `- (void)pauseAnimation;`
 *
 * 与原播放逻辑互斥，请使用`stop(isClear: Bool)`进行停止
 *  `- (void)stopAnimation;`
 *  `- (void)stopAnimation:(BOOL)isClear;`
 */

// MARK: - 开始加载SVGA | SVGA加载回调
private extension SVGAParsePlayer {
    func _loadSVGA(_ svgaSource: String, fromFrame: Int, isAutoPlay: Bool) {
        if svgaSource.count == 0 {
            _stopSVGA(isClear: true)
            _failedHandler(.unknownSource(svgaSource))
            return
        }
        
        if self.svgaSource == svgaSource, entity != nil {
            _debugLog("已经有了，不用加载 \(svgaSource)")
            asyncTag = nil
            _playSVGA(fromFrame: fromFrame, isAutoPlay: isAutoPlay, isNew: false)
            return
        }
        
        // 记录最新状态
        isWillAutoPlay = isAutoPlay
        
        guard !isLoading else {
            _debugLog("已经在加载了，不要重复加载 \(svgaSource)")
            return
        }
        status = .loading
        
        _debugLog("开始加载 \(svgaSource) - 先清空当前动画")
        stopAnimation(true)
        videoItem = nil
        clearDynamicObjects()
        
        let newTag = UUID()
        asyncTag = newTag
        
        guard let loader = Self.loader else {
            if svgaSource.hasPrefix("http://") || svgaSource.hasPrefix("https://") {
                _downLoadData(svgaSource, newTag, isAutoPlay)
            } else {
                _parseFromAsset(svgaSource, newTag, isAutoPlay)
            }
            return
        }
        
        let success = _getLoadSuccess(svgaSource, newTag, isAutoPlay)
        let failure = _getLoadFailure(svgaSource, newTag, isAutoPlay)
        let forwardDownload: ForwardLoad = { [weak self] in self?._downLoadData($0, newTag, isAutoPlay) }
        let forwardLoadAsset: ForwardLoad = { [weak self] in self?._parseFromAsset($0, newTag, isAutoPlay) }
        loader(svgaSource, success, failure, forwardDownload, forwardLoadAsset)
    }
}

private extension SVGAParsePlayer {
    func _getLoadSuccess(_ svgaSource: String, _ asyncTag: UUID, _ isAutoPlay: Bool) -> LoadSuccess {
        return { [weak self] data in
            guard let self, self.asyncTag == asyncTag else { return }

            let newTag = UUID()
            self.asyncTag = newTag

            self._debugLog("外部加载SVGA - 成功 \(svgaSource)")
            self._parseFromData(data, svgaSource, newTag, isAutoPlay)
        }
    }
    
    func _getLoadFailure(_ svgaSource: String, _ asyncTag: UUID, _ isAutoPlay: Bool) -> LoadFailure {
        return { [weak self] error in
            guard let self, self.asyncTag == asyncTag else { return }
            self.asyncTag = nil

            self._debugLog("外部加载SVGA - 失败 \(svgaSource)")
            self._stopSVGA(isClear: true)
            self._failedHandler(.dataLoadFailed(svgaSource, error))
        }
    }
    
    func _failedHandler(_ error: SVGAParsePlayerError) {
        guard let myDelegate else { return }
        
        switch error {
        case let .unknownSource(s):
            myDelegate.svgaParsePlayer?(self, unknownSvga: s)
            
        case let .dataLoadFailed(s, e):
            myDelegate.svgaParsePlayer?(self, svga: s, dataLoadFailed: e)
            
        case let .dataParseFailed(s, e):
            myDelegate.svgaParsePlayer?(self, svga: s, dataParseFailed: e)
            
        case let .assetParseFailed(s, e):
            myDelegate.svgaParsePlayer?(self, svga: s, assetParseFailed: e)
            
        case let .entityInvalid(s, entity, error):
            myDelegate.svgaParsePlayer?(self, svga: s, entity: entity, invalid: error)
        }
    }
}

// MARK: - 下载Data | 解析Data | 解析Asset | 解析完成
private extension SVGAParsePlayer {
    func _downLoadData(_ svgaSource: String,
                       _ asyncTag: UUID,
                       _ isAutoPlay: Bool) {
        guard let downloader = Self.downloader else {
            _parseFromUrl(svgaSource, asyncTag, isAutoPlay)
            return
        }
        
        let success = _getLoadSuccess(svgaSource, asyncTag, isAutoPlay)
        let failure = _getLoadFailure(svgaSource, asyncTag, isAutoPlay)
        downloader(svgaSource, success, failure)
    }
    
    func _parseFromUrl(_ svgaSource: String,
                       _ asyncTag: UUID,
                       _ isAutoPlay: Bool) {
        guard let url = URL(string: svgaSource) else {
            _stopSVGA(isClear: true)
            _failedHandler(.unknownSource(svgaSource))
            return
        }
        
        let parser = SVGAParser()
        parser.enabledMemoryCache = isEnabledMemoryCache
        parser.parse(with: url) { [weak self] entity in
            guard let self, self.asyncTag == asyncTag else { return }
            self.asyncTag = nil
            
            self._debugLog("内部下载远程SVGA - 成功 \(svgaSource)")
            
            if let entity {
                self._parseDone(svgaSource, entity)
                return
            }
            
            let error = NSError(domain: "SVGAParsePlayer", code: -3, userInfo: [NSLocalizedDescriptionKey: "下载的SVGA资源为空"])
            self._debugLog("内部下载远程SVGA - 资源为空")
            self._stopSVGA(isClear: true)
            self._failedHandler(.dataLoadFailed(svgaSource, error))
            
        } failureBlock: { [weak self] e in
            guard let self, self.asyncTag == asyncTag else { return }
            self.asyncTag = nil
            
            let error = e ?? NSError(domain: "SVGAParsePlayer", code: -2, userInfo: [NSLocalizedDescriptionKey: "SVGA下载失败"])
            self._debugLog("内部下载远程SVGA - 失败 \(svgaSource)")
            self._stopSVGA(isClear: true)
            self._failedHandler(.dataLoadFailed(svgaSource, error))
        }
    }
    
    func _parseFromData(_ data: Data,
                        _ svgaSource: String,
                        _ asyncTag: UUID,
                        _ isAutoPlay: Bool) {
        let cacheKey = Self.cacheKeyGenerator?(svgaSource) ?? svgaSource
        let parser = SVGAParser()
        parser.enabledMemoryCache = isEnabledMemoryCache
        parser.parse(with: data, cacheKey: cacheKey) { [weak self] entity in
            guard let self, self.asyncTag == asyncTag else { return }
            self.asyncTag = nil
            
            self._debugLog("解析远程SVGA - 成功 \(svgaSource)")
            self._parseDone(svgaSource, entity)
            
        } failureBlock: { [weak self] error in
            guard let self, self.asyncTag == asyncTag else { return }
            self.asyncTag = nil
            
            self._debugLog("解析远程SVGA - 失败 \(svgaSource) \(error)")
            self._stopSVGA(isClear: true)
            self._failedHandler(.dataParseFailed(svgaSource, error))
        }
    }
    
    func _parseFromAsset(_ svgaSource: String,
                         _ asyncTag: UUID,
                         _ isAutoPlay: Bool) {
        let parser = SVGAParser()
        parser.enabledMemoryCache = isEnabledMemoryCache
        parser.parse(withNamed: svgaSource, in: nil) { [weak self] entity in
            guard let self, self.asyncTag == asyncTag else { return }
            self.asyncTag = nil
            
            self._debugLog("解析本地SVGA - 成功 \(svgaSource)")
            self._parseDone(svgaSource, entity)
            
        } failureBlock: { [weak self] error in
            guard let self, self.asyncTag == asyncTag else { return }
            self.asyncTag = nil
            
            self._debugLog("解析本地SVGA - 失败 \(svgaSource) \(error)")
            self._stopSVGA(isClear: true)
            self._failedHandler(.assetParseFailed(svgaSource, error))
        }
    }
    
    func _parseDone(_ svgaSource: String, _ entity: SVGAVideoEntity) {
        guard _checkEntityIsCanUse(entity, for: svgaSource) else { return }
        guard self.svgaSource == svgaSource else { return }
        self.entity = entity
        videoItem = entity
        myDelegate?.svgaParsePlayer?(self, svga: svgaSource, parseDone: entity)
        _playSVGA(fromFrame: currentFrame, isAutoPlay: isWillAutoPlay, isNew: true)
    }
}

// MARK: - 检查Entity
private extension SVGAParsePlayer {
    func _checkEntityIsCanUse(_ entity: SVGAVideoEntity, for svgaSource: String) -> Bool {
        let error: NSError
        switch Self.checkVideoItem(entity) {
        case .none: 
            return true
        case .zeroVideoSize:
            error = NSError(domain: "SVGAParsePlayer", code: -4, userInfo: [NSLocalizedDescriptionKey: "SVGA资源无效：画面尺寸为0"])
        case .zeroFPS:
            error = NSError(domain: "SVGAParsePlayer", code: -5, userInfo: [NSLocalizedDescriptionKey: "SVGA资源无效：FPS为0"])
        case .zeroFrames:
            error = NSError(domain: "SVGAParsePlayer", code: -6, userInfo: [NSLocalizedDescriptionKey: "SVGA资源无效：帧数为0"])
        @unknown default:
            error = NSError(domain: "SVGAParsePlayer", code: -7, userInfo: [NSLocalizedDescriptionKey: "SVGA资源无效：其他原因"])
        }
        
        _debugLog(error.localizedDescription)
        _stopSVGA(isClear: true)
        _failedHandler(.entityInvalid(svgaSource, entity, error))
        return false
    }
}

// MARK: - 播放 | 停止
private extension SVGAParsePlayer {
    func _playSVGA(fromFrame: Int, isAutoPlay: Bool, isNew: Bool) {
        if isNew {
            myDelegate?.svgaParsePlayer?(self, svga: svgaSource, readyForPlay: isAutoPlay)
        }
        
        if step(toFrame: fromFrame, andPlay: isAutoPlay) {
            if isAutoPlay {
                _debugLog("成功跳至特定帧\(fromFrame) - 播放 \(svgaSource)")
                status = .playing
            } else {
                _debugLog("成功跳至特定帧\(fromFrame) - 暂停 \(svgaSource)")
                status = .paused
            }
        } else {
            _debugLog("不能跳至特定帧\(fromFrame) - 暂停 \(svgaSource)")
            pauseAnimation()
            status = .paused
        }
        
        _show()
    }
    
    func _stopSVGA(isClear: Bool) {
        asyncTag = nil
        stopAnimation(isClear)
        
        if isResetLoopCountWhenStopped || isClear {
            resetLoopCount()
        }
        
        if isClear {
            svgaSource = ""
            entity = nil
            videoItem = nil
            clearDynamicObjects()
            
            _debugLog("停止 - 清空")
            status = .idle
        } else {
            _debugLog("停止 - 不清空，回到开头/结尾处")
            step(toFrame: isStepToTrailingWhenStopped ? trailingFrame : leadingFrame)
            status = .stopped
        }
    }
}

// MARK: - 展示 | 隐藏
private extension SVGAParsePlayer {
    func _show() {
        guard isAnimated else {
            alpha = 1
            return
        }

        UIView.animate(withDuration: 0.2) {
            self.alpha = 1
        }
    }
    
    func _hideIfNeeded(completion: @escaping () -> Void) {
        if isHidesWhenStopped, isAnimated {
            let newTag = UUID()
            self.asyncTag = newTag
            
            UIView.animate(withDuration: 0.2) {
                self.alpha = 0
            } completion: { _ in
                guard self.asyncTag == newTag else { return }
                self.asyncTag = nil
                completion()
            }
        } else {
            if isHidesWhenStopped { alpha = 0 }
            completion()
        }
    }
}

// MARK: - <SVGAOptimizedPlayerDelegate>
extension SVGAParsePlayer: SVGAOptimizedPlayerDelegate {
    public func svgaPlayerDidAnimating(_ player: SVGAOptimizedPlayer) {
        myDelegate?.svgaParsePlayer?(self, svga: svgaSource, didAnimatingToFrame: currentFrame)
    }
    
    public func svgaPlayerDidFinishedOnceAnimation(_ player: SVGAOptimizedPlayer) {
        myDelegate?.svgaParsePlayer?(self, svga: svgaSource, didFinishedOnceAnimation: loopCount)
    }
    
    public func svgaPlayerDidFinishedAllAnimation(_ player: SVGAOptimizedPlayer) {
        let svgaSource = self.svgaSource
        _debugLog("did finished all: \(svgaSource)")
        _hideIfNeeded { [weak self] in
            guard let self else { return }
            self._stopSVGA(isClear: false)
            self.myDelegate?.svgaParsePlayer?(self, svga: svgaSource, didFinishedAllAnimation: false)
        }
    }
}

// MARK: - API
public extension SVGAParsePlayer {
    /// 播放目标SVGA
    /// - Parameters:
    ///   - svgaSource: SVGA资源路径
    ///   - fromFrame: 从第几帧开始
    ///   - isAutoPlay: 是否自动开始播放
    func play(_ svgaSource: String, fromFrame: Int, isAutoPlay: Bool) {
        guard self.svgaSource != svgaSource else {
            _loadSVGA(svgaSource, fromFrame: fromFrame, isAutoPlay: isAutoPlay)
            return
        }
        
        self.svgaSource = svgaSource
        entity = nil
        asyncTag = nil
        status = .idle
        
        _hideIfNeeded { [weak self] in
            guard let self else { return }
            self._loadSVGA(svgaSource, fromFrame: fromFrame, isAutoPlay: isAutoPlay)
        }
    }
    
    /// 播放目标SVGA（从头开始、自动播放）
    /// 如果设置过`startFrame`或`endFrame`，则从`leadingFrame`开始
    /// - Parameters:
    ///   - svgaSource: SVGA资源路径
    func play(_ svgaSource: String) {
        play(svgaSource, fromFrame: leadingFrame, isAutoPlay: true)
    }
    
    /// 播放目标SVGA
    /// - Parameters:
    ///   - entity: SVGA资源（`svgaSource`为`entity`的内存地址）
    ///   - fromFrame: 从第几帧开始
    ///   - isAutoPlay: 是否自动开始播放
    func play(with entity: SVGAVideoEntity, fromFrame: Int, isAutoPlay: Bool) {
        asyncTag = nil
        
        let memoryAddress = unsafeBitCast(entity, to: Int.self)
        let svgaSource = String(format: "%p", memoryAddress)
        guard _checkEntityIsCanUse(entity, for: svgaSource) else { return }
        
        guard self.svgaSource != svgaSource else {
            _playSVGA(fromFrame: fromFrame, isAutoPlay: isAutoPlay, isNew: false)
            return
        }
        
        self.svgaSource = svgaSource
        self.entity = nil
        status = .idle
        
        _hideIfNeeded { [weak self] in
            guard let self else { return }
            
            self.stopAnimation(true)
            self.clearDynamicObjects()
            
            self.entity = entity
            self.videoItem = entity
            
            self._playSVGA(fromFrame: fromFrame, isAutoPlay: isAutoPlay, isNew: true)
        }
    }
    
    /// 播放目标SVGA（从头开始、自动播放）
    /// 如果设置过`startFrame`或`endFrame`，则从`leadingFrame`开始
    /// - Parameters:
    ///   - entity: SVGA资源（`svgaSource`为`entity`的内存地址）
    func play(with entity: SVGAVideoEntity) {
        play(with: entity, fromFrame: leadingFrame, isAutoPlay: true)
    }
    
    /// 播放当前SVGA（从当前所在帧开始）
    func play() {
        switch status {
        case .paused:
            if startAnimation() {
                _debugLog("继续播放")
                status = .playing
            } else {
                _debugLog("播放失败，继续暂停")
                pauseAnimation()
            }
        case .playing: return
        default: play(fromFrame: currentFrame, isAutoPlay: true)
        }
    }
    
    /// 播放当前SVGA
    /// - Parameters:
    ///  - fromFrame: 从第几帧开始
    ///  - isAutoPlay: 是否自动开始播放
    func play(fromFrame: Int, isAutoPlay: Bool) {
        guard svgaSource.count > 0 else { return }
        
        if entity == nil {
            _debugLog("播放 - 需要加载")
            _loadSVGA(svgaSource, fromFrame: fromFrame, isAutoPlay: isAutoPlay)
            return
        }
        
        _debugLog("播放 - 无需加载 继续")
        _playSVGA(fromFrame: fromFrame, isAutoPlay: isAutoPlay, isNew: false)
    }
    
    /// 重置当前SVGA（回到开头）
    /// 如果设置过`startFrame`或`endFrame`，则从`leadingFrame`开始
    /// - Parameters:
    ///   - isAutoPlay: 是否自动开始播放
    func reset(isAutoPlay: Bool = true) {
        guard svgaSource.count > 0 else { return }
        
        if entity == nil {
            _debugLog("重播 - 需要加载")
            _loadSVGA(svgaSource, fromFrame: leadingFrame, isAutoPlay: isAutoPlay)
            return
        }
        
        _debugLog("重播 - 无需加载")
        _playSVGA(fromFrame: leadingFrame, isAutoPlay: isAutoPlay, isNew: false)
    }
    
    /// 暂停
    func pause() {
        _debugLog("暂停")
        guard isPlaying else {
            isWillAutoPlay = false
            return
        }
        pauseAnimation()
        status = .paused
    }
    
    /// 停止
    /// - Parameters:
    ///   - isClear: 是否清空SVGA资源（清空的话下次播放就需要重新加载资源）
    func stop(isClear: Bool) {
        let svgaSource = self.svgaSource
        _hideIfNeeded { [weak self] in
            guard let self else { return }
            self._stopSVGA(isClear: isClear)
            self.myDelegate?.svgaParsePlayer?(self, svga: svgaSource, didFinishedAllAnimation: true)
        }
    }
}
