config =

  web: false

  storage:
    mysql:
      enable: false
    redis: {}


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
    filePath: "/home/web/static/luxy"
    storeFiles: true
  }


module.exports = config
