//
//  OuterObject.h
//  
//
//  Created by Zachary West on 2015-06-02.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class InnerObject;

@interface OuterObject : NSManagedObject

@property (nonatomic, retain) NSString *outerSortKey;
@property (nonatomic, retain) NSOrderedSet *objects;

@end
