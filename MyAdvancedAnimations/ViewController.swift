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
        
        func getFrameFrom(_ view: UIView) -> CGRect {
            
            switch self {
            case .collapsed:
                return CGRect(x: 0,
                              y: view.frame.height - Constants.collapsedHeight,
                              width: view.frame.width,
                              height: view.frame.height - 44)
            case .expanded:
                return CGRect(x: 0,
                              y: 44,
                              width: view.frame.width,
                              height: view.frame.height - 44)
            }
        }
        
        var next: State {
            switch self {
            case .collapsed:
                return .expanded
            case .expanded:
                return .collapsed
            }
        }
    }
    
    // MARK: - Constants
    
    enum Constants {
        static var animationDuration: TimeInterval = 0.35
        static var collapsedHeight: CGFloat = 170
    }
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var controlView: UIView!
    
    // MARK: - Private properties
    
    private var progressWhenInterrupted: CGFloat = 0
    private var runningAnimators = [UIViewPropertyAnimator]()
    private var state: State = .collapsed
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        controlView.frame = state.getFrameFrom(view)
        addGestures()
    }
    
    private func addGestures() {
        
        // Tap gesture
        controlView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTapGesture)))
        
        // Pan gesutre
        controlView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture)))
    }
    
    // MARK: - Gestures
    
    @objc
    private func handleTapGesture(_ recognizer: UITapGestureRecognizer) {
        
        animateOrReverseRunningTransition(state: state.next, duration: Constants.animationDuration)
    }
    
    @objc
    private func handlePanGesture(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: controlView)
        
        switch recognizer.state {
        case .began:
            startInteractiveTransition(state: state.next, duration: Constants.animationDuration)
        case .changed:
            updateInteractiveTransition(fractionComplete: fractionComplete(state: state.next, translation: translation))
        case .ended:
            continueInteractiveTransition(fractionComplete: fractionComplete(state: state.next, translation: translation))
        default:
            break
        }
    }
    
    private func fractionComplete(state: State, translation: CGPoint) -> CGFloat {
        
        let translationY = state == .expanded ? -translation.y : translation.y
        let fractionComplete = translationY / (view.frame.height - Constants.collapsedHeight - 0) + progressWhenInterrupted
        
        print("translationY: \(translationY) | fractionComplete: \(fractionComplete)")
        
        return fractionComplete
    }
    
    // MARK: - Animations
    
    func animateTransitionIfNeeded(state: State, duration: TimeInterval) {
        
        addCornerRadiusAnimator(state: state, duration: duration)
        addTabBarAnimator(state: state, duration: duration)
        
        let frameAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) {
            
            self.controlView.frame = state.getFrameFrom(self.view)
            print("Animating state: \(state)")
            print("Frame animator state:", state.getFrameFrom(self.view))
        }
        
        frameAnimator.addCompletion { position in
            switch position {
            case .start:
                print("Completion at start")
            case .end:
                print("Completion at end")
                self.state = self.state.next
            case .current:
                print("Completion at current")
            @unknown default:
                fatalError()
            }
            self.runningAnimators.removeAll()
        }
        
        runningAnimators.append(frameAnimator)
    }
    
    private func addTabBarAnimator(state: State, duration: TimeInterval) {
        
        guard let tabBar = tabBarController?.tabBar else {
            return
        }
        
        let isHidden = state == .expanded
        
        if !isHidden {
            tabBar.isHidden = false
        }
        
        let height = tabBar.frame.size.height
        let offsetY = view.frame.height - (isHidden ? 0 : height)
        let frame = CGRect(origin: CGPoint(x: tabBar.frame.minX, y: offsetY), size: tabBar.frame.size)
        
        let tabBarAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) {
            
            tabBar.frame = frame
        }
        runningAnimators.append(tabBarAnimator)
    }
    
    private func addCornerRadiusAnimator(state: State, duration: TimeInterval) {
        controlView.clipsToBounds = true
        // Corner mask
        if #available(iOS 11, *) {
            controlView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }
        let cornerRadiusAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) { [self] in
            switch state {
            case .expanded:
                self.controlView.layer.cornerRadius = 20
            case .collapsed:
                self.controlView.layer.cornerRadius = 0
            }
        }
        runningAnimators.append(cornerRadiusAnimator)
    }
    
    func animateOrReverseRunningTransition(state: State, duration: TimeInterval) {
        
        if runningAnimators.isEmpty {
            animateTransitionIfNeeded(state: state, duration: duration)
            runningAnimators.forEach { $0.startAnimation() }
        } else {
            runningAnimators.forEach { $0.isReversed = !$0.isReversed }
        }
    }
    
    func startInteractiveTransition(state: State, duration: TimeInterval) {
        
        animateTransitionIfNeeded(state: state, duration: duration)
        runningAnimators.forEach { $0.pauseAnimation() }
        progressWhenInterrupted = runningAnimators.first?.fractionComplete ?? 0
    }
    
    func updateInteractiveTransition(fractionComplete: CGFloat) {
        //        runningAnimators.first.fr
        runningAnimators.forEach { $0.fractionComplete = fractionComplete }
    }
    
    func continueInteractiveTransition(fractionComplete: CGFloat) {
        
        let cancel: Bool = fractionComplete < 0.2
        
        if cancel {
            runningAnimators.forEach {
                $0.isReversed = !$0.isReversed
                $0.continueAnimation(withTimingParameters: nil, durationFactor: 0)
            }
            return
        }
        
        let timing = UICubicTimingParameters(animationCurve: .easeOut)
        runningAnimators.forEach { $0.continueAnimation(withTimingParameters: timing, durationFactor: 0) }
    }
}

extension UITabBarController {
    
    func setTabBarHidden(_ isHidden: Bool, animated: Bool, completion: (() -> Void)? = nil ) {
        if (tabBar.isHidden == isHidden) {
            completion?()
        }
        
        if !isHidden {
            tabBar.isHidden = false
        }
        
        let height = tabBar.frame.size.height
        let offsetY = view.frame.height - (isHidden ? 0 : height)
        let duration = (animated ? 0.25 : 0.0)
        
        let frame = CGRect(origin: CGPoint(x: tabBar.frame.minX, y: offsetY), size: tabBar.frame.size)
        UIView.animate(withDuration: duration, animations: {
            self.tabBar.frame = frame
        }) { _ in
            self.tabBar.isHidden = isHidden
            completion?()
        }
    }
}
