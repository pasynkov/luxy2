projectConfig =

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
      name: "luxy"
      username: "luxy"
      password: "085bdb2261"
      host: "db.vakoo.ru"
      enable: true

    mysql:
      host: "db.vakoo.ru"
      user: "luxy"
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
