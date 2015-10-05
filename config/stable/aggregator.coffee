config =

  web: false

  storage:
    mysql:
      enable: false
    redis: {}
    mongo:
      name: "luxy"
      username: "luxy"
      password: "085bdb2261"
      host: "db.vakoo.ru"
      enable: true


  loggers:
    aggregator: {}
    imageGetter: {}

  crons: [
    {
      name: "Products aggregator"
      time: "00 00 */4 * * *"
      script: "aggregator"
    }
  ]

  initializers: false

  aggregator: {
    csv: "http://stripmag.ru/datafeed/p5s.csv"
    xml: "http://uslada-shop.ru/yml/offers.xml"
    filePath: "/home/web/services/luxy.sexy/public/files"
    storeFiles: false
  }


module.exports = config
