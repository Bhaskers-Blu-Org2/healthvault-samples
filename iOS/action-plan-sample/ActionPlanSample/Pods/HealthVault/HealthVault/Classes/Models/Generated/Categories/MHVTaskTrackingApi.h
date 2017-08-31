//
// MHVTaskTrackingApi.h
// MHVLib
//
// Copyright (c) 2017 Microsoft Corporation. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

/**
* NOTE: This class is auto generated by the swagger code generator program.
* https://github.com/swagger-api/swagger-codegen.git
* Do not edit the class manually.
*/


#import <Foundation/Foundation.h>
#import "MHVRemoteMonitoringClient.h"
#import "MHVErrorResponse.h"
#import "MHVTaskTrackingOccurrence.h"


NS_ASSUME_NONNULL_BEGIN

@interface MHVRemoteMonitoringClient (MHVTaskTrackingApi)

/// Delete a task tracking occurrence
/// 
///
/// @param occurrenceId The task tracking occurrence id.
/// 
- (void)taskTrackingDeleteWithOccurrenceId:(NSString* )occurrenceId
    completion:(void(^_Nonnull)(NSNumber* _Nullable output, NSError* _Nullable error))completion;


/// Patch an task tracking occurrence
/// 
///
/// @param occurrenceId The task tracking occurrence id.
/// @param taskTrackingOccurrence The plan task tracking occurrence.
/// 
- (void)taskTrackingPatchWithOccurrenceId:(NSString* )occurrenceId
    taskTrackingOccurrence:(MHVTaskTrackingOccurrence* )taskTrackingOccurrence
    completion:(void(^_Nonnull)(MHVTaskTrackingOccurrence* _Nullable output, NSError* _Nullable error))completion;


/// Post a task tracking
/// 
///
/// @param taskTrackingOccurrence The plan task tracking occurrence.
/// 
- (void)taskTrackingPostWithTaskTrackingOccurrence:(MHVTaskTrackingOccurrence* )taskTrackingOccurrence
    completion:(void(^_Nonnull)(MHVTaskTrackingOccurrence* _Nullable output, NSError* _Nullable error))completion;



@end

NS_ASSUME_NONNULL_END