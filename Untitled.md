NeoKylin Linux操作系统 问题
1.	NeoKylin Linux操作系统在配置文件/etc/login.defs、/etc/pam.d/system-auth中未配置口令更新时间。
可以

2.	NeoKylin Linux操作系统在配置文件/etc/pam.d/system-auth、/etc/pam.d/sshd中未设置用户登录失败处理策略。
可以

3.	NeoKylin Linux操作系统已启用rsyslogd服务，但是在配置文件中未设置日志服务器地址，无法将本机审计记录进行转发，无法避免审计记录受到未预期的删除、修改或覆盖。
可以 目前应该是有日志收集服务器，还未配置。

4.	NeoKylin Linux操作系统在配置文件/etc/hosts.allow、/etc/hosts.deny中未通过设定终端接入方式或网络地址范围对通过网络进行管理的管理终端进行限制。

不建议，allow的IP地址比较多，且不确定，deny段也不太确定。

5.	NeoKylin Linux操作系统在配置文件/etc/profile文件中HISTSIZE=1000，无法保证存有敏感数据的存储空间被释放或重新分配前得到完全清除。安全加固建议
可以

NeoKylin Linux操作系统 修改建议
1.	建议NeoKylin Linux操作系统在配置文件/etc/login.defs中修改PASS_MAX_DAYS、PASS_MIN_LEN等参数的值，或者在配置文件/etc/pam.d/system-auth中添加password  requisite pam_cracklib.so  retry=3 difok=3 minlen=8 ucredit=-1 lcredit=-2 dcredit=-1 ocredit=-1。
2.	建议NeoKylin Linux操作系统在配置文件/etc/pam.d/system-auth中添加auth required pam_tally2.so  deny=3 unlock_time=30 even_deny_root root_unlock_time=30。
3.	建议NeoKylin Linux操作系统在配置文件/etc/rsyslog.conf中设置日志服务器地址，将本机日志进行转存。
4.	建议NeoKylin Linux操作系统在配置文件/etc/hosts.allow中添加ALL:ALL禁用所有的远程连接，在配置文件/etc/hosts.deny中添加sshd:XX.XX.XX.XX仅允许某个地址或者地址段能够远程访问。
5.	建议NeoKylin Linux操作系统在配置文件/etc/profile文件中将参数HISTSIZE设置为0，保证存有敏感数据的存储空间被释放或重新分配前得到完全清除。
