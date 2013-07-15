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
@property(nonatomic, assign) JKRemoteSessionType type;

@property(nonatomic, strong) NSNetService *service;
@property(nonatomic, strong) NSNetServiceBrowser *browser;

@end

@implementation JKRemoteSession

- (id) initWithIdentifier:(NSString *)identifier displayName:(NSString *)name type:(JKRemoteSessionType)type
{
    self = [super init];
    
    if (self) {
        _identifier = identifier;
        _name = name;
        _type = type;
        
        NSString *serviceType = [NSString stringWithFormat:@"%@._tcp.", identifier];
        
        if (self.type == JKRemoteSessionServer) {
            self.service = [[NSNetService alloc] initWithDomain:@"" type:serviceType name:self.name port:9009];
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

#pragma mark - Browser delegate

- (void) netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    NSLog(@"Found service: %@", aNetService);
}

@end
