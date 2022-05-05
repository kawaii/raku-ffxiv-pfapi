```sql
insert into pfapi_users values (gen_random_uuid(), 'kawaii', 496805464491687949, now());
```

```sql
insert into pfapi_characters values (35383842, -2, 'test comment', now(), 496805464491687949);
```
```sql
insert into pfapi_encounters values ('Alliance Raids (Endwalker)', 47, 1054, '{2037,2038,2039,2040}', 'Aglaia');
```
```sh
http GET :10000/character/35383842 Auth:b241c27c-1404-43fa-970c-920c9f5a0268
```
