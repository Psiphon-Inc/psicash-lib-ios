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

NSErrorDomain const TestErrorDomain = @"PsiCashLibTest";

typedef NS_ENUM(NSInteger, TestError) {
    TestErrorSetupTempDirCreationFailed = 1,
    TestErrorTeardownTempDirDeletionFailed
};

@interface PsiCashLibWrapperTests : XCTestCase

// If true, network requests are not completed.
@property (atomic) BOOL httpRequestsDryRun;

@end

@implementation PsiCashLibWrapperTests {
    dispatch_semaphore_t sema;
    PsiCashLibWrapper *lib;
    Error *initErr;
    HTTPParams *lastParams;
    NSURL *tempDir;
}

/**
 Creates temporary directory with path `<NSTemporaryDirectory()>/PsiCashLibTests`.
 If that directory already exists, deletes the directory and all of its contents.
 */
+ (NSURL *_Nullable)createTempDir:(NSError *_Nullable *_Nonnull)error {
    NSURL *globalTemp = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:TRUE];
    NSURL *temp = [globalTemp URLByAppendingPathComponent:@"PsiCashLibTests" isDirectory:TRUE];
    
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:temp.path];
    if (exists) {
        [[NSFileManager defaultManager] removeItemAtURL:temp error:error];
        if (*error != nil) {
            return nil;
        }
    }
    
    BOOL created = [[NSFileManager defaultManager] createDirectoryAtURL:temp
                                            withIntermediateDirectories:FALSE
                                                             attributes:nil
                                                                  error:error];
    
    if (*error != nil) {
        return nil;
    }
    
    if (created == FALSE) {
        *error = [NSError errorWithDomain:TestErrorDomain
                                     code:TestErrorSetupTempDirCreationFailed userInfo:nil];
        return nil;
    }
    
    return temp;
}

- (BOOL)setUpWithError:(NSError *__autoreleasing  _Nullable *)error {
    
    self.httpRequestsDryRun = FALSE;
    
    // Creates temp directory.
    tempDir = [PsiCashLibWrapperTests createTempDir:error];
    if (*error != nil) {
        return FALSE;
    }
    assert(tempDir != nil);
    
    sema = dispatch_semaphore_create(0);
    
    lib = [[PsiCashLibWrapper alloc] init];
    
    initErr = [lib initializeWithUserAgent:@"Psiphon-PsiCash-iOS"
                          andFileStoreRoot:tempDir.path
                 httpRequestFunc:^HTTPResult * _Nonnull(HTTPParams * _Nonnull params) {
        
        self->lastParams = params;
        
        if (self.httpRequestsDryRun == TRUE) {
            return [[HTTPResult alloc] initWithCode:[HTTPResult CRITICAL_ERROR]
                                               body:@"" date:@"" error:@"dry-run"];
        }
        
        NSMutableURLRequest *request =
        [NSMutableURLRequest requestWithURL:[params makeURL]
                                cachePolicy:NSURLRequestReloadIgnoringCacheData
                            timeoutInterval:60.0];
        
        [request setHTTPMethod:params.method];
        [request setAllHTTPHeaderFields:params.headers];

        HTTPResult *__block result;
        
        NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            
            if (error != nil) {
                result = [[HTTPResult alloc] initWithCode:HTTPResult.RECOVERABLE_ERROR
                                                   body:@""
                                                   date:@""
                                                  error:[error description]];
            } else {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                NSString *dateHeader = [httpResponse valueForHTTPHeaderField:@"Date"];
                
                NSString *body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
             
                result = [[HTTPResult alloc] initWithCode:(int)httpResponse.statusCode
                                                       body:body
                                                       date:dateHeader
                                                      error:@""];
            }
            
            dispatch_semaphore_signal(self->sema);
        }];
        
        [task resume];
        
        // Blocks until HTTP request finishes.
        dispatch_semaphore_wait(self->sema, DISPATCH_TIME_FOREVER);
        
        return result;
        
    } test:TRUE];
    
    return TRUE;
}

// Refreshes PsiCash state.
- (void)refreshState:(NSArray<NSString *> *_Nonnull)purchaseClasses {
    // Act
    Result<StatusWrapper *> *result = [lib refreshStateWithPurchaseClasses:purchaseClasses];
    
    // Assert
    XCTAssert(result != nil);
    XCTAssert(result.failure == nil);
    XCTAssert(result.success != nil);
    XCTAssert(result.success.status == StatusSuccess);
}

- (BOOL)tearDownWithError:(NSError *__autoreleasing  _Nullable *)error {
    BOOL success = [[NSFileManager defaultManager] removeItemAtURL:tempDir error:error];
    if (*error != nil) {
        return FALSE;
    }
    if (success == FALSE) {
        *error = [NSError errorWithDomain:TestErrorDomain
                                     code:TestErrorTeardownTempDirDeletionFailed userInfo:nil];
        return FALSE;
    }
    
    sema = nil;
    lib = nil;
    initErr = nil;
    lastParams = nil;
    return TRUE;
}

- (void)testInitialized {
    XCTAssert(initErr == nil);
    XCTAssert([lib initialized] == TRUE);
}

- (void)testReset {
    // Act
    Error *error = [lib resetWithFileStoreRoot:tempDir.path test:TRUE];
    
    // Assert
    XCTAssert(error == nil);
}

- (void)testSetRequestMetadataItem {
    // Arrange
    Error *err1 = [lib setRequestMetadataItem:@"metadata_key_1" withValue:@"metadata_value_1"];
    Error *err2 = [lib setRequestMetadataItem:@"metadata_key_2" withValue:@"metadata_value_2"];
    self.httpRequestsDryRun = TRUE;
    
    // Act
    Result<StatusWrapper *> *result = [lib refreshStateWithPurchaseClasses:@[]];
    
    // Assert
    XCTAssert(err1 == nil);
    XCTAssert(err2 == nil);
    XCTAssert(result.success == nil);
    XCTAssert(result.failure != nil);
    XCTAssertTrue([lastParams.headers[@"X-PsiCash-Metadata"] isEqualToString:@"{\"attempt\":1,\"metadata_key_1\":\"metadata_value_1\",\"metadata_key_2\":\"metadata_value_2\",\"user_agent\":\"Psiphon-PsiCash-iOS\",\"v\":1}"]);
}

- (void)testValidTokenTypesBeforeRefresh {
    // Act
    NSArray<NSString *> *validTokenTypes = [lib validTokenTypes];
    
    // Assert
    XCTAssert(validTokenTypes != nil);
    XCTAssert(validTokenTypes.count == 0);
}

- (void)testValidTokenTypes {
    // Act
    [self refreshState:@[]];
    NSArray<NSString *> *validTokenTypes = [lib validTokenTypes];
    
    // Assert
    XCTAssert(validTokenTypes != nil);
    XCTAssert([validTokenTypes containsObject:TokenType.earnerTokenType]);
    XCTAssert([validTokenTypes containsObject:TokenType.spenderTokenType]);
    XCTAssert([validTokenTypes containsObject:TokenType.indicatorTokenType]);
}

- (void)testIsAccount {
    // Arrange
    [self refreshState:@[]];
    NSArray<NSString *> *validTokenTypes = [lib validTokenTypes];

    // Act
    BOOL isAccount = [lib isAccount];
    
    // Assert
    if ([validTokenTypes containsObject: TokenType.accountTokenType]) {
        XCTAssert(isAccount == TRUE);
    } else {
        XCTAssert(isAccount == FALSE);
    }
}

- (void)testBalance {
    XCTAssert(lib.balance == 0);
    
    [self refreshState:@[]];
    
    XCTAssert(lib.balance == 90000000000);
}

- (void)testGetPurchasePrices {
    // Act
    [self refreshState:@[@"speed-boost"]];
    NSArray<PurchasePrice *> *array = [lib getPurchasePrices];
    
    // Assert
    XCTAssert(array != nil);
    XCTAssert(array.count > 0);
    XCTAssert([array[0].transactionClass isEqualToString:@"speed-boost"]);
}

- (void)testGetPurchasesWithoutPurchase {
    // Act
    NSArray *array = [lib getPurchases];
    
    // Assert
    XCTAssert(array != nil);
    XCTAssert(array.count == 0);
}

- (void)testActivePurchasesWithoutPurchase {
    // Act
    NSArray *array = [lib activePurchases];
    
    // Assert
    XCTAssert(array != nil);
    XCTAssert(array.count == 0);
}

- (void)testGetAuthorizationsWithoutPurchase {
    // Act
    NSArray *array = [lib getAuthorizationsWithActiveOnly:FALSE];
    
    // Assert
    XCTAssert(array != nil);
    XCTAssert(array.count == 0);
}

- (void)testGetPurchasesByAuthorizationIdWithoutPurchase {
    // Act
    NSArray *purchases = [lib getPurchasesByAuthorizationID:@[]];
    
    // Assert
    XCTAssert(purchases != nil);
    XCTAssert(purchases.count == 0);
}

- (void)testNextExpiringPurchaseWithoutPurchase {
    // Act
    Purchase *optional = [lib nextExpiringPurchase];
    
    // Assert
    XCTAssert(optional == nil);
}

- (void)testRemovePurchasesWithoutPurchase {
    // Act
    Result<NSArray<Purchase *> *> *result = [lib removePurchases:@[]];
    
    // Assert
    XCTAssert(result.failure == nil);
    XCTAssert(result.success != nil);
    XCTAssert(result.success.count == 0);
}

- (void)testModifyLandingPage {
    // Act
    Result<NSString *> * result = [lib modifyLandingPage:@"https://example.com/"];
    
    // Assert
    XCTAssert(result != nil);
    XCTAssert(result.failure == nil);
    
    // Base-64 version of string "{"debug":1,"dev":1,"metadata":{"user_agent":"Psiphon-PsiCash-iOS","v":1},"tokens":null,"v":1}"
    XCTAssert([result.success isEqualToString:@"https://example.com/#!psicash=eyJkZWJ1ZyI6MSwiZGV2IjoxLCJtZXRhZGF0YSI6eyJ1c2VyX2FnZW50IjoiUHNpcGhvbi1Qc2lDYXNoLWlPUyIsInYiOjF9LCJ0b2tlbnMiOm51bGwsInYiOjF9"]);
}

- (void)testGetBuyPsiURLWithoutRefresh {
    // Act
    Result<NSString *> *result = [lib getBuyPsiURL];
    
    // Assert
    XCTAssert(result != nil);
    XCTAssert(result.failure != nil);
    XCTAssert(result.success == nil);
}

- (void)testGetBuyPsiURLWithRefresh {
    // Act
    [self refreshState:@[]];
    Result<NSString *> *result = [lib getBuyPsiURL];
    
    // Assert
    XCTAssert(result != nil);
    XCTAssert(result.failure == nil);
    XCTAssert([result.success containsString:@"https://buy.psi.cash/#!psicash="]);
}

- (void)testGetRewardedActivityDataWithNoReward {
    // Act
    [self refreshState:@[]];
    Result<NSString *> *result = [lib getRewardedActivityData];
    
    // Assert
    XCTAssert(result != nil);
    XCTAssert(result.failure == nil);
    XCTAssert(result.success != nil);
    XCTAssert(result.success.length > 0);
}

- (void)testDiagnosticInfo {
    // Act
    NSString *info = [lib getDiagnosticInfo];
    
    // Assert
    XCTAssert(info != nil);
    XCTAssert([info isEqualToString:@"{\"balance\":0,\"isAccount\":false,\"purchasePrices\":[],\"purchases\":[],\"serverTimeDiff\":0,\"test\":true,\"validTokenTypes\":[]}"]);
}

- (void)testExpiringPurchaseWithInsufficientBalance {
    // Arrange
    [self refreshState:@[@"speed-boost"]];
    NSArray<PurchasePrice *> *purchasePrices = [lib getPurchasePrices];
    PurchasePrice *itemToBuy = purchasePrices[0];
    
    // Act
    Result<NewExpiringPurchaseResponse *> *result =
    [lib newExpiringPurchaseWithTransactionClass:itemToBuy.transactionClass
                                   distinguisher:itemToBuy.distinguisher
                                   expectedPrice:itemToBuy.price];
    
    // Assert
    XCTAssert(result != nil);
    XCTAssert(result.failure == nil);
    XCTAssert(result.success != nil);
    XCTAssert(result.success.status == StatusInsufficientBalance);
    XCTAssert(result.success.purchase == nil);
}

@end
