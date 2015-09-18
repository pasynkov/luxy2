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
    {
      name: "Image downloader"
      time: "*/5 * * * * *"
      script: "image-getter"
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
