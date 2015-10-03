class Router


  constructor: (@webServer)->

    @webServer.addRoute "get", "/", "shop", "index"

    @webServer.addRoute "get", "/product", "shop", "minifyProduct"

    @webServer.addRoute "post", "/cart", "cart", "index"
    @webServer.addRoute "post", "/checkout", "cart", "checkout"
    @webServer.addRoute "post", "/order", "cart", "order"


module.exports = Router