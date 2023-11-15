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
    let player = SVGAParsePlayer()
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
        
        setupLoader()
        setupDownloader()
        setupCacheKeyGenerator()
        
        writeBundleDataToCache("Rocket")
        writeBundleDataToCache("Rose")
    }
}

// MARK: - Player Actions
private extension ViewController {
    @objc func playRemote() {
        let svga = RemoteSources.randomElement()!
        player.play(svga)
    }

    @objc func playLocal() {
        let svga = LocalSources.randomElement()!
        player.play(svga)
    }
    
    @objc func toggleReverse(_ sender: UISwitch) {
        SVProgressHUD.setDefaultMaskType(.none)
        SVProgressHUD.showInfo(withStatus: sender.isOn ? "开启反转播放" : "恢复正常播放")
        player.isReversing = sender.isOn
    }
    
    @objc func play() {
        player.play()
    }
    
    @objc func pause() {
        player.pause()
    }
    
    @objc func reset() {
        player.reset(isAutoPlay: true)
    }
    
    @objc func stop() {
        player.stop(isClear: false)
    }
}

// MARK: - <SVGAParsePlayerDelegate>
extension ViewController: SVGAParsePlayerDelegate {
    func svgaParsePlayer(_ player: SVGAParsePlayer, 
                         statusDidChanged status: SVGAParsePlayerStatus,
                         oldStatus: SVGAParsePlayerStatus) {
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
    
    func svgaParsePlayer(_ player: SVGAParsePlayer, unknownSvga source: String) {
        SVProgressHUD.setDefaultMaskType(.none)
        SVProgressHUD.showError(withStatus: "未知来源")
    }
    
    func svgaParsePlayer(_ player: SVGAParsePlayer, svga source: String, dataLoadFailed error: Error) {
        SVProgressHUD.setDefaultMaskType(.none)
        SVProgressHUD.showError(withStatus: error.localizedDescription)
    }
    
    func svgaParsePlayer(_ player: SVGAParsePlayer, svga source: String, dataParseFailed error: Error) {
        SVProgressHUD.setDefaultMaskType(.none)
        SVProgressHUD.showError(withStatus: error.localizedDescription)
    }
    
    func svgaParsePlayer(_ player: SVGAParsePlayer, svga source: String, assetParseFailed error: Error) {
        SVProgressHUD.setDefaultMaskType(.none)
        SVProgressHUD.showError(withStatus: error.localizedDescription)
    }
    
    func svgaParsePlayer(_ player: SVGAParsePlayer, svga source: String, entity: SVGAVideoEntity, invalid error: Error) {
        SVProgressHUD.setDefaultMaskType(.none)
        SVProgressHUD.showError(withStatus: error.localizedDescription)
    }
    
    func svgaParsePlayer(_ player: SVGAParsePlayer, svga source: String, didAnimatingToFrame frame: Int) {
        guard player.isPlaying else { return }
        progressView.progress = player.progress
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
        player.myDelegate = self
    }
    
    func setupProgressView() {
        progressView.frame = CGRect(x: 0, y: operationBar.frame.origin.y - 3, width: PortraitScreenWidth, height: 3)
        progressView.trackTintColor = .clear
        progressView.alpha = 0
        view.addSubview(progressView)
    }
    
    func setupLoader() {
        SVGAParsePlayer.loader = { svgaSource, success, failure, forwardDownload, forwardLoadAsset in
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
        SVGAParsePlayer.downloader = { svgaSource, success, failure in
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
        SVGAParsePlayer.cacheKeyGenerator = { $0.md5 }
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
