#import "SerializeUtils.h"

@implementation SerializeUtils 
+ (NSDictionary *) transceiverToJSONWithPeerConnectionId: (NSNumber *) id
                                                           transceiver:(RTCRtpTransceiver * _Nonnull) transceiver {
    NSMutableDictionary *result = [NSMutableDictionary new];
   
    result[@"id"] = transceiver.sender.senderId;
    result[@"peerConnectionId"] = id;
    result[@"mid"] = transceiver.mid;
    result[@"direction"] = [SerializeUtils serializeDirection: transceiver.direction];
    
    RTCRtpTransceiverDirection currentDirection;
    if ([transceiver currentDirection: &currentDirection]) {
        result[@"currentDirection"] = [SerializeUtils serializeDirection: currentDirection];
    }
    
    result[@"isStopped"] = [NSNumber numberWithBool:transceiver.isStopped];
    result[@"receiver"] = [SerializeUtils receiverToJSONWithPeerConnectionId: id receiver: transceiver.receiver];
    result[@"sender"] = [SerializeUtils senderToJSONWithPeerConnectionId: id sender: transceiver.sender];
                                                               
    return result;
}

+ (NSMutableArray *) constructTransceiversInfoArrayWithPeerConnection: (RTCPeerConnection *) peerConnection
                                                   peerConnectionId: (NSNumber *) peerConnectionId {
    NSMutableArray *transceiverUpdates = [NSMutableArray new];
    
    for (RTCRtpTransceiver *transceiver in peerConnection.transceivers) {
        RTCRtpTransceiverDirection currentDirection;
        if ([transceiver currentDirection: &currentDirection]) {
            NSMutableDictionary *transceiverUpdate= [NSMutableDictionary new];
            transceiverUpdate[@"transceiverId"] = transceiver.sender.senderId;
            transceiverUpdate[@"peerConnectionId"] = peerConnectionId;
            transceiverUpdate[@"mid"] = transceiver.mid;
            NSString *currentDirectionSerialized = [SerializeUtils serializeDirection: currentDirection];
            transceiverUpdate[@"currentDirection"] = currentDirectionSerialized;
            transceiverUpdate[@"senderRtpParameters"] = [SerializeUtils parametersToJSON:transceiver.sender.parameters];
            
            [transceiverUpdates addObject:transceiverUpdate];
        }
    }
                                                               
    return transceiverUpdates;
}


+ (NSDictionary *) senderToJSONWithPeerConnectionId: (NSNumber *) id
                                            sender: (RTCRtpSender *) sender {
    NSMutableDictionary *senderDictionary= [NSMutableDictionary new];
    senderDictionary[@"id"] = sender.senderId;
    senderDictionary[@"peerConnectionId"] = id;

    if (sender.track) {
        senderDictionary[@"track"] = [SerializeUtils trackToJSONWithPeerConnectionId: id track: sender.track];
    }

    senderDictionary[@"rtpParameters"] = [SerializeUtils parametersToJSON: sender.parameters];
   
   return senderDictionary;
}

+ (NSDictionary *) receiverToJSONWithPeerConnectionId: (NSNumber *) id
                                            receiver: (RTCRtpReceiver *) receiver {
    NSMutableDictionary *receiverDictionary = [NSMutableDictionary new];
    receiverDictionary[@"id"] = receiver.receiverId;
    receiverDictionary[@"peerConnectionId"] = id;

    if (receiver.track) {
        receiverDictionary[@"track"] = [SerializeUtils trackToJSONWithPeerConnectionId: id track: receiver.track];
    }
   
   return receiverDictionary;
}

+ (NSDictionary *) parametersToJSON: (RTCRtpParameters *) params {
    NSMutableDictionary *paramsDictionary = [NSMutableDictionary new];
    
    NSMutableDictionary *rtcpDictionary = [NSMutableDictionary new];
    rtcpDictionary[@"cname"] = params.rtcp.cname;
    rtcpDictionary[@"reducedSize"] = [NSNumber numberWithBool: params.rtcp.isReducedSize];
    
    NSMutableArray *headerExtensions = [NSMutableArray new];
    
    for (RTCRtpHeaderExtension *extension in params.headerExtensions) {
        NSMutableDictionary *extensionDictionary = [NSMutableDictionary new];
        extensionDictionary[@"id"] = [NSNumber numberWithInt: extension.id];
        extensionDictionary[@"uri"] = extension.uri;
        extensionDictionary[@"encrypted"] = [NSNumber numberWithBool: extension.isEncrypted];
        
        [headerExtensions addObject: extensionDictionary];
    }
    
    NSMutableArray *encodings = [NSMutableArray new];
    
    for (RTCRtpEncodingParameters *encoding in params.encodings) {
        NSMutableDictionary *encodingDictionary = [NSMutableDictionary new];
        
        encodingDictionary[@"active"] = [NSNumber numberWithBool: encoding.isActive];
               
        if (encoding.maxBitrateBps) {
            encodingDictionary[@"maxBitrate"] = encoding.maxBitrateBps;
        }
        if (encoding.maxFramerate) {
            encodingDictionary[@"maxFramerate"] = encoding.maxFramerate;
        }
        if (encoding.scaleResolutionDownBy) {
            encodingDictionary[@"scaleResolutionDownBy"] = encoding.scaleResolutionDownBy;
        }
        
        [encodings addObject: encodingDictionary];
    }

    NSMutableArray *codecs = [NSMutableArray new];
    
    for (RTCRtpCodecParameters *codec in params.codecs) {
        NSMutableDictionary *codecDictionary = [NSMutableDictionary new];
        
        codecDictionary[@"payloadType"] = [NSNumber numberWithInt: codec.payloadType];
        codecDictionary[@"mimeType"] = codec.name;
        codecDictionary[@"clockRate"] = codec.clockRate;
        
        if (codec.numChannels) {
            codecDictionary[@"channels"] = codec.numChannels;
        }
        
        codecDictionary[@"sdpFmtpLine"] = codec.parameters;

        [codecs addObject: codecDictionary];
    }

    paramsDictionary[@"transactionId"] = params.transactionId;
    paramsDictionary[@"rtcp"] = rtcpDictionary;
    paramsDictionary[@"headerExtensions"] = headerExtensions;
    paramsDictionary[@"encodings"] = encodings;
    paramsDictionary[@"codecs"] = codecs;
    
    if (params.degradationPreference) {
        paramsDictionary[@"degradationPreference"] = params.degradationPreference;
    }
    
    return paramsDictionary;
}

+ (NSDictionary *) trackToJSONWithPeerConnectionId: (NSNumber *) id
                                            track: (RTCMediaStreamTrack *) track {
    NSString *readyState;
    switch (track.readyState) {
        case RTCMediaStreamTrackStateLive:
            readyState = @"Live";
        case RTCMediaStreamTrackStateEnded:
            readyState = @"Ended";
    }
    
    return @{
        @"id": track.trackId,
        @"peerConnectionId": id,
        @"kind": track.kind,
        @"enabled": [NSNumber numberWithBool:track.isEnabled],
        @"readyState":  readyState,
        @"remote": [NSNumber numberWithBool:YES],
    };
}

+ (NSString *) serializeDirection: (RTCRtpTransceiverDirection) direction {
    if (direction == RTCRtpTransceiverDirectionInactive) {
        return @"inactive";
    } else if (direction == RTCRtpTransceiverDirectionRecvOnly) {
        return @"recvonly";
    } else if (direction == RTCRtpTransceiverDirectionSendOnly) {
        return @"sendonly";
    } else if (direction == RTCRtpTransceiverDirectionSendRecv) {
        return @"sendrecv";
    } else if (direction == RTCRtpTransceiverDirectionStopped) {
        return @"stopped";
    }
    return nil;
}

+ (RTCRtpTransceiverDirection) parseDirection: (NSString *) direction {
    if ([direction  isEqual: @"inactive"]) {
        return RTCRtpTransceiverDirectionInactive;
    } else if ([direction  isEqual: @"recvonly"]) {
        return RTCRtpTransceiverDirectionRecvOnly;
    } else if ([direction  isEqual: @"sendonly"]) {
        return RTCRtpTransceiverDirectionSendOnly;
    } else if ([direction  isEqual: @"sendrecv"]) {
        return RTCRtpTransceiverDirectionSendRecv;
    } else if ([direction  isEqual: @"stopped"]) {
        return RTCRtpTransceiverDirectionStopped;
    }
    
    return RTCRtpTransceiverDirectionInactive;
}


+ (NSDictionary *)streamToJSONWithPeerConnectionId: (NSNumber *) id
                                                stream: (RTCMediaStream *) stream
                                                streamReactTag: (NSString *) streamReactTag {
    NSMutableDictionary *streamDictionary = [NSMutableDictionary new];
    
    streamDictionary[@"streamId"] = stream.streamId;
    streamDictionary[@"streamReactTag"] = streamReactTag;

    NSMutableArray *tracks = [NSMutableArray new];
    
    for (RTCAudioTrack *audioTrack in stream.audioTracks) {
        [tracks addObject:[SerializeUtils trackToJSONWithPeerConnectionId:id track:audioTrack]];
    }
    
    for (RTCVideoTrack *videoTrack in stream.videoTracks) {
        [tracks addObject:[SerializeUtils trackToJSONWithPeerConnectionId:id track:videoTrack]];
    }
                                                    
    streamDictionary[@"tracks"] = tracks;
    
    return streamDictionary;
}
@end
