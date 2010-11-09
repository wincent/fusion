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

#import "WOFPlugIn.h"

#import <libkern/OSAtomic.h>

//! Private methods, properties and property re-declarations.
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

//! Scans the default search paths for plug-ins.
//!
//! @see    #searchPaths
- (void)findAllPlugIns;

//! Removes duplicate plug-ins (plug-ins in different locations but with
//! identical identifiers), prioritizing plug-ins found earlier on in the search
//! path.
//!
//! @see #findAllPlugIns
- (void)determineUniquePlugIns;

//! Examines the declared dependencies of the set of unique plug-ins, and
//! establishes an order in which they should be loaded that will guarantee that
//! each plug-in's dependencies are already available by the time it is loaded.
//!
//! @exception  WOFCircularDependencyException thrown if a circular dependency
//!             is detected.
//! @note       There may be multiple valid load orders that would satisfy all
//!             dependencies; the load order that is determined by this method
//!             arises from the order in which plug-ins are listed on the disk.
- (void)resolveDependencies;

//! Recusive helper method that is used during the dependency resolution
//! process.
//!
//! @exception  WOFCircularDependencyException thrown if a circular dependency
//!             is detected.
- (void)resolveDependenciesForPlugIn:(WOFPlugIn *)aPlugIn
                            resolved:(NSMutableArray *)resolved
                          unresolved:(NSMutableSet *)unresolved;

//! An ordered list of plug-ins as found on disk.
//!
//! Locations are searched in the order returned by
//! NSSearchPathForDirectoriesInDomains(), which means that plug-ins which are
//! "closer" (for example, embedded inside the host application itself, or in
//! the user's home directory) will appear before plug-ins found elsewhere (in
//! /Library, for instance).
//!
//! This allows us to establish a precendence mechanism so that, given two
//! plug-ins in different locations but with the same bundle identifier, we
//! prefer the most proximal.
@property(readwrite, copy) NSArray *plugIns;

//! A dictionary of unique plug-ins, using bundle identifiers as keys and
//! plug-in instances as values, produced by removing duplicate plug-ins from
//! the plugIns list.
//!
//! When multiple plug-ins share the same identifier, the most proximal plug-in
//! is selected for membership in the uniquePlugIns set.
@property(readwrite, copy) NSDictionary *uniquePlugIns;

//! An ordered list of plug-ins with dependencies resolved.
//!
//! Plug-ins are ordered such that those which are dependencies of other
//! plug-ins appear earlier in the list. As such, the resolvedPlugIns list
//! effectively indicates the order in which plug-ins should be loaded so as to
//! guarantee that all dependencies are met.
@property(readwrite, copy) NSArray *resolvedPlugIns;

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

- (id)init
{
    if ((self = [super init]))
    {
        [self findAllPlugIns];
        [self determineUniquePlugIns];
    }
    return self;
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

- (void)findAllPlugIns
{
    NSMutableArray *plugIns = [NSMutableArray array];
    NSFileManager *manager = [NSFileManager defaultManager];
    for (NSString *path in [self searchPaths])
    {
        NSArray *paths = [manager contentsOfDirectoryAtPath:path error:NULL];
        if (paths)
        {
            for (NSString *path in paths)
            {
                WOFPlugIn *plugIn = [WOFPlugIn plugInWithPath:path];
                if (plugIn)
                    [plugIns addObject:plugIn];
            }
        }
    }
    self.plugIns = plugIns;
}

- (void)determineUniquePlugIns
{
    NSMutableDictionary *entries = [NSMutableDictionary dictionaryWithCapacity:[self.plugIns count]];
    for (WOFPlugIn *plugIn in self.plugIns)
    {
        NSString *identifier = [plugIn bundleIdentifier];
        if (![entries objectForKey:identifier])
            [entries setObject:plugIn forKey:identifier];
    }
    self.uniquePlugIns = entries;
}

- (void)resolveDependencies
{
    NSUInteger count = [self.uniquePlugIns count];
    NSMutableArray *resolved = [NSMutableArray arrayWithCapacity:count];
    for (NSString *identifier in self.uniquePlugIns)
    {
        [self resolveDependenciesForPlugIn:[self plugInForIdentifier:identifier]
                                  resolved:resolved
                                unresolved:[NSMutableSet setWithCapacity:count]];
    }
    self.resolvedPlugIns = resolved;
}

- (void)resolveDependenciesForPlugIn:(WOFPlugIn *)aPlugIn
                            resolved:(NSMutableArray *)resolved
                          unresolved:(NSMutableSet *)unresolved
{
    [unresolved addObject:aPlugIn];
    for (NSString *identifier in aPlugIn.dependencies)
    {
        WOFPlugIn *dependency = [self plugInForIdentifier:identifier];
        if (![resolved containsObject:dependency])
        {
            if ([unresolved containsObject:dependency])
                [NSException raise:@"WOFCircularDependencyException"
                            format:@"plug-ins %@ and %@ form part of a circular dependency",
                 aPlugIn, dependency];
            [self resolveDependenciesForPlugIn:dependency
                                      resolved:resolved
                                    unresolved:unresolved];
        }
    }
    [resolved addObject:aPlugIn];
    [unresolved removeObject:aPlugIn];
}

- (NSError *)loadAllPlugIns
{
    if (!self.resolvedPlugIns)
        [self resolveDependencies];

    for (WOFPlugIn *plugIn in self.resolvedPlugIns)
    {
        if (![plugIn isLoaded])
        {
            NSError *error;
            if (![plugIn loadAndReturnError:&error])
                return error;
        }

        if (![plugIn instance])
            [plugIn instantiate];
    }
    return nil;
}

- (WOFPlugIn *)plugInForIdentifier:(NSString *)anIdentifier
{
    return [self.uniquePlugIns objectForKey:anIdentifier];
}

@synthesize plugIns;
@synthesize uniquePlugIns;
@synthesize resolvedPlugIns;

@end
