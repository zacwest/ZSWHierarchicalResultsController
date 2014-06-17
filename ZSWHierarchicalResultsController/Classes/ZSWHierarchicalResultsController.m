//
//  ZSWHierarchicalResultsController.m
//  ZSWHierarchicalResultsController
//
//  Created by Zachary West on 6/13/14.
//  Copyright (c) 2014 Hey, Inc. All rights reserved.
//

#import "HLHierarchicalResultsController.h"

HLDefineLogLevel(LOG_LEVEL_VERBOSE);

@interface HLHierarchicalResultsController()
@property (nonatomic, copy) NSFetchRequest *fetchRequest;
@property (nonatomic, copy) NSString *childKey;
@property (nonatomic, strong) NSManagedObjectContext *context;

@property (nonatomic, strong) NSArray *sectionObjects;
@property (nonatomic, strong) NSDictionary *objectsBySection;
@end

@implementation HLHierarchicalResultsController

#pragma mark - Lifecycle

- (instancetype)initWithFetchRequest:(NSFetchRequest *)fetchRequest
                            childKey:(NSString *)childKey
                managedObjectContext:(NSManagedObjectContext *)context {
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
        
        [self initializeFetch];
    }
    return self;
}

- (instancetype)initWithParentObject:(NSManagedObject *)parentObject
                            childKey:(NSString *)childKey
                managedObjectContext:(NSManagedObjectContext *)context {
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:parentObject.entity.name];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"self == %@", parentObject];
    return [self initWithFetchRequest:fetchRequest childKey:childKey managedObjectContext:context];
}

- (id)init {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (void)initializeFetch {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(objectsDidChange:)
                                                 name:NSManagedObjectContextObjectsDidChangeNotification
                                               object:self.context];
    
    NSError *error;
    self.sectionObjects = [self.context executeFetchRequest:self.fetchRequest
                                                      error:&error];
    if (!self.sectionObjects) {
        DDLogError(@"Failed to fetch objects: %@", error);
    }
    
    NSMutableDictionary *objectsBySection = [NSMutableDictionary dictionaryWithCapacity:self.sectionObjects.count];
    
    [self.sectionObjects enumerateObjectsUsingBlock:^(NSManagedObject *parentObject, NSUInteger idx, BOOL *stop) {
        NSOrderedSet *objects = [parentObject valueForKey:self.childKey];
        NSAssert([objects isKindOfClass:[NSOrderedSet class]], @"Objects should be ordered set, but is %@", [objects class]);
        objectsBySection[@(idx)] = objects.array;
    }];
    
    self.objectsBySection = objectsBySection;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Object observing
- (void)objectsDidChange:(NSNotification *)notification {
    
}

#pragma mark - Getters

#define HLVerifySectionArray(sectionObject, sectionIdx) NSAssert(sectionObject.count > sectionIdx, @"Asked for a section %d out of range %d", sectionIdx, sectionObject.count);
#define HLVerifySectionDict(sectionObject, sectionIdx) NSAssert(sectionObject[@(sectionIdx)], @"Asked for section %d but does not exist", sectionIdx);

- (NSInteger)numberOfSections {
    return self.sectionObjects.count;
}

- (NSInteger)numberOfObjectsInSection:(NSInteger)section {
    HLVerifySectionDict(self.objectsBySection, section);
    return [self.objectsBySection[@(section)] count];
}

- (id)objectForSection:(NSInteger)section {
    HLVerifySectionArray(self.sectionObjects, section);
    return self.sectionObjects[section];
}

- (id)objectAtIndexPath:(NSIndexPath *)indexPath {
    HLVerifySectionDict(self.objectsBySection, indexPath.section);
    NSArray *objectsBySection = self.objectsBySection[@(indexPath.section)];
    HLVerifySectionArray(objectsBySection, indexPath.item);
    id object = objectsBySection[indexPath.item];
    return object;
}

- (NSArray *)allObjectsInSection:(NSInteger)section {
    HLVerifySectionDict(self.objectsBySection, section);
    return self.objectsBySection[@(section)];
}

@end
