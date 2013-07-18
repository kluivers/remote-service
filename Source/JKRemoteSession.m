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

#define ANNOUNCE_TAG 1
#define MSG_TAG 2

@implementation JKRemoteSession {
    NSMutableArray *_services;
    NSMutableDictionary *_servers;
    NSMutableDictionary *_clients;
    
    NSData *_separatorData;
    
    void(^_dataHandler)(NSData *);
}

- (id) initWithIdentifier:(NSString *)identifier displayName:(NSString *)name type:(JKRemoteSessionType)type
{
    self = [super init];
    
    if (self) {
        _separatorData = [@"\n<<MSG_END>>\n\n" dataUsingEncoding:NSUTF8StringEncoding];
        
        _services = [NSMutableArray array];
        _servers = [NSMutableDictionary dictionary];
        _clients = [NSMutableDictionary dictionary];
        
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
            
            self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
            
            NSError *acceptError = nil;
            BOOL acceptSuccess = [self.socket acceptOnPort:9009 error:&acceptError];
            if (!acceptSuccess) {
                NSLog(@"Failed to start listening on port: %@", acceptError);
            }
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

- (void) setReceivedDataHandler:(void(^)(NSData *))dataHandler
{
    _dataHandler = dataHandler;
}

- (void) connectTo:(NSUUID *)uuid withTimeout:(NSTimeInterval)timeout
{
    NSNetService *server = _servers[uuid];
    if (!server) {
        return;
    }
    
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
    if (self.type == JKRemoteSessionClient) {
        [self.socket writeData:data withTimeout:10.0 tag:0];
        [self.socket writeData:_separatorData withTimeout:10.0 tag:0];
    } else {
        // write data to all clients
        
        for (id key in [_clients allKeys]) {
            [self sendData:data toPeer:key];
        }
    }
}

- (void) sendData:(NSData *)data toPeer:(NSUUID *)peer
{
    GCDAsyncSocket *client = [_clients objectForKey:peer];
    
    [client writeData:data withTimeout:10.0 tag:0];
    [client writeData:_separatorData withTimeout:10.0 tag:0];
}

#pragma mark - Async socket delegation

- (void) socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port;
{
    NSLog(@"%s", __func__);
    
    // announce self
    NSDictionary *announcement = @{@"sessionUUID": [self.sessionUUID UUIDString]};
    
    NSError *serializationError = nil;
    NSData *announceData = [NSPropertyListSerialization dataWithPropertyList:announcement format:NSPropertyListBinaryFormat_v1_0 options:0 error:&serializationError];
    if (!announceData) {
        NSLog(@"Error: %@", serializationError);
        return;
    }
    
    [self sendData:announceData];
    [self.socket readDataToData:_separatorData withTimeout:-1 tag:MSG_TAG];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    NSLog(@"Did disconnect with error: %@", err);
}

- (void) socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    NSLog(@"%s", __func__);
    
    [newSocket readDataToData:_separatorData withTimeout:10.0 tag:ANNOUNCE_TAG];
}

- (void) socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    NSLog(@"Incoming data length: %d", [data length]);
    
    NSData *cleanData = [data subdataWithRange:NSMakeRange(0, [data length] - [_separatorData length])];
    
    if (tag == ANNOUNCE_TAG) {
        NSError *error = nil;
        NSDictionary *announce = [NSPropertyListSerialization propertyListWithData:cleanData options:NSPropertyListImmutable format:NULL error:&error];
        if (!announce) {
            NSLog(@"Deserialize error: %@", error);
            return;
        }
        
        NSUUID *sessionUUID = [[NSUUID alloc] initWithUUIDString:announce[@"sessionUUID"]];
        if (!sessionUUID) {
            [sock disconnect];
            return;
        }
        
        NSLog(@"New client announcement: %@", announce);
        
        if (![self.delegate respondsToSelector:@selector(remoteSession:shouldAcceptClient:)]
            || [self.delegate remoteSession:self shouldAcceptClient:announce]) {
            // accept
            
            [_clients setObject:sock forKey:sessionUUID];
            
            if ([self.delegate respondsToSelector:@selector(remoteSession:didConnectNewPeer:)]) {
                [self.delegate remoteSession:self didConnectNewPeer:sessionUUID];
            }
        } else {
            [sock disconnect];
            return;
        }
    }
    
    if (tag == MSG_TAG) {
        if (_dataHandler) {
            _dataHandler(cleanData);
        }
    }

    if (self.type == JKRemoteSessionClient) {
        [self.socket readDataToData:_separatorData withTimeout:-1 tag:MSG_TAG];
    } else {
        // server type, re-initiate read from socket we just received from
        [sock readDataToData:_separatorData withTimeout:-1 tag:MSG_TAG];
    }
    
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
    [_services removeObject:aNetService];
    
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
