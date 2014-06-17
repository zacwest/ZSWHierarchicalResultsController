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
- (void)objectsDidChange:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSEntityDescription *entity = self.fetchRequest.entity;
    
    BOOL (^matchesObject)(id) = ^(NSManagedObject *obj){
        return [obj.entity isKindOfEntity:entity];
    };
    
    NSArray *insertedObjects = [userInfo[NSInsertedObjectsKey] bk_select:matchesObject];
    NSArray *updatedObjects = [userInfo[NSUpdatedObjectsKey] bk_select:matchesObject];
    NSArray *deletedObjects = [userInfo[NSDeletedObjectsKey] bk_select:matchesObject];
    
    NSLog(@"Inserted: %@, updated: %@, deleted: %@", insertedObjects, updatedObjects, deletedObjects);
    
    NSMutableIndexSet *insertedSet;
    
    if (insertedObjects.count > 0) {
        NSMutableArray *updatedSections = [NSMutableArray arrayWithArray:self.sections];
        
        insertedSet = [NSMutableIndexSet indexSet];
        
        NSArray *sortDescriptors = self.fetchRequest.sortDescriptors;
        NSComparator comparator = ^NSComparisonResult(HLHierarchicalResultsSection *section1,
                                                      HLHierarchicalResultsSection *section2) {
            return [section1 compare:section2 usingSortDescriptors:sortDescriptors];
        };
        
        for (id insertedObject in insertedObjects) {
            HLHierarchicalResultsSection *section = [self newSectionInfoForObject:insertedObject];
            NSInteger insertIdx = [updatedSections indexOfObject:section
                                                 inSortedRange:NSMakeRange(0, self.sections.count)
                                                       options:NSBinarySearchingInsertionIndex
                                               usingComparator:comparator];
            [insertedSet addIndex:insertIdx];
            
            [updatedSections insertObject:section atIndex:insertIdx];
        }
        
        self.sections = updatedSections;
    }
    
    NSMutableIndexSet *deletedSet;
    
    if (deletedObjects.count > 0) {
        NSMutableArray *updatedSections = [NSMutableArray arrayWithArray:self.sections];
        
        deletedSet = [NSMutableIndexSet indexSet];
        
        for (id deletedObject in deletedObjects) {
            HLHierarchicalResultsSection *section = [self sectionInfoForObject:deletedObject];
            NSInteger deleteIdx = [self.sections indexOfObject:section];
            [deletedSet addIndex:deleteIdx];
            [updatedSections removeObjectAtIndex:deleteIdx];
        }
        
        self.sections = updatedSections;
    }
    
    NSMutableArray *insertedItems;
    NSMutableArray *deletedItems;
    
    if (updatedObjects.count > 0) {
        insertedItems = [NSMutableArray array];
        deletedItems = [NSMutableArray array];
        
        for (NSManagedObject *updatedObject in updatedObjects) {
            HLHierarchicalResultsSection *section = [self sectionInfoForObject:updatedObject];
            NSArray *previousObjects = section.containedObjects;
            NSArray *currentObjects = [updatedObject valueForKey:self.childKey];
            
            
        }
    }
    
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

- (HLHierarchicalResultsSection *)sectionInfoForObject:(id)object {
    return [self.sections bk_match:^BOOL(HLHierarchicalResultsSection *section) {
        return section.object == object;
    }];
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
