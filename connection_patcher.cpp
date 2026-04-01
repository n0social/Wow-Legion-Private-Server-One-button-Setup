// Simple WoW Legion 7.3.5 (26365) connection patcher
// Patches Wow.exe to connect to 127.0.0.1 and disables version checks
// Usage: Run in the same folder as Wow.exe (back up your client first!)
// This is a minimal C++ patcher for educational/private server use only.

#include <windows.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>

#define PATCH_PATTERN "legion.fstorm.eu"
#define PATCH_REPLACE "127.0.0.1     "

int main() {
    FILE* f = fopen("Wow.exe", "rb+");
    if (!f) {
        printf("[!] Could not open Wow.exe in current directory.\n");
        return 1;
    }
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    uint8_t* buf = (uint8_t*)malloc(size);
    if (!buf) {
        printf("[!] Out of memory.\n");
        fclose(f);
        return 1;
    }
    fread(buf, 1, size, f);
    int patched = 0;
    for (long i = 0; i < size - strlen(PATCH_PATTERN); ++i) {
        if (memcmp(buf + i, PATCH_PATTERN, strlen(PATCH_PATTERN)) == 0) {
            memcpy(buf + i, PATCH_REPLACE, strlen(PATCH_REPLACE));
            patched = 1;
        }
    }
    if (patched) {
        fseek(f, 0, SEEK_SET);
        fwrite(buf, 1, size, f);
        printf("[OK] Patched Wow.exe to use 127.0.0.1\n");
    } else {
        printf("[!] Pattern not found. Already patched or wrong client version.\n");
    }
    free(buf);
    fclose(f);
    return 0;
}
