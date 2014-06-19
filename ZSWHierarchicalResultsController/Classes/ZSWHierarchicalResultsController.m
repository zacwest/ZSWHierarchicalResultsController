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
@property (nonatomic, copy) NSString *inverseChildKey;
@property (nonatomic, strong) NSManagedObjectContext *context;

@property (nonatomic, weak, readwrite) id<HLHierarchicalResultsDelegate> delegate;

@property (nonatomic, strong) NSArray *sections;

@property (nonatomic, strong) NSArray *sortDescriptors;
@property (nonatomic, strong) NSArray *reverseSortDescriptors;

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
    
    NSAssert(relationship.inverseRelationship != nil,
             @"childKey %@ must have an inverse relationship on %@", childKey, relationship.destinationEntity.name);
    
    self = [super init];
    if (self) {
        NSFetchRequest *updatedFetchRequest = [fetchRequest copy];
        NSMutableArray *prefetchRelationships = [updatedFetchRequest.relationshipKeyPathsForPrefetching mutableCopy];
        [prefetchRelationships addObject:childKey];
        updatedFetchRequest.relationshipKeyPathsForPrefetching = prefetchRelationships;
        
        if (!updatedFetchRequest.predicate) {
            updatedFetchRequest.predicate = [NSPredicate predicateWithValue:YES];
        }
        
        self.fetchRequest = updatedFetchRequest;
        
        self.sortDescriptors = updatedFetchRequest.sortDescriptors;
        self.reverseSortDescriptors = [self.sortDescriptors bk_map:^id(NSSortDescriptor *sortDescriptor) {
            return [sortDescriptor reversedSortDescriptor];
        }];
        
        self.childKey = childKey;
        self.inverseChildKey = relationship.inverseRelationship.name;
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
    fetchRequest.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES] ];
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

- (NSComparator)comparatorForSections {
    NSArray *sortDescriptors = self.sortDescriptors;
    
    return ^NSComparisonResult(HLHierarchicalResultsSection *sectionInfo1,
                               HLHierarchicalResultsSection *sectionInfo2) {
        return [sectionInfo1 compare:sectionInfo2 usingSortDescriptors:sortDescriptors];
    };
}

- (NSIndexSet *)updateSectionsWithInsertedObjects:(NSArray *)insertedObjects {
    if (insertedObjects.count == 0) {
        return nil;
    }
    
#ifdef CONFIGURATION_Debug
    NSAssert([insertedObjects isEqualToArray:[insertedObjects sortedArrayUsingDescriptors:self.sortDescriptors]], @"This method must be passed sorted objects to keep stable indexes in the index set (otherwise we could have 2 inserts on a single index, which the index set coalesces)");
#endif
    
    NSMutableArray *updatedSections = [NSMutableArray arrayWithArray:self.sections];
    NSMutableIndexSet *insertedSet = [NSMutableIndexSet indexSet];
    
    NSComparator comparator = [self comparatorForSections];
    
    NSInteger lastInsertedIdx = 0;
    
    for (id insertedObject in insertedObjects) {
        // note: section indices on section objects are not valid in this method
        
        HLHierarchicalResultsSection *sectionInfo = [self newSectionInfoForObject:insertedObject];
        NSInteger insertIdx = [updatedSections indexOfObject:sectionInfo
                                               inSortedRange:NSMakeRange(lastInsertedIdx, updatedSections.count - lastInsertedIdx)
                                                     options:NSBinarySearchingInsertionIndex
                                             usingComparator:comparator];
        
        [insertedSet addIndex:insertIdx];
        [updatedSections insertObject:sectionInfo atIndex:insertIdx];
        
        // we keep the last inserted index since we're inserting in order,
        // this way we can speed up the math a bit
        lastInsertedIdx = insertIdx;
    }
    
    self.sections = updatedSections;
    
    return insertedSet;
}

- (NSIndexSet *)updateSectionsWithDeletedObjects:(NSArray *)deletedObjects {
    if (deletedObjects.count == 0) {
        return nil;
    }

#ifdef CONFIGURATION_Debug
    NSAssert([deletedObjects isEqualToArray:[deletedObjects sortedArrayUsingDescriptors:self.reverseSortDescriptors]], @"This method must be passed sorted objects to keep stable indexes in the index set (otherwise we could have 2 inserts on a single index, which the index set coalesces)");
#endif
    
    NSMutableArray *updatedSections = [NSMutableArray arrayWithArray:self.sections];
    NSMutableIndexSet *deletedSet = [NSMutableIndexSet indexSet];
    
    for (id deletedObject in deletedObjects) {
        // note: section indices on section objects are not valid in this method
        // but since we're going backwards, our indices are valid before our current delete point
        HLHierarchicalResultsSection *sectionInfo = [self sectionInfoForObject:deletedObject];
        [deletedSet addIndex:sectionInfo.sectionIdx];
    }
    
    [updatedSections removeObjectsAtIndexes:deletedSet];
    
    self.sections = updatedSections;
    
    return deletedSet;
}

// this method guarantees that the out parameters will be unmodified if unchanged
- (void)updateSectionsWithUpdatedObjects:(NSArray *)updatedObjects
                      insertedIndexPaths:(out NSArray **)outInsertedIndexPaths
                       deletedIndexPaths:(out NSArray **)outDeletedIndexPaths {
    if (!updatedObjects.count) {
        return;
    }
    
    // Remember, we ask our delegates to process deletes before inserts, so we need to also do that
    // so our index paths match up to the expected locations.
    
    NSMutableArray *insertedIndexPaths = [NSMutableArray array];
    NSMutableArray *deletedIndexPaths = [NSMutableArray array];
    
    for (NSManagedObject *object in updatedObjects) {
        HLHierarchicalResultsSection *sectionInfo = [self sectionInfoForObject:object];
        NSInteger sectionIdx = sectionInfo.sectionIdx;
        
        NSArray *existingItems = sectionInfo.containedObjects;
        NSArray *updatedItems = [[object valueForKeyPath:self.childKey] array];

        NSSet *existingItemsSet = [NSSet setWithArray:existingItems];
        NSSet *updatedItemsSet = [NSSet setWithArray:updatedItems];
        
        NSMutableIndexSet *deletedIndexSet = [NSMutableIndexSet indexSet];
        NSMutableIndexSet *insertedIndexSet = [NSMutableIndexSet indexSet];
        
        for (NSInteger existingIdx = 0, updatedIdx = 0;
             existingIdx < existingItems.count || updatedIdx < updatedItems.count;
             /* no increment */) {
            id existingObject = existingIdx < existingItems.count ? existingItems[existingIdx] : nil;
            id updatedObject = updatedIdx < updatedItems.count ? updatedItems[updatedIdx] : nil;
            
            if (updatedObject && ![existingItemsSet containsObject:updatedObject]) {
                // We inserted this one. Skip this one.
                [insertedIndexSet addIndex:updatedIdx];
                updatedIdx++;
                continue;
            }
            
            if (existingObject && ![updatedItemsSet containsObject:existingObject]) {
                // We deleted this one. Skip this now.
                [deletedIndexSet addIndex:existingIdx];
                existingIdx++;
                continue;
            }
            
            if (existingObject != updatedObject) {
                // We moved this object within the list.
                // We don't support multi-section move, and implementing intra-section move is tough
                // so let's just consider this a delete and insert
                [deletedIndexSet addIndex:existingIdx];
                [insertedIndexSet addIndex:updatedIdx];
            }
            
            existingIdx++;
            updatedIdx++;
        }
        
        // Finally, put together the index paths
        [insertedIndexSet enumerateIndexesWithOptions:0
                                           usingBlock:^(NSUInteger idx, BOOL *stop) {
                                               NSIndexPath *indexPath = [NSIndexPath indexPathForItem:idx inSection:sectionIdx];
                                               [insertedIndexPaths addObject:indexPath];
                                           }];

        [deletedIndexSet enumerateIndexesWithOptions:NSEnumerationReverse /* reverse 'cause delete! */
                                          usingBlock:^(NSUInteger idx, BOOL *stop) {
                                              NSIndexPath *indexPath = [NSIndexPath indexPathForItem:idx inSection:sectionIdx];
                                              [deletedIndexPaths addObject:indexPath];
                                          }];

        sectionInfo.containedObjects = updatedItems;
    }
    
    if (insertedIndexPaths.count > 0) {
        *outInsertedIndexPaths = insertedIndexPaths;
    }
    
    if (deletedIndexPaths.count > 0) {
        *outDeletedIndexPaths = deletedIndexPaths;
    }
}

- (void)objectsDidChange:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSEntityDescription *entity = self.fetchRequest.entity;
    
    // Grab all objects which are our parent object type
    BOOL (^matchesObject)(id) = ^(NSManagedObject *obj){
        return [obj.entity isKindOfEntity:entity];
    };
    
    // these are unnecessary but since I keep forgetting that they're sets and not arrays,
    // let's keep them floating around with their correct type.
    NSSet *notificationInsertedObjects = userInfo[NSInsertedObjectsKey];
    NSSet *notificationUpdatedObjects = userInfo[NSUpdatedObjectsKey];
    NSSet *notificationDeletedObjects = userInfo[NSDeletedObjectsKey];
    
    NSSet *advertisedInsertedObjects = [notificationInsertedObjects bk_select:matchesObject];
    NSSet *advertisedUpdatedObjects = [notificationUpdatedObjects bk_select:matchesObject];
    NSSet *advertisedDeletedObjects = [notificationDeletedObjects bk_select:matchesObject];
    
    if (!advertisedInsertedObjects.count && !advertisedUpdatedObjects.count && !advertisedDeletedObjects.count) {
        // early abort if we have no work to do.
        return;
    }
    
    // Now, we need to update inserted/updated/deleted to be true about objects matching
    // the predicate. So, if something is updated to not match, consider it deleted,
    // and if it's inserted but doesn't match, don't include it.
    
    NSPredicate *fetchRequestPredicate = self.fetchRequest.predicate;
    NSArray *insertedObjects = [advertisedInsertedObjects filteredSetUsingPredicate:fetchRequestPredicate].allObjects;
    
    // Avoiding more memory hits is better than using a bit more memory for deleted.
    NSMutableArray *updatedObjects = [NSMutableArray arrayWithCapacity:advertisedUpdatedObjects.count];
    NSMutableArray *deletedObjects = [NSMutableArray arrayWithCapacity:advertisedUpdatedObjects.count + advertisedDeletedObjects.count];
    
    for (NSManagedObject *updatedObject in advertisedUpdatedObjects) {
        if ([fetchRequestPredicate evaluateWithObject:updatedObject]) {
            [updatedObjects addObject:updatedObject];
        } else {
            [deletedObjects addObject:updatedObject];
        }
    }
    
    [deletedObjects addObjectsFromArray:advertisedDeletedObjects.allObjects];
    
    // Sort the inserted/deleted objects, since we need stable indexes for keeping the index set going
    [deletedObjects sortUsingDescriptors:self.reverseSortDescriptors];
    insertedObjects = [insertedObjects sortedArrayUsingDescriptors:self.sortDescriptors];
    
    //
    
    NSLog(@"Inserted: %@, updated: %@, deleted: %@", insertedObjects, updatedObjects, deletedObjects);
    
    NSIndexSet *deletedSections = [self updateSectionsWithDeletedObjects:deletedObjects];
    NSIndexSet *insertedSections = [self updateSectionsWithInsertedObjects:insertedObjects];
    
    NSArray *insertedIndexPaths, *deletedIndexPaths;
    [self updateSectionsWithUpdatedObjects:updatedObjects
                        insertedIndexPaths:&insertedIndexPaths
                         deletedIndexPaths:&deletedIndexPaths];
    
    if (insertedSections || deletedSections || insertedIndexPaths || deletedIndexPaths) {
        [self.delegate hierarchicalController:self
                 didUpdateWithDeletedSections:deletedSections
                             insertedSections:insertedSections
                                 deletedItems:deletedIndexPaths
                                insertedItems:insertedIndexPaths];
    }
}

#pragma mark - Section info

- (void)setSections:(NSArray *)sections {
    _sections = sections;
    
    [_sections enumerateObjectsUsingBlock:^(HLHierarchicalResultsSection *sectionInfo, NSUInteger idx, BOOL *stop) {
        sectionInfo.sectionIdx = idx;
    }];
}

- (HLHierarchicalResultsSection *)newSectionInfoForObject:(id)object {
    HLHierarchicalResultsSection *sectionInfo = [[HLHierarchicalResultsSection alloc] init];
    sectionInfo.object = object;
    sectionInfo.containedObjects = [[object valueForKey:self.childKey] array];
    return sectionInfo;
}

- (HLHierarchicalResultsSection *)sectionInfoForObject:(id)object {
    // todo: faster; remember this is a sorted array
    // we can either use a binary search or store a map from object to section
    
    return [self.sections bk_match:^BOOL(HLHierarchicalResultsSection *sectionInfo) {
        return sectionInfo.object == object;
    }];
}

- (HLHierarchicalResultsSection *)sectionInfoForSection:(NSInteger)section {
    if (section < self.sections.count) {
        return self.sections[section];
    } else {
        return nil;
    }
}

#pragma mark - Getters

- (NSInteger)numberOfSections {
    return self.sections.count;
}

- (NSInteger)numberOfObjectsInSection:(NSInteger)section {
    HLHierarchicalResultsSection *sectionInfo = [self sectionInfoForSection:section];
    if (!sectionInfo) {
        DDLogError(@"Asked for count of section %zd which is out of bounds", section);
        return -1;
    }
    
    return sectionInfo.countOfContainedObjects;
}

- (id)parentObjectForSection:(NSInteger)section {
    HLHierarchicalResultsSection *sectionInfo = [self sectionInfoForSection:section];
    if (!sectionInfo) {
        DDLogError(@"Asked for parent object of section %zd which is out of bounds", section);
        return nil;
    }
    
    return sectionInfo.object;
}

- (NSInteger)sectionForParentObject:(id)parentObject {
    HLHierarchicalResultsSection *sectionInfo = [self sectionInfoForObject:parentObject];
    if (!sectionInfo) {
        DDLogError(@"Asked for section of parent object %@ but not found", parentObject);
        return NSNotFound;
    }
    
    return sectionInfo.sectionIdx;
}

- (id)objectAtIndexPath:(NSIndexPath *)indexPath {
    HLHierarchicalResultsSection *sectionInfo = [self sectionInfoForSection:indexPath.section];
    if (!sectionInfo) {
        DDLogError(@"Asked for object in section %zd (index path %@) but out of bounds", indexPath.section, indexPath);
        return nil;
    }
    
    return sectionInfo[indexPath.item];
}

- (NSIndexPath *)indexPathForObject:(id)object {
    id parentObject = [object valueForKey:self.inverseChildKey];
    HLHierarchicalResultsSection *sectionInfo = [self sectionInfoForObject:parentObject];
    if (!sectionInfo) {
        DDLogError(@"Asked for an object %@ which had no section for parent object %@", object, parentObject);
        return nil;
    }
    
    NSInteger itemIdx = [sectionInfo.containedObjects indexOfObject:object];
    if (itemIdx == NSNotFound) {
        DDLogError(@"Asked for an object %@ which had a section %@ but wasn't in containedObjects %@", object, sectionInfo, sectionInfo.containedObjects);
        return nil;
    }
    
    return [NSIndexPath indexPathForItem:itemIdx inSection:sectionInfo.sectionIdx];
}

- (NSArray *)allObjectsInSection:(NSInteger)section {
    HLHierarchicalResultsSection *sectionInfo = [self sectionInfoForSection:section];
    if (!sectionInfo) {
        DDLogError(@"Asked for section %zd which is out of bounds", section);
        return nil;
    }
    
    return sectionInfo.containedObjects;
}

@end
