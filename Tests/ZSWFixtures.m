//
//  ZSWFixtures.m
//  Tests
//
//  Created by Zachary West on 2015-06-02.
//  Copyright (c) 2015 Zachary West. All rights reserved.
//

#import "ZSWFixtures.h"
#import <CoreData/CoreData.h>

@implementation ZSWFixtures

+ (NSManagedObjectContext *)context {
    NSManagedObjectModel *model = [NSManagedObjectModel mergedModelFromBundles:
                                   @[ [NSBundle bundleForClass:[self class]] ]];
    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    
    NSError *error;
    BOOL added = [coordinator addPersistentStoreWithType:NSInMemoryStoreType
                                           configuration:nil
                                                     URL:nil
                                                 options:nil
                                                   error:&error];
    if (!added) {
        NSLog(@"Failed to create: %@", error);
    }
    
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    context.persistentStoreCoordinator = coordinator;
    return context;
}

+ (OuterObject *)outerObjectWithContext:(NSManagedObjectContext *)context {
    return [self outerObjectWithInnerCount:0 context:context];
}

+ (OuterObject *)outerObjectWithInnerCount:(NSInteger)innerCount
                                   context:(NSManagedObjectContext *)context {
    OuterObject *object = [NSEntityDescription insertNewObjectForEntityForName:ZSWClass(OuterObject) inManagedObjectContext:context];
    object.outerSortKey = [NSUUID UUID].UUIDString;
    
    NSMutableOrderedSet *orderedSet = [NSMutableOrderedSet orderedSet];
    for (NSInteger idx = 0; idx < innerCount; idx++) {
        [orderedSet addObject:[self innerObjectWithContext:context]];
    }
    object.objects = orderedSet;
    
    return object;
}
         
+ (InnerObject *)innerObjectWithContext:(NSManagedObjectContext *)context {
    InnerObject *object = [NSEntityDescription insertNewObjectForEntityForName:ZSWClass(InnerObject) inManagedObjectContext:context];
    object.innerSortKey = [NSUUID UUID].UUIDString;
    return object;
}

@end
