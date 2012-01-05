#if defined(__CYGWIN__)
#include <windows.h>

int listencanfork()
{
  OSVERSIONINFO osvi;
  osvi.dwOSVersionInfoSize = sizeof(osvi);
  GetVersionEx (&osvi);
  return (osvi.dwPlatformId != VER_PLATFORM_WIN32_WINDOWS);
}
#else
int listencanfork() { return 1; }
#endif
