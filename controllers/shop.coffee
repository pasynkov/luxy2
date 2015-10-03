

async = require "async"
_ = require "underscore"
handlebars = require "handlebars"

ContextDecorator = require "../decorators/context"
StaticDecorator = require "../decorators/static"
StorageDecorator = require "../decorators/storage"
UtilsDecorator = require "../decorators/utils"

class ShopController

  constructor: (@context)->

    @staticDecorator = new StaticDecorator @context
    @storageDecorator = new StorageDecorator
    @utilsDecorator = new UtilsDecorator @context
    @contextDecorator = new ContextDecorator @context

    @shopConfig = vakoo.configurator.config.shop

    @logger = vakoo.logger.context

  index: ->

    async.waterfall(
      [
        @contextDecorator.createCity
        async.apply async.parallel, {
          mainTemplate: async.apply @staticDecorator.createTemplate, "main_page"
          mainSliderData: @storageDecorator.mainSliderData
          mainPage: async.apply @storageDecorator.getPage, "main"
        }

        ({mainTemplate, mainSliderData, mainPage}, taskCallback)->

          taskCallback null, mainTemplate({
            categories: mainSliderData
            title: mainPage.title
            meta: mainPage.meta
          }), {title: mainPage.title, meta: mainPage.meta}

        @staticDecorator.createPage

      ]
      @context.sendHtml
    )

  page: ->


    page = @context.requester.path.split("/")[-1...][0]

    async.waterfall(
      [
        @contextDecorator.createCity
        async.apply async.parallel, {
          template: async.apply @staticDecorator.createTemplate, "page"
          page: async.apply @storageDecorator.getPage, page
          related: @storageDecorator.getPageList
          breadcrumbs: async.apply async.waterfall, [
            async.apply @storageDecorator.getPage, page
            (page, miniTaskCallback)->
              miniTaskCallback null, crumbs: [
                {title: "Главная", url: "/"}
                {title: page.title}
              ]
            @staticDecorator.getBreadcrumbs
          ]
        }

        ({template, page, related, breadcrumbs}, taskCallback)=>

          page.content = handlebars.compile(page.content) {city: @context.city}

          taskCallback null, template({
            page
            related
            breadcrumbs
          }), {title: page.title, meta: page.meta}

        @staticDecorator.createPage
      ]
      @context.sendHtml
    )

  category: ->

    category = @context.requester.path.split("/")[-1...][0]

    limit = @shopConfig.productsPerPage
    skip = 0
    pagesCount = 0
    page = +(@context.request.query.p or 0)
    skip = page * limit

    async.waterfall(
      [
        @contextDecorator.createCity
        async.apply @storageDecorator.getProductsCountByCategory, category

        (count, taskCallback)->
          pagesCount = Math.ceil(count / limit)
          taskCallback()

        async.apply async.parallel, {
          category: async.apply @storageDecorator.getCategory, category
          breadcrumbs: async.apply async.waterfall, [
            async.apply @storageDecorator.getBreadcrumbsForCategory, category
            (crumbs, subTaskCallback)->
              crumbs[crumbs.length - 1].url = false
              subTaskCallback null, {crumbs}
            @staticDecorator.getBreadcrumbs
          ]
          products: async.apply @storageDecorator.getProductsByCategory, category, {
            skip
            limit
            sort: @utilsDecorator.getSort()
          }
          categories: async.apply @storageDecorator.getCategoriesByParent, category
          categoryTemplate: async.apply @staticDecorator.createTemplate, "category"
          productTemplate: async.apply @staticDecorator.readTemplate, "partials/product_card"
          paginationTemplate: async.apply @staticDecorator.readTemplate, "partials/pagination"
        }

        ({category, products, categoryTemplate, categories, productTemplate, paginationTemplate, breadcrumbs}, taskCallback)=>

          unless category
            return taskCallback "Category not found"

          handlebars.registerPartial "product", productTemplate
          handlebars.registerPartial "pagination", paginationTemplate

          products = _.map(
            products
            (product)=>
              product.url = @utilsDecorator.createUrl product
              product.price = @utilsDecorator.numberFormat product.price, true
              return product
          )

          categories = _.map(
            categories
            (category, k)=>
              if k >= 4
                category.hide = true

              category.url = @utilsDecorator.createUrl category
              return category
          )

          category.description = handlebars.compile(category.description) {city: @context.city}

          taskCallback null, categoryTemplate({
            category
            products
            categories
            breadcrumbs
            city: @context.city
            sort: @utilsDecorator.getSort()
            pagination: @utilsDecorator.createPagination page, pagesCount
          }), {title: category?.title, meta: category?.meta}
        @staticDecorator.createPage
      ]
      @context.sendHtml
    )

  minifyProduct: ->

    @storageDecorator.getProductByAlias @context.request.query.id, (err, product)=>
      if err
        return @context.sendHtml err

      unless product
        return @context.sendHtml "Not found product"

      @context.responser.send {
        _id: product._id
        title: product.title
        alias: @context.request.query.id
        url: @utilsDecorator.createUrl product
        price: product.price
      }


  product: ->

    product = @context.request.path.split("/")[-1...][0]

    async.waterfall(
      [
        @contextDecorator.createCity
        async.apply async.parallel, {
          product: async.apply @storageDecorator.getProductByAlias, product
          productTemplate: async.apply @staticDecorator.createTemplate, "product"
          breadcrumbs: async.apply async.waterfall, [
            async.apply @storageDecorator.getBreadcrumbsForProduct, product
            (crumbs, subTaskCallback)->
              subTaskCallback null, {crumbs}
            @staticDecorator.getBreadcrumbs
          ]
        }
        ({product, productTemplate, breadcrumbs}, taskCallback)=>

          unless product
            return @category()

          product.miniDesc = product.desc
          product.url = @utilsDecorator.createUrl product
          product.price = @utilsDecorator.numberFormat product.price, true

          product.freeDelivery = product.price >= @shopConfig.freeDelivery
          product.freeDeliverySum = @shopConfig.freeDelivery
          product.delivery = @shopConfig.deliveryCost

          if product.params?.items
            product.params.items = @utilsDecorator.createParamsClasses product.params.items

          append = '...<br/><br/><a href="javascript:goToDescr()" class="btn btn-success btn-sm"><i class="fa fa-list"></i> Подробнее о товаре</a>'

          if product.desc.length >= 150
            trimmedString = product.desc.substr(0, 150);
            trimmedString = trimmedString.substr(0, Math.min(trimmedString.length, trimmedString.lastIndexOf(" ")))
            product.miniDesc = trimmedString + append

          taskCallback null, productTemplate({product, breadcrumbs, city: @context.city}), {title: product.title, meta: product.meta}
        @staticDecorator.createPage
      ]
      @context.sendHtml
    )

  redirector: ->
    _id = @context.request.query.id or @context.request.query.product

    vakoo.mongo.collection("product").findOne {_id}, (err, product)=>
      if err
        return @context.sendHtml err
      else if product
        @context.response.redirect @utilsDecorator.createUrl product
      else
        return @context.sendHtml "Nothing"


module.exports = ShopController
