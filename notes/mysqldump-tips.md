# mysqldump tips

使用 mysqldump 迁移数据库，没有主从复制关系。

```
# 默认 --opt 打开会包含 --create-options，这里使用了 --skip-opt 避免锁表等。使用 --create-options 以输出 MySQL 特有的 table schema 属性，比如auto_increment 关键字;
# 使用 --no-autocommit 以避免导入时的 auto commit;
# 可以使用 --no-data 只输出 table schema;
mysqldump -h $DB_HOST -u $DB_USER -p -e -q --set-gtid-purged=OFF --skip-opt --no-autocommit --create-options --single-transaction \
    -r $DB_TABLE.sql -w "updated_on >= '2018-01-01'" $DB_DATABASE $DB_TABLE


# 如果没用 --no-autocommit 导出，则要用 "SET AUTOCOMMIT=0; ....; COMMIT"
mysql -h $DB_HOST -u $DB_USER -p --force -e 'SET FOREIGN_KEY_CHECKS=0; SOURCE $DB_TABLE.sql; SET FOREIGN_KEY_CHECKS=1' $DB_DATABASE 2>&1 | tee some.log

# 设置自增序列增加一百万，不要用 ALTER TABLE，会重建表格很慢
mysql -h $DB_HOST -u $DB_USER -p -e "SELECT @n:=(SELECT MAX(id) FROM $DB_TABLE); START TRANSACTION; INSERT INTO $DB_TABLE (id, ......) VALUES (1000000+@n, ...); ROLLBACK;" $DB_DATABASE

# 增量导出，使用 --no-create-info 不再生成 CREATE TABLE 语句，此时也不需要 --create-options 了。
mysqldump -h $DB_HOST -u $DB_USER -p -e -q --set-gtid-purged=OFF --skip-opt --no-autocommit \
    -r $DB_TABLE-extra.sql -w "id > ...." --no-create-info $DB_DATABASE $DB_TABLE

# 再次导入，不关闭外键检查
mysql -h $DB_HOST -u $DB_USER -p --force -e 'SOURCE $DB_TABLE-extra.sql' $DB_DATABASE 2>&1 | tee $DB_TABLE-extra.log
```
