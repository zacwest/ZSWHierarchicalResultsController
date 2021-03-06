//
//  ZSWHierarchicalResultsController.m
//  ZSWHierarchicalResultsController
//
//  Created by Zachary West on 6/13/14.
//  Copyright (c) 2014 Hey, Inc. All rights reserved.
//

#import "ZSWHierarchicalResultsController.h"
#import "ZSWHierarchicalResultsSection.h"

@interface ZSWHierarchicalResultsController()
@property (nonatomic, copy) NSFetchRequest *fetchRequest;
@property (nonatomic, copy) NSString *childKey;
@property (nonatomic, copy) NSString *inverseChildKey;
@property (nonatomic, strong, readwrite) NSManagedObjectContext *managedObjectContext;

@property (nonatomic, weak, readwrite) id<ZSWHierarchicalResultsDelegate> delegate;

@property (nonatomic, copy) NSArray *sections;
@property (nonatomic, copy) NSDictionary *objectIdToSectionMap;

@property (nonatomic, copy) NSArray *sortDescriptors;
@property (nonatomic, copy) NSArray *reverseSortDescriptors;
@property (nonatomic, copy) NSArray *sortDescriptorKeys;

@end

@implementation ZSWHierarchicalResultsController

#pragma mark - Lifecycle

- (instancetype)initWithFetchRequest:(NSFetchRequest *)fetchRequest
                            childKey:(NSString *)childKey
                managedObjectContext:(NSManagedObjectContext *)context
               isSingleObjectRequest:(BOOL)isSingleObjectRequest
                            delegate:(id<ZSWHierarchicalResultsDelegate>)delegate {
    NSParameterAssert(fetchRequest != nil);
    NSParameterAssert(childKey != nil);
    NSParameterAssert(context != nil);
    
    NSAssert(isSingleObjectRequest || fetchRequest.sortDescriptors.count > 0,
             @"At least one sort descriptor is required for %@", fetchRequest);
    
    NSEntityDescription *entity;
    
    if (fetchRequest.entityName) {
        entity = [NSEntityDescription entityForName:fetchRequest.entityName inManagedObjectContext:context];
    } else {
        entity = fetchRequest.entity;
    }
    
    NSRelationshipDescription *relationship = entity.relationshipsByName[childKey];
    
    // test for an invalid childkey
    NSAssert(relationship != nil,
             @"childKey %@ must be a relationship on %@", childKey, entity);
    
    // we require ordered because we display in an order. if we don't want this anymore, we need to
    // have the consumers give us sort descriptors and handle that
    NSAssert(relationship.isOrdered,
             @"childKey %@ must be ordered relationship on %@", childKey, entity);
    
    // inverse relationship is required for object to index path lookup. if we don't want this constraint
    // anymore, we need to make that fast, too, somehow.
    NSAssert(relationship.inverseRelationship != nil,
             @"childKey %@ must have an inverse relationship on %@", childKey, relationship.destinationEntity.name);
    
    self = [super init];
    if (self) {
        // Force the child key to be prefetched or else we fault on every single parent object
        NSFetchRequest *updatedFetchRequest = [fetchRequest copy];
        NSMutableArray *prefetchRelationships = [NSMutableArray arrayWithArray:updatedFetchRequest.relationshipKeyPathsForPrefetching];
        [prefetchRelationships addObject:childKey];
        updatedFetchRequest.relationshipKeyPathsForPrefetching = prefetchRelationships;
        
        if (!updatedFetchRequest.predicate) {
            // Things that take predicates don't appreciate having a nil predicate elsewhere, so for our internal
            // sanity let's keep the predicate set.
            updatedFetchRequest.predicate = [NSPredicate predicateWithValue:YES];
        }
        
        self.fetchRequest = updatedFetchRequest;
        
        if (isSingleObjectRequest) {
            self.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"self"
                                                                    ascending:YES
                                                                   comparator:^NSComparisonResult(id obj1, id obj2) {
                                                                       return NSOrderedSame;
                                                                   }] ];
        } else {
            self.sortDescriptors = updatedFetchRequest.sortDescriptors;
        }
        
        self.reverseSortDescriptors = ^{
            NSMutableArray *reverseSortDescriptors = [NSMutableArray arrayWithCapacity:self.sortDescriptors.count];
            for (NSSortDescriptor *sortDescriptor in self.sortDescriptors) {
                [reverseSortDescriptors addObject:[sortDescriptor reversedSortDescriptor]];
            }
            return reverseSortDescriptors;
        }();
        
        self.sortDescriptorKeys = ^{
            NSMutableArray *sortDescriptorKeys = [NSMutableArray arrayWithCapacity:self.sortDescriptors.count];
            for (NSSortDescriptor *sortDescriptor in self.sortDescriptors) {
                [sortDescriptorKeys addObject:sortDescriptor.key];
            }
            return sortDescriptorKeys;
        }();

        self.childKey = childKey;
        self.inverseChildKey = relationship.inverseRelationship.name;
        self.managedObjectContext = context;
        self.delegate = delegate;
        
        [self initializeFetch];
    }
    return self;
}

- (instancetype)initWithFetchRequest:(NSFetchRequest *)fetchRequest
                            childKey:(NSString *)childKey
                managedObjectContext:(NSManagedObjectContext *)context
                            delegate:(id<ZSWHierarchicalResultsDelegate>)delegate {
    return [self initWithFetchRequest:fetchRequest
                             childKey:childKey
                 managedObjectContext:context
                isSingleObjectRequest:NO
                             delegate:delegate];
}

- (instancetype)initWithParentObject:(NSManagedObject *)parentObject
                            childKey:(NSString *)childKey
                managedObjectContext:(NSManagedObjectContext *)context
                            delegate:(id<ZSWHierarchicalResultsDelegate>)delegate {
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:parentObject.entity.name];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"self = %@", parentObject];

    return [self initWithFetchRequest:fetchRequest
                             childKey:childKey
                 managedObjectContext:context
                isSingleObjectRequest:YES
                             delegate:delegate];
}

- (id)init {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (void)initializeFetch {
    NSError *error;
    NSArray *sectionObjects = [self.managedObjectContext executeFetchRequest:self.fetchRequest
                                                                       error:&error];
    if (!sectionObjects) {
        NSLog(@"Failed to fetch objects: %@", error);
    }
    
    self.sections = ^{
        NSMutableArray *sections = [NSMutableArray array];
        for (id obj in sectionObjects) {
            [sections addObject:[self newSectionInfoForObject:obj]];
        }
        return sections;
    }();
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(objectsDidChange:)
                                                 name:NSManagedObjectContextObjectsDidChangeNotification
                                               object:self.managedObjectContext];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Object observing

- (NSComparator)comparatorForSections {
    NSArray *sortDescriptors = self.sortDescriptors;
    
    return ^NSComparisonResult(ZSWHierarchicalResultsSection *sectionInfo1,
                               ZSWHierarchicalResultsSection *sectionInfo2) {
        return [sectionInfo1 compare:sectionInfo2 usingSortDescriptors:sortDescriptors];
    };
}

- (NSIndexSet *)updateSectionsWithInsertedObjects:(NSArray *)insertedObjects {
    if (insertedObjects.count == 0) {
        return nil;
    }
    
    // we must operate on a sorted list because we depend on inserts going into their index set in a stable order
    insertedObjects = [insertedObjects sortedArrayUsingDescriptors:self.sortDescriptors];
    
    NSMutableArray *updatedSections = [NSMutableArray arrayWithArray:self.sections];
    NSMutableIndexSet *insertedSet = [NSMutableIndexSet indexSet];
    
    NSComparator comparator = [self comparatorForSections];
    
    NSInteger lastInsertedIdx = 0;
    
    for (id insertedObject in insertedObjects) {
        // note: section indices on section objects are not valid in this method
        
        ZSWHierarchicalResultsSection *sectionInfo = [self newSectionInfoForObject:insertedObject];
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
    
    // we must operate on a *reverse* sorted list because we depend on indexes going in *backwards*
    // think about the delete callbacks: we're modifying an array (or so) that needs to know what indexes
    // to delete, and going forwards would produce the wrong numbers (since indexes change during delete)
    deletedObjects = [deletedObjects sortedArrayUsingDescriptors:self.reverseSortDescriptors];
    
    NSMutableArray *updatedSections = [NSMutableArray arrayWithArray:self.sections];
    NSMutableIndexSet *deletedSet = [NSMutableIndexSet indexSet];
    
    for (id deletedObject in deletedObjects) {
        // note: section indices on section objects are not valid in this method
        // but since we're going backwards, our indices are valid before our current delete point
        ZSWHierarchicalResultsSection *sectionInfo = [self sectionInfoForObject:deletedObject];
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
        ZSWHierarchicalResultsSection *sectionInfo = [self sectionInfoForObject:object];
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
            
            if (![existingObject isEqual:updatedObject]) {
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

- (NSSet *)objectsInSet:(NSSet *)uncheckedSet matchingEntity:(NSEntityDescription *)entity {
    NSMutableSet *checkedSet = [NSMutableSet setWithCapacity:uncheckedSet.count];
    for (NSManagedObject *obj in uncheckedSet) {
        if ([obj.entity isKindOfEntity:entity]) {
            [checkedSet addObject:obj];
        }
    }
    return checkedSet;
}

- (void)objectsDidChange:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSEntityDescription *entity = self.fetchRequest.entity;
    
    // these are unnecessary but since I keep forgetting that they're sets and not arrays,
    // let's keep them floating around with their correct type.
    NSSet *notificationInsertedObjects = userInfo[NSInsertedObjectsKey];
    NSSet *notificationUpdatedObjects = userInfo[NSUpdatedObjectsKey];
    NSSet *notificationDeletedObjects = userInfo[NSDeletedObjectsKey];
    NSSet *notificationRefreshedObjects = userInfo[NSRefreshedObjectsKey];
    
    NSSet *advertisedInsertedObjects = [self objectsInSet:notificationInsertedObjects matchingEntity:entity];
    NSSet *advertisedUpdatedObjects = [self objectsInSet:notificationUpdatedObjects matchingEntity:entity];
    NSSet *advertisedDeletedObjects = [self objectsInSet:notificationDeletedObjects matchingEntity:entity];
    NSSet *advertisedRefreshedObjects = [self objectsInSet:notificationRefreshedObjects matchingEntity:entity];
    
    NSSet *advertisedUpdatedOrRefreshedObjects = [[NSSet setWithSet:advertisedUpdatedObjects] setByAddingObjectsFromSet:advertisedRefreshedObjects];
    
    if (!advertisedInsertedObjects.count && !advertisedUpdatedOrRefreshedObjects.count && !advertisedDeletedObjects.count) {
        // early abort if we have no work to do.
        return;
    }
    
    // Now, we need to update inserted/updated/deleted to be true about objects matching
    // the predicate. So, if something is updated to not match, consider it deleted,
    // and if it's inserted but doesn't match, don't include it.
    
    NSPredicate *fetchRequestPredicate = self.fetchRequest.predicate;
    NSMutableSet *insertedObjects = [NSMutableSet setWithSet:[advertisedInsertedObjects filteredSetUsingPredicate:fetchRequestPredicate]];
    
    // Make sure we're not doing inserts for objects we've already loaded
    // This may happen e.g. if we get a notification just after our creation
    {
        for (NSManagedObject *insertedObject in [insertedObjects copy]) {
            // we can use our association map because we haven't modified the sections array at all
            // otherwise, it would have been invalidated by pending changes done below
            if (self.objectIdToSectionMap[insertedObject.objectID] != nil) {
                [insertedObjects removeObject:insertedObject];
            }
        }
    }

    // Avoiding more memory hits is better than using a bit more memory for deleted.
    NSMutableSet *updatedObjects = [NSMutableSet setWithCapacity:advertisedUpdatedOrRefreshedObjects.count];
    NSMutableSet *deletedObjects = [NSMutableSet setWithCapacity:advertisedUpdatedOrRefreshedObjects.count + advertisedDeletedObjects.count];
    
    // Note we use sets for updated/inserted/deleted objects in case we somehow gain duplicates
    
    for (NSManagedObject *updatedObject in advertisedUpdatedOrRefreshedObjects) {
        BOOL objectCurrentlyExists = [self sectionInfoForObject:updatedObject] != nil;
        BOOL objectMatchesPredicate = [fetchRequestPredicate evaluateWithObject:updatedObject];
        
        if (objectCurrentlyExists && objectMatchesPredicate) {
            if ([updatedObject.changedValuesForCurrentEvent.allKeys firstObjectCommonWithArray:self.sortDescriptorKeys]) {
                // Sort order may have changed, process as a delete/insert.
                [deletedObjects addObject:updatedObject];
                [insertedObjects addObject:updatedObject];
            } else {
                // Sort order didn't change, handle as a normal update.
                [updatedObjects addObject:updatedObject];
            }
        } else if (objectCurrentlyExists && !objectMatchesPredicate) {
            // Object no longer matches the predicate, handle as a delete.
            [deletedObjects addObject:updatedObject];
        } else if (!objectCurrentlyExists && objectMatchesPredicate) {
            // Object now newly matches the predicate, handle as an insert.
            [insertedObjects addObject:updatedObject];
        }
    }
    
    [deletedObjects addObjectsFromArray:advertisedDeletedObjects.allObjects];

    // Do the actual processing now that we've figured out what each class of changes are
    
    // Remember: we must handle deletes *before* inserts. This guy deletes sections and thus
    // changes section indexes.
    NSIndexSet *deletedSections = [self updateSectionsWithDeletedObjects:deletedObjects.allObjects];
    
    // This guy does both deletes and inserts, but section numbers don't change, so it's okay to do them together.
    NSArray *insertedIndexPaths, *deletedIndexPaths;
    [self updateSectionsWithUpdatedObjects:updatedObjects.allObjects
                        insertedIndexPaths:&insertedIndexPaths
                         deletedIndexPaths:&deletedIndexPaths];
    
    // This guy does inserts, which changes section indexes. This has to happen after all deletes.
    NSIndexSet *insertedSections = [self updateSectionsWithInsertedObjects:insertedObjects.allObjects];
    
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
    
    // Update our section caches: the section index, the lookup table
    NSMutableDictionary *objectIdToSectionMap = [NSMutableDictionary dictionaryWithCapacity:_sections.count];
    [_sections enumerateObjectsUsingBlock:^(ZSWHierarchicalResultsSection *sectionInfo, NSUInteger idx, BOOL *stop) {
        sectionInfo.sectionIdx = idx;
        objectIdToSectionMap[sectionInfo.object.objectID] = sectionInfo;
    }];
    self.objectIdToSectionMap = objectIdToSectionMap;
}

- (ZSWHierarchicalResultsSection *)newSectionInfoForObject:(id)object {
    ZSWHierarchicalResultsSection *sectionInfo = [[ZSWHierarchicalResultsSection alloc] init];
    sectionInfo.object = object;
    sectionInfo.containedObjects = [[object valueForKey:self.childKey] array];
    return sectionInfo;
}

- (ZSWHierarchicalResultsSection *)sectionInfoForObject:(NSManagedObject *)object {
    if (!object) {
        // an external consumer could force us to do a query like this somehow
        return nil;
    }
    
    // Note: although the sections array is generally sorted, if we're processing as a result of the
    // sort order changing, we can't count on this sorting order.
    //
    // Therefor, we can't use a binary search to do the lookup because it returns the wrong indexes
    // if the sorting constraint doesn't hold on the items it's doing a binary search on.
    // Yes, even if you check for NSNotFound as the return of the binary search; it's going to return
    // the wrong index as though it's correct.
    
    ZSWHierarchicalResultsSection *sectionInfo = self.objectIdToSectionMap[object.objectID];
    if (!sectionInfo) {
        // If we don't have this section mapped already, we need to do a scan to find it.
        for (ZSWHierarchicalResultsSection *sectionInfoTest in self.sections) {
            if ([sectionInfoTest.object isEqual:object]) {
                sectionInfo = sectionInfoTest;
                break;
            }
        }
    }
    
    NSAssert(!sectionInfo || [sectionInfo.object isEqual:object], @"Sanity check: we aren't returning the right section for the queried object");
    return sectionInfo;
}

- (ZSWHierarchicalResultsSection *)sectionInfoForSection:(NSInteger)section {
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
    ZSWHierarchicalResultsSection *sectionInfo = [self sectionInfoForSection:section];
    if (!sectionInfo) {
        NSLog(@"Asked for count of section %zd which is out of bounds", section);
        return -1;
    }
    
    return sectionInfo.countOfContainedObjects;
}

- (id)parentObjectForSection:(NSInteger)section {
    ZSWHierarchicalResultsSection *sectionInfo = [self sectionInfoForSection:section];
    if (!sectionInfo) {
        NSLog(@"Asked for parent object of section %zd which is out of bounds", section);
        return nil;
    }
    
    return sectionInfo.object;
}

- (NSInteger)sectionForParentObject:(id)parentObject {
    ZSWHierarchicalResultsSection *sectionInfo = [self sectionInfoForObject:parentObject];
    if (!sectionInfo) {
        NSLog(@"Asked for section of parent object %@ but not found", parentObject);
        return NSNotFound;
    }
    
    return sectionInfo.sectionIdx;
}

- (id)objectAtIndexPath:(NSIndexPath *)indexPath {
    ZSWHierarchicalResultsSection *sectionInfo = [self sectionInfoForSection:indexPath.section];
    if (!sectionInfo) {
        NSLog(@"Asked for object in section %zd (index path %@) but out of bounds", indexPath.section, indexPath);
        return nil;
    }
    
    return sectionInfo[indexPath.item];
}

- (NSIndexPath *)indexPathForObject:(id)object {
    id parentObject = [object valueForKey:self.inverseChildKey];
    ZSWHierarchicalResultsSection *sectionInfo = [self sectionInfoForObject:parentObject];
    if (!sectionInfo) {
        NSLog(@"Asked for an object %@ which had no section for parent object %@", object, parentObject);
        return nil;
    }
    
    NSInteger itemIdx = [sectionInfo.containedObjects indexOfObject:object];
    if (itemIdx == NSNotFound) {
        NSLog(@"Asked for an object %@ which had a section %@ but wasn't in containedObjects %@", object, sectionInfo, sectionInfo.containedObjects);
        return nil;
    }
    
    return [NSIndexPath indexPathForItem:itemIdx inSection:sectionInfo.sectionIdx];
}

- (NSArray *)allObjectsInSection:(NSInteger)section {
    ZSWHierarchicalResultsSection *sectionInfo = [self sectionInfoForSection:section];
    if (!sectionInfo) {
        NSLog(@"Asked for section %zd which is out of bounds", section);
        return nil;
    }
    
    return sectionInfo.containedObjects;
}

@end
