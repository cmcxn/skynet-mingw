#ifndef DLFCN_H
#define DLFCN_H

/* Windows implementation of dlfcn.h using LoadLibrary/GetProcAddress */

#include <windows.h>

/* Mode flags for dlopen */
#define RTLD_LAZY     0x00001  /* Lazy function call binding */
#define RTLD_NOW      0x00002  /* Immediate function call binding */
#define RTLD_GLOBAL   0x00100  /* Make symbols available globally */
#define RTLD_LOCAL    0x00000  /* Opposite of RTLD_GLOBAL */

#ifdef __cplusplus
extern "C" {
#endif

/* Open a shared library */
static inline void *dlopen(const char *filename, int flag) {
	HMODULE handle;
	(void)flag; /* Unused on Windows */
	
	if (filename == NULL) {
		return GetModuleHandle(NULL);
	}
	
	handle = LoadLibraryA(filename);
	return (void *)handle;
}

/* Get symbol address from shared library */
static inline void *dlsym(void *handle, const char *symbol) {
	return (void *)GetProcAddress((HMODULE)handle, symbol);
}

/* Close shared library */
static inline int dlclose(void *handle) {
	return FreeLibrary((HMODULE)handle) ? 0 : -1;
}

/* Get error message */
static inline char *dlerror(void) {
	static char error_buf[256];
	DWORD error = GetLastError();
	
	if (error == 0) {
		return NULL;
	}
	
	FormatMessageA(
		FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
		NULL,
		error,
		0,
		error_buf,
		sizeof(error_buf),
		NULL
	);
	
	return error_buf;
}

#ifdef __cplusplus
}
#endif

#endif /* DLFCN_H */
