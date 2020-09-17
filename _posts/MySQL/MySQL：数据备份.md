---
title: MySQL 数据备份
categories:
  - MySQL
date: 2020-05-02 01:58:05
---



# 1. 概述 - mysqldump 备份与恢复

- 数据备份分为冷备份和热备份
- 冷备份 : 停止服务进行备份，即停止数据库的写入
- 热备份 : 不挺尸服务进行备份（在线）
- mysql 的 MyIsam 引擎只支持冷备份，InnoDB 支持热备份
- InnoDB 不支持直接复制整个数据库目录和使用 mysqlhotcopy 工具进行物理备份，而是要利用 mysqldump 进行备份

# 2. mysqldump 备份概述

- mysqldump 可以产生两种类型的输出，这取决于是否使用 `--tab=<dir_name>` 选项
    - 不使用 `--tab=<dir_name>` 选项，则 mysqldump 备份得到的文件是纯文本的 sql 文件，其包含了 create, insert 相关语句，可以使用 mysql 指定来恢复这个备份文件
    - 若使用 `--tab=<dir_name>` 选项，则 mysqldump 对备份的数据库中的每个数据表产生两个文件 : 其中 `表名.sql` 文件存储了建表语句，而 `表名.txt` 存储了数据，每行一条记录
- 注意使用第二种方式备份得到的是多个 sql 文件和多个对应的 txt 文件，在进行恢复时要先使用 mysql 指令还原表结构，再使用 `mysqlimport` 或者 `LOAD DATA INFILE` 从 txt 还原数据，较为麻烦
- 使用 `mysqldump -help` 查看备份基础语法，`--help` 可以查看更详细的参数，下面介绍一些详细选项
- `--add-drop-table` : 该选项在每个表的前面加一句 DROP IF EXISTS 语句，这样可以保证导回 MySQL 数据库时不会出错，默认是开启的
- `--add-locks` : 在 INSERT 语句前后加上一个 LOCK TABLE 和 UNLOCK TABLE 语句，以避免导入数据库时其他用户对表进行操作，默认是开启的
- `--tab=<dir_name>` : 使用第二种方式备份数据库
- `--quick 或 --opt` : 默认打开，再转储结果之前会吧全部内容载入到内存中，这在转储大数据量的数据库时可能会产生问题，可以使用 `--skip-opt` 关闭它
- `--compact` : 只输出最重要的语句，不输出注释和删除表语句


# 3. 以 sql 格式备份和恢复数据

- 不使用 `--tab=<dir_name>` 选项，则为以 sql 


## 3.1 备份

- 指定备份路径备份所有数据库 : `mysqldump -h 主机名 -u用户名 -p密码 --all-databases > xxx.sql`
- 指定备份路径备份指定数据库 : `mysqldump -u用户名 -p密码 --databases db1 db2 db3... > xxx.sql`
- 指定备份路径备份单个数据库 : `mysqldump -u用户名 -p密码 --databases db > xxx.sql` （常用）
- 不使用 --databases 选项 : `mysqldump -u用户名 -p密码 db > xxx.sql`
- 注意如果不带有 --databases 选项执行备份，则生成的 sql 中是没有 CREATE DATABASE 和 USE 语句的，在使用 mysql 命令恢复时需要指定一个数据库，这样服务器才知道恢复到哪个数据库中
- 备份某几张表 : `mysqldump -u用户名 -p密码 数据库名 表名1 表名2 ... > xxx.sql`

## 3.2 恢复 

- 通过 mysqldump 备份得到的 sql 文件，如果使用了 --all-databases 或者 --databases 选项，则 sql 文件中包含 CREATE DATABASE 和 USE 语句，不需要指定一个数据库去恢复备份文件
- 从 sql 文件恢复 : `mysql -u密码 -p密码 < xxx.sql`
- 如果 mysqldump 备份的是单个数据库且没有使用 --databases 选项，则备份文件中不包含建库语句的 USE 语句，恢复时需要创建数据库，并在恢复时指定数据库
- `mysql -u用户名 -p密码 数据库名 < xxx.sql`
- 推荐添加 --databases 选项，这样恢复时比较方便


# 4. 以 sql + txt 格式备份和恢复数据

- 略


