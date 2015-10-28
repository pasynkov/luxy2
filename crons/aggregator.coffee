
async = require "async"
_ = require "underscore"
request = require "request"
uuid = require "node-uuid"
mkdirp = require "mkdirp"
transliteration = require("transliteration")
slugify = (word)->
  return transliteration.slugify(
    word
    {lowercase: true, separator: "-"}
  )
{parseString} = require "xml2js"

crypto = require "crypto"
path = require "path"
fs = require "graceful-fs"

StorageDecorator = require "../decorators/storage"

COL_CATEGORIES = "categories2"
COL_PRODUCTS = "products2"

categoryObject = ->
  _.clone({
    "_id" : "",
    "title" : "",
    "description" : "",
    "anonce" : "",
    "image" : {
      "id" : "",
      "path" : "",
      "name" : "",
      "alt" : ""
    },
    "meta" : {
      "description" : "",
      "title" : "",
      "keywords" : ""
    },
    "mainImage" : {
      "id" : "",
      "path" : "",
      "name" : "",
      "alt" : ""
    },
    "mainSmallImage" : {
      "id" : "",
      "path" : "",
      "name" : "",
      "alt" : ""
    },
    "main" : false,
    "ancestors" : [],
    "parent" : "",
    "import" : {
      "id" : 0,
      "parent_id" : 0
    }
  })

class Aggregator

  constructor: (callback)->

    @logger = vakoo.logger.aggregator

    @logger.info "Start aggregate products"

    @storageDecorator = new StorageDecorator

    @redis = vakoo.storage.redis.main

    @mongo = vakoo.storage.mongo.main

    @instanceName = vakoo.configurator.instanceName

    @config = vakoo.configurator.config.aggregator

    @updated = 0
    @inserted = 0
    @stored = 0

    async.waterfall(
      [
        @aggregateProducts
        @createCategories
        @updatePrices
      ]
      (err)=>
        if err
          @logger.error "Crashed with err: `#{err}`"
        else
          @logger.info "Aggregate successfully"
        callback()
    )

  updatePrices: (callback)=>

    @logger.info "Start update prices and set categories for products"

    async.waterfall(
      [

        (taskCallback)=>

          @redis.getex(
            "productlist"
            (redisCallback)=>

              async.waterfall(
                [
                  (subTaskCallback)=>
                    request.get @config.xml, subTaskCallback
                  (res, body, subTaskCallback)=>
                    parseString body, subTaskCallback
                  (xml, subTaskCallback)=>

                    subTaskCallback null, _.map(
                      xml.yml_catalog.shop[0].offers[0].offer
                      (item)->
                        {
                        price: +item.price[0]
                        cat_id: +item.categoryId[0]
                        sku: +item.vendorCode[0]
                        }
                    )
                ]
                redisCallback
              )
            (60 * 30)
            taskCallback
          )

        (list, taskCallback)=>

          @logger.info "XML received, start update `#{list.length}` objects"

          async.map(
            list
            (item, done)=>

              @mongo.collectionNative(COL_CATEGORIES).findOne {"import.id": item.cat_id}, (err, cat)=>
                if err
                  return done err

                unless cat
                  return done()

                @mongo.collectionNative(COL_PRODUCTS).update(
                  {sku: item.sku}
                  $set:
                    price: item.price
                    category: cat._id
                    ancestors: _.compact _.flatten [cat.ancestors, [cat._id]]
                  (err)->
                    done err
                )

            taskCallback
          )

        (..., taskCallback)=>

          @logger.info "Products updated"
          taskCallback()

      ]
      callback
    )



  createCategories: (callback)=>

    @logger.info "Start create categories"

    async.waterfall(
      [

        (taskCallback)=>
          @redis.getex(
            "catlist"
            (redisCallback)=>
              async.waterfall(
                [
                  (subTaskCallback)=>

                    request.get @config.xml, subTaskCallback

                  (res, body, subTaskCallback)=>

                    parseString body, subTaskCallback

                  (xml, subTaskCallback)=>
                    catList = _.map(
                      xml.yml_catalog.shop[0].categories[0].category
                      (cat)->
                        return {
                        title: cat._.replace("\n", "")
                        id: +cat.$.id
                        parentId: if _.isNaN(+cat.$.parentId) then 0 else +cat.$.parentId
                        }
                    )

                    subTaskCallback null, catList

                ]
                redisCallback
              )
            (60 * 30)
            taskCallback
          )

        (catList, taskCallback)=>

          rootCats = _.filter catList, (c)-> not c.parentId

          groupedByParent = _.groupBy catList, (c)-> c.parentId

          tree = _.map(
            rootCats
            (c)->
              c.childs = _.map(
                groupedByParent[c.id]
                (child)->
                  child.childs = _.map(
                    groupedByParent[child.id]
                    (child2)->
                      child2.childs = groupedByParent[child2.id]
                      return child2
                  )
                  return child
              )
              return c
          )

          catsHref =
            86: "strapony"
            162: "falloprotezy"
            88: "falloprotezy"
            82: "vaginalnye-shariki"
            102: "stimulyaciya-klitora"
            107: "stimulyaciya-grudi"
            108: "vakuumnye-pompy"
            140: "vibratory"
            63: "eroticheskaya-odezhda-i-bele"
            79: "vakuumnye-i-gidro-pompy"
            80: "vaginy-i-masturbatory"
            83: "kolca-i-nasadki-na-penis"
            84: "kolca-i-nasadki-na-penis"
            94: "vaginy-i-masturbatory"
            101: "seks-kukly-zhenshiny"
            120: "analnaya-stimulyaciya/:slug"
            74: "analnaya-stimulyaciya"
            67: "falloimitatory"
            65: "vibratory"
            92: "geli-i-smazki"
            115: "eroticheskie-igry"
            71: "fetish-i-bdsm"
            119: "prezervativy"
            117: "intimnaya-gigiena"
            126: "knigi-i-zhurnaly"
            161: "seks-igrushki"
            91: "podarki-suveniry-i-prikoly"
            111: "intimnaya-kosmetika/:slug"
            157: "intimnaya-gigiena/:slug"
            124: "mebel-i-postelnoe-bele"
            149: "seks-mashiny"
            155: "fetish-i-bdsm/:slug"
            74: "analnaya-stimulyaciya/:slug"
            168: "vibratory/vibratory-:slug"

          for root, r in tree
            root.href = catsHref[root.id] ? false

            if root.href and root.href.indexOf(":slug") >= 0
              root.href = root.href.replace(":slug", slugify root.title)

            tree[r] = root

            for child, c1 in root.childs

              if catsHref[child.id]
                child.href = catsHref[child.id]
              else
                if root.href
                  child.href = "#{root.href}/#{slugify child.title}"
                else
                  child.href = false

              if child.href and child.href.indexOf(":slug") >= 0
                child.href = child.href.replace(":slug", slugify child.title)

              tree[r][c1] = child

          categories = []

          for root in tree
            if root.href
              categories.push {
                id: root.id
                title: root.title
                href: root.href
              }
            for child in root.childs
              if child.href
                categories.push {
                  id: child.id
                  title: child.title
                  href: child.href
                }

          taskCallback null, categories

        (categories, taskCallback)=>

          async.mapSeries(
            categories
            (cat, done)=>

              if (catstree = cat.href.split("/")).length > 1

                async.mapSeries(
                  catstree
                  (subcat, subDone)=>
                    @mongo.collectionNative(COL_CATEGORIES).findOne {_id: subcat}, (err, subCatObject)=>
                      if err
                        return subDone err
                      if subCatObject
                        if _.indexOf(catstree, subcat) is (catstree.length - 1)
                          @mongo.collectionNative(COL_CATEGORIES).update {_id: subcat}, {$set: {title: cat.title, import: {id: cat.id}}}, (err)->
                            subDone err
                        else
                          subDone()
                      else
                        subCatObject = categoryObject()
                        subCatObject._id = subcat
                        if _.indexOf(catstree, subcat) is (catstree.length - 1)
                          subCatObject.title = cat.title
                          subCatObject.import = {id: cat.id}
                        @mongo.collectionNative(COL_CATEGORIES).insert subCatObject, (err)->
                          subDone err
                  (err)=>
                    done err
                )

              else
                @mongo.collectionNative(COL_CATEGORIES).update(
                  {_id: cat.href}
                  {$set: {import: {id: cat.id}}}
                  done
                )

            (err)->
              taskCallback err, categories
          )

        (categories, taskCallback)=>

          @logger.info "Start set ancestors"

          async.map(
            categories
            (cat, done)=>

              if (catstree = cat.href.split("/")).length > 1

                async.map(
                  catstree
                  (subcat, subDone)=>
                    @mongo.collectionNative(COL_CATEGORIES).findOne {_id: subcat}, subDone
                  (err, catlist)=>
                    catlist = _.map catlist, (c)-> _.pick(c, ["_id", "title", "parent", "ancestors"])

                    for caty, i in catlist
                      unless i
                        continue
                      catlist[i].parent = catlist[i-1]._id
                      catlist[i].ancestors = _.compact _.flatten [catlist[i-1].ancestors, [catlist[i-1]._id]]

                    async.map(
                      catlist
                      (catFromList, subsubDone)=>
                        @mongo.collectionNative(COL_CATEGORIES).update {_id: catFromList._id}, {$set: catFromList}, subsubDone
                      done
                    )

                )

              else
                done()

            (err)->
              taskCallback err
          )

        (taskCallback)=>

          @logger.info "Done create categories"
          taskCallback()

      ]
      callback
    )


  aggregateProducts: (callback)=>

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

    @logger.info "Start store objects"

    async.waterfall(
      [
        (taskCallback)=>
          @redis.client.keys "#{@instanceName}-raw-product-*", taskCallback
        (keys, taskCallback)=>
          async.map(
            keys
            (redisKey, done)=>
              @redis.client.get redisKey, (err, json)=>

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
                product.distributor = raw["Производитель"]
                product.distributor_sku = raw["Артикул производителя"]
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

                @stored++
                @storeObject product, (err)=>
                  if err
                    return done err
                  @redis.client.del redisKey, (err)->
                    done err

            taskCallback
          )
        (..., taskCallback)=>
          @logger.info "Successfully inserted `#{@inserted}` and updated `#{@updated}` from stored `#{@stored}`"
          taskCallback()
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
                return done()

              if +product.sku is 37290
                console.log product.photos, imagePath
                console.log product


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
                  (exists, taskCallback)=>

                    if exists
                      return taskCallback()

                    return @addImageToDownloadQueue photoLink, imagePath, taskCallback

                    request.get photoLink
                    .on "error", (err)=>
                      @addImageToDownloadQueue photoLink, imagePath, taskCallback
                    .on "end", ->
                      taskCallback()
                    .pipe fs.createWriteStream(imagePath)

                  (taskCallback)->
                    product.photos[pIndex] = imagePath
                    taskCallback()
                ]
                done
              )

            taskCallback
          )
        (..., taskCallback)=>

          @mongo.collectionNative(COL_PRODUCTS).findOne(
            {sku: product.sku}
            taskCallback
          )

        (mongoObj, taskCallback)=>
          if mongoObj
            if +product.sku is 37290
              console.log "update"
              console.log {$set:
                available: product.available
                price: product.price
                tradePrice: product.tradePrice
                lastUpdate: new Date()
                distributor_sku: product.distributor_sku
                images: @createObject(product).images
                image: @createObject(product).image
                isNew: false
              }

            @updated++
            @mongo.collectionNative(COL_PRODUCTS).update(
              {_id: mongoObj._id}
              {
                $set:
                  available: product.available
                  price: product.price
                  tradePrice: product.tradePrice
                  lastUpdate: new Date()
                  distributor_sku: product.distributor_sku
                  images: @createObject(product).images
                  image: @createObject(product).image
                  isNew: false
              }
              (err, res)->
                if +product.sku is 37290
                  console.log typeof mongoObj._id
                  console.log mongoObj
                  console.log err, res
                taskCallback()
            )
          else
            @inserted++
            @mongo.collectionNative(COL_PRODUCTS).insert(
              @createObject(product)
              taskCallback
            )
      ]
      callback
    )

  createObject: (product)=>

    image = product.photos[0].replace(@config.filePath.replace("/files",""), "")

    images = product.photos[1...]

    return {
    title: product.title
    alias: slugify("#{product.sku} #{product.title}")
    category: ""
    ancestors: []
    price: product.price
    tradePrice: product.tradePrice
    sku: product.sku
    distributor_sku: product.distributor_sku
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
          ["Брэнд", product.distributor]
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
      (image)=>
        image = image.replace(@config.filePath.replace("/files",""), "")
        return {
        name: ""
        alt: product.title
        path: image
        }
    )
    lastUpdate: new Date()
    isNew: true
    }

  addImageToDownloadQueue: (link, destination, callback)=>

    @logger.info "add image `#{link}` to queue"

    @redis.client.rpush(
      "images-queue"
      "#{link}==#{destination}"
      (err)->
        callback err
    )







module.exports = Aggregator