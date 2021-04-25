//
//  ViewController.swift
//  MyAdvancedAnimations
//
//  Created by Denys Danyliuk on 12.04.2021.
//

import UIKit

final class ViewController: UIViewController {
    
    // MARK: - State
    
    enum State {
        case collapsed
        case expanded
        
        func getContentFrameIn(_ view: UIView) -> CGRect {
            
            switch self {
            case .collapsed:
                return CGRect(x: 0,
                              y: view.frame.height - Constants.collapsedHeight,
                              width: view.frame.width,
                              height: Constants.collapsedHeight - 83)
            case .expanded:
                return CGRect(x: 0,
                              y: 50,
                              width: view.frame.width,
                              height: view.frame.height - 50)
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .collapsed:
                return 0
            case .expanded:
                return 20
            }
        }
        
        static prefix func !(_ state: State) -> State {
            return state == .collapsed ? .expanded : .collapsed
        }
    }
    
    // MARK: - Constants
    
    enum Constants {
        static var animationDuration: TimeInterval = 0.35
        static var collapsedHeight: CGFloat = 166
    }
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var contentView: UIVisualEffectView!
    @IBOutlet weak var albumImageView: UIImageView!
    @IBOutlet weak var albumWidth: NSLayoutConstraint!
    
    // MARK: - Private properties
    
    private var progressWhenInterrupted: CGFloat = 0
    private var runningAnimators = [UIViewPropertyAnimator]()
    private var state: State = .collapsed
    private var isCancelling = false
    
    private let gradient = CAGradientLayer()
    private var gradientSet = [[CGColor]]()
    private var currentGradient: Int = 0
    
    private let gradientOne = #colorLiteral(red: 0.1098039216, green: 0.2431372549, blue: 0.4039215686, alpha: 1).cgColor
    private let gradientTwo = #colorLiteral(red: 0.9568627451, green: 0.3450980392, blue: 0.2078431373, alpha: 1).cgColor
    private let gradientThree = #colorLiteral(red: 0.768627451, green: 0.2745098039, blue: 0.4196078431, alpha: 1).cgColor
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupTabbar()
        setupGradient()
        setupView()
        addGestures()
    }
    
    private func setupView() {
        
        contentView.clipsToBounds = true
        contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        albumImageView.layer.cornerRadius = 10
        contentView.frame = state.getContentFrameIn(view)
    }
    
    private func setupTabbar() {
        
        guard let tabBar = tabBarController?.tabBar else {
            return
        }
        
        tabBar.isTranslucent = true
        tabBar.backgroundImage = UIImage()
        tabBar.barTintColor = .clear
        tabBar.backgroundColor = .black
        tabBar.layer.backgroundColor = UIColor.clear.cgColor
        
        let blurEffect = UIBlurEffect(style: .systemThinMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = tabBarController?.view.frame ?? .zero
        blurView.autoresizingMask = .flexibleWidth
        tabBar.insertSubview(blurView, at: 0)
    }
    
    private func setupGradient() {
        
        gradientSet.append([gradientOne, gradientTwo])
        gradientSet.append([gradientTwo, gradientThree])
        gradientSet.append([gradientThree, gradientOne])
        
        gradient.frame = self.view.bounds
        gradient.colors = gradientSet[currentGradient]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.drawsAsynchronously = true
        view.layer.insertSublayer(gradient, at: 0)
        
        animateGradient()
    }
    
    // MARK: - Gestures
    
    private func addGestures() {
        
        contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTapGesture)))
        contentView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture)))
    }
    
    @objc
    private func handleTapGesture(_ recognizer: UITapGestureRecognizer) {
        
        animateOrReverseRunningTransition(state: !state, duration: Constants.animationDuration)
    }
    
    @objc
    private func handlePanGesture(_ recognizer: UIPanGestureRecognizer) {
        
        guard !isCancelling else {
            return
        }
        
        let translation = recognizer.translation(in: contentView)
        
        switch recognizer.state {
        case .began:
            startInteractiveTransition(state: !state, duration: Constants.animationDuration)
        case .changed:
            updateInteractiveTransition(fractionComplete: fractionComplete(state: !state, translation: translation))
        case .ended:
            continueInteractiveTransition(fractionComplete: fractionComplete(state: !state, translation: translation))
        default:
            break
        }
    }
    
    private func fractionComplete(state: State, translation: CGPoint) -> CGFloat {
        
        let translationY = state == .expanded ? -translation.y : translation.y
        let fractionComplete = translationY / (view.frame.height - Constants.collapsedHeight - 0) + progressWhenInterrupted
        
        return fractionComplete
    }
    
    // MARK: - Animations
    
    func animateTransitionIfNeeded(state: State, duration: TimeInterval) {
        
        if runningAnimators.isEmpty {
            addControlViewFrameAnimator(state: state, duration: duration)
            addCornerRadiusAnimator(state: state, duration: duration)
            addTabBarAnimator(state: state, duration: duration)
            addAlbumCoverAnimation(state: state, duration: duration)
        }
    }
    
    func animateOrReverseRunningTransition(state: State, duration: TimeInterval) {
        
        if runningAnimators.isEmpty {
            animateTransitionIfNeeded(state: state, duration: duration)
            runningAnimators.forEach { $0.startAnimation() }
        } else {
            guard !isCancelling else {
                return
            }
            runningAnimators.forEach { $0.isReversed = !$0.isReversed }
        }
    }
    
    func startInteractiveTransition(state: State, duration: TimeInterval) {
        
        animateTransitionIfNeeded(state: state, duration: duration)
        runningAnimators.forEach { $0.pauseAnimation() }
        progressWhenInterrupted = runningAnimators.first?.fractionComplete ?? 0
    }
    
    func updateInteractiveTransition(fractionComplete: CGFloat) {
        
        runningAnimators.forEach { $0.fractionComplete = fractionComplete }
    }
    
    func continueInteractiveTransition(fractionComplete: CGFloat) {
        
        let cancel: Bool = fractionComplete < 0.1
        
        if cancel {
            guard !runningAnimators.isEmpty else {
                return
            }
            isCancelling = true
            runningAnimators.forEach {
                $0.isReversed = !$0.isReversed
                $0.continueAnimation(withTimingParameters: nil, durationFactor: 0.5)
            }
            return
        }
        let timing = UICubicTimingParameters(animationCurve: .easeOut)
        runningAnimators.forEach { $0.continueAnimation(withTimingParameters: timing, durationFactor: 0) }
    }
    
    // MARK: - PropertyAnimators
    
    private func addControlViewFrameAnimator(state: State, duration: TimeInterval) {
        
        let frameAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) { [self] in
            contentView.frame = state.getContentFrameIn(view)
        }
        
        frameAnimator.addCompletion { [weak self] position in
            
            guard let self = self else {
                return
            }
            switch position {
            case .current:
                break
            case .end:
                self.state = !self.state
            case .start:
                break
            default:
                break
            }
            self.runningAnimators.removeAll()
            if self.isCancelling {
                self.isCancelling = false
            }
        }
        
        runningAnimators.append(frameAnimator)
    }
    
    private func addTabBarAnimator(state: State, duration: TimeInterval) {
        
        guard let tabBar = tabBarController?.tabBar else {
            return
        }
        
        if !(state == .expanded) {
            tabBar.isHidden = false
        }
        
        let offsetY = view.frame.height - (state == .expanded ? 0 : tabBar.frame.size.height)
        let frame = CGRect(origin: CGPoint(x: tabBar.frame.minX, y: offsetY), size: tabBar.frame.size)
        
        let tabBarAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) {
            
            tabBar.frame = frame
        }
        runningAnimators.append(tabBarAnimator)
    }
    
    private func addAlbumCoverAnimation(state: State, duration: TimeInterval) {
        
        albumWidth.constant = state == .expanded ? view.frame.width - 22 : 61
        
        let albumCoverAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) {
            self.view.layoutIfNeeded()
        }
        runningAnimators.append(albumCoverAnimator)
    }
    
    private func addCornerRadiusAnimator(state: State, duration: TimeInterval) {
        
        let cornerRadiusAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) {
            self.contentView.layer.cornerRadius = state.cornerRadius
        }
        runningAnimators.append(cornerRadiusAnimator)
    }
}

// MARK: - Gradient

extension ViewController: CAAnimationDelegate {
    
    func animateGradient() {
        
        if currentGradient < gradientSet.count - 1 {
            currentGradient += 1
        } else {
            currentGradient = 0
        }
        
        let gradientChangeAnimation = CABasicAnimation(keyPath: "colors")
        gradientChangeAnimation.delegate = self
        gradientChangeAnimation.duration = 2.0
        gradientChangeAnimation.toValue = gradientSet[currentGradient]
        gradientChangeAnimation.fillMode = .forwards
        gradientChangeAnimation.isRemovedOnCompletion = false
        gradient.add(gradientChangeAnimation, forKey: "colorChange")
    }
    
    func animationDidStop(_ animation: CAAnimation, finished: Bool) {
        if finished {
            gradient.colors = gradientSet[currentGradient]
            animateGradient()
        }
    }
}
