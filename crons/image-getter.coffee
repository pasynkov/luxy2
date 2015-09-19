
async = require "async"
request = require "request"
fs = require "fs"

class ImageGetter

  constructor: (callback)->

    @logger = vakoo.logger.imageGetter

    @redis = vakoo.storage.redis.main

    async.waterfall(
      [
        (taskCallback)=>
          @redis.client.llen "images-queue", taskCallback
        (len, taskCallback)=>
          unless len
            return taskCallback "Not images in queue"

          @redis.client.lpop "images-queue", taskCallback

        (item, taskCallback)=>
          [link, destination] = item.split("==")

          @logger.info "Start pipe file `#{link}` to `#{destination}`"

          request.get link
          .on "error", (err)=>
            @logger.error "Get image from `#{link}` failed with err: `#{err}`"
            @addImageToDownloadQueue link, destination, taskCallback
          .on "end", ->
            taskCallback()
          .pipe fs.createWriteStream(destination)

      ]
      (err)=>
        if err
          if err isnt "Not images in queue"
            @logger.warn "Complete with err: `#{err}`"
        callback()
    )

  addImageToDownloadQueue: (link, destination, callback)=>

    @logger.info "add image `#{link}` to queue"

    @redis.client.rpush(
      "images-queue"
      "#{link}==#{destination}"
      (err)->
        callback err
    )




module.exports = ImageGetter