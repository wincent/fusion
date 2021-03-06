// WOFPlugInManager.h
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

#import <Foundation/Foundation.h>

@class WOFPlugIn;

@interface WOFPlugInManager : NSObject {

}

#pragma mark Class methods

//! @return The shared instance of the WOFPlugInManager class.
+ (WOFPlugInManager *)sharedManager;

#pragma mark Instance methods

//! Loads and instantiates all plug-ins which are eligible for loading (that is,
//! all plug-ins whose dependencies are available)
//!
//! "Instantiation" here means instantiating an instance of the plug-in's
//! principal class and sending it an "activate" message, if it responds to it.
//!
//! @return An NSError object containing information about the first failure
//!         encountered during loading
//! @return nil if no errors occurred
//! @note   In the event of an error this method aborts further processing and
//!         returns the associated NSError object immediately
- (NSError *)loadAllPlugIns;

//! @return The first found instance of a WOFPlugIn which matches the
//!         identifier.
- (WOFPlugIn *)plugInForIdentifier:(NSString *)anIdentifier;

#pragma mark Properties

//! An array of WOFPlugIn instances corresponding to the bundles found in the
//! standard search locations.
@property(readonly,copy) NSArray *plugIns;

@end
