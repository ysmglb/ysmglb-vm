/* Android/bionic 兼容层 — 通过 --extra-cflags="-include ..." 强制包含
 *
 * bionic 到 API 30 才提供 memfd_create(), API 28 的 <sys/mman.h> 连声明都没有。
 * QEMU 认为 host_os == linux, 会直接调 memfd_create(), 于是编译失败。
 * arm64 上 __NR_memfd_create 一直可用, 这里用 syscall 兜一个同名函数即可。
 */
#ifndef A23_ANDROID_COMPAT_H
#define A23_ANDROID_COMPAT_H

#if defined(__ANDROID__) && defined(__ANDROID_API__) && __ANDROID_API__ < 30

#include <sys/syscall.h>
#include <sys/types.h>
#include <unistd.h>

static inline int a23_memfd_create(const char *name, unsigned int flags)
{
    return (int)syscall(__NR_memfd_create, name, flags);
}

#define memfd_create(name, flags) a23_memfd_create((name), (flags))

#endif /* __ANDROID_API__ < 30 */

#endif
