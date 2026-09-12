#include <assert.h>
#include <string.h>
#include "libgotohp.h"
int main(void){
 assert(GunshotPing()==1);
 GunshotSetHostBearerProvider(0);
 char *response=GunshotRequest("{\"op\":\"ping\"}","settings");
 assert(strstr(response,"not_initialized")!=0);
 GunshotFree(response);
 return 0;
}
