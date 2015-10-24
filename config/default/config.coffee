config =

  storage:

    enable: true

    redis:
      main:
        enable: true
        startupClean: true
      remote:
        enable: true
        host: "db.vakoo.ru"
        password: "085bdb2261"

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
    port: 8090

  loggers:
    routesInitializer: {}
    cacheInitializer: {}
    yandex: {}

  initializers: [
    "cache"
    "routes"
  ]

  city: {
    redirect: false
    defaultCity: "www"
    chooseCookie: "choose"
  }

  shop: {
    productsPerPage: 20
    freeDelivery: 2900
    deliveryCost: 290
    minCart: 1000
  }




module.exports = config
