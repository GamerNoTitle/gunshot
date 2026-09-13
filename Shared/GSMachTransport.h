#pragma once
#include <mach/mach.h>
#include <stddef.h>
#include <string.h>

// XNU 8792 reply-port semantics; older SDKs may omit the public flag name.
#ifndef MPO_REPLY_PORT
#define MPO_REPLY_PORT 0x1000
#endif
static inline kern_return_t GSCreateReplyPort(mach_port_t *port) {
 *port=MACH_PORT_NULL;
 mach_port_options_t options={0};
 if(__builtin_available(iOS 16.0, macOS 13.0, *))options.flags=MPO_REPLY_PORT;
 // Never retry with an ordinary port on a kernel enforcing reply semantics.
 return mach_port_construct(mach_task_self(),&options,0,port);
}
static inline void GSDestroyReplyPort(mach_port_t port) {
 if(MACH_PORT_VALID(port))mach_port_mod_refs(mach_task_self(),port,MACH_PORT_RIGHT_RECEIVE,-1);
}

// Interoperate with RocketBootstrap's published lookup wire format. Its legacy
// client allocates an ordinary receive port, rejected by reply-enforcing brokers.
// Keep the broker's unlock/access policy and the daemon's audit-token checks.
typedef struct {
 mach_msg_header_t header;
 mach_msg_body_t body;
 uint32_t nameLength;
 char name[128];
} GSLookupQuery;
typedef struct {
 mach_msg_header_t header;
 mach_msg_body_t body;
 mach_msg_port_descriptor_t port;
} GSLookupResponse;
static inline kern_return_t GSLookupBrokerWithStage(mach_port_t broker,const char *name,mach_port_t *server,mach_msg_timeout_t timeout,const char **stage) {
 *stage="broker.arguments";
 *server=MACH_PORT_NULL;
 size_t length=strlen(name);if(!length||length>=sizeof(((GSLookupQuery *)0)->name))return KERN_INVALID_ARGUMENT;
 *stage="broker.reply-port";
 mach_port_t reply=MACH_PORT_NULL;kern_return_t kr=GSCreateReplyPort(&reply);
 if(kr!=KERN_SUCCESS)return kr;
 union { GSLookupQuery query; GSLookupResponse response; char receive[sizeof(GSLookupQuery)+sizeof(mach_msg_max_trailer_t)]; } buffer={0};
 GSLookupQuery *query=&buffer.query;
 query->header.msgh_bits=MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND,MACH_MSG_TYPE_MAKE_SEND_ONCE);
 query->header.msgh_remote_port=broker;query->header.msgh_local_port=reply;query->header.msgh_id=-1;
 query->header.msgh_size=(mach_msg_size_t)((offsetof(GSLookupQuery,name)+length+3)&~3);
 if(query->header.msgh_size<sizeof(GSLookupResponse))query->header.msgh_size=sizeof(GSLookupResponse);
 query->nameLength=(uint32_t)length;memcpy(query->name,name,length);
 *stage="broker.exchange";
 kr=mach_msg(&query->header,MACH_SEND_MSG|MACH_RCV_MSG|MACH_SEND_TIMEOUT|MACH_RCV_TIMEOUT,query->header.msgh_size,sizeof(buffer),reply,timeout,MACH_PORT_NULL);
 if(kr==KERN_SUCCESS){
  *stage="broker.response";
  GSLookupResponse *response=&buffer.response;
  if(response->header.msgh_id==0&&response->header.msgh_size==sizeof(GSLookupResponse)&&
     (response->header.msgh_bits&MACH_MSGH_BITS_COMPLEX)&&response->body.msgh_descriptor_count==1&&
     response->port.type==MACH_MSG_PORT_DESCRIPTOR&&response->port.disposition==MACH_MSG_TYPE_PORT_SEND&&MACH_PORT_VALID(response->port.name)){
   *stage="broker.connected";*server=response->port.name;response->port.name=MACH_PORT_NULL;
  }else{
   // A valid empty broker reply means the service is unavailable to the broker,
   // not necessarily that the daemon is absent from its own bootstrap domain.
   if(response->header.msgh_id==0&&response->header.msgh_size>=sizeof(mach_msg_header_t)+sizeof(mach_msg_body_t)&&
      !(response->header.msgh_bits&MACH_MSGH_BITS_COMPLEX)&&response->body.msgh_descriptor_count==0)*stage="broker.service-unavailable";
   kr=KERN_FAILURE;
  }
  mach_msg_destroy(&response->header);
 }
 GSDestroyReplyPort(reply);return kr;
}

static inline kern_return_t GSLookupBroker(mach_port_t broker,const char *name,mach_port_t *server,mach_msg_timeout_t timeout) {
 const char *stage;return GSLookupBrokerWithStage(broker,name,server,timeout,&stage);
}
