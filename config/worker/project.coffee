projectConfig =

  storage:

    enable: true

    redis:
      enable: true

    mongo:
      name: "luxy"
      enable: true

    mysql:
      host: "rangg.ru"
      user: "root"
      password: "085bdb2261"
      database: "luxy"

  loggers:
    aggregator: {}

  aggregator: {
    csv: "http://luxy.sexy/files/p5s.csv"
    xml: "http://uslada-shop.ru/yml/offers.xml"
    filePath: "/Users/Pasa/dev/tmp/files"
    storeFiles: false
    collectionName: "products2"
#    csv: "http://stripmag.ru/datafeed/p5s.csv"
#    csv: "http://stripmag.ru/datafeed/p5s_ling.csv"
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
