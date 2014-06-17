//
//  ZSWHierarchicalResultsSection.m
//  ZSWHierarchicalResultsController
//
//  Created by Zachary West on 6/17/14.
//  Copyright (c) 2014 Hey, Inc. All rights reserved.
//

#import "HLHierarchicalResultsSection.h"

@interface HLHierarchicalResultsSection()
@property (nonatomic, readwrite) NSArray *sortDescriptors;
@end

@implementation HLHierarchicalResultsSection

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p; object = %@, contained objects = %@>", NSStringFromClass([self class]), self, self.object, self.containedObjects];
}

- (NSUInteger)hash {
    return self.object.hash;
}

- (BOOL)isEqual:(HLHierarchicalResultsSection *)section {
    return [self.object isEqual:section.object];
}

- (NSComparisonResult)compare:(HLHierarchicalResultsSection *)anotherSection
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

@end
