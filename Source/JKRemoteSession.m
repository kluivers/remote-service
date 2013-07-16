//
//  JKRemoteSession.m
//  RemoteServer
//
//  Created by Joris Kluivers on 7/15/13.
//  Copyright (c) 2013 Joris Kluivers. All rights reserved.
//

#import "JKRemoteSession.h"

#import "GCDAsyncSocket.h"

@interface JKRemoteSession () <NSNetServiceBrowserDelegate, NSNetServiceDelegate, GCDAsyncSocketDelegate>
@property(nonatomic, strong) NSString *identifier;
@property(nonatomic, strong) NSString *name;
@property(nonatomic, strong) NSUUID *sessionUUID;
@property(nonatomic, assign) JKRemoteSessionType type;

@property(nonatomic, strong) NSNetService *service;
@property(nonatomic, strong) NSNetServiceBrowser *browser;

@property(nonatomic, strong) GCDAsyncSocket *socket;

@end

@implementation JKRemoteSession {
    NSMutableArray *_services;
    NSMutableDictionary *_servers;
}

- (id) initWithIdentifier:(NSString *)identifier displayName:(NSString *)name type:(JKRemoteSessionType)type
{
    self = [super init];
    
    if (self) {
        _services = [NSMutableArray array];
        _servers = [NSMutableDictionary dictionary];
        
        _sessionUUID = [NSUUID UUID];
        
        _identifier = identifier;
        _name = name;
        _type = type;
        
        NSString *serviceType = [NSString stringWithFormat:@"%@._tcp.", identifier];
        
        if (self.type == JKRemoteSessionServer) {
            self.service = [[NSNetService alloc] initWithDomain:@"" type:serviceType name:self.name port:9009];
            
            NSDictionary *serviceInfo = @{@"sessionUUID": [_sessionUUID UUIDString]};
            NSLog(@"Service info: %@", serviceInfo);
            BOOL success = [self.service setTXTRecordData:[NSNetService dataFromTXTRecordDictionary:serviceInfo]];
            if (!success) {
                NSLog(@"Failed to set TXT record data");
            }

            [self.service publish];
            
            // TODO: setup socket to accept connections
        } else if (self.type == JKRemoteSessionClient) {
            self.browser = [[NSNetServiceBrowser alloc] init];
            self.browser.delegate = self;
            [self.browser searchForServicesOfType:serviceType inDomain:@""];
        }
    }
    
    return self;
}

- (NSString *) nameForServerUUID:(NSUUID *)uuid
{
    NSNetService *service = _servers[uuid];
    return [service name];
}

- (NSArray *) discoveredServers
{
    return [_servers allKeys];
}

- (void) connectTo:(NSUUID *)uuid withTimeout:(NSTimeInterval)timeout
{
    NSNetService *server = _servers[uuid];
    if (!server) {
        return;
    }
    
    NSLog(@"Connect to %@:%d", server.hostName, server.port);
    
    self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    NSError *connectError = nil;
    
    NSData *address = [server addresses][0];
    BOOL success = [self.socket connectToAddress:address withTimeout:timeout error:&connectError];
    
    if (!success) {
        NSLog(@"Error connecting: %@", connectError);
        return;
    }
}

- (void) sendData:(NSData *)data
{
    
}

#pragma mark - Async socket delegation

- (void) socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port;
{
    NSLog(@"%s", __func__);
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    NSLog(@"Did disconnect with error: %@", err);
}

#pragma mark - Browser delegate

- (void) netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    NSLog(@"Found service: %@", aNetService);
    [_services addObject:aNetService];
    
    if (!moreComing) {
        [self resolveServices];
    }
}

- (void) resolveServices
{
    for (NSNetService *service in _services) {
        service.delegate = self;
        [service resolveWithTimeout:5.0];
    }
}

- (void) netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    NSLog(@"Remove service: %@", aNetService);
    
    if (!moreComing && [self.delegate respondsToSelector:@selector(discoveredServersDidChangeForSession:)]) {
        [self.delegate discoveredServersDidChangeForSession:self];
    }
}

- (void) netServiceDidResolveAddress:(NSNetService *)sender
{
    NSLog(@"Resolved service: %@", sender);
    
    NSData *textData = [sender TXTRecordData];
    NSDictionary *serviceInfo = [NSNetService dictionaryFromTXTRecordData:textData];
    
    NSData *stringData = serviceInfo[@"sessionUUID"];
    
    NSString *uuidString = [[NSString alloc] initWithData:stringData encoding:NSUTF8StringEncoding];
    
    [_servers setObject:sender forKey:[[NSUUID alloc] initWithUUIDString:uuidString]];
    [_services removeObject:sender];
    
    if ([self.delegate respondsToSelector:@selector(discoveredServersDidChangeForSession:)]) {
        [self.delegate discoveredServersDidChangeForSession:self];
    }
}



@end
