config =

  loggers:
    yandex: {}

  storage:

    redis:
      enable: true

    mongo:
      name: "luxy"
      enable: true

  initializers: false

  city: {
    yaToken: "fbbb03d1ecf844dcb92d5941cdc4c48f"
  }

#https://oauth.yandex.ru/authorize?response_type=code&client_id=d7a66948380142d2ac6bd1c42f7891e4
#    request.post {
#        url: "https://oauth.yandex.ru/token"
#        form: {
#          grant_type: "authorization_code"
#          code: 9228799
#          client_id: "d7a66948380142d2ac6bd1c42f7891e4"
#          client_secret: "b460ddfe9dae486e80f393e39eb9dbf6"
#        }
#      }, (err, res, body)->
#      console.log body

module.exports = config
