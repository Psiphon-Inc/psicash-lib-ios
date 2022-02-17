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
#import <PsiCashLib/PsiCashLib.h>
#import "SecretTestValues.h"

NSString *const PsiCashUserAgent = @"Psiphon-PsiCash-iOS";
NSString *const SpeedBoostPurchaseClass = @"speed-boost";
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
    PSIHttpRequest *lastHttpRequest;
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
    
    initErr = [lib initializeWithUserAgent:PsiCashUserAgent
                          fileStoreRoot:tempDir.path
                 httpRequestFunc:^PSIHttpResult * _Nonnull(PSIHttpRequest * _Nonnull value) {
        
        self->lastHttpRequest = value;
        
        if (self.httpRequestsDryRun == TRUE) {
            return [[PSIHttpResult alloc] initWithCode:[PSIHttpResult CRITICAL_ERROR]
                                               headers:@{} body:@"" error:@"dry-run"];
        }
        
        NSMutableURLRequest *request =
        [NSMutableURLRequest requestWithURL:[value makeURL]
                                cachePolicy:NSURLRequestReloadIgnoringCacheData
                            timeoutInterval:60.0];
        
        [request setHTTPMethod:value.method];
        [request setAllHTTPHeaderFields:value.headers];
        [request setHTTPBody:[value.body dataUsingEncoding:NSUTF8StringEncoding]];

        PSIHttpResult *__block result;
        
        NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            
            if (error != nil) {
                result = [[PSIHttpResult alloc] initWithCode:PSIHttpResult.RECOVERABLE_ERROR
                                                     headers: @{}
                                                        body:@""
                                                       error:[error description]];
            } else {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                
                NSMutableDictionary<NSString *, NSArray<NSString *> *> *headers = [NSMutableDictionary dictionary];
                
                NSDictionary *allHeaders = [httpResponse allHeaderFields];

                for (NSString *key in allHeaders) {
                    NSString *value = (NSString *)allHeaders[key];
                    headers[key] = @[value];
                }
                
                NSString *body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
             
                result = [[PSIHttpResult alloc] initWithCode:(int)httpResponse.statusCode
                                                     headers: headers
                                                        body:body
                                                       error:@""];
            }
            
            dispatch_semaphore_signal(self->sema);
        }];
        
        [task resume];
        
        // Blocks until HTTP request finishes.
        dispatch_semaphore_wait(self->sema, DISPATCH_TIME_FOREVER);
        
        return result;
        
    } forceReset:FALSE test:TRUE];
    
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
    lastHttpRequest = nil;
    return TRUE;
}

#pragma mark - Helper functions

// Refreshes PsiCash state.
- (void)refreshState:(NSArray<NSString *> *_Nonnull)purchaseClasses localOnly:(BOOL)localOnly {
    // Act
    PSIResult<PSIRefreshStateResponse *> *result = [lib refreshStateWithPurchaseClasses:purchaseClasses
                                                                              localOnly:localOnly];
    
    // Assert
    XCTAssert(result != nil);
    XCTAssert(result.failure == nil);
    XCTAssert(result.success != nil);
    XCTAssert(result.success.status == PSIStatusSuccess);
    XCTAssert([lib hasTokens] == TRUE);
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

- (void)testForceReset {
    // Arrange
    [self refreshState:@[SpeedBoostPurchaseClass] localOnly:FALSE];
    NSError *err;
    NSArray<NSString *> *contents = [NSFileManager.defaultManager
                                     contentsOfDirectoryAtPath:tempDir.path
                                     error:&err];
    
    XCTAssert(err == nil);
    XCTAssert(contents.count == 1);
    XCTAssertTrue([contents isEqualToArray:@[@"psicashdatastore.dev"]]);
    XCTAssert([lib hasTokens] == TRUE);
    
    // Act
    lib = nil;
    lib = [[PSIPsiCashLibWrapper alloc] init];
    initErr = [lib initializeWithUserAgent:@"Psiphon-PsiCash"
                             fileStoreRoot:tempDir.path
                           httpRequestFunc:nil
                                forceReset:TRUE
                                      test:TRUE];
    
    // Assert
    XCTAssert(initErr == nil);
    XCTAssert([lib initialized] == TRUE);
    XCTAssert([lib hasTokens] == FALSE); // Indicates that the datastore has been
                                                 // reset and there are no tokens.
}

- (void)testMigrateToken {
    // Arrange
    NSDictionary<NSString *, NSString *> *tokens = @{
        @"earner":
            @"d31b70ac051a28a2f758e5ec12fa5cbdf7a13bf9a00beb293fdec5bc249b36f9",
        @"indicator":
            @"9330841355ebb06457a42eebcf4ae99caca402bc9e0edb531ad24576ee4b8b2c",
        @"spender":
            @"ffb3588957b3581705da824826038a6c578d79cbca1c6debd44657a1d0392562"
    };
    XCTAssert([lib hasTokens] == FALSE);
    XCTAssert([lib isAccount] == FALSE);
    
    // Act
    [lib migrateTrackerTokens:tokens];
    
    // Assert
    XCTAssert([lib hasTokens] == TRUE);
    XCTAssert([lib isAccount] == FALSE);
}

- (void)testSetRequestMetadataItem {
    // Arrange
    NSDictionary *items = @{ @"metadata_key_1": @"metadata_value_1",
                             @"metadata_key_2": @"metadata_value_2" };
    
    PSIError *err = [lib setRequestMetadataItems:items];
    self.httpRequestsDryRun = TRUE;
    
    // Act
    PSIResult<PSIRefreshStateResponse *> *result = [lib refreshStateWithPurchaseClasses:@[] localOnly:FALSE];
    
    // Assert
    XCTAssert(err == nil);
    XCTAssert(result.success == nil);
    XCTAssert(result.failure != nil);
    XCTAssertTrue([lastHttpRequest.headers[@"X-PsiCash-Metadata"] isEqualToString:@"{\"attempt\":1,\"metadata_key_1\":\"metadata_value_1\",\"metadata_key_2\":\"metadata_value_2\",\"user_agent\":\"Psiphon-PsiCash-iOS\",\"v\":1}"]);
}

- (void)testSetLocale {
    
    // Act
    PSIError *err = [lib setLocale:@"zh-Hant_CA"];
    
    // Assert
    XCTAssert(err == nil);
    
}

- (void)testHasTokensAndIsAccountBeforeRefresh {
    // Assert
    XCTAssert([lib hasTokens] == FALSE);
    XCTAssert([lib isAccount] == FALSE);
}

- (void)testHasTokensAndIsAccountAfterRefresh {
    // Act
    [self refreshState:@[] localOnly:FALSE];

    // Assert
    XCTAssert([lib hasTokens] == TRUE);
    XCTAssert([lib isAccount] == FALSE);
}

- (void)testBalanceUnrefreshed {
    XCTAssert(lib.balance == 0);
}

- (void)testBalanceFirstRefresh {
    // Act
    [self refreshState:@[] localOnly:FALSE];
    
    // Assert
    XCTAssert(lib.balance == 90000000000);
}

- (void)testBalanceAfterReward {
    // Arrange
    XCTAssert(lib.balance == 0);
    [self refreshState:@[] localOnly:FALSE];
    
    // Act
    PSIError *err = [lib testRewardWithClass:@TEST_CREDIT_TRANSACTION_CLASS
                               distinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER];
    
    // Assert
    XCTAssert(err == nil);
    XCTAssert(lib.balance == 90000000000);
}

- (void)testGetPurchasePrices {
    // Act
    [self refreshState:@[SpeedBoostPurchaseClass] localOnly:FALSE];
    NSArray<PSIPurchasePrice *> *array = [lib getPurchasePrices];
    
    // Assert
    XCTAssert(array != nil);
    XCTAssert(array.count > 0);
    XCTAssert([array[0].transactionClass isEqualToString:SpeedBoostPurchaseClass]);
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
    
    XCTAssert([result.success hasPrefix:@"https://example.com/?psicash="]);
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
    [self refreshState:@[] localOnly:FALSE];
    PSIResult<NSString *> *result = [lib getBuyPsiURL];
    
    // Assert
    XCTAssert(result != nil);
    XCTAssert(result.failure == nil);
}

- (void)testGetUserSiteURL {
    // Act
    NSString *url1 = [lib getUserSiteURL:PSIUserSiteURLTypeAccountSignup webview:TRUE];
    NSString *url2 = [lib getUserSiteURL:PSIUserSiteURLTypeAccountManagement webview:TRUE];
    NSString *url3 = [lib getUserSiteURL:PSIUserSiteURLTypeForgotAccount webview:TRUE];

    // Assert
    XCTAssert(url1 != nil);
    XCTAssert([url1 length] > 0);
    XCTAssert(url2 != nil);
    XCTAssert([url2 length] > 0);
    XCTAssert(url3 != nil);
    XCTAssert([url3 length] > 0);
}

- (void)testGetRewardedActivityDataWithNoReward {
    // Act
    [self refreshState:@[] localOnly:FALSE];
    PSIResult<NSString *> *result = [lib getRewardedActivityData];
    
    // Assert
    XCTAssert(result != nil);
    XCTAssert(result.failure == nil);
    XCTAssert(result.success != nil);
    XCTAssert(result.success.length > 0);
}

- (void)testDiagnosticInfo {
    // Act
    NSString *info = [lib getDiagnosticInfo:FALSE];
    
    // Assert
    XCTAssert(info != nil);
    XCTAssert([info isEqualToString:@"{\"balance\":0,\"hasInstanceID\":true,\"isAccount\":false,\"isLoggedOutAccount\":false,\"purchasePrices\":[],\"purchases\":[],\"serverTimeDiff\":0,\"test\":true,\"validTokenTypes\":[]}"]);
}

- (void)testExpiringPurchaseWithInsufficientBalance {
    // Arrange
    [self refreshState:@[SpeedBoostPurchaseClass] localOnly:FALSE];
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
    [self refreshState:@[SpeedBoostPurchaseClass] localOnly:FALSE];
    XCTAssert([lib hasTokens] == TRUE);
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
    XCTAssert([purchases[0].transactionClass isEqualToString:SpeedBoostPurchaseClass]);
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

#pragma mark - Account login tests

- (void)helperLoginWithExpectedLastTrackerMergeValue:(NSNumber *_Nullable)expected {
    // Act
    PSIResult<PSIAccountLoginResponse *> *result =
    [lib accountLoginWithUsername:@TEST_ACCOUNT_ONE_USERNAME
                      andPassword:@TEST_ACCOUNT_ONE_PASSWORD];
    
    // Assert
    XCTAssert(result != nil);
    XCTAssert(result.failure == nil);
    XCTAssert(result.success != nil);
    XCTAssert(result.success.status == PSIStatusSuccess);

    if (expected != nil) {
        XCTAssert(result.success.lastTrackerMerge != nil);
        XCTAssert([result.success.lastTrackerMerge boolValue] == [expected boolValue]);
    } else {
        XCTAssertNil(result.success.lastTrackerMerge);
    }
}

// Tests logging in without a tracker already in place (no state refresh).
- (void)testLoginWithoutTracker {
    // Act, Assert
    [self helperLoginWithExpectedLastTrackerMergeValue:nil];
    XCTAssert([lib hasTokens] == TRUE);
    XCTAssert([lib isAccount] == TRUE);
}

// Tests logging in with a tracker already in place.
- (void)testLoginWithTracker {
    // Arrange
    [self refreshState:@[SpeedBoostPurchaseClass] localOnly:FALSE]; // get tracker tokens
    XCTAssert([lib isAccount] == FALSE);
    
    // Act
    [self helperLoginWithExpectedLastTrackerMergeValue:@(FALSE)];
    
    // Assert
    XCTAssert([lib hasTokens] == TRUE);
    XCTAssert([lib isAccount] == TRUE);
}

- (void)testAccountLogout {
    // Arrange
    [self helperLoginWithExpectedLastTrackerMergeValue:nil];
    
    // Act
    [lib accountLogout];

    // Assert
    XCTAssert([lib hasTokens] == FALSE);
    XCTAssert([lib isAccount] == TRUE);
}

- (void)testResetUserWithTrackerOnly {
    // Arrange
    [self refreshState:@[SpeedBoostPurchaseClass] localOnly:FALSE]; // get tracker tokens
    
    // Act
    [lib resetUser];
    
    // Assert
    XCTAssert([lib hasTokens] == FALSE);
}

- (void)testResetUserWithAccount {
    // Arrange
    [self helperLoginWithExpectedLastTrackerMergeValue:nil];
    
    XCTAssert([lib isAccount] == TRUE);
    
    // Act
    [lib resetUser];
    
    // Assert
    XCTAssert([lib isAccount] == FALSE);
    XCTAssert([lib hasTokens] == FALSE);
}

@end
