//
//  ZSWHierarchicalResultsController.h
//  ZSWHierarchicalResultsController
//
//  Created by Zachary West on 6/13/14.
//  Copyright (c) 2014 Hey, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class ZSWHierarchicalResultsController;
@protocol ZSWHierarchicalResultsDelegate <NSObject>
/*!
 * @brief The controller updated
 *
 * You must process the changes in the order of parameters of this method.
 * For example, instruct your view layer to handle deletes before inserts.
 *
 * It is by design that individual index paths do not get updates. You must handle
 * this yourself via KVO on the individual objects or some other mechanism.
 *
 * @param deletedsections The sections newly deleted
 * @param insertedSections The sections newly inserted
 * @param deletedIndexPaths The items newly inserted
 * @param insertedIndexPaths The items newly deleted
 */
- (void)hierarchicalController:(ZSWHierarchicalResultsController *)controller
  didUpdateWithDeletedSections:(NSIndexSet *)deletedSections
              insertedSections:(NSIndexSet *)insertedSections
                  deletedItems:(NSArray *)deletedIndexPaths
                 insertedItems:(NSArray *)insertedIndexPaths;

@end

/*!
 * @brief An NSFetchedResultsController-like class based on object hierarchies
 *
 * This class watches for changes on a particular fetch request's objects and considers
 * them to be parents in a two-deep hierarchy. Each parent object is represented
 * by a section, and the children of the parent object are items in that section.
 *
 * This class is designed to function with a \ref UICollectionView but can be used for
 * other areas as well, but the delegate methods in \ref ZSWHierarchicalResultsDelegate aim
 * to make working with the collection view easy.
 */
@interface ZSWHierarchicalResultsController : NSObject

#pragma mark - Creation

/*!
 * @brief Create a controller based on a fetch request
 *
 * The fetch request must have at least one sort descriptor, like \ref NSFetchedResultsController.
 *
 * @param fetchRequest The fetch request for the parent objects
 * @param childKey The child key on the entity for the fetchRequest representing items in the sections; this must have an inverse relationship
 * @param context The NSManagedObjectContext for Core Data requests
 */
- (instancetype)initWithFetchRequest:(NSFetchRequest *)fetchRequest
                            childKey:(NSString *)childKey
                managedObjectContext:(NSManagedObjectContext *)context
                            delegate:(id<ZSWHierarchicalResultsDelegate>)delegate;

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
                managedObjectContext:(NSManagedObjectContext *)context
                            delegate:(id<ZSWHierarchicalResultsDelegate>)delegate;

@property (nonatomic, strong, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, weak, readonly) id<ZSWHierarchicalResultsDelegate> delegate;

#pragma mark - Information

/*!
 * @brief Number of sections
 */
- (NSInteger)numberOfSections;

/*!
 * @brief Number of objects in a section
 *
 * This count does not include the object representing the section.
 * This may be 0 for sections without any contents.
 *
 * @return Number of objects in the section: [0,n], or -1 if out of bounds
 */
- (NSInteger)numberOfObjectsInSection:(NSInteger)section;

/*!
 * @brief Object representing a section
 *
 * This is the parent object for the objects within the section.
 *
 * @return The parent object, or \a nil if out of bounds
 */
- (id)parentObjectForSection:(NSInteger)section;

/*!
 * @brief Section index for a parent object
 *
 * @return The index [0,n] of the object if found, \ref NSNotFound otherwise
 */
- (NSInteger)sectionForParentObject:(id)parentObject;

/*!
 * @brief Object within a section
 *
 * This gets the object in section indexPath.section at index indexPath.item.
 *
 * @return The object at the index path, or \a nil if out of bounds
 */
- (id)objectAtIndexPath:(NSIndexPath *)indexPath;

/*!
 * @brief Index path for an object in a section
 *
 * @return The index path if found, \a nil otherwise
 */
- (NSIndexPath *)indexPathForObject:(id)object;

/*!
 * @brief All objects in a section
 *
 * This is the equivalent of calling \ref -objectAtIndexPath: for all NSIndexPath
 * within the section.
 *
 * This does not include the object for the section.
 *
 * @return Array of the objects in the section, or nil if out of bounds
 */
- (NSArray *)allObjectsInSection:(NSInteger)section;

@end
