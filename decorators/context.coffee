StorageDecorator = require "../decorators/storage"

moment = require "moment"

class ContextDecorator

  constructor: (@context)->

    @storageDecorator = new StorageDecorator

    @logger = vakoo.logger.context

    @cityConfig = vakoo.configurator.config.city

    @createHost()

  createCity: (callback)=>

    cookieCity = @context.requester.cookies.city
    redirectUrl = false

    if not @subdomain and not cookieCity
      @storageDecorator.getCityByIP @context.request.ip, (err, city)=>
        if err
          return callback err

        if city
          @context.city = city
          redirectUrl = "http://#{city.alias}.#{@host}#{@context.request.url}"
        else
          @setCityCookie()
          redirectUrl = "http://#{@cityConfig.defaultCity}.#{@host}#{@context.request.url}"

        if redirectUrl
          if @cityConfig.redirect
            @context.response.redirect = redirectUrl
          else
            @logger.warn "Redirect to `#{redirectUrl}` turn off"

        if @context.city?.alias is @cityConfig.defaultCity
          @context.city = false
        callback()
    else
      if cookieCity and cookieCity isnt @cityConfig.chooseCookie
        @storageDecorator.getCityByAlias cookieCity, (err, city)=>
          if err
            return callback err

          if city
            if @subdomain is city.alias
              @context.city = city
            else
              redirectUrl = "http://#{city.alias}.#{@host}#{@context.request.url}"
          else
            @setCityCookie @cityConfig.defaultCity
            if @subdomain isnt @cityConfig.defaultCity
              redirectUrl = "http://#{@cityConfig.defaultCity}.#{@host}#{@context.request.url}"

          if redirectUrl
            if @cityConfig.redirect
              @context.response.redirect = redirectUrl
            else
              @logger.warn "Redirect to `#{redirectUrl}` turn off"

          if @context.city?.alias is @cityConfig.defaultCity
            @context.city = false
          callback()
      else
        @storageDecorator.getCityByAlias @subdomain, (err, city)=>
          if err
            return callback err

          if city
            @context.city = city
            @setCityCookie city.alias
            if @context.city?.alias is @cityConfig.defaultCity
              @context.city = false
            callback()
          else if @subdomain is @cityConfig.defaultCity
            @setCityCookie @cityConfig.chooseCookie
            if @context.city?.alias is @cityConfig.defaultCity
              @context.city = false
            callback()
          else
            @storageDecorator.getCityByIP @context.request.ip, (err, city)=>
              if err
                return callback err

              if city
                @setCityCookie city.alias
                redirectUrl = "http://#{city.alias}.#{@host}#{@context.request.url}"
              else
                @setCityCookie @cityConfig.chooseCookie
                redirectUrl = "http://#{@cityConfig.defaultCity}.#{@host}#{@context.request.url}"

              if redirectUrl
                if @cityConfig.redirect
                  @context.response.redirect = redirectUrl
                else
                  @logger.warn "Redirect to `#{redirectUrl}` turn off"
              if @context.city?.alias is @cityConfig.defaultCity
                @context.city = false
              callback()


  setCityCookie: (city = @cityConfig.defaultCity)=>

    @context.responser.cookie(
      "city"
      city
      {
        domain: @host
        maxAge: moment().add(1, "year").toDate()
      }
    )

  createHost: =>
    hostname = @context.requester.hostname

    #todo kill that
    hostname = "izhevsk.luxy.sexy"
    @context.request.ip = "91.146.50.41"
#    @context.request.ip = "127.0.0.1"
    #todo end

    [[subdomain...]..., domainName, domainZone] = hostname.split(".")

    @subdomain = subdomain.join "."
    @host = [domainName, domainZone].join "."



module.exports = ContextDecorator