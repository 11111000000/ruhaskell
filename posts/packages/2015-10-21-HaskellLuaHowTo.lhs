---
author:         Алексей Пирогов
title:          Haskell + Lua = дружба!
description:    Использование Lua-скриптов в Haskell-программах
tags:           haskell,lua,scripting
hrefToOriginal: http://astynax.github.io/posts/2015-10-21-HaskellLuaHowTo.html
---

Обратите внимание на то, что эта статья является исходником программы
- она написана на [Literate Haskell](https://wiki.haskell.org/Literate_programming)!
Запустить эту программу можно с помощью
[stack](https://github.com/commercialhaskell/stack/blob/master/doc/install_and_upgrade.md)
командой:

```shell
stack --resolver lts-3.2 runghc --package hslua --package bytestring имя_файла.lhs
```

Использование **Lua**-скриптов в программе на **Haskell**
===

Иногда бывает очень полезно иметь возможность расширения/изменения поведения
программы без её перекомпиляции. Для решения этой задачи часто используют
*скриптовые языки*, встраивая их интерпретаторы прямо в основную программу.
Один из наиболее популярных встраиваемых скриптовых языков, это [Lua](http://www.lua.org).
Это динамически типизированный процедурный язык программирования, очень
экономно расходующий ресурсы процессора и памяти. Эта статья не рассматривает
сам Lua, а демонстрирует лишь типичный сценарий его использования, поэтому тем,
кто желает познакомиться с этим языком поближе, автор рекомендует почитать
официальное руководство по оному.

Итак, приступим. Начнем, как обычно, с импортов:

> import           Control.Monad         (when, void)
> import qualified Scripting.Lua         as Lua
> import qualified Data.ByteString.Char8 as BSS

"Скриптом" нам послужит такая строка:

> script :: String
> script = unlines
>   [ "function pine(height)                             "
>   , "   for i = 1, height do                           "
>   , "      write(  replicate(height - i,      \" \"))  "
>   , "      writeLn(replicate(1 + (i - 1) * 2, \"*\"))  "
>   , "   end                                            "
>   , "end                                               " ]

Автору этот код видится достаточно очевидным для любого читателя,
знакомого с каким-либо процедурным языком. Делает же функция ``pine``
следующее: при вызове для некоего числа, скажем, ``5``, она всего лишь
выводит на экран (печатает в ``stdout``) "ёлочку" с высотой, равной этому
числу:

```
    *
   ***
  *****
 *******
*********
```

Заметьте, что скрипт не обязан быть строкой, более того, чаще всего
скрипты расширения именно из файлов и читаются. Это, собственно, и
позволяет модифицировать их после того, как основная программа скомпилирована.
В данном же случае скрипт хранится в строке только лишь для того, чтобы
literate-исходник оставался самодостаточным.

Теперь напишем основную программу:

> main :: IO ()
> main = do

Для начала инициализируем интерпретатор и загрузим стандартные библиотеки:

>   lua <- Lua.newstate
>   Lua.openlibs lua

Теперь стоит снова обратить свой взор на код скрипта, а точнее, на процедуры
``write`` и ``writeLn`` и функцию ``replicate``. Дело в том, что это не встроенные
в язык элементы - функция и процедуры инжектируются в пространство имен скрипта
нашей основной программой! Т.е. мы способны не только вызывать скрипт снаружи,
мы можем расширять "лексикон" самого скриптового языка!
Регистрируются функции довольно просто:

>   Lua.registerhsfunction lua "write"     $ putStr   . BSS.unpack
>   Lua.registerhsfunction lua "writeLn"   $ putStrLn . BSS.unpack
>   Lua.registerhsfunction lua "replicate" $ \n s ->
>     (return $ BSS.concat $ replicate n s) :: IO BSS.ByteString

Последняя функция выглядит чуть сложнее первых двух, но так же довольно проста.
Регистрируемые функции должны принимать аргументы нескольких простых типов,
таких как числа (``Int``) и байтовые строки (``ByteString``), и возвращать столь
же простые значения, но уже в контексте ``IO``. Так, первые две
зарегистрированные функции - настоящие процедуры, возвращающие ``IO()``,
т.е. "ничего".

Окружение готово, теперь нужно загрузить скрипт:

>   res <- Lua.loadstring lua script "script"

Строка ``"script"`` здесь - "имя" скрипта, которое интерпретатор использует
в сообщениях об ошибках. Из файла скрипт бы загружался так:

>   -- res <- Lua.loadfile lua "replua.lua"

Скрипт может и не загрузиться и это стоит проверить:

>   when (res /= 0) $ error "Can't load script!"

Загруженный скрипт можно выполнить (с начала первой строки, ``0 0``):

>   Lua.call lua 0 0

Скрипт загружен, можно что-нибудь из него повызывать:

>   void $ Lua.callproc lua "pine" (10 :: Int)

И, конечно же, корректно завершить работу с интерпретатором:

>   Lua.close lua

Вот и всё! Тем Lua и хорош (не только этим, конечно же), что легко встраивается,
в т.ч. и в Haskell :)
