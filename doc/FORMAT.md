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
   - \<function\> - имя функции в исходных кодах, например, "main"
   - \<color\> - имя цвета в тестовой нотации, например, "lightcyan"

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
   - \<name\> - краткое имя-идентификатор, например, '#41'
   - \<description\> - развёрнутое описание проблемы, например, 'Проблемы с моделированием аллокации памяти'
   - \<regexp\> - регялярное выражение для поиска по коду функции, например, '\bmalloc\b'

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
   - done - доказанные функции
   - lemma-proof-required - функции, доказанные без доказательства лемм
   - partial-specs - функции с не до конца разработанными(частичными) спецификациями
   - specs-only - функции с разработанными спецификациями, которые не могут быть доказаны
   - \<function\> - имя функции в исходных кодах, например, "main"

Функция не может одновременно присутствовать в разных категориях.

[Пример конфигурации](/config/status_ext2.conf.sample).

## Dismember
**TBD**

[Пример конфигурации](/config/dismember-compile-test.conf.sample).

## Web
**TBD**

[Пример конфигурации](/web/.config.sample).

## Calls Status
**TBD**
