#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>

int main(void) {
    // Elevate real, effective, and saved user IDs to root (UID 0)
    if (setresuid(0, 0, 0) != 0) {
        perror("[-] Error: setresuid failed");
        return 1;
    }
    if (setresgid(0, 0, 0) != 0) {
        perror("[-] Error: setresgid failed");
        return 1;
    }

    printf("==========================================\n");
    printf("   CyberLab System Health Monitor v1.0   \n");
    printf("==========================================\n");
    printf("[*] Running system diagnostics...\n");
    fflush(stdout);

    // Intentionally vulnerable to PATH hijacking:
    // Relative command invocation without absolute path
    int status = system("healthcheck");

    printf("[*] Diagnostics completed (exit code: %d).\n", status);
    return status;
}
