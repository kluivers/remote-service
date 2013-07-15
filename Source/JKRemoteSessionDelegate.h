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

@optional

#pragma mark - Server delegation

- (void) remoteSessionDidReceiveConnectionRequest:(JKRemoteSession *)session;

#pragma mark - Client delegation

- (void) discoveredServersDidChangeForSession:(JKRemoteSession *)session;

@end
