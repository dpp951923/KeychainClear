#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <sys/socket.h>
#import <sys/un.h>
#import <sys/stat.h>
#import <unistd.h>
#import <errno.h>
#import <string.h>

static NSString * const kSocketPath = @"/var/mobile/Library/Caches/com.example.keychainclear.sock";

static NSArray *ItemClasses(void) {
    return @[
        (__bridge NSString *)kSecClassKey,
        (__bridge NSString *)kSecClassIdentity,
        (__bridge NSString *)kSecClassCertificate,
        (__bridge NSString *)kSecClassGenericPassword,
        (__bridge NSString *)kSecClassInternetPassword
    ];
}

static NSDictionary *ClearKeychain(void) {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];

    for (NSString *itemClass in ItemClasses()) {
        NSDictionary *query = @{
            (__bridge NSString *)kSecClass: itemClass,
            (__bridge NSString *)kSecAttrSynchronizable:
                (__bridge id)kSecAttrSynchronizableAny
        };

        OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
        result[itemClass] = @(status);
        NSLog(@"[KeychainClear] SecItemDelete(%@) => OSStatus %d", itemClass, (int)status);
    }

    return result;
}

static NSString *RunClear(void) {
    @try {
        NSLog(@"[KeychainClear] Clearing keychain...");
        NSDictionary *result = ClearKeychain();
        NSData *data = [NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
        NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"[KeychainClear] Done.");
        return [NSString stringWithFormat:@"%@\n", json ?: @"{}"]; 
    } @catch (NSException *exception) {
        NSLog(@"[KeychainClear] Error: %@", exception);
        return [NSString stringWithFormat:@"error: %@\n", exception.reason ?: @"unknown"];
    }
}

static NSString *HandleCommand(NSString *command) {
    NSString *value = [command stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([value isEqualToString:@"ping"]) return @"pong\n";
    if ([value isEqualToString:@"status"]) return @"ready\n";
    if ([value isEqualToString:@"clear"]) return RunClear();
    return @"error: unknown command\n";
}

static void StartSocketServer(void) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        const char *path = kSocketPath.UTF8String;
        unlink(path);

        int serverFD = socket(AF_UNIX, SOCK_STREAM, 0);
        if (serverFD < 0) return;

        struct sockaddr_un address;
        memset(&address, 0, sizeof(address));
        address.sun_family = AF_UNIX;
        strncpy(address.sun_path, path, sizeof(address.sun_path) - 1);

        if (bind(serverFD, (struct sockaddr *)&address, sizeof(address)) != 0) {
            close(serverFD);
            return;
        }

        chmod(path, 0660);
        if (listen(serverFD, 4) != 0) {
            close(serverFD);
            unlink(path);
            return;
        }

        NSLog(@"[KeychainClear] socket ready: %@", kSocketPath);

        for (;;) {
            int clientFD = accept(serverFD, NULL, NULL);
            if (clientFD < 0) continue;

            char buffer[256] = {0};
            ssize_t length = read(clientFD, buffer, sizeof(buffer) - 1);
            if (length > 0) {
                NSString *command = [[NSString alloc] initWithBytes:buffer length:(NSUInteger)length encoding:NSUTF8StringEncoding];
                NSString *response = HandleCommand(command ?: @"");
                NSData *responseData = [response dataUsingEncoding:NSUTF8StringEncoding];
                write(clientFD, responseData.bytes, responseData.length);
            }
            close(clientFD);
        }
    });
}

%ctor {
    StartSocketServer();
}
