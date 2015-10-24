

async = require "async"
_ = require "underscore"
handlebars = require "handlebars"
Robokassa = require "robo-kassa"

crypto = require "crypto"

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

    @robo = new Robokassa {
      login: "luxy.sexy"
      password1: "Webadmin45"
      password2: "Webadmin45_"
    }

  billing: ->

    act = @context.request.query.act

    if act is "result" and @context.request.method is "POST"

      payment_result = @robo.checkPaymentParams @context.request.body

      if payment_result
        @logger.info "Successfully payment order `#{@context.request.body.InvId}`"
        vakoo.storage.redis.remote.client.publish "luxy_order", "Successfully payment order `#{@context.request.body.InvId}`"
      else
        @logger.info "Fail payment order `#{@context.request.body.InvId}`"
        vakoo.storage.redis.remote.client.publish "luxy_order", "Fail payment order `#{@context.request.body.InvId}`"

      vakoo.mongo.collectionNative("orders").update {r_id: +@context.request.body.InvId}, {$set: {payment_result}}, @context.sendHtml

    else

      async.waterfall(
        [
          async.apply async.parallel, {
            template: async.apply @staticDecorator.createTemplate, "thanks"
            breadcrumbs: async.apply async.waterfall, [
              (miniTaskCallback)->
                miniTaskCallback null, crumbs: [
                  {title: "Главная", url: "/"}
                  {title: "Спасибо за покупку!"}
                ]
              @staticDecorator.getBreadcrumbs
            ]
          }
          ({template, breadcrumbs}, taskCallback)=>

            message = "Вы успешно оплатили заказ! С минуты на минуту с вами свяжется наш менеджер!"

            if @context.requester.params.result is "fail"
              message = "Оплата не была проведена. Возможно это ошибка? Свяжитесь с нами по E-mail <a href=\"mailto:shop@luxy.sexy\">shop@luxy.sexy</a>"

            taskCallback(
              null
              template({
                message
                breadcrumbs
                city: @context.city
              })
              {title: "Спасибо за покупку!"}
            )

          @staticDecorator.createPage
        ]
        @context.sendHtml
      )



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

          order.r_id = Math.round(new Date().getTime()/1000)

          vakoo.mongo.collectionNative("orders").insert order, (err, r)=>

            order._id = r?.ops[0]?._id

            vakoo.storage.redis.remote.client.publish "luxy_order", "New order. ID is `#{order._id}`"

            link = null

            summ = order.total + 0

            if order.total < @shopConfig.freeDelivery
              summ += @shopConfig.deliveryCost

            if +order.payment is 0
              link = @robo.createUrl {
                id: order.r_id
                summ
                description: "Оплата заказа в интернет-магазине LUXYsexy"
              }

            taskCallback(
              err
              template({
                link
                summ: @utilsDecorator.numberFormat(summ)
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
