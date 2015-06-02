//
//  ZSWFixtures.h
//  Tests
//
//  Created by Zachary West on 2015-06-02.
//  Copyright (c) 2015 Zachary West. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OuterObject.h"
#import "InnerObject.h"
#import "ZSWMacros.h"

@interface ZSWFixtures : NSObject

+ (NSManagedObjectContext *)context;
+ (OuterObject *)outerObjectWithInnerCount:(NSInteger)innerCount context:(NSManagedObjectContext *)context;
+ (InnerObject *)innerObjectWithContext:(NSManagedObjectContext *)context;

@end
