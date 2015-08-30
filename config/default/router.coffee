class Router


  constructor: (@webServer)->

    @webServer.addRoute "get", "/", "shop", "index"


module.exports = Router