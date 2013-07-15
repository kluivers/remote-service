//
//  JKRemoteSession.h
//  RemoteServer
//
//  Created by Joris Kluivers on 7/15/13.
//  Copyright (c) 2013 Joris Kluivers. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "JKRemoteSessionDelegate.h"

typedef NS_ENUM(NSInteger, JKRemoteSessionType) {
    JKRemoteSessionServer,
    JKRemoteSessionClient
};

@interface JKRemoteSession : NSObject

@property(nonatomic, readonly) NSString *identifier;
@property(nonatomic, readonly) NSString *name;
@property(nonatomic, readonly) JKRemoteSessionType type;

@property(nonatomic, weak) id<JKRemoteSessionDelegate> delegate;

- (id) initWithIdentifier:(NSString *)identifier displayName:(NSString *)name type:(JKRemoteSessionType)type;

@end
