#ifndef DPI_HOST_H
#define DPI_HOST_H

#include <svdpi.h>

#ifdef __cplusplus
extern "C" {
#endif

extern int tohost(const svBitVecVal *data);
//extern void fromhost(const svBitVecVal *data); // TODO: Implement this

#ifdef __cplusplus
}
#endif

#endif // DPI_HOST_H