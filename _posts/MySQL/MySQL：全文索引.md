---
title: MySQL 全文索引
categories:
  - MySQL
date: 2020-05-01 23:44:23
---

# 1. 概述

- 在 MySQL 5.7.6 之前，全文索引只支持英文全文索引，不支持中文全文索引，需要利用分词器把中文段落预处理拆分成单词，然后存入数据库
- 从 MySQL 5.7.6 开始，MySQL 内置了 ngram 全文解析器，用来支持中文、日文、韩文分词

# 2. ngram 全文解析器

- ngram 就是一段文字里面连续 n 个字的序列，ngram 全文解析器能够对文本进行分词，每个单词是连续的 n 个字符的序列
- 例如，使用 ngram 全文解析器对“生日快乐”进行分词：
```
n=1, 生, 日, 快, 乐
n=2, 生日, 日快, 快乐
n=3, 生日快, 日快乐
n=4, 生日快乐
```
- MySQL 中使用全局变量 ngram_token_size 来配置 ngram 中 n 的大小，其取值范围是 1 到 10，默认值为 2，可以使用 `show variables like 'ngram_token_size';` 查看值
- 通常 ngram_token_size 设置为要查询的单词的最小字数，如果需要搜索单字，就要把 ngram_token_size 设置为 1，在默认值是 2 的情况下，搜索单字是得不到任何结果的
- 中文单词最少是两个汉字，推荐使用默认值 2 （这意味着单独搜索一个汉字是搜不到结果的）
- 全局变量 ngram_token_size 的两种设置方法：
    - 启动 mysqld 命令时设置 : `mysqld --ngram_token_size=2`
    - 修改 MySQL 配置文件
```
[mysqld] 
ngram_token_size=2
```

# 3. 创建全文索引

- 创建表的同时创建全文索引，注意一定要指明解析器 ngram，否则可能对中文无效 :
```sql
drop table if exists item;
create table item(
  id bigint primary key,
  name varchar(31) not null,
  price float not null,
  note varchar(127) not null default '',
  status tinyint not null default 0,
  constraint unq_name unique(name),
  fulltext key ftx_name(name) WITH PARSER ngram
);
insert into item values(1, '妙蛙种子', 299.0, '', 0);
insert into item values(2, '小火龙', 399.0, '', 0);
insert into item values(3, '火恐龙', 299.0, '', 0);
insert into item values(4, '皮卡丘', 999.0, '', 0);
insert into item values(5, '小锯鳄', 799.0, '', 0);
insert into item values(6, '小火猴', 1399.0, '', 0);
insert into item values(7, '小火狐', 599.0, '', 0);
insert into item values(8, '小拳石', 699.0, '', 0);
insert into item values(9, '超梦', 4999.0, '', 0);
insert into item values(10, '妙蛙草', 5999.0, '', 0);
insert into item values(11, '妙蛙花', 3999.0, '', 0);
```
- 通过 alter table 的方式添加 :
```sql
alter table item add fulltext index ftx_name(name) with parser ngram;
```
- 通过 create index 的方式 :
```sql
create fulltext index ftx_name on item (name) with parser ngram; 
```

# 4. 全文索引的使用

- 常用的全文检索模式有两种 : 自然语言模式 (natural language mode) 和 boolean 模式 (boolean mode)
- 自然语言模式是 MySQL 默认的全文检索模式，自然语言模式比较基础，不能指定操作符，不能指定关键字必须出现或者不能出现等复杂查询，多个用空格分开的词之间是或的关系
- boolean 模式可以使用操作符，可以支持指明特定关键字必须出现或者必须不能出现，还能指定特定的关键词是权重高还是权重低等复杂查询
- 特别注意，ngram 进行中文分词时，ngram_token_size 默认值为 2，即在进行搜索时，只搜索单个字是无法搜索结果的，必须至少两个字以上（ngram 会对列和搜索条件都进行分词，然后进行匹配）

**自然语言模式**

- `select * from item where match(name) against('小火');` 或 `select * from item where match(name) against('小火' in natural language mode);` : 搜索出 name 包含“小火”的记录
- `select * from item where match(name) against('小火 种子');` : 搜索出 name 包含“小火”或“种子”的记录
- 如果想看相关性得分，可以把 `match(name) against('小火 种子') as score` 放到查询列中来得到得分，不相关的得分为 0 : `select *, match(name) against('小火 火龙') as score from item order by score desc;`
- 注意，`select * from item where match(name) against('小');` 是搜不出结果的，至少需要两个词

**boolean 模式**

- boolean 模式可以利用一些特殊符号进行一些更高级的、更精准的查询
- `select * from item where match(name) against('+小火' in boolean mode);` : 必须包含小火，+ 表示必须包含
- `select * from item where match(name) against('+小火 -火龙' in boolean mode);` : 必须包含小火，且不能包含火龙，- 表示不能包含
- 下面介绍 boolean 常用运算符 :
    - `小火 种子` : 无操作符，表示或，包含小火或者种子
    - `+小火 +火龙` : 必须同时包含小火和火龙
    - `+小火 火猴` : 必须包含小火，如果同时含有火猴则相关性更高
    - `+小火 -火龙` : 必须包含小火，且不包含火龙
    - `+小火 ~火龙` : 必须包含小火，如果包含了火龙，则相关性比不包含的更低（经测试无用）
    - `+小火 +(>火猴 <火狐)` : 必须包含“小火和火猴”或者“小火和火狐”，且“小火和火猴”的相关性比“小火和火狐”高
    - `小*` : 通配支持单个字，查询以小开头的记录
    - `"some words"` : 使用双引号把要搜素的词括起来，效果类似于like '%some words%'，例如“some words of wisdom”会被匹配到，而“some noise words”就不会被匹配（好像是用于英文的，中文要先分词）

# 5. 补充说明

- 只能在类型为 CHAR, VARCHAR, TEXT 的字段上创建全文索引
- 全文索引只支持 InnoDB 和 MyISAM 引擎
- `match (columnName) AGAINST ('keywords')` : match() 函数使用的字段名，必须要与创建全文索引时指定的字段名一致，例如前面建表时是 `match(name)` 则查询时也必须是 `match(name)`
- 如果要对多个字段分别查询，就要在多个字段上分别创建全文索引，如果要统一查询多个字段，则可以联合多个字段创建全文索引，但查询时要指定你要使用哪个索引，且格式要和创建时保持一致
- match() 函数使用的字段名只能是同一个表的字段，因为全文索引不能够跨多个表进行检索
- 如果要导入大数据集，使用先导入数据再在表上创建全文索引的方式要比先创建全文索引再导入数据的方式快很多，所以全文索引时很影响 TPS 的