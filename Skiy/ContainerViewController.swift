//
//  ContainerViewController.swift
//  Skiy
//
//  Created by Tristan Secord on 2016-05-21.
//  Copyright © 2016 Tristan Secord. All rights reserved.
//

import UIKit

class ContainerViewController: UIViewController {
    
    enum controllerState {
        case Hidden
        case Visible
    }
    
    var currentState = controllerState.Hidden
    var controlPanelViewController: ControlPanelViewController!
    var mapViewController: ViewController!
    var signInViewController: SignInViewController!
    var signUpViewController: SignUpViewController!
    var addFriendViewController: AddFriendViewController?
    var viewWidth: CGFloat = 0.0
    var viewHeight: CGFloat = 0.0
    var blurView = UIImageView()
    let defaults = NSUserDefaults.standardUserDefaults()
    let appDelegate =
        UIApplication.sharedApplication().delegate as! AppDelegate
    
    override func viewDidLoad() {
        super.viewDidLoad()

        viewWidth = view.frame.size.width
        viewHeight = view.frame.size.height
        
        //instantiate mapViewController
        mapViewController = UIStoryboard.mapViewController()
        mapViewController.view.frame = CGRectMake(0, 0, viewWidth, viewHeight)
        mapViewController.delegate = self
        view.addSubview(mapViewController.view)
        addChildViewController(mapViewController)
        mapViewController.didMoveToParentViewController(self)
        
        //instantiate controlPanelViewController
        instantiateControlPanelViewController()
        
        //instantiate signInViewController
        signInViewController = UIStoryboard.signInViewController()
        signInViewController.delegate = self
        signInViewController.view.frame = CGRectMake(0, 0, viewWidth, viewHeight)
        
        signUpViewController = UIStoryboard.signUpViewController()
        signUpViewController.delegate = self
        signUpViewController.view.frame = CGRectMake(0, 0, viewWidth, viewHeight);
    }
    
    func instantiateControlPanelViewController() {
        controlPanelViewController = UIStoryboard.controlPanelViewController()
        controlPanelViewController.delegate = self
        controlPanelViewController.view.frame = CGRectMake(0, -viewHeight, viewWidth, viewHeight + 66)
        
        //add Gesture Recognizer to control panel
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(ContainerViewController.handlePanGesture(_:)))
        controlPanelViewController!.view.addGestureRecognizer(panGestureRecognizer)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(true)
        
        //try and use single map
        if defaults.objectForKey("userLoggedIn") == nil {
            controlPanelViewController.clearCoreData()
            hideContentController(controlPanelViewController, animation: true)
            displayContentController(signInViewController, animation: true)
        } else {
            displayContentController(controlPanelViewController, animation: true)
            hideContentController(signInViewController, animation: true)
        }
    }
    
    func hideContentController(content: UIViewController, animation: Bool) {
        content.willMoveToParentViewController(nil)
        if (animation == true) {
            UIView.animateWithDuration(0.5, animations: {content.view.alpha = 0.0},
                                       completion: {(value: Bool) in
                                        content.view.removeFromSuperview()
            })
        } else {
            content.view.removeFromSuperview()
        }
        content.removeFromParentViewController()
    }
    
    func displayContentController(content: UIViewController, animation: Bool) {
        addChildViewController(content)
        content.view.alpha = 0.0
        UIView.animateWithDuration(0.5, animations: {content.view.alpha = 1.0},
                                    completion: {(value: Bool) in
                                    self.view.addSubview(content.view)
        })
        content.didMoveToParentViewController(self)
    }
}

private extension UIStoryboard {
    class func mainStoryboard() -> UIStoryboard { return UIStoryboard(name: "Main", bundle: NSBundle.mainBundle()) }
    
    class func controlPanelViewController() -> ControlPanelViewController? {
        return mainStoryboard().instantiateViewControllerWithIdentifier("ControlPanelViewController") as? ControlPanelViewController
    }
    
    class func mapViewController() -> ViewController? {
        return mainStoryboard().instantiateViewControllerWithIdentifier("ViewController") as? ViewController
    }
    
    class func signInViewController() -> SignInViewController? {
        return mainStoryboard().instantiateViewControllerWithIdentifier("SignInViewController") as? SignInViewController
    }
    
    class func signUpViewController() -> SignUpViewController? {
        return mainStoryboard().instantiateViewControllerWithIdentifier("SignUpViewController") as? SignUpViewController
    }
}

extension ContainerViewController: UIGestureRecognizerDelegate {
    
    func handlePanGesture(recognizer: UIPanGestureRecognizer) {
        let gestureIsDraggingFromTopToBottom = (recognizer.velocityInView(view).y > 0)
        let gestureIsDraggingFromBottomToTop = (recognizer.velocityInView(view).y < 0)
        switch(recognizer.state) {
        case .Changed:
            if (currentState == .Visible && gestureIsDraggingFromBottomToTop) {
                recognizer.view!.center.y = recognizer.view!.center.y + recognizer.translationInView(view).y
                recognizer.setTranslation(CGPointZero, inView: view)
            } else if (currentState == .Hidden && gestureIsDraggingFromTopToBottom) {
                recognizer.view!.center.y = recognizer.view!.center.y + recognizer.translationInView(view).y
                recognizer.setTranslation(CGPointZero, inView: view)
            }
        case .Ended:
            if (controlPanelViewController != nil) {
                // animate the side panel open or closed based on whether the view has moved more or less than quarter way
                if gestureIsDraggingFromTopToBottom {
                    if currentState == .Hidden {
                        let hasMovedGreaterThanQuarterWay = recognizer.view!.center.y > -viewHeight + view.bounds.size.height/4
                        animateControlPanel(hasMovedGreaterThanQuarterWay)
                    }
                } else if gestureIsDraggingFromBottomToTop {
                    if currentState == .Visible {
                        let hasMovedGreaterThanQuarterWay = recognizer.view!.center.y < -viewHeight / 4
                        animateControlPanel(hasMovedGreaterThanQuarterWay)
                    }
                }
            }
        default:
            break
        }
    }
}

extension ContainerViewController: ViewControllerDelegate {
    
    func animateControlPanel(shouldExpand: Bool) {
        if (shouldExpand) {
            currentState = .Visible
            animateControlPanelYPosition(0)
        } else {
            animateControlPanelYPosition(-CGRectGetHeight(mapViewController.view.frame)) { finished in
                self.currentState = .Hidden
            }
        }
    }
    
    func animateControlPanelYPosition(targetPosition: CGFloat, completion: ((Bool) -> Void)! = nil) {
        UIView.animateWithDuration(0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: .CurveEaseInOut, animations: {
            self.controlPanelViewController!.view.frame.origin.y = targetPosition
            }, completion: completion)
    }
}

extension ContainerViewController: SignInViewControllerDelegate {
    func SignedIn() {
        instantiateControlPanelViewController()
        hideContentController(signInViewController, animation: true)
        displayContentController(controlPanelViewController, animation: true)
        if defaults.objectForKey("userLoggedIn") != nil {
            appDelegate.updateData()
        }
    }
    
    func showSignUp() {
        displayContentController(signUpViewController, animation: true)
    }
}

extension ContainerViewController: ControlPanelViewControllerDelegate {
    func SignedOut() {
        animateControlPanel(false)
        hideContentController(controlPanelViewController, animation: true)
        controlPanelViewController = nil
        displayContentController(signInViewController, animation: true)
    }
    
    func showAddFriendViewController() {
        addFriendViewController = AddFriendViewController()
        addFriendViewController!.delegate = self
        if (addFriendViewController != nil) {
            hideContentController(controlPanelViewController, animation: true)
            displayContentController(addFriendViewController!, animation: true)
        }
    }
    
    func addFriend(username: String, status: String, selectedCell: FindFriendsCell?) {
        addFriendViewController = AddFriendViewController()
        addFriendViewController!.delegate = self
        addFriendViewController!.addFriend(username, status: status, selectedCell: nil)
    }
    
    func removeFriend(username: String, selectedCell: FindFriendsCell?) {
        addFriendViewController = AddFriendViewController()
        addFriendViewController!.delegate = self
        addFriendViewController!.removeFriend(username, selectedCell: nil)
    }
}

extension ContainerViewController: SignUpViewControllerDelegate {
    func hideSignUp(animation: Bool) {
        hideContentController(signUpViewController, animation: animation)
    }
}

extension ContainerViewController: AddFriendDelegate {
    func hideAddFriend() {
        if (addFriendViewController != nil) {
            hideContentController(addFriendViewController!, animation: true)
            displayContentController(controlPanelViewController, animation: true)
        }
    }
    
    func updateFriendsTableView() {
        print("updateFriendsTableView")
        controlPanelViewController.refreshFriendsTV()
    }
}