//
//  InnerObject.h
//  
//
//  Created by Zachary West on 2015-06-02.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class OuterObject;

@interface InnerObject : NSManagedObject

@property (nonatomic, retain) NSString * innerSortKey;
@property (nonatomic, retain) OuterObject *parentObject;

@end
