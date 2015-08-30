_ = require "underscore"

class UtilsDecorator


  constructor: (@context)->


  numberFormat: (number, price)->

    if price
      if +number < 500
        number = +((number / 10) * 10)
      else
        number = +((number / 100) * 100)

    decimals = 0
    dec_point = '.'
    thousands_sep = ' '

    i = parseInt(number = (+number or 0).toFixed(decimals)) + ''
    if (j = i.length) > 3
      j = j % 3
    else
      j = 0
    km = if j then i.substr(0, j) + thousands_sep else ''
    kw = i.substr(j).replace(/(\d{3})(?=\d)/g, '$1' + thousands_sep)
    #kd = (decimals ? dec_point + Math.abs(number - i).toFixed(decimals).slice(2) : "");
    kd = if decimals then dec_point + Math.abs(number - i).toFixed(decimals).replace(/-/, 0).slice(2) else ''

    return km + kw + kd;




  createUrl: (object)->
    if object.alias
      return "/" + object.ancestors.concat([object.alias]).join("/")

    return "/" + object.ancestors.concat([object._id]).join("/")

  getSort: ->

    sort = {
      price:{
        active:false
        url:'sort=price,desc'
        run: false
      }
      title:{
        active:false,
        url:'sort=title,desc'
        run: false
      }
    }

    order = false


    if @context.request.query.sort
      order = @context.request.query.sort.split(',');
      sort[order[0]].run = true
      if order[1] is "desc"
        sort[order[0]].active = true
        sort[order[0]].url = 'sort=' + order[0] + ',asc'

    return sort

  createPagination: (page, pagesCount)->

    page++

    pagesArr = []
    pagesMax = 20
    link = @context.request.path

    if _.isEmpty _.omit(@context.request.query, "p")
      link += "?p="
    else
      link += "?" + _.map(
        _.pairs(_.omit(@context.request.query, "p"))
        (pair)->
          pair.join "="
      ).join("&") + "&p="

    if pagesCount > pagesMax

      from = (page - pagesMax/2)
      to = (page + pagesMax/2)
      addedBefore = 0
      addedAfter = 0

      i = from
      while i < page
        if i > 0
          pagesArr.push
            page: i
            url: link + (if i - 1 == 0 then '' else i - 1)
            active: page is i
          addedBefore++
        i++

      i = page
      while i <= to
        if i <= pagesCount
          pagesArr.push
            page: i
            url: link + (if i - 1 == 0 then '' else i - 1)
            active: page is i
          addedAfter++
        i++

      if from > 1
        if from > 2
          firstDotes = from - 2
          pagesArr.unshift
            page: '...'
            url: link + firstDotes
        pagesArr.unshift
          page: 1
          url: link
      if to < pagesCount
        if to < pagesCount - 1
          pagesArr.push
            page: '...'
            url: link + to
        pagesArr.push
          page: pagesCount
          url: link + (pagesCount - 1)



    else
      i = 1
      while i <= pagesCount
        pagesArr.push
          page: i
          url: link + (if i - 1 == 0 then '' else  i - 1)
          active: page is i
        i++

    prev =
      url: link + (if page - 2 is 0 then '' else page - 2)
      enable: false
    if page > 1
      prev.enable = true
    next =
      url: link + page
      enable: false
    if page isnt pagesCount
      next.enable = true

    if pagesArr.length < 2
      return false


    return {pagesArr, prev, next}

  createParamsClasses: (items)->

    paramsClasses = {
      'Страна':'geolocalizator',
      'Время работы':'watch',
      'Водонепроницаемость':'happy-drop',
      'Материал':'share',
      'Состав':'share',
      'Длина, см':'pencil-ruler',
      'Диаметр, см':'globe',
      'Диаметр для пениса, см':'globe',
      'Общий диаметр, см':'globe',
      'Ширина':'expand',
      'Объем, мл':'wine',
      'Цвет':'image',
      'Тип батареек':'battery-4',
      'Бренд':'ticket',
      'Лубрикант':'compass',
      'Форма':'life-buoy',
      'Текстура':'list',
      'Аромат':'coffee',
      'Толщина':'pen-pencil-ruler',
    }

    for item in items
      item[2] = paramsClasses[item[0]] || 'setting-1'

    return items

module.exports = UtilsDecorator
