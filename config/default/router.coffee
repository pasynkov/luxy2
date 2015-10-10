class Router


  constructor: (@webServer)->

    @webServer.addRoute "get", "/", "shop", "index"

    @webServer.addRoute "get", "/product", "shop", "minifyProduct"

    @webServer.addRoute "post", "/cart", "cart", "index"
    @webServer.addRoute "post", "/checkout", "cart", "checkout"
    @webServer.addRoute "post", "/order", "cart", "order"

    @webServer.addRoute "get", "/checkout", "shop", "redirector"
    @webServer.addRoute "get", "/shop/products/index", "shop", "redirector"
    @webServer.addRoute "get", "/archive/:product_id", "shop", "product"


    @webServer.addRoute "post", "/billing", "cart", "billing"


module.exports = Router