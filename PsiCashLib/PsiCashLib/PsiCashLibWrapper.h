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

#import <Foundation/Foundation.h>

#ifndef WARN_UNUSED_RESULT
#define WARN_UNUSED_RESULT __attribute__((warn_unused_result))
#endif

NS_ASSUME_NONNULL_BEGIN

@interface PSIPair<Value> : NSObject

@property (nonatomic) Value first;
@property (nonatomic) Value second;

@end



@interface PSIHTTPParams : NSObject

@property (nonatomic, readonly) NSString *scheme;
@property (nonatomic, readonly) NSString *hostname;
@property (nonatomic, readonly) int port;
@property (nonatomic, readonly) NSString *method;
@property (nonatomic, readonly) NSString *path;
@property (nonatomic, readonly) NSDictionary<NSString *, NSString *> *headers;
@property (nonatomic, readonly) NSArray<PSIPair<NSString *> *> *query;

/**
 Creates complete URL including the query string.
 */
- (NSURL *)makeURL;

@end


@interface PSIHTTPResult: NSObject

+ (int)CRITICAL_ERROR;
+ (int)RECOVERABLE_ERROR;

- (instancetype)initWithCode:(int)code
                        body:(NSString *)body
                        date:(NSString *)date
                       error:(NSString *)error;

@end


@interface PSIError : NSObject

@property (nonatomic, readonly) BOOL critical;
@property (nonatomic, readonly) BOOL hasValue;
@property (nonatomic, readonly) NSString *errorDescription;

@end


@interface PSIResult<Value> : NSObject

@property (nonatomic, nullable) Value success;
@property (nonatomic, nullable) PSIError *failure;

@end


@interface PSIAuthorization : NSObject

@property (nonatomic, readonly) NSString *ID;
@property (nonatomic, readonly) NSString *accessType;
@property (nonatomic, readonly) NSString *iso8601Expires;
@property (nonatomic, readonly) NSString *encoded;

@end


@interface PSIPurchasePrice : NSObject

@property (nonatomic, readonly) NSString *transactionClass;
@property (nonatomic, readonly) NSString *distinguisher;
@property (nonatomic, readonly) int64_t price;

@end


@interface PSIPurchase : NSObject

@property (nonatomic, readonly) NSString *transactionID;
@property (nonatomic, readonly) NSString *transactionClass;
@property (nonatomic, readonly) NSString *distinguisher;
@property (nonatomic, readonly, nullable) NSString * iso8601ServerTimeExpiry;
@property (nonatomic, readonly, nullable) NSString * iso8601LocalTimeExpiry;
@property (nonatomic, readonly, nullable) PSIAuthorization * authorization;

@end


// Values should match psicash::Status enum class.
typedef NS_ENUM(NSInteger, PSIStatus) {
    PSIStatusInvalid = -1, // Should never be used if well-behaved
    PSIStatusSuccess = 0,
    PSIStatusExistingTransaction,
    PSIStatusInsufficientBalance,
    PSIStatusTransactionAmountMismatch,
    PSIStatusTransactionTypeNotFound,
    PSIStatusInvalidTokens,
    PSIStatusServerError
};

@interface PSIStatusWrapper : NSObject

@property (nonatomic, readonly) PSIStatus status;

@end


@interface PSINewExpiringPurchaseResponse : NSObject

@property (nonatomic, readonly) PSIStatus status;
@property (nonatomic, readonly, nullable) PSIPurchase *purchase;

@end


// Enumeration of possible token types.
@interface PSITokenType : NSObject

@property (class, nonatomic, readonly, nonnull) NSString *earnerTokenType;
@property (class, nonatomic, readonly, nonnull) NSString *spenderTokenType;
@property (class, nonatomic, readonly, nonnull) NSString *indicatorTokenType;
@property (class, nonatomic, readonly, nonnull) NSString *accountTokenType;

@end


@interface PSIPsiCashLibWrapper : NSObject

- (PSIError *_Nullable)initializeWithUserAgent:(NSString *)userAgent
                           andFileStoreRoot:(NSString *)fileStoreRoot
                            httpRequestFunc:(PSIHTTPResult * (^)(PSIHTTPParams *))httpRequestFunc
                                       test:(BOOL)test WARN_UNUSED_RESULT;

- (PSIError *_Nullable)resetWithFileStoreRoot:(NSString *)fileStoreRoot test:(BOOL)test WARN_UNUSED_RESULT;

- (BOOL)initialized;

- (PSIError *_Nullable)setRequestMetadataItem:(NSString *)key withValue:(NSString *)value WARN_UNUSED_RESULT;

- (NSArray<NSString *> *)validTokenTypes;

- (BOOL)isAccount;

- (int64_t)balance;

- (NSArray<PSIPurchasePrice *> *)getPurchasePrices;

- (NSArray<PSIPurchase *> *)getPurchases;

- (NSArray<PSIPurchase *> *)activePurchases;

- (NSArray<PSIAuthorization *> *)getAuthorizationsWithActiveOnly:(BOOL)activeOnly;

- (NSArray<PSIPurchase *> *)getPurchasesByAuthorizationID:(NSArray<NSString *> *)authorizationIDs;

- (PSIPurchase *_Nullable)nextExpiringPurchase;

- (PSIResult<NSArray<PSIPurchase *> *> *)expirePurchases WARN_UNUSED_RESULT;

- (PSIResult<NSArray<PSIPurchase *> *> *)removePurchases:(NSArray<NSString *> *)transactionIds WARN_UNUSED_RESULT;

- (PSIResult<NSString *> *)modifyLandingPage:(NSString *)url;

- (PSIResult<NSString *> *)getBuyPsiURL;

- (PSIResult<NSString *> *)getRewardedActivityData;

- (NSString *)getDiagnosticInfo;

- (PSIResult<PSIStatusWrapper *> *)refreshStateWithPurchaseClasses:(NSArray<NSString *> *)purchaseClasses WARN_UNUSED_RESULT;

- (PSIResult<PSINewExpiringPurchaseResponse *> *)
newExpiringPurchaseWithTransactionClass:(NSString *)transactionClass
distinguisher:(NSString *)distinguisher
expectedPrice:(int64_t)expectedPrice WARN_UNUSED_RESULT;

@end

NS_ASSUME_NONNULL_END
