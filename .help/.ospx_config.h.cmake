#ifndef __OSPX_CONFIG_H__
#define __OSPX_CONFIG_H__

#cmakedefine HAS_STDINT_H                       1
#cmakedefine HAS_PTHREAD_RWLOCK                 1
#cmakedefine HAS_PTHREAD_CONDATTR_SETCLOCK      1
#cmakedefine HAS_PTHREAD_ATTR_GETINHERITSCHED   1
#cmakedefine HAS_CLOCK_GETTIME                  1
#cmakedefine HAS_CLOCK_MONOTONIC                1
#cmakedefine HAS_SEM_TIMEDWAIT                  1
#cmakedefine HAS_PRCTL                          1

#endif