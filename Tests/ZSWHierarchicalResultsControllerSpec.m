//
//  ZSWHierarchicalResultsControllerSpec.m
//  ZSWHierarchicalResultsController
//
//  Created by Zachary West on 6/17/14.
//  Copyright (c) 2014 Hey, Inc. All rights reserved.
//

#import "HLHierarchicalResultsController.h"

#import "CDDay.h"
#import "CDLocationEvent.h"

SpecBegin(HLHierarchicalResultsController)

describe(@"HLHierarchicalResultsController", ^{
    __block HLHierarchicalResultsController *controller;
    __block id delegate;
    __block NSManagedObjectContext *context;
    
    describe(@"for multiple objects when created for no existing objects", ^{
        beforeEach(^{
            NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:HLClass(CDDay)];
            fetchRequest.predicate = [NSPredicate predicateWithFormat:@"sectionIdentifier != nil"];
            fetchRequest.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:HLSelector(sectionIdentifier)
                                                                            ascending:YES] ];
            
            context = [HLFixtures testingContext];
            
            delegate = [OCMockObject mockForProtocol:@protocol(HLHierarchicalResultsDelegate)];
            
            controller = [[HLHierarchicalResultsController alloc] initWithFetchRequest:fetchRequest
                                                                              childKey:HLSelector(locationEvents)
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
            __block CDDay *day1;
            
            beforeEach(^{
                day1 = [HLFixtures dayInContext:context];
                day1.sectionIdentifier = @"1";
                
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
                expect([controller sectionForParentObject:day1]).to.equal(0);
            });
            
            describe(@"when adding an an object to the section", ^{
                __block CDLocationEvent *day1Event1;
                
                beforeEach(^{
                    day1Event1 = [HLFixtures locationEventInContext:context];
                    [[day1 mutableOrderedSetValueForKey:HLSelector(locationEvents)] addObject:day1Event1];
                    
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
                    expect([controller objectAtIndexPath:indexPath]).to.equal(day1Event1);
                    expect([controller indexPathForObject:day1Event1]).to.equal(indexPath);
                });
                
                describe(@"when adding 2 more events, in different locations", ^{
                    __block CDLocationEvent *day1Event2, *day1Event3;
                    
                    beforeEach(^{
                        day1Event2 = [HLFixtures locationEventInContext:context];
                        day1Event3 = [HLFixtures locationEventInContext:context];
                        
                        NSMutableOrderedSet *orderedSet = [day1 mutableOrderedSetValueForKey:HLSelector(locationEvents)];
                        [orderedSet insertObject:day1Event2 atIndex:0];
                        [orderedSet addObject:day1Event3];
                        
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
                        NSIndexPath *event1IndexPath = [NSIndexPath indexPathForItem:1 inSection:0];
                        NSIndexPath *event2IndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
                        NSIndexPath *event3IndexPath = [NSIndexPath indexPathForItem:2 inSection:0];
                        
                        expect([controller objectAtIndexPath:event1IndexPath]).to.equal(day1Event1);
                        expect([controller objectAtIndexPath:event2IndexPath]).to.equal(day1Event2);
                        expect([controller objectAtIndexPath:event3IndexPath]).to.equal(day1Event3);
                        
                        expect([controller indexPathForObject:day1Event1]).to.equal(event1IndexPath);
                        expect([controller indexPathForObject:day1Event2]).to.equal(event2IndexPath);
                        expect([controller indexPathForObject:day1Event3]).to.equal(event3IndexPath);
                    });
                    
                    describe(@"when 2 of the events get deleted and one is inserted", ^{
                        __block CDLocationEvent *day1Event4;
                        
                        beforeEach(^{
                            day1Event4 = [HLFixtures locationEventInContext:context];
                            
                            NSMutableOrderedSet *orderedSet = [day1 mutableOrderedSetValueForKey:HLSelector(locationEvents)];
                            [orderedSet removeObject:day1Event2];
                            [orderedSet removeObject:day1Event3];
                            [orderedSet addObject:day1Event4];
                            
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
                            NSIndexPath *event1IndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
                            NSIndexPath *event4IndexPath = [NSIndexPath indexPathForItem:1 inSection:0];
                            
                            expect([controller objectAtIndexPath:event1IndexPath]).to.equal(day1Event1);
                            expect([controller objectAtIndexPath:event4IndexPath]).to.equal(day1Event4);
                            
                            expect([controller indexPathForObject:day1Event1]).to.equal(event1IndexPath);
                            expect([controller indexPathForObject:day1Event4]).to.equal(event4IndexPath);
                        });
                        
                        it(@"should not have index paths for the deleted objects", ^{
                            expect([controller indexPathForObject:day1Event2]).to.beNil();
                            expect([controller indexPathForObject:day1Event3]).to.beNil();
                        });
                    });
                });
                
                describe(@"when inserting objects and sections at the same time", ^{
                    __block CDDay *day2;
                    __block CDLocationEvent *day2Event1, *day2Event2;
                    __block CDLocationEvent *day1Event2, *day1Event3;
                    
                    beforeEach(^{
                        day2 = [HLFixtures dayInContext:context];
                        day2.sectionIdentifier = @"2";
                        
                        day2Event1 = [HLFixtures locationEventInContext:context];
                        day2Event2 = [HLFixtures locationEventInContext:context];
                        
                        day1Event2 = [HLFixtures locationEventInContext:context];
                        day1Event3 = [HLFixtures locationEventInContext:context];
                        
                        NSMutableOrderedSet *day1OrderedSet = [day1 mutableOrderedSetValueForKey:HLSelector(locationEvents)];
                        NSMutableOrderedSet *day2OrderedSet = [day2 mutableOrderedSetValueForKey:HLSelector(locationEvents)];
                        
                        [day1OrderedSet addObjectsFromArray:@[ day1Event2, day1Event3 ]];
                        [day2OrderedSet addObjectsFromArray:@[ day2Event1, day2Event2 ]];
                        
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
                        NSIndexPath *event1IndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
                        NSIndexPath *event2IndexPath = [NSIndexPath indexPathForItem:1 inSection:0];
                        NSIndexPath *event3IndexPath = [NSIndexPath indexPathForItem:2 inSection:0];
                        
                        expect([controller objectAtIndexPath:event1IndexPath]).to.equal(day1Event1);
                        expect([controller objectAtIndexPath:event2IndexPath]).to.equal(day1Event2);
                        expect([controller objectAtIndexPath:event3IndexPath]).to.equal(day1Event3);
                        
                        expect([controller indexPathForObject:day1Event1]).to.equal(event1IndexPath);
                        expect([controller indexPathForObject:day1Event2]).to.equal(event2IndexPath);
                        expect([controller indexPathForObject:day1Event3]).to.equal(event3IndexPath);
                    });
                    
                    it(@"should return the right objects and backwards in section 1", ^{
                        NSIndexPath *event1IndexPath = [NSIndexPath indexPathForItem:0 inSection:1];
                        NSIndexPath *event2IndexPath = [NSIndexPath indexPathForItem:1 inSection:1];
                        
                        expect([controller objectAtIndexPath:event1IndexPath]).to.equal(day2Event1);
                        expect([controller objectAtIndexPath:event2IndexPath]).to.equal(day2Event2);
                        
                        expect([controller indexPathForObject:day2Event1]).to.equal(event1IndexPath);
                        expect([controller indexPathForObject:day2Event2]).to.equal(event2IndexPath);
                    });
                    
                    describe(@"when events are deleted in multiple sections", ^{
                        beforeEach(^{
                            NSMutableOrderedSet *day1OrderedSet = [day1 mutableOrderedSetValueForKey:HLSelector(locationEvents)];
                            NSMutableOrderedSet *day2OrderedSet = [day2 mutableOrderedSetValueForKey:HLSelector(locationEvents)];
                            
                            [day1OrderedSet removeObject:day1Event2];
                            [day1OrderedSet removeObject:day1Event3];
                            
                            [day2OrderedSet removeObject:day2Event1];
                            
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
                            NSIndexPath *event1IndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
                            
                            expect([controller objectAtIndexPath:event1IndexPath]).to.equal(day1Event1);
                            
                            expect([controller indexPathForObject:day1Event1]).to.equal(event1IndexPath);
                        });
                        
                        it(@"should return the right objects and backwards in section 1", ^{
                            NSIndexPath *event2IndexPath = [NSIndexPath indexPathForItem:0 inSection:1];
                            
                            expect([controller objectAtIndexPath:event2IndexPath]).to.equal(day2Event2);
                            
                            expect([controller indexPathForObject:day2Event2]).to.equal(event2IndexPath);
                        });
                    });
                    
                    describe(@"when inserting a section (early) and deleting an object (late) at the same time", ^{
                        __block CDDay *day3;
                        __block CDLocationEvent *day3Event1;
                        
                        beforeEach(^{
                            day3 = [HLFixtures dayInContext:context];
                            day3.sectionIdentifier = @"1a"; // puts us before section 2
                            
                            day3Event1 = [HLFixtures locationEventInContext:context];
                            [[day3 mutableOrderedSetValueForKey:HLSelector(locationEvents)] addObject:day3Event1];
                            
                            [[day2 mutableOrderedSetValueForKey:HLSelector(locationEvents)] removeObjectAtIndex:0];
                            
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
                        __block CDDay *day3;
                        __block CDLocationEvent *day3Event1;
                        
                        beforeEach(^{
                            day3 = [HLFixtures dayInContext:context];
                            day3.sectionIdentifier = @"3";
                            
                            day3Event1 = [HLFixtures locationEventInContext:context];
                            [[day3 mutableOrderedSetValueForKey:HLSelector(locationEvents)] addObject:day3Event1];

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
                        
                        describe(@"when deleting 2 days in core data", ^{
                            beforeEach(^{
                                [context deleteObject:day1];
                                [context deleteObject:day3];
                                
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
                                day1.sectionIdentifier = @"1";
                                
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
                                day1.sectionIdentifier = @"9";
                                
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
                    
                    describe(@"when the first section no longer matches the predicate and a new day is inserted", ^{
                        __block CDDay *day3;
                        __block CDLocationEvent *day3Event1;
                        
                        beforeEach(^{
                            day2.sectionIdentifier = nil;
                            
                            day3 = [HLFixtures dayInContext:context];
                            day3.sectionIdentifier = @"3";
                            
                            day3Event1 = [HLFixtures locationEventInContext:context];
                            [[day3 mutableOrderedSetValueForKey:HLSelector(locationEvents)] addObject:day3Event1];
                            
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
                            NSIndexPath *event1IndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
                            NSIndexPath *event2IndexPath = [NSIndexPath indexPathForItem:1 inSection:0];
                            NSIndexPath *event3IndexPath = [NSIndexPath indexPathForItem:2 inSection:0];
                            
                            expect([controller objectAtIndexPath:event1IndexPath]).to.equal(day1Event1);
                            expect([controller objectAtIndexPath:event2IndexPath]).to.equal(day1Event2);
                            expect([controller objectAtIndexPath:event3IndexPath]).to.equal(day1Event3);
                            
                            expect([controller indexPathForObject:day1Event1]).to.equal(event1IndexPath);
                            expect([controller indexPathForObject:day1Event2]).to.equal(event2IndexPath);
                            expect([controller indexPathForObject:day1Event3]).to.equal(event3IndexPath);
                        });
                        
                        it(@"should return the right objects and backwards in section 1", ^{
                            NSIndexPath *event1IndexPath = [NSIndexPath indexPathForItem:0 inSection:1];
                            
                            expect([controller objectAtIndexPath:event1IndexPath]).to.equal(day3Event1);
                            
                            expect([controller indexPathForObject:day3Event1]).to.equal(event1IndexPath);
                        });
                        
                        describe(@"when the section returns to matching the predicate", ^{
                            beforeEach(^{
                                day2.sectionIdentifier = @"2";
                                
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
                                day2.sectionIdentifier = nil;
                                
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
        __block CDDay *day;
        
        beforeEach(^{
            context = [HLFixtures testingContext];
            day = [HLFixtures dayInContext:context];
            [context processPendingChanges];
            
            delegate = [OCMockObject mockForProtocol:@protocol(HLHierarchicalResultsDelegate)];
            
            controller = [[HLHierarchicalResultsController alloc] initWithParentObject:day
                                                                              childKey:HLSelector(locationEvents)
                                                                  managedObjectContext:context
                                                                              delegate:delegate];
        });
        
        it(@"should start with no items in the day", ^{
            expect(controller.numberOfSections).to.equal(1);
            expect([controller numberOfObjectsInSection:0]).to.equal(0);
        });
        
        describe(@"when a couple events are inserted", ^{
            __block CDLocationEvent *event1, *event2;
            
            beforeEach(^{
                event1 = [HLFixtures locationEventInContext:context];
                event2 = [HLFixtures locationEventInContext:context];
                
                NSMutableOrderedSet *orderedSet = [day mutableOrderedSetValueForKey:HLSelector(locationEvents)];
                [orderedSet addObjectsFromArray:@[ event1, event2 ]];
                
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
                NSIndexPath *event1IndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
                NSIndexPath *event2IndexPath = [NSIndexPath indexPathForItem:1 inSection:0];
                
                expect([controller objectAtIndexPath:event1IndexPath]).to.equal(event1);
                expect([controller objectAtIndexPath:event2IndexPath]).to.equal(event2);
                
                expect([controller indexPathForObject:event1]).to.equal(event1IndexPath);
                expect([controller indexPathForObject:event2]).to.equal(event2IndexPath);
            });
            
            describe(@"when adding a few more events", ^{
                __block CDLocationEvent *event3, *event4, *event5;
                
                beforeEach(^{
                    event3 = [HLFixtures locationEventInContext:context];
                    event4 = [HLFixtures locationEventInContext:context];
                    event5 = [HLFixtures locationEventInContext:context];
                    
                    NSMutableOrderedSet *orderedSet = [day mutableOrderedSetValueForKey:HLSelector(locationEvents)];
                    [orderedSet addObjectsFromArray:@[ event3, event4, event5 ]];
                    
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
                    NSIndexPath *event1IndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
                    NSIndexPath *event2IndexPath = [NSIndexPath indexPathForItem:1 inSection:0];
                    NSIndexPath *event3IndexPath = [NSIndexPath indexPathForItem:2 inSection:0];
                    NSIndexPath *event4IndexPath = [NSIndexPath indexPathForItem:3 inSection:0];
                    NSIndexPath *event5IndexPath = [NSIndexPath indexPathForItem:4 inSection:0];
                    
                    expect([controller objectAtIndexPath:event1IndexPath]).to.equal(event1);
                    expect([controller objectAtIndexPath:event2IndexPath]).to.equal(event2);
                    expect([controller objectAtIndexPath:event3IndexPath]).to.equal(event3);
                    expect([controller objectAtIndexPath:event4IndexPath]).to.equal(event4);
                    expect([controller objectAtIndexPath:event5IndexPath]).to.equal(event5);
                    
                    expect([controller indexPathForObject:event1]).to.equal(event1IndexPath);
                    expect([controller indexPathForObject:event2]).to.equal(event2IndexPath);
                    expect([controller indexPathForObject:event3]).to.equal(event3IndexPath);
                    expect([controller indexPathForObject:event4]).to.equal(event4IndexPath);
                    expect([controller indexPathForObject:event5]).to.equal(event5IndexPath);
                });

                describe(@"and then we move 2 items within the list", ^{
                    beforeEach(^{
                        NSMutableOrderedSet *orderedSet = [day mutableOrderedSetValueForKey:HLSelector(locationEvents)];
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
                        NSIndexPath *event1IndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
                        NSIndexPath *event2IndexPath = [NSIndexPath indexPathForItem:3 inSection:0];
                        NSIndexPath *event3IndexPath = [NSIndexPath indexPathForItem:2 inSection:0];
                        NSIndexPath *event4IndexPath = [NSIndexPath indexPathForItem:1 inSection:0];
                        NSIndexPath *event5IndexPath = [NSIndexPath indexPathForItem:4 inSection:0];
                        
                        expect([controller objectAtIndexPath:event1IndexPath]).to.equal(event1);
                        expect([controller objectAtIndexPath:event2IndexPath]).to.equal(event2);
                        expect([controller objectAtIndexPath:event3IndexPath]).to.equal(event3);
                        expect([controller objectAtIndexPath:event4IndexPath]).to.equal(event4);
                        expect([controller objectAtIndexPath:event5IndexPath]).to.equal(event5);
                        
                        expect([controller indexPathForObject:event1]).to.equal(event1IndexPath);
                        expect([controller indexPathForObject:event2]).to.equal(event2IndexPath);
                        expect([controller indexPathForObject:event3]).to.equal(event3IndexPath);
                        expect([controller indexPathForObject:event4]).to.equal(event4IndexPath);
                        expect([controller indexPathForObject:event5]).to.equal(event5IndexPath);
                    });
                });
            });
            
            describe(@"when the order of the objects changes", ^{
                beforeEach(^{
                    NSMutableOrderedSet *orderedSet = [day mutableOrderedSetValueForKey:HLSelector(locationEvents)];
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
                    NSIndexPath *event1IndexPath = [NSIndexPath indexPathForItem:1 inSection:0];
                    NSIndexPath *event2IndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
                    
                    expect([controller objectAtIndexPath:event1IndexPath]).to.equal(event1);
                    expect([controller objectAtIndexPath:event2IndexPath]).to.equal(event2);
                    
                    expect([controller indexPathForObject:event1]).to.equal(event1IndexPath);
                    expect([controller indexPathForObject:event2]).to.equal(event2IndexPath);
                });
            });
            
            describe(@"when the order changes and we insert at the same time", ^{
                __block CDLocationEvent *event3;
                
                beforeEach(^{
                    event3 = [HLFixtures locationEventInContext:context];
                    
                    NSMutableOrderedSet *orderedSet = [day mutableOrderedSetValueForKey:HLSelector(locationEvents)];
                    [orderedSet exchangeObjectAtIndex:0 withObjectAtIndex:1];
                    [orderedSet insertObject:event3 atIndex:1];
                    
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
                    NSIndexPath *event1IndexPath = [NSIndexPath indexPathForItem:2 inSection:0];
                    NSIndexPath *event2IndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
                    NSIndexPath *event3IndexPath = [NSIndexPath indexPathForItem:1 inSection:0];
                    
                    expect([controller objectAtIndexPath:event1IndexPath]).to.equal(event1);
                    expect([controller objectAtIndexPath:event2IndexPath]).to.equal(event2);
                    expect([controller objectAtIndexPath:event3IndexPath]).to.equal(event3);
                    
                    expect([controller indexPathForObject:event1]).to.equal(event1IndexPath);
                    expect([controller indexPathForObject:event2]).to.equal(event2IndexPath);
                    expect([controller indexPathForObject:event3]).to.equal(event3IndexPath);
                });
            });
        });
    });
});

SpecEnd
