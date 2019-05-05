---
title: sysbench使用
date: 2019-03-30 10:10:39
categories: linux
tags: [linux, sysbench]
---


# sysbench 介绍


# sysbench CPU性能测试
sysbench 的 cpu 测试是在指定时间内，循环进行素数计算


## CPU 压测命令
```
# 默认参数，素数上限10000，时间10秒，单线程

sysbench cpu run
```

## 常用参数

**--cpu-max-prime**: 素数生成数量的上限

- 若设置为3，则表示2、3、5（这样要计算1-5共5次）
- 若设置为10，则表示2、3、5、7、11、13、17、19、23、29（这样要计算1-29共29次）
- 默认值为10000

**--threads**: 线程数

- 若设置为1，则sysbench仅启动1个线程进行素数的计算

- 若设置为2，则sysbench会启动2个线程，同时分别进行素数的计算

- 默认值为1


**--time**: 运行时长，单位秒

- 若设置为5，则sysbench会在5秒内循环往复进行素数计算，从输出结果可以看到在5秒内完成了几次，比如配合--cpu-max-prime=3，则表示第一轮算得3个素数，如果时间还有剩就再进行一轮素数计算，直到时间耗尽。
- 每完成一轮就叫一个event
- 默认值为10
- 相同时间，比较的是谁完成的event多


**--events**: event 上限次数

- 若设置为100，则表示当完成100次event后，即使时间还有剩，也停止运行
- 默认值为0，则表示不限event次数
- 相同event次数，比较的是谁用时更少


## 5. 测试示例

这里我们进行如下测试：
```
# 素数上限2万，默认10秒，2个线程

sysbench cpu --cpu-max-prime=20000 --threads=2 run
```

**结果分析**
```
➜  sysbench cpu --cpu-max-prime=20000 --threads=2 run

sysbench 1.0.14 (using system LuaJIT 2.1.0-beta3)

Running the test with following options:
Number of threads: 2 // 指定的线程数为2
Initializing random number generator from current time


Prime numbers limit: 20000 // 每个线程产生的素数上限为20000个

Initializing worker threads...

Threads started!

CPU speed:
    events per second:   841.13 // 所有线程每秒完成了841.13次event

General statistics:
    total time:                          10.0018s // 总共耗费10秒
    total number of events:              8414 // 10秒内所有线程一共完成了8414次event

Latency (ms):
         min:                                    2.33 // 完成1次event最少耗时
         avg:                                    2.38 // 所有event平均耗时
         max:                                    4.47 // 完成1次event最多耗时
         95th percentile:                        2.48 //  95%次event在2.48ms内完成
         sum:                                19998.97 // 线程耗时叠加

Threads fairness:
    events (avg/stddev):           4207.0000/5.00 // // 平均每个线程完成4207次event，标准差为5
    execution time (avg/stddev):   9.9995/0.00 // // 每个线程平均耗时10秒，标准差为0
```

***解释***

- event: 完成了几轮的素数计算
- stddev(标准差): 在相同时间内，多个线程分别完成的素数计算次数是否稳定，如果数值越低，则表示多个线程的结果越接近(即越稳定)。该参数对于单线程无意义。

## 分析依据

同时对多台服务器进行 CPU 性能对比，当素数上限和线程数一致时：
*   相同时间，比较 event
*   相同 event，比较时间
*   时间和 event 都相同，比较 stddev(标准差)

