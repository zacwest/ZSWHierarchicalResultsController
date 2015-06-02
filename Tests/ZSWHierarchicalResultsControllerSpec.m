//
//  ZSWHierarchicalResultsControllerSpec.m
//  ZSWHierarchicalResultsController
//
//  Created by Zachary West on 6/17/14.
//  Copyright (c) 2014 Hey, Inc. All rights reserved.
//

#import "ZSWHierarchicalResultsController.h"

#import "ZSWFixtures.h"

SpecBegin(ZSWHierarchicalResultsController)

describe(@"ZSWHierarchicalResultsController", ^{
    __block ZSWHierarchicalResultsController *controller;
    __block id delegate;
    __block NSManagedObjectContext *context;

    describe(@"for multiple objects when created with existing objects", ^{
        __block NSArray *existingOuters;

        beforeEach(^{
            NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"OuterObject"];
            fetchRequest.predicate = [NSPredicate predicateWithFormat:@"%K != nil", ZSWSelector(outerSortKey)];
            fetchRequest.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:ZSWSelector(outerSortKey)
                                                                            ascending:YES] ];
            
            context = [ZSWFixtures context];
            
            delegate = [OCMockObject mockForProtocol:@protocol(ZSWHierarchicalResultsDelegate)];
            
            existingOuters = @[ [ZSWFixtures outerObjectWithInnerCount:2 context:context],
                                [ZSWFixtures outerObjectWithInnerCount:2 context:context],
                                [ZSWFixtures outerObjectWithInnerCount:2 context:context] ];
            
            [existingOuters[0] setOuterSortKey:@"0"];
            [existingOuters[1] setOuterSortKey:@"1"];
            [existingOuters[2] setOuterSortKey:@"2"];
            
            controller = [[ZSWHierarchicalResultsController alloc] initWithFetchRequest:fetchRequest
                                                                               childKey:ZSWSelector(objects)
                                                                   managedObjectContext:context
                                                                               delegate:delegate];
        });
        
        it(@"should have sections for all 3 created outers", ^{
            expect(controller.numberOfSections).to.equal(3);
            expect([controller parentObjectForSection:0]).to.equal(existingOuters[0]);
            expect([controller parentObjectForSection:1]).to.equal(existingOuters[1]);
            expect([controller parentObjectForSection:2]).to.equal(existingOuters[2]);
        });

        describe(@"when an objects-did-change notification includes already-inserted outers (possibly because we're creating the controller before the notification is sent over, but after the objects are added to our parent context, or something)", ^{
            beforeEach(^{
                [[delegate reject] hierarchicalController:OCMOCK_ANY
                             didUpdateWithDeletedSections:OCMOCK_ANY
                                         insertedSections:OCMOCK_ANY
                                             deletedItems:OCMOCK_ANY
                                            insertedItems:OCMOCK_ANY];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:NSManagedObjectContextObjectsDidChangeNotification
                                                                    object:context
                                                                  userInfo:@{ NSInsertedObjectsKey: [NSSet setWithArray:existingOuters] }];
            });
            
            it(@"should not have updated the delete", ^{
                [delegate verify];
            });
            
            it(@"should not have added any extra outers", ^{
                expect(controller.numberOfSections).to.equal(3);
                expect([controller parentObjectForSection:0]).to.equal(existingOuters[0]);
                expect([controller parentObjectForSection:1]).to.equal(existingOuters[1]);
                expect([controller parentObjectForSection:2]).to.equal(existingOuters[2]);
            });
        });
    });

    describe(@"for multiple objects when created for no existing objects", ^{
        beforeEach(^{
            NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:ZSWClass(OuterObject)];
            fetchRequest.predicate = [NSPredicate predicateWithFormat:@"%K != nil", ZSWSelector(outerSortKey)];
            fetchRequest.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:ZSWSelector(outerSortKey)
                                                                            ascending:YES] ];
            
            context = [ZSWFixtures context];
            
            delegate = [OCMockObject mockForProtocol:@protocol(ZSWHierarchicalResultsDelegate)];
            
            controller = [[ZSWHierarchicalResultsController alloc] initWithFetchRequest:fetchRequest
                                                                               childKey:ZSWSelector(objects)
                                                                   managedObjectContext:context
                                                                               delegate:delegate];
        });
        
        it(@"should find no existing sections", ^{
            expect(controller.numberOfSections).to.equal(0);
        });
        
        it(@"should return -1 for any section count", ^{
            expect([controller numberOfObjectsInSection:0]).to.equal(-1);
        });
        
        it(@"should return nil for any section's objects", ^{
            expect([controller allObjectsInSection:0]).to.beNil();
        });
        
        describe(@"when adding a section with no objects", ^{
            __block OuterObject *outer1;
            
            beforeEach(^{
                outer1 = [ZSWFixtures outerObjectWithContext:context];
                outer1.outerSortKey = @"1";
                
                [[delegate expect] hierarchicalController:controller
                             didUpdateWithDeletedSections:nil
                                         insertedSections:[NSIndexSet indexSetWithIndex:0]
                                             deletedItems:nil
                                            insertedItems:nil];
                [context processPendingChanges];
            });
            
            it(@"should have called the delegate about the insert", ^{
                [delegate verify];
            });
            
            it(@"should now have one section with no objects", ^{
                expect(controller.numberOfSections).to.equal(1);
                expect([controller numberOfObjectsInSection:0]).to.equal(0);
            });
            
            it(@"should translate from object to section", ^{
                expect([controller sectionForParentObject:outer1]).to.equal(0);
            });
            
            describe(@"when adding an an object to the section", ^{
                __block InnerObject *outer1Inner1;
                
                beforeEach(^{
                    outer1Inner1 = [ZSWFixtures innerObjectWithContext:context];
                    [[outer1 mutableOrderedSetValueForKey:ZSWSelector(objects)] addObject:outer1Inner1];
                    
                    [[delegate expect] hierarchicalController:controller
                                 didUpdateWithDeletedSections:nil
                                             insertedSections:nil
                                                 deletedItems:nil
                                                insertedItems:@[ [NSIndexPath indexPathForItem:0 inSection:0] ]];
                    [context processPendingChanges];
                });
                
                it(@"should have called the delegate about the insert", ^{
                    [delegate verify];
                });
                
                it(@"should now have an object in the section", ^{
                    expect([controller numberOfObjectsInSection:0]).to.equal(1);
                });
                
                it(@"should return the right object and backwards", ^{
                    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];
                    expect([controller objectAtIndexPath:indexPath]).to.equal(outer1Inner1);
                    expect([controller indexPathForObject:outer1Inner1]).to.equal(indexPath);
                });
                
                describe(@"when adding 2 more inners, in different locations", ^{
                    __block InnerObject *outer1Inner2, *outer1Inner3;
                    
                    beforeEach(^{
                        outer1Inner2 = [ZSWFixtures innerObjectWithContext:context];
                        outer1Inner3 = [ZSWFixtures innerObjectWithContext:context];
                        
                        NSMutableOrderedSet *orderedSet = [outer1 mutableOrderedSetValueForKey:ZSWSelector(objects)];
                        [orderedSet insertObject:outer1Inner2 atIndex:0];
                        [orderedSet addObject:outer1Inner3];
                        
                        [[delegate expect] hierarchicalController:controller
                                     didUpdateWithDeletedSections:nil
                                                 insertedSections:nil
                                                     deletedItems:nil
                                                    insertedItems:@[ [NSIndexPath indexPathForItem:0 inSection:0],
                                                                     [NSIndexPath indexPathForItem:2 inSection:0] ]];
                        [context processPendingChanges];
                    });
                    
                    it(@"should have called the delegate about the inserts", ^{
                        [delegate verify];
                    });
                    
                    it(@"should now have 3 objects in the section", ^{
                        expect([controller numberOfObjectsInSection:0]).to.equal(3);
                    });
                    
                    it(@"should return the right objects and backwards", ^{
                        NSIndexPath *inner1IndexPath = [NSIndexPath indexPathForItem:1 inSection:0];
                        NSIndexPath *inner2IndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
                        NSIndexPath *inner3IndexPath = [NSIndexPath indexPathForItem:2 inSection:0];
                        
                        expect([controller objectAtIndexPath:inner1IndexPath]).to.equal(outer1Inner1);
                        expect([controller objectAtIndexPath:inner2IndexPath]).to.equal(outer1Inner2);
                        expect([controller objectAtIndexPath:inner3IndexPath]).to.equal(outer1Inner3);
                        
                        expect([controller indexPathForObject:outer1Inner1]).to.equal(inner1IndexPath);
                        expect([controller indexPathForObject:outer1Inner2]).to.equal(inner2IndexPath);
                        expect([controller indexPathForObject:outer1Inner3]).to.equal(inner3IndexPath);
                    });
                    
                    describe(@"when 2 of the inners get deleted and one is inserted", ^{
                        __block InnerObject *outer1Inner4;
                        
                        beforeEach(^{
                            outer1Inner4 = [ZSWFixtures innerObjectWithContext:context];
                            
                            NSMutableOrderedSet *orderedSet = [outer1 mutableOrderedSetValueForKey:ZSWSelector(objects)];
                            [orderedSet removeObject:outer1Inner2];
                            [orderedSet removeObject:outer1Inner3];
                            [orderedSet addObject:outer1Inner4];
                            
                            [[delegate expect] hierarchicalController:controller
                                         didUpdateWithDeletedSections:nil
                                                     insertedSections:nil
                                                         deletedItems:@[ [NSIndexPath indexPathForItem:2 inSection:0],
                                                                         [NSIndexPath indexPathForItem:0 inSection:0] ]
                                                        insertedItems:@[ [NSIndexPath indexPathForItem:1 inSection:0] ]];
                            [context processPendingChanges];
                        });
                        
                        it(@"should have called the delegate", ^{
                            [delegate verify];
                        });
                        
                        it(@"should now have 2 items in the section", ^{
                            expect([controller numberOfObjectsInSection:0]).to.equal(2);
                        });
                        
                        it(@"should return the right objects and backwards", ^{
                            NSIndexPath *inner1IndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
                            NSIndexPath *inner4IndexPath = [NSIndexPath indexPathForItem:1 inSection:0];
                            
                            expect([controller objectAtIndexPath:inner1IndexPath]).to.equal(outer1Inner1);
                            expect([controller objectAtIndexPath:inner4IndexPath]).to.equal(outer1Inner4);
                            
                            expect([controller indexPathForObject:outer1Inner1]).to.equal(inner1IndexPath);
                            expect([controller indexPathForObject:outer1Inner4]).to.equal(inner4IndexPath);
                        });
                        
                        it(@"should not have index paths for the deleted objects", ^{
                            expect([controller indexPathForObject:outer1Inner2]).to.beNil();
                            expect([controller indexPathForObject:outer1Inner3]).to.beNil();
                        });
                    });
                });
                
                describe(@"when inserting objects and sections at the same time", ^{
                    __block OuterObject *outer2;
                    __block InnerObject *outer2Inner1, *outer2Inner2;
                    __block InnerObject *outer1Inner2, *outer1Inner3;
                    
                    beforeEach(^{
                        outer2 = [ZSWFixtures outerObjectWithContext:context];
                        outer2.outerSortKey = @"2";
                        
                        outer2Inner1 = [ZSWFixtures innerObjectWithContext:context];
                        outer2Inner2 = [ZSWFixtures innerObjectWithContext:context];
                        
                        outer1Inner2 = [ZSWFixtures innerObjectWithContext:context];
                        outer1Inner3 = [ZSWFixtures innerObjectWithContext:context];
                        
                        NSMutableOrderedSet *outer1OrderedSet = [outer1 mutableOrderedSetValueForKey:ZSWSelector(objects)];
                        NSMutableOrderedSet *outer2OrderedSet = [outer2 mutableOrderedSetValueForKey:ZSWSelector(objects)];
                        
                        [outer1OrderedSet addObjectsFromArray:@[ outer1Inner2, outer1Inner3 ]];
                        [outer2OrderedSet addObjectsFromArray:@[ outer2Inner1, outer2Inner2 ]];
                        
                        [[delegate expect] hierarchicalController:controller
                                     didUpdateWithDeletedSections:nil
                                                 insertedSections:[NSIndexSet indexSetWithIndex:1]
                                                     deletedItems:nil
                                                    insertedItems:@[ [NSIndexPath indexPathForItem:1 inSection:0],
                                                                     [NSIndexPath indexPathForItem:2 inSection:0 ]]];
                        [context processPendingChanges];
                    });
                    
                    it(@"should inform the delegate about the inserts", ^{
                        [delegate verify];
                    });
                    
                    it(@"should now have 2 sections", ^{
                        expect(controller.numberOfSections).to.equal(2);
                    });
                    
                    it(@"should have the right item counts", ^{
                        expect([controller numberOfObjectsInSection:0]).to.equal(3);
                        expect([controller numberOfObjectsInSection:1]).to.equal(2);
                    });
                    
                    it(@"should return the right objects and backwards in section 0", ^{
                        NSIndexPath *inner1IndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
                        NSIndexPath *inner2IndexPath = [NSIndexPath indexPathForItem:1 inSection:0];
                        NSIndexPath *inner3IndexPath = [NSIndexPath indexPathForItem:2 inSection:0];
                        
                        expect([controller objectAtIndexPath:inner1IndexPath]).to.equal(outer1Inner1);
                        expect([controller objectAtIndexPath:inner2IndexPath]).to.equal(outer1Inner2);
                        expect([controller objectAtIndexPath:inner3IndexPath]).to.equal(outer1Inner3);
                        
                        expect([controller indexPathForObject:outer1Inner1]).to.equal(inner1IndexPath);
                        expect([controller indexPathForObject:outer1Inner2]).to.equal(inner2IndexPath);
                        expect([controller indexPathForObject:outer1Inner3]).to.equal(inner3IndexPath);
                    });
                    
                    it(@"should return the right objects and backwards in section 1", ^{
                        NSIndexPath *inner1IndexPath = [NSIndexPath indexPathForItem:0 inSection:1];
                        NSIndexPath *inner2IndexPath = [NSIndexPath indexPathForItem:1 inSection:1];
                        
                        expect([controller objectAtIndexPath:inner1IndexPath]).to.equal(outer2Inner1);
                        expect([controller objectAtIndexPath:inner2IndexPath]).to.equal(outer2Inner2);
                        
                        expect([controller indexPathForObject:outer2Inner1]).to.equal(inner1IndexPath);
                        expect([controller indexPathForObject:outer2Inner2]).to.equal(inner2IndexPath);
                    });
                    
                    describe(@"when inners are deleted in multiple sections", ^{
                        beforeEach(^{
                            NSMutableOrderedSet *outer1OrderedSet = [outer1 mutableOrderedSetValueForKey:ZSWSelector(objects)];
                            NSMutableOrderedSet *outer2OrderedSet = [outer2 mutableOrderedSetValueForKey:ZSWSelector(objects)];
                            
                            [outer1OrderedSet removeObject:outer1Inner2];
                            [outer1OrderedSet removeObject:outer1Inner3];
                            
                            [outer2OrderedSet removeObject:outer2Inner1];
                            
                            OCMArg *deletedTest = [OCMArg checkWithBlock:^BOOL(NSArray *incomingArray) {
                                // we need to test that the order *within* sections is valid
                                // but the order that the changes themselves are delivered is undefined
                                
                                NSArray *possibleValues = @[
                                                            @[ [NSIndexPath indexPathForItem:2 inSection:0],
                                                               [NSIndexPath indexPathForItem:1 inSection:0],
                                                               [NSIndexPath indexPathForItem:0 inSection:1] ],
                                                            @[ [NSIndexPath indexPathForItem:0 inSection:1],
                                                               [NSIndexPath indexPathForItem:2 inSection:0],
                                                               [NSIndexPath indexPathForItem:1 inSection:0] ],
                                                            ];
                                                               
                                
                                return [possibleValues containsObject:incomingArray];
                            }];
                            
                            [[delegate expect] hierarchicalController:controller
                                         didUpdateWithDeletedSections:nil
                                                     insertedSections:nil
                                                         deletedItems:(id)deletedTest
                                                        insertedItems:nil];
                            [context processPendingChanges];
                        });
                        
                        it(@"should have told the delegate", ^{
                            [delegate verify];
                        });
                        
                        it(@"should return the right number of objects in each section", ^{
                            expect([controller numberOfObjectsInSection:0]).to.equal(1);
                            expect([controller numberOfObjectsInSection:1]).to.equal(1);
                        });
                        
                        it(@"should return the right objects and backwards in section 0", ^{
                            NSIndexPath *inner1IndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
                            
                            expect([controller objectAtIndexPath:inner1IndexPath]).to.equal(outer1Inner1);
                            
                            expect([controller indexPathForObject:outer1Inner1]).to.equal(inner1IndexPath);
                        });
                        
                        it(@"should return the right objects and backwards in section 1", ^{
                            NSIndexPath *inner2IndexPath = [NSIndexPath indexPathForItem:0 inSection:1];
                            
                            expect([controller objectAtIndexPath:inner2IndexPath]).to.equal(outer2Inner2);
                            
                            expect([controller indexPathForObject:outer2Inner2]).to.equal(inner2IndexPath);
                        });
                    });
                    
                    describe(@"when inserting a section (early) and deleting an object (late) at the same time", ^{
                        __block OuterObject *outer3;
                        __block InnerObject *outer3Inner1;
                        
                        beforeEach(^{
                            outer3 = [ZSWFixtures outerObjectWithContext:context];
                            outer3.outerSortKey = @"1a"; // puts us before section 2
                            
                            outer3Inner1 = [ZSWFixtures innerObjectWithContext:context];
                            [[outer3 mutableOrderedSetValueForKey:ZSWSelector(objects)] addObject:outer3Inner1];
                            
                            [[outer2 mutableOrderedSetValueForKey:ZSWSelector(objects)] removeObjectAtIndex:0];
                            
                            [[delegate expect] hierarchicalController:controller
                                         didUpdateWithDeletedSections:nil
                                                     insertedSections:[NSIndexSet indexSetWithIndex:1]
                                                         deletedItems:@[ [NSIndexPath indexPathForItem:0 inSection:1] ]
                                                        insertedItems:nil];
                            [context processPendingChanges];
                        });
                        
                        it(@"should delete and insert at the same time in the right order", ^{
                            [delegate verify];
                        });
                    });
                    
                    describe(@"when inserting a section", ^{
                        __block OuterObject *outer3;
                        __block InnerObject *outer3Inner1;
                        
                        beforeEach(^{
                            outer3 = [ZSWFixtures outerObjectWithContext:context];
                            outer3.outerSortKey = @"3";
                            
                            outer3Inner1 = [ZSWFixtures innerObjectWithContext:context];
                            [[outer3 mutableOrderedSetValueForKey:ZSWSelector(objects)] addObject:outer3Inner1];

                            [[delegate expect] hierarchicalController:controller
                                         didUpdateWithDeletedSections:nil
                                                     insertedSections:[NSIndexSet indexSetWithIndex:2]
                                                         deletedItems:nil
                                                        insertedItems:nil];
                            [context processPendingChanges];
                        });
                        
                        it(@"should inform the delegate", ^{
                            [delegate verify];
                        });
                        
                        it(@"should return the right number of sections", ^{
                            expect(controller.numberOfSections).to.equal(3);
                        });
                        
                        it(@"should return the right counts for each section", ^{
                            expect([controller numberOfObjectsInSection:0]).to.equal(3);
                            expect([controller numberOfObjectsInSection:1]).to.equal(2);
                            expect([controller numberOfObjectsInSection:2]).to.equal(1);
                        });
                        
                        describe(@"when deleting 2 outers in core data", ^{
                            beforeEach(^{
                                [context deleteObject:outer1];
                                [context deleteObject:outer3];
                                
                                NSMutableIndexSet *deleteIndexSet = [NSMutableIndexSet indexSet];
                                [deleteIndexSet addIndex:0];
                                [deleteIndexSet addIndex:2];
                                
                                [[delegate expect] hierarchicalController:controller
                                             didUpdateWithDeletedSections:deleteIndexSet
                                                         insertedSections:nil
                                                             deletedItems:nil
                                                            insertedItems:nil];
                                [context processPendingChanges];
                            });
                            
                            it(@"should inform the delegate", ^{
                                [delegate verify];
                            });
                            
                            it(@"should return the right number of sections", ^{
                                expect(controller.numberOfSections).to.equal(1);
                            });
                            
                            it(@"should return the right counts for each section", ^{
                                expect([controller numberOfObjectsInSection:0]).to.equal(2);
                            });
                        });
                        
                        describe(@"when the sections change their sorting key to the same value", ^{
                            beforeEach(^{
                                outer1.outerSortKey = @"1";
                                
                                [[delegate reject] hierarchicalController:controller
                                             didUpdateWithDeletedSections:OCMOCK_ANY
                                                         insertedSections:OCMOCK_ANY
                                                             deletedItems:OCMOCK_ANY
                                                            insertedItems:OCMOCK_ANY];
                                [context processPendingChanges];
                            });
                            
                            it(@"should not call the delegate at all", ^{
                                [delegate verify];
                            });
                        });
                        
                        describe(@"when the sections change their sort order", ^{
                            beforeEach(^{
                                outer1.outerSortKey = @"9";
                                
                                [[delegate expect] hierarchicalController:controller
                                             didUpdateWithDeletedSections:[NSIndexSet indexSetWithIndex:0]
                                                         insertedSections:[NSIndexSet indexSetWithIndex:2]
                                                             deletedItems:nil
                                                            insertedItems:nil];
                                [context processPendingChanges];
                            });
                            
                            it(@"should inform the delegate", ^{
                                [delegate verify];
                            });
                        });
                    });
                    
                    describe(@"when the first section no longer matches the predicate and a new outer is inserted", ^{
                        __block OuterObject *outer3;
                        __block InnerObject *outer3Inner1;
                        
                        beforeEach(^{
                            outer2.outerSortKey = nil;
                            
                            outer3 = [ZSWFixtures outerObjectWithContext:context];
                            outer3.outerSortKey = @"3";
                            
                            outer3Inner1 = [ZSWFixtures innerObjectWithContext:context];
                            [[outer3 mutableOrderedSetValueForKey:ZSWSelector(objects)] addObject:outer3Inner1];
                            
                            [[delegate expect] hierarchicalController:controller
                                         didUpdateWithDeletedSections:[NSIndexSet indexSetWithIndex:1]
                                                     insertedSections:[NSIndexSet indexSetWithIndex:1]
                                                         deletedItems:nil
                                                        insertedItems:nil];
                            [context processPendingChanges];
                        });
                        
                        it(@"should inform the delegate", ^{
                            [delegate verify];
                        });
                        
                        it(@"should return the right counts for sections", ^{
                            expect(controller.numberOfSections).to.equal(2);
                        });
                        
                        it(@"should return the right counts in each section", ^{
                            expect([controller numberOfObjectsInSection:0]).to.equal(3);
                            expect([controller numberOfObjectsInSection:1]).to.equal(1);
                        });
                        
                        it(@"should return the right objects and backwards in section 0", ^{
                            NSIndexPath *inner1IndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
                            NSIndexPath *inner2IndexPath = [NSIndexPath indexPathForItem:1 inSection:0];
                            NSIndexPath *inner3IndexPath = [NSIndexPath indexPathForItem:2 inSection:0];
                            
                            expect([controller objectAtIndexPath:inner1IndexPath]).to.equal(outer1Inner1);
                            expect([controller objectAtIndexPath:inner2IndexPath]).to.equal(outer1Inner2);
                            expect([controller objectAtIndexPath:inner3IndexPath]).to.equal(outer1Inner3);
                            
                            expect([controller indexPathForObject:outer1Inner1]).to.equal(inner1IndexPath);
                            expect([controller indexPathForObject:outer1Inner2]).to.equal(inner2IndexPath);
                            expect([controller indexPathForObject:outer1Inner3]).to.equal(inner3IndexPath);
                        });
                        
                        it(@"should return the right objects and backwards in section 1", ^{
                            NSIndexPath *inner1IndexPath = [NSIndexPath indexPathForItem:0 inSection:1];
                            
                            expect([controller objectAtIndexPath:inner1IndexPath]).to.equal(outer3Inner1);
                            
                            expect([controller indexPathForObject:outer3Inner1]).to.equal(inner1IndexPath);
                        });
                        
                        describe(@"when the section returns to matching the predicate", ^{
                            beforeEach(^{
                                outer2.outerSortKey = @"2";
                                
                                [[delegate expect] hierarchicalController:controller
                                             didUpdateWithDeletedSections:nil
                                                         insertedSections:[NSIndexSet indexSetWithIndex:1]
                                                             deletedItems:nil
                                                            insertedItems:nil];
                                [context processPendingChanges];
                            });
                            
                            it(@"should have told the delegate to insert", ^{
                                [delegate verify];
                            });
                        });
                        
                        describe(@"when the deleted section updates again and is still deleted", ^{
                            beforeEach(^{
                                outer2.outerSortKey = nil;
                                
                                [[delegate reject] hierarchicalController:controller
                                             didUpdateWithDeletedSections:OCMOCK_ANY
                                                         insertedSections:OCMOCK_ANY
                                                             deletedItems:OCMOCK_ANY
                                                            insertedItems:OCMOCK_ANY];
                                [context processPendingChanges];
                            });
                            
                            it(@"should not have told the delegate anything", ^{
                                [delegate verify];
                            });
                        });
                    });
                });
            });
        });
    });
    
    describe(@"for a single object", ^{
        __block OuterObject *outer;
        
        beforeEach(^{
            context = [ZSWFixtures context];
            outer = [ZSWFixtures outerObjectWithContext:context];
            [context processPendingChanges];
            
            delegate = [OCMockObject mockForProtocol:@protocol(ZSWHierarchicalResultsDelegate)];
            
            controller = [[ZSWHierarchicalResultsController alloc] initWithParentObject:outer
                                                                              childKey:ZSWSelector(objects)
                                                                  managedObjectContext:context
                                                                              delegate:delegate];
        });
        
        it(@"should start with no items in the outer", ^{
            expect(controller.numberOfSections).to.equal(1);
            expect([controller numberOfObjectsInSection:0]).to.equal(0);
        });
        
        describe(@"when a couple inners are inserted", ^{
            __block InnerObject *inner1, *inner2;
            
            beforeEach(^{
                inner1 = [ZSWFixtures innerObjectWithContext:context];
                inner2 = [ZSWFixtures innerObjectWithContext:context];
                
                NSMutableOrderedSet *orderedSet = [outer mutableOrderedSetValueForKey:ZSWSelector(objects)];
                [orderedSet addObjectsFromArray:@[ inner1, inner2 ]];
                
                [[delegate expect] hierarchicalController:controller
                             didUpdateWithDeletedSections:nil
                                         insertedSections:nil
                                             deletedItems:nil
                                            insertedItems:@[ [NSIndexPath indexPathForItem:0 inSection:0],
                                                             [NSIndexPath indexPathForItem:1 inSection:0] ]];
                [context processPendingChanges];
            });
            
            it(@"should inform the delegate about the inserts", ^{
                [delegate verify];
            });
            
            it(@"should return the right counts in section", ^{
                expect([controller numberOfObjectsInSection:0]).to.equal(2);
            });
            
            it(@"should return the right objects and backwards", ^{
                NSIndexPath *inner1IndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
                NSIndexPath *inner2IndexPath = [NSIndexPath indexPathForItem:1 inSection:0];
                
                expect([controller objectAtIndexPath:inner1IndexPath]).to.equal(inner1);
                expect([controller objectAtIndexPath:inner2IndexPath]).to.equal(inner2);
                
                expect([controller indexPathForObject:inner1]).to.equal(inner1IndexPath);
                expect([controller indexPathForObject:inner2]).to.equal(inner2IndexPath);
            });
            
            describe(@"when adding a few more inners", ^{
                __block InnerObject *inner3, *inner4, *inner5;
                
                beforeEach(^{
                    inner3 = [ZSWFixtures innerObjectWithContext:context];
                    inner4 = [ZSWFixtures innerObjectWithContext:context];
                    inner5 = [ZSWFixtures innerObjectWithContext:context];
                    
                    NSMutableOrderedSet *orderedSet = [outer mutableOrderedSetValueForKey:ZSWSelector(objects)];
                    [orderedSet addObjectsFromArray:@[ inner3, inner4, inner5 ]];
                    
                    [[delegate expect] hierarchicalController:controller
                                 didUpdateWithDeletedSections:nil
                                             insertedSections:nil
                                                 deletedItems:nil
                                                insertedItems:@[ [NSIndexPath indexPathForItem:2 inSection:0],
                                                                 [NSIndexPath indexPathForItem:3 inSection:0],
                                                                 [NSIndexPath indexPathForItem:4 inSection:0] ]];
                    
                    [context processPendingChanges];
                });
                
                it(@"should inform the delegate", ^{
                    [delegate verify];
                });
                
                it(@"should return the right counts in section", ^{
                    expect([controller numberOfObjectsInSection:0]).to.equal(5);
                });
                
                it(@"should return the right objects and backwards", ^{
                    NSIndexPath *inner1IndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
                    NSIndexPath *inner2IndexPath = [NSIndexPath indexPathForItem:1 inSection:0];
                    NSIndexPath *inner3IndexPath = [NSIndexPath indexPathForItem:2 inSection:0];
                    NSIndexPath *inner4IndexPath = [NSIndexPath indexPathForItem:3 inSection:0];
                    NSIndexPath *inner5IndexPath = [NSIndexPath indexPathForItem:4 inSection:0];
                    
                    expect([controller objectAtIndexPath:inner1IndexPath]).to.equal(inner1);
                    expect([controller objectAtIndexPath:inner2IndexPath]).to.equal(inner2);
                    expect([controller objectAtIndexPath:inner3IndexPath]).to.equal(inner3);
                    expect([controller objectAtIndexPath:inner4IndexPath]).to.equal(inner4);
                    expect([controller objectAtIndexPath:inner5IndexPath]).to.equal(inner5);
                    
                    expect([controller indexPathForObject:inner1]).to.equal(inner1IndexPath);
                    expect([controller indexPathForObject:inner2]).to.equal(inner2IndexPath);
                    expect([controller indexPathForObject:inner3]).to.equal(inner3IndexPath);
                    expect([controller indexPathForObject:inner4]).to.equal(inner4IndexPath);
                    expect([controller indexPathForObject:inner5]).to.equal(inner5IndexPath);
                });

                describe(@"and then we move 2 items within the list", ^{
                    beforeEach(^{
                        NSMutableOrderedSet *orderedSet = [outer mutableOrderedSetValueForKey:ZSWSelector(objects)];
                        [orderedSet exchangeObjectAtIndex:1 withObjectAtIndex:3];
                        
                        [[delegate expect] hierarchicalController:controller
                                     didUpdateWithDeletedSections:nil
                                                 insertedSections:nil
                                                     deletedItems:@[ [NSIndexPath indexPathForItem:3 inSection:0],
                                                                     [NSIndexPath indexPathForItem:1 inSection:0] ]
                                                    insertedItems:@[ [NSIndexPath indexPathForItem:1 inSection:0],
                                                                     [NSIndexPath indexPathForItem:3 inSection:0] ]];
                        [context processPendingChanges];
                    });
                    
                    it(@"should inform the delegate", ^{
                        [delegate verify];
                    });
                    
                    it(@"should return the right counts in section", ^{
                        expect([controller numberOfObjectsInSection:0]).to.equal(5);
                    });
                    
                    it(@"should return the right objects and backwards", ^{
                        NSIndexPath *inner1IndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
                        NSIndexPath *inner2IndexPath = [NSIndexPath indexPathForItem:3 inSection:0];
                        NSIndexPath *inner3IndexPath = [NSIndexPath indexPathForItem:2 inSection:0];
                        NSIndexPath *inner4IndexPath = [NSIndexPath indexPathForItem:1 inSection:0];
                        NSIndexPath *inner5IndexPath = [NSIndexPath indexPathForItem:4 inSection:0];
                        
                        expect([controller objectAtIndexPath:inner1IndexPath]).to.equal(inner1);
                        expect([controller objectAtIndexPath:inner2IndexPath]).to.equal(inner2);
                        expect([controller objectAtIndexPath:inner3IndexPath]).to.equal(inner3);
                        expect([controller objectAtIndexPath:inner4IndexPath]).to.equal(inner4);
                        expect([controller objectAtIndexPath:inner5IndexPath]).to.equal(inner5);
                        
                        expect([controller indexPathForObject:inner1]).to.equal(inner1IndexPath);
                        expect([controller indexPathForObject:inner2]).to.equal(inner2IndexPath);
                        expect([controller indexPathForObject:inner3]).to.equal(inner3IndexPath);
                        expect([controller indexPathForObject:inner4]).to.equal(inner4IndexPath);
                        expect([controller indexPathForObject:inner5]).to.equal(inner5IndexPath);
                    });
                });
            });
            
            describe(@"when the order of the objects changes", ^{
                beforeEach(^{
                    NSMutableOrderedSet *orderedSet = [outer mutableOrderedSetValueForKey:ZSWSelector(objects)];
                    [orderedSet exchangeObjectAtIndex:0 withObjectAtIndex:1];
                    
                    [[delegate expect] hierarchicalController:controller
                                 didUpdateWithDeletedSections:nil
                                             insertedSections:nil
                                                 deletedItems:@[ [NSIndexPath indexPathForItem:1 inSection:0],
                                                                 [NSIndexPath indexPathForItem:0 inSection:0] ]
                                                insertedItems:@[ [NSIndexPath indexPathForItem:0 inSection:0],
                                                                 [NSIndexPath indexPathForItem:1 inSection:0] ]];
                    [context processPendingChanges];
                });
                
                it(@"should inform the delegate", ^{
                    [delegate verify];
                });
                
                it(@"should return the correct counts in the section", ^{
                    expect([controller numberOfObjectsInSection:0]).to.equal(2);
                });
                
                it(@"should return the right objects and backwards", ^{
                    NSIndexPath *inner1IndexPath = [NSIndexPath indexPathForItem:1 inSection:0];
                    NSIndexPath *inner2IndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
                    
                    expect([controller objectAtIndexPath:inner1IndexPath]).to.equal(inner1);
                    expect([controller objectAtIndexPath:inner2IndexPath]).to.equal(inner2);
                    
                    expect([controller indexPathForObject:inner1]).to.equal(inner1IndexPath);
                    expect([controller indexPathForObject:inner2]).to.equal(inner2IndexPath);
                });
            });
            
            describe(@"when the order changes and we insert at the same time", ^{
                __block InnerObject *inner3;
                
                beforeEach(^{
                    inner3 = [ZSWFixtures innerObjectWithContext:context];
                    
                    NSMutableOrderedSet *orderedSet = [outer mutableOrderedSetValueForKey:ZSWSelector(objects)];
                    [orderedSet exchangeObjectAtIndex:0 withObjectAtIndex:1];
                    [orderedSet insertObject:inner3 atIndex:1];
                    
                    [[delegate expect] hierarchicalController:controller
                                 didUpdateWithDeletedSections:nil
                                             insertedSections:nil
                                                 deletedItems:@[ [NSIndexPath indexPathForItem:1 inSection:0 ],
                                                                 [NSIndexPath indexPathForItem:0 inSection:0] ]
                                                insertedItems:@[ [NSIndexPath indexPathForItem:0 inSection:0],
                                                                 [NSIndexPath indexPathForItem:1 inSection:0],
                                                                 [NSIndexPath indexPathForItem:2 inSection:0] ]];
                    [context processPendingChanges];
                });
                
                it(@"should inform the delegate", ^{
                    [delegate verify];
                });
                
                it(@"should return the correct counts in the section", ^{
                    expect([controller numberOfObjectsInSection:0]).to.equal(3);
                });
                
                it(@"should return the right objects and backwards", ^{
                    NSIndexPath *inner1IndexPath = [NSIndexPath indexPathForItem:2 inSection:0];
                    NSIndexPath *inner2IndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
                    NSIndexPath *inner3IndexPath = [NSIndexPath indexPathForItem:1 inSection:0];
                    
                    expect([controller objectAtIndexPath:inner1IndexPath]).to.equal(inner1);
                    expect([controller objectAtIndexPath:inner2IndexPath]).to.equal(inner2);
                    expect([controller objectAtIndexPath:inner3IndexPath]).to.equal(inner3);
                    
                    expect([controller indexPathForObject:inner1]).to.equal(inner1IndexPath);
                    expect([controller indexPathForObject:inner2]).to.equal(inner2IndexPath);
                    expect([controller indexPathForObject:inner3]).to.equal(inner3IndexPath);
                });
            });
        });
    });
});

SpecEnd
