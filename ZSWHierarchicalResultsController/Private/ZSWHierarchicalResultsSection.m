//
//  ZSWHierarchicalResultsSection.m
//  ZSWHierarchicalResultsController
//
//  Created by Zachary West on 6/17/14.
//  Copyright (c) 2014 Hey, Inc. All rights reserved.
//

#import "ZSWHierarchicalResultsSection.h"

@interface ZSWHierarchicalResultsSection()
@property (nonatomic, readwrite) NSArray *sortDescriptors;
@end

@implementation ZSWHierarchicalResultsSection

- (id)init {
    self = [super init];
    if (self) {
        self.sectionIdx = NSNotFound;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p; object = %@, contained objects = %@>", NSStringFromClass([self class]), self, self.object, self.containedObjects];
}

- (NSUInteger)hash {
    return self.object.hash;
}

- (BOOL)isEqual:(ZSWHierarchicalResultsSection *)section {
    return [self.object isEqual:section.object];
}

- (NSComparisonResult)compare:(ZSWHierarchicalResultsSection *)anotherSection
         usingSortDescriptors:(NSArray *)sortDescriptors {
    NSComparisonResult result = NSOrderedSame;
    
    for (NSSortDescriptor *sortDescriptor in sortDescriptors) {
        result = [sortDescriptor compareObject:self.object toObject:anotherSection.object];
        
        if (result != NSOrderedSame) {
            break;
        }
    }
    
    return result;
}

- (NSInteger)countOfContainedObjects {
    return self.containedObjects.count;
}

- (id)objectInContainedObjectsAtIndex:(NSUInteger)idx {
    // this keeps the same error-throwing behavior as accessing the array
    return self.containedObjects[idx];
}

- (id)objectAtIndexedSubscript:(NSUInteger)idx {
    if (idx < self.containedObjects.count) {
        return self.containedObjects[idx];
    } else {
        NSLog(@"Asked for object at idx %zd in section %zd but out of bounds", idx, self.sectionIdx);
        return nil;
    }
}

@end
