// WOFPlugInManager.m
// Copyright 2010 Wincent Colaiuta. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

#import "WOFPlugInManager.h"

#import <libkern/OSAtomic.h>

//! Private methods.
@interface WOFPlugInManager ()

//! @return A stable, localization-independent identifying string for the host
//!         application bundle, based on the CFBundleName value from the
//!         application's Info.plist if available, and falling back to the
//!         running process name if not. This string is used as a subdirectory
//!         when searching for plug-ins inside the "Application Support"
//!         folders.
- (NSString *)hostBundleName;

//! @return An array of paths to be scanned when searching for plug-ins.
//! @note   Paths are ordered by decreasing specifity; that is, the "PlugIns"
//!         folder inside the host application bundle will appear before the
//!         corresponding folder in the user's home directory, which in turn
//!         will appear before the equivalent folder in the global "/Library/"
//!         directory.
- (NSArray *)searchPaths;

//! Scans the default search paths for bundles.
//!
//! @see    #searchPaths
- (void)findAllBundles;

@property(readwrite, copy) NSArray *bundles;

@end

@implementation WOFPlugInManager

+ (WOFPlugInManager *)sharedManager
{
    static WOFPlugInManager *manager = nil;
    if (!manager)
    {
        WOFPlugInManager *temp = [[self alloc] init];
        OSAtomicCompareAndSwapPtrBarrier(nil, temp, (void *)&manager);
    }
    return manager;
}

- (NSString *)hostBundleName
{
    NSString *name = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleNameKey];
    if (!name)
        name = [[NSProcessInfo processInfo] processName];
    return name;
}

- (NSArray *)searchPaths
{
    NSMutableArray *paths = [NSMutableArray arrayWithObject:[[NSBundle mainBundle] builtInPlugInsPath]];
    NSString *hostIdentifier = [self hostBundleName];
    NSSearchPathDomainMask domains = NSAllDomainsMask - NSSystemDomainMask;
    for (NSString *path in NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, domains, YES))
    {
        path = [path stringByAppendingPathComponent:hostIdentifier];
        path = [path stringByAppendingPathComponent:@"PlugIns"];
        [paths addObject:path];
    }
    return [paths copy];
}

- (void)findAllBundles
{
    NSMutableArray *bundles = [NSMutableArray array];
    NSFileManager *manager = [NSFileManager defaultManager];
    for (NSString *path in [self searchPaths])
    {
        NSArray *paths = [manager contentsOfDirectoryAtPath:path error:NULL];
        if (paths)
        {
            for (NSString *path in paths)
            {
                NSBundle *bundle = [NSBundle bundleWithPath:path];
                if (bundle)
                    [bundles addObject:bundle];
            }
        }
    }
    self.bundles = bundles;
}

- (WOFPlugIn *)plugInForIdentifier:(NSString *)anIdentifier
{
    // TODO: implementation
    return nil;
}

@synthesize bundles;

@end
