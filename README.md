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
./ps_custom.sh | head -n 20
PID	TTY	STAT	TIME	COMMAND
1		S	19:37	init
2		S	0:00	[kthreadd]
3		S	0:00	[pool_workqueue_release]
4		I	0:00	[kworker/R-rcu_g]
5		I	0:00	[kworker/R-rcu_p]
6		I	0:00	[kworker/R-slub_]
7		I	0:00	[kworker/R-netns]
9		I	0:00	[kworker/0:0H-events_highpri]
10		I	0:00	[kworker/0:1-events]
12		I	0:00	[kworker/R-mm_pe]
14		I	0:00	[rcu_tasks_kthread]
15		I	0:00	[rcu_tasks_rude_kthread]
16		I	0:00	[rcu_tasks_trace_kthread]
17		S	0:00	[ksoftirqd/0]
18		I	0:00	[rcu_preempt]
19		S	0:00	[migration/0]
20		S	0:00	[idle_inject/0]
21		S	0:00	[cpuhp/0]
22		S	0:00	[cpuhp/1]

./ps_custom.sh | tail -n 20
5022		S	0:01	/opt/vscode/code
5032		S	0:19	/opt/vscode/code
5033		S	0:01	/opt/vscode/code
5239	pts/2	S	0:00	bash
5270		S	0:05	/usr/lib64/firefox/firefox-contentproc-childID17-isForBrowser-prefsLen30660-prefMapSize242233-jsInitLen235388-parentBuildID20240207140857-greomni/usr/lib64/firefox/omni.ja-appomni/usr/lib64/firefox/browser/omni.ja-appDir/usr/lib64/firefox/browser{107504f7-9b9b-41f8-9891-85c865b53cdf}4014tab
5316		S	0:02	/usr/lib64/firefox/firefox-contentproc-childID18-isForBrowser-prefsLen30660-prefMapSize242233-jsInitLen235388-parentBuildID20240207140857-greomni/usr/lib64/firefox/omni.ja-appomni/usr/lib64/firefox/browser/omni.ja-appDir/usr/lib64/firefox/browser{bbda49f1-920d-4627-b815-f71a6441851f}4014tab
5525		S	0:00	/usr/lib64/firefox/firefox-contentproc-childID20-isForBrowser-prefsLen30660-prefMapSize242233-jsInitLen235388-parentBuildID20240207140857-greomni/usr/lib64/firefox/omni.ja-appomni/usr/lib64/firefox/browser/omni.ja-appDir/usr/lib64/firefox/browser{c0745f20-5c33-45f7-b4c1-07d861233d4a}4014tab
5663		S	0:00	/usr/lib64/firefox/firefox-contentproc-childID21-isForBrowser-prefsLen30756-prefMapSize242233-jsInitLen235388-parentBuildID20240207140857-greomni/usr/lib64/firefox/omni.ja-appomni/usr/lib64/firefox/browser/omni.ja-appDir/usr/lib64/firefox/browser{edc7a189-f359-47b3-a53b-b197a449a704}4014tab
6141		I	0:00	[kworker/5:0-events]
6281		I	0:00	[kworker/3:1-inet_frag_wq]
6350		I	0:00	[kworker/u16:3-btrfs-endio-write]
6534		I	0:00	[kworker/4:2-events]
6551		I	0:00	[kworker/6:1]
6939		S	0:00	/usr/libexec/gvfsd-http--spawner:1.1/org/gtk/gvfs/exec_spaw/1
6977		S	0:00	/usr/lib64/firefox/firefox-contentproc-childID22-isForBrowser-prefsLen30756-prefMapSize242233-jsInitLen235388-parentBuildID20240207140857-greomni/usr/lib64/firefox/omni.ja-appomni/usr/lib64/firefox/browser/omni.ja-appDir/usr/lib64/firefox/browser{bd320de3-12ba-41d5-88f3-a72263c86135}4014tab
7005		I	0:00	[kworker/2:1-events]
7006		I	0:00	[kworker/1:0]
7038		I	0:00	[kworker/u16:0-events_unbound]
7047		I	0:00	[kworker/u16:1-flush-btrfs-1]
7074		I	0:00	[kworker/u16:4-btrfs-endio-write]

```
