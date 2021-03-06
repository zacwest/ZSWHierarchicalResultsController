//
//  ZSWHierarchicalResultsSection.h
//  ZSWHierarchicalResultsController
//
//  Created by Zachary West on 6/17/14.
//  Copyright (c) 2014 Hey, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface ZSWHierarchicalResultsSection : NSObject

@property (nonatomic) NSInteger sectionIdx;
@property (nonatomic) NSManagedObject *object;

// note this copies because the proxy from core data live-updates and we don't want that
@property (nonatomic, copy) NSArray *containedObjects;

- (NSInteger)countOfContainedObjects;
- (id)objectInContainedObjectsAtIndex:(NSUInteger)idx;
- (id)objectAtIndexedSubscript:(NSUInteger)idx;

- (NSComparisonResult)compare:(ZSWHierarchicalResultsSection *)anotherSection
         usingSortDescriptors:(NSArray *)sortDescriptors;

@end
