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

#if DEBUG

#include <string>
#include "PsiCashTest.hpp"
#include "utils.hpp"
#include "http_status_codes.h"

using namespace std;
using namespace psicash;

// Copied from https://github.com/Psiphon-Inc/psicash-lib-android/blob/f6ada9c7e8e87dd93086e267770627e3b53b4c17/psicashlib/src/main/cpp/jnitest.cpp#L30-L43

error::Error PsiCashTest::TestReward(const string& transaction_class, const string& distinguisher) {
    auto result = MakeHTTPRequestWithRetry(
            "POST", "/transaction", true,
            {{"class",         transaction_class},
             {"distinguisher", distinguisher}});
    if (!result) {
        return WrapError(result.error(), "MakeHTTPRequestWithRetry failed");
    } else if (result->code != kHTTPStatusOK) {
        return error::MakeNoncriticalError(
                utils::Stringer("reward request failed: ", result->code, "; ", result->error, "; ", result->body));
    }

    return error::nullerr;
}

#endif
