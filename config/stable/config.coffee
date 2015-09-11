projectConfig =

  storage:

    enable: true

    redis:
      enable: true
#      startupClean: true

    mongo:
      name: "vakoo"
      enable: true

    mysql:
      host: "rangg.ru"
      user: "root"
      password: "085bdb2261"
      database: "luxy"

  web:
    enable: true
    static: "static"
    cacheStatic: true
    port: 8088

  loggers:
    routesInitializer: {}
    cacheInitializer: {}
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

  initializers: [
#    "aggregator"
    "cache"
    "routes"
  ]




module.exports = projectConfig
