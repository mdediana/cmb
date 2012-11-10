// from http://www.linuxatemyram.com/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <limits.h>

#define GB 1024 * 1024 * 1024
#define FOREVER UINT_MAX

int main(int argc, char** argv) {
    int max = -1;
    int gb = 0;
    char* buffer;

    if(argc > 1)
        max = atoi(argv[1]);

    while((buffer=malloc(GB)) != NULL && gb != max) {
        memset(buffer, 0, GB);
        gb++;
        printf("Allocated %d GB\n", gb);
    }

    printf("Halt\n");
    sleep(FOREVER);
    
    return 0;
}
