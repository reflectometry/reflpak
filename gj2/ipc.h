#ifndef ipc_h
#define ipc_h

void ipc_fitupdate(void);
int ipc_send(char *str);
int ipc_recv(char *str);
double onlyCalcChiSq(double *);

#endif /* ipc_h */
