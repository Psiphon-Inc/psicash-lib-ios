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

@interface Pair<Value> : NSObject

@property (nonatomic) Value first;
@property (nonatomic) Value second;

@end



@interface HTTPParams : NSObject

@property (nonatomic, readonly) NSString *scheme;
@property (nonatomic, readonly) NSString *hostname;
@property (nonatomic, readonly) int port;
@property (nonatomic, readonly) NSString *method;
@property (nonatomic, readonly) NSString *path;
@property (nonatomic, readonly) NSDictionary<NSString *, NSString *> *headers;
@property (nonatomic, readonly) NSArray<Pair<NSString *> *> *query;

/**
 Creates complete URL including the query string.
 */
- (NSURL *)makeURL;

@end


@interface HTTPResult: NSObject

+ (int)CRITICAL_ERROR;
+ (int)RECOVERABLE_ERROR;

- (instancetype)initWithCode:(int)code
                        body:(NSString *)body
                        date:(NSString *)date
                       error:(NSString *)error;

@end


@interface Error : NSObject

@property (nonatomic, readonly) BOOL critical;
@property (nonatomic, readonly) BOOL hasValue;
@property (nonatomic, readonly) NSString *errorDescription;

@end


@interface Result<Value> : NSObject

@property (nonatomic, nullable) Value success;
@property (nonatomic, nullable) Error *failure;

@end


@interface Authorization : NSObject

@property (nonatomic, readonly) NSString *ID;
@property (nonatomic, readonly) NSString *accessType;
@property (nonatomic, readonly) NSString *iso8601Expires;
@property (nonatomic, readonly) NSString *encoded;

@end


@interface PurchasePrice : NSObject

@property (nonatomic, readonly) NSString *transactionClass;
@property (nonatomic, readonly) NSString *distinguisher;
@property (nonatomic, readonly) int64_t price;

@end


@interface Purchase : NSObject

@property (nonatomic, readonly) NSString *transactionID;
@property (nonatomic, readonly) NSString *transactionClass;
@property (nonatomic, readonly) NSString *distinguisher;
@property (nonatomic, readonly, nullable) NSString * iso8601ServerTimeExpiry;
@property (nonatomic, readonly, nullable) NSString * iso8601LocalTimeExpiry;
@property (nonatomic, readonly, nullable) Authorization * authorization;

@end


// Values should match psicash::Status enum class.
typedef NS_ENUM(NSInteger, Status) {
    StatusInvalid = -1, // Should never be used if well-behaved
    StatusSuccess = 0,
    StatusExistingTransaction,
    StatusInsufficientBalance,
    StatusTransactionAmountMismatch,
    StatusTransactionTypeNotFound,
    StatusInvalidTokens,
    StatusServerError
};

@interface StatusWrapper : NSObject

@property (nonatomic, readonly) Status status;

@end


@interface NewExpiringPurchaseResponse : NSObject

@property (nonatomic, readonly) Status status;
@property (nonatomic, readonly, nullable) Purchase *purchase;

@end


// Enumeration of possible token types.
@interface TokenType : NSObject

@property (class, nonatomic, readonly, nonnull) NSString *earnerTokenType;
@property (class, nonatomic, readonly, nonnull) NSString *spenderTokenType;
@property (class, nonatomic, readonly, nonnull) NSString *indicatorTokenType;
@property (class, nonatomic, readonly, nonnull) NSString *accountTokenType;

@end


@interface PsiCashLibWrapper : NSObject

- (Error *_Nullable)initializeWithUserAgent:(NSString *)userAgent
                           andFileStoreRoot:(NSString *)fileStoreRoot
                            httpRequestFunc:(HTTPResult * (^)(HTTPParams *))httpRequestFunc
                                       test:(BOOL)test WARN_UNUSED_RESULT;

- (Error *_Nullable)resetWithFileStoreRoot:(NSString *)fileStoreRoot test:(BOOL)test WARN_UNUSED_RESULT;

- (BOOL)initialized;

- (Error *_Nullable)setRequestMetadataItem:(NSString *)key withValue:(NSString *)value WARN_UNUSED_RESULT;

- (NSArray<NSString *> *)validTokenTypes;

- (BOOL)isAccount;

- (int64_t)balance;

- (NSArray<PurchasePrice *> *)getPurchasePrices;

- (NSArray<Purchase *> *)getPurchases;

- (NSArray<Purchase *> *)activePurchases;

- (NSArray<Authorization *> *)getAuthorizationsWithActiveOnly:(BOOL)activeOnly;

- (NSArray<Purchase *> *)getPurchasesByAuthorizationID:(NSArray<NSString *> *)authorizationIDs;

- (Purchase *_Nullable)nextExpiringPurchase;

- (Result<NSArray<Purchase *> *> *)expirePurchases WARN_UNUSED_RESULT;

- (Result<NSArray<Purchase *> *> *)removePurchases:(NSArray<NSString *> *)transactionIds WARN_UNUSED_RESULT;

- (Result<NSString *> *)modifyLandingPage:(NSString *)url;

- (Result<NSString *> *)getBuyPsiURL;

- (Result<NSString *> *)getRewardedActivityData;

- (NSString *)getDiagnosticInfo;

- (Result<StatusWrapper *> *)refreshStateWithPurchaseClasses:(NSArray<NSString *> *)purchaseClasses WARN_UNUSED_RESULT;

- (Result<NewExpiringPurchaseResponse *> *)
newExpiringPurchaseWithTransactionClass:(NSString *)transactionClass
distinguisher:(NSString *)distinguisher
expectedPrice:(int64_t)expectedPrice WARN_UNUSED_RESULT;

@end

NS_ASSUME_NONNULL_END
