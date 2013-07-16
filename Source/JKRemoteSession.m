//
//  JKRemoteSession.m
//  RemoteServer
//
//  Created by Joris Kluivers on 7/15/13.
//  Copyright (c) 2013 Joris Kluivers. All rights reserved.
//

#import "JKRemoteSession.h"

@interface JKRemoteSession () <NSNetServiceBrowserDelegate>
@property(nonatomic, strong) NSString *identifier;
@property(nonatomic, strong) NSString *name;
@property(nonatomic, strong) NSUUID *sessionUUID;
@property(nonatomic, assign) JKRemoteSessionType type;

@property(nonatomic, strong) NSNetService *service;
@property(nonatomic, strong) NSNetServiceBrowser *browser;

@end

@implementation JKRemoteSession {
    NSMutableArray *_servers;
}

- (id) initWithIdentifier:(NSString *)identifier displayName:(NSString *)name type:(JKRemoteSessionType)type
{
    self = [super init];
    
    if (self) {
        _servers = [NSMutableArray array];
        
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
    return nil;
}

#pragma mark - Browser delegate

- (void) netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    NSLog(@"Found service: %@", aNetService);
    
    NSData *textData = [aNetService TXTRecordData];
    NSDictionary *serviceInfo = [NSNetService dictionaryFromTXTRecordData:textData];
    
    NSLog(@"Service info: %@", serviceInfo);
    
    if (!moreComing && [self.delegate respondsToSelector:@selector(discoveredServersDidChangeForSession:)]) {
        [self.delegate discoveredServersDidChangeForSession:self];
    }
}

- (void) netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    NSLog(@"Remove service: %@", aNetService);
    
    if (!moreComing && [self.delegate respondsToSelector:@selector(discoveredServersDidChangeForSession:)]) {
        [self.delegate discoveredServersDidChangeForSession:self];
    }
}



@end
