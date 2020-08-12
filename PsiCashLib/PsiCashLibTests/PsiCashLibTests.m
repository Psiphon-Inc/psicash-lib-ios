/*
 * Copyright (c) 2020, Psiphon Inc.
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import <XCTest/XCTest.h>
#import "PsiCashLibWrapper.h"

@interface PsiCashLibTests : XCTestCase

@end

@implementation PsiCashLibTests

- (void)testHTTPParams {
    HTTPParams *params = [[HTTPParams alloc] initWithScheme:@"scheme"
                                                   hostname:@"hostname"
                                                       port:80
                                                     method:@"GET"
                                                       path:@"/path"
                                                    headers:@{@"header1": @"header1value"}
                                                      query:@{@"query1": @"query1value"}];
    
    XCTAssertTrue([params.debugDescription isEqualToString:@"HTTPParams { scheme: scheme, hostname: hostname, port: 80 }"]);
}

@end
