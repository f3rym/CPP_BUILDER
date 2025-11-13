# 🛠️ Сборка проекта с помощью feBuild.sh

# feBuild v2

## 🔹 Описание

`feBuild` — это скрипт сборки C++ проектов с поддержкой блоков и зависимостей шаблонов и заголовков.  

**Основные особенности:**

- Компиляция файлов `.cpp` по блокам (по 3 файла на блок по умолчанию).  
- Файлы `.tpp` и `.ipp` используются как **зависимости**, но **не компилируются сами**.  
- При изменении `.h`, `.tpp`, `.ipp` пересобираются только нужные `.cpp` файлы.  
- Любая ошибка компиляции:  
  - удаляются все `.a` архивы и объектники (`build/binary` и `build/obj`);  
  - выполняется **одна попытка полной пересборки**;  
  - если снова ошибка — сборка останавливается, `main` не запускается.  
- Любая ошибка линковки → сборка останавливается сразу.  
- Скрипт создаёт бинарник `build/main` только при успешной компиляции и линковке.  

**Папки и файлы:**

build/
├─ binary/ # Архивы .a по блокам
├─ obj/ # Объектные файлы .o
├─ main # Финальный исполняемый файл
├─ listSRC.txt # Список всех .cpp файлов
├─ listH.txt # Список всех заголовков и шаблонов
└─ prev/ # Сохранённые старые списки (для истории)

## 🔹 Использование

1. Копируйте скрипт `feBuild.sh` в корень проекта.  
2. Дайте права на выполнение:

```bash
chmod +x feBuild.sh
```

Запуск сборки:

```bash
./feBuild.sh
```
🔹 Принцип работы
Скрипт сканирует проект на .cpp файлы и создаёт список зависимостей .h, .tpp, .ipp.

Проверяет, есть ли build/main и какие файлы изменились с момента последней сборки.

Компилирует только необходимые блоки, учитывая зависимости.

Линкует все свежесозданные .a архивы в build/main.

Если компиляция любого блока не удалась — скрипт очищает архивы и объектники и пробует сборку заново.

После успешной сборки запускается build/main.

🔹 Пример работы
Исходная структура проекта:


project/
 ├─ main.cpp
 ├─ myf.cpp
 ├─ source/
 │   ├─ Apartment.cpp
 │   └─ Apartment.h
 └─ header/
     ├─ Exp.h
     └─ ExpInput.h
Первый запуск сборки:

```bash
$ ./feBuild.sh
Found 3 .cpp files and 4 header/template files
Checking if compilation is needed...
First compilation...

➤ Compiling block 1 (files 1–3)...
g++ -c "./main.cpp" -o "build/obj/main.o"
✔ build/obj/main.o is up-to-date
g++ -c "./myf.cpp" -o "build/obj/myf.o"
✔ build/obj/myf.o is up-to-date
g++ -c "./source/Apartment.cpp" -o "build/obj/Apartment.o"
✔ build/obj/Apartment.o is up-to-date

ar rcs build/binary/block1.a build/obj/main.o build/obj/myf.o build/obj/Apartment.o
✔ Block 1 -> build/binary/block1.a created

g++ -o build/main -Wl,--start-group build/binary/block1.a -Wl,--end-group
✔ Linking done!

✅ Build completed successfully!
```
Если изменился Exp.h:

```bash
$ ./feBuild.sh
Changes detected, compiling...

➤ Compiling block 1 (files 1–3)...
g++ -c "./main.cpp" -o "build/obj/main.o"
✔ build/obj/main.o is up-to-date
g++ -c "./myf.cpp" -o "build/obj/myf.o"
✔ build/obj/myf.o is up-to-date
g++ -c "./source/Apartment.cpp" -o "build/obj/Apartment.o"
✔ build/obj/Apartment.o is up-to-date

g++ -o build/main -Wl,--start-group build/binary/block1.a -Wl,--end-group
✔ Linking done!

✅ Build completed successfully!
```
Если при компиляции блока произошла ошибка:

```bash
✗ Error compiling: ./source/Apartment.cpp
⚠ Cleaning binary archives due to compilation error...
⚠ Error detected. Cleaning archives and retrying full rebuild...
✗ Full rebuild failed. Build aborted.
```
Архивы и объектники очищены.

Скрипт завершился с кодом 1.

main не запускается.
```