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

#import "PsiCashLibWrapper.h"
#include "psicash.hpp"

// Note that on 32-bit platforms `BOOL` is a `signed char`, whereas in 64-bit it is a `bool`.

BOOL bool2ObjcBOOL(bool value) {
    return (value == true) ? YES : NO;
}

bool ObjcBOOL2bool(BOOL value) {
    return (value == YES) ? true : false;
}

#pragma mark - Pair

@implementation Pair

- (instancetype)initWith:(id)first :(id)second {
    self = [super init];
    if (self) {
        _first = first;
        _second = second;
    }
    return self;
}

@end

#pragma mark - Helper function

std::map<std::string, std::string> mapFromNSDictionary(NSDictionary<NSString *, NSString *> *_Nonnull dict) {
    std::map<std::string, std::string> map;
    
    for (NSString *key in dict) {
        std::string cppKey = [key UTF8String];
        std::string cppValue = [dict[key] UTF8String];
        map[cppKey] = cppValue;
    }
    
    return map;
}

std::vector<std::pair<std::string, std::string>> vecFromNSDictionary(NSDictionary<NSString *, NSString *> *_Nonnull dict) {
    std::vector<std::pair<std::string, std::string>> vec;
    
    for (NSString *key in dict) {
        std::string cppKey = [key UTF8String];
        std::string cppValue = [dict[key] UTF8String];
        vec.push_back(std::make_pair(cppKey, cppValue));
    }
    
    return vec;
}

NSArray<NSString *> *arrayFromVec(const std::vector<std::string>& vec) {
    
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:vec.size()];
    for (auto value : vec) {
        [array addObject: [NSString stringWithUTF8String:value.c_str()]];
    }
    return array;
}

std::vector<std::string> vecFromArray(NSArray<NSString *> *_Nonnull array) {
    std::vector<std::string> vec;
    for (NSString *value in array) {
        vec.push_back([value UTF8String]);
    }
    return vec;
}

NSDictionary<NSString *, NSString *> *_Nonnull
dictionaryFromMap(const std::map<std::string, std::string>& map) {

    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:map.size()];
    
    for (auto pair : map) {
        NSString *objcKey = [NSString stringWithUTF8String:pair.first.c_str()];
        NSString *objcValue = [NSString stringWithUTF8String:pair.second.c_str()];
        dict[objcKey] = objcValue;
    }
    
    return dict;
}

NSArray<Pair<NSString *> *> *_Nonnull
arrayFromVecPair(const std::vector<std::pair<std::string, std::string>>& vec) {
    NSMutableArray<Pair<NSString *> *> *array = [NSMutableArray arrayWithCapacity:vec.size()];
    
    for (auto pair : vec) {
        NSString *first = [NSString stringWithUTF8String:pair.first.c_str()];
        NSString *second = [NSString stringWithUTF8String:pair.second.c_str()];
        [array addObject:[[Pair alloc] initWith:first :second]];
    }
    
    return array;
}

#pragma mark - HTTPParams

@implementation HTTPParams

- (instancetype)initWithCppHTTPParams:(const psicash::HTTPParams&)params {
    self = [super init];
    if (self) {
        self->_scheme = [NSString stringWithUTF8String:params.scheme.c_str()];
        self->_hostname = [NSString stringWithUTF8String:params.hostname.c_str()];
        self->_port = params.port;
        self->_method = [NSString stringWithUTF8String:params.method.c_str()];
        self->_path = [NSString stringWithUTF8String:params.path.c_str()];
        self->_headers = dictionaryFromMap(params.headers);
        self->_query = arrayFromVecPair(params.query);
    }
    return self;
}

- (NSString *_Nonnull)makeQueryString {
    NSMutableString *string = [NSMutableString stringWithString:@""];
    for (int i = 0; i < self.query.count; i++) {
        [string appendFormat:@"%@=%@", self.query[i].first, self.query[i].second];
        if (i != self.query.count - 1) {
            [string appendString:@"&"];
        }
    }
    return string;
}

- (NSURL *)makeURL {
    NSString *urlString;
    NSString *queryString = [self makeQueryString];
    
    if ([queryString isEqualToString:@""]) {
        urlString = [NSString stringWithFormat:@"%@://%@%@", self.scheme, self.hostname, self.path];
    } else {
        urlString = [NSString stringWithFormat:@"%@://%@%@?%@", self.scheme, self.hostname,
                     self.path, [self makeQueryString]];
    }
    return [NSURL URLWithString:urlString];
}

@end

#pragma mark - HTTPResult

@implementation HTTPResult {
    psicash::HTTPResult result;
}

+ (int)CRITICAL_ERROR {
    return psicash::HTTPResult::CRITICAL_ERROR;
}

+ (int)RECOVERABLE_ERROR {
    return psicash::HTTPResult::RECOVERABLE_ERROR;
}

- (instancetype)initWithCode:(int)code
                        body:(NSString *)body
                        date:(NSString *)date
                       error:(NSString *)error {
    self = [super init];
    if (self) {
        result.code = code;
        result.body = [body UTF8String];
        result.date = [date UTF8String];
        result.error = [error UTF8String];
    }
    return self;
}

- (psicash::HTTPResult)cppHttpResult {
    return result;
}

@end

#pragma mark - Error

@implementation Error

+ (Error *_Nullable)createFrom:(const psicash::error::Error&)error {
    if (error.HasValue() == false) {
        return nil;
    } else {
        return [[Error alloc]
                initWithCritical:bool2ObjcBOOL(error.Critical())
                description:[NSString stringWithUTF8String:error.ToString().c_str()]];
    }
}

+ (Error *_Nonnull)createOrThrow:(const psicash::error::Error&)error {
    Error *_Nullable err = [Error createFrom:error];
    if (err == nil){
        @throw [NSException exceptionWithName:@"Unexpected value"
                                       reason:@"expected error to have a value"
                                     userInfo:nil];
    }
    return err;
}

- (instancetype)initWithCritical:(BOOL)critical description:(NSString *_Nonnull)description {
    self = [super init];
    if (self) {
        _critical = critical;
        _errorDescription = description;
    }
    return self;
}

- (NSString *)description {
    return _errorDescription;
}

@end

#pragma mark - Result

@implementation Result

- (instancetype)initWithSuccess:(id _Nonnull)success {
    self = [super init];
    if (self) {
        _success = success;
        _failure = nil;
    }
    return self;
}

- (instancetype)initWithFailure:(Error *_Nonnull)failure {
    self = [super init];
    if (self) {
        _success = nil;
        _failure = failure;
    }
    return self;
}

+ (Result *_Nonnull)success:(id _Nonnull)success {
    return [[Result alloc] initWithSuccess:success];
}

+ (Result *_Nonnull)failure:(Error *_Nonnull)failure {
    return [[Result alloc] initWithFailure:failure];
}

+ (Result<NSString *> *_Nonnull)fromStringResult:(const psicash::error::Result<std::string>&)result {
    if (result.has_value()) {
        return [Result success:[NSString stringWithUTF8String:result.value().c_str()]];
    } else {
        return [Result failure:[Error createOrThrow:result.error()]];
    }
}

@end

#pragma mark - Authorization

@implementation Authorization

- (instancetype)initWithAuth:(const psicash::Authorization&)auth {
    self = [super init];
    if (self) {
        _ID = [NSString stringWithUTF8String:auth.id.c_str()];
        _accessType = [NSString stringWithUTF8String:auth.access_type.c_str()];
        _iso8601Expires = [NSString stringWithUTF8String:auth.expires.ToISO8601().c_str()];
        _encoded = [NSString stringWithUTF8String:auth.encoded
                    .c_str()];
    }
    return self;
}

+ (Authorization *_Nonnull)createFrom:(const psicash::Authorization&)auth {
    return [[Authorization alloc] initWithAuth:auth];
}

@end

#pragma mark - PurchasePrice

@implementation PurchasePrice

- (instancetype)initWithPurchasePrice:(const psicash::PurchasePrice&)purchasePrice {
    self = [super init];
    if (self) {
        _transactionClass = [NSString stringWithUTF8String:purchasePrice.transaction_class.c_str()];
        _distinguisher = [NSString stringWithUTF8String:purchasePrice.distinguisher.c_str()];
        _price = purchasePrice.price;
    }
    return self;
}

+ (PurchasePrice *_Nonnull)createFrom:(const psicash::PurchasePrice&)purchasePrice {
    return [[PurchasePrice alloc] initWithPurchasePrice:purchasePrice];
}

@end

#pragma mark - Purchase

@implementation Purchase

- (instancetype)initWithPurchase:(const psicash::Purchase&)purchase {
    self = [super init];
    if (self) {
        _transactionID = [NSString stringWithUTF8String:purchase.id.c_str()];
        _transactionClass = [NSString stringWithUTF8String:purchase.transaction_class.c_str()];
        _distinguisher = [NSString stringWithUTF8String:purchase.distinguisher.c_str()];
        
        if (purchase.server_time_expiry.has_value()) {
            _iso8601ServerTimeExpiry = [NSString
                                        stringWithUTF8String:purchase.server_time_expiry.value().ToISO8601().c_str()];
        } else {
            _iso8601ServerTimeExpiry = nil;
        }
        
        if (purchase.local_time_expiry.has_value()) {
            _iso8601LocalTimeExpiry = [NSString
                                        stringWithUTF8String:purchase.local_time_expiry.value().ToISO8601().c_str()];
        } else {
            _iso8601LocalTimeExpiry = nil;
        }
        
        if (purchase.authorization.has_value()) {
            _authorization = [Authorization createFrom:purchase.authorization.value()];
        } else {
            _authorization = nil;
        }
    }
    return self;
}

+ (Purchase *_Nonnull)createFrom:(const psicash::Purchase&)purchase {
    return [[Purchase alloc] initWithPurchase:purchase];
}

+ (Purchase *_Nullable)fromOptional:(const nonstd::optional<psicash::Purchase>&)purchase {
    if (purchase.has_value()) {
        return [Purchase createFrom:purchase.value()];
    } else {
        return nil;
    }
}

+ (Result<NSArray<Purchase *> *> *_Nonnull)
fromResult:(const psicash::error::Result<psicash::Purchases>&)result {
    if (result.has_value()) {
        return [Result success:[Purchase fromArray:result.value()]];
    } else {
        return [Result failure:[Error createOrThrow:result.error()]];
    }
}

+ (NSArray<Purchase *> *_Nonnull)fromArray:(const psicash::Purchases&)purchases {
    NSMutableArray<Purchase *> *array = [NSMutableArray arrayWithCapacity:purchases.size()];
    for (auto value: purchases) {
        [array addObject:[Purchase createFrom:value]];
    }
    return array;
}

@end

#pragma mark - Status

Status statusFromStatus(const psicash::Status& status) {
    switch (status) {
        case psicash::Status::Invalid:
            return StatusInvalid;
        case psicash::Status::Success:
            return StatusSuccess;
        case psicash::Status::ExistingTransaction:
            return StatusExistingTransaction;
        case psicash::Status::InsufficientBalance:
            return StatusInsufficientBalance;
        case psicash::Status::TransactionAmountMismatch:
            return StatusTransactionAmountMismatch;
        case psicash::Status::TransactionTypeNotFound:
            return StatusTransactionTypeNotFound;
        case psicash::Status::InvalidTokens:
            return StatusInvalidTokens;
        case psicash::Status::ServerError:
            return StatusServerError;
    }
}

@implementation StatusWrapper

- (instancetype)initWithStatus:(const psicash::Status&)status {
    self = [super init];
    if (self) {
        _status = statusFromStatus(status);
    }
    return self;
}

+ (Result<StatusWrapper *> *_Nonnull)fromResult:(const psicash::error::Result<psicash::Status>&)result {
    if (result.has_value()) {
        return [Result success:[[StatusWrapper alloc] initWithStatus:result.value()]];
    } else {
        return [Result failure:[Error createOrThrow:result.error()]];
    }
}

@end

#pragma mark - NewExpiringPurchaseResponse

@implementation NewExpiringPurchaseResponse

- (instancetype)initWith:(const psicash::PsiCash::NewExpiringPurchaseResponse&)value {
    self = [super init];
    if (self) {
        _status = statusFromStatus(value.status);
        _purchase = [Purchase fromOptional:value.purchase];
    }
    return self;
}

+ (Result<NewExpiringPurchaseResponse *> *_Nonnull)
fromResult:(const psicash::error::Result<psicash::PsiCash::NewExpiringPurchaseResponse>&)result {
    
    if (result.has_value()) {
        return [Result success:[[NewExpiringPurchaseResponse alloc] initWith:result.value()]];
    } else {
        return [Result failure:[Error createOrThrow:result.error()]];
    }
}

@end

#pragma mark - Token types

@implementation TokenType

+ (NSString *)earnerTokenType {
    return [NSString stringWithUTF8String:psicash::kEarnerTokenType];
}

+ (NSString *)spenderTokenType {
    return [NSString stringWithUTF8String:psicash::kSpenderTokenType];
}

+ (NSString *)indicatorTokenType {
    return [NSString stringWithUTF8String:psicash::kIndicatorTokenType];
}
+ (NSString *)accountTokenType {
    return [NSString stringWithUTF8String:psicash::kAccountTokenType];
}

@end

#pragma mark - PsiCashLibWrapper

@implementation PsiCashLibWrapper {
    psicash::PsiCash *psiCash;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        psiCash = new psicash::PsiCash();
    }
    return self;
}

- (void)dealloc {
    delete psiCash;
}

- (Error *_Nullable)initializeWithUserAgent:(NSString *)userAgent
                           andFileStoreRoot:(NSString *)fileStoreRoot
                            httpRequestFunc:(HTTPResult * (^)(HTTPParams *))httpRequestFunc
                                       test:(BOOL)test {
    psicash::error::Error err = psiCash->Init([userAgent UTF8String],
                                              [fileStoreRoot UTF8String],
                                              [httpRequestFunc](const psicash::HTTPParams& cppParams) -> psicash::HTTPResult {
        return [httpRequestFunc([[HTTPParams alloc] initWithCppHTTPParams:cppParams])
                cppHttpResult];
    }, ObjcBOOL2bool(test));
    
    return [Error createFrom:err];
}

- (Error *_Nullable)resetWithFileStoreRoot:(NSString *)fileStoreRoot test:(BOOL)test {
    psicash::error::Error error = psiCash->Reset([fileStoreRoot UTF8String], ObjcBOOL2bool(test));
    return [Error createFrom:error];
}

- (BOOL)initialized {
    return bool2ObjcBOOL(psiCash->Initialized());
}

- (Error *_Nullable)setRequestMetadataItem:(NSString *)key
                                 withValue:(NSString *)value {
    psicash::error::Error err = psiCash->SetRequestMetadataItem([key UTF8String],
                                                                [value UTF8String]);
    return [Error createFrom:err];
}

- (NSArray<NSString *> *_Nonnull)validTokenTypes {
    return arrayFromVec(psiCash->ValidTokenTypes());
}

- (BOOL)isAccount {
    return bool2ObjcBOOL(psiCash->IsAccount());
}

- (int64_t)balance {
    return psiCash->Balance();
}

- (NSArray<PurchasePrice *> *)getPurchasePrices {
    psicash::PurchasePrices pp = psiCash->GetPurchasePrices();
    NSMutableArray<PurchasePrice *> *array = [NSMutableArray arrayWithCapacity:pp.size()];
    for (auto value : pp) {
        [array addObject:[PurchasePrice createFrom:value]];
    }
    return array;
}

- (NSArray<Purchase *> *)getPurchases {
    psicash::Purchases purchases = psiCash->GetPurchases();
    return [Purchase fromArray:purchases];
}

- (NSArray<Purchase *> *)activePurchases {
    psicash::Purchases activePurchases = psiCash->ActivePurchases();
    return [Purchase fromArray:activePurchases];
}

- (NSArray<Authorization *> *)getAuthorizationsWithActiveOnly:(BOOL)activeOnly {
    psicash::Authorizations auths = psiCash->GetAuthorizations(ObjcBOOL2bool(activeOnly));
    NSMutableArray<Authorization *> *array = [NSMutableArray arrayWithCapacity:auths.size()];
    for (auto value: auths) {
        [array addObject:[Authorization createFrom:value]];
    }
    return array;
}

- (NSArray<Purchase *> *)getPurchasesByAuthorizationID:(NSArray<NSString *> *)authorizationIDs {
    std::vector<std::string> authorization_ids = vecFromArray(authorizationIDs);
    psicash::Purchases purchases = psiCash->GetPurchasesByAuthorizationID(authorization_ids);
    return [Purchase fromArray:purchases];
}

- (Purchase *_Nullable)nextExpiringPurchase {
    nonstd::optional<psicash::Purchase> purchase = psiCash->NextExpiringPurchase();
    return [Purchase fromOptional:purchase];
}

- (Result<NSArray<Purchase *> *> *)expirePurchases {
    psicash::error::Result<psicash::Purchases> result = psiCash->ExpirePurchases();
    return [Purchase fromResult:result];
}

- (Result<NSArray<Purchase *> *> *)removePurchases:(NSArray<NSString *> *)transactionIds {
    std::vector<std::string> transaction_ids = vecFromArray(transactionIds);
    psicash::error::Result<psicash::Purchases> result = psiCash->RemovePurchases(transaction_ids);
    return [Purchase fromResult:result];
}

- (Result<NSString *> *)modifyLandingPage:(NSString *)url {
    psicash::error::Result<std::string> result = psiCash->ModifyLandingPage([url UTF8String]);
    return [Result fromStringResult:result];
}

- (Result<NSString *> *)getBuyPsiURL {
    psicash::error::Result<std::string> result = psiCash->GetBuyPsiURL();
    return [Result fromStringResult:result];
}

- (Result<NSString *> *)getRewardedActivityData {
    psicash::error::Result<std::string> result = psiCash->GetRewardedActivityData();
    return [Result fromStringResult:result];
}

- (NSString *)getDiagnosticInfo {
    nlohmann::json diagnostic = psiCash->GetDiagnosticInfo();
    auto dump = diagnostic.dump(-1, ' ', true);
    return [NSString stringWithUTF8String:dump.c_str()];
}

- (Result<StatusWrapper *> *)refreshStateWithPurchaseClasses:(NSArray<NSString *> *)purchaseClasses {
    std::vector<std::string> purchase_classes = vecFromArray(purchaseClasses);
    psicash::error::Result<psicash::Status> result = psiCash->RefreshState(purchase_classes);
    return [StatusWrapper fromResult:result];
}

- (Result<NewExpiringPurchaseResponse *> *)
newExpiringPurchaseWithTransactionClass:(NSString *)transactionClass
distinguisher:(NSString *)distinguisher
expectedPrice:(int64_t)expectedPrice {
    auto result = psiCash->NewExpiringPurchase([transactionClass UTF8String],
                                               [distinguisher UTF8String],
                                               expectedPrice);
    
    return [NewExpiringPurchaseResponse fromResult:result];
}

@end
