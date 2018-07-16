//
//  LoginViewController.h
//  PirateRadio
//
//  Created by A-Team User on 28.06.18.
//  Copyright © 2018 A-Team User. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Protocols.h"

@interface LoginViewController : UIViewController <UITextFieldDelegate>

@property (strong, nonatomic) id<ProfileLoginPresenterDelegate> profileDelegate;

@end
