

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

    @logger = vakoo.logger.context

  index: ->

    async.waterfall(
      [
        async.apply async.parallel, {
          mainTemplate: async.apply @staticDecorator.createTemplate, "main_page"
          mainSliderData: @storageDecorator.mainSliderData
        }

        ({mainTemplate, mainSliderData}, taskCallback)->

          taskCallback null, mainTemplate {
            categories: mainSliderData
          }

        @staticDecorator.createPage

      ]
      @context.sendHtml
    )

  category: ->

    category = @context.requester.path.split("/")[-1...][0]

    limit = 20
    skip = 0
    pagesCount = 0
    page = +(@context.request.query.p or 0)
    skip = page * limit

    async.waterfall(
      [

        async.apply @storageDecorator.getProductsCountByCategory, category

        (count, taskCallback)->
          pagesCount = Math.ceil(count / limit)
          taskCallback()

        async.apply async.parallel, {
          category: async.apply @storageDecorator.getCategory, category
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

        ({category, products, categoryTemplate, categories, productTemplate, paginationTemplate}, taskCallback)=>

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

          taskCallback null, categoryTemplate({
            category
            products
            categories
            sort: @utilsDecorator.getSort()
            pagination: @utilsDecorator.createPagination page, pagesCount
          })
        @staticDecorator.createPage
      ]
      @context.sendHtml
    )

  product: ->

    product = @context.request.path.split("/")[-1...][0]

    async.waterfall(
      [
        async.apply async.parallel, {
          product: async.apply @storageDecorator.getProductByAlias, product
          productTemplate: async.apply @staticDecorator.createTemplate, "product"
        }
        ({product, productTemplate}, taskCallback)=>

          unless product
            return @category()

          product.miniDesc = product.desc
          product.url = @utilsDecorator.createUrl product
          product.price = @utilsDecorator.numberFormat product.price, true

          product.freeDelivery = product.price >= 4000
          product.freeDeliverySum = 4000
          product.delivery = 300

          if product.params?.items
            product.params.items = @utilsDecorator.createParamsClasses product.params.items

          append = '...<br/><br/><a href="javascript:goToDescr()" class="btn btn-success btn-sm"><i class="fa fa-list"></i> Подробнее о товаре</a>'

          if product.desc.length >= 150
            trimmedString = product.desc.substr(0, 150);
            trimmedString = trimmedString.substr(0, Math.min(trimmedString.length, trimmedString.lastIndexOf(" ")))
            product.miniDesc = trimmedString + append

          taskCallback null, productTemplate({product})
        @staticDecorator.createPage
      ]
      @context.sendHtml
    )


module.exports = ShopController
