# Формат конфигурационных файлов
## Priority
Используется YAML. Структура в общем виде:
```YAML
priority:
   lists:
      - &1
         - <function>
         - <function>
         - ...

      - &2
         - <function>
         - <function>
         - <function>
         - ...

      ...

      - &n
         - <function>
         - <function>
         - ...

   colors:
        *1 : <color>
        *2 : <color>
        *3 : <color>
        ...
        *n : <color>
```
Где:
   - **\<function\>** - имя функции в исходных кодах, например, "main"
   - **\<color\>** - имя цвета в тестовой нотации, например, "lightcyan"

Количество приоритетов произвольно. Количество цветов должно соответствовать количеству приоритетов. Имена цветов можно брать из [документации программы dot](http://www.graphviz.org/content/color-names). Функции должны быть уникальны в каждом приоритете.

[Пример конфигурации](/config/priority_ext2.conf.sample).

## Issues
Используется YAML. Структура в общем виде:
```YAML
issues:
   <name>:
      description: <description>
      re: '<regexp>'
   <name>:
      description: <description>
      re: '<regexp>'
   ...
```
Где:
   - **\<name\>** - краткое имя-идентификатор, например, '#41'
   - **\<description\>** - развёрнутое описание проблемы, например, 'Проблемы с моделированием аллокации памяти'
   - **\<regexp\>** - регулярное выражение для поиска по коду функции, например, '\bmalloc\b'

## Status
Используется YAML. Структура в общем виде:
```YAML
done:
   - <function>
   - <function>
   ...

lemma-proof-required:
   - <function>
   - <function>
   ...

partial-specs:
   - <function>
   - <function>
   ...

specs-only:
   - <function>
   - <function>
   ...
```
Где:
   - **done** - доказанные функции
   - **lemma-proof-required** - функции, доказанные без доказательства лемм
   - **partial-specs** - функции с не до конца разработанными(частичными) спецификациями
   - **specs-only** - функции с разработанными спецификациями, которые не могут быть доказаны
   - **\<function\>** - имя функции в исходных кодах, например, "main"

Функция не может одновременно присутствовать в разных категориях.

[Пример конфигурации](/config/status_ext2.conf.sample).

## Extricate
```
full=1
single=1
cache=0

plugin=inline
plugin-inline-text=begin^1^#define KERNRELEASE "TEST"

plugin=exec
plugin-exec-file=scripts/compile.sh
```
Конфигурация состоит из опций коммандной строки программы. Опции должны располагаться на отдельных строках. Флаги указываются через равенство единице или нулю. Конфигурация будет считываться по-умолчанию, в командной строке можно после переопределить определенные флаги.

[Пример конфигурации](/config/extricate-compile-test.conf.sample).

## Web
```
kernel_dir   = /spec-utils/linux-4.17/
module_dir   = /spec-utils/linux-4.17/fs/ext2/
cache        = 1
cache_file   = /spec-utils/web/_web.graph.cache
out          = /spec-utils/web/
format       = svg

priority = 1
done     = 1

priority_config_file  = /spec-utils/config/priority_ext2.conf.sample
status_config_file    = /spec-utils/config/status_ext2.conf.sample
dbfile                = /spec-utils/web/ext2.db
```

В конфигурации используются следующие параметры:
   - **kernel_dir** - путь к директории ядра (абсолютный путь)
   - **module_dir** - путь к модулю (абсолютный путь)
   - **cache** - использовать кеш или нет
   - **cache_file** - файл для кеширования (абсолютный путь). Опция нужна, если cache выставлен 
   - **out** - директория для хранения временных файлов (тут сохраняются карты)
   - **format** - формат карты поумолчанию. Доступны такие же параметры, как в программе graph + нужно чтобы формат поддерживался браузером
   - **priority** - отмечать на карте приоритеты
   - **done** - отмечать на карте статус верификации функции
   - **priority_config_file** - путь до конфигурационного файла приоритетов (абсолютный путь). Опция нужна, если priority выставлен
   - **status_config_file** - путь до конфигурационного файла статуса функций (абсолютный путь). Опция нужна, если status выставлен
   - **dbfile** - файл базы sqlite для отображения информации по правому клику мыши (абсолютный путь)

[Пример конфигурации](/web/.config.sample).

## Calls Status
```
functions:
   +/-:
      - copy_from_user
      - copy_to_user
      - put_cred
      - d_find_alias
      - get_cred
      - dput
      - dget
      - fget
      - fput
      - getxattr


   +:
      - memcpy
      - kfree
      - kmalloc
      - kzalloc
      - memset
      - memcpm
      - printk
      - SOCKET_I
      - atomic_inc
      - strcat
      - strcmp
      - strcpy
      - strncmp

macros:
   ready:
      - IS_RDONLY

   '!':
      - likely
      - unlikely
      - EXPORT_SYMBOL
```

На верхнем уровне используются два ключа - functions и macros. На третьем уровне должны использоваться имена функций/макросов в соответствии с первым уровнем. Имена функций и макросов должны быть уникальными. На втором уровне используются произвольные ключи. Ключами с этого уровня помечаются соответствующие макросы и функции в отчетах. Так, в данном примере функция ```memcpy``` в графе отчета **Статус** имеет значение ```+```, ```copy_from_user``` - ```+/-```.
