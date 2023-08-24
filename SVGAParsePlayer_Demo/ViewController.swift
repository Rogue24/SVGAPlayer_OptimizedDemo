//
//  ViewController.swift
//  SVGAParsePlayer_Demo
//
//  Created by aa on 2023/8/23.
//

import UIKit
import SVProgressHUD

class ViewController: UIViewController {
    let player = SVGAParsePlayer()
    var isAutoPlay = true

    override func viewDidLoad() {
        super.viewDidLoad()
        setupOperationBar()
        setupPlayer()
        
        player.isAnimated = true
        player.isHidesWhenStopped = true
        player.myDelegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
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
}

// MARK: - Actions
private extension ViewController {
    @objc func playRemote() {
        let svga = RemoteSources.randomElement()!
        player.play(svga, fromFrame: 0, isAutoPlay: isAutoPlay)
    }

    @objc func playLocal() {
        let svga = LocalSources.randomElement()!
        player.play(svga, fromFrame: 0, isAutoPlay: isAutoPlay)
    }
    
    @objc func toggleAutoPlay(_ sender: UISwitch) {
        isAutoPlay = sender.isOn
    }
    
    @objc func play() {
        player.play()
    }
    
    @objc func pause() {
        player.pause()
    }
    
    @objc func reset() {
        player.reset(isAutoPlay: isAutoPlay)
    }
    
    @objc func stop() {
        player.stop(isClear: false)
    }
}

// MARK: - <SVGAParsePlayerDelegate>
extension ViewController: SVGAParsePlayerDelegate {
    func svgaParsePlayer(_ player: SVGAParsePlayer, statusDidChanged status: SVGAParsePlayerStatus, oldStatus: SVGAParsePlayerStatus) {
        switch status {
        case .loading:
            SVProgressHUD.setDefaultMaskType(.none)
            SVProgressHUD.show()
        default:
            SVProgressHUD.dismiss()
        }
    }
    
    func svgaParsePlayer(_ player: SVGAParsePlayer, unknownSvga source: String) {
        SVProgressHUD.setDefaultMaskType(.none)
        SVProgressHUD.showError(withStatus: "未知来源")
    }
    
    func svgaParsePlayer(_ player: SVGAParsePlayer, svga source: String, downloadFailed error: Error) {
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
}

// MARK: - Setup UI
private extension ViewController {
    func setupOperationBar() {
        let h = NavBarH + NavBarH + DiffTabBarH
        let operationBar = UIView(frame: CGRect(x: 0, y: PortraitScreenHeight - h, width: PortraitScreenWidth, height: h))
        view.addSubview(operationBar)
        
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blurView.frame = operationBar.bounds
        operationBar.addSubview(blurView)
        
        setupTopItems(operationBar)
        setupBottomItems(operationBar)
    }
    
    func setupTopItems(_ operationBar: UIView) {
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
        
        let autoPlaySwitch = UISwitch()
        autoPlaySwitch.isOn = isAutoPlay
        autoPlaySwitch.addTarget(self, action: #selector(toggleAutoPlay(_:)), for: .valueChanged)
        autoPlaySwitch.frame.origin.x = PortraitScreenWidth - autoPlaySwitch.frame.width - 20.px
        autoPlaySwitch.frame.origin.y = (NavBarH - autoPlaySwitch.frame.height) * 0.5
        operationBar.addSubview(autoPlaySwitch)
    }
    
    func setupBottomItems(_ operationBar: UIView) {
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
        player.contentMode = .scaleAspectFit
        player.frame = CGRect(x: 0, y: StatusBarH, width: PortraitScreenWidth, height: PortraitScreenHeight - StatusBarH - (NavBarH + NavBarH + DiffTabBarH))
        view.addSubview(player)
    }
}
