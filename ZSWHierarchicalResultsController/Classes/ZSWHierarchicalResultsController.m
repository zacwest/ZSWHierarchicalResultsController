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

- (NSIndexSet *)updateSectionsWithInsertedObjects:(NSArray *)insertedObjects {
    if (insertedObjects.count == 0) {
        return nil;
    }
    
#ifdef CONFIGURATION_Debug
    NSAssert([insertedObjects isEqualToArray:[insertedObjects sortedArrayUsingDescriptors:self.fetchRequest.sortDescriptors]], @"This method must be passed sorted objects to keep stable indexes in the index set (otherwise we could have 2 inserts on a single index, which the index set coalesces)");
#endif
    
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

#ifdef CONFIGURATION_Debug
    NSAssert([deletedObjects isEqualToArray:[deletedObjects sortedArrayUsingDescriptors:self.fetchRequest.sortDescriptors]], @"This method must be passed sorted objects to keep stable indexes in the index set (otherwise we could have 2 inserts on a single index, which the index set coalesces)");
#endif
    
    NSMutableArray *updatedSections = [NSMutableArray arrayWithArray:self.sections];
    NSMutableIndexSet *deletedSet = [NSMutableIndexSet indexSet];
    
    
    for (id deletedObject in deletedObjects) {
        NSInteger deleteIdx;
        __unused HLHierarchicalResultsSection *section = [self sectionInfoForObject:deletedObject index:&deleteIdx];
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
    NSArray *sortDescriptors = self.fetchRequest.sortDescriptors;
    [deletedObjects sortUsingDescriptors:sortDescriptors];
    insertedObjects = [insertedObjects sortedArrayUsingDescriptors:sortDescriptors];
    
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

#pragma mark - Section info

- (HLHierarchicalResultsSection *)newSectionInfoForObject:(id)object {
    HLHierarchicalResultsSection *section = [[HLHierarchicalResultsSection alloc] init];
    section.object = object;
    
    // we need to copy the array because the default is a placeholder which dynamically updates
    // when the object is updated, but we need to manage the updating ourselves
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

#pragma mark - Getters

- (NSInteger)numberOfSections {
    return self.sections.count;
}

- (NSInteger)numberOfObjectsInSection:(NSInteger)section {
    return [self sectionInfoForSection:section].countOfContainedObjects;
}

- (id)objectForSection:(NSInteger)section {
    return [self sectionInfoForSection:section].object;
}

- (id)objectAtIndexPath:(NSIndexPath *)indexPath {
    return [self sectionInfoForSection:indexPath.section][indexPath.item];
}

- (NSArray *)allObjectsInSection:(NSInteger)section {
    return [self sectionInfoForSection:section].containedObjects;
}

@end
