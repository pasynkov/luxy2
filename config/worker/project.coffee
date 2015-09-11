projectConfig =

  storage:

    enable: true

    redis:
      enable: true

    mongo:
      name: "vakoo"
      enable: true

    mysql:
      host: "rangg.ru"
      user: "root"
      password: "085bdb2261"
      database: "luxy"

  loggers:
    aggregator: {}

  aggregator: {
    csv: "http://stripmag.ru/datafeed/p5s.csv"
    xml: "http://uslada-shop.ru/yml/offers.xml"
    filePath: "/home/web/services/luxy.sexy/public/files"
    storeFiles: true
  }

  crons: [
#    {
#      name: "Products aggregator"
#      time: "* * * * * *"
#      script: "aggregator"
#    }
  ]

  initializers: [
    "aggregator"
  ]


module.exports = projectConfig