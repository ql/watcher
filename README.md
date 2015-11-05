# Watcher, пример инструмента для мониторинга сайтов #

Простой мониторинг на основе EventMachine. Для взаимодействия с внешними библиотеками, написанными в синхронном стиле использует Resque.


## Требования ##
  Redis

## Запуск ##

    bundle install
    cp config.yaml.sample config.yaml
    PIDFILE=./resque.pid BACKGROUND=yes QUEUE=notifications rake resque:work
    bundle exec ruby main.rb

## Известные недостатки ##

Теряет состояние при перезапуске. Отправляет уведомления с ограниченной точностью по времени.

