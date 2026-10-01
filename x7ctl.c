#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/hid/IOHIDManager.h>
#include <IOKit/hid/IOHIDKeys.h>
#include <arpa/inet.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CREATIVE_VID 0x041e

typedef struct { bool apply; } Options;

static long cfnum(IOHIDDeviceRef d, CFStringRef key) {
    CFTypeRef v = IOHIDDeviceGetProperty(d, key);
    long out = -1;
    if (v && CFGetTypeID(v) == CFNumberGetTypeID()) CFNumberGetValue((CFNumberRef)v, kCFNumberLongType, &out);
    return out;
}
static void cfstr(IOHIDDeviceRef d, CFStringRef key, char *buf, size_t n) {
    buf[0] = 0; CFTypeRef v = IOHIDDeviceGetProperty(d,key);
    if (v && CFGetTypeID(v)==CFStringGetTypeID()) CFStringGetCString((CFStringRef)v,buf,n,kCFStringEncodingUTF8);
}
static bool is_x7(IOHIDDeviceRef d) {
    if (cfnum(d, CFSTR(kIOHIDVendorIDKey)) != CREATIVE_VID) return false;
    char p[256]; cfstr(d, CFSTR(kIOHIDProductKey), p, sizeof p);
    return strstr(p,"X7") || strstr(p,"Sound Blaster");
}
static void list_devices(void) {
    IOHIDManagerRef m=IOHIDManagerCreate(kCFAllocatorDefault,kIOHIDOptionsTypeNone);
    IOHIDManagerSetDeviceMatching(m,NULL); IOHIDManagerOpen(m,kIOHIDOptionsTypeNone);
    CFSetRef s=IOHIDManagerCopyDevices(m); if(!s){puts("No HID devices."); CFRelease(m); return;}
    CFIndex n=CFSetGetCount(s); IOHIDDeviceRef *a=calloc((size_t)n,sizeof(*a)); CFSetGetValues(s,(const void**)a);
    for(CFIndex i=0;i<n;i++){
        if(cfnum(a[i],CFSTR(kIOHIDVendorIDKey))!=CREATIVE_VID) continue;
        char p[256],ser[256]; cfstr(a[i],CFSTR(kIOHIDProductKey),p,sizeof p); cfstr(a[i],CFSTR(kIOHIDSerialNumberKey),ser,sizeof ser);
        printf("Creative HID: VID=%04lx PID=%04lx product=\"%s\" serial=\"%s\"%s\n",
          cfnum(a[i],CFSTR(kIOHIDVendorIDKey)),cfnum(a[i],CFSTR(kIOHIDProductIDKey)),p,ser,is_x7(a[i])?"  <candidate>":"");
    }
    free(a); CFRelease(s); IOHIDManagerClose(m,kIOHIDOptionsTypeNone); CFRelease(m);
}
static IOHIDDeviceRef find_x7(IOHIDManagerRef *mgrOut) {
    IOHIDManagerRef m=IOHIDManagerCreate(kCFAllocatorDefault,kIOHIDOptionsTypeNone);
    IOHIDManagerSetDeviceMatching(m,NULL); if(IOHIDManagerOpen(m,kIOHIDOptionsTypeNone)!=kIOReturnSuccess){CFRelease(m);return NULL;}
    CFSetRef s=IOHIDManagerCopyDevices(m); if(!s){IOHIDManagerClose(m,0);CFRelease(m);return NULL;}
    CFIndex n=CFSetGetCount(s); IOHIDDeviceRef *a=calloc((size_t)n,sizeof(*a)); CFSetGetValues(s,(const void**)a);
    IOHIDDeviceRef found=NULL;
    for(CFIndex i=0;i<n;i++) if(is_x7(a[i])) { found=(IOHIDDeviceRef)CFRetain(a[i]); break; }
    free(a); CFRelease(s); if(!found){IOHIDManagerClose(m,0);CFRelease(m);return NULL;} *mgrOut=m; return found;
}
static void hexprint(const uint8_t *p,size_t n){for(size_t i=0;i<n;i++)printf("%s%02X",i?" ":"",p[i]);putchar('\n');}
static int send_report(const uint8_t *p,size_t n, Options o) {
    printf("report-id=0 output len=%zu: ",n); hexprint(p,n);
    if(!o.apply){puts("DRY RUN (add --apply to send)"); return 0;}
    IOHIDManagerRef m=NULL; IOHIDDeviceRef d=find_x7(&m); if(!d){fprintf(stderr,"No Creative X7 HID candidate found. Run: x7ctl list\n");return 2;}
    IOReturn r=IOHIDDeviceOpen(d,kIOHIDOptionsTypeNone);
    if(r==kIOReturnSuccess) r=IOHIDDeviceSetReport(d,kIOHIDReportTypeOutput,0,p,(CFIndex)n);
    if(r==kIOReturnSuccess) puts("sent successfully"); else fprintf(stderr,"IOHID write failed: 0x%08x\n",r);
    IOHIDDeviceClose(d,0); CFRelease(d); IOHIDManagerClose(m,0); CFRelease(m); return r==kIOReturnSuccess?0:3;
}
static void put_be_float(uint8_t *p,float f){uint32_t u;memcpy(&u,&f,4);u=htonl(u);memcpy(p,&u,4);}
static int dsp(uint8_t paramLo,uint8_t ns,float value,Options o){
    uint8_t p[16]={0x20,0x00,0x16,0x0A,0xD5,0x02,0x08,paramLo,0x20,ns,0,0,0,0,0x4D,0x00}; put_be_float(&p[10],value); return send_report(p,sizeof p,o);
}
static int onoff(const char *s,bool *v){if(!strcmp(s,"on")){*v=true;return 0;}if(!strcmp(s,"off")){*v=false;return 0;}return -1;}
static void usage(void){
 puts("x7ctl - experimental Sound Blaster X7 controller\n"
      "Usage:\n"
      "  x7ctl list\n"
      "  x7ctl [--apply] surround on|off\n"
      "  x7ctl [--apply] surround amount 0.0..1.0\n"
      "  x7ctl [--apply] crystalizer on|off\n"
      "  x7ctl [--apply] crystalizer amount 0.0..1.0\n"
      "  x7ctl [--apply] dialog on|off\n"
      "  x7ctl [--apply] dialog amount 0.0..1.0\n"
      "  x7ctl [--apply] smart-volume on|off\n"
      "  x7ctl [--apply] smart-volume amount 0.0..1.0\n"
      "  x7ctl [--apply] smart-volume mode normal|loud|night\n"
      "  x7ctl [--apply] direct on|off\n"
      "  x7ctl [--apply] spdif-direct on|off\n"
      "  x7ctl [--apply] output speakers|headphones\n"
      "  x7ctl [--apply] auto-standby on|off\n"
      "  x7ctl [--apply] scout on|off\n"
      "  x7ctl [--apply] bass-redirection on|off\n"
      "  x7ctl [--apply] crossover 10..500\n"
      "  x7ctl [--apply] subwoofer-gain on|off\n"
      "  x7ctl [--apply] dolby-drc full|normal|night\n"
      "  x7ctl [--apply] eq on|off\n"
      "  x7ctl [--apply] eq level -12..12\n"
      "  x7ctl [--apply] eq band 31|62|125|250|500|1k|2k|4k|8k|16k -12..12\n"
      "  x7ctl [--apply] eq preset flat|acoustic|classical|country|dance|jazz|newage|pop|rock|vocal\n"
      "Default is DRY RUN. --apply performs the hardware write.");
}
int main(int argc,char **argv){
    Options o={0}; int i=1; if(i<argc&&!strcmp(argv[i],"--apply")){o.apply=true;i++;}
    if(i>=argc){usage();return 1;} const char *c=argv[i++];
    if(!strcmp(c,"list")){list_devices();return 0;}
    bool b;
    if(!strcmp(c,"surround")){
        if(i<argc&&!strcmp(argv[i],"amount")){if(++i>=argc)return 1;float v=strtof(argv[i],NULL);if(v<0||v>1){fprintf(stderr,"amount must be 0..1\n");return 1;}return dsp(0x02,0x96,v,o);} if(i>=argc||onoff(argv[i],&b))return 1;return dsp(0x00,0x96,b?1.f:0.f,o);
    }
    if(!strcmp(c,"crystalizer")){
        if(i<argc&&!strcmp(argv[i],"amount")){if(++i>=argc)return 1;float v=strtof(argv[i],NULL);if(v<0||v>1)return 1;return dsp(0x10,0x96,v,o);} if(i>=argc||onoff(argv[i],&b))return 1;return dsp(0x0E,0x96,b?1.f:0.f,o);
    }
    if(!strcmp(c,"dialog")){
        if(i<argc&&!strcmp(argv[i],"amount")){if(++i>=argc)return 1;float v=strtof(argv[i],NULL);if(v<0||v>1)return 1;return dsp(0x06,0x96,v,o);}
        if(i>=argc||onoff(argv[i],&b))return 1;return dsp(0x04,0x96,b?1.f:0.f,o);
    }
    if(!strcmp(c,"smart-volume")){
        if(i<argc&&!strcmp(argv[i],"amount")){if(++i>=argc)return 1;float v=strtof(argv[i],NULL);if(v<0||v>1)return 1;return dsp(0x0A,0x96,v,o);}
        if(i<argc&&!strcmp(argv[i],"mode")){if(++i>=argc)return 1;float v=!strcmp(argv[i],"normal")?0.f:!strcmp(argv[i],"loud")?1.f:!strcmp(argv[i],"night")?2.f:-1.f;if(v<0)return 1;return dsp(0x0C,0x96,v,o);} if(i>=argc||onoff(argv[i],&b))return 1;return dsp(0x08,0x96,b?1.f:0.f,o);
    }
    if(!strcmp(c,"direct")||!strcmp(c,"spdif-direct")){if(i>=argc||onoff(argv[i],&b))return 1;uint8_t p[3]={0x23,!strcmp(c,"direct")?0x43:0x4B,b?1:0};return send_report(p,3,o);}
    if(!strcmp(c,"output")){if(i>=argc)return 1;if(!strcmp(argv[i],"speakers")){uint8_t p[]={0x23,0x4E,0x00,0x00,0x00,0x80};return send_report(p,6,o);}if(!strcmp(argv[i],"headphones")){uint8_t p[]={0x23,0x4E,0x01,0x00,0x00,0x00};return send_report(p,6,o);}return 1;}

    if(!strcmp(c,"bass-redirection")){if(i>=argc||onoff(argv[i],&b))return 1;return dsp(0x2A,0x96,b?1.f:0.f,o);}
    if(!strcmp(c,"crossover")){if(i>=argc)return 1;float v=strtof(argv[i],NULL);if(v<10||v>500){fprintf(stderr,"crossover must be 10..500 Hz\n");return 1;}return dsp(0x2C,0x96,v,o);}
    if(!strcmp(c,"subwoofer-gain")){if(i>=argc||onoff(argv[i],&b))return 1;return dsp(0x3C,0x96,b?1.f:0.f,o);}
    if(!strcmp(c,"dolby-drc")){if(i>=argc)return 1;float v=!strcmp(argv[i],"full")?1.f:!strcmp(argv[i],"normal")?2.f:!strcmp(argv[i],"night")?3.f:-1.f;if(v<0)return 1;return dsp(0x04,0x97,v,o);}
    if(!strcmp(c,"eq")){
        if(i>=argc)return 1;
        if(!strcmp(argv[i],"on")||!strcmp(argv[i],"off")){if(onoff(argv[i],&b))return 1;return dsp(0x12,0x96,b?1.f:0.f,o);}
        if(!strcmp(argv[i],"level")){if(++i>=argc)return 1;float v=strtof(argv[i],NULL);if(v<-12||v>12)return 1;return dsp(0x14,0x96,v,o);}
        if(!strcmp(argv[i],"band")){
            if(i+2>=argc)return 1; const char *band=argv[++i]; float v=strtof(argv[++i],NULL); if(v<-12||v>12)return 1;
            const char *names[]={"31","62","125","250","500","1k","2k","4k","8k","16k"}; uint8_t id=0;
            for(int k=0;k<10;k++)if(!strcmp(band,names[k]))id=(uint8_t)(0x16+2*k); if(!id)return 1; return dsp(id,0x96,v,o);
        }
        if(!strcmp(argv[i],"preset")){
            if(++i>=argc)return 1; const char *name=argv[i];
            static const struct {const char *n; float v[11];} ps[]={
              {"flat",{0,0,0,0,0,0,0,0,0,0,0}},
              {"acoustic",{0,0,1,2,0,0,0,0,2,2,2}},
              {"classical",{0,0,6,6,3,0,0,0,0,3,3}},
              {"country",{0,-1,0,1,1,1,0,0,2,3,4}},
              {"dance",{0,-1,2,3,4,-1,-1,0,0,4,4}},
              {"jazz",{0,0,0,1,4,4,4,0,1,3,3}},
              {"newage",{0,0,2,2,0,0,0,1,2,2,2}},
              {"pop",{0,-2,0,2,2,0,-1,-1,0,3,6}},
              {"rock",{0,-1,-1,1,2,-1,-1,0,0,4,4}},
              {"vocal",{0,-2,-1,-1,0,3,4,3,0,0,1}}
            };
            const float *vals=NULL; for(size_t k=0;k<sizeof(ps)/sizeof(ps[0]);k++)if(!strcmp(name,ps[k].n)){vals=ps[k].v;break;} if(!vals)return 1;
            for(int k=0;k<11;k++){int rc=dsp((uint8_t)(0x14+2*k),0x96,vals[k],o);if(rc)return rc;} return 0;
        }
        return 1;
    }
    if(!strcmp(c,"auto-standby")){if(i>=argc||onoff(argv[i],&b))return 1;uint8_t p[]={0x5A,0x39,0x03,0x00,0x0B,b?1:0};return send_report(p,6,o);}
    if(!strcmp(c,"scout")){if(i>=argc||onoff(argv[i],&b))return 1;uint8_t p[]={0x23,0x23,0x02,b?1:0,0x03,0x00,0x00,0x04};return send_report(p,8,o);}
    usage(); return 1;
}
