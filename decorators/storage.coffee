
async = require "async"
_ = require "underscore"

COL_CATEGORIES = "categories2"
COL_PRODUCTS = "products2"

UtilsDecorator = require "../decorators/utils"

class StorageDecorator

  constructor: (@context)->

    @mysql = vakoo.storage.mysql?.main
    @redis = vakoo.storage.redis.main
    @mongo = vakoo.storage.mongo.main

    @redisTtl = 600

    @utilsDecorator = new UtilsDecorator


  mainSliderData: (callback)=>

    async.parallel(
      {
        categories: @getMainSliderCategories
        settings: @getMainSliderSettings
      }
      (err, {categories, settings})->
        if err
          return callback err

        for cat in categories
          settings[cat._id].category = cat

        callback null, settings
    )

  getPage: (alias, callback)=>
    @redis.getex(
      "#{vakoo.instanceName}-page-#{alias}"
      async.apply @mongo.collection("pages").findOne, {alias}
      @redisTtl
      callback
    )

  getPageList: (callback)=>

    @redis.getex(
      "#{vakoo.instanceName}-page-list"
      async.apply(
        @mongo.collection("pages").find
        {
          $query: {alias: {$nin: ["main", "contacts"]}, status: "active", type: "article"}
          $orderby: {label: 1}
        }
        {alias: 1, title: 1, label: 1}
      )
      @redisTtl
      callback
    )


  getMainSliderCategories: (callback)=>

    @redis.getex(
      "#{vakoo.configurator.instanceName}-main-slider-categories"
      async.apply @mongo.collection(COL_CATEGORIES).find, main: true
      @redisTtl
      callback
    )

  getMainSliderSettings: (callback)=>

    @redis.getex(
      "#{vakoo.configurator.instanceName}-main-slider-settings"
      (redisCallback)=>
        @mysql.execute "SELECT * FROM main_slider_settings", (err, rows)->
          redisCallback err, _.indexBy(rows, (r)->r.category)
      @redisTtl
      callback
    )

  getCategoriesList: (callback)=>
    @redis.getex(
      "#{vakoo.configurator.instanceName}-categories-list"
      (redisCallback)=>
        async.waterfall(
          [
            @mongo.collection(COL_CATEGORIES).find
            (categories, taskCallback)=>
              async.map(
                categories
                (category, done)=>
                  @getProductsCountByCategory category._id, yes, (err, count)->
                    category.count = count
                    done err, category
                taskCallback
              )
          ]
          redisCallback
        )
      @redisTtl
      callback
    )


  getCategoriesTree: (callback)=>

    @redis.getex(
      "#{vakoo.configurator.instanceName}-categories-tree"
      (redisCallback)=>

        async.waterfall(
          [

            @getCategoriesList

            (categories, taskCallback)->

              categories = _.map(
                categories
                (category)->
                  category.path = "/" + category.ancestors.concat([category._id]).join("/")
                  return category
              )

              categories = _.filter categories, (c)-> c.count

              parents = _.indexBy _.filter(
                categories
                (category)->
                  return not category.parent
              ), (category)-> category._id

              grouped = _.groupBy(
                categories
                (category)->
                  return category.parent
              )

              tree = _.mapObject(
                parents
                (category)->
                  category.childs = _.map(
                    grouped[category._id] or []
                    (ca)->
                      ca.childs = grouped[ca._id]
                      return ca
                  )

                  unless category.childs.length
                    category.childs = false

                  return category
              )

              taskCallback null, tree

          ]
          redisCallback
        )

      @redisTtl
      callback
    )

  getCategory: (name, callback)=>
    @redis.getex(
      "#{vakoo.configurator.instanceName}-category-#{name}"
      (redisCallback)=>
        @mongo.collectionNative(COL_CATEGORIES).findOne {_id: name}, redisCallback
      @redisTtl
      callback
    )

  getBreadcrumbsForCategory: (categoryName, callback)=>

    @redis.getex(
      "#{vakoo.configurator.instanceName}-breadcrumbs-for-category-#{categoryName}"
      async.apply async.waterfall, [
        async.apply @getCategory, categoryName
        ([category]..., taskCallback)=>
          async.map(
            category?.ancestors or []
            @getCategory
            (err, categories)->
              if err
                return taskCallback err
              taskCallback null, _.compact _.flatten [categories, category]
          )
        (list, taskCallback)=>
          result = _.map(
            list
            (item, i)=>
              {title: item.title, url: @utilsDecorator.createUrl(item)}
          )

          crumbs = [{title: "Главная", url: "/"}]
          crumbs = crumbs.concat result

          taskCallback null, crumbs
      ]
      @redisTtl
      callback
    )

  getBreadcrumbsForProduct: (productName, callback)=>

    async.waterfall(
      [
        async.apply @getProductByAlias, productName
        ([product]..., taskCallback)=>
          unless product
            return taskCallback "Product not found"
          @getBreadcrumbsForCategory product.category, (err, crumbs)=>
            if err
              return taskCallback err

            crumbs.push {
              title: product.title
            }

            taskCallback null, crumbs
      ]
      callback
    )

  getProductsByCategory: (categoryName, opts, callback)=>

    skip = opts.skip
    limit = opts.limit

    sort = _.find opts.sort, run:true

    if sort
      opts.sort = [sort]
      opts.sort.push {url: "sort=available,desc"}
    else
      opts.sort = [{url: "sort=available,desc"}]

    sort = _.map(
      opts.sort
      (s)->
        s = s.url.split("=")[1].split(",")
        s[1] = if s[1] is "asc" then 1 else -1
        return s
    )

    @redis.getex(
      "#{vakoo.configurator.instanceName}-products-of-#{categoryName}-#{skip}-#{limit}-#{sort.join(",")}"
      (redisCallback)=>

        @mongo.collectionNative(COL_PRODUCTS).find {ancestors: categoryName}, {sort}, (err, cursor)->
          if err
            return redisCallback err
          cursor.skip(skip).limit(limit).toArray redisCallback

      @redisTtl
      callback
    )

  getProductsCountByCategory: ([categoryName, onlyAvailable], callback)=>

    onlyAvailable ?= false

    if onlyAvailable
      available = true
    else
      available = {$ne: null}

    @redis.getex(
      "#{vakoo.configurator.instanceName}-products-count-of-#{categoryName}-#{if onlyAvailable then "1" else "0"}"
      async.apply @mongo.collection(COL_PRODUCTS).count, {ancestors: categoryName, available}
      @redisTtl
      callback
    )

  getCategoriesByParent: (category, callback)=>

    @redis.getex(
      "#{vakoo.configurator.instanceName}-subcategories-of-#{category}"
      async.apply @mongo.collection(COL_CATEGORIES).find, {parent: category}
      @redisTtl
      callback
    )

  getProductByAlias: (product, callback)=>

    @redis.getex(
      "#{vakoo.configurator.instanceName}-product-#{product}"
      async.apply @mongo.collection(COL_PRODUCTS).findOne, {alias: product}
      @redisTtl
      callback
    )

  getProductsByAlias: (aliases, callback)=>
    async.map(
      aliases
      @getProductByAlias
      callback
    )

  getCityByIP: (ip, callback)=>
    ipA = ip.split "."
    block = ((+ipA[0] * 256 * 256 * 256) + (+ipA[1] * 256 * 256) + (+ipA[2] * 256) + +ipA[3])
    @mongo.collection("cities").findOne(
      {
        block:{$elemMatch:{begin_ip:{$lte:block},begin_end:{$gte:block}}}
        status: "active"
      }
      callback
    )

  getCityByAlias: (alias, callback)=>

    @redis.getex(
      "#{vakoo.configurator.instanceName}-city-#{alias}"
      async.apply async.waterfall, [
        async.apply @mongo.collection("cities").findOne, {alias:alias, status:"active"}
        (city, taskCallback)->
          unless city
            return taskCallback()
          taskCallback null, {
            alias: city.alias
            title: city.name_ru
            titles:
              "in": city.title_in
              from: city.title_from
            region: city.region
            yandexUin: city.yandexUin
          }
      ]
      @redisTtl
      callback
    )

module.exports = StorageDecorator