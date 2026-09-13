#import "GSLocalization.h"
#import "IPCProtocol.h"
#include <stddef.h>
#import "GSMachTransport.h"

static kern_return_t GSLookupDaemon(mach_port_t *server) {
 // Prefer direct / redirected launchd lookup before the compatibility broker.
 kern_return_t kr=bootstrap_look_up(bootstrap_port,GS_SERVICE,server);
 if(kr==KERN_SUCCESS)return kr;
 kr=bootstrap_look_up(bootstrap_port,"cy:rbs:" GS_SERVICE,server);
 if(kr==KERN_SUCCESS)return kr;
 mach_port_t broker=MACH_PORT_NULL;
 kr=bootstrap_look_up(bootstrap_port,"com.apple.ReportCrash.SimulateCrash",&broker);
 if(kr!=KERN_SUCCESS)return kr;
 kr=GSLookupBroker(broker,GS_SERVICE,server,5000);
 mach_port_deallocate(mach_task_self(),broker);return kr;
}
NSDictionary *GSRequest(NSDictionary *request, NSError **error) {
 NSData *data=[NSJSONSerialization dataWithJSONObject:request options:0 error:error];
 if (!data || data.length>GS_MAX_JSON) return nil;
 mach_port_t server=MACH_PORT_NULL, reply=MACH_PORT_NULL;
 kern_return_t kr=GSLookupDaemon(&server);
 if(kr!=KERN_SUCCESS) goto fail;
 kr=GSCreateReplyPort(&reply);
 if(kr!=KERN_SUCCESS) goto fail;
 {
 GSMessage *message=calloc(1,sizeof(GSMessage)+sizeof(mach_msg_max_trailer_t));
 if(!message){kr=KERN_RESOURCE_SHORTAGE;goto fail;}
 message->header.msgh_bits=MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND,MACH_MSG_TYPE_MAKE_SEND_ONCE);
 message->header.msgh_remote_port=server;message->header.msgh_local_port=reply;
 message->header.msgh_id=GS_MESSAGE_ID;message->length=(uint32_t)data.length;
 memcpy(message->json,data.bytes,data.length);
 message->header.msgh_size=(mach_msg_size_t)((offsetof(GSMessage,json)+data.length+3)&~3);
 kr=mach_msg(&message->header,MACH_SEND_MSG|MACH_SEND_TIMEOUT,message->header.msgh_size,0,MACH_PORT_NULL,5000,MACH_PORT_NULL);
 if(kr==KERN_SUCCESS)kr=mach_msg(&message->header,MACH_RCV_MSG|MACH_RCV_TIMEOUT,0,sizeof(GSMessage)+sizeof(mach_msg_max_trailer_t),reply,120000,MACH_PORT_NULL);
 NSDictionary *result=nil;
 if(kr==KERN_SUCCESS && !(message->header.msgh_bits&MACH_MSGH_BITS_COMPLEX) && message->header.msgh_id==GS_MESSAGE_ID && message->header.msgh_size>=offsetof(GSMessage,json) && message->length<=GS_MAX_JSON && message->length<=message->header.msgh_size-offsetof(GSMessage,json)) {
 id parsed=[NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:message->json length:message->length] options:0 error:nil];
 if([parsed isKindOfClass:NSDictionary.class] && [parsed[@"ok"] boolValue])result=parsed[@"data"]==NSNull.null?@{}:parsed[@"data"];
 }
 if(kr==KERN_SUCCESS)mach_msg_destroy(&message->header);
 free(message);GSDestroyReplyPort(reply);mach_port_deallocate(mach_task_self(),server);
 if(result)return result;
 if(error)*error=[NSError errorWithDomain:@"Gunshot" code:1 userInfo:@{NSLocalizedDescriptionKey:GSL(@"GoToHP request failed. Check the daemon, account and queue.")}];return nil;
 }
fail:
 GSDestroyReplyPort(reply);
 if(server!=MACH_PORT_NULL)mach_port_deallocate(mach_task_self(),server);
 if(error)*error=[NSError errorWithDomain:@"Gunshot" code:kr userInfo:@{NSLocalizedDescriptionKey:GSL(@"GoToHP daemon unavailable. Check installation and RocketBootstrap.")}];return nil;
}
