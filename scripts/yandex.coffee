{parseString} = require "xml2js"
request = require "request"
async = require "async"
_ = require "underscore"

class Yandex

  constructor: (callback)->

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

          async.map(
            uins
            ([siteId, uin], done)->

              vakoo.mongo.collectionNative("cities").update {yandexId: siteId}, {$set: {yandexUin: uin}}, done

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

    postData ?= {}

    async.waterfall(
      [
        (taskCallback)=>
          request[method](
            "http://webmaster.yandex.ru/api/v2/#{url}"
            {
              headers: {
                Authorization: "OAuth #{@cityConfig.yaToken}"
              }
              form: postData
            }
            taskCallback
          )
        (res, body, taskCallback)->
          parseString body, taskCallback
      ]
      callback
    )





module.exports = Yandex