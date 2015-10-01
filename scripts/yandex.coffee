xml2js = require "xml2js"
parseString = xml2js.parseString
request = require "request"
async = require "async"
_ = require "underscore"

class Yandex

  constructor: (callback)->

    @logger = vakoo.logger.yandex

    @cityConfig = vakoo.configurator.config.city

    async.waterfall(
      [
        @getHosts
        (hosts, taskCallback)=>

          hosts = _.reject(
            hosts
            (host)->
              host.verification[0].$.state is "VERIFIED"
          )

          unless hosts.length
            taskCallback "Not found unverified sites"

          @logger.info "Finded `#{hosts.length}` unverified hosts"

          async.map(
            hosts
            (host, done)=>

              siteId = host.$.href.split("/")[-1...][0]

              @yaRequest "get", "hosts/#{siteId}/verify", (err, res)->
                if err
                  return done err
                done null, [siteId, res.host.verification[0].uin[0]]

            taskCallback
          )
        (uins, taskCallback)=>

          @logger.info "received `#{uins.length}` successfully, run update cities"

          async.map(
            uins
            ([siteId, uin], done)->

              vakoo.mongo.collectionNative("cities").update {yandexId: siteId}, {$set: {yandexUin: uin}}, (err)->
                done err, siteId

            taskCallback
          )

        (siteIds, taskCallback)->

          vakoo.redis.client.keys "*city*", (err, keys)->

            if err
              return taskCallback err

            unless keys.length
              return taskCallback null, siteIds

            vakoo.redis.client.del keys, (err)->

              if err
                return taskCallback err

              taskCallback null, siteIds

        (siteIds, taskCallback)=>

          @logger.info "cache cleaned successfully, run verify"

          async.map(
            siteIds
            (siteId, done)=>
              @yaRequest "put", "hosts/#{siteId}/verify", {host:{type: "META_TAG"}}, (err, response)->
                done err

            taskCallback
          )

      ]
      callback
    )

  getHosts: (callback)=>
    async.waterfall(
      [
        async.apply @yaRequest, "get", "hosts"
        (yaResult, taskCallback)->
          taskCallback null, yaResult.hostlist.host
      ]
      callback
    )

  yaRequest: ([method, url, postData]..., callback)=>

    async.waterfall(
      [
        (taskCallback)->
          if postData
            builder = new xml2js.Builder headless: true
            xml = builder.buildObject postData
            taskCallback null, xml
          else
            taskCallback()
        ([body]...,taskCallback)=>
          request[method](
            "https://webmaster.yandex.ru/api/v2/#{url}"
            {
              headers: {
                Authorization: "OAuth #{@cityConfig.yaToken}"
              }
              body
            }
            taskCallback
          )
        (res, body, taskCallback)->
          parseString body, taskCallback
      ]
      callback
    )





module.exports = Yandex