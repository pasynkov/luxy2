
async = require "async"
_ = require "underscore"

COL_CATEGORIES = "categories2"
COL_PRODUCTS = "products2"

class StorageDecorator

  constructor: (@context)->

    @mysql = vakoo.storage.mysql?.main
    @redis = vakoo.storage.redis.main
    @mongo = vakoo.storage.mongo.main

    @redisTtl = 600


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

  getMainSliderCategories: (callback)=>

    @redis.getex(
      "#{vakoo.configurator.instanceName}-main-slider-categories"
      (redisCallback)=>
        @mongo.collection(COL_CATEGORIES).find {main: true}, (err, cursor)->
          if err
            return redisCallback err

          cursor.toArray redisCallback

      600
      callback
    )

  getMainSliderSettings: (callback)=>

    @redis.getex(
      "#{vakoo.configurator.instanceName}-main-slider-settings"
      (redisCallback)=>
        @mysql.client.query "SELECT * FROM main_slider_settings", (err, rows)->
          redisCallback err, _.indexBy(rows, (r)->r.category)
      @redisTtl
      callback
    )

  getCategoriesList: (callback)=>

    @redis.getex(
      "#{vakoo.configurator.instanceName}-categories-list"
      (redisCallback)=>
        @mongo.collection(COL_CATEGORIES).find (err, cursor)->

          if err
            return redisCallback err

          cursor.toArray redisCallback

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

              parents = _.indexBy _.filter(
                categories
                (category)->
                  return not category.parent
              ), (category)-> category._id

              grouped = _.groupBy(
                categories
                (category)->
                  return category.ancestors[0]
              )

              tree = _.mapObject(
                parents
                (category)->
                  category.childs = grouped[category._id] or []
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

        @mongo.collection(COL_CATEGORIES).findOne {_id: name}, redisCallback

      @redisTtl
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

        @mongo.collection(COL_PRODUCTS).find {ancestors: categoryName}, {sort}, (err, cursor)->
          if err
            return redisCallback err
          cursor.skip(skip).limit(limit).toArray redisCallback

      @redisTtl
      callback
    )

  getProductsCountByCategory: (categoryName, callback)=>

    @redis.getex(
      "#{vakoo.configurator.instanceName}-products-count-of-#{categoryName}"
      (redisCallback)=>

        @mongo.collection(COL_PRODUCTS).count {ancestors: categoryName}, redisCallback

      @redisTtl
      callback
    )

  getCategoriesByParent: (category, callback)=>

    @redis.getex(
      "#{vakoo.configurator.instanceName}-subcategories-of-#{category}"
      (redisCallback)=>

        @mongo.collection(COL_CATEGORIES).find {parent: category}, (err, cursor)->
          if err
            return redisCallback err
          cursor.toArray redisCallback

      @redisTtl
      callback
    )

  getProductByAlias: (product, callback)=>

    @redis.getex(
      "#{vakoo.configurator.instanceName}-product-#{product}"
      (redisCallback)=>

        @mongo.collection(COL_PRODUCTS).findOne {alias: product}, redisCallback

      @redisTtl
      callback
    )


module.exports = StorageDecorator