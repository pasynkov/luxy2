config =

  storage:

    enable: true

    redis:
      enable: true

    mongo:
      name: "vakoo"
      enable: true

  aggregator: {
    csv: "http://stripmag.ru/datafeed/p5s.csv"
    xml: "http://uslada-shop.ru/yml/offers.xml"
    filePath: "/home/web/services/luxy.sexy/public/files"
    storeFiles: true
  }


module.exports = config
