#include <stdio.h>

int main(int argc);

int main(int argc)
{
   unsigned int c;

#define SHIFT 4

   argc--;
   for (c = getc(stdin); c != EOF; c = getc(stdin)) {
      c = (argc) ? c << 8 - SHIFT : c << SHIFT;
      c = (c & 0xFF) + (c >> 8);
      putc(c, stdout);
   }
   return 0;
}

