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
      name: "Image downloader"
      time: "*/5 * * * * *"
      script: "image-getter"
    }
  ]

  initializers: false


module.exports = config
