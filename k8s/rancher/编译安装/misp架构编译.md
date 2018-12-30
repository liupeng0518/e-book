# rancher二进制
```
go get github.com/rancher/rancher
```
或者，建议这种方式
```
wget https://github.com/rancher/rancher/archive/v2.1.4.tar.gz
cp https://github.com/rancher/rancher/archive/v2.1.4.tar.gz $GOPATH/src/github.com/rancher/

```

这里编译的时候要指定tag为k8s
```bash
[root@node152 rancher]# go build -tags k8s
```

这里会遇到几个错误
```bash
# github.com/rancher/rancher/vendor/github.com/fsnotify/fsnotify
vendor/github.com/fsnotify/fsnotify/inotify.go:39:15: undefined: unix.InotifyInit
# github.com/rancher/rancher/vendor/github.com/kr/pty
vendor/github.com/kr/pty/pty_linux.go:34:8: undefined: _C_uint
vendor/github.com/kr/pty/pty_linux.go:43:8: undefined: _C_int
# github.com/rancher/rancher/vendor/github.com/google/cadvisor/fs
vendor/github.com/google/cadvisor/fs/fs.go:527:20: cannot use buf.Dev (type uint32) as type uint64 in argument to major
vendor/github.com/google/cadvisor/fs/fs.go:528:20: cannot use buf.Dev (type uint32) as type uint64 in argument to minor
vendor/github.com/google/cadvisor/fs/fs.go:759:65: cannot use buf.Dev (type uint32) as type uint64 in argument to major
vendor/github.com/google/cadvisor/fs/fs.go:759:86: cannot use buf.Dev (type uint32) as type uint64 in argument to minor
vendor/github.com/google/cadvisor/fs/fs.go:760:66: cannot use buf.Rdev (type uint32) as type uint64 in argument to major
vendor/github.com/google/cadvisor/fs/fs.go:760:88: cannot use buf.Rdev (type uint32) as type uint64 in argument to minor
vendor/github.com/google/cadvisor/fs/fs.go:762:23: cannot use buf.Dev (type uint32) as type uint64 in argument to major
vendor/github.com/google/cadvisor/fs/fs.go:762:44: cannot use buf.Dev (type uint32) as type uint64 in argument to minor
```


这里有三个包有错误：
## 第一个
# github.com/rancher/rancher/vendor/github.com/fsnotify/fsnotify
vendor/github.com/fsnotify/fsnotify/inotify.go:39:15: undefined: unix.InotifyInit

这里有两种解决方法：
第一个是go get 最新的golang.org/x包，替换

第二个是添加一个函数：
vim vendor/golang.org/x/sys/unix/zsyscall_linux_mips64le.go 
```golang
func InotifyInit() (fd int, err error) {
r0, _, e1 := RawSyscall(SYS_INOTIFY_INIT, 0, 0, 0)
fd = int(r0)
if e1 != 0 {
err = errnoErr(e1)
}
return
}
```

## 第二个
# github.com/rancher/rancher/vendor/github.com/kr/pty
vendor/github.com/kr/pty/pty_linux.go:34:8: undefined: _C_uint
vendor/github.com/kr/pty/pty_linux.go:43:8: undefined: _C_int

pty包问题，这里查看https://github.com/kr/pty/pull/45 这个pr，新版本已经支持mips

```
go get github.com/kr/pty
```
替换vendor下的文件夹

## 第三个错误
# github.com/rancher/rancher/vendor/github.com/google/cadvisor/fs
vendor/github.com/google/cadvisor/fs/fs.go:527:20: cannot use buf.Dev (type uint32) as type uint64 in argument to major
vendor/github.com/google/cadvisor/fs/fs.go:528:20: cannot use buf.Dev (type uint32) as type uint64 in argument to minor
vendor/github.com/google/cadvisor/fs/fs.go:759:65: cannot use buf.Dev (type uint32) as type uint64 in argument to major
vendor/github.com/google/cadvisor/fs/fs.go:759:86: cannot use buf.Dev (type uint32) as type uint64 in argument to minor
vendor/github.com/google/cadvisor/fs/fs.go:760:66: cannot use buf.Rdev (type uint32) as type uint64 in argument to major
vendor/github.com/google/cadvisor/fs/fs.go:760:88: cannot use buf.Rdev (type uint32) as type uint64 in argument to minor
vendor/github.com/google/cadvisor/fs/fs.go:762:23: cannot use buf.Dev (type uint32) as type uint64 in argument to major
vendor/github.com/google/cadvisor/fs/fs.go:762:44: cannot use buf.Dev (type uint32) as type uint64 in argument to minor


这里需要进行强制转换

```golang
527         major := major(uint64(buf.Dev))
528         minor := minor(uint64(buf.Dev))
...
752         if buf.Mode&syscall.S_IFMT == syscall.S_IFBLK {
753                 err := syscall.Stat(mount.Mountpoint, buf)
754                 if err != nil {
755                         err = fmt.Errorf("stat failed on %s with error: %s", mount.Mountpoint, err)
756                         return 0, 0, err
757                 }
758 
759                 glog.V(4).Infof("btrfs dev major:minor %d:%d\n", int(major(uint64(buf.Dev))), int(minor(uint64(buf.D    ev))))
760                 glog.V(4).Infof("btrfs rdev major:minor %d:%d\n", int(major(uint64(buf.Rdev))), int(minor(uint64(buf    .Rdev))))
761 
762                 return int(major(uint64(buf.Dev))), int(minor(uint64(buf.Dev))), nil
763         } else {
764                 return 0, 0, fmt.Errorf("%s is not a block device", mount.Source)
765         }
766 }

```
