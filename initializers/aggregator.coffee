
async = require "async"
_ = require "underscore"
request = require "request"
uuid = require "node-uuid"
mkdirp = require "mkdirp"
slugify = require("transliteration").slugify

crypto = require "crypto"
path = require "path"
fs = require "graceful-fs"

StorageDecorator = require "../decorators/storage"

class Aggregator

  constructor: (callback)->

    @logger = vakoo.logger.aggregator

    @logger.info "Start aggregate products"

    @storageDecorator = new StorageDecorator

    @redis = vakoo.storage.redis.main

    @mongo = vakoo.storage.mongo.main

    @instanceName = vakoo.configurator.instanceName

    @config = vakoo.configurator.projectConfig.aggregator

    async.waterfall(
      [
        @getProducts
      ]
      (err)=>
        if err
          @logger.error "Crashed with err: `#{err}`"
        else
          @logger.info "Aggregate successfully"
        callback()
    )

  getProducts: (callback)=>

    @redis.client.keys "#{@instanceName}-raw-product-*", (err, keys)=>

      if err
        return callback err

      if keys.length
        @logger.info "Founded `#{keys.length}` records"
        return @productsToRecords callback
      else
        @logger.info "Start get products csv from `#{@config.csv}`"

      request.get @config.csv, (err, response, body)=>
        if err
          return callback err

        rows = body.split "\n"

        @logger.info "Received `#{rows.length}` rows"

        names = _.map(
          _.clone rows[0].split ";"
          (name)->
            if name[0] is "\""
              name = name[1...]
            if name[-1...] is "\""
              name = name[...-1]
            name
        )

        table = rows[1...-2]

        products = _.map(
          table
          (row)->
            return _.object(names, row.split ";")
        )

        async.map(
          products
          (product, done)=>
            @redis.client.set "#{@instanceName}-raw-product-#{uuid.v1()}", JSON.stringify(product), done
          (err)=>
            if err
              return callback err
            @productsToRecords callback
        )

  productsToRecords: (callback)=>

    async.waterfall(
      [
        (taskCallback)=>
          @redis.client.keys "#{@instanceName}-raw-product-*", taskCallback
        (keys, taskCallback)=>
          async.map(
            keys
            (key, done)=>
              @redis.client.get key, (err, json)=>

                if err
                  return done err

                raw = JSON.parse json
                product = {}

                raw = _.mapObject(
                  raw
                  (value)->
                    if value[0] is "\""
                      value = value[1...]
                    if value[-1...] is "\""
                      value = value[...-1]
                    return value
                )

                product.sku = +raw["Артикул"]
                product.title = raw["Наименование"]
                product.desc = raw["Описание"]
                product.distributor = raw["Производитель"] + ": " + raw["Артикул производителя"]
                product.price = +raw["Цена (Розница)"]
                product.tradePrice = +raw["Цена (Опт)"]
                product.available = +raw["Можно купить"] is 1

                for key, value of raw

                  if value
                    if key is "Размер/Цвет"
                      product.size = value.split(" ")[0]
                      product.color = value.split(" ")[1]
                    if key is "Материал"
                      product.material = value
                    if key is "Батарейки"
                      product.battery = value
                    if key is "Упаковка"
                      product.packing = value
                    if key is "Вес (брутто)"
                      product.weight = value
                    if key.indexOf("Фотография") > -1
                      if key.indexOf("маленькая") is -1
                        product.photos ?= []
                        product.photos.push value

                @storeObject product, (err)=>
                  if err
                    return done err
                  @redis.client.del key, (err)->
                    done err

            taskCallback
          )
        (products, taskCallback)->

      ]
      callback
    )

  storeObject: (product, callback)=>

    async.waterfall(
      [
        (taskCallback)=>

          async.map(
            product.photos
            (photoLink, done)=>


              pathHash = crypto.createHash("sha256").update(product.sku + product.title).digest("hex")
              photoPath = path.resolve @config.filePath, [pathHash[0..1], pathHash[2..3], pathHash[4...]].join("/")
              pIndex = product.photos.indexOf photoLink
              imagePath = path.resolve photoPath, "#{pIndex}#{path.extname photoLink}"

              unless @config.storeFiles
                product.photos[pIndex] = imagePath
                return taskCallback()


              async.waterfall(
                [
                  (taskCallback)->
                    fs.exists photoPath, (exists)->
                      taskCallback null, exists
                  (exists, taskCallback)->
                    if exists
                      taskCallback()
                    else
                      mkdirp photoPath, taskCallback

                  (..., taskCallback)->
                    fs.exists imagePath, (exists)->
                      taskCallback null, exists
                  (exists, taskCallback)->

                    if exists
                      return taskCallback()

                    request.get photoLink
                    .on "error", taskCallback
                    .on "end", ->
                      taskCallback()
                    .pipe fs.createWriteStream(imagePath)

                  (taskCallback)->
                    product.photos[pIndex] = imagePath
                ]
                done
              )

            taskCallback
          )
        (taskCallback)=>

          @mongo.collection(@config.collectionName).findOne(
            {sku: product.sku}
            taskCallback
          )

        (mongoObj, taskCallback)=>
          if mongoObj
            console.log mongoObj
          else
            @mongo.collection(@config.collectionName).insert(
              @createObject(product)
              taskCallback
            )
      ]
    )

  createObject: (product)=>

    image = product.photos[0].replace("/Users/Pasa/dev/tmp", "")

    images = product.photos[1...]

    return {
      title: product.title
      alias: slugify("#{product.sku} #{product.title}", {lowercase: true, separator: "-"})
      category: ""
      ancestors: []
      price: product.price
      tradePrice: product.tradePrice
      sku: product.sku
      desc: product.desc
      shortDesc: ""
      status: "active"
      available: product.available
      meta: {
        description: product.desc
        title: product.title
        keywords: ""
      }
      params: {
        benefits: []
        items: _.filter(
          [
            ["Брэнд", product.distributor.split(":")[0]]
            ["Материал", product.material]
            ["Цвет", product.color]
            ["Размер", product.size]
            ["Упаковка", product.packing]
            ["Батарейки", product.battery]
            ["Вес", product.weight]
          ]
          (item)->
            return item[1]? and item[1].length
        )
      }
      size: {
        current: product.size
        sizes: false
      }
      image: {
        name: ""
        alt: product.title
        path: image
      }
      images: _.map(
        images
        (image)->
          image = image.replace("/Users/Pasa/dev/tmp", "")
          return {
            name: ""
            alt: product.title
            path: image
          }
      )
      lastUpdate: new Date()
      isNew: false
    }






module.exports = Aggregator