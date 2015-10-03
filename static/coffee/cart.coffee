class Cart

  constructor: ->
    unless window.localStorage?
      alert("Not supporting local storage. Please update browser!")
      return

    @storage = @getCart()
    @config = JSON.parse '@@shopConfig'

    @initEvents()
    @saveCart()


  initEvents: =>
    $(".add-cart-btn").click (e)=>
      e.preventDefault()
      @addFromEl e.currentTarget

    $(document).on "click", ".cart-dropdown .delete", (e)=>

      $target = $(e.currentTarget)

      if $target.data("id") is "delivery"


        @popover(
          e.currentTarget
          """
            Чтобы товар был достален бесплатно, сумма должна быть больше
            <b>#{@config.freeDelivery}</b> <span class="fa fa-rouble"/>.
            Осталось <b>#{(@config.freeDelivery - @storage.total - @config.deliveryCost)}</b> <span class="fa fa-rouble"/>.
          """
          ".cart-dropdown"
          3
        )

      else
        @removeById $target.data("id")

    $(document).on 'change','.cart-dropdown input, .shopping-cart .items-list .item input', (e)=>
      e.preventDefault()
      count = +$(e.currentTarget).val()
      if isNaN(count) or count < 1
        count = 1
        $(e.currentTarget).val count

      @changeCountById $(e.currentTarget).data("id"), count

    $(".incr-btn").on "click", (e)=>
      $button = $(e.currentTarget)
      id = $button.data('id')
      count = +$button.parent().find("input").val();
      if isNaN count
        count = 1

      if $button.text() is  "+"
        count++
      else
        count--

      if count <= 0
        count = 1

      if id
        @changeCountById id, count

      $button.parent().find('input').val count
      $a = $button.parent().parent().find('.one-click')
      if $a
        $a.data 'count', count

      e.preventDefault();

  addFromEl: (el)=>
    $.get "/product?id=#{$(el).data("alias")}", (product)=>
      product.count = 1

      if $(el).data("value-selector")
        product.count = +$($(el).data("value-selector")).val()

      product.total = product.count * product.price

      @add product

      @popover(
        el
        "Товар добавлен в корзину"
        if $(el).attr("id") is "addItemToCart" then $(el).parent() else null
        1
      )

  changeCountById: (id, count = 1)=>

    if isNaN(count) or count < 1
      count = 1

    if (index = @getIndexById(id)) >= 0

      @storage.items[index].count = count
      @storage.items[index].total = @storage.items[index].count * @storage.items[index].price

    @saveCart()

  add: (product)=>

    if (index = @getIndexById(product._id)) >= 0
      @storage.items[index].count += product.count
      @storage.items[index].total = @storage.items[index].count * @storage.items[index].price
    else
      @storage.items.push product

    @saveCart()

  removeById: (id)=>

    index = @getIndexById id

    if index >= 0
      @storage.items.splice index, 1

    @saveCart()

    $shoppingCart = $(".shopping-cart")

    if $shoppingCart.length
      $target = $shoppingCart.find(".items-list .item[data-id=#{id}]")
      $target.hide(
        300
        ->
          $target.remove()
      )

  getIndexById: (id)=>

    for product, i in @storage.items
      if product._id is id
        return i

    return -1

  getCart: ->

    try
      return JSON.parse localStorage["cart"]
    catch e
      return {count: 0, total: 0, items: []}

  calculate: =>

    @storage.total = 0
    @storage.count = 0

    for item in @storage.items
      @storage.total += item.price * item.count
      @storage.count += item.count

    @storage.delivery = if @storage.total < @config.freeDelivery then @config.deliveryCost else false

    if @storage.delivery
      @storage.total += @storage.delivery

  saveCart: =>
    @calculate()
    localStorage["cart"] = JSON.stringify @storage
    @html()

  oneClick: (e)=>

    e.preventDefault()
    el = e.currentTarget

    $.get "/product?id=#{$(el).data("alias")}", (product)=>

      product.count = +$(el).data("count")

      if isNaN(product.count) or product.count < 1
        product.count = 1

      if (product.price * product.count)>= @config.minCart
        @storage.items = [product]
        @calculate()
        @checkout e
      else

        @add product

        content = """
            Чтобы купить в один клик сумма товара должна быть больше
            <b>#{@config.minCart}</b> <span class="fa fa-rouble"/>.<br/>
            Мы добавили этот товар в вашу корзину
        """
        @popover el, content, null

  checkout: (e)=>

    e.preventDefault()
    el = e.currentTarget

    total = @storage.total
    if @storage.delivery
      total -= @storage.delivery

    if total < @config.minCart

      @popover(
        el
        """
          К сожалению, общая сумма заказа должна привышать
          <b>#{@config.minCart}</b> <span class="fa fa-rouble"/>.
          Осталось <b>#{(@config.minCart - total)}</b> <span class="fa fa-rouble"/>.
        """
        if $(el).attr("name") is "to-checkout" then null else $(".cart-dropdown")
        4
      )

    else

      $form = $("<form></form>", {
        method: "post"
        action: "/checkout"
      }).html("<input type='hidden' name='json' value='#{JSON.stringify @storage}'>").submit()

  popover: ([el, content, container]..., timeout = 3)->

    container ?= "body"

    $(el).popover({
      content
      placement: "top"
      container: container
      html: true
    }).popover("show")

    setTimeout(
      ->
        $(el).popover "destroy"
      (timeout * 1000)
    )

  show: ->

    $form = $("<form></form>", {
      method: "post"
      action: "/cart"
    }).html("<input type='hidden' name='json' value='#{JSON.stringify @storage}'>").submit()

  setOrder: (json)->
    try
      order = JSON.parse json
    catch e
      return console.error e

    @storage = {count: 0, total: 0, items: []}
    @saveCart()

    localStorage["lastOrder"] = JSON.stringify order

  html: =>
    unless @storage.count
      $(".cart-btn .btn span").empty()
      $(".cart-btn").addClass "empty"
      return

    $(".cart-btn .btn span").html @storage.count
    if $("#checkout-form").length
      return
    $(".cart-btn").removeClass "empty"
    $(".cart-dropdown .total .t").html numberFormat @storage.total

    $table = $(".cart-dropdown .body table").empty()

    $table.append """
      <tr>
        <th>Наименование</th>
        <th>Кол-во</th>
        <th>Стоимость</th>
      </tr>
    """

    $(@storage.items).each (i, product)->

      $tr = $("<tr></tr>", "class":"item")
      $tr.html """
        <td>
          <div class="delete" data-id="#{product._id}"></div>
          <a href="#{product.url}">#{product.title}</a>
        </td>
        <td>
          <input type="text" value="#{product.count}" data-id="#{product._id}">
        </td>
        <td class="price">
          #{numberFormat product.total} <span class="fa fa-rouble"></span>
        </td>
      """

      $table.append($tr);

    if @storage.delivery
      $table.append """
        <tr class="item">
          <td>
            <div class="delete" data-id="delivery"></div>
            <a href="/delivery">Доставка</a>
          </td>
          <td>
          </td>
          <td class="price">
            #{numberFormat @storage.delivery} <span class="fa fa-rouble"></span>
          </td>
        </tr>
      """

    $shoppingCart = $(".shopping-cart")

    if $shoppingCart.length

      $list = $shoppingCart.find(".items-list")

      $(@storage.items).each (i, product)->
        $list.find(".item[data-id=#{product._id}] .total").html "#{numberFormat product.total} <span class=\"fa fa-rouble\"/>"
        $list.find(".item[data-id=#{product._id}] .quantity").val product.count

      if @storage.delivery
        $shoppingCart.find(".cart-totals .total").html "#{numberFormat (@storage.total - @storage.delivery)} <span class=\"fa fa-rouble\"/>"
        $shoppingCart.find(".cart-totals .delivery").html "#{numberFormat @storage.delivery} <span class=\"fa fa-rouble\"/>"
      else
        $shoppingCart.find(".cart-totals .delivery").html "Бесплатно"
      $shoppingCart.find(".cart-totals .order-total").html "#{numberFormat @storage.total} <span class=\"fa fa-rouble\"/>"




$ ->
  window.cart = new Cart()