
path = require "path"
async = require "async"
_ = require "underscore"
Handlebars = require "handlebars"

TEMPLATES_PATH = "templates"

StorageDecorator = require "../decorators/storage"

class StaticDecorator


  constructor: (@context)->

    @redis = vakoo.storage.redis.main
    @redisTtl = 600

    @static = new vakoo.classes.Static
    @storageDecorator = new StorageDecorator

  readTemplate: (name, callback)=>
    templatePath = path.resolve TEMPLATES_PATH, "#{name}.hbs"

    @redis.get(
      "#{vakoo.configurator.instanceName}-static-#{templatePath}"
      async.apply @static.readFile, templatePath
      callback
    )

  createTemplate: (name, callback)=>
    @readTemplate name, (err, html)->
      callback err, unless err then Handlebars.compile(html)

  getFooter: (callback)=>
    @createTemplate "partials/footer", (err, template)=>
      callback err, template?({city: @context.city})

  getCatalogMenu: (callback)=>

    async.waterfall(
      [
        async.apply async.parallel, {
          template: async.apply @createTemplate, "partials/catalog_menu"
          tree: @storageDecorator.getCategoriesTree
        }
        ({template, tree}, taskCallback)=>

          taskCallback null, template({tree, city: @context.city})

      ]
      callback
    )

  getSearch: (callback)=>
    @createTemplate "partials/search", (err, template)=>
      callback err, template?({city: @context.city})

  getToolbar: (callback)=>
    @createTemplate "partials/toolbar", (err, template)=>
      callback err, template?({city: @context.city})

  getBreadcrumbs: ([common]..., callback)=>

    common ?= {}

    common.city = @context.city

    @createTemplate "partials/breadcrumbs", (err, template)=>
      callback err, template?(common)

  createPage: ([content, common]..., callback)=>

    async.waterfall(
      [
        async.apply async.parallel, {
          layoutTemplate: async.apply @createTemplate, "layout"
          commonData: async.apply async.parallel, {
            footer: @getFooter
            catalog_menu: @getCatalogMenu
            search: @getSearch
            toolbar: @getToolbar
            breadcrumbs: async.apply @getBreadcrumbs, common
          }
        }
        ({layoutTemplate, commonData}, taskCallback)=>

          commonData ?= {}

          commonData.common = common
          commonData.city = @context.city

          taskCallback null, layoutTemplate _.extend({content}, commonData)

      ]
      callback
    )


module.exports = StaticDecorator