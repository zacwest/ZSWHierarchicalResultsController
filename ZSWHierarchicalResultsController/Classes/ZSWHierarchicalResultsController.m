//
//  ZSWHierarchicalResultsController.m
//  ZSWHierarchicalResultsController
//
//  Created by Zachary West on 6/13/14.
//  Copyright (c) 2014 Hey, Inc. All rights reserved.
//

#import "HLHierarchicalResultsController.h"
#import "HLHierarchicalResultsSection.h"

HLDefineLogLevel(LOG_LEVEL_VERBOSE);

@interface HLHierarchicalResultsController()
@property (nonatomic, copy) NSFetchRequest *fetchRequest;
@property (nonatomic, copy) NSString *childKey;
@property (nonatomic, strong) NSManagedObjectContext *context;

@property (nonatomic, weak, readwrite) id<HLHierarchicalResultsDelegate> delegate;

@property (nonatomic, strong) NSArray *sections;
@end

@implementation HLHierarchicalResultsController

#pragma mark - Lifecycle

- (instancetype)initWithFetchRequest:(NSFetchRequest *)fetchRequest
                            childKey:(NSString *)childKey
                managedObjectContext:(NSManagedObjectContext *)context
                            delegate:(id<HLHierarchicalResultsDelegate>)delegate {
    NSParameterAssert(fetchRequest != nil);
    NSParameterAssert(childKey != nil);
    NSParameterAssert(context != nil);
    
    NSAssert(fetchRequest.sortDescriptors.count > 0,
             @"At least one sort descriptor is required for %@", fetchRequest);
    
    NSEntityDescription *entity;
    
    if (fetchRequest.entityName) {
        entity = [NSEntityDescription entityForName:fetchRequest.entityName inManagedObjectContext:context];
    } else {
        entity = fetchRequest.entity;
    }
    
    NSRelationshipDescription *relationship = entity.relationshipsByName[childKey];
    
    NSAssert(relationship != nil,
             @"childKey %@ must be a relationship on %@", childKey, entity);
    
    NSAssert(relationship.isOrdered,
             @"childKey %@ must be ordered relationship on %@", childKey, entity);
    
    self = [super init];
    if (self) {
        NSFetchRequest *updatedFetchRequest = [fetchRequest copy];
        NSMutableArray *prefetchRelationships = [updatedFetchRequest.relationshipKeyPathsForPrefetching mutableCopy];
        [prefetchRelationships addObject:childKey];
        updatedFetchRequest.relationshipKeyPathsForPrefetching = prefetchRelationships;
        
        self.fetchRequest = updatedFetchRequest;
        self.childKey = childKey;
        self.context = context;
        self.delegate = delegate;
        
        [self initializeFetch];
    }
    return self;
}

- (instancetype)initWithParentObject:(NSManagedObject *)parentObject
                            childKey:(NSString *)childKey
                managedObjectContext:(NSManagedObjectContext *)context
                            delegate:(id<HLHierarchicalResultsDelegate>)delegate {
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:parentObject.entity.name];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"self == %@", parentObject];
    return [self initWithFetchRequest:fetchRequest childKey:childKey managedObjectContext:context delegate:delegate];
}

- (id)init {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (void)initializeFetch {
    NSError *error;
    NSArray *sectionObjects = [self.context executeFetchRequest:self.fetchRequest
                                                      error:&error];
    if (!sectionObjects) {
        DDLogError(@"Failed to fetch objects: %@", error);
    }
    
    self.sections = [sectionObjects bk_map:^id(id obj) {
        return [self newSectionInfoForObject:obj];
    }];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(objectsDidChange:)
                                                 name:NSManagedObjectContextObjectsDidChangeNotification
                                               object:self.context];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Object observing
- (NSIndexSet *)updateSectionsWithInsertedObjects:(NSArray *)insertedObjects {
    if (insertedObjects.count == 0) {
        return nil;
    }
    
    NSMutableArray *updatedSections = [NSMutableArray arrayWithArray:self.sections];
    NSMutableIndexSet *insertedSet = [NSMutableIndexSet indexSet];
    
    NSArray *sortDescriptors = self.fetchRequest.sortDescriptors;
    NSComparator comparator = ^NSComparisonResult(HLHierarchicalResultsSection *section1,
                                                  HLHierarchicalResultsSection *section2) {
        return [section1 compare:section2 usingSortDescriptors:sortDescriptors];
    };
    
    for (id insertedObject in insertedObjects) {
        HLHierarchicalResultsSection *section = [self newSectionInfoForObject:insertedObject];
        NSInteger insertIdx = [updatedSections indexOfObject:section
                                               inSortedRange:NSMakeRange(0, updatedSections.count)
                                                     options:NSBinarySearchingInsertionIndex
                                             usingComparator:comparator];
        [insertedSet addIndex:insertIdx];
        
        [updatedSections insertObject:section atIndex:insertIdx];
    }
    
    self.sections = updatedSections;
    
    return insertedSet;
}

- (NSIndexSet *)updateSectionsWithDeletedObjects:(NSArray *)deletedObjects {
    if (deletedObjects.count == 0) {
        return nil;
    }
    
    NSMutableArray *updatedSections = [NSMutableArray arrayWithArray:self.sections];
    NSMutableIndexSet *deletedSet = [NSMutableIndexSet indexSet];
    
    for (id deletedObject in deletedObjects) {
        HLHierarchicalResultsSection *section = [self sectionInfoForObject:deletedObject index:NULL];
        NSInteger deleteIdx = [self.sections indexOfObject:section];
        [deletedSet addIndex:deleteIdx];
        [updatedSections removeObjectAtIndex:deleteIdx];
    }
    
    self.sections = updatedSections;
    
    return deletedSet;
}

// this method guarantees that the out parameters will be unmodified if unchanged
- (void)updateSectionsWithUpdatedObjects:(NSArray *)updatedObjects
                      insertedIndexPaths:(out NSArray **)insertedIndexPaths
                       deletedIndexPaths:(out NSArray **)deletedIndexPaths {
    if (!updatedObjects.count) {
        return;
    }
    
    
}

- (void)objectsDidChange:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSEntityDescription *entity = self.fetchRequest.entity;
    
    // Grab all objects which are our parent object type
    BOOL (^matchesObject)(id) = ^(NSManagedObject *obj){
        return [obj.entity isKindOfEntity:entity];
    };
    
    NSArray *advertisedInsertedObjects = [userInfo[NSInsertedObjectsKey] bk_select:matchesObject];
    NSArray *advertisedUpdatedObjects = [userInfo[NSUpdatedObjectsKey] bk_select:matchesObject];
    NSArray *advertisedDeletedObjects = [userInfo[NSDeletedObjectsKey] bk_select:matchesObject];
    
    if (!advertisedInsertedObjects.count && !advertisedUpdatedObjects.count && !advertisedDeletedObjects.count) {
        // early abort if we have no work to do.
        return;
    }
    
    // Now, we need to update inserted/updated/deleted to be true about objects matching
    // the predicate. So, if something is updated to not match, consider it deleted,
    // and if it's inserted but doesn't match, don't include it.
    
    NSPredicate *fetchRequestPredicate = self.fetchRequest.predicate;
    NSArray *insertedObjects = [advertisedInsertedObjects filteredArrayUsingPredicate:fetchRequestPredicate];
    
    // Avoiding more memory hits is better than using a bit more memory.
    const NSInteger capacity = advertisedUpdatedObjects.count + advertisedDeletedObjects.count;
    
    NSMutableArray *updatedObjects = [NSMutableArray arrayWithCapacity:capacity];
    NSMutableArray *deletedObjects = [NSMutableArray arrayWithCapacity:capacity];
    
    for (NSManagedObject *updatedObject in advertisedUpdatedObjects) {
        if ([fetchRequestPredicate evaluateWithObject:updatedObject]) {
            [updatedObjects addObject:updatedObject];
        } else {
            [deletedObjects addObject:updatedObject];
        }
    }
    
    [deletedObjects addObjectsFromArray:advertisedDeletedObjects];
    
    //
    
    NSLog(@"Inserted: %@, updated: %@, deleted: %@", insertedObjects, updatedObjects, deletedObjects);
    
    NSIndexSet *insertedSet = [self updateSectionsWithInsertedObjects:insertedObjects];
    NSIndexSet *deletedSet = [self updateSectionsWithDeletedObjects:deletedObjects];
    
    NSArray *insertedItems, *deletedItems;
    
    [self updateSectionsWithUpdatedObjects:updatedObjects
                        insertedIndexPaths:&insertedItems
                         deletedIndexPaths:&deletedItems];
    
    if (insertedSet || deletedSet || insertedItems || deletedItems) {
        [self.delegate hierarchicalController:self
                didUpdateWithInsertedSections:insertedSet
                              deletedSections:deletedSet
                                insertedItems:insertedItems
                                 deletedItems:deletedItems];
    }
}

#pragma mark - Getters

- (HLHierarchicalResultsSection *)newSectionInfoForObject:(id)object {
    HLHierarchicalResultsSection *section = [[HLHierarchicalResultsSection alloc] init];
    section.object = object;
    section.containedObjects = [[[object valueForKey:self.childKey] array] copy];
    return section;
}

- (HLHierarchicalResultsSection *)sectionInfoForObject:(id)object index:(out NSInteger *)outIndex {
    // todo: faster
    
    __block HLHierarchicalResultsSection *returnSection;
    __block NSInteger returnIdx;
    
    [self.sections enumerateObjectsUsingBlock:^(HLHierarchicalResultsSection *section, NSUInteger idx, BOOL *stop) {
        if (section.object == object) {
            returnSection = section;
            returnIdx = idx;
        }
    }];
    
    if (outIndex) {
        *outIndex = returnIdx;
    }
    
    return returnSection;
}

- (HLHierarchicalResultsSection *)sectionInfoForSection:(NSInteger)section {
    return self.sections[section];
}

- (NSInteger)numberOfSections {
    return self.sections.count;
}

- (NSInteger)numberOfObjectsInSection:(NSInteger)section {
    return [self sectionInfoForSection:section].containedObjects.count;
}

- (id)objectForSection:(NSInteger)section {
    return [self sectionInfoForSection:section].object;
}

- (id)objectAtIndexPath:(NSIndexPath *)indexPath {
    return [self sectionInfoForSection:indexPath.section].containedObjects[indexPath.item];
}

- (NSArray *)allObjectsInSection:(NSInteger)section {
    return [self sectionInfoForSection:section].containedObjects;
}

@end
