crypto = require "crypto"

class Test

  constructor: (callback)->

    console.log crypto.createHash("md5").update("21312623").digest("hex")

    callback()





module.exports = Test