# Работа с процессами #
&ensp;&ensp;Написать реализацию ps ax используя анализ /proc.<br/>
### Ход решения ###
&ensp;&ensp;Работа скрипта основывается на анализе файлов /proc/PID/stat и /proc/PID/cmdline.<br/>
Первый файл состоит из 52 полей данных, в которых содержится информация о процессе, такая как<br/>
PID процесса, имя исполняемого файла, статус процесса, PID родительского процесса, наименование<br/>
управляющего терминала процесса, временные параметры процесса в пользовательском режиме и режиме<br/>
ядра, количество занимаемой виртуальной и реальной памяти и др. Во втором файле содержится полная<br/>
полная командная строка для процесса.
1. Подготовка скрипта<br/>
```shell
#!/bin/bash

# Функция возвращает значение PID процесса из первого поля файла stat
function get_pid {
    echo $(cat "$1" | awk '{print $1}')
}

# Функция возвращает наименование управляющего терминала процесса из
# из седьмого поля файла stat
function get_tty {
    term=$(cat "$1" | awk '{print $7}')
    # В двух следующих условиях полученное значение проверяется на соответствие
    # терминалам tty (значение 1024 соответствует tty0, 1025 - tty1, и.т.д) и
    # pts (значение 34816 соответствует pts0, 34817 - pts1, и.т.д). 
    if [[ ($term -ge 1024) && ($term -le 2048) ]]
    then
        ((tty=term-1024))
        echo "tty/$tty"
    fi
    if [[ ($term -ge 34816) && ($term -le 35840) ]]
    then
        ((pts=term-34816))
        echo "pts/$pts"
    fi
}

# Функция возвращает статус процесса из третьего поля файла stat.
function get_state {
    # sed используется для удаления второго поля, сожержащего имя исполняемого файла.
    # Данная мера применена из-за того, что в имени исполняемого файла могут содержаться
    # пробелы, мешающие корректной работе awk, в котором поле разделителя по-умолчанию
    # настроено на пробелы.  
    echo $(cat "$1" | sed -e 's/(.*)//' | awk '{print $2}')
}

# Функция возвращает полную командную строку пользовательского процесса из файла cmdline.
function get_cmd_sys {
    echo $((tr -d '\0' </$1) | awk '{print $1}') 
}

# Функция возвращает имя исполняемого файла процесса ядра из файла stat.
function get_cmd_kern {
    echo $(cat "$1" | awk '{print $2}' | sed -e 'y/()/[]/')
}

# Функция предназначена для определения режимов процесса - пользовательский, либо ядра
# В ходе анализа различных режимов процессов было установлено, что для процессов ядра,
# значения полей 23 (vsize) и 24 (rss) равны 0. Следовательно, если возвращаемое значение
# равно 0, то процесс является процессом ядра. Если возвращаемое значение больше 0, то
# процесс пользовательский. 
function is_vsz_rss {
    vsz=$(cat "$1" | awk '{print $23}')
    rss=$(cat "$1" | awk '{print $24}')
    ((total=vsz+rss))
    echo $total
}

# Функция возвращает значение времени работы процесса со всеми своими потомками в формате мм:сс
function get_time {
    # Значение из 14 поля файла stat,  показывающее время, в течение которого процесс был 
    # запланирован в пользовательском режиме. Измеряется в тактах.
    utime=$(cat $1 | awk '{print $14}')
    # Значение из 16 поля файла stat, показывающее время ожидания процессом работы своих
    # дочерних процессов, запланированных в пользовательском режиме. Измеряется в тактах.
    cutime=$(cat $1 | awk '{print $16}')
    # Блок выражений, преобразующих значения тактового времени в формат мм:сс
    ((total_sec=(utime+cutime)/100))
    ((minutes=total_sec/60 % 60))
    ((seconds=total_sec % 60))
    printf -v total '%2d:%02d' $minutes $seconds
    echo $total 
}

# Главный цикл скрипта, в котором осуществляется перебор директорий, содержащихся в /proc
for directory in $(ls /proc)
do
    # Отбор директорий, имена которых соответствуют значениям PID процессов
    if [[ ( -d /proc/$directory ) && ( $directory =~ ^[0-9]+$ ) ]]
    then
        # Определение режимов процессов. Если процесс пользовательский, то командная строка
        # читается из файла cmdline, если процесс ядра, то название исполняемого файла читается
        # из второго поля файла stat.    
        if [[ $(is_vsz_rss /proc/$directory/stat) -eq 0 ]]
        then
            cmd=$(get_cmd_kern /proc/$directory/stat)
        else
            cmd=$(get_cmd_sys /proc/$directory/cmdline)
        fi
        # Получаем значение PID процесса
        pid=$(get_pid /proc/$directory/stat)
        # Получаем наименование управляющего терминала процесса 
        tty=$(get_tty /proc/$directory/stat)
        # Получаем значение статуса процесса
        state=$(get_state /proc/$directory/stat)
        # Получаем значение времени работы процесса со всеми своими потомками
        time_=$(get_time /proc/$direc3tory/stat)
    fi
    # Получаем результирующую строку со всеми необходимыми значениями
    total+=$pid'\t'$tty'\t'$state'\t'$time_'\t'$cmd'\n';
done
# Вывод заголовка
echo -e "PID\tTTY\tSTAT\tTIME\tCOMMAND"
# Вывод информации о процессах, отсортированной по PID процессов.
echo -en "$total" | sort -g
exit 0
```
2. Проверка работоспособности скрипта<br/>
```shell

```
