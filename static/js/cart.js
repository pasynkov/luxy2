(function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);var f=new Error("Cannot find module '"+o+"'");throw f.code="MODULE_NOT_FOUND",f}var l=n[o]={exports:{}};t[o][0].call(l.exports,function(e){var n=t[o][1][e];return s(n?n:e)},l,l.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s})({1:[function(require,module,exports){
var Cart,
  bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  slice = [].slice;

Cart = (function() {
  function Cart() {
    this.html = bind(this.html, this);
    this.checkout = bind(this.checkout, this);
    this.oneClick = bind(this.oneClick, this);
    this.saveCart = bind(this.saveCart, this);
    this.calculate = bind(this.calculate, this);
    this.getIndexById = bind(this.getIndexById, this);
    this.removeById = bind(this.removeById, this);
    this.add = bind(this.add, this);
    this.changeCountById = bind(this.changeCountById, this);
    this.addFromEl = bind(this.addFromEl, this);
    this.initEvents = bind(this.initEvents, this);
    if (window.localStorage == null) {
      alert("Not supporting local storage. Please update browser!");
      return;
    }
    this.storage = this.getCart();
    this.config = JSON.parse('{"productsPerPage":20,"freeDelivery":2900,"deliveryCost":290,"minCart":1000}');
    this.initEvents();
    this.saveCart();
  }

  Cart.prototype.initEvents = function() {
    $(".add-cart-btn").click((function(_this) {
      return function(e) {
        e.preventDefault();
        return _this.addFromEl(e.currentTarget);
      };
    })(this));
    $(document).on("click", ".cart-dropdown .delete", (function(_this) {
      return function(e) {
        var $target;
        $target = $(e.currentTarget);
        if ($target.data("id") === "delivery") {
          return _this.popover(e.currentTarget, "Чтобы товар был достален бесплатно, сумма должна быть больше\n<b>" + _this.config.freeDelivery + "</b> <span class=\"fa fa-rouble\"/>.\nОсталось <b>" + (_this.config.freeDelivery - _this.storage.total - _this.config.deliveryCost) + "</b> <span class=\"fa fa-rouble\"/>.", ".cart-dropdown", 3);
        } else {
          return _this.removeById($target.data("id"));
        }
      };
    })(this));
    $(document).on('change', '.cart-dropdown input, .shopping-cart .items-list .item input', (function(_this) {
      return function(e) {
        var count;
        e.preventDefault();
        count = +$(e.currentTarget).val();
        if (isNaN(count) || count < 1) {
          count = 1;
          $(e.currentTarget).val(count);
        }
        return _this.changeCountById($(e.currentTarget).data("id"), count);
      };
    })(this));
    return $(".incr-btn").on("click", (function(_this) {
      return function(e) {
        var $a, $button, count, id;
        $button = $(e.currentTarget);
        id = $button.data('id');
        count = +$button.parent().find("input").val();
        if (isNaN(count)) {
          count = 1;
        }
        if ($button.text() === "+") {
          count++;
        } else {
          count--;
        }
        if (count <= 0) {
          count = 1;
        }
        if (id) {
          _this.changeCountById(id, count);
        }
        $button.parent().find('input').val(count);
        $a = $button.parent().parent().find('.one-click');
        if ($a) {
          $a.data('count', count);
        }
        return e.preventDefault();
      };
    })(this));
  };

  Cart.prototype.addFromEl = function(el) {
    return $.get("/product?id=" + ($(el).data("alias")), (function(_this) {
      return function(product) {
        product.count = 1;
        if ($(el).data("value-selector")) {
          product.count = +$($(el).data("value-selector")).val();
        }
        product.total = product.count * product.price;
        _this.add(product);
        return _this.popover(el, "Товар добавлен в корзину", $(el).attr("id") === "addItemToCart" ? $(el).parent() : null, 1);
      };
    })(this));
  };

  Cart.prototype.changeCountById = function(id, count) {
    var index;
    if (count == null) {
      count = 1;
    }
    if (isNaN(count) || count < 1) {
      count = 1;
    }
    if ((index = this.getIndexById(id)) >= 0) {
      this.storage.items[index].count = count;
      this.storage.items[index].total = this.storage.items[index].count * this.storage.items[index].price;
    }
    return this.saveCart();
  };

  Cart.prototype.add = function(product) {
    var index;
    if ((index = this.getIndexById(product._id)) >= 0) {
      this.storage.items[index].count += product.count;
      this.storage.items[index].total = this.storage.items[index].count * this.storage.items[index].price;
    } else {
      this.storage.items.push(product);
    }
    return this.saveCart();
  };

  Cart.prototype.removeById = function(id) {
    var $shoppingCart, $target, index;
    index = this.getIndexById(id);
    if (index >= 0) {
      this.storage.items.splice(index, 1);
    }
    this.saveCart();
    $shoppingCart = $(".shopping-cart");
    if ($shoppingCart.length) {
      $target = $shoppingCart.find(".items-list .item[data-id=" + id + "]");
      return $target.hide(300, function() {
        return $target.remove();
      });
    }
  };

  Cart.prototype.getIndexById = function(id) {
    var i, j, len, product, ref;
    ref = this.storage.items;
    for (i = j = 0, len = ref.length; j < len; i = ++j) {
      product = ref[i];
      if (product._id === id) {
        return i;
      }
    }
    return -1;
  };

  Cart.prototype.getCart = function() {
    var e, error;
    try {
      return JSON.parse(localStorage["cart"]);
    } catch (error) {
      e = error;
      return {
        count: 0,
        total: 0,
        items: []
      };
    }
  };

  Cart.prototype.calculate = function() {
    var item, j, len, ref;
    this.storage.total = 0;
    this.storage.count = 0;
    ref = this.storage.items;
    for (j = 0, len = ref.length; j < len; j++) {
      item = ref[j];
      this.storage.total += item.price * item.count;
      this.storage.count += item.count;
    }
    this.storage.delivery = this.storage.total < this.config.freeDelivery ? this.config.deliveryCost : false;
    if (this.storage.delivery) {
      return this.storage.total += this.storage.delivery;
    }
  };

  Cart.prototype.saveCart = function() {
    this.calculate();
    localStorage["cart"] = JSON.stringify(this.storage);
    return this.html();
  };

  Cart.prototype.oneClick = function(e) {
    var el;
    e.preventDefault();
    el = e.currentTarget;
    return $.get("/product?id=" + ($(el).data("alias")), (function(_this) {
      return function(product) {
        var content;
        product.count = +$(el).data("count");
        if (isNaN(product.count) || product.count < 1) {
          product.count = 1;
        }
        if ((product.price * product.count) >= _this.config.minCart) {
          _this.storage.items = [product];
          _this.calculate();
          return _this.checkout(e);
        } else {
          _this.add(product);
          content = "Чтобы купить в один клик сумма товара должна быть больше\n<b>" + _this.config.minCart + "</b> <span class=\"fa fa-rouble\"/>.<br/>\nМы добавили этот товар в вашу корзину";
          return _this.popover(el, content, null);
        }
      };
    })(this));
  };

  Cart.prototype.checkout = function(e) {
    var $form, el, total;
    e.preventDefault();
    el = e.currentTarget;
    total = this.storage.total;
    if (this.storage.delivery) {
      total -= this.storage.delivery;
    }
    if (total < this.config.minCart) {
      return this.popover(el, "К сожалению, общая сумма заказа должна привышать\n<b>" + this.config.minCart + "</b> <span class=\"fa fa-rouble\"/>.\nОсталось <b>" + (this.config.minCart - total) + "</b> <span class=\"fa fa-rouble\"/>.", $(el).attr("name") === "to-checkout" ? null : $(".cart-dropdown"), 4);
    } else {
      return $form = $("<form></form>", {
        method: "post",
        action: "/checkout"
      }).html("<input type='hidden' name='json' value='" + (JSON.stringify(this.storage)) + "'>").submit();
    }
  };

  Cart.prototype.popover = function() {
    var arg, container, content, el, j, timeout;
    arg = 2 <= arguments.length ? slice.call(arguments, 0, j = arguments.length - 1) : (j = 0, []), timeout = arguments[j++];
    el = arg[0], content = arg[1], container = arg[2];
    if (timeout == null) {
      timeout = 3;
    }
    if (container == null) {
      container = "body";
    }
    $(el).popover({
      content: content,
      placement: "top",
      container: container,
      html: true
    }).popover("show");
    return setTimeout(function() {
      return $(el).popover("destroy");
    }, timeout * 1000);
  };

  Cart.prototype.show = function() {
    var $form;
    return $form = $("<form></form>", {
      method: "post",
      action: "/cart"
    }).html("<input type='hidden' name='json' value='" + (JSON.stringify(this.storage)) + "'>").submit();
  };

  Cart.prototype.setOrder = function(json) {
    var e, error, order;
    try {
      order = JSON.parse(json);
    } catch (error) {
      e = error;
      return console.error(e);
    }
    this.storage = {
      count: 0,
      total: 0,
      items: []
    };
    this.saveCart();
    return localStorage["lastOrder"] = JSON.stringify(order);
  };

  Cart.prototype.html = function() {
    var $list, $shoppingCart, $table;
    if (!this.storage.count) {
      $(".cart-btn .btn span").empty();
      $(".cart-btn").addClass("empty");
      return;
    }
    $(".cart-btn .btn span").html(this.storage.count);
    if ($("#checkout-form").length) {
      return;
    }
    $(".cart-btn").removeClass("empty");
    $(".cart-dropdown .total .t").html(numberFormat(this.storage.total));
    $table = $(".cart-dropdown .body table").empty();
    $table.append("<tr>\n  <th>Наименование</th>\n  <th>Кол-во</th>\n  <th>Стоимость</th>\n</tr>");
    $(this.storage.items).each(function(i, product) {
      var $tr;
      $tr = $("<tr></tr>", {
        "class": "item"
      });
      $tr.html("<td>\n  <div class=\"delete\" data-id=\"" + product._id + "\"></div>\n  <a href=\"" + product.url + "\">" + product.title + "</a>\n</td>\n<td>\n  <input type=\"text\" value=\"" + product.count + "\" data-id=\"" + product._id + "\">\n</td>\n<td class=\"price\">\n  " + (numberFormat(product.total)) + " <span class=\"fa fa-rouble\"></span>\n</td>");
      return $table.append($tr);
    });
    if (this.storage.delivery) {
      $table.append("<tr class=\"item\">\n  <td>\n    <div class=\"delete\" data-id=\"delivery\"></div>\n    <a href=\"/delivery\">Доставка</a>\n  </td>\n  <td>\n  </td>\n  <td class=\"price\">\n    " + (numberFormat(this.storage.delivery)) + " <span class=\"fa fa-rouble\"></span>\n  </td>\n</tr>");
    }
    $shoppingCart = $(".shopping-cart");
    if ($shoppingCart.length) {
      $list = $shoppingCart.find(".items-list");
      $(this.storage.items).each(function(i, product) {
        $list.find(".item[data-id=" + product._id + "] .total").html((numberFormat(product.total)) + " <span class=\"fa fa-rouble\"/>");
        return $list.find(".item[data-id=" + product._id + "] .quantity").val(product.count);
      });
      if (this.storage.delivery) {
        $shoppingCart.find(".cart-totals .total").html((numberFormat(this.storage.total - this.storage.delivery)) + " <span class=\"fa fa-rouble\"/>");
        $shoppingCart.find(".cart-totals .delivery").html((numberFormat(this.storage.delivery)) + " <span class=\"fa fa-rouble\"/>");
      } else {
        $shoppingCart.find(".cart-totals .delivery").html("Бесплатно");
      }
      return $shoppingCart.find(".cart-totals .order-total").html((numberFormat(this.storage.total)) + " <span class=\"fa fa-rouble\"/>");
    }
  };

  return Cart;

})();

$(function() {
  return window.cart = new Cart();
});

},{}]},{},[1]);
