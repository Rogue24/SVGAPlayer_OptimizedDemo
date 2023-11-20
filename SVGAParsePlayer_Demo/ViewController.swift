//
//  ViewController.swift
//  SVGAParsePlayer_Demo
//
//  Created by aa on 2023/8/23.
//

import UIKit
import SVProgressHUD

class ViewController: UIViewController {
    let operationBar = UIView()
    let reverseSwitch = UISwitch()
    let player = SVGAExPlayer()
    let progressView = UIProgressView()
    
    var isProgressing: Bool = false {
        didSet {
            guard isProgressing != oldValue else { return }
            UIView.animate(withDuration: 0.15) {
                self.progressView.alpha = self.isProgressing ? 1 : 0
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupOperationBar()
        setupPlayer()
        setupProgressView()
        
        writeBundleDataToCache("Rocket")
        writeBundleDataToCache("Rose")
        
        setupLoader()
        setupDownloader()
        setupCacheKeyGenerator()
    }
}

private extension ViewController {
    // MARK: - 播放远程SVGA
    @objc func playRemote() {
        let svga = RemoteSources.randomElement()!
        player.play(svga)
    }

    // MARK: - 播放本地SVGA
    @objc func playLocal() {
        let svga = LocalSources.randomElement()!
        player.play(svga)
    }
    
    // MARK: - 反转播放
    @objc func toggleReverse(_ sender: UISwitch) {
        SVProgressHUD.setDefaultMaskType(.none)
        SVProgressHUD.showInfo(withStatus: sender.isOn ? "开启反转播放" : "恢复正常播放")
        player.isReversing = sender.isOn
        
        // test
//        SVProgressHUD.setDefaultMaskType(.none)
//        if sender.isOn {
//            SVProgressHUD.showInfo(withStatus: "只播放30~70帧")
//            player.setStartFrame(30, endFrame: 100)
//        } else {
//            SVProgressHUD.showInfo(withStatus: "完整播放")
//            player.resetStartFrameAndEndFrame()
//        }
    }
    
    // MARK: - 播放
    @objc func play() {
        player.play()
    }
    
    // MARK: - 暂停
    @objc func pause() {
        player.pause()
    }
    
    // MARK: - 重新开始
    @objc func reset() {
        player.reset(isAutoPlay: true)
    }
    
    // MARK: - 停止
    @objc func stop() {
        player.stop()
    }
}

// MARK: - <SVGAExPlayerDelegate>
extension ViewController: SVGAExPlayerDelegate {
    /// 状态发生改变【状态更新】
    func svgaExPlayer(_ player: SVGAExPlayer,
                      statusDidChanged status: SVGAExPlayerStatus,
                      oldStatus: SVGAExPlayerStatus) {
        isProgressing = (status == .playing || status == .paused)
        switch status {
        case .loading:
            SVProgressHUD.setDefaultMaskType(.none)
            SVProgressHUD.show()
            reverseSwitch.isUserInteractionEnabled = false
        default:
            SVProgressHUD.dismiss()
            reverseSwitch.isUserInteractionEnabled = true
        }
    }
    
    /// SVGA未知来源【无法播放】
    func svgaExPlayer(_ player: SVGAExPlayer,
                      unknownSvga source: String) {
        SVProgressHUD.setDefaultMaskType(.none)
        SVProgressHUD.showError(withStatus: "未知来源")
    }
    
    /// SVGA资源加载失败【无法播放】
    func svgaExPlayer(_ player: SVGAExPlayer,
                      svga source: String,
                      dataLoadFailed error: Error) {
        SVProgressHUD.setDefaultMaskType(.none)
        SVProgressHUD.showError(withStatus: error.localizedDescription)
    }
    
    /// 加载的SVGA资源解析失败【无法播放】
    func svgaExPlayer(_ player: SVGAExPlayer,
                      svga source: String,
                      dataParseFailed error: Error) {
        SVProgressHUD.setDefaultMaskType(.none)
        SVProgressHUD.showError(withStatus: error.localizedDescription)
    }
    
    /// 本地SVGA资源解析失败【无法播放】
    func svgaExPlayer(_ player: SVGAExPlayer,
                      svga source: String,
                      assetParseFailed error: Error) {
        SVProgressHUD.setDefaultMaskType(.none)
        SVProgressHUD.showError(withStatus: error.localizedDescription)
    }
    
    /// SVGA资源无效【无法播放】
    func svgaExPlayer(_ player: SVGAExPlayer,
                      svga source: String,
                      entity: SVGAVideoEntity,
                      invalid error: SVGAVideoEntityError) {
        let status: String
        switch error {
        case .zeroVideoSize: status = "SVGA资源有问题：videoSize是0！"
        case .zeroFPS: status = "SVGA资源有问题：FPS是0！"
        case .zeroFrames: status = "SVGA资源有问题：frames是0！"
        default: return
        }
        SVProgressHUD.setDefaultMaskType(.none)
        SVProgressHUD.showError(withStatus: status)
    }
    
    /// SVGA动画执行回调【正在播放】
    func svgaExPlayer(_ player: SVGAExPlayer,
                      svga source: String,
                      animationPlaying currentFrame: Int) {
        guard player.isPlaying else { return }
        progressView.progress = player.progress
    }
    
    /// SVGA动画完成一次播放【正在播放】
    func svgaExPlayer(_ player: SVGAExPlayer, svga source: String, animationDidFinishedOnce loopCount: Int) {
        print("jpjpjp 完成第\(loopCount)次")
        
        // test
//        if loopCount >= 3 {
//            DispatchQueue.main.async {
//                self.playLocal()
//            }
//        }
        
        // 反复反转
//        player.isReversing.toggle()
    }
    
    /// SVGA动画播放失败的回调【播放失败】
    func svgaExPlayer(_ player: SVGAExPlayer,
                      svga source: String,
                      animationPlayFailed error: SVGARePlayerPlayError) {
        let status: String
        switch error {
        case .nullEntity: status = "SVGA资源是空的，无法播放"
        case .nullSuperview: status = "父视图是空的，无法播放"
        case .onlyOnePlayableFrame: status = "只有一帧可播放帧，无法形成动画"
        default: return
        }
        SVProgressHUD.setDefaultMaskType(.none)
        SVProgressHUD.showError(withStatus: status)
    }
}

// MARK: - Setup UI & Data
private extension ViewController {
    func setupOperationBar() {
        let h = NavBarH + NavBarH + DiffTabBarH
        operationBar.frame = CGRect(x: 0, y: PortraitScreenHeight - h, width: PortraitScreenWidth, height: h)
        view.addSubview(operationBar)
        
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blurView.frame = operationBar.bounds
        operationBar.addSubview(blurView)
        
        setupTopItems()
        setupBottomItems()
    }
    
    func setupTopItems() {
        let playRemoteBtn = UIButton(type: .system)
        playRemoteBtn.setTitle("Remote SVGA", for: .normal)
        playRemoteBtn.titleLabel?.font = .systemFont(ofSize: 16.px, weight: .bold)
        playRemoteBtn.tintColor = .systemYellow
        playRemoteBtn.addTarget(self, action: #selector(playRemote), for: .touchUpInside)
        playRemoteBtn.sizeToFit()
        playRemoteBtn.frame.size.height = NavBarH
        playRemoteBtn.frame.origin.x = 20.px
        operationBar.addSubview(playRemoteBtn)
        
        let playLocalBtn = UIButton(type: .system)
        playLocalBtn.setTitle("Local SVGA", for: .normal)
        playLocalBtn.titleLabel?.font = .systemFont(ofSize: 16.px, weight: .bold)
        playLocalBtn.tintColor = .systemTeal
        playLocalBtn.addTarget(self, action: #selector(playLocal), for: .touchUpInside)
        playLocalBtn.sizeToFit()
        playLocalBtn.frame.size.height = NavBarH
        playLocalBtn.frame.origin.x = playRemoteBtn.frame.maxX + 20.px
        operationBar.addSubview(playLocalBtn)
        
        reverseSwitch.isOn = false
        reverseSwitch.addTarget(self, action: #selector(toggleReverse(_:)), for: .valueChanged)
        reverseSwitch.frame.origin.x = PortraitScreenWidth - reverseSwitch.frame.width - 20.px
        reverseSwitch.frame.origin.y = (NavBarH - reverseSwitch.frame.height) * 0.5
        operationBar.addSubview(reverseSwitch)
    }
    
    func setupBottomItems() {
        let stackView = UIStackView()
        stackView.backgroundColor = .clear
        stackView.frame = CGRect(x: 0, y: NavBarH, width: PortraitScreenWidth, height: NavBarH)
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        operationBar.addSubview(stackView)
        
        func createBtn(_ title: String, _ action: Selector) -> UIButton {
            let btn = UIButton(type: .system)
            btn.setTitle(title, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 15.px, weight: .medium)
            btn.tintColor = .white
            btn.addTarget(self, action: action, for: .touchUpInside)
            btn.frame.size = CGSize(width: 60.px, height: NavBarH)
            return btn
        }
        
        stackView.addArrangedSubview(
            createBtn("Play", #selector(play))
        )
        
        stackView.addArrangedSubview(
            createBtn("Pause", #selector(pause))
        )
        
        stackView.addArrangedSubview(
            createBtn("Reset", #selector(reset))
        )
        
        stackView.addArrangedSubview(
            createBtn("Stop", #selector(stop))
        )
    }
    
    func setupPlayer() {
        let height = PortraitScreenHeight - StatusBarH - operationBar.frame.height
        player.frame = CGRect(x: 0, y: StatusBarH, width: PortraitScreenWidth, height: height)
        player.contentMode = .scaleAspectFit
        view.addSubview(player)
        
        player.isDebugLog = true
        player.isAnimated = true
        player.exDelegate = self
    }
    
    func setupProgressView() {
        progressView.frame = CGRect(x: 0, y: operationBar.frame.origin.y - 3, width: PortraitScreenWidth, height: 3)
        progressView.trackTintColor = .clear
        progressView.alpha = 0
        view.addSubview(progressView)
    }
    
    func writeBundleDataToCache(_ resName: String) {
        guard let url = Bundle.main.url(forResource: resName, withExtension: "svga") else {
            JPrint(resName, "路径不存在")
            return
        }
        
        let cacheUrl = URL(fileURLWithPath: cacheFilePath(resName + ".svga"))
        try? FileManager.default.removeItem(at: cacheUrl)
        
        do {
            let data = try Data(contentsOf: url)
            try data.write(to: cacheUrl)
        } catch {
            JPrint(resName, "写入错误：", error)
        }
    }
}

// MARK: - Setup SVGA Loader & Downloader & CacheKeyGenerator
private extension ViewController {
    func setupLoader() {
        SVGAExPlayer.loader = { svgaSource, success, failure, forwardDownload, forwardLoadAsset in
            guard FileManager.default.fileExists(atPath: svgaSource) else {
                if svgaSource.hasPrefix("http://") || svgaSource.hasPrefix("https://") {
                    forwardDownload(svgaSource)
                } else {
                    forwardLoadAsset(svgaSource)
                }
                return
            }
            
            print("jpjpjp 加载磁盘的SVGA - \(svgaSource)")
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: svgaSource))
                success(data)
            } catch {
                failure(error)
            }
        }
    }
    
    func setupDownloader() {
        SVGAExPlayer.downloader = { svgaSource, success, failure in
            guard let url = URL(string: svgaSource) else {
                failure(NSError(domain: "SVGAParsePlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "路径错误"]))
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
    }
    
    func setupCacheKeyGenerator() {
        SVGAExPlayer.cacheKeyGenerator = { $0.md5 }
    }
}
