create table t(a integer primary key,b text,c real);
with recursive r(i) as (select 1 union all select i+1 from r where i<600000) insert into t select i,"row"||i,i*1.5 from r;
select count(*) from t where b like "%99%";
select * from t where c>1e12;
.shell sleep 60
