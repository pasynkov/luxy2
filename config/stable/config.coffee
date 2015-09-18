projectConfig =

  storage:

    enable: true

    redis:
      enable: true
      startupClean: true

    mongo:
      name: "vakoo"
      enable: true

    mysql:
      host: "rangg.ru"
      user: "root"
      password: "085bdb2261"
      database: "luxy"

  city: {
    redirect: true
    defaultCity: "www"
    chooseCookie: "choose"
  }

module.exports = projectConfig
