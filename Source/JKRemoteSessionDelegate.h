//
//  JKRemoteSessionDelegate.h
//  RemoteServer
//
//  Created by Joris Kluivers on 7/15/13.
//  Copyright (c) 2013 Joris Kluivers. All rights reserved.
//

#import <Foundation/Foundation.h>

@class JKRemoteSession;

@protocol JKRemoteSessionDelegate <NSObject>
- (void) remoteSessionDidReceiveConnectionRequest:(JKRemoteSession *)session;
@end
