
StorageDecorator = require "../decorators/storage"
async = require "async"

class CacheInitializer

  constructor: (callback)->

    @storageDecorator = new StorageDecorator

    @logger = vakoo.logger.cacheInitializer

    @logger.info "Start cache storage data"

    async.parallel(
      [
        @storageDecorator.getCategoriesTree
        @storageDecorator.mainSliderData
      ]
      (err)=>
        if err
          @logger.error "Cache storage data crash with err: `#{err}`"
        else
          @logger.info "Storage data cached successfully"
        callback()
    )


module.exports = CacheInitializer