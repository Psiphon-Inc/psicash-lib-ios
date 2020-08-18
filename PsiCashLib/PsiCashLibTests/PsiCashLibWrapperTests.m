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
#import "SecretTestValues.h"

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
    PSIPsiCashLibWrapper *lib;
    PSIError *initErr;
    PSIHTTPParams *lastParams;
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
    
    lib = [[PSIPsiCashLibWrapper alloc] init];
    
    initErr = [lib initializeWithUserAgent:@"Psiphon-PsiCash-iOS"
                          fileStoreRoot:tempDir.path
                 httpRequestFunc:^PSIHTTPResult * _Nonnull(PSIHTTPParams * _Nonnull params) {
        
        self->lastParams = params;
        
        if (self.httpRequestsDryRun == TRUE) {
            return [[PSIHTTPResult alloc] initWithCode:[PSIHTTPResult CRITICAL_ERROR]
                                               body:@"" date:@"" error:@"dry-run"];
        }
        
        NSMutableURLRequest *request =
        [NSMutableURLRequest requestWithURL:[params makeURL]
                                cachePolicy:NSURLRequestReloadIgnoringCacheData
                            timeoutInterval:60.0];
        
        [request setHTTPMethod:params.method];
        [request setAllHTTPHeaderFields:params.headers];

        PSIHTTPResult *__block result;
        
        NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            
            if (error != nil) {
                result = [[PSIHTTPResult alloc] initWithCode:PSIHTTPResult.RECOVERABLE_ERROR
                                                   body:@""
                                                   date:@""
                                                  error:[error description]];
            } else {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                NSString *dateHeader = nil;
                
                if (@available(iOS 13.0, *)) {
                    dateHeader = [httpResponse valueForHTTPHeaderField:@"Date"];
                } else {
                    // Fallback on earlier versions
                    dateHeader = [httpResponse allHeaderFields][@"Date"];
                }
                
                NSString *body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
             
                result = [[PSIHTTPResult alloc] initWithCode:(int)httpResponse.statusCode
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

#pragma mark - Helper functions

// Refreshes PsiCash state.
- (void)refreshState:(NSArray<NSString *> *_Nonnull)purchaseClasses {
    // Act
    PSIResult<PSIStatusWrapper *> *result = [lib refreshStateWithPurchaseClasses:purchaseClasses];
    
    // Assert
    XCTAssert(result != nil);
    XCTAssert(result.failure == nil);
    XCTAssert(result.success != nil);
    XCTAssert(result.success.status == PSIStatusSuccess);
}

- (void)rewardInTrillions:(int)trillions {
    for (int i = 0; i < trillions; i++) {
        if (i != 0) {
            [NSThread sleepForTimeInterval:1.0];
        }
        
        PSIError *err = [lib testRewardWithClass:@TEST_CREDIT_TRANSACTION_CLASS
                                   distinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER];
        XCTAssert(err == nil);
    }
}

#pragma mark - Tests

- (void)testInitialized {
    XCTAssert(initErr == nil);
    XCTAssert([lib initialized] == TRUE);
}

- (void)testReset {
    // Act
    PSIError *error = [lib resetWithFileStoreRoot:tempDir.path test:TRUE];
    
    // Assert
    XCTAssert(error == nil);
}

- (void)testSetRequestMetadataItem {
    // Arrange
    PSIError *err1 = [lib setRequestMetadataItem:@"metadata_key_1" withValue:@"metadata_value_1"];
    PSIError *err2 = [lib setRequestMetadataItem:@"metadata_key_2" withValue:@"metadata_value_2"];
    self.httpRequestsDryRun = TRUE;
    
    // Act
    PSIResult<PSIStatusWrapper *> *result = [lib refreshStateWithPurchaseClasses:@[]];
    
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
    XCTAssert([validTokenTypes containsObject:PSITokenType.earnerTokenType]);
    XCTAssert([validTokenTypes containsObject:PSITokenType.spenderTokenType]);
    XCTAssert([validTokenTypes containsObject:PSITokenType.indicatorTokenType]);
}

- (void)testIsAccount {
    // Arrange
    [self refreshState:@[]];
    NSArray<NSString *> *validTokenTypes = [lib validTokenTypes];

    // Act
    BOOL isAccount = [lib isAccount];
    
    // Assert
    if ([validTokenTypes containsObject: PSITokenType.accountTokenType]) {
        XCTAssert(isAccount == TRUE);
    } else {
        XCTAssert(isAccount == FALSE);
    }
}

- (void)testBalanceUnrefreshed {
    XCTAssert(lib.balance == 0);
}

- (void)testBalanceFirstRefresh {
    // Act
    [self refreshState:@[]];
    
    // Assert
    XCTAssert(lib.balance == 90000000000);
}

- (void)testBalanceAfterReward {
    // Arrange
    XCTAssert(lib.balance == 0);
    [self refreshState:@[]];
    
    // Act
    PSIError *err = [lib testRewardWithClass:@TEST_CREDIT_TRANSACTION_CLASS
                               distinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER];
    
    // Assert
    XCTAssert(err == nil);
    XCTAssert(lib.balance == 90000000000);
}

- (void)testGetPurchasePrices {
    // Act
    [self refreshState:@[@"speed-boost"]];
    NSArray<PSIPurchasePrice *> *array = [lib getPurchasePrices];
    
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
    PSIPurchase *optional = [lib nextExpiringPurchase];
    
    // Assert
    XCTAssert(optional == nil);
}

- (void)testRemovePurchasesWithoutPurchase {
    // Act
    PSIResult<NSArray<PSIPurchase *> *> *result = [lib removePurchasesWithTransactionID:@[]];
    
    // Assert
    XCTAssert(result.failure == nil);
    XCTAssert(result.success != nil);
    XCTAssert(result.success.count == 0);
}

- (void)testModifyLandingPage {
    // Act
    PSIResult<NSString *> * result = [lib modifyLandingPage:@"https://example.com/"];
    
    // Assert
    XCTAssert(result != nil);
    XCTAssert(result.failure == nil);
    
    // Base-64 version of string "{"debug":1,"dev":1,"metadata":{"user_agent":"Psiphon-PsiCash-iOS","v":1},"tokens":null,"v":1}"
    XCTAssert([result.success isEqualToString:@"https://example.com/#!psicash=eyJkZWJ1ZyI6MSwiZGV2IjoxLCJtZXRhZGF0YSI6eyJ1c2VyX2FnZW50IjoiUHNpcGhvbi1Qc2lDYXNoLWlPUyIsInYiOjF9LCJ0b2tlbnMiOm51bGwsInYiOjF9"]);
}

- (void)testGetBuyPsiURLWithoutRefresh {
    // Act
    PSIResult<NSString *> *result = [lib getBuyPsiURL];
    
    // Assert
    XCTAssert(result != nil);
    XCTAssert(result.failure != nil);
    XCTAssert(result.success == nil);
}

- (void)testGetBuyPsiURLWithRefresh {
    // Act
    [self refreshState:@[]];
    PSIResult<NSString *> *result = [lib getBuyPsiURL];
    
    // Assert
    XCTAssert(result != nil);
    XCTAssert(result.failure == nil);
    XCTAssert([result.success containsString:@"https://buy.psi.cash/#!psicash="]);
}

- (void)testGetRewardedActivityDataWithNoReward {
    // Act
    [self refreshState:@[]];
    PSIResult<NSString *> *result = [lib getRewardedActivityData];
    
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
    NSArray<PSIPurchasePrice *> *purchasePrices = [lib getPurchasePrices];
    XCTAssert(purchasePrices != nil);
    XCTAssert(purchasePrices.count > 0);
    PSIPurchasePrice *itemToBuy = purchasePrices[0];
    
    // Act
    PSIResult<PSINewExpiringPurchaseResponse *> *result =
    [lib newExpiringPurchaseWithTransactionClass:itemToBuy.transactionClass
                                   distinguisher:itemToBuy.distinguisher
                                   expectedPrice:itemToBuy.price];
    
    // Assert
    XCTAssert(result != nil);
    XCTAssert(result.failure == nil);
    XCTAssert(result.success != nil);
    XCTAssert(result.success.status == PSIStatusInsufficientBalance);
    XCTAssert(result.success.purchase == nil);
}

- (void)testPurchaseAndExpire {
    // Arrange
    XCTAssert(lib.balance == 0);
    [self refreshState:@[@"speed-boost"]];
    XCTAssert(lib.validTokenTypes.count >= 3);
    [self rewardInTrillions:3];
    
    // Get products.
    NSArray<PSIPurchasePrice*> *purchasePrices = [lib getPurchasePrices];
    XCTAssert(purchasePrices.count > 0);
    PSIPurchasePrice *purchasePrice = purchasePrices[0];
    
    // Makes purchase
    PSIResult<PSINewExpiringPurchaseResponse *> *result =
    [lib newExpiringPurchaseWithTransactionClass:purchasePrice.transactionClass
                                   distinguisher:purchasePrice.distinguisher
                                   expectedPrice:purchasePrice.price];
    
    XCTAssert(result != nil);
    XCTAssert(result.failure == nil);
    XCTAssert(result.success != nil);
    XCTAssert(result.success.status == PSIStatusSuccess);
    
    // Checks purchases
    NSArray<PSIPurchase *> *purchases = [lib getPurchases];
    XCTAssert(purchases != nil);
    XCTAssert(purchases.count == 1);
    XCTAssert(purchases[0].transactionID.length > 0);
    XCTAssert([purchases[0].transactionClass isEqualToString:@"speed-boost"]);
    XCTAssert([purchases[0].distinguisher isEqualToString:@"1hr"]);
    XCTAssert(purchases[0].iso8601ServerTimeExpiry.length > 0);
    XCTAssert(purchases[0].iso8601LocalTimeExpiry.length > 0);
    XCTAssert(purchases[0].authorization.ID.length > 0);
    XCTAssert([purchases[0].authorization.accessType isEqualToString:@"speed-boost-test"]);
    XCTAssert(purchases[0].authorization.iso8601Expires.length > 0);
    XCTAssert(purchases[0].authorization.encoded.length > 0);
    
    // Checks active purchase and ensure it's the same as `purchases[0]`.
    NSArray<PSIPurchase *> *activePurchases = [lib activePurchases];
    XCTAssert(activePurchases != nil);
    XCTAssert(activePurchases.count == 1);
    XCTAssert([activePurchases[0].transactionID isEqualToString:purchases[0].transactionID]);
    XCTAssert([activePurchases[0].authorization.ID isEqualToString:purchases[0].authorization.ID]);

    
    // Checks getAuthorizationsWithActiveOnly
    NSArray<PSIAuthorization *> *auths = [lib getAuthorizationsWithActiveOnly:TRUE];
    XCTAssert(auths != nil);
    XCTAssert(auths.count == 1);
    XCTAssert([auths[0].encoded isEqualToString:activePurchases[0].authorization.encoded]);
    
    // Checks getPurchasesByAuthorizationID
    NSArray<PSIPurchase *> *purchaseByAuth = [lib getPurchasesByAuthorizationID:@[auths[0].ID]];
    XCTAssert(purchaseByAuth != nil);
    XCTAssert(purchaseByAuth.count == 1);
    XCTAssert([purchaseByAuth[0].transactionID isEqualToString:purchases[0].transactionID]);
    XCTAssert([purchaseByAuth[0].authorization.encoded isEqualToString:auths[0].encoded]);
    
    // Checks next expiring purchase
    PSIPurchase *nextExpiringPurchase = [lib nextExpiringPurchase];
    XCTAssert(nextExpiringPurchase != nil);
    XCTAssert([nextExpiringPurchase.transactionID
               isEqualToString:activePurchases[0].transactionID]);
    
    // Artificially expires the purchase (even if the local clock hasn't indicated yet).
    PSIResult<NSArray<PSIPurchase *> *> *resultRemoving =
    [lib removePurchasesWithTransactionID:@[nextExpiringPurchase.transactionID]];
    
    XCTAssert(resultRemoving != nil);
    XCTAssert(resultRemoving.failure == nil);
    XCTAssert(resultRemoving.success != nil);
    XCTAssert(resultRemoving.success.count == 1);
    XCTAssert([resultRemoving.success[0].transactionID
               isEqualToString: nextExpiringPurchase.transactionID]);
    XCTAssert([lib nextExpiringPurchase] == nil); // The only purchase has been expired.
    
    // Checks expirePurchases
    PSIResult<NSArray<PSIPurchase *> *> *expireResult = [lib expirePurchases];
    XCTAssert(expireResult != nil);
    XCTAssert(expireResult.failure == nil);
    XCTAssert(expireResult.success != nil);
}

@end
