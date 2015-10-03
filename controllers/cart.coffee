

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
    data = null
    json = @context.request.body.json
    unless json
      return @context.sendHtml "404"

    try
      data = JSON.parse json
    catch
      return @context.sendHtml "404"

    async.waterfall(
      [
        async.apply async.parallel, {
          template: async.apply @staticDecorator.createTemplate, "cart"
          products: async.apply @storageDecorator.getProductsByAlias, _.map(data.items, (p)->p.alias)
          breadcrumbs: async.apply async.waterfall, [
            (miniTaskCallback)->
              miniTaskCallback null, crumbs: [
                {title: "Главная", url: "/"}
                {title: "Корзина"}
              ]
            @staticDecorator.getBreadcrumbs
          ]
        }
        ({template, products, breadcrumbs}, taskCallback)=>

          total = 0
          delivery = false

          products = _.map(
            products
            (product)=>
              product.url = @utilsDecorator.createUrl product
              product.count = _.find(data.items, (i)-> i.alias is product.alias)?.count or 1
              if _.isNaN +product.count
                product.count = 1
              product.total = product.count * product.price
              total += product.total
              product.total = @utilsDecorator.numberFormat product.total
              product.price = @utilsDecorator.numberFormat product.price
              return product
          )

          if total < @shopConfig.freeDelivery
            delivery = @shopConfig.deliveryCost

          orderTotal = total + +delivery

          deliveryMessage = """При заказе на сумму свыше
            <b>#{ @utilsDecorator.numberFormat @shopConfig.freeDelivery}</b> <span class="fa fa-rouble"/>
            доставка осуществляется бесплатно.
          """

          taskCallback(
            null
            template({
              products
              breadcrumbs
              total: @utilsDecorator.numberFormat total
              orderTotal: @utilsDecorator.numberFormat orderTotal
              delivery
              deliveryMessage
              checkout: total >= @shopConfig.minCart
              city: @context.city
            })
            {title: "Корзина"}
          )


        @staticDecorator.createPage
      ]
      @context.sendHtml
    )

  checkout: ->

    data = null
    json = @context.request.body.json
    unless json
      return @context.sendHtml "404"

    try
      data = JSON.parse json
    catch
      return @context.sendHtml "404"

    async.waterfall(
      [
        async.apply async.parallel, {
          template: async.apply @staticDecorator.createTemplate, "checkout"
          products: async.apply @storageDecorator.getProductsByAlias, _.map(data.items, (p)->p.alias)
          breadcrumbs: async.apply async.waterfall, [
            (miniTaskCallback)->
              miniTaskCallback null, crumbs: [
                {title: "Главная", url: "/"}
                {title: "Оформление заказа"}
              ]
            @staticDecorator.getBreadcrumbs
          ]
        }
        ({products, breadcrumbs, template}, taskCallback)=>

          total = 0
          delivery = false

          products = _.map(
            products
            (product)=>
              product.url = @utilsDecorator.createUrl product
              product.count = _.find(data.items, (i)-> i.alias is product.alias)?.count or 1
              if _.isNaN +product.count
                product.count = 1
              product.total = product.count * product.price
              total += product.total
              product.total = @utilsDecorator.numberFormat product.total
              product.price = @utilsDecorator.numberFormat product.price
              return product
          )

          if total < @shopConfig.freeDelivery
            delivery = @shopConfig.deliveryCost

          orderTotal = total + +delivery


          taskCallback(
            null
            template({
              products
              breadcrumbs
              total: @utilsDecorator.numberFormat total
              orderTotal: @utilsDecorator.numberFormat orderTotal
              delivery
              city: @context.city
            })
            {title: "Оформление заказа"}
          )

        @staticDecorator.createPage
      ]
      @context.sendHtml
    )

  order: ->
    async.waterfall(
      [
        async.apply async.parallel, {
            template: async.apply @staticDecorator.createTemplate, "thanks"
            products: async.apply @storageDecorator.getProductsByAlias, _.keys(@context.request.body.products)
            breadcrumbs: async.apply async.waterfall, [
              (miniTaskCallback)->
                miniTaskCallback null, crumbs: [
                  {title: "Главная", url: "/"}
                  {title: "Спасибо за покупку!"}
                ]
              @staticDecorator.getBreadcrumbs
            ]
          }
        ({template, products, breadcrumbs}, taskCallback)=>

          unless products?.length
            return taskCallback "null"

          order = _.defaults @context.request.body, {
            status: "new"
            productCount: 0
            total: 0
            date: new Date
            ip: @context.request.ip
            ua: @context.request.userAgent
          }

          order.products = _.map(
            products
            (product)=>
              product.count = +@context.request.body.products[product.alias]
              product.total = product.count * product.price
              order.productCount += product.count
              order.total += product.total
              return product
          )

          vakoo.mongo.collectionNative("orders").insert order, (err, r)=>

            order._id = r?.ops[0]?._id

            taskCallback(
              err
              template({
                products
                breadcrumbs
                order: JSON.stringify order
                city: @context.city
              })
              {title: "Спасибо за покупку!"}
            )
        @staticDecorator.createPage
      ]
      @context.sendHtml
    )

module.exports = ShopController