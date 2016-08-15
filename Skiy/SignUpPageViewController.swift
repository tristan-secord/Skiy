//
//  SignUpPageViewController.swift
//  Skiy
//
//  Created by Tristan Secord on 2016-08-03.
//  Copyright © 2016 Tristan Secord. All rights reserved.
//

import UIKit

class SignUpPageViewController: UIPageViewController {
    
    var signUpVC : SignUpViewController?
    var signUpName : SignUpNameVC?
    var signUpEmail : SignUpEmailVC?
    var signUpPassword : SignUpPasswordVC?
    
    private(set) lazy var orderedViewControllers: [UIViewController] = {
        return [self.getViewController("SignUpNameVC"),
                self.getViewController("SignUpEmailVC"),
                self.getViewController("SignUpPasswordVC")]
    }()
    
    private func getViewController(identifier: String) -> UIViewController {
        let controller = UIStoryboard(name: "Main", bundle: nil) .
            instantiateViewControllerWithIdentifier(identifier)
        switch (identifier) {
        case "SignUpNameVC":
            signUpName = controller as? SignUpNameVC
            break
        case "SignUpEmailVC":
            signUpEmail = controller as? SignUpEmailVC
            break
        default:
            signUpPassword = controller as? SignUpPasswordVC
            break
        }
        
        return controller
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource = self
        
        if let firstViewController = orderedViewControllers.first {
            setViewControllers([firstViewController],
                               direction: .Forward,
                               animated: true,
                               completion: nil)
        }
    }
    
    /*let containerSegueName = "signUpSegue"
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == containerSegueName {
            signUpVC = segue.sourceViewController as? SignUpViewController
        }
    }*/

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func getSignUpNameVC() -> SignUpNameVC? {
        if ((signUpName == nil) || (signUpName!.firstName == nil) || (signUpName!.lastName == nil)) {
            return nil
        }
        return signUpName!
    }
    
    func getSignUpEmailVC() -> SignUpEmailVC? {
        if ((signUpEmail == nil)  || (signUpEmail!.username == nil) || (signUpEmail!.email == nil)) {
            return nil
        }
        return signUpEmail!
    }
    
    func getSignUpPasswordVC() -> SignUpPasswordVC? {
        if ((signUpPassword == nil)  || (signUpPassword!.password == nil) || (signUpPassword!.verifyPassword == nil)) {
            return nil
        }
        return signUpPassword!
    }
}

extension SignUpPageViewController: UIPageViewControllerDataSource {
    
    func pageViewController(pageViewController: UIPageViewController,
                            viewControllerBeforeViewController viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = orderedViewControllers.indexOf(viewController) else {
            return nil
        }
        
        let previousIndex = viewControllerIndex - 1
        
        guard previousIndex >= 0 else {
            return nil
        }
        
        guard orderedViewControllers.count > previousIndex else {
            return nil
        }
        
        return orderedViewControllers[previousIndex]
    }
    
    func pageViewController(pageViewController: UIPageViewController,
                            viewControllerAfterViewController viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = orderedViewControllers.indexOf(viewController) else {
            print ("Could not get viewController Index")
            return nil
        }
        
        //check information given first
        switch viewControllerIndex {
        case 0:
            guard signUpName!.checkFields() == true else {
                if (signUpVC == nil) {
                    print ("Sign up vc nil")
                }
                signUpVC!.displayErrorAlert("Looks like your missing some information...")
                break
            }
            break
        case 1:
            break
        default:
            break
        }
        
        let nextIndex = viewControllerIndex + 1
        let orderedViewControllersCount = orderedViewControllers.count
        
        guard orderedViewControllersCount != nextIndex else {
            return nil
        }
        
        guard orderedViewControllersCount > nextIndex else {
            return nil
        }
        
        return orderedViewControllers[nextIndex]
    }
}
