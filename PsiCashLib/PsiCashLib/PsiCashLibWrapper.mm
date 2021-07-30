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
#include "PsiCashTest.hpp"

// Note that on 32-bit platforms `BOOL` is a `signed char`, whereas in 64-bit it is a `bool`.

BOOL bool2ObjcBOOL(bool value) {
    return (value == true) ? YES : NO;
}

bool ObjcBOOL2bool(BOOL value) {
    return (value == YES) ? true : false;
}

#pragma mark - Pair

@implementation PSIPair

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

std::map<std::string, std::string>
dictToCppMap(NSDictionary<NSString *, NSString *> *_Nullable dict) {
    std::map<std::string, std::string> map;
    
    for (NSString *key in dict) {
        std::string cppKey = [key UTF8String];
        std::string cppValue = [dict[key] UTF8String];
        map[cppKey] = cppValue;
    }
    
    return map;
}

NSArray<NSString *> *cppVecOfStringsToArrayOfStrings(const std::vector<std::string>& vec) {
    
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:vec.size()];
    for (auto value : vec) {
        [array addObject: [NSString stringWithUTF8String:value.c_str()]];
    }
    return array;
}

std::vector<std::string> arrayOfStringsToCppVecOfStrings(NSArray<NSString *> *_Nonnull array) {
    std::vector<std::string> vec;
    for (NSString *value in array) {
        vec.push_back([value UTF8String]);
    }
    return vec;
}

NSDictionary<NSString *, NSString *> *_Nonnull
cppMapToDict(const std::map<std::string, std::string>& map) {
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:map.size()];
    
    for (auto pair : map) {
        NSString *objcKey = [NSString stringWithUTF8String:pair.first.c_str()];
        NSString *objcValue = [NSString stringWithUTF8String:pair.second.c_str()];
        dict[objcKey] = objcValue;
    }
    
    return dict;
}

NSArray<PSIPair<NSString *> *> *_Nonnull
cppVecOfPairsToArray(const std::vector<std::pair<std::string, std::string>>& vec) {
    NSMutableArray<PSIPair<NSString *> *> *array = [NSMutableArray arrayWithCapacity:vec.size()];
    
    for (auto pair : vec) {
        NSString *first = [NSString stringWithUTF8String:pair.first.c_str()];
        NSString *second = [NSString stringWithUTF8String:pair.second.c_str()];
        [array addObject:[[PSIPair alloc] initWith:first :second]];
    }
    
    return array;
}

std::map<std::string, std::vector<std::string>>
dictOfArrayOfStringsToCppMap(NSDictionary<NSString *, NSArray<NSString *> *> *_Nullable dict) {
    
    std::map<std::string, std::vector<std::string>> map;
    
    for (NSString *key in dict) {
        std::string cppKey = [key UTF8String];
        NSArray<NSString *> *_Nonnull values;
        if (dict[key] == nil) {
            values = @[];
        } else {
            values = dict[key];
        }
        std::vector<std::string> cppValues = arrayOfStringsToCppVecOfStrings(values);
        
        map[cppKey] = cppValues;
    }
    
    return map;
}

#pragma mark - HTTPParams

@implementation PSIHttpRequest

- (instancetype)initWithCppHTTPParams:(const psicash::HTTPParams&)params {
    self = [super init];
    if (self) {
        self->_scheme = [NSString stringWithUTF8String:params.scheme.c_str()];
        self->_hostname = [NSString stringWithUTF8String:params.hostname.c_str()];
        self->_port = params.port;
        self->_method = [NSString stringWithUTF8String:params.method.c_str()];
        self->_path = [NSString stringWithUTF8String:params.path.c_str()];
        self->_headers = cppMapToDict(params.headers);
        self->_query = cppVecOfPairsToArray(params.query);
        self->_body = [NSString stringWithUTF8String:params.body.c_str()];
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

@implementation PSIHttpResult {
    psicash::HTTPResult result;
}

+ (int)CRITICAL_ERROR {
    return psicash::HTTPResult::CRITICAL_ERROR;
}

+ (int)RECOVERABLE_ERROR {
    return psicash::HTTPResult::RECOVERABLE_ERROR;
}

- (instancetype)initWithCode:(int)code
                     headers:(NSDictionary<NSString *, NSArray<NSString *> *> *)headers
                        body:(NSString *)body
                       error:(NSString *)error {
    self = [super init];
    if (self) {
        result.code = code;
        result.headers = dictOfArrayOfStringsToCppMap(headers);
        result.body = [body UTF8String];
        result.error = [error UTF8String];
    }
    return self;
}

- (instancetype)initWithCriticalError:(NSString *)error {
    return [self initWithCode:[PSIHttpResult CRITICAL_ERROR] headers:@{} body:@"" error:error];
}

- (instancetype)initWithRecoverableError:(NSString *)error {
    return [self initWithCode:[PSIHttpResult RECOVERABLE_ERROR] headers:@{} body:@"" error:error];
}

- (psicash::HTTPResult)cppHttpResult {
    return result;
}

@end

#pragma mark - Error

@implementation PSIError

+ (PSIError *_Nullable)createFrom:(const psicash::error::Error&)error {
    if (error.HasValue() == false) {
        return nil;
    } else {
        return [[PSIError alloc]
                initWithCritical:bool2ObjcBOOL(error.Critical())
                description:[NSString stringWithUTF8String:error.ToString().c_str()]];
    }
}

+ (PSIError *_Nonnull)createOrThrow:(const psicash::error::Error&)error {
    PSIError *_Nullable err = [PSIError createFrom:error];
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

@implementation PSIResult

- (instancetype)initWithSuccess:(id _Nonnull)success {
    self = [super init];
    if (self) {
        _success = success;
        _failure = nil;
    }
    return self;
}

- (instancetype)initWithFailure:(PSIError *_Nonnull)failure {
    self = [super init];
    if (self) {
        _success = nil;
        _failure = failure;
    }
    return self;
}

+ (PSIResult *_Nonnull)success:(id _Nonnull)success {
    return [[PSIResult alloc] initWithSuccess:success];
}

+ (PSIResult *_Nonnull)failure:(PSIError *_Nonnull)failure {
    return [[PSIResult alloc] initWithFailure:failure];
}

+ (PSIResult<NSString *> *_Nonnull)fromStringResult:(const psicash::error::Result<std::string>&)result {
    if (result.has_value()) {
        return [PSIResult success:[NSString stringWithUTF8String:result.value().c_str()]];
    } else {
        return [PSIResult failure:[PSIError createOrThrow:result.error()]];
    }
}

@end

#pragma mark - Authorization

@implementation PSIAuthorization

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

+ (PSIAuthorization *_Nonnull)createFrom:(const psicash::Authorization&)auth {
    return [[PSIAuthorization alloc] initWithAuth:auth];
}

@end

#pragma mark - PurchasePrice

@implementation PSIPurchasePrice

- (instancetype)initWithPurchasePrice:(const psicash::PurchasePrice&)purchasePrice {
    self = [super init];
    if (self) {
        _transactionClass = [NSString stringWithUTF8String:purchasePrice.transaction_class.c_str()];
        _distinguisher = [NSString stringWithUTF8String:purchasePrice.distinguisher.c_str()];
        _price = purchasePrice.price;
    }
    return self;
}

+ (PSIPurchasePrice *_Nonnull)createFrom:(const psicash::PurchasePrice&)purchasePrice {
    return [[PSIPurchasePrice alloc] initWithPurchasePrice:purchasePrice];
}

@end

#pragma mark - Purchase

@implementation PSIPurchase

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
            _authorization = [PSIAuthorization createFrom:purchase.authorization.value()];
        } else {
            _authorization = nil;
        }
    }
    return self;
}

+ (PSIPurchase *_Nonnull)createFrom:(const psicash::Purchase&)purchase {
    return [[PSIPurchase alloc] initWithPurchase:purchase];
}

+ (PSIPurchase *_Nullable)fromOptional:(const nonstd::optional<psicash::Purchase>&)purchase {
    if (purchase.has_value()) {
        return [PSIPurchase createFrom:purchase.value()];
    } else {
        return nil;
    }
}

+ (PSIResult<NSArray<PSIPurchase *> *> *_Nonnull)
fromResult:(const psicash::error::Result<psicash::Purchases>&)result {
    if (result.has_value()) {
        return [PSIResult success:[PSIPurchase fromArray:result.value()]];
    } else {
        return [PSIResult failure:[PSIError createOrThrow:result.error()]];
    }
}

+ (NSArray<PSIPurchase *> *_Nonnull)fromArray:(const psicash::Purchases&)purchases {
    NSMutableArray<PSIPurchase *> *array = [NSMutableArray arrayWithCapacity:purchases.size()];
    for (auto value: purchases) {
        [array addObject:[PSIPurchase createFrom:value]];
    }
    return array;
}

@end

#pragma mark - Status

PSIStatus statusFromStatus(const psicash::Status& status) {
    switch (status) {
        case psicash::Status::Invalid:
            return PSIStatusInvalid;
        case psicash::Status::Success:
            return PSIStatusSuccess;
        case psicash::Status::ExistingTransaction:
            return PSIStatusExistingTransaction;
        case psicash::Status::InsufficientBalance:
            return PSIStatusInsufficientBalance;
        case psicash::Status::TransactionAmountMismatch:
            return PSIStatusTransactionAmountMismatch;
        case psicash::Status::TransactionTypeNotFound:
            return PSIStatusTransactionTypeNotFound;
        case psicash::Status::InvalidTokens:
            return PSIStatusInvalidTokens;
        case psicash::Status::InvalidCredentials:
            return PSIStatusInvalidCredentials;
        case psicash::Status::BadRequest:
            return PSIStatusBadRequest;
        case psicash::Status::ServerError:
            return PSIStatusServerError;
    }
}

@implementation PSIStatusWrapper

- (instancetype)initWithStatus:(const psicash::Status&)status {
    self = [super init];
    if (self) {
        _status = statusFromStatus(status);
    }
    return self;
}

+ (PSIResult<PSIStatusWrapper *> *_Nonnull)fromResult:(const psicash::error::Result<psicash::Status>&)result {
    if (result.has_value()) {
        return [PSIResult success:[[PSIStatusWrapper alloc] initWithStatus:result.value()]];
    } else {
        return [PSIResult failure:[PSIError createOrThrow:result.error()]];
    }
}

@end

#pragma mark - NewExpiringPurchaseResponse

@implementation PSINewExpiringPurchaseResponse

- (instancetype)initWith:(const psicash::PsiCash::NewExpiringPurchaseResponse&)value {
    self = [super init];
    if (self) {
        _status = statusFromStatus(value.status);
        _purchase = [PSIPurchase fromOptional:value.purchase];
    }
    return self;
}

+ (PSIResult<PSINewExpiringPurchaseResponse *> *_Nonnull)
fromResult:(const psicash::error::Result<psicash::PsiCash::NewExpiringPurchaseResponse>&)result {
    
    if (result.has_value()) {
        return [PSIResult success:[[PSINewExpiringPurchaseResponse alloc] initWith:result.value()]];
    } else {
        return [PSIResult failure:[PSIError createOrThrow:result.error()]];
    }
}

@end

#pragma mark - RefreshStateResponse

@implementation PSIRefreshStateResponse

- (instancetype)initWith:(const psicash::PsiCash::RefreshStateResponse&)value {
    self = [super init];
    if (self) {
        _status = statusFromStatus(value.status);
        _reconnectRequired = bool2ObjcBOOL(value.reconnect_required);
    }
    return self;
}

+ (PSIResult<PSIRefreshStateResponse *> *_Nonnull)
fromResult:(const psicash::error::Result<psicash::PsiCash::RefreshStateResponse>&)result {
    
    if (result.has_value()) {
        return [PSIResult success:[[PSIRefreshStateResponse alloc] initWith:result.value()]];
    } else {
        return [PSIResult failure:[PSIError createOrThrow:result.error()]];
    }
    
}

@end

#pragma mark - AccountLogoutResponse

@implementation PSIAccountLogoutResponse

- (instancetype)initWith:(const psicash::PsiCash::AccountLogoutResponse&)value {
    self = [super init];
    if (self) {
        _reconnectRequired = bool2ObjcBOOL(value.reconnect_required);
    }
    return self;
}

+ (PSIResult<PSIAccountLogoutResponse *> *_Nonnull)
fromResult:(const psicash::error::Result<psicash::PsiCash::AccountLogoutResponse>&)result {
    
    if (result.has_value()) {
        return [PSIResult success:[[PSIAccountLogoutResponse alloc] initWith:result.value()]];
    } else {
        return [PSIResult failure:[PSIError createOrThrow:result.error()]];
    }
    
}

@end

#pragma mark - AccountLoginResponse

@implementation PSIAccountLoginResponse

- (instancetype)initWith:(const psicash::PsiCash::AccountLoginResponse&)value {
    self = [super init];
    if (self) {
        _status = statusFromStatus(value.status);
        
        if (value.last_tracker_merge.has_value()) {
            _lastTrackerMerge = [NSNumber numberWithBool:
                                 bool2ObjcBOOL(value.last_tracker_merge.value())];
        } else {
            _lastTrackerMerge = nil;
        }
         
    }
    return self;
}

+ (PSIResult<PSIAccountLoginResponse *> *_Nonnull)fromResult:
(const psicash::error::Result<psicash::PsiCash::AccountLoginResponse>&)result {
    if (result.has_value()) {
        return [PSIResult success:[[PSIAccountLoginResponse alloc] initWith:result.value()]];
    } else {
        return [PSIResult failure:[PSIError createOrThrow:result.error()]];
    }
}

@end


#pragma mark - PsiCashLibWrapper

@implementation PSIPsiCashLibWrapper {
    psicash::PsiCash *psiCash;
    BOOL test;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        psiCash = new psicash::PsiCash();
        test = FALSE;
    }
    return self;
}

- (void)dealloc {
    delete psiCash;
}

- (PSIError *_Nullable)initializeWithUserAgent:(NSString *)userAgent
                                 fileStoreRoot:(NSString *)fileStoreRoot
                               httpRequestFunc:(PSIHttpResult * (^_Nullable)(PSIHttpRequest *))httpRequestFunc
                                    forceReset:(BOOL)forceReset
                                          test:(BOOL)test {
    self->test = test;
    psicash::error::Error err;
    
    if (httpRequestFunc == nil) {
        
        err = psiCash->Init([userAgent UTF8String], [fileStoreRoot UTF8String],
                            nil, ObjcBOOL2bool(forceReset), ObjcBOOL2bool(test));
    } else {

        err = psiCash->Init([userAgent UTF8String],
                            [fileStoreRoot UTF8String],
                            [httpRequestFunc](const psicash::HTTPParams& cppParams) -> psicash::HTTPResult {
            return [httpRequestFunc([[PSIHttpRequest alloc] initWithCppHTTPParams:cppParams])
                    cppHttpResult];
        }, ObjcBOOL2bool(forceReset), ObjcBOOL2bool(test));
        
    }
    
    return [PSIError createFrom:err];
}

- (BOOL)initialized {
    return bool2ObjcBOOL(psiCash->Initialized());
}

- (PSIError *_Nullable)resetUser {
    psicash::error::Error error = psiCash->ResetUser();
    return [PSIError createFrom:error];
}

- (PSIError *_Nullable)migrateTrackerTokens:(NSDictionary<NSString *, NSString *> *_Nonnull)tokens {
    std::map<std::string, std::string> _tokens = dictToCppMap(tokens);
    psicash::error::Error err = psiCash->MigrateTrackerTokens(_tokens);
    return [PSIError createFrom:err];
}

- (PSIError *_Nullable)setRequestMetadataItem:(NSString *)key
                                    withValue:(NSString *)value {
    psicash::error::Error err = psiCash->SetRequestMetadataItem([key UTF8String],
                                                                [value UTF8String]);
    return [PSIError createFrom:err];
}

- (PSIError *_Nullable)setLocale:(NSString *)locale {
    psicash::error::Error err = psiCash->SetLocale([locale UTF8String]);
    return [PSIError createFrom:err];
}

- (BOOL)hasTokens {
    return bool2ObjcBOOL(psiCash->HasTokens());
}

- (BOOL)isAccount {
    return bool2ObjcBOOL(psiCash->IsAccount());
}

- (NSString *_Nullable)accountUsername {
    
    nonstd::optional<std::string> username = psiCash->AccountUsername();
    
    if (username.has_value()) {
        return [NSString stringWithUTF8String:username.value().c_str()];
    } else {
        return nil;
    }
    
}

- (int64_t)balance {
    return psiCash->Balance();
}

- (NSArray<PSIPurchasePrice *> *)getPurchasePrices {
    psicash::PurchasePrices pp = psiCash->GetPurchasePrices();
    NSMutableArray<PSIPurchasePrice *> *array = [NSMutableArray arrayWithCapacity:pp.size()];
    for (auto value : pp) {
        [array addObject:[PSIPurchasePrice createFrom:value]];
    }
    return array;
}

- (NSArray<PSIPurchase *> *)getPurchases {
    psicash::Purchases purchases = psiCash->GetPurchases();
    return [PSIPurchase fromArray:purchases];
}

- (NSArray<PSIPurchase *> *)activePurchases {
    psicash::Purchases activePurchases = psiCash->ActivePurchases();
    return [PSIPurchase fromArray:activePurchases];
}

- (NSArray<PSIAuthorization *> *)getAuthorizationsWithActiveOnly:(BOOL)activeOnly {
    psicash::Authorizations auths = psiCash->GetAuthorizations(ObjcBOOL2bool(activeOnly));
    NSMutableArray<PSIAuthorization *> *array = [NSMutableArray arrayWithCapacity:auths.size()];
    for (auto value: auths) {
        [array addObject:[PSIAuthorization createFrom:value]];
    }
    return array;
}

- (NSArray<PSIPurchase *> *)getPurchasesByAuthorizationID:(NSArray<NSString *> *)authorizationIDs {
    std::vector<std::string> authorization_ids = arrayOfStringsToCppVecOfStrings(authorizationIDs);
    psicash::Purchases purchases = psiCash->GetPurchasesByAuthorizationID(authorization_ids);
    return [PSIPurchase fromArray:purchases];
}

- (PSIPurchase *_Nullable)nextExpiringPurchase {
    nonstd::optional<psicash::Purchase> purchase = psiCash->NextExpiringPurchase();
    return [PSIPurchase fromOptional:purchase];
}

- (PSIResult<NSArray<PSIPurchase *> *> *)expirePurchases {
    psicash::error::Result<psicash::Purchases> result = psiCash->ExpirePurchases();
    return [PSIPurchase fromResult:result];
}

- (PSIResult<NSArray<PSIPurchase *> *> *)
removePurchasesWithTransactionID:(NSArray<NSString *> *)transactionIds {
    std::vector<std::string> transaction_ids = arrayOfStringsToCppVecOfStrings(transactionIds);
    psicash::error::Result<psicash::Purchases> result = psiCash->RemovePurchases(transaction_ids);
    return [PSIPurchase fromResult:result];
}

- (PSIResult<NSString *> *)modifyLandingPage:(NSString *)url {
    psicash::error::Result<std::string> result = psiCash->ModifyLandingPage([url UTF8String]);
    return [PSIResult fromStringResult:result];
}

- (PSIResult<NSString *> *)getBuyPsiURL {
    psicash::error::Result<std::string> result = psiCash->GetBuyPsiURL();
    return [PSIResult fromStringResult:result];
}

- (NSString *)getUserSiteURL:(PSIUserSiteURLType)urlType webview:(BOOL)webview {
    psicash::PsiCash::UserSiteURLType cppUrlType = (psicash::PsiCash::UserSiteURLType)urlType;
    std::string url = psiCash->GetUserSiteURL(cppUrlType, ObjcBOOL2bool(webview));
    return [NSString stringWithUTF8String:url.c_str()];
}

- (PSIResult<NSString *> *)getRewardedActivityData {
    psicash::error::Result<std::string> result = psiCash->GetRewardedActivityData();
    return [PSIResult fromStringResult:result];
}

- (NSString *)getDiagnosticInfo {
    nlohmann::json diagnostic = psiCash->GetDiagnosticInfo();
    try {
        auto dump = diagnostic.dump(-1, ' ', true);
        return [NSString stringWithUTF8String:dump.c_str()];
    } catch (nlohmann::json::exception& e) {
        // Should never happen...
        return [NSString stringWithFormat:@"error: id:'%d' cause:'%@'", e.id,
                [NSString stringWithUTF8String:e.what()]];
    }
}

- (PSIResult<PSIRefreshStateResponse *> *)refreshStateWithPurchaseClasses:(NSArray<NSString *> *)purchaseClasses
                                                                localOnly:(BOOL)localOnly {
    std::vector<std::string> cppPurchasesClasses = arrayOfStringsToCppVecOfStrings(purchaseClasses);
    psicash::error::Result<psicash::PsiCash::RefreshStateResponse> result = psiCash->RefreshState(ObjcBOOL2bool(localOnly), cppPurchasesClasses);
    return [PSIRefreshStateResponse fromResult:result];
}

- (PSIResult<PSINewExpiringPurchaseResponse *> *)
newExpiringPurchaseWithTransactionClass:(NSString *)transactionClass
distinguisher:(NSString *)distinguisher
expectedPrice:(int64_t)expectedPrice {
    auto result = psiCash->NewExpiringPurchase([transactionClass UTF8String],
                                               [distinguisher UTF8String],
                                               expectedPrice);
    
    return [PSINewExpiringPurchaseResponse fromResult:result];
}

- (PSIResult<PSIAccountLogoutResponse *> *)accountLogout {
    psicash::error::Result<psicash::PsiCash::AccountLogoutResponse> result = psiCash->AccountLogout();
    return [PSIAccountLogoutResponse fromResult:result];
}

- (PSIResult<PSIAccountLoginResponse *> *)accountLoginWithUsername:(NSString *)username
                                                       andPassword:(NSString *)password {
    auto result = psiCash->AccountLogin([username UTF8String], [password UTF8String]);
    return [PSIAccountLoginResponse fromResult:result];
}

# pragma mark - Testing only
#if DEBUG

- (PSIError *_Nullable)testRewardWithClass:(NSString *)transactionClass
                             distinguisher:(NSString *)distinguisher {
    if (test == FALSE) {
        return [[PSIError alloc] initWithCritical:TRUE
                                      description:@"Not initialized in test mode"];
    }
    
    PsiCashTest *client = (PsiCashTest *)self->psiCash;
    psicash::error::Error err = client->TestReward([transactionClass UTF8String],
                                                   [distinguisher UTF8String]);
    return [PSIError createFrom:err];
}

#endif

@end
