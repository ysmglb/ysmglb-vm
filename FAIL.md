HEAD_SHA=f8431ce50bdcb8023c3c045e58842a0805c5a041
RUN_URL=https://github.com/ysmglb/ysmglb-vm/actions/runs/42620301510
===== DEPS: LAST 40 LINES =====
Package gbm was not found in the pkg-config search path.
Perhaps you should add the directory containing `gbm.pc'
to the PKG_CONFIG_PATH environment variable
No package 'gbm' found
-----------
CMake binary for host machine is not cached
CMake binary missing from cross or native file, or env var undefined.
Default target is not allowed for cross use
Found CMake: NO
Dependency lookup for gbm with method 'cmake' failed: CMake binary for machine host machine not found. Giving up.
Run-time dependency gbm found: NO  (tried pkg-config)

src-virglrenderer/meson.build:245:22: ERROR: Dependency "gbm" not found (tried pkg-config)

::endgroup::

==DEP== FAIL-SETUP virglrenderer
==DEP== WARN virglrenderer 不可用 (缺少 gbm), QEMU 将不带 OpenGL 加速

依赖库安装完成 → /home/runner/work/ysmglb-vm/ysmglb-vm/build/_prefix
gio
glib-2.0
libdrm.a
libepoxy.a
libffi.a
libffi.la
libgio-2.0.a
libgirepository-2.0.a
libglib-2.0.a
libgmodule-2.0.a
libgobject-2.0.a
libgthread-2.0.a
libintl.a
libpcre2-16.a
libpcre2-32.a
libpcre2-8.a
libpcre2-posix.a
libpixman-1.a
libslirp.a
pkgconfig
===== DEPS: ==DEP== MARKERS =====
==DEP== START glib-2.0
==DEP== SETUP glib-2.0
==DEP== NINJA glib-2.0
==DEP== DONE  glib-2.0
==DEP== START pixman-1
==DEP== SETUP pixman-1
==DEP== NINJA pixman-1
==DEP== DONE  pixman-1
==DEP== START slirp
==DEP== SETUP slirp
==DEP== NINJA slirp
==DEP== DONE  slirp
==DEP== START libdrm
==DEP== SETUP libdrm
==DEP== NINJA libdrm
==DEP== DONE  libdrm
==DEP== START epoxy
==DEP== SETUP epoxy
==DEP== NINJA epoxy
==DEP== DONE  epoxy
==DEP== START virglrenderer
==DEP== SETUP virglrenderer
==DEP== FAIL-SETUP virglrenderer
==DEP== WARN virglrenderer 不可用 (缺少 gbm), QEMU 将不带 OpenGL 加速
===== QEMU: LAST 100 LINES =====
/usr/local/lib/android/sdk/ndk/26.3.11579264/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/include/scsi/sg.h:78:9: note: previous definition is here
#define COMMAND_TERMINATED 0x11
        ^
In file included from ../hw/scsi/virtio-scsi.c:29:
/home/runner/work/ysmglb-vm/ysmglb-vm/build/_work/qemu-9.1.0/include/scsi/constants.h:179:9: warning: 'ACA_ACTIVE' macro redefined [-Wmacro-redefined]
#define ACA_ACTIVE           0x30
        ^
/usr/local/lib/android/sdk/ndk/26.3.11579264/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/include/scsi/sg.h:80:9: note: previous definition is here
#define ACA_ACTIVE 0x18
        ^
In file included from ../hw/scsi/virtio-scsi.c:29:
/home/runner/work/ysmglb-vm/ysmglb-vm/build/_work/qemu-9.1.0/include/scsi/constants.h:180:9: warning: 'TASK_ABORTED' macro redefined [-Wmacro-redefined]
#define TASK_ABORTED         0x40
        ^
/usr/local/lib/android/sdk/ndk/26.3.11579264/toolchains/llvm/prebuilt/linux-x86_64/bin/../sysroot/usr/include/scsi/sg.h:81:9: note: previous definition is here
#define TASK_ABORTED 0x20
        ^
9 warnings generated.
[1878/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_vfio_helpers.c.o
[1879/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_net_virtio-net.c.o
[1880/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_vfio_container-base.c.o
[1881/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_vfio_common.c.o
[1882/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_vfio_migration.c.o
[1883/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_vfio_container.c.o
[1884/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_vfio_cpr.c.o
[1885/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_vfio_display.c.o
[1886/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_vfio_iommufd.c.o
[1887/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_vfio_pci-quirks.c.o
[1888/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_vfio_calxeda-xgmac.c.o
[1889/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_vfio_platform.c.o
[1890/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_vfio_amd-xgbe.c.o
[1891/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_virtio_virtio-config-io.c.o
[1892/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_vfio_pci.c.o
[1893/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_virtio_virtio-qmp.c.o
[1894/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_virtio_virtio-balloon.c.o
[1895/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_virtio_virtio.c.o
[1896/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_virtio_virtio-rng.c.o
[1897/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_virtio_virtio-crypto-pci.c.o
[1898/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_virtio_virtio-input-host-pci.c.o
[1899/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_virtio_virtio-input-pci.c.o
[1900/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_virtio_virtio-rng-pci.c.o
[1901/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_virtio_virtio-mem.c.o
[1902/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_virtio_virtio-balloon-pci.c.o
[1903/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_virtio_virtio-scsi-pci.c.o
[1904/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_virtio_virtio-blk-pci.c.o
[1905/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_virtio_virtio-net-pci.c.o
[1906/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_virtio_virtio-serial-pci.c.o
[1907/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_virtio_virtio-iommu-pci.c.o
[1908/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_virtio_virtio-md-pci.c.o
[1909/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_virtio_virtio-mem-pci.c.o
[1910/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_i386_kvm_xen-stubs.c.o
[1911/1957] Compiling C object libqemu-aarch64-softmmu.a.p/dump_win_dump.c.o
[1912/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_remote_memory.c.o
[1913/1957] Compiling C object libqemu-aarch64-softmmu.a.p/hw_remote_proxy-memory-listener.c.o
[1914/1957] Compiling C object libqemu-aarch64-softmmu.a.p/system_arch_init.c.o
[1915/1957] Compiling C object libqemu-aarch64-softmmu.a.p/cpu-target.c.o
[1916/1957] Compiling C object libqemu-aarch64-softmmu.a.p/system_ioport.c.o
[1917/1957] Compiling C object libqemu-aarch64-softmmu.a.p/system_watchpoint.c.o
[1918/1957] Compiling C object libqemu-aarch64-softmmu.a.p/page-target.c.o
[1919/1957] Compiling C object libqemu-aarch64-softmmu.a.p/page-vary-target.c.o
[1920/1957] Compiling C object libqemu-aarch64-softmmu.a.p/system_memory.c.o
[1921/1957] Compiling C object libqemu-aarch64-softmmu.a.p/system_physmem.c.o
[1922/1957] Compiling C object libqemu-aarch64-softmmu.a.p/migration_target.c.o
[1923/1957] Compiling C object libqemu-aarch64-softmmu.a.p/monitor_hmp-target.c.o
[1924/1957] Compiling C object libqemu-aarch64-softmmu.a.p/monitor_hmp-cmds-target.c.o
[1925/1957] Compiling C object libqemu-aarch64-softmmu.a.p/semihosting_guestfd.c.o
[1926/1957] Compiling C object libqemu-aarch64-softmmu.a.p/semihosting_config.c.o
[1927/1957] Compiling C object libqemu-aarch64-softmmu.a.p/migration_ram.c.o
[1928/1957] Compiling C object libqemu-aarch64-softmmu.a.p/semihosting_syscalls.c.o
[1929/1957] Compiling C object libqemu-aarch64-softmmu.a.p/semihosting_console.c.o
[1930/1957] Compiling C object libqemu-aarch64-softmmu.a.p/semihosting_uaccess.c.o
[1931/1957] Compiling C object libqemu-aarch64-softmmu.a.p/accel_accel-target.c.o
[1932/1957] Compiling C object libqemu-aarch64-softmmu.a.p/semihosting_arm-compat-semi.c.o
[1933/1957] Compiling C object libqemu-aarch64-softmmu.a.p/accel_tcg_tcg-all.c.o
[1934/1957] Compiling C object libqemu-aarch64-softmmu.a.p/accel_tcg_cpu-exec.c.o
[1935/1957] Compiling C object libqemu-aarch64-softmmu.a.p/accel_tcg_tb-maint.c.o
[1936/1957] Compiling C object libqemu-aarch64-softmmu.a.p/accel_tcg_tcg-runtime.c.o
[1937/1957] Compiling C object libqemu-aarch64-softmmu.a.p/accel_tcg_translate-all.c.o
[1938/1957] Compiling C object libqemu-aarch64-softmmu.a.p/accel_tcg_translator.c.o
[1939/1957] Compiling C object libqemu-aarch64-softmmu.a.p/accel_tcg_plugin-gen.c.o
[1940/1957] Compiling C object libqemu-aarch64-softmmu.a.p/accel_tcg_tcg-runtime-gvec.c.o
[1941/1957] Compiling C object libqemu-aarch64-softmmu.a.p/accel_tcg_watchpoint.c.o
[1942/1957] Compiling C object libqemu-aarch64-softmmu.a.p/fpu_softfloat.c.o
[1943/1957] Compiling C object libqemu-aarch64-softmmu.a.p/accel_kvm_kvm-accel-ops.c.o
[1944/1957] Compiling C object libqemu-aarch64-softmmu.a.p/accel_stubs_xen-stub.c.o
[1945/1957] Compiling C object libqemu-aarch64-softmmu.a.p/accel_kvm_kvm-all.c.o
[1946/1957] Compiling C object libqemu-aarch64-softmmu.a.p/plugins_loader.c.o
[1947/1957] Compiling C object libqemu-aarch64-softmmu.a.p/plugins_core.c.o
[1948/1957] Compiling C object libqemu-aarch64-softmmu.a.p/accel_tcg_cputlb.c.o
[1949/1957] Compiling C object libqemu-aarch64-softmmu.a.p/plugins_api.c.o
[1950/1957] Compiling C object libqemu-aarch64-softmmu.a.p/accel_tcg_tcg-accel-ops.c.o
[1951/1957] Compiling C object libqemu-aarch64-softmmu.a.p/accel_tcg_tcg-accel-ops-mttcg.c.o
[1952/1957] Compiling C object libqemu-aarch64-softmmu.a.p/accel_tcg_tcg-accel-ops-icount.c.o
[1953/1957] Compiling C object libqemu-aarch64-softmmu.a.p/accel_qtest_qtest.c.o
[1954/1957] Compiling C object libqemu-aarch64-softmmu.a.p/accel_tcg_tcg-accel-ops-rr.c.o
[1955/1957] Compiling C object qemu-system-aarch64.p/system_main.c.o
[1956/1957] Compiling C object libqemu-aarch64-softmmu.a.p/target_arm_tcg_sve_helper.c.o
[1957/1957] Linking target qemu-system-aarch64
make[1]: Leaving directory '/home/runner/work/ysmglb-vm/ysmglb-vm/build/_work/qemu-9.1.0/build'
cp: cannot stat 'qemu-system-aarch64': No such file or directory
