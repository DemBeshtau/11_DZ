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

# Функция возвращает наименование управляющего терминала процесса из<br/>
# из седьмого поля файла stat
function get_tty {
    term=$(cat "$1" | awk '{print $7}')
    # В двух следующих условиях полученное значение проверяется на соответствие<br/>
    # терминалам tty (значение 1024 соответствует tty0, 1025 - tty1, и.т.д) и<br/>
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

# Функция возвращает статус процесса из третьего поля файла stat
function get_state {
    # sed используется для удаления второго поля, сожержащего имя исполняемого файла<br/>.
    # Данная мера применена из-за того, что в имени исполняемого файла могут содержаться<br/>
    # пробелы, мешающие корректной работе awk, в котором поле разделителя по-умолчанию<br/>
    # настроено на пробелы.  
    echo $(cat "$1" | sed -e 's/(.*)//' | awk '{print $2}')
}

# Функция возвращает полную командную строку пользовательского процесса из файла cmdline<br/>
function get_cmd_sys {
    echo $((tr -d '\0' </$1) | awk '{print $1}') 
}

# Функция возвращает имя исполняемого файла процесса ядра из файла stat
function get_cmd_kern {
    echo $(cat "$1" | awk '{print $2}' | sed -e 'y/()/[]/')
}

# Функция предназначена для определения режимов процесса - пользовательский, либо ядра<br/>
# В ходе анализа различных режимов процессов было установлено, что для процессов ядра,<br/>
# значения полей 23 (vsize) и 24 (rss) равны 0. Следовательно, если возвращаемое значение<br/>
# равно 0, то процесс является процессом ядра. Если возвращаемое значение больше 0, то<br>
# процесс пользовательский. 
function is_vsz_rss {
    vsz=$(cat "$1" | awk '{print $23}')
    rss=$(cat "$1" | awk '{print $24}')
    ((total=vsz+rss))
    echo $total
}

# Функция возвращает значение 
function get_time {
    utime=$(cat $1 | awk '{print $14}')
    cutime=$(cat $1 | awk '{print $16}')
    ((total_sec=(utime+cutime)/100))
    ((minutes=total_sec/60 % 60))
    ((seconds=total_sec % 60))
    printf -v total '%2d:%02d' $minutes $seconds
    echo $total 
}

for directory in $(ls /proc)
do
    if [[ ( -d /proc/$directory ) && ( $directory =~ ^[0-9]+$ ) ]]
    then
        if [[ $(is_vsz_rss /proc/$directory/stat) -eq 0 ]]
        then
            cmd=$(get_cmd_kern /proc/$directory/stat)
        else
            cmd=$(get_cmd_sys /proc/$directory/cmdline)
        fi
        pid=$(get_pid /proc/$directory/stat)
        tty=$(get_tty /proc/$directory/stat)
        state=$(get_state /proc/$directory/stat)
        time_=$(get_time /proc/$directory/stat)
    fi
    total+=$pid'\t'$tty'\t'$state'\t'$time_'\t'$cmd'\n';
done
echo -e "PID\tTTY\tSTAT\tTIME\tCOMMAND"
echo -en "$total" | sort -g
exit 0
```
