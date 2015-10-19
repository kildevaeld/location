//
//  NSKeyedUnarchiver+Location.h
//  Pods
//
//  Created by Rasmus Kildevæld   on 19/10/2015.
//
//

#import <Foundation/Foundation.h>

@interface NSKeyedUnarchiver (Location)

+ (id)location_unarchiveObjectWithFilePath:(NSString *)filePath error:(NSError **)error;

@end
