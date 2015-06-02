# ZSWHierarchicalResultsController

[![CI Status](http://img.shields.io/travis/zacwest/ZSWHierarchicalResultsController.svg?style=flat)](https://travis-ci.org/zacwest/ZSWHierarchicalResultsController)
[![Version](https://img.shields.io/cocoapods/v/ZSWHierarchicalResultsController.svg?style=flat)](http://cocoapods.org/pods/ZSWHierarchicalResultsController)
[![License](https://img.shields.io/cocoapods/l/ZSWHierarchicalResultsController.svg?style=flat)](http://cocoapods.org/pods/ZSWHierarchicalResultsController)
[![Platform](https://img.shields.io/cocoapods/p/ZSWHierarchicalResultsController.svg?style=flat)](http://cocoapods.org/pods/ZSWHierarchicalResultsController)

ZSWHierarchicalResultsController is a replacement for `NSFetchedResultsController`. Instead of supporting a single array of objects, this class shows one section per object, and an ordered set of objects within each section.

This class is both fast and well-tested, and is able to handle a large number of objects; the major constraint will be memory usage which the controller aims to keep as low as it can.

## Creating a controller

Let's say you're trying to display a section per `Day` which can contain some number of `Event` within:

```objective-c
@interface Day : NSManagedObject
@property id sortKey;
@property NSOrderedSet *events;
@end

@interface Event : NSManagedObject
@property Day *day;
@end
```

You can create a controller to display the events contained within each day:

```objective-c
NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"Day"];
req.predicate = [NSPredicate predicateWithFormat:@"sortKey != nil"];
req.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"sortKey" ascending:YES] ];

controller = [[ZSWHierarchicalResultsController alloc]
                   initWithFetchRequest:req
                               childKey:@"objects"
                   managedObjectContext:context
                               delegate:self];
```

## Receiving updates

The delegate callback is similar to that of NSFetchedResultsController, but designed for easy use with UICollectionViews:

```objective-c
- (void)hierarchicalController:(ZSWHierarchicalResultsController *)controller
  didUpdateWithDeletedSections:(NSIndexSet *)deletedSections
              insertedSections:(NSIndexSet *)insertedSections
                  deletedItems:(NSArray *)deletedIndexPaths
                 insertedItems:(NSArray *)insertedIndexPaths {
  [self.collectionView performBatchUpdates:^{
    if (deletedSections) {
      [self.collectionView deleteSections:deletedSections];
    }

    if (insertedSections) {
      [self.collectionView insertSections:insertedSections];
    }

    if (deletedIndexPaths) {
      [self.collectionView deleteItemsAtIndexPaths:deletedIndexPaths];
    }

    if (insertedIndexPaths) {
      [self.collectionView insertItemsAtIndexPaths:insertedIndexPaths];
    }
  } completion:^(BOOL finished) {

  }];
}
```

By design, this class does not emit "Update" notifications. If you are interested in knowing when your objects change in a way that should update your UI, you should set up KVO observers.

## Single parent object

You may occasionally wish to present a controller for a single object, for example if you expand the object or reveal an editing screen. `-[ZSWHierarchicalResultsController initWithParentObject:childKey:managedObjectContext:delegate:]` makes this convenient for you.

## Installation

ZSWHierarchicalResultsController is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "ZSWHierarchicalResultsController", "~> 1.0"
```

## License

ZSWHierarchicalResultsController is available under the [MIT license](https://github.com/zacwest/ZSWHierarchicalResultsController/blob/master/LICENSE). This library was created while working on [Heyday](http://hey.co) who allowed this to be open-sourced. If you are contributing via pull request, please include an appropriate test for the bug you are fixing or feature you are adding. 
