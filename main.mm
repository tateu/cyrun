#import <signal.h>
#import <sys/sysctl.h>
#import <arpa/inet.h>
#import <spawn.h>
#import <AppList/AppList.h>

typedef long BKSOpenApplicationErrorCode;
enum {
	BKSOpenApplicationErrorCodeNone = 0,
};

extern NSString *BKSActivateForEventOptionTypeBackgroundContentFetching;
extern NSString *BKSDebugOptionKeyArguments;
extern NSString *BKSDebugOptionKeyEnvironment;
extern NSString *BKSDebugOptionKeyStandardOutPath;
extern NSString *BKSDebugOptionKeyStandardErrorPath;
extern NSString *BKSDebugOptionKeyWaitForDebugger;
extern NSString *BKSDebugOptionKeyDisableASLR;
extern NSString *BKSOpenApplicationOptionKeyDebuggingOptions;
extern NSString *BKSOpenApplicationOptionKeyUnlockDevice;
extern NSString *BKSOpenApplicationOptionKeyActivateForEvent;
extern NSString *BKSDebugOptionKeyDebugOnNextLaunch;
extern NSString *BKSDebugOptionKeyCancelDebugOnNextLaunch;

@interface BKSSystemService : NSObject {
	// FBSSystemService* _fbsSystemService;
}
-(void)cleanupClientPort:(unsigned)arg1 ;
-(void)openApplication:(id)arg1 options:(id)arg2 clientPort:(unsigned)arg3 withResult:(/*^block*/id)arg4 ;
-(void)terminateApplication:(id)arg1 forReason:(int)arg2 andReport:(BOOL)arg3 withDescription:(id)arg4 ;
-(void)terminateApplicationGroup:(int)arg1 forReason:(int)arg2 andReport:(BOOL)arg3 withDescription:(id)arg4 ;
-(id)init;
-(void)dealloc;
-(void)openApplication:(id)arg1 options:(id)arg2 withResult:(/*^block*/id)arg3 ;
-(id)systemApplicationBundleIdentifier;
-(int)pidForApplication:(id)arg1 ;
-(unsigned)createClientPort;
-(void)openURL:(id)arg1 application:(id)arg2 options:(id)arg3 clientPort:(unsigned)arg4 withResult:(/*^block*/id)arg5 ;
-(BOOL)canOpenApplication:(id)arg1 reason:(int*)arg2 ;
@end

inline BOOL isLocalPortOpen(short port)
{
	struct sockaddr_in addr;
	int sock = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);

	memset(&addr, 0, sizeof(addr));
	addr.sin_family = AF_INET;
	addr.sin_port = htons(port);

	if (inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr)) {
		int result = connect(sock, (struct sockaddr *)&addr, sizeof(addr));
		if (result == 0) {
			close(sock);
			return YES;
		}
	}

	return NO;
}

// https://stackoverflow.com/questions/6610705/how-to-get-process-id-in-iphone-or-ipad
inline int getPID(NSString *processNameSearch, NSString **actualProcessName)
{
	int pid = -1;
	int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL ,0};

	size_t miblen = 4;
	size_t size;
	int st = sysctl(mib, miblen, NULL, &size, NULL, 0);
	struct kinfo_proc * process = NULL;
	struct kinfo_proc * newprocess = NULL;

	do {
		size += size / 10;
		newprocess = (kinfo_proc *)realloc(process, size);

		if (!newprocess) {
			if (process) {
				free(process);
				process = NULL;
			}

			return pid;
		}

		process = newprocess;
		st = sysctl(mib, miblen, process, &size, NULL, 0);
	} while (st == -1 && errno == ENOMEM);

	if (st == 0) {
		if (size % sizeof(struct kinfo_proc) == 0) {
			int nprocess = size / sizeof(struct kinfo_proc);
			if (nprocess) {
				for (int i = nprocess - 1; i >= 0; i--) {
					NSString *processName = [[NSString alloc] initWithFormat:@"%s", process[i].kp_proc.p_comm];
					// fprintf(stderr, "processName (%s)\n", [processName UTF8String]);
					// NSString * processID = [[NSString alloc] initWithFormat:@"%d", process[i].kp_proc.p_pid];
					// NSString * proc_CPU = [[NSString alloc] initWithFormat:@"%d", process[i].kp_proc.p_estcpu];
					// double t = [[NSDate date] timeIntervalSince1970] - process[i].kp_proc.p_un.__p_starttime.tv_sec;
					// NSString * proc_useTiem = [[NSString alloc] initWithFormat:@"%f",t];

					if ([processName rangeOfString:processNameSearch options:NSCaseInsensitiveSearch].location != NSNotFound) {
						pid = process[i].kp_proc.p_pid;
						*actualProcessName = [processName copy];
						[processName release];
						break;
					}

					[processName release];
				}
			}
		}

		free(process);
		process = NULL;
	}

	return pid;
}

void showHelp()
{
	// fprintf(stderr, "Usage: %s \n", argv[0]);
	fprintf(stderr, "Usage:\n");
	fprintf(stderr, "      -b <AppBundleID>     - Bundle Identifier of the Application \n");
	fprintf(stderr, "                             \"com.apple.MobileSMS\"\n");
	fprintf(stderr, "      -n <AppName>         - Application Name\n");
	fprintf(stderr, "                             \"Messages\"\n");
	fprintf(stderr, "      -e                   - Enable Cycript for the given AppBundleID or AppName,\n");
	fprintf(stderr, "                                 then restart the Application\n");
	fprintf(stderr, "      -d                   - Disable Cycript for the given AppBundleID or AppName\n");
	fprintf(stderr, "                                 then restart the Application\n");
	fprintf(stderr, "                             If both enable and disable are set,\n");
	fprintf(stderr, "                                 Cycript will be loaded and then unloaded when done\n");
	fprintf(stderr, "      You must choose an option to Sign or an (AppBundleID or AppName) and options for (enable and/or disable Cycript)\n");
}

int main(int argc, char **argv, char **envp)
{
	BOOL enable = NO;
	BOOL disable = NO;
	BOOL force = NO;
	NSString *bundleIdentifier = nil;
	NSString *applicationName = nil;

	for (int i = 0; i < argc; i++) {
		if (strcmp(argv[i], "--bundle") == 0 || strcmp(argv[i], "-b") == 0) {
			bundleIdentifier = [NSString stringWithUTF8String:argv[++i]];
		} else if (strcmp(argv[i], "--name") == 0 || strcmp(argv[i], "-n") == 0) {
			applicationName = [NSString stringWithUTF8String:argv[++i]];
		} else if (strcmp(argv[i], "--enable") == 0 || strcmp(argv[i], "-e") == 0) {
			enable = YES;
		} else if (strcmp(argv[i], "--disable") == 0 || strcmp(argv[i], "-d") == 0) {
			disable = YES;
		} else if (strcmp(argv[i], "--force") == 0 || strcmp(argv[i], "-f") == 0) {
			force = YES;
		} else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
			showHelp();
			return 1;
		}
	}

	if ((!bundleIdentifier && !applicationName) || (!enable && !disable)) {
		showHelp();
		return 1;
	}

	if ([bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
		applicationName = @"SpringBoard";
	} else if (applicationName && [applicationName rangeOfString:@"SpringBoard" options:NSCaseInsensitiveSearch].location != NSNotFound) {
		applicationName = @"SpringBoard";
		bundleIdentifier = @"com.apple.springboard";
	} else {
		NSDictionary *applications = [[ALApplicationList sharedApplicationList] applications];
		if (bundleIdentifier) {
			applicationName = [applications objectForKey:bundleIdentifier];
			if (!applicationName) {
				fprintf(stderr, "ERROR - invalid bundleIdentifier %s\n", [bundleIdentifier UTF8String]);
			}
		} else {
			for (NSString *key in applications) {
				NSString *name = [applications objectForKey:key];
				// if ([name rangeOfString:applicationName options:NSCaseInsensitiveSearch].location != NSNotFound) {
				if ([name isEqualToString:applicationName]) {
					applicationName = name;
					bundleIdentifier = key;
					break;
				}
			}
		}
	}

	if (!bundleIdentifier) {
		fprintf(stderr, "ERROR - could not find bundleIdentifier for %s\n", [applicationName UTF8String]);
		return 1;
	}

	if (!applicationName) {
		fprintf(stderr, "ERROR - could not find applicationName for %s\n", [bundleIdentifier UTF8String]);
		return 1;
	}

	// if (bundleIdentifier) {
	// 	NSBundle *bundle = [NSBundle bundleWithIdentifier:bundleIdentifier];
	// 	if (!bundle) {
	// 		fprintf(stderr, "ERROR - invalid bundleIdentifier %s\n", [bundleIdentifier UTF8String]);
	// 		// return 1;
	// 	}
	//
	// 	applicationName = [bundle objectForInfoDictionaryKey:@"CFBundleExecutable"];
	// 	if (!applicationName) {
	// 		fprintf(stderr, "ERROR - could not find applicationName for bundleIdentifier %s\n", [bundleIdentifier UTF8String]);
	// 		// return 1;
	// 	}
	// }

	// NSArray *array = [NSBundle allBundles];
	// NSLog(@"allBundles %@", array);


	NSArray *filterFileBundles = nil;
	NSString *actualProcessName = nil;
	int pid = getPID(applicationName, &actualProcessName);
	BOOL isCycriptRunning = isLocalPortOpen(8556);
	if (isCycriptRunning) {
		NSDictionary *filterFile = [NSDictionary dictionaryWithContentsOfFile:@"/usr/lib/TweakInject/cycriptListener.plist"];
		NSDictionary *filter = [filterFile objectForKey:@"Filter"];
		filterFileBundles = [filter objectForKey:@"Bundles"];
		[filterFile release];
	}

	if (actualProcessName) {
		applicationName = actualProcessName;
	}
	fprintf(stderr, "applicationName (%s) is %s\n    bundleIdentifier (%s)\n    pid (%d)\n    Cycript is %s (%s)\n", [applicationName UTF8String], pid == -1 ? "not running" : "running", [bundleIdentifier UTF8String], pid, isCycriptRunning ? "active" : "inactive", filterFileBundles ? [[filterFileBundles objectAtIndex:0] UTF8String] : "");

	if (isCycriptRunning && !enable && disable) {
		if (filterFileBundles && ![bundleIdentifier isEqualToString:[filterFileBundles objectAtIndex:0]]) {
			fprintf(stderr, "WARNING - Cycript is active but it looks like the bundleIdentifier you are trying to disable it for does not match!\n");
		}
	}

	if (!force) {
		fprintf(stderr, "Do you want to continue %s Cycript (y or n)? ", enable ? "enabling" : "disabling");

		char userInput;
		scanf("%c", &userInput);
		if (userInput != 'y' && userInput != 'Y') {
			fprintf(stderr, "Ok, cancelled\n");
			if (actualProcessName) {
				[actualProcessName release];
			}
			return 1;
		}
	}

	if (enable) {
		if (isCycriptRunning) {
			fprintf(stderr, "ERROR - Cannot enable because Cycript is already active\n");
			fprintf(stderr, "You can probably disable it with\n    cyrun -b %s -d\n", [[filterFileBundles objectAtIndex:0] UTF8String]);
			return 1;
		}

		NSDictionary *filter = [NSDictionary dictionaryWithObjectsAndKeys:
			@[bundleIdentifier], @"Bundles",
			nil
		];
		NSDictionary *filterFile = [NSDictionary dictionaryWithObjectsAndKeys:
			filter, @"Filter",
			nil
		];

		[filterFile writeToFile:@"/usr/lib/TweakInject/cycriptListener.plist" atomically:YES];
		[filter release];
		[filterFile release];

		if ([NSFileManager.defaultManager fileExistsAtPath:@"/usr/lib/TweakInject/cycriptListener.disabled"]) {
			NSError *error = NULL;
			BOOL result = YES;
			if ([NSFileManager.defaultManager fileExistsAtPath:@"/usr/lib/TweakInject/cycriptListener.dylib"]) {
				// this might happen right after reinstalling the tweak
				result = [NSFileManager.defaultManager removeItemAtPath:@"/usr/lib/TweakInject/cycriptListener.disabled" error:&error];
			} else {
				result = [NSFileManager.defaultManager moveItemAtPath:@"/usr/lib/TweakInject/cycriptListener.disabled" toPath:@"/usr/lib/TweakInject/cycriptListener.dylib" error:&error];
				if (!result) {
					fprintf(stderr, "ERROR - enabling dylib file\n    (%ld) %s\n", error.code, [error.localizedDescription UTF8String]);
					return 1;
				}
			}
		}

		BKSSystemService *systemService = [[BKSSystemService alloc] init];
		NSMutableDictionary *options = [NSMutableDictionary dictionary];
		[options setObject:[NSNumber numberWithBool:NO] forKey:BKSOpenApplicationOptionKeyUnlockDevice];
		[options setObject:[NSNumber numberWithBool:YES] forKey:@"__ActivateSuspended"];
		// [options setObject:[NSNumber numberWithBool:YES] forKey:BKSActivateForEventOptionTypeBackgroundContentFetching];

		if (pid != -1) {
			// [systemService terminateApplication:bundleIdentifier forReason:0 andReport:NO withDescription:@"cyrun"];
			// [systemService terminateApplication:applicationName forReason:0 andReport:NO withDescription:@"cyrun"];
			pid_t p;
			char *argv[] = {"killall", "-9", (char *)[applicationName UTF8String], NULL};
			posix_spawn(&p, "/usr/bin/killall", NULL, NULL, argv, NULL);
			// char pids[16];
			// sprintf(pids, "-n 9 %d", pid);
			// char *argv[] = {"kill", pids, NULL};
			// posix_spawn(&p, "/usr/bin/kill", NULL, NULL, argv, NULL);

			// while (pid != -1) {
			// 	pid = getPID(applicationName, &actualProcessName);
			// }

			if ([bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
				fprintf(stderr, "Waiting for SpringBoard to close...\n");
				int lastpid = pid;
				[NSThread sleepForTimeInterval:2.0f];
				pid = getPID(applicationName, &actualProcessName);
				if (lastpid == pid) {
					fprintf(stderr, "ERROR - could not kill SpringBoard\n");
					return 1;
				}
			} else {
				fprintf(stderr, "Waiting for App to close...\n");
				[NSThread sleepForTimeInterval:2.0f];
				pid = getPID(applicationName, &actualProcessName);
				if (pid != -1) {
					fprintf(stderr, "ERROR - could not kill App\n");
					return 1;
				}
			}
		}

		if (![bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
			__block BKSOpenApplicationErrorCode openApplicationErrorCode = BKSOpenApplicationErrorCodeNone;
			__block dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
			[systemService openApplication:bundleIdentifier options:options withResult:^(NSError *error) {
					if (error) {
						fprintf(stderr, "ERROR - openApplication failed for %s\n    (%ld) %s\n", [bundleIdentifier UTF8String], error.code, [error.localizedDescription UTF8String]);
						openApplicationErrorCode = (BKSOpenApplicationErrorCode)[error code];
					}

					// always returns -1
					// pid_t pid = [systemService pidForApplication:bundleIdentifier];
					// fprintf(stderr, "pid = %d, %s\n", pid, [bundleIdentifier UTF8String]);

					dispatch_semaphore_signal(semaphore);
				}
			];

			const uint32_t timeoutDuration = 10;
			dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, timeoutDuration * NSEC_PER_SEC);
			long success = dispatch_semaphore_wait(semaphore, timeout) == 0;

			if (!success) {
				fprintf(stderr, "ERROR - openApplication timeout for %s\n", [bundleIdentifier UTF8String]);
			} else if (openApplicationErrorCode != BKSOpenApplicationErrorCodeNone) {
				// fprintf(stderr, "ERROR - openApplication failed (%ld) for %s\n", openApplicationErrorCode, [bundleIdentifier UTF8String]);
			} else {
				pid = getPID(applicationName, &actualProcessName);
				if (pid == -1) {
					fprintf(stderr, "ERROR - could not launch App, pid not found for %s\n", [applicationName UTF8String]);
				} else {
					isCycriptRunning = isLocalPortOpen(8556);
					fprintf(stderr, "Waiting for Cycript to be active...\n");
					for (int i = 0; i < 5 && !isCycriptRunning; i++) {
						[NSThread sleepForTimeInterval:1.0f];
						isCycriptRunning = isLocalPortOpen(8556);
					}

					if (!isCycriptRunning) {
						fprintf(stderr, "ERROR - could connect to Cycript\n");
					} else {
						fprintf(stderr, "Success, you may now run\n    cycript -r 127.0.0.1:8556\n");
					}
				}
			}

			dispatch_release(semaphore);
			[systemService release];
			[options release];
		} else {
			fprintf(stderr, "Waiting for SpringBoard to launch...\n");
			[NSThread sleepForTimeInterval:5.0f];
			fprintf(stderr, "Successfully enabled, you may now run\n    cycript -r 127.0.0.1:8556\n");
		}
	} else {
		if ([NSFileManager.defaultManager fileExistsAtPath:@"/usr/lib/TweakInject/cycriptListener.dylib"]) {
			NSError *error = NULL;
			BOOL result = YES;
			if ([NSFileManager.defaultManager fileExistsAtPath:@"/usr/lib/TweakInject/cycriptListener.disabled"]) {
				// this might happen right after reinstalling the tweak
				result = [NSFileManager.defaultManager removeItemAtPath:@"/usr/lib/TweakInject/cycriptListener.disabled" error:&error];
			}

			result = [NSFileManager.defaultManager moveItemAtPath:@"/usr/lib/TweakInject/cycriptListener.dylib" toPath:@"/usr/lib/TweakInject/cycriptListener.disabled" error:&error];
			if (!result) {
				fprintf(stderr, "ERROR - disabling dylib file\n    (%ld) %s\n", error.code, [error.localizedDescription UTF8String]);
				return 1;
			}
		}

		if (isCycriptRunning) {
			if (pid != -1) {
				// [systemService terminateApplication:bundleIdentifier forReason:0 andReport:NO withDescription:@"cyrun"];
				pid_t p;
				char *argv[] = {"killall", "-9", (char *)[applicationName UTF8String], NULL};
				posix_spawn(&p, "/usr/bin/killall", NULL, NULL, argv, NULL);

				// while (pid != -1) {
				// 	pid = getPID(applicationName, &actualProcessName);
				// }

				if (![bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
					fprintf(stderr, "Waiting for App to close...\n");
					[NSThread sleepForTimeInterval:2.0f];
					pid = getPID(applicationName, &actualProcessName);
					if (pid != -1) {
						fprintf(stderr, "ERROR - could not kill App\n");
						return 1;
					}
				}

				isCycriptRunning = isLocalPortOpen(8556);
				fprintf(stderr, "Waiting for Cycript to be inactive...\n");
				for (int i = 0; i < 5 && isCycriptRunning; i++) {
					[NSThread sleepForTimeInterval:1.0f];
					isCycriptRunning = isLocalPortOpen(8556);
				}

				if (isCycriptRunning) {
					fprintf(stderr, "ERROR - Cycript is still running\n    %s was killed\n", [applicationName UTF8String]);
				} else {
					fprintf(stderr, "Successfully disabled\n    %s was killed\n", [applicationName UTF8String]);
				}
			} else {
				fprintf(stderr, "Successfully disabled\n");
			}
		} else {
			fprintf(stderr, "Successfully disabled\n    Cycript was not active, so %s was not killed\n", [applicationName UTF8String]);
		}
	}

	if (actualProcessName) {
		[actualProcessName release];
	}

	return 0;
}
