//
//  NSKeyedUnarchiver+Location.m
//  Pods
//
//  Created by Rasmus Kildevæld   on 19/10/2015.
//
//

#import "NSKeyedUnarchiver+Location.h"

@implementation NSKeyedUnarchiver (Location)

+ (id)location_unarchiveObjectWithFilePath:(NSString *)filePath error:(NSError **)error {
    id object = nil;
    @try {
        object = [self unarchiveObjectWithFile:filePath];
    }
    @catch (NSException *exception) {
        object = nil;
        if (error != nil) {
            *error = [NSError errorWithDomain:@"com.softshag.location" code:1 userInfo:nil];
        }
    }
    
    return object;
}

@end
