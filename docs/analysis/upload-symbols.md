# アップロード関連クラス・selector 索引

ここでは今回の調査で参照したクラスの instance method metadata 全項目を列挙します。存在・型・静的アドレスの確認であり、各メソッドの実装を全て解析したという意味ではありません。全クラスは [機械可読索引](objc/README.md) を検索してください。アドレスは各イメージ内の static VM address で、ASLR slide 適用前です。framework と main のアドレスを混同しないでください。

## PHSBackupActionBehaviorImpl

Image: `main`。状態: metadata 確認。

| Selector | Type encoding | Static IMP |
| --- | --- | --- |
| `initWithAccount:context:` | `@32@0:8@16@24` | `0x10003bb28` |
| `addOverflowMenuElements:` | `@24@0:8@16` | `0x100f9db24` |
| `overflowMenuElements` | `@16@0:8` | `0x100f9dba8` |
| `configureBackupAction:` | `v24@0:8@16` | `0x100f9de28` |
| `backupLocalAssets:` | `v24@0:8@16` | `0x100f9e044` |
| `logActionWithTag:numberOfMediaItems:sectionTag:` | `v40@0:8{?=iBs}16Q24{?=iBs}32` | `0x100f9e91c` |
| `logTapWithVisualElement:sectionTag:` | `v32@0:8@16{?=iBs}24` | `0x100f9e984` |
| `day` | `@16@0:8` | `0x100f9ea80` |
| `userSettings` | `@16@0:8` | `0x100f9eb10` |
| `.cxx_destruct` | `v16@0:8` | `0x100f9eb20` |

## PHSUploadMediaStrategy

Image: `main`。状態: metadata 確認。

| Selector | Type encoding | Static IMP |
| --- | --- | --- |
| `initWithAssets:shouldUploadThumbnail:forceUploadOnAnyConnection:addedClusterKeys:removedClusterKeys:` | `@48@0:8@16B24B28@32@40` | `0x102efd198` |
| `initWithAssets:shouldUploadThumbnail:forceUploadOnAnyConnection:` | `@32@0:8@16B24B28` | `0x102efd44c` |
| `commonInit` | `v16@0:8` | `0x102efd458` |
| `inFlightUpload` | `@16@0:8` | `0x102efd5c4` |
| `setInFlightUpload:` | `v24@0:8@16` | `0x102efd60c` |
| `setAssetsToUpload:` | `v24@0:8@16` | `0x102efd66c` |
| `dealloc` | `v16@0:8` | `0x102efd6e8` |
| `encodeWithCoder:` | `v24@0:8@16` | `0x102efd744` |
| `initWithCoder:` | `@24@0:8@16` | `0x102efd868` |
| `didQueue` | `@16@0:8` | `0x102efdab4` |
| `commitWithKeys:` | `@24@0:8@16` | `0x102efdc5c` |
| `didCancel` | `@16@0:8` | `0x102efdea0` |
| `actionTypeForLogging` | `i16@0:8` | `0x102efdf6c` |
| `isPermanentlyFailedAfterTimeSinceFirstFailure:` | `B24@0:8d16` | `0x102efdf74` |
| `transformedLocalAssetIDs` | `@16@0:8` | `0x102efdf7c` |
| `userInitiatedUpload:didCompleteWithError:` | `v32@0:8@16@24` | `0x102efdf98` |
| `userInitiatedUpload:assetDidComplete:serverPhoto:` | `v40@0:8@16@24@32` | `0x102efe134` |
| `userInitiatedUploadDidProgress:` | `v24@0:8@16` | `0x102efe200` |
| `photoLibraryDidChange:` | `v24@0:8@16` | `0x102efe22c` |
| `prioritizeAssets:` | `v24@0:8@16` | `0x102efe334` |
| `unsubscribeFromAutoBackupEvents` | `v16@0:8` | `0x102efe424` |
| `subscribeToAutoBackupEvents` | `v16@0:8` | `0x102efe4c0` |
| `handleAutoBackupEvent:` | `v24@0:8@16` | `0x102efe55c` |
| `updateAutoBackupUploadWithAssetsResult:` | `v24@0:8@16` | `0x102efeca0` |
| `createUploadRequestForPHAssets:` | `@24@0:8@16` | `0x102eff1bc` |
| `startInFlightUploadForPHAssets:` | `v24@0:8@16` | `0x102eff258` |
| `updateUserInitiatedUploadWithAssetsResult:` | `v24@0:8@16` | `0x102eff2e8` |
| `phAssetsNeedingUpload` | `@16@0:8` | `0x102eff5a0` |
| `shouldUploadViaAutoBackupPrioritization` | `B16@0:8` | `0x102eff98c` |
| `notifyTransactionsWithProgress:` | `v20@0:8f16` | `0x102effac0` |
| `updateTemporaryCreationData:mediaKey:` | `v32@0:8@16@24` | `0x102effb98` |
| `transformedDedupKeys` | `@16@0:8` | `0x102effcfc` |
| `assetIDs` | `@16@0:8` | `0x102effd0c` |
| `addedClusterKeys` | `@16@0:8` | `0x102effd1c` |
| `removedClusterKeys` | `@16@0:8` | `0x102effd2c` |
| `shouldUploadThumbnail` | `B16@0:8` | `0x102effd3c` |
| `forceUploadOnAnyConnection` | `B16@0:8` | `0x102effd4c` |
| `temporaryCreationDataArray` | `@16@0:8` | `0x102effd5c` |
| `backupChannel` | `@16@0:8` | `0x102effd6c` |
| `.cxx_destruct` | `v16@0:8` | `0x102effd7c` |

## PHSUserInitiatedUpload

Image: `main`。状態: metadata 確認。

| Selector | Type encoding | Static IMP |
| --- | --- | --- |
| `initWithAccountIdentifier:uploadCount:delegate:` | `@40@0:8@16Q24@32` | `0x1031517a4` |
| `start` | `B16@0:8` | `0x103151ae0` |
| `cancel` | `v16@0:8` | `0x103151c40` |
| `uploadRequestShouldUseBackgroundUploadPath:` | `B24@0:8@16` | `0x103151dcc` |
| `uploadRequestDidBeginUploading:isResumedUpload:` | `v28@0:8@16B24` | `0x103151dd4` |
| `uploadRequestDidProgress:` | `v24@0:8@16` | `0x103151ee0` |
| `computeProgressFromRequest:` | `v24@0:8@16` | `0x103151fbc` |
| `uploadRequest:didCompleteWithError:resultantMediaItem:` | `v40@0:8@16@24@32` | `0x103152104` |
| `uploadRequest:shouldUploadFingerprint:` | `B32@0:8@16@24` | `0x103152684` |
| `uploadRequestAssetStateForAsset:` | `@24@0:8@16` | `0x10315268c` |
| `uploadRequest:didStartDownloadForAsset:` | `v32@0:8@16@24` | `0x1031526fc` |
| `uploadRequest:shouldUploadPairedVideoForPhotoFingerprint:` | `B32@0:8@16@24` | `0x103152700` |
| `callCompletionHandlerWithError:` | `v24@0:8@16` | `0x103152708` |
| `resetExponentialBackoffTime` | `v16@0:8` | `0x103152794` |
| `calculateExponentialBackoffTime` | `q16@0:8` | `0x1031527a4` |
| `assets` | `@16@0:8` | `0x10315281c` |
| `isCancelled` | `B16@0:8` | `0x10315282c` |
| `delegate` | `@16@0:8` | `0x10315283c` |
| `setDelegate:` | `v24@0:8@16` | `0x10315285c` |
| `queue` | `@16@0:8` | `0x103152870` |
| `uploadQueue` | `@16@0:8` | `0x103152880` |
| `serverPhotoForAsset` | `@16@0:8` | `0x103152890` |
| `setServerPhotoForAsset:` | `v24@0:8@16` | `0x1031528a0` |
| `progress` | `d16@0:8` | `0x1031528ac` |
| `setProgress:` | `v24@0:8d16` | `0x1031528bc` |
| `startAttempted` | `B16@0:8` | `0x1031528cc` |
| `setStartAttempted:` | `v20@0:8B16` | `0x1031528dc` |
| `credentialsPromise` | `@16@0:8` | `0x1031528ec` |
| `storagePolicy` | `i16@0:8` | `0x1031528fc` |
| `uploadCount` | `Q16@0:8` | `0x10315290c` |
| `completedCount` | `Q16@0:8` | `0x10315291c` |
| `setCompletedCount:` | `v24@0:8Q16` | `0x10315292c` |
| `pendingRequests` | `@16@0:8` | `0x10315293c` |
| `.cxx_destruct` | `v16@0:8` | `0x10315294c` |

## PHSUserInitiatedAssetUpload

Image: `main`。状態: metadata 確認。

| Selector | Type encoding | Static IMP |
| --- | --- | --- |
| `initWithAccountIdentifier:assets:delegate:shouldUploadThumbnail:addedClusterKeys:removedClusterKeys:` | `@60@0:8@16@24@32B40@44@52` | `0x103152a14` |
| `initWithAccountIdentifier:assets:delegate:shouldUploadThumbnail:` | `@44@0:8@16@24@32B40` | `0x103152b70` |
| `start` | `B16@0:8` | `0x103152b7c` |
| `addClusterKeysForUploadRequest:` | `@24@0:8@16` | `0x103152c30` |
| `removedClusterKeysForUploadRequest:` | `@24@0:8@16` | `0x103152c5c` |
| `uploadRequest:didStartDownloadForAsset:` | `v32@0:8@16@24` | `0x103152c88` |
| `enqueueAssets:` | `v24@0:8Q16` | `0x103152c8c` |
| `shouldUploadAsThumbnailAsset:` | `@24@0:8@16` | `0x103152e28` |
| `scheduleUploadForAsset:` | `v24@0:8@16` | `0x103152fc8` |
| `scheduleUploadForAssetWithExponentialBackoff:` | `v24@0:8@16` | `0x1031536e0` |
| `uploadRequest:didCompleteWithError:resultantMediaItem:` | `v40@0:8@16@24@32` | `0x1031537f4` |
| `uploadRequest:didDiscoverFingerprintExists:mediaKey:` | `v40@0:8@16@24@32` | `0x103153c5c` |
| `dealloc` | `v16@0:8` | `0x103153f58` |
| `shouldUploadThumbnail` | `B16@0:8` | `0x103154014` |
| `nextAssetIndex` | `Q16@0:8` | `0x103154024` |
| `setNextAssetIndex:` | `v24@0:8Q16` | `0x103154034` |
| `quotaManager` | `@16@0:8` | `0x103154044` |
| `.cxx_destruct` | `v16@0:8` | `0x103154054` |

## PHSSelectiveBackupAssetUpload

Image: `main`。状態: metadata 確認。

| Selector | Type encoding | Static IMP |
| --- | --- | --- |
| `init` | `@16@0:8` | `0x103150fc8` |
| `uploadAssets:withCredentialsPromise:` | `v32@0:8@16@24` | `0x103151028` |
| `uploadRequest:didCompleteWithError:resultantMediaItem:` | `v40@0:8@16@24@32` | `0x1031513b8` |
| `uploadRequestDidProgress:` | `v24@0:8@16` | `0x103151774` |
| `uploadRequest:shouldUploadFingerprint:` | `B32@0:8@16@24` | `0x103151778` |
| `uploadRequest:didDiscoverFingerprintExists:mediaKey:` | `v40@0:8@16@24@32` | `0x103151780` |
| `uploadRequest:shouldUploadPairedVideoForPhotoFingerprint:` | `B32@0:8@16@24` | `0x103151784` |
| `uploadRequestShouldUseBackgroundUploadPath:` | `B24@0:8@16` | `0x10315178c` |
| `uploadRequest:didStartDownloadForAsset:` | `v32@0:8@16@24` | `0x103151794` |
| `.cxx_destruct` | `v16@0:8` | `0x103151798` |

## PHSLockedPhotoUploader

Image: `main`。状態: metadata 確認。

| Selector | Type encoding | Static IMP |
| --- | --- | --- |
| `initWithAccountID:queue:` | `@32@0:8@16@24` | `0x100f878c0` |
| `asUserInitiatedUploadDelegate` | `@16@0:8` | `0x100f879b0` |
| `uploadLockedLocalAssets:whenCancelled:` | `@32@0:8@16@?24` | `0x100f879b4` |
| `userInitiatedUpload:didCompleteWithError:` | `v32@0:8@16@24` | `0x100f8877c` |
| `userInitiatedUpload:assetDidComplete:serverPhoto:` | `v40@0:8@16@24@32` | `0x100f88920` |
| `userInitiatedUploadDidProgress:` | `v24@0:8@16` | `0x100f88b24` |
| `createUploadWorkerWithAssets:` | `@24@0:8@16` | `0x100f88c94` |
| `markNonUploadedAssetsAsFailedWithError:` | `v24@0:8@16` | `0x100f88e64` |
| `completeActionAndResolvePromise:` | `v20@0:8B16` | `0x100f88f94` |
| `cleanupAndFinish` | `v16@0:8` | `0x100f89294` |
| `workQueue` | `@16@0:8` | `0x100f8932c` |
| `isWorking` | `B16@0:8` | `0x100f8933c` |
| `setIsWorking:` | `v20@0:8B16` | `0x100f89350` |
| `isCancelled` | `B16@0:8` | `0x100f89360` |
| `setIsCancelled:` | `v20@0:8B16` | `0x100f89370` |
| `assetMap` | `@16@0:8` | `0x100f89380` |
| `cancelBlock` | `@?16@0:8` | `0x100f89390` |
| `setCancelBlock:` | `v24@0:8@?16` | `0x100f893a0` |
| `uploadWorker` | `@16@0:8` | `0x100f893ac` |
| `setUploadWorker:` | `v24@0:8@16` | `0x100f893bc` |
| `actionResult` | `@16@0:8` | `0x100f893f8` |
| `setActionResult:` | `v24@0:8@16` | `0x100f89408` |
| `completionPromise` | `@16@0:8` | `0x100f89444` |
| `setCompletionPromise:` | `v24@0:8@16` | `0x100f89454` |
| `folderItemStore` | `@16@0:8` | `0x100f89490` |
| `backupController` | `@16@0:8` | `0x100f894a0` |
| `dontBackupRequestResult` | `@16@0:8` | `0x100f894b0` |
| `setDontBackupRequestResult:` | `v24@0:8@16` | `0x100f894c0` |
| `.cxx_destruct` | `v16@0:8` | `0x100f894fc` |

## _TtC84googlemac_iPhone_Shared_Photos_Upload_Request_Scotty_ScottyUploadServiceImpl_ImplLib23ScottyUploadServiceImpl

Image: `main`。状態: metadata 確認。

| Selector | Type encoding | Static IMP |
| --- | --- | --- |
| `URLSession:dataTask:didReceiveData:` | `v40@0:8@16@24@32` | `0x100621d68` |
| `URLSession:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:` | `v56@0:8@16@24q32q40q48` | `0x100622050` |
| `uploadWithAsset:shouldAllowCellular:useBackgroundSession:start:progress:onDataReleased:completionHandler:` | `v64@0:8@"GMUUploadAsset"16B24B28@?<v@?B>32@?<v@?d>40@?<v@?>48@?<v@?@"NSData"@"NSError">56` | `0x1006204d8` |
| `statelessUploadWithAsset:shouldAllowCellular:progress:completionHandler:` | `v44@0:8@"GMUUploadAsset"16B24@?<v@?d>28@?<v@?@"NSData"@"NSError">36` | `0x100620dfc` |
| `cancelUploadForAsset:completionHandler:` | `v32@0:8@"GMUUploadAsset"16@?<v@?>24` | `0x1006213cc` |
| `reconnectOutstandingRequestsWithCompletionHandler:` | `v24@0:8@?<v@?@"NSArray">16` | `0x1006215ec` |
| `init` | `@16@0:8` | `0x103a1acdc` |

## PHSActionsGridModel

Image: `framework`。状態: metadata 確認。

| Selector | Type encoding | Static IMP |
| --- | --- | --- |
| `archiveMediaItems:archiveOperation:archiveReason:` | `v40@0:8@16Q24Q32` | `0xf7a400` |
| `pickPhotosForArchive` | `v16@0:8` | `0xf7a53c` |
| `backupLocalAssets:` | `v24@0:8@16` | `0xf7a588` |
| `favoriteMediaItems:isFavoriting:` | `v28@0:8@16B24` | `0xf7a658` |
| `prepareAndDeleteMediaItems:shouldExpand:` | `v28@0:8@16B24` | `0xf7a75c` |
| `deleteMediaItems:deleteOperation:shouldExpand:serverOnlyTrashAlertConfirmed:` | `v40@0:8@16Q24B32B36` | `0xf7a860` |
| `deleteMediaItems:deleteOperation:shouldExpand:` | `v36@0:8@16Q24B32` | `0xf7a9cc` |
| `deleteDeviceCopiesWithLocalAssets:serverPhotos:` | `v32@0:8@16@24` | `0xf7a9d4` |
| `presentTrashAlertForMediaItems:photoGroups:cancelBlock:confirmBlock:` | `v48@0:8@16Q24@?32@?40` | `0xf7aabc` |
| `enrichmentsAdded:expectedEnrichments:context:` | `v40@0:8@16@24@32` | `0xf7ac20` |
| `pickedLocation:` | `v24@0:8@16` | `0xf7ad2c` |
| `shareFromSourceView:` | `v24@0:8@16` | `0xf7ae08` |
| `keepPhotos:` | `v24@0:8@16` | `0xf7aefc` |
| `setGroupPrimary:` | `v24@0:8@16` | `0xf7afc8` |
| `removeGroupItems:` | `v24@0:8@16` | `0xf7b0bc` |
| `addToGroup:` | `v24@0:8@16` | `0xf7b18c` |
| `mergeGroups:` | `v24@0:8@16` | `0xf7b25c` |
| `createGroup:` | `v24@0:8@16` | `0xf7b32c` |
| `create` | `v16@0:8` | `0xf7b3fc` |
| `ungroupGroupWithIdentifier:` | `v24@0:8@16` | `0xf7b448` |
| `getOverflowMenuElementsWithDestination:` | `@24@0:8@16` | `0xf7b518` |
| `configureAddToAction:` | `v24@0:8@16` | `0xf7b694` |
| `configureAddToAlbumAction:` | `v24@0:8@16` | `0xf7b764` |
| `configureArchiveAction:` | `v24@0:8@16` | `0xf7b834` |
| `configureBackupAction:` | `v24@0:8@16` | `0xf7b904` |
| `configureCreateAction:` | `v24@0:8@16` | `0xf7b9d4` |
| `configureDeleteFromDeviceAction:` | `v24@0:8@16` | `0xf7baa4` |
| `configureEditDateTimeAction:serverPhotos:` | `v32@0:8@16@24` | `0xf7bb74` |
| `configureEditLocationAction:localAssets:` | `v32@0:8@16@24` | `0xf7bc5c` |
| `configureFavoriteAction:` | `v24@0:8@16` | `0xf7bd44` |
| `configureMoveToLockedFolderAction:` | `v24@0:8@16` | `0xf7be14` |
| `configurePrintAction:` | `v24@0:8@16` | `0xf7bee4` |
| `configureSaveToDeviceAction:` | `v24@0:8@16` | `0xf7bfb4` |
| `configureShareAction:` | `v24@0:8@16` | `0xf7c084` |
| `configureTrashAction:` | `v24@0:8@16` | `0xf7c154` |
| `configureKeepPhotosAction:` | `v24@0:8@16` | `0xf7c224` |
| `configureSetGroupPrimaryAction:` | `v24@0:8@16` | `0xf7c2f0` |
| `configureRemoveFromGroupAction:` | `v24@0:8@16` | `0xf7c3bc` |
| `configureAddToGroupAction:` | `v24@0:8@16` | `0xf7c48c` |
| `configureMergeGroupsAction:` | `v24@0:8@16` | `0xf7c55c` |
| `configureCreateGroupAction:` | `v24@0:8@16` | `0xf7c62c` |
| `configureUngroupAction:` | `v24@0:8@16` | `0xf7c6fc` |
| `showPlusMenu` | `v16@0:8` | `0xf7c7cc` |
| `configurePlusMenu:` | `v24@0:8@16` | `0xf7c818` |
| `showPrintedProductsActionSheetWithContext:sourceView:` | `v32@0:8@16@24` | `0xf7c8e8` |
| `showPeopleNamingView` | `v16@0:8` | `0xf7c9a8` |
| `openSearchResultsInContext` | `v16@0:8` | `0xf7c9f4` |
| `openStoryInContext` | `v16@0:8` | `0xf7ca40` |
| `openStoryInCell:` | `v24@0:8@16` | `0xf7ca8c` |
| `openMyWeekCreationCellWithAlbumMediaKey:envelopeMediaKey:` | `v32@0:8@16@24` | `0xf7cb5c` |
| `openMyWeekOnboardingCell` | `v16@0:8` | `0xf7cc5c` |
| `openMyWeekStoryPreview:initialMediaKey:shouldOpenActivityView:` | `v36@0:8@16@24B32` | `0xf7cca8` |
| `openPromoCardCell:` | `v24@0:8@16` | `0xf7ce04` |
| `openGameStoryCardCell:` | `v24@0:8@16` | `0xf7ced4` |
| `openVideoLaneCardCell:` | `v24@0:8@16` | `0xf7cfa4` |
| `playStory:forCell:` | `v32@0:8@16@24` | `0xf7d074` |
| `startTripRenamingFlow` | `v16@0:8` | `0xf7d15c` |
| `beginRenamingTripForCell:` | `v24@0:8@16` | `0xf7d1a8` |
| `endRenamingTripWithTitle:` | `v24@0:8@16` | `0xf7d278` |

## PHSLocalAsset

Image: `framework`。状態: metadata 確認。

| Selector | Type encoding | Static IMP |
| --- | --- | --- |
| `setCaption:` | `v24@0:8@16` | `0x1248c40` |
| `caption` | `@16@0:8` | `0x1248c50` |
| `initWithLocalIdentifier:` | `@24@0:8@16` | `0xfbbf58` |
| `updateCreationFlag` | `v16@0:8` | `0xfbbff4` |
| `updatePHAsset` | `v16@0:8` | `0xfbc348` |
| `initWithPHAsset:source:index:` | `@36@0:8@16@24I32` | `0x124983c` |
| `initWithPHAsset:` | `@24@0:8@16` | `0x1249b14` |
| `phAsset` | `@16@0:8` | `0x1249b20` |
| `representsBurst` | `B16@0:8` | `0x1249bb8` |
| `modificationTimeMs` | `q16@0:8` | `0x1249bc4` |
| `isLocalDedupKeyReady` | `B16@0:8` | `0x1249c40` |
| `isCollage` | `B16@0:8` | `0x1249c50` |
| `isAnimation` | `B16@0:8` | `0x1249c5c` |
| `isCinematicPhoto` | `B16@0:8` | `0x1249c68` |
| `isMovie` | `B16@0:8` | `0x1249c74` |
| `updatePHAsset:` | `v24@0:8@16` | `0x1249c80` |
| `updateSize:editListVersionId:` | `v28@0:8Q16s24` | `0x1249db4` |
| `updateLocalDedupKey:localDedupKeyTimeMs:` | `v32@0:8@16q24` | `0x1249dc0` |
| `localDedupKey` | `@16@0:8` | `0x1249e3c` |
| `isArchived` | `B16@0:8` | `0x1249e7c` |
| `setArchived:` | `v20@0:8B16` | `0x1249e88` |
| `isAutoArchived` | `B16@0:8` | `0x1249ea8` |
| `setAutoArchived:` | `v20@0:8B16` | `0x1249eb4` |
| `isUnarchived` | `B16@0:8` | `0x1249ed4` |
| `setUnarchived:` | `v20@0:8B16` | `0x1249ee0` |
| `isPendingArchiveSuggestion` | `B16@0:8` | `0x1249f00` |
| `isFavorite` | `B16@0:8` | `0x1249f08` |
| `isPHAssetFavorite` | `B16@0:8` | `0x1249f14` |
| `setFavorite:` | `v20@0:8B16` | `0x1249f20` |
| `isHidden` | `B16@0:8` | `0x1249f40` |
| `setHidden:` | `v20@0:8B16` | `0x1249f4c` |
| `hasAdjustments` | `B16@0:8` | `0x1249f60` |
| `isAutoAdd` | `B16@0:8` | `0x1249f6c` |
| `burstIdentifier` | `@16@0:8` | `0x1249f74` |
| `groupIdentifier` | `@16@0:8` | `0x1249fc4` |
| `groupPrimaryScore` | `q16@0:8` | `0x1249fcc` |
| `dimensions` | `{CGSize=dd}16@0:8` | `0x1249fd4` |
| `timestamp` | `d16@0:8` | `0x1249fe8` |
| `timeZoneOffset` | `@16@0:8` | `0x124a000` |
| `canMakeCreation` | `B16@0:8` | `0x124a008` |
| `isCreation` | `B16@0:8` | `0x124a010` |
| `isAnimated` | `B16@0:8` | `0x124a024` |
| `isTrash` | `B16@0:8` | `0x124a038` |
| `isVideo` | `B16@0:8` | `0x124a040` |
| `isLivePhoto` | `B16@0:8` | `0x124a04c` |
| `isVRMedia` | `B16@0:8` | `0x124a058` |
| `is360Media` | `B16@0:8` | `0x124a064` |
| `isHDRMedia` | `B16@0:8` | `0x124a070` |
| `isVideoStreamed` | `B16@0:8` | `0x124a08c` |
| `isVideoHighFrameRate` | `B16@0:8` | `0x124a098` |
| `isVideoTimelapse` | `B16@0:8` | `0x124a0a4` |
| `isPhotoHDR` | `B16@0:8` | `0x124a0b0` |
| `isPhotoScreenshot` | `B16@0:8` | `0x124a0bc` |
| `isPhotoDepthEffect` | `B16@0:8` | `0x124a0c8` |
| `isPanoramicPhoto` | `B16@0:8` | `0x124a0d4` |
| `isEditedCopy` | `B16@0:8` | `0x124a108` |
| `hasC2PAProvenanceData` | `B16@0:8` | `0x124a114` |
| `adjustedDateComponents` | `I16@0:8` | `0x124a120` |
| `url` | `@16@0:8` | `0x124a134` |
| `itemType` | `C16@0:8` | `0x124a13c` |
| `videoDuration` | `d16@0:8` | `0x124a144` |
| `needsFullBackup` | `B16@0:8` | `0x124a184` |
| `hasLocationCoordinate` | `B16@0:8` | `0x124a18c` |
| `coordinate` | `{CLLocationCoordinate2D=dd}16@0:8` | `0x124a198` |
| `containedItem` | `@16@0:8` | `0x124a1b8` |
| `showcaseScore` | `q16@0:8` | `0x124a1c0` |
| `isLocked` | `B16@0:8` | `0x124a1c8` |
| `isSticker` | `B16@0:8` | `0x124a1d0` |
| `isApparelItem` | `B16@0:8` | `0x124a1d8` |
| `isApparelOutfit` | `B16@0:8` | `0x124a1e0` |
| `isImageFromPrompt` | `B16@0:8` | `0x124a1e8` |
| `copyWithZone:` | `@24@0:8^{_NSZone=}16` | `0x124a21c` |
| `key` | `@16@0:8` | `0x124a334` |
| `dedupKey` | `@16@0:8` | `0x124a358` |
| `assetFromAssetSource` | `@16@0:8` | `0x124a37c` |
| `assetSource` | `@16@0:8` | `0x124a40c` |
| `assetSourceIndex` | `I16@0:8` | `0x124a430` |
| `mediaKey` | `@16@0:8` | `0x124a438` |
| `size` | `Q16@0:8` | `0x124a440` |
| `weakAsset` | `@16@0:8` | `0x124a448` |
| `localDedupKeyTimeMs` | `q16@0:8` | `0x124a460` |
| `editListVersionId` | `s16@0:8` | `0x124a468` |
| `shareCount` | `I16@0:8` | `0x124a470` |
| `setShareCount:` | `v20@0:8I16` | `0x124a478` |
| `viewCount` | `I16@0:8` | `0x124a480` |
| `setViewCount:` | `v20@0:8I16` | `0x124a488` |
| `timestampMs` | `q16@0:8` | `0x124a490` |
| `setTimestampMs:` | `v24@0:8q16` | `0x124a498` |
| `flags` | `S16@0:8` | `0x124a4a0` |
| `setFlags:` | `v20@0:8S16` | `0x124a4a8` |
| `setShowcaseScore:` | `v24@0:8q16` | `0x124a4b0` |
| `.cxx_destruct` | `v16@0:8` | `0x124a4b8` |

## GMUUploadRequest

Image: `framework`。状態: metadata 確認。

| Selector | Type encoding | Static IMP |
| --- | --- | --- |
| `commonBlueprintCompletionBlock` | `@?16@0:8` | `0x1995b28` |
| `commonUploadFetcherDidCompleteWithData:error:` | `v32@0:8@16@24` | `0x1995e4c` |
| `commonCancel` | `v16@0:8` | `0x1996164` |
| `editType` | `i16@0:8` | `0x1a4bdcc` |
| `setEditType:` | `v20@0:8i16` | `0x1a4bddc` |
| `initWithCredentials:storagePolicy:delegate:` | `@36@0:8@16i24@28` | `0x1a4bf04` |
| `initWithCredentials:delegate:` | `@32@0:8@16@24` | `0x1a4bff8` |
| `initWithData:mimeType:creationDate:modificationDate:albumId:storagePolicy:credentials:delegate:` | `@76@0:8@16@24@32@40@48i56@60@68` | `0x1a4c004` |
| `start` | `v16@0:8` | `0x1a4c0f4` |
| `incrementLastProgressDate` | `v16@0:8` | `0x1a4c348` |
| `shouldTimeout` | `B16@0:8` | `0x1a4c3b0` |
| `cancel` | `v16@0:8` | `0x1a4c450` |
| `cleanup` | `v16@0:8` | `0x1a4c5ac` |
| `disableIntegrityChecks` | `v16@0:8` | `0x1a4c5b0` |
| `configureRequestProtoWithFingerprint:displayName:editList:videoEdits:creationDate:modificationDate:` | `v64@0:8@16@24@32@40@48@56` | `0x1a4c5c0` |
| `createRpcRequest` | `v16@0:8` | `0x1a4c5c4` |
| `uploadFetcherDidCompleteWithData:error:` | `v32@0:8@16@24` | `0x1a4c5c8` |
| `fetcherCompletionHandler` | `@?16@0:8` | `0x1a4c5cc` |
| `uploadFetcherDidProgress:totalBytesSent:totalBytesExpected:` | `v40@0:8@16q24q32` | `0x1a4c910` |
| `configureFetcherBlocks` | `v16@0:8` | `0x1a4c9e0` |
| `createFetcher` | `v16@0:8` | `0x1a4ccd0` |
| `replaceUploadFetcher:` | `v24@0:8@16` | `0x1a4cf64` |
| `startFetcher` | `v16@0:8` | `0x1a4d008` |
| `sessionFetcherUploadLocationObtainedNotification:` | `v24@0:8@16` | `0x1a4d150` |
| `didObtainUploadLocationURL:` | `v24@0:8@16` | `0x1a4d1d4` |
| `didCompleteWithSuccess:resultantMediaItem:error:` | `v36@0:8B16@20@28` | `0x1a4d1d8` |
| `delegate` | `@16@0:8` | `0x1a4d280` |
| `setDelegate:` | `v24@0:8@16` | `0x1a4d2a0` |
| `isCancelled` | `B16@0:8` | `0x1a4d2b4` |
| `uploadFileURL` | `@16@0:8` | `0x1a4d2c8` |
| `setUploadFileURL:` | `v24@0:8@16` | `0x1a4d2d8` |
| `fingerprints` | `@16@0:8` | `0x1a4d2e4` |
| `setFingerprints:` | `v24@0:8@16` | `0x1a4d2f4` |
| `requestQueue` | `@16@0:8` | `0x1a4d300` |
| `setRequestQueue:` | `v24@0:8@16` | `0x1a4d310` |
| `didStart` | `B16@0:8` | `0x1a4d31c` |
| `setDidStart:` | `v20@0:8B16` | `0x1a4d32c` |
| `purpose` | `i16@0:8` | `0x1a4d33c` |
| `setPurpose:` | `v20@0:8i16` | `0x1a4d34c` |
| `SHA1Base64Digest` | `@16@0:8` | `0x1a4d35c` |
| `applyIntegrityChecks` | `B16@0:8` | `0x1a4d36c` |
| `storagePolicy` | `i16@0:8` | `0x1a4d37c` |
| `creationDate` | `@16@0:8` | `0x1a4d38c` |
| `setCreationDate:` | `v24@0:8@16` | `0x1a4d39c` |
| `modificationDate` | `@16@0:8` | `0x1a4d3d8` |
| `setModificationDate:` | `v24@0:8@16` | `0x1a4d3e8` |
| `credentials` | `@16@0:8` | `0x1a4d424` |
| `setCredentials:` | `v24@0:8@16` | `0x1a4d434` |
| `urlRequest` | `@16@0:8` | `0x1a4d470` |
| `setUrlRequest:` | `v24@0:8@16` | `0x1a4d480` |
| `uploadFetcher` | `@16@0:8` | `0x1a4d4bc` |
| `progress` | `d16@0:8` | `0x1a4d4cc` |
| `setProgress:` | `v24@0:8d16` | `0x1a4d4dc` |
| `mimeType` | `@16@0:8` | `0x1a4d4ec` |
| `setMimeType:` | `v24@0:8@16` | `0x1a4d4fc` |
| `uploadData` | `@16@0:8` | `0x1a4d508` |
| `setUploadData:` | `v24@0:8@16` | `0x1a4d518` |
| `uploadLocationURL` | `@16@0:8` | `0x1a4d554` |
| `setUploadLocationURL:` | `v24@0:8@16` | `0x1a4d564` |
| `albumId` | `@16@0:8` | `0x1a4d5a0` |
| `setAlbumId:` | `v24@0:8@16` | `0x1a4d5b0` |
| `lastProgressDate` | `d16@0:8` | `0x1a4d5ec` |
| `setLastProgressDate:` | `v24@0:8d16` | `0x1a4d5fc` |
| `.cxx_destruct` | `v16@0:8` | `0x1a4d60c` |

## GMUAssetUploadRequest

Image: `framework`。状態: metadata 確認。

| Selector | Type encoding | Static IMP |
| --- | --- | --- |
| `initWithAsset:networkFetchAllowed:storagePolicy:credentials:delegate:` | `@48@0:8@16B24i28@32@40` | `0x1a20e24` |
| `shouldTimeout` | `B16@0:8` | `0x1a20f04` |
| `start` | `v16@0:8` | `0x1a20f60` |
| `fingerprintDidCompleteAfterDownload:error:` | `v32@0:8@16@24` | `0x1a21364` |
| `resumeAfterDownload` | `v16@0:8` | `0x1a214b4` |
| `fingerprintDidComplete:error:` | `v32@0:8@16@24` | `0x1a214fc` |
| `existenceCheckDidFailWithFingerprint:` | `v24@0:8@16` | `0x1a219e4` |
| `startRequestWithFingerprint:` | `v24@0:8@16` | `0x1a21c74` |
| `didCompleteWithSuccess:resultantMediaItem:error:` | `v36@0:8B16@20@28` | `0x1a2267c` |
| `SHA1Base64Digest` | `@16@0:8` | `0x1a228e0` |
| `cancel` | `v16@0:8` | `0x1a22920` |
| `asset` | `@16@0:8` | `0x1a22b78` |
| `didFailExistenceCheck` | `B16@0:8` | `0x1a22b88` |
| `setDidFailExistenceCheck:` | `v20@0:8B16` | `0x1a22b98` |
| `streamzCounter` | `@16@0:8` | `0x1a22ba8` |
| `progress` | `d16@0:8` | `0x1a22bb8` |
| `setProgress:` | `v24@0:8d16` | `0x1a22bc8` |
| `isCancelled` | `B16@0:8` | `0x1a22bd8` |
| `setIsCancelled:` | `v20@0:8B16` | `0x1a22bec` |
| `startTime` | `d16@0:8` | `0x1a22bfc` |
| `uploadRate` | `d16@0:8` | `0x1a22c0c` |
| `assetFetchNetworkAccessAllowed` | `B16@0:8` | `0x1a22c1c` |
| `isThumbnailUpload` | `B16@0:8` | `0x1a22c2c` |
| `videoAsset` | `@16@0:8` | `0x1a22c3c` |
| `setVideoAsset:` | `v24@0:8@16` | `0x1a22c4c` |
| `assetFingerprint` | `@16@0:8` | `0x1a22c88` |
| `setAssetFingerprint:` | `v24@0:8@16` | `0x1a22c98` |
| `uploadAsset` | `@16@0:8` | `0x1a22cd4` |
| `setUploadAsset:` | `v24@0:8@16` | `0x1a22ce4` |
| `.cxx_destruct` | `v16@0:8` | `0x1a22d20` |

## GMUUploadMediaRequest

Image: `framework`。状態: metadata 確認。

| Selector | Type encoding | Static IMP |
| --- | --- | --- |
| `initWithAsset:networkFetchAllowed:storagePolicy:credentials:delegate:` | `@48@0:8@16B24i28@32@40` | `0x19941d0` |
| `configureRequestProtoWithFingerprint:displayName:editList:videoEdits:creationDate:modificationDate:` | `v64@0:8@16@24@32@40@48@56` | `0x1994294` |
| `createUploadAttempt` | `v16@0:8` | `0x199461c` |
| `uploadAttempt` | `@16@0:8` | `0x1994710` |
| `uploadLocationURL` | `@16@0:8` | `0x19947dc` |
| `uploadFetcherDidCompleteWithData:error:` | `v32@0:8@16@24` | `0x1994830` |
| `cancel` | `v16@0:8` | `0x1994a98` |
| `createRpcRequest` | `v16@0:8` | `0x1994adc` |
| `shouldTimeout` | `B16@0:8` | `0x1994c5c` |
| `didObtainUploadLocationURL:` | `v24@0:8@16` | `0x1994cac` |
| `SHA1Base64Digest` | `@16@0:8` | `0x1994d9c` |
| `startCNDEUpload` | `v16@0:8` | `0x1994df8` |
| `uploadRequest:didCompleteWithError:resultantMediaItem:` | `v40@0:8@16@24@32` | `0x19954b0` |
| `uploadRequest:shouldUploadFingerprint:` | `B32@0:8@16@24` | `0x1995578` |
| `uploadRequestDidProgress:` | `v24@0:8@16` | `0x19955cc` |
| `uploadRequest:didStartDownloadForAsset:` | `v32@0:8@16@24` | `0x19955d0` |
| `uploadRequest:didCompleteWithBlobRef:` | `v32@0:8@16@24` | `0x1995624` |
| `allUploadsDidCompleteWithData:error:` | `v32@0:8@16@24` | `0x19956b4` |
| `blueprint` | `@16@0:8` | `0x19957c8` |
| `setBlueprint:` | `v24@0:8@16` | `0x19957d8` |
| `didCompleteUploadMedia` | `B16@0:8` | `0x1995814` |
| `setDidCompleteUploadMedia:` | `v20@0:8B16` | `0x1995824` |
| `uploadMediaMetadata` | `@16@0:8` | `0x1995834` |
| `setUploadMediaMetadata:` | `v24@0:8@16` | `0x1995844` |
| `uploadRate` | `d16@0:8` | `0x1995880` |
| `setUploadRate:` | `v24@0:8d16` | `0x1995890` |
| `setUploadAttempt:` | `v24@0:8@16` | `0x19958a0` |
| `db` | `@16@0:8` | `0x19958dc` |
| `setDb:` | `v24@0:8@16` | `0x19958ec` |
| `originalBytesScottyUploadTokenData` | `@16@0:8` | `0x1995928` |
| `setOriginalBytesScottyUploadTokenData:` | `v24@0:8@16` | `0x1995938` |
| `editedBytesUploadRequest` | `@16@0:8` | `0x1995974` |
| `setEditedBytesUploadRequest:` | `v24@0:8@16` | `0x1995984` |
| `editList` | `@16@0:8` | `0x19959c0` |
| `setEditList:` | `v24@0:8@16` | `0x19959d0` |
| `.cxx_destruct` | `v16@0:8` | `0x1995a0c` |

## GMULivePhotoSingleUploadRequest

Image: `framework`。状態: metadata 確認。

| Selector | Type encoding | Static IMP |
| --- | --- | --- |
| `initWithAsset:networkFetchAllowed:storagePolicy:credentials:delegate:` | `@48@0:8@16B24i28@32@40` | `0x197cb10` |
| `dealloc` | `v16@0:8` | `0x197ccb4` |
| `didStart` | `B16@0:8` | `0x197cd30` |
| `start` | `v16@0:8` | `0x197cdcc` |
| `cancel` | `v16@0:8` | `0x197cf1c` |
| `disableIntegrityChecks` | `v16@0:8` | `0x197d018` |
| `shouldTimeout` | `B16@0:8` | `0x197d028` |
| `progress` | `d16@0:8` | `0x197d0c4` |
| `logIntegrityChecksNotAppliedWithBlobType:` | `v24@0:8Q16` | `0x197d1d0` |
| `didCompleteWithError:resultantMediaItem:` | `v32@0:8@16@24` | `0x197d2a4` |
| `incrementProgressDate` | `v16@0:8` | `0x197d4f0` |
| `startPhotoFingerprint` | `v16@0:8` | `0x197d568` |
| `startLegacyUploadFlow:` | `v24@0:8@16` | `0x197dfb0` |
| `startPhotoUpload:` | `v24@0:8@16` | `0x197e084` |
| `startVideoFingerprint` | `v16@0:8` | `0x197e574` |
| `startVideoUpload:` | `v24@0:8@16` | `0x197ed64` |
| `createLivePhotoMediaItem` | `v16@0:8` | `0x197f1e4` |
| `configureRequestProtoWithFingerprint:displayName:editList:videoEdits:creationDate:modificationDate:` | `v64@0:8@16@24@32@40@48@56` | `0x197f3e0` |
| `updateAssetAnalyticsFileSize:` | `v24@0:8Q16` | `0x197fa3c` |
| `uploadRequest:shouldUploadPairedVideoForPhotoFingerprint:` | `B32@0:8@16@24` | `0x197faec` |
| `uploadRequestShouldUseBackgroundUploadPath:` | `B24@0:8@16` | `0x197fb54` |
| `uploadRequest:didCompleteWithBlobRef:` | `v32@0:8@16@24` | `0x197fb94` |
| `uploadRequest:didCompleteWithError:resultantMediaItem:` | `v40@0:8@16@24@32` | `0x197fca8` |
| `uploadRequestDidProgress:` | `v24@0:8@16` | `0x197ff74` |
| `uploadRequest:shouldUploadFingerprint:` | `B32@0:8@16@24` | `0x1980054` |
| `uploadRequest:didDiscoverFingerprintExists:mediaKey:` | `v40@0:8@16@24@32` | `0x19800f4` |
| `uploadRequestAssetStateForAsset:` | `@24@0:8@16` | `0x198027c` |
| `assetEditedSinceRequestStarted` | `B16@0:8` | `0x1980320` |
| `uploadRequest:didStartDownloadForAsset:` | `v32@0:8@16@24` | `0x198045c` |
| `asset` | `@16@0:8` | `0x19804b8` |
| `credentials` | `@16@0:8` | `0x19804c8` |
| `delegate` | `@16@0:8` | `0x19804d8` |
| `setDelegate:` | `v24@0:8@16` | `0x19804f8` |
| `didFailExistenceCheck` | `B16@0:8` | `0x198050c` |
| `fingerprints` | `@16@0:8` | `0x198051c` |
| `setFingerprints:` | `v24@0:8@16` | `0x198052c` |
| `isCancelled` | `B16@0:8` | `0x1980538` |
| `purpose` | `i16@0:8` | `0x198054c` |
| `setPurpose:` | `v20@0:8i16` | `0x198055c` |
| `requestQueue` | `@16@0:8` | `0x198056c` |
| `setRequestQueue:` | `v24@0:8@16` | `0x198057c` |
| `useLegacyFlow` | `B16@0:8` | `0x1980588` |
| `setUseLegacyFlow:` | `v20@0:8B16` | `0x198059c` |
| `applyIntegrityChecks` | `B16@0:8` | `0x19805ac` |
| `SHA1Base64Digest` | `@16@0:8` | `0x19805bc` |
| `setSHA1Base64Digest:` | `v24@0:8@16` | `0x19805cc` |
| `editType` | `i16@0:8` | `0x1980608` |
| `streamzCounter` | `@16@0:8` | `0x1980618` |
| `uploadRate` | `d16@0:8` | `0x1980628` |
| `lastProgressDate` | `@16@0:8` | `0x1980638` |
| `setLastProgressDate:` | `v24@0:8@16` | `0x1980648` |
| `networkFetchAllowed` | `B16@0:8` | `0x1980654` |
| `legacyLivePhotoUpload` | `@16@0:8` | `0x1980664` |
| `setLegacyLivePhotoUpload:` | `v24@0:8@16` | `0x1980674` |
| `storagePolicy` | `i16@0:8` | `0x1980680` |
| `setStoragePolicy:` | `v20@0:8i16` | `0x1980690` |
| `legacyLivePhotoFingerprint` | `@16@0:8` | `0x19806a0` |
| `setLegacyLivePhotoFingerprint:` | `v24@0:8@16` | `0x19806b0` |
| `photoUpload` | `@16@0:8` | `0x19806bc` |
| `setPhotoUpload:` | `v24@0:8@16` | `0x19806cc` |
| `photoFingerprint` | `@16@0:8` | `0x19806d8` |
| `setPhotoFingerprint:` | `v24@0:8@16` | `0x19806e8` |
| `photoBlobRef` | `@16@0:8` | `0x19806f4` |
| `setPhotoBlobRef:` | `v24@0:8@16` | `0x1980704` |
| `videoUpload` | `@16@0:8` | `0x1980710` |
| `setVideoUpload:` | `v24@0:8@16` | `0x1980720` |
| `videoFingerprint` | `@16@0:8` | `0x198072c` |
| `setVideoFingerprint:` | `v24@0:8@16` | `0x198073c` |
| `videoBlobRef` | `@16@0:8` | `0x1980748` |
| `setVideoBlobRef:` | `v24@0:8@16` | `0x1980758` |
| `lastProgress` | `d16@0:8` | `0x1980764` |
| `setLastProgress:` | `v24@0:8d16` | `0x1980774` |
| `editList` | `@16@0:8` | `0x1980784` |
| `setEditList:` | `v24@0:8@16` | `0x1980794` |
| `uneditedLivePhoto` | `@16@0:8` | `0x19807d0` |
| `setUneditedLivePhoto:` | `v24@0:8@16` | `0x19807e0` |
| `.cxx_destruct` | `v16@0:8` | `0x198081c` |

## GMUThumbnailUploadRequest

Image: `framework`。状態: metadata 確認。

| Selector | Type encoding | Static IMP |
| --- | --- | --- |
| `configureRequestProtoWithFingerprint:displayName:editList:videoEdits:creationDate:modificationDate:` | `v64@0:8@16@24@32@40@48@56` | `0x198ed08` |
| `dealloc` | `v16@0:8` | `0x198ed8c` |
| `setMaximumQualityAndResolution` | `v16@0:8` | `0x198edd0` |
| `uploadLocationURL` | `@16@0:8` | `0x198eea8` |
| `createUploadAttempt` | `v16@0:8` | `0x198eeb0` |
| `uploadAttempt` | `@16@0:8` | `0x198eeb4` |
| `isThumbnailUpload` | `B16@0:8` | `0x198eebc` |
| `setUploadAttempt:` | `v24@0:8@16` | `0x198eec4` |
| `startRequestWithFingerprint:` | `v24@0:8@16` | `0x198eec8` |
| `lowResVideoFingerprintDidCompleteWithSuccess:fingerprint:` | `v28@0:8B16@20` | `0x198f244` |
| `cancel` | `v16@0:8` | `0x198f4c8` |
| `maxPixelCount` | `d16@0:8` | `0x198f534` |
| `compressionRatio` | `d16@0:8` | `0x198f554` |
| `generateLowResVideoWithCompletion:` | `v24@0:8@?16` | `0x198f65c` |
| `deleteLowResVideoFile` | `v16@0:8` | `0x198f7c0` |
| `SHA1Base64Digest` | `@16@0:8` | `0x198fb10` |
| `setMaxPixelCount:` | `v24@0:8d16` | `0x198fb18` |
| `setCompressionRatio:` | `v24@0:8d16` | `0x198fb28` |
| `.cxx_destruct` | `v16@0:8` | `0x198fb38` |

## GMUUploadRequestCredentials

Image: `framework`。状態: metadata 確認。

| Selector | Type encoding | Static IMP |
| --- | --- | --- |
| `initWithAccountID:authorizer:` | `@32@0:8@16@24` | `0x1a4d7ac` |
| `initWithAccountID:authorizer:cellularBlock:` | `@40@0:8@16@24@?32` | `0x1a4d7c0` |
| `authorizer` | `@16@0:8` | `0x1a4d888` |
| `testBlock` | `@?16@0:8` | `0x1a4d898` |
| `setTestBlock:` | `v24@0:8@?16` | `0x1a4d8a8` |
| `urlSessionConfigurationBlock` | `@?16@0:8` | `0x1a4d8b4` |
| `setUrlSessionConfigurationBlock:` | `v24@0:8@?16` | `0x1a4d8c4` |
| `shouldAllowCellularBlock` | `@?16@0:8` | `0x1a4d8d0` |
| `setShouldAllowCellularBlock:` | `v24@0:8@?16` | `0x1a4d8e0` |
| `featureFlags` | `@16@0:8` | `0x1a4d8ec` |
| `.cxx_destruct` | `v16@0:8` | `0x1a4d8fc` |

## GMUUploadAsset

Image: `framework`。状態: metadata 確認。

| Selector | Type encoding | Static IMP |
| --- | --- | --- |
| `initWithData:videoAsset:contentLength:mimeType:asset:isThumbnail:purpose:storagePolicy:sha1Digest:` | `@76@0:8@16@24q32@40@48B56i60i64@68` | `0x1a297c0` |
| `init` | `@16@0:8` | `0x4cbee64` |
| `.cxx_destruct` | `v16@0:8` | `0x1a29908` |

## GMUUploadMediaRequestQueueImpl

Image: `framework`。状態: metadata 確認。

| Selector | Type encoding | Static IMP |
| --- | --- | --- |
| `initWithAccountID:` | `@24@0:8@16` | `0x1a1fff4` |
| `maxConcurrentRequests` | `Q16@0:8` | `0x1a20058` |

## GMUUserInitiatedUploadRequestQueueImpl

Image: `framework`。状態: metadata 確認。

| Selector | Type encoding | Static IMP |
| --- | --- | --- |
| `initWithAccountID:` | `@24@0:8@16` | `0x1a20228` |
| `maxConcurrentRequests` | `Q16@0:8` | `0x1a2028c` |

## PHSLockedPhotoMediaUploadRequest

Image: `framework`。状態: metadata 確認。

| Selector | Type encoding | Static IMP |
| --- | --- | --- |
| `initWithAsset:storagePolicy:credentials:delegate:` | `@44@0:8@16i24@28@36` | `0x3ee4a4` |
| `lockedPhotoDelegate` | `@16@0:8` | `0x3ee588` |
| `start` | `v16@0:8` | `0x3ee58c` |
| `fingerprintAndData` | `@16@0:8` | `0x3ee74c` |
| `fingerprinterDidComplete:` | `v24@0:8@16` | `0x3eec1c` |
| `existenceRequestCompletionBlockWithFingerprint:` | `@?24@0:8@16` | `0x3eedf4` |
| `didCompleteWithError:resultantMediaItem:` | `v32@0:8@16@24` | `0x3eefb4` |
| `existenceCheckDidFailWithFingerprint:` | `v24@0:8@16` | `0x3eeff4` |
| `startRequestWithLockedPhotoFingerprint:` | `v24@0:8@16` | `0x3ef068` |
| `configureRequestProtoWithFingerprint:displayName:editList:videoEdits:creationDate:modificationDate:` | `v64@0:8@16@24@32@40@48@56` | `0x3ef4f8` |
| `createRpcRequestForFingerprint:` | `v24@0:8@16` | `0x3ef7dc` |
| `uploadFetcherDidCompleteWithData:error:` | `v32@0:8@16@24` | `0x3ef830` |
| `allUploadsDidCompleteWithData:error:` | `v32@0:8@16@24` | `0x3ef834` |
| `blueprintCompletionBlock` | `@?16@0:8` | `0x3ef8c4` |
| `blueprint` | `@16@0:8` | `0x3efba8` |
| `setBlueprint:` | `v24@0:8@16` | `0x3efbb8` |
| `didCompleteUploadMedia` | `B16@0:8` | `0x3efbf4` |
| `setDidCompleteUploadMedia:` | `v20@0:8B16` | `0x3efc04` |
| `uploadMediaMetadata` | `@16@0:8` | `0x3efc14` |
| `setUploadMediaMetadata:` | `v24@0:8@16` | `0x3efc24` |
| `SHA1Base64Digest` | `@16@0:8` | `0x3efc60` |
| `asset` | `@16@0:8` | `0x3efc70` |
| `setAsset:` | `v24@0:8@16` | `0x3efc80` |
| `didFailExistenceCheck` | `B16@0:8` | `0x3efcbc` |
| `setDidFailExistenceCheck:` | `v20@0:8B16` | `0x3efccc` |
| `assetFingerprint` | `@16@0:8` | `0x3efcdc` |
| `setAssetFingerprint:` | `v24@0:8@16` | `0x3efcec` |
| `streamzCounter` | `@16@0:8` | `0x3efd28` |
| `.cxx_destruct` | `v16@0:8` | `0x3efd38` |

## PHSLockedPhotoLivePhotoSingleUploadRequest

Image: `framework`。状態: metadata 確認。

| Selector | Type encoding | Static IMP |
| --- | --- | --- |
| `initWithAsset:storagePolicy:credentials:delegate:` | `@44@0:8@16i24@28@36` | `0x3eb858` |
| `dealloc` | `v16@0:8` | `0x3eb94c` |
| `lockedPhotoDelegate` | `@16@0:8` | `0x3eb9c8` |
| `didFailExistenceCheck` | `B16@0:8` | `0x3eb9cc` |
| `didStart` | `B16@0:8` | `0x3eba04` |
| `start` | `v16@0:8` | `0x3ebaa0` |
| `cancel` | `v16@0:8` | `0x3ebb5c` |
| `shouldTimeout` | `B16@0:8` | `0x3ebc58` |
| `progress` | `d16@0:8` | `0x3ebcf4` |
| `blueprintDidCompleteWithSuccess:resultantMediaItem:error:` | `v36@0:8B16@20@28` | `0x3ebe00` |
| `didCompleteWithError:resultantMediaItem:` | `v32@0:8@16@24` | `0x3ebe08` |
| `incrementProgressDate` | `v16@0:8` | `0x3ec024` |
| `fingerprintAndDataPairedVideo:` | `@20@0:8B16` | `0x3ec09c` |
| `startPhotoFingerprint` | `v16@0:8` | `0x3ec5f8` |
| `photoFingerprinterDidComplete:` | `v24@0:8@16` | `0x3ec7c4` |
| `existenceRequestCompletionBlockWithPhotoFingerprint:` | `@?24@0:8@16` | `0x3ec9c8` |
| `existenceCheckDidFailWithPhotoFingerprint:` | `v24@0:8@16` | `0x3ecbe4` |
| `startPhotoUpload:` | `v24@0:8@16` | `0x3ecc58` |
| `startVideoFingerprint` | `v16@0:8` | `0x3ece38` |
| `videoFingerprinterDidComplete:` | `v24@0:8@16` | `0x3ed010` |
| `existenceRequestCompletionBlockWithVideoFingerprint:` | `@?24@0:8@16` | `0x3ed188` |
| `existenceCheckDidFailWithVideoFingerprint:` | `v24@0:8@16` | `0x3ed348` |
| `startVideoUpload:` | `v24@0:8@16` | `0x3ed3bc` |
| `createLivePhotoMediaItem` | `v16@0:8` | `0x3ed5cc` |
| `configureRequestProtoWithFingerprint:displayName:editList:videoEdits:creationDate:modificationDate:` | `v64@0:8@16@24@32@40@48@56` | `0x3ed718` |
| `SHA1Base64Digest` | `@16@0:8` | `0x3edcf0` |
| `uploadRequest:didCompleteWithBlobRef:` | `v32@0:8@16@24` | `0x3edd30` |
| `uploadRequest:didCompleteWithError:resultantMediaItem:` | `v40@0:8@16@24@32` | `0x3ede44` |
| `uploadRequestDidProgress:` | `v24@0:8@16` | `0x3ee0d0` |
| `uploadComponentDidProgress:` | `v24@0:8@16` | `0x3ee0d4` |
| `uploadRequest:shouldUploadFingerprint:` | `B32@0:8@16@24` | `0x3ee188` |
| `uploadRequest:didStartDownloadForAsset:` | `v32@0:8@16@24` | `0x3ee274` |
| `asset` | `@16@0:8` | `0x3ee278` |
| `isCancelled` | `B16@0:8` | `0x3ee288` |
| `didFailPhotoExistenceCheck` | `B16@0:8` | `0x3ee29c` |
| `setDidFailPhotoExistenceCheck:` | `v20@0:8B16` | `0x3ee2b0` |
| `didFailVideoExistenceCheck` | `B16@0:8` | `0x3ee2c0` |
| `setDidFailVideoExistenceCheck:` | `v20@0:8B16` | `0x3ee2d4` |
| `photoUpload` | `@16@0:8` | `0x3ee2e4` |
| `setPhotoUpload:` | `v24@0:8@16` | `0x3ee2f4` |
| `videoUpload` | `@16@0:8` | `0x3ee300` |
| `setVideoUpload:` | `v24@0:8@16` | `0x3ee310` |
| `photoFingerprint` | `@16@0:8` | `0x3ee31c` |
| `setPhotoFingerprint:` | `v24@0:8@16` | `0x3ee32c` |
| `videoFingerprint` | `@16@0:8` | `0x3ee338` |
| `setVideoFingerprint:` | `v24@0:8@16` | `0x3ee348` |
| `photoBlobRef` | `@16@0:8` | `0x3ee354` |
| `setPhotoBlobRef:` | `v24@0:8@16` | `0x3ee364` |
| `videoBlobRef` | `@16@0:8` | `0x3ee370` |
| `setVideoBlobRef:` | `v24@0:8@16` | `0x3ee380` |
| `lastProgressDate` | `@16@0:8` | `0x3ee38c` |
| `setLastProgressDate:` | `v24@0:8@16` | `0x3ee39c` |
| `lastProgress` | `d16@0:8` | `0x3ee3a8` |
| `setLastProgress:` | `v24@0:8d16` | `0x3ee3b8` |
| `streamzCounter` | `@16@0:8` | `0x3ee3c8` |
| `.cxx_destruct` | `v16@0:8` | `0x3ee3d8` |
