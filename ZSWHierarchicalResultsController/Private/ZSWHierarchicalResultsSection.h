//
//  ZSWHierarchicalResultsSection.h
//  ZSWHierarchicalResultsController
//
//  Created by Zachary West on 6/17/14.
//  Copyright (c) 2014 Hey, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HLHierarchicalResultsSection : NSObject

@property (nonatomic) NSManagedObject *object;
@property (nonatomic) NSArray *containedObjects;

- (NSComparisonResult)compare:(HLHierarchicalResultsSection *)anotherSection
         usingSortDescriptors:(NSArray *)sortDescriptors;

@end
