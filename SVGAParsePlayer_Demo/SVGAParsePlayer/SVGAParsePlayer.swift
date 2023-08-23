//
//  SVGAParsePlayer.swift
//  SVGAParsePlayer_Demo
//
//  Created by aa on 2023/8/23.
//

import UIKit
import SVGAPlayer

@objc
protocol SVGAParsePlayerDelegate: NSObjectProtocol {
    @objc optional
    func svgaParsePlayer(_ player: SVGAParsePlayer,
                         statusDidChanged status: SVGAParsePlayerStatus,
                         oldStatus: SVGAParsePlayerStatus)
    
    @objc optional
    func svgaParsePlayer(_ player: SVGAParsePlayer,
                         unknownSvga source: String)
    
    @objc optional
    func svgaParsePlayer(_ player: SVGAParsePlayer,
                         svga source: String,
                         downloadFailed error: Error)
    
    @objc optional
    func svgaParsePlayer(_ player: SVGAParsePlayer,
                         svga source: String,
                         dataParseFailed error: Error)
    
    @objc optional
    func svgaParsePlayer(_ player: SVGAParsePlayer,
                         svga source: String,
                         assetParseFailed error: Error)
    
    @objc optional
    func svgaParsePlayer(_ player: SVGAParsePlayer,
                         svga source: String,
                         didAnimatedToFrame frame: Int)
    
    @objc optional
    func svgaParsePlayer(_ player: SVGAParsePlayer,
                         svga source: String,
                         didFinishedAnimation isUserStop: Bool)
}

@objc
enum SVGAParsePlayerStatus: Int {
    case idle
    case loading
    case playing
    case paused
    case stopped
}

enum SVGAParsePlayerError: Swift.Error, LocalizedError {
    case unknownSource(_ svgaSource: String)
    case downloadFailed(_ svgaSource: String, _ error: Swift.Error)
    case dataParseFailed(_ svgaSource: String, _ error: Swift.Error)
    case assetParseFailed(_ svgaSource: String, _ error: Swift.Error)
    
    var errorDescription: String? {
        switch self {
        case .unknownSource:
            return "未知来源"
        case let .downloadFailed(_, error): fallthrough
        case let .dataParseFailed(_, error): fallthrough
        case let .assetParseFailed(_, error):
            return (error as NSError).localizedDescription
        }
    }
}

@objcMembers
class SVGAParsePlayer: SVGAPlayer {
    typealias DownloadSuccess = (_ data: Data) -> Void
    typealias DownloadFailure = (_ error: Error) -> Void
    typealias Downloader = (_ svgaSource: String,
                            _ success: @escaping DownloadSuccess,
                            _ failure: @escaping DownloadFailure) -> Void
    
    /// 自定义下载器
    static var downloader: Downloader? = nil
    
    /// 打印调试日志
    static func debugLog(_ str: String) {
        print("jpjpjp \(str)")
    }
    
    private var entity: SVGAVideoEntity?
    private var asyncTag: UUID?
    private var isWillAutoPlay = false
    
    /// SVGA资源路径
    private(set) var svgaSource: String = ""
    
    /// 动画时长
    var duration: TimeInterval { entity?.duration ?? 0 }
    
    /// 总帧数
    var frames: Int { Int(entity?.frames ?? 0) }
    
    /// 当前帧
    private(set) var currFrame: Int = 0
    
    /// 当前状态
    private(set) var status: SVGAParsePlayerStatus = .idle {
        didSet {
            guard let myDelegate, status != oldValue else { return }
            myDelegate.svgaParsePlayer?(self, statusDidChanged: status, oldStatus: oldValue)
        }
    }
    
    /// 是否正在空闲
    var isIdle: Bool { status == .idle }
    /// 是否正在加载
    var isLoading: Bool { status == .loading }
    /// 是否正在播放
    var isPlaying: Bool { status == .playing }
    /// 是否已暂停
    var isPaused: Bool { status == .paused }
    /// 是否已停止
    var isStopped: Bool { status == .stopped }
    
    /// 是否带动画过渡
    /// - 为`true`则会在「更换SVGA」和「播放/停止」的场景中带有淡入淡出的效果
    var isAnimated = false
    
    /// 是否在空闲/停止状态时隐藏自身
    var isHidesWhenStopped = false {
        didSet {
            if status == .idle || status == .loading || status == .stopped {
                alpha = isHidesWhenStopped ? 0 : 1
            } else {
                alpha = 1
            }
        }
    }
    
    /// 是否启用内存缓存
    var isEnabledMemoryCache = false
    
    /// 代理
    weak var myDelegate: (any SVGAParsePlayerDelegate)? = nil
    
    // MARK: - 初始化
    override init(frame: CGRect) {
        super.init(frame: frame)
        baseSetup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        baseSetup()
    }
    
    private func baseSetup() {
        delegate = self
    }
}

// MARK: - 开始加载SVGA | SVGA加载失败
private extension SVGAParsePlayer {
    func _loadSVGA(_ svgaSource: String, fromFrame: Int, isAutoPlay: Bool) {
        if svgaSource.count == 0 {
            _stopSVGA(isClear: true)
            _loadFaild(.unknownSource(svgaSource))
            return
        }
        
        if self.svgaSource == svgaSource, entity != nil {
            Self.debugLog("已经有了，不用加载 \(svgaSource)")
            asyncTag = nil
            _playSVGA(fromFrame: fromFrame, isAutoPlay: isAutoPlay)
            return
        }
        
        // 记录最新状态
        currFrame = fromFrame
        isWillAutoPlay = isAutoPlay
        
        guard !isLoading else {
            Self.debugLog("已经在加载了，不要重复加载 \(svgaSource)")
            return
        }
        status = .loading
        
        Self.debugLog("开始加载 \(svgaSource) - 先清空当前动画")
        stopAnimation()
        videoItem = nil
        
        let newTag = UUID()
        self.asyncTag = newTag
        
        if svgaSource.hasPrefix("http://") || svgaSource.hasPrefix("https://") {
            _downLoadData(svgaSource, newTag, isAutoPlay)
        } else {
            _parseFromAsset(svgaSource, newTag, isAutoPlay)
        }
    }
    
    func _loadFaild(_ error: SVGAParsePlayerError) {
        guard let myDelegate else { return }
        
        switch error {
        case let .unknownSource(s):
            myDelegate.svgaParsePlayer?(self, unknownSvga: s)
            
        case let .downloadFailed(s, e):
            myDelegate.svgaParsePlayer?(self, svga: s, downloadFailed: e)
            
        case let .dataParseFailed(s, e):
            myDelegate.svgaParsePlayer?(self, svga: s, dataParseFailed: e)
            
        case let .assetParseFailed(s, e):
            myDelegate.svgaParsePlayer?(self, svga: s, assetParseFailed: e)
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
        
        let success: DownloadSuccess = { [weak self] data in
            guard let self, self.asyncTag == asyncTag else { return }

            let newTag = UUID()
            self.asyncTag = newTag

            Self.debugLog("外部下载 - 远程SVGA下载成功 \(svgaSource)")
            self._parseFromData(data, svgaSource, newTag, isAutoPlay)
        }
        
        let failure: DownloadFailure = { [weak self] error in
            guard let self, self.asyncTag == asyncTag else { return }
            self.asyncTag = nil

            Self.debugLog("外部下载 - 远程SVGA下载失败 \(svgaSource)")
            self._stopSVGA(isClear: true)
            self._loadFaild(.downloadFailed(svgaSource, error))
        }
        
        downloader(svgaSource, success, failure)
    }
    
    func _parseFromUrl(_ svgaSource: String,
                       _ asyncTag: UUID,
                       _ isAutoPlay: Bool) {
        guard let url = URL(string: svgaSource) else {
            _stopSVGA(isClear: true)
            _loadFaild(.unknownSource(svgaSource))
            return
        }
        
        let parser = SVGAParser()
        parser.enabledMemoryCache = isEnabledMemoryCache
        parser.parse(with: url) { [weak self] entity in
            guard let self, self.asyncTag == asyncTag else { return }
            self.asyncTag = nil
            
            Self.debugLog("内部下载 - 远程SVGA下载成功 \(svgaSource)")
            
            if let entity {
                self._parseDone(svgaSource, entity)
                return
            }
            
            Self.debugLog("内部下载 - 远程SVGA资源为空")
            self._stopSVGA(isClear: true)
            
            let error = NSError(domain: "SVGAParsePlayer", code: 404, userInfo: [NSLocalizedDescriptionKey: "SVGA资源为空"])
            self._loadFaild(.downloadFailed(svgaSource, error))
            
        } failureBlock: { [weak self] e in
            guard let self, self.asyncTag == asyncTag else { return }
            self.asyncTag = nil
            
            Self.debugLog("内部下载 - 远程SVGA下载失败 \(svgaSource)")
            self._stopSVGA(isClear: true)
            
            let error = e ?? NSError(domain: "SVGAParsePlayer", code: 404, userInfo: [NSLocalizedDescriptionKey: "SVGA下载失败"])
            self._loadFaild(.downloadFailed(svgaSource, error))
        }
    }
    
    func _parseFromData(_ data: Data,
                        _ svgaSource: String,
                        _ asyncTag: UUID,
                        _ isAutoPlay: Bool) {
        let parser = SVGAParser()
        parser.enabledMemoryCache = isEnabledMemoryCache
        parser.parse(with: data, cacheKey: svgaSource.md5) { [weak self] entity in
            guard let self, self.asyncTag == asyncTag else { return }
            self.asyncTag = nil
            
            Self.debugLog("远程SVGA解析成功 \(svgaSource)")
            self._parseDone(svgaSource, entity)
            
        } failureBlock: { [weak self] error in
            guard let self, self.asyncTag == asyncTag else { return }
            self.asyncTag = nil
            
            Self.debugLog("远程SVGA解析失败 \(svgaSource) \(error)")
            self._stopSVGA(isClear: true)
            self._loadFaild(.dataParseFailed(svgaSource, error))
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
            
            Self.debugLog("本地SVGA解析成功 \(svgaSource)")
            self._parseDone(svgaSource, entity)
            
        } failureBlock: { [weak self] error in
            guard let self, self.asyncTag == asyncTag else { return }
            self.asyncTag = nil
            
            Self.debugLog("本地SVGA解析失败 \(svgaSource) \(error)")
            self._stopSVGA(isClear: true)
            self._loadFaild(.assetParseFailed(svgaSource, error))
        }
    }
    
    func _parseDone(_ svgaSource: String, _ entity: SVGAVideoEntity) {
        guard self.svgaSource == svgaSource else { return }
        self.entity = entity
        videoItem = entity
        _playSVGA(fromFrame: currFrame, isAutoPlay: isWillAutoPlay)
    }
}

// MARK: - 播放 | 停止
private extension SVGAParsePlayer {
    func _playSVGA(fromFrame: Int, isAutoPlay: Bool) {
        currFrame = fromFrame
        
        step(toFrame: fromFrame, andPlay: isAutoPlay)
        if isAutoPlay {
            Self.debugLog("跳至特定帧\(fromFrame) - 播放 \(svgaSource)")
            status = .playing
        } else {
            Self.debugLog("跳至特定帧\(fromFrame) - 暂停 \(svgaSource)")
            status = .paused
        }
        
        _show()
    }
    
    func _stopSVGA(isClear: Bool) {
        asyncTag = nil
        stopAnimation()
        currFrame = 0
        
        if isClear {
            svgaSource = ""
            entity = nil
            videoItem = nil
            
            Self.debugLog("停止 - 清空")
            status = .idle
        } else {
            Self.debugLog("停止 - 不清空")
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

// MARK: - <SVGAPlayerDelegate>
extension SVGAParsePlayer: SVGAPlayerDelegate {
    func svgaPlayer(_ player: SVGAPlayer!, didAnimatedToFrame frame: Int) {
        currFrame = frame
        myDelegate?.svgaParsePlayer?(self, svga: svgaSource, didAnimatedToFrame: frame)
    }
    
    func svgaPlayerDidFinishedAnimation(_ player: SVGAPlayer!) {
        let svgaSource = self.svgaSource
        _hideIfNeeded { [weak self] in
            guard let self else { return }
            self._stopSVGA(isClear: false)
            self.myDelegate?.svgaParsePlayer?(self, svga: svgaSource, didFinishedAnimation: false)
        }
        Self.debugLog("svgaPlayerDidFinishedAnimation！！！")
    }
}

// MARK: - API
extension SVGAParsePlayer {
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
    /// - Parameters:
    ///   - svgaSource: SVGA资源路径
    func play(_ svgaSource: String) {
        play(svgaSource, fromFrame: 0, isAutoPlay: true)
    }
    
    /// 播放当前SVGA（从当前所在帧开始）
    func play() {
        switch status {
        case .paused:
            Self.debugLog("继续")
            startAnimation()
            status = .playing
        case .playing:
            return
        default:
            play(fromFrame: currFrame)
        }
    }
    
    /// 播放当前SVGA
    /// - Parameters:
    ///  - fromFrame: 从第几帧开始
    func play(fromFrame: Int) {
        guard svgaSource.count > 0 else { return }
        
        if entity == nil {
            Self.debugLog("播放 - 需要加载")
            _loadSVGA(svgaSource, fromFrame: fromFrame, isAutoPlay: true)
            return
        }
        
        Self.debugLog("播放 - 无需加载 继续")
        _playSVGA(fromFrame: fromFrame, isAutoPlay: true)
    }
    
    /// 重置当前SVGA（回到开头）
    /// - Parameters:
    ///   - isAutoPlay: 是否自动开始播放
    func reset(isAutoPlay: Bool = true) {
        guard svgaSource.count > 0 else { return }
        
        if entity == nil {
            Self.debugLog("重播 - 需要加载")
            _loadSVGA(svgaSource, fromFrame: 0, isAutoPlay: isAutoPlay)
            return
        }
        
        Self.debugLog("重播 - 无需加载")
        _playSVGA(fromFrame: 0, isAutoPlay: isAutoPlay)
    }
    
    /// 暂停
    func pause() {
        Self.debugLog("暂停")
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
            self.myDelegate?.svgaParsePlayer?(self, svga: svgaSource, didFinishedAnimation: true)
        }
    }
}
