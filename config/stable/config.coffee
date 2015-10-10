projectConfig =

  storage:

    enable: true

    redis:
      enable: true
      startupClean: true

    mongo:
      name: "luxy"
      username: "luxy"
      password: "085bdb2261"
      host: "db.vakoo.ru"
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

  city: {
    redirect: true
    defaultCity: "www"
    chooseCookie: "choose"
  }

module.exports = projectConfig
