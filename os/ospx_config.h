#ifndef __OSPX_CONFIG_H__
#define __OSPX_CONFIG_H__
/*
 *  COPYRIGHT (C) 2014 - 2020, piggy_xrh
 * 
 *	  Stpool is a portable and efficient tasks pool library, it can work on diferent 
 * platforms such as Windows, linux, unix and ARM.  
 *
 *    If you have any troubles or questions on using the library, contact me.
 *
 * 	  (Email: piggy_xrh@163.com  QQ: 1169732280)
 */

/*
 * PATCH(macOS): Darwin must not be configured with the "monotonic cond" 
 * feature sets, because @pthread_condattr_setclock does not exist there.
 * The Apple branch of @OSPX_pthread_cond_timedwait uses 
 * @pthread_cond_timedwait_relative_np instead, so the CLOCK_* macros are 
 * not needed at all; @sem_timedwait is missing on Darwin too, therefor
 * HAS_SEM_TIMEDWAIT must stay undefined (otherwise ospx.c will not link).
 *
 * NOTE: this block is duplicated in .help/.ospx_config, keep them in sync so
 * that a future @configure run does not drop it.
 */
#if defined(__APPLE__)
# ifndef HAS_STDINT_H
#  define HAS_STDINT_H 1
# endif
# ifndef HAS_PTHREAD_RWLOCK
#  define HAS_PTHREAD_RWLOCK 1	/* Darwin has pthread_rwlock_t */
# endif
#endif




#endif
