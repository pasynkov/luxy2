
StorageDecorator = require "../decorators/storage"
UtilsDecorator = require "../decorators/utils"
async = require "async"

class RoutesInitializer

  constructor: (callback)->

    @storageDecorator = new StorageDecorator
    @utilsDecorator = new UtilsDecorator

    @logger = vakoo.logger.routesInitializer

    @logger.info "Start create routes"

    async.waterfall(
      [
        @storageDecorator.getCategoriesList
        (categories, taskCallback)=>

          for category in categories
            vakoo.web.server.addRoute "get", @utilsDecorator.createUrl(category),"shop", "category"
            vakoo.web.server.addRoute "get", @utilsDecorator.createUrl(category) + "/","shop", "category"

          for category in categories
            vakoo.web.server.addRoute "get", @utilsDecorator.createUrl(category) + "/:product_alias","shop", "product"

          taskCallback null, categories

      ]
      (err, routes)->

        if err

          @logger.error "Creating routes crash with err: `#{err}`"

        else
          @logger.info "Successfully create `#{routes.length}` routes"

        callback()
    )

module.exports = RoutesInitializer