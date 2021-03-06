//
//  NSURL+URLWithQueryItems.h
//  PirateRadio
//
//  Created by A-Team User on 10.05.18.
//  Copyright © 2018 A-Team User. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURL (URLWithQueryItems)

-(NSURL *) URLByAppendingQueryItems:(NSArray<NSURLQueryItem *> *)queryItems;
-(NSURL *) URLByAppendingQueryItems:(NSArray<NSURLQueryItem *> *)queryItems withCheckForDuplicates:(BOOL)checkForDuplicates;

@end
