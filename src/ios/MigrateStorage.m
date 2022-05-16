#import <Cordova/CDV.h>
#import <Cordova/NSDictionary+CordovaPreferences.h>
#import <sqlite3.h>
#import "MigrateStorage.h"

// Uncomment this to enable debug mode
// #define DEBUG_MODE = 1;

#ifdef DEBUG_MODE
#   define logDebug(...) NSLog(__VA_ARGS__)
#else
#   define logDebug(...)
#endif

#define TAG @"\nMigrateStorage"

#define LOCALSTORAGE_DIRPATH @"WebKit/WebsiteData/LocalStorage/"
#define INDEXDB_DIRPATH @"WebKit/WebsiteData/IndexedDB/v1/"
#define DEFAULT_TARGET_HOSTNAME @"localhost"
#define DEFAULT_TARGET_SCHEME @"ionic"
#define DEFAULT_TARGET_PORT_NUMBER @"0"

#define DEFAULT_ORIGINAL_HOSTNAME @"localhost"
#define DEFAULT_ORIGINAL_SCHEME @"http"
#define DEFAULT_ORIGINAL_PORT_NUMBER @"8080"

#define SETTING_TARGET_PORT_NUMBER @"WKPort"
#define SETTING_TARGET_HOSTNAME @"Hostname"
#define SETTING_TARGET_SCHEME @"iosScheme"

#define SETTING_ORIGINAL_PORT_NUMBER @"MIGRATE_STORAGE_ORIGINAL_PORT_NUMBER"
#define SETTING_ORIGINAL_HOSTNAME @"MIGRATE_STORAGE_ORIGINAL_HOSTNAME"
#define SETTING_ORIGINAL_SCHEME @"MIGRATE_STORAGE_ORIGINAL_SCHEME"


@interface MigrateStorage ()
    @property (nonatomic, assign) NSString *originalPortNumber;
    @property (nonatomic, assign) NSString *originalHostname;
    @property (nonatomic, assign) NSString *originalScheme;
    @property (nonatomic, assign) NSString *targetPortNumber;
    @property (nonatomic, assign) NSString *targetHostname;
    @property (nonatomic, assign) NSString *targetScheme;
@end

@implementation MigrateStorage

- (NSString*)getOriginalPath
{
    return [NSString stringWithFormat:@"%@_%@_%@", self.originalScheme, self.originalHostname, self.originalPortNumber];
}

- (NSString*)getTargetPath
{
    return [NSString stringWithFormat:@"%@_%@_%@", self.targetScheme, self.targetHostname, self.targetPortNumber];
}

- (BOOL)moveFile:(NSString*)src to:(NSString*)dest
{
    logDebug(@"%@ moveFile()", TAG);
    logDebug(@"%@ moveFile() src: %@", TAG, src);
    logDebug(@"%@ moveFile() dest: %@", TAG, dest);

    NSFileManager *fileManager = [NSFileManager defaultManager];

    // Bail out if source file does not exist
    if (![fileManager fileExistsAtPath:src]) {
        logDebug(@"%@ source file does not exist: %@", TAG, src);
        return NO;
    }

    // Bail out if dest file exists
    if ([fileManager fileExistsAtPath:dest]) {
        logDebug(@"%@ destination file already exists: %@", TAG, dest);
         return NO;
    }

    // create path to destination
    if (![fileManager createDirectoryAtPath:[dest stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil]) {
        logDebug(@"%@ create dir failed: %@", TAG, dest);
         return NO;
    }

    BOOL res = [fileManager moveItemAtPath:src toPath:dest error:nil];

    logDebug(@"%@ end moveFile(src: %@ , dest: %@ ); success: %@", TAG, src, dest, res ? @"YES" : @"NO");

    return res;
}

- (BOOL) migrateLocalStorage
{
    NSLog(@"ket inside migrateLocalStorage!");
    logDebug(@"%@ migrateLocalStorage()", TAG);

    BOOL success;
    NSString *originalPath = [self getOriginalPath];
    NSString *targetPath = [self getTargetPath];

    NSString *appLibraryFolder = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];

    NSString *originalLocalStorageFileName = [originalPath stringByAppendingString:@".localstorage"];

    NSString *targetLocalStorageFileName = [targetPath stringByAppendingString:@".localstorage"];

    NSString *originalLocalStorageFilePath = [[appLibraryFolder stringByAppendingPathComponent:LOCALSTORAGE_DIRPATH] stringByAppendingPathComponent:originalLocalStorageFileName];

    NSString *targetLocalStorageFilePath = [[appLibraryFolder stringByAppendingPathComponent:LOCALSTORAGE_DIRPATH] stringByAppendingPathComponent:targetLocalStorageFileName];

    logDebug(@"%@ LocalStorage original %@", TAG, originalLocalStorageFilePath);
    logDebug(@"%@ LocalStorage target %@", TAG, targetLocalStorageFilePath);

    NSFileManager *fileManager = [NSFileManager defaultManager];

    if ([fileManager fileExistsAtPath:originalLocalStorageFilePath]) {
        logDebug(@"%@ LocalStorage target exists!", TAG);
    } else {
        logDebug(@"%@ LocalStorage target does not exist!", TAG);
    }

    if ([fileManager fileExistsAtPath:targetLocalStorageFilePath]) {
        logDebug(@"%@ LocalStorage original exists!", TAG);
    } else {
        logDebug(@"%@ LocalStorage original does not exist!", TAG);
    }

   

    // Only copy data if no existing localstorage data exists yet for wkwebview
    if (![fileManager fileExistsAtPath:targetLocalStorageFilePath]) {
              logDebug(@"ket  copy data if no existing localstorage data exists yet for wkwebview ooooooooooooooooooooooooooooooooooooo");

        logDebug(@"%@ No existing localstorage data found for WKWebView. Migrating data from UIWebView", TAG);
        BOOL success1 = [self moveFile:originalLocalStorageFilePath to:targetLocalStorageFilePath];
        BOOL success2 = [self moveFile:[originalLocalStorageFilePath stringByAppendingString:@"-shm"] to:[targetLocalStorageFilePath stringByAppendingString:@"-shm"]];
        BOOL success3 = [self moveFile:[originalLocalStorageFilePath stringByAppendingString:@"-wal"] to:[targetLocalStorageFilePath stringByAppendingString:@"-wal"]];
        logDebug(@"%@ copy status %d %d %d", TAG, success1, success2, success3);
        success = success1 && success2 && success3;
    }
    else {
                  logDebug(@"ket  found existing target LocalStorage data. Not migrating ooooooooooooooooooooooooooooooooooooo");


        logDebug(@"%@ found existing target LocalStorage data. Not migrating.", TAG);
        success = NO;
    }

    logDebug(@"%@ end migrateLocalStorage() with success: %@", TAG, success ? @"YES": @"NO");

    return success;
}

- (BOOL) migrateIndexedDB
{
    logDebug(@"%@ migrateIndexedDB()", TAG);
    
    NSString *originalPath = [self getOriginalPath];
    NSString *targetPath = [self getTargetPath];
    
    NSString *appLibraryFolder = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    NSString *original = [[appLibraryFolder stringByAppendingPathComponent:INDEXDB_DIRPATH] stringByAppendingPathComponent:originalPath];
    NSString *target = [[appLibraryFolder stringByAppendingPathComponent:INDEXDB_DIRPATH] stringByAppendingPathComponent:targetPath];
    
    logDebug(@"%@ IDB original %@", TAG, original);
    logDebug(@"%@ IDB target %@", TAG, target);
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:target]) {
        logDebug(@"%@ No existing IDB data found for WKWebView. Migrating data from UIWebView", TAG);
        BOOL success = [self moveFile:original to:target];
        logDebug(@"%@ copy status IDB %d", TAG, success);
        return success;
    }
    else {
        logDebug(@"%@ found IDB data. Not migrating", TAG);
        return NO;
    }
}

- (void)pluginInitialize
{
    logDebug(@"%@ pluginInitialize()", TAG);

    NSDictionary *cdvSettings = self.commandDelegate.settings;

    self.originalPortNumber = [cdvSettings cordovaSettingForKey:SETTING_ORIGINAL_PORT_NUMBER];
    if([self.originalPortNumber length] == 0) {
        self.originalPortNumber = DEFAULT_ORIGINAL_PORT_NUMBER;
    }

    self.originalHostname = [cdvSettings cordovaSettingForKey:SETTING_ORIGINAL_HOSTNAME];
    if([self.originalHostname length] == 0) {
        self.originalHostname = DEFAULT_ORIGINAL_HOSTNAME;
    }

    self.originalScheme = [cdvSettings cordovaSettingForKey:SETTING_ORIGINAL_SCHEME];
    if([self.originalScheme length] == 0) {
        self.originalScheme = DEFAULT_ORIGINAL_SCHEME;
    }

    self.targetPortNumber = [cdvSettings cordovaSettingForKey:SETTING_TARGET_PORT_NUMBER];
    if([self.targetPortNumber length] == 0) {
        self.targetPortNumber = DEFAULT_TARGET_PORT_NUMBER;
    }

    self.targetHostname = [cdvSettings cordovaSettingForKey:SETTING_TARGET_HOSTNAME];
    if([self.targetHostname length] == 0) {
        self.targetHostname = DEFAULT_TARGET_HOSTNAME;
    }

    self.targetScheme = [cdvSettings cordovaSettingForKey:SETTING_TARGET_SCHEME];
    if([self.targetScheme length] == 0) {
        self.targetScheme = DEFAULT_TARGET_SCHEME;
    }

    [self migrateLocalStorage];
    [self migrateIndexedDB];

    logDebug(@"ket  end pluginInitialize ooooooooooooooooooooooooooooooooooooo");

    logDebug(@"%@ end pluginInitialize()", TAG);
}

@end
