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

/*!
 * List of NSUUID's for discovered servers.
 */
@property(nonatomic, readonly) NSArray *discoveredServers;

/*!
 * session uuid as know by other peers
 */
@property(nonatomic, readonly) NSUUID *sessionUUID;

@property(nonatomic, weak) id<JKRemoteSessionDelegate> delegate;

- (id) initWithIdentifier:(NSString *)identifier displayName:(NSString *)name type:(JKRemoteSessionType)type;

- (NSString *) nameForServerUUID:(NSUUID *)uuid;

/*!
 * Connect to a server
 */
- (void) connectTo:(NSUUID *)uuid withTimeout:(NSTimeInterval)timeout;

/*!
 * Sends data to the other end of the session. In case of a client session, 
 * this will send to the server. In case of a server session this will send 
 * to all clients.
 */
- (void) sendData:(NSData *)data;

/*!
 * Sends data to a specific peer, identified by it's NSUUID.
 */
- (void) sendData:(NSData *)data toPeer:(NSUUID *)peer;

@end
