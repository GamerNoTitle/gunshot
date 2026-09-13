#import <Foundation/Foundation.h>
#include <assert.h>
#define bootstrap_look_up GSFixtureLookup
#import "../Shared/IPCClient.m"
#undef bootstrap_look_up
#ifndef MPO_ENFORCE_REPLY_PORT_SEMANTICS
#define MPO_ENFORCE_REPLY_PORT_SEMANTICS 0x2000
#endif
static mach_port_t Server,Broker;
static NSUInteger Route,Lookups;
kern_return_t GSFixtureLookup(mach_port_t bootstrap,const char *name,mach_port_t *port){
 assert(MACH_PORT_VALID(bootstrap));
 Lookups++;*port=MACH_PORT_NULL;
 if((Route==0&&!strcmp(name,GS_SERVICE))||(Route==1&&!strcmp(name,"cy:rbs:" GS_SERVICE)))*port=Server;
 if((Route==2||Route==4)&&!strcmp(name,"com.apple.ReportCrash.SimulateCrash"))*port=Broker;
 if(!MACH_PORT_VALID(*port))return KERN_FAILURE;
 return mach_port_mod_refs(mach_task_self(),*port,MACH_PORT_RIGHT_SEND,1);
}
static mach_port_t Endpoint(void){
 mach_port_options_t options={0};options.flags=MPO_ENFORCE_REPLY_PORT_SEMANTICS;
 mach_port_t port;assert(mach_port_construct(mach_task_self(),&options,0,&port)==KERN_SUCCESS);
 assert(mach_port_insert_right(mach_task_self(),port,port,MACH_MSG_TYPE_MAKE_SEND)==KERN_SUCCESS);return port;
}
static void Exchange(NSUInteger route,BOOL malformed){
 Route=route;Lookups=0;Server=Endpoint();Broker=Endpoint();
 dispatch_semaphore_t done=dispatch_semaphore_create(0);
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^{@autoreleasepool{
  if(route==2||route==4){
   union { GSLookupQuery query; char bytes[sizeof(GSLookupQuery)+sizeof(mach_msg_max_trailer_t)]; } incoming={0};
   assert(mach_msg(&incoming.query.header,MACH_RCV_MSG|MACH_RCV_TIMEOUT,0,sizeof(incoming),Broker,3000,0)==KERN_SUCCESS);
   GSLookupResponse response={0};response.header.msgh_bits=MACH_MSGH_BITS(MACH_MSG_TYPE_MOVE_SEND_ONCE,0)|MACH_MSGH_BITS_COMPLEX;
   response.header.msgh_size=sizeof(response);response.header.msgh_remote_port=incoming.query.header.msgh_remote_port;
   if(route==4)response.header.msgh_bits&=~MACH_MSGH_BITS_COMPLEX;
   response.body.msgh_descriptor_count=route==4?0:1;response.port.name=Server;response.port.type=MACH_MSG_PORT_DESCRIPTOR;response.port.disposition=MACH_MSG_TYPE_COPY_SEND;
   assert(mach_msg(&response.header,MACH_SEND_MSG|MACH_SEND_TIMEOUT,sizeof(response),0,0,3000,0)==KERN_SUCCESS);
   if(route==4){dispatch_semaphore_signal(done);return;}
  }
  size_t capacity=sizeof(GSMessage)+sizeof(mach_msg_max_trailer_t);GSMessage *message=calloc(1,capacity);
  assert(mach_msg(&message->header,MACH_RCV_MSG|MACH_RCV_TIMEOUT,0,(mach_msg_size_t)capacity,Server,3000,0)==KERN_SUCCESS);
  assert(message->header.msgh_id==GS_MESSAGE_ID);
  NSDictionary *request=[NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:message->json length:message->length] options:0 error:nil];
  assert([request[@"op"]isEqual:@"queue"]);
  mach_port_t reply=message->header.msgh_remote_port;memset(message,0,sizeof(*message));
  NSData *data=[@"{\"ok\":true,\"data\":{\"jobs\":[]}}" dataUsingEncoding:NSUTF8StringEncoding];
  message->header.msgh_remote_port=reply;message->header.msgh_bits=MACH_MSGH_BITS(MACH_MSG_TYPE_MOVE_SEND_ONCE,0);
  message->header.msgh_id=malformed?999:GS_MESSAGE_ID;message->length=(uint32_t)data.length;
  memcpy(message->json,data.bytes,data.length);message->header.msgh_size=(mach_msg_size_t)((offsetof(GSMessage,json)+data.length+3)&~3);
  assert(mach_msg(&message->header,MACH_SEND_MSG|MACH_SEND_TIMEOUT,message->header.msgh_size,0,0,3000,0)==KERN_SUCCESS);
  free(message);dispatch_semaphore_signal(done);
 }});
 NSError *error=nil;NSDictionary *response=GSRequest(@{@"op":@"queue"},&error);
 assert(Lookups==MIN(route+1,3));
 NSDictionary *snapshot=GSIPCDiagnosticsSnapshot();
 assert([snapshot[@"steps"][0][@"stage"]isEqual:@"lookup.bootstrap"]);
 if(route==4){assert(!response&&error&&[snapshot[@"stage"]isEqual:@"broker.service-unavailable"]);assert(![snapshot[@"reachable"]boolValue]);}
 else
 if(malformed){assert(!response&&error&&[snapshot[@"stage"]isEqual:@"request.response"]);assert([error.localizedDescription containsString:@"request.response"]);}
 else {assert(!error&&[response[@"jobs"]isEqual:@[]]);assert([snapshot[@"reachable"]boolValue]);}
 assert(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC))==0);
 for(NSUInteger i=0;i<2;i++){
  mach_port_t port=i?Broker:Server;mach_port_urefs_t refs=0;
  assert(mach_port_get_refs(mach_task_self(),port,MACH_PORT_RIGHT_SEND,&refs)==KERN_SUCCESS&&refs==1);
  mach_port_deallocate(mach_task_self(),port);GSDestroyReplyPort(port);
 }
}
int main(void){@autoreleasepool{
 for(NSUInteger route=0;route<3;route++){Exchange(route,NO);Exchange(route,YES);}
 Exchange(4,NO); // A running daemon fixture can still be unavailable to the broker.
 Route=3;Lookups=0;NSError *error=nil;
 assert(!GSRequest(@{@"op":@"accounts",@"secret":@"must-never-appear-in-diagnostics"},&error));
 NSDictionary *snapshot=GSIPCDiagnosticsSnapshot();assert([snapshot[@"stage"]isEqual:@"lookup.broker"]);
 assert([error.localizedDescription containsString:@"lookup.broker"]);
 NSData *data=[NSJSONSerialization dataWithJSONObject:snapshot options:0 error:nil];
 assert(![[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]containsString:@"must-never"]);
 NSLog(@"PASS GSRequest direct, redirected and broker lookup; daemon RPC, rejected response and right cleanup");
}}
