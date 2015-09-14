config =

  storage:

    enable: true

    redis:
      enable: true
      startupClean: true

    mongo:
      name: "luxy"
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

  initializers: [
    "cache"
    "routes"
  ]




module.exports = config
