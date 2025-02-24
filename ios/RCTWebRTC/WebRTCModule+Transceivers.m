#import <objc/runtime.h>

#import <React/RCTBridge.h>
#import <React/RCTBridgeModule.h>

#import <WebRTC/RTCRtpSender.h>
#import <WebRTC/RTCRtpReceiver.h>

#import "WebRTCModule.h"
#import "SerializeUtils.h"

@implementation WebRTCModule (Transceivers)

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(senderGetCapabilities)
{
    __block id params;

    dispatch_sync(self.workerQueue, ^{
        NSMutableArray *videoCodecs = [NSMutableArray new];
        for(RTCVideoCodecInfo * videoCodecInfo in [self.encoderFactory supportedCodecs]) {
            [videoCodecs addObject:@{
                @"mimeType": [NSString stringWithFormat:@"video/%@", videoCodecInfo.name]
            }];
        }
        
        params = @{
            @"codecs":videoCodecs
        };
    });

    return params;
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(receiverGetCapabilities)
{
    __block id params;

    dispatch_sync(self.workerQueue, ^{
        NSMutableArray *videoCodecs = [NSMutableArray new];
        for(RTCVideoCodecInfo * videoCodecInfo in [self.decoderFactory supportedCodecs]) {
            [videoCodecs addObject:@{
                @"mimeType": [NSString stringWithFormat:@"video/%@", videoCodecInfo.name]
            }];
        }
        
        params = @{
            @"codecs":videoCodecs
        };
    });

    return params;
}

RCT_EXPORT_METHOD(senderReplaceTrack:(nonnull NSNumber *) objectID
                            senderId:(NSString *)senderId
                            trackId:(NSString *)trackId
                            resolver:(RCTPromiseResolveBlock)resolve
                            rejecter:(RCTPromiseRejectBlock)reject)
{
        RTCPeerConnection *peerConnection = self.peerConnections[objectID];

        if (peerConnection == nil) {
            RCTLogWarn(@"PeerConnection %@ not found in senderReplaceTrack()", objectID);
            reject(@"E_INVALID", @"Peer Connection is not initialized", nil);
        }

        RTCRtpTransceiver *transceiver = nil;
        for (RTCRtpTransceiver *t in peerConnection.transceivers) {
            if ([senderId isEqual: t.sender.senderId]) {
                transceiver = t;
                break;
            }
        }

        if (transceiver == nil) {
            RCTLogWarn(@"senderReplaceTrack() transceiver is null");
            reject(@"E_INVALID", @"Could not get transceive", nil);
        }
        
        RTCRtpSender *sender = transceiver.sender;
        RTCMediaStreamTrack *track = self.localTracks[trackId];
        [sender setTrack:track];
        resolve(@true);
}

RCT_EXPORT_METHOD(senderSetParameters:(nonnull NSNumber *) objectID
                            senderId:(NSString *)senderId
                            options:(NSDictionary *)options
                            resolver:(RCTPromiseResolveBlock)resolve
                            rejecter:(RCTPromiseRejectBlock)reject)
{
        RTCPeerConnection *peerConnection = self.peerConnections[objectID];

        if (peerConnection == nil) {
            RCTLogWarn(@"PeerConnection %@ not found in senderSetParameters()", objectID);
            reject(@"E_INVALID", @"Peer Connection is not initialized", nil);
        }

        RTCRtpTransceiver *transceiver = nil;
        for (RTCRtpTransceiver *t in peerConnection.transceivers) {
            if ([senderId isEqual: t.sender.senderId]) {
                transceiver = t;
                break;
            }
        }

        if (transceiver == nil) {
            RCTLogWarn(@"senderSetParameters() transceiver is null");
            reject(@"E_INVALID", @"Could not get transceive", nil);
        }
        
        RTCRtpSender *sender = transceiver.sender;
        RTCRtpParameters *parameters = sender.parameters;
        [sender setParameters:[self updateParametersWithOptions: options params: parameters]];
}

RCT_EXPORT_METHOD(transceiverSetDirection:(nonnull NSNumber *) objectID
                            senderId:(NSString *)senderId
                            direction:(NSString *)direction)
{
        RTCPeerConnection *peerConnection = self.peerConnections[objectID];

        if (peerConnection == nil) {
            RCTLogWarn(@"transceiverSetDirection() PeerConnection %@ not found in transceiverSetDirection()", objectID);
            return;
        }

        RTCRtpTransceiver *transceiver = nil;
        for (RTCRtpTransceiver *t in peerConnection.transceivers) {
            if ([senderId isEqual: t.sender.senderId]) {
                transceiver = t;
                break;
            }
        }

        if (transceiver == nil) {
            RCTLogWarn(@"transceiverSetDirection() transceiver is null");
            return;
        }
        
        NSMutableDictionary *identifier = [NSMutableDictionary new];
        identifier[@"peerConnectionId"] = objectID;
        identifier[@"transceiverId"] = senderId;
        
        NSMutableDictionary *params = [NSMutableDictionary new];
        RTCRtpTransceiverDirection oldDirrection = transceiver.direction;
        params[@"oldDirection"] = [SerializeUtils serializeDirection: oldDirrection];
        NSError *error;
        [transceiver setDirection:[SerializeUtils parseDirection:direction] error: &error];
        
        if (error) {
            [self sendErrorWithEventName: kEventTransceiverOnError
                                funcName: @"transceiverSetDirection"
                                 message: [error localizedDescription]
                                    info: nil];
        }
}

RCT_EXPORT_METHOD(transceiverStop:(nonnull NSNumber *) objectID
                            senderId:(NSString *)senderId)
{
        RTCPeerConnection *peerConnection = self.peerConnections[objectID];

        if (peerConnection == nil) {
            RCTLogWarn(@"PeerConnection %@ not found in transceiverStop()", objectID);
            return;
        }

        RTCRtpTransceiver *transceiver = nil;
        for (RTCRtpTransceiver *t in peerConnection.transceivers) {
            if ([senderId isEqual: t.sender.senderId]) {
                transceiver = t;
                break;
            }
        }

        if (transceiver == nil) {
            RCTLogWarn(@"senderSetParameters() transceiver is null");
            return;
        }

        [transceiver stopInternal];
        [self sendEventWithName:kEventTransceiverStopSuccessful
                              body:@{
                                @"peerConnectionId": objectID,
                                @"transceiverId": senderId
                              }];
}

- (RTCRtpParameters *) updateParametersWithOptions: (NSDictionary *) options
                                        params: (RTCRtpParameters *) params{
    NSArray *encodingsArray = options[@"encodings"];
    NSArray *encodings = params.encodings;
    
    if ([encodingsArray count] != [encodings count]) {
        return nil;
    }
    
    for (int i = 0; i < [encodingsArray count]; i++) {
        NSDictionary *encodingUpdate = encodingsArray[i];
        RTCRtpEncodingParameters *encoding = encodings[i];
        
        [encoding setIsActive: encodingUpdate[@"active"]];
        encoding.maxBitrateBps = encodingUpdate[@"maxBitrate"];
        encoding.maxFramerate =  encodingUpdate[@"maxFramerate"];
        encoding.scaleResolutionDownBy = encodingUpdate[@"scaleResolutionDownBy"];
    }
    
    if ([options objectForKey:@"degradationPreference"]) {
        params.degradationPreference = [options objectForKey:@"degradationPreference"];
    }
    
    return params;
}

@end
