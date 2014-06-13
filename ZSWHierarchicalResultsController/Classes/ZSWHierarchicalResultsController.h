//
//  ZSWHierarchicalResultsController.h
//  ZSWHierarchicalResultsController
//
//  Created by Zachary West on 6/13/14.
//  Copyright (c) 2014 Hey, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol HLHierarchicalResultsDelegate <NSObject>
- (void)updateWithInsertedIndexPaths:(NSArray *)insertedIndexPaths
                   deletedIndexPaths:(NSArray *)deletedIndexPaths
                    insertedSections:(NSIndexSet *)insertedSections
                     deletedSections:(NSIndexSet *)deletedSections;
@end

@interface HLHierarchicalResultsController : NSObject

#pragma mark - Creation

/*!
 * @brief Create a controller based on a fetch request
 *
 * The fetch request must have at least one sort descriptor, like \ref NSFetchedResultsController.
 *
 * @param fetchRequest The fetch request for the parent objects
 * @param childKey The child key on the entity for the fetchRequest representing items in the sections
 * @param context The NSManagedObjectContext for Core Data requests
 */
- (instancetype)initWithFetchRequest:(NSFetchRequest *)fetchRequest
                            childKey:(NSString *)childKey
                managedObjectContext:(NSManagedObjectContext *)context;

/*!
 * @brief Create a controller based on a single object
 *
 * This will result in a single section with items based on the child key.
 *
 * @param parentObject The parent object to return items in the section:managedObjectContext:
 * @param childKey The child key, see \ref -initWithFetchRequest:childKey
 * @param context The NSManagedObjectContext for Core Data requests
 */
- (instancetype)initWithParentObject:(NSManagedObject *)parentObject
                            childKey:(NSString *)childKey
                managedObjectContext:(NSManagedObjectContext *)context;

#pragma mark - Information

/*!
 * @brief Number of objects in a section
 *
 * This count does not include the object representing the section.
 * This may be 0 for sections without any contents.
 *
 * @return Number of objects in the section: [0,n]
 */
- (NSInteger)numberOfObjectsInSection:(NSInteger)section;

/*!
 * @brief Object representing a section
 *
 * This is the parent object for the objects within the section.
 */
- (NSManagedObject *)objectForSection:(NSInteger)section;

/*!
 * @brief Object within a section
 *
 * This gets the object in section indexPath.section at index indexPath.item.
 */
- (NSManagedObject *)objectAtIndexPath:(NSIndexPath *)indexPath;

/*!
 * @brief All objects in a section
 *
 * This is the equivalent of calling \ref -objectAtIndexPath: for all NSIndexPath
 * within the section.
 *
 * This does not include the object for the section.
 *
 * @return Array of the objects in the section
 */
- (NSArray *)allObjectsInSection:(NSInteger)section;

@end
