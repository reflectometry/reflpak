/*

Fortran format for G specifiers

Data Magnitude	Effective Format
           m <    0.1	Ew.d[Ee]
    0.1 <= m <    1.0	F(w-n).d
    1.0 <= m <   10.0	F(w-n).(d-1)
10d - 2 <= m <  10d - 1	F(w-n).1
10d - 1 <= m <  10d	F(w-n).0
           m >= 10d     Ew.d

*/

#include <stdio.h>

int main(void);

int main(void)
{

   double g[] = {0.1234567E-01, -0.12345678E00, 0.123456789E+01,
                 0.1234567890E+02, 0.12345678901E+03, -0.123456789012E+04,
                 0.1234567890123E+05, 0.12345678901234E+06,
                -0.123456789012345E+07,
0.123456E-02,
0.12345E-03,
0.1234E-04,
};
   int i;

   for (i = 0; i < 12; i++) printf("%#13.6G\n", g[i]);

   return 0;
}

