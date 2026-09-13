#import <Foundation/Foundation.h>
#include <assert.h>
#import "../Shared/GSMachTransport.h"
#ifndef MPO_ENFORCE_REPLY_PORT_SEMANTICS
#define MPO_ENFORCE_REPLY_PORT_SEMANTICS 0x2000
#endif
// A real kernel round trip against a reply-enforcing endpoint, not a mocked
// mach_msg. Exercise success, denied/malformed replies and timeout repeatedly.
static void Exchange(NSUInteger mode) {
 mach_port_t broker=MACH_PORT_NULL,service=MACH_PORT_NULL;
 mach_port_options_t options={0};options.flags=MPO_ENFORCE_REPLY_PORT_SEMANTICS;
 assert(mach_port_construct(mach_task_self(),&options,0,&broker)==KERN_SUCCESS);
 assert(mach_port_insert_right(mach_task_self(),broker,broker,MACH_MSG_TYPE_MAKE_SEND)==KERN_SUCCESS);
 assert(mach_port_allocate(mach_task_self(),MACH_PORT_RIGHT_RECEIVE,&service)==KERN_SUCCESS);
 assert(mach_port_insert_right(mach_task_self(),service,service,MACH_MSG_TYPE_MAKE_SEND)==KERN_SUCCESS);
 dispatch_semaphore_t done=dispatch_semaphore_create(0),clientDone=dispatch_semaphore_create(0);
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^{
  union { GSLookupQuery query; char bytes[sizeof(GSLookupQuery)+sizeof(mach_msg_max_trailer_t)]; } incoming={0};
  assert(mach_msg(&incoming.query.header,MACH_RCV_MSG|MACH_RCV_TIMEOUT,0,sizeof(incoming),broker,3000,MACH_PORT_NULL)==KERN_SUCCESS);
  assert(incoming.query.header.msgh_id==-1);
  assert(incoming.query.nameLength==strlen("test.service"));
  assert(!memcmp(incoming.query.name,"test.service",incoming.query.nameLength));
  if(mode==3){assert(dispatch_semaphore_wait(clientDone,dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC))==0);mach_msg_destroy(&incoming.query.header);dispatch_semaphore_signal(done);return;}
  GSLookupResponse response={0};response.header.msgh_bits=MACH_MSGH_BITS(MACH_MSG_TYPE_MOVE_SEND_ONCE,0);
  response.header.msgh_remote_port=incoming.query.header.msgh_remote_port;
  response.header.msgh_size=sizeof(response);response.header.msgh_id=mode==2?999:0;
  if(mode!=1){
   response.header.msgh_bits|=MACH_MSGH_BITS_COMPLEX;response.body.msgh_descriptor_count=1;
   response.port.name=service;response.port.type=MACH_MSG_PORT_DESCRIPTOR;response.port.disposition=MACH_MSG_TYPE_COPY_SEND;
  }
  assert(mach_msg(&response.header,MACH_SEND_MSG|MACH_SEND_TIMEOUT,response.header.msgh_size,0,MACH_PORT_NULL,3000,MACH_PORT_NULL)==KERN_SUCCESS);
  dispatch_semaphore_signal(done);
 });
 mach_port_t result=MACH_PORT_NULL;kern_return_t kr=GSLookupBroker(broker,"test.service",&result,1000);
 dispatch_semaphore_signal(clientDone);
 if(mode==3)assert(kr==MACH_RCV_TIMED_OUT);
 if(mode==0){assert(kr==KERN_SUCCESS&&result==service);mach_port_deallocate(mach_task_self(),result);}
 else assert(kr!=KERN_SUCCESS&&result==MACH_PORT_NULL);
 assert(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC))==0);
 // A malformed descriptor response must not leave an extra service send right.
 mach_port_urefs_t refs=0;assert(mach_port_get_refs(mach_task_self(),service,MACH_PORT_RIGHT_SEND,&refs)==KERN_SUCCESS&&refs==1);
 mach_port_destroy(mach_task_self(),broker);mach_port_destroy(mach_task_self(),service);
}
int main(void){@autoreleasepool{
 for(NSUInteger i=0;i<5;i++)for(NSUInteger mode=0;mode<4;mode++)Exchange(mode);
 mach_port_t result=MACH_PORT_NULL;assert(GSLookupBroker(MACH_PORT_NULL,"",&result,1)==KERN_INVALID_ARGUMENT);
 NSLog(@"PASS reply-enforcing Mach broker, success, rejected reply, malformed descriptor cleanup, timeout and repeat calls");
}}
