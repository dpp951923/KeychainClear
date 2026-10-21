#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <sys/socket.h>
#import <sys/un.h>
#import <unistd.h>
#import <errno.h>
#import <string.h>

// 与原 keychain_clear.js 对应的本地控制接口
static NSString * const kSocketPath = @"/var/mobile/Library/Caches/com.example.keychainclear.sock";

// 对应 JS 中的 itemClasses。
static NSArray<NSString *> *ItemClasses(void) {
    return @[
        (__bridge NSString *)kSecClassKey,
        (__bridge NSString *)kSecClassIdentity,
        (__bridge NSString *)kSecClassCertificate,
        (__bridge NSString *)kSecClassGenericPassword,
        (__bridge NSString *)kSecClassInternetPassword
    ];
}

// 对应 JS：SecItemDelete(searchDictionary)。
// 每一种 kSecClass 都使用 kSecAttrSynchronizableAny。
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

        NSLog(@"[KeychainClear] SecItemDelete(%@) => OSStatus %d",
              itemClass, (int)status);
    }

    return result;
}

static NSString *RunClear(void) {
    @try {
        NSLog(@"[KeychainClear] Clearing keychain...");
        NSDictionary *result = ClearKeychain();
        NSLog(@"[KeychainClear] Done.");

        NSData *data = [NSJSONSerialization dataWithJSONObject:result
                                                         options:0
                                                           error:nil];
        NSString *json = [[NSString alloc] initWithData:data
                                               encoding:NSUTF8StringEncoding];
        return [NSString stringWithFormat:@"%@\n", json ?: @"{}"];
    }
    @catch (NSException *exception) {
        NSLog(@"[KeychainClear] Error: %@", exception);
        return [NSString stringWithFormat:@"error: %@\n", exception.reason ?: @"unknown"];
    }
}

static NSString *HandleCommand(NSString *command) {
    NSString *value = [command stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if ([value isEqualToString:@"ping"]) {
        return @"pong\n";
    }

    if ([value isEqualToString:@"status"]) {
        return @"ready\n";
    }

    if ([value isEqualToString:@"clear"]) {
        return RunClear();
    }

    return @"error: unknown command\n";
}

static void StartSocketServer(void) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        const char *path = kSocketPath.UTF8String;
        unlink(path);

        int serverFD = socket(AF_UNIX, SOCK_STREAM, 0);
        if (serverFD < 0) {
            NSLog(@"[KeychainClear] socket failed, errno=%d", errno);
            return;
        }

        struct sockaddr_un address;
        memset(&address, 0, sizeof(address));
        address.sun_family = AF_UNIX;
        strncpy(address.sun_path, path, sizeof(address.sun_path) - 1);

        if (bind(serverFD, (struct sockaddr *)&address, sizeof(address)) != 0) {
            NSLog(@"[KeychainClear] bind failed, errno=%d", errno);
            close(serverFD);
            return;
        }

        chmod(path, 0660);

        if (listen(serverFD, 4) != 0) {
            NSLog(@"[KeychainClear] listen failed, errno=%d", errno);
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
                NSString *command = [[NSString alloc]
                    initWithBytes:buffer
                           length:(NSUInteger)length
                         encoding:NSUTF8StringEncoding];

                NSString *response = HandleCommand(command ?: @"");
                NSData *responseData =
                    [response dataUsingEncoding:NSUTF8StringEncoding];

                write(clientFD, responseData.bytes, responseData.length);
            }

            close(clientFD);
        }
    });
}

%ctor {
    // JS 是加载后立即执行；Tweak 改为加载后建立 Socket，
    // 由 Python 发送 clear 命令来触发同样的清理逻辑。
    StartSocketServer();
}
