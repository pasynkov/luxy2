class Test

  constructor: (callback)->


    vakoo.mysql.collection("main_slider_settings").find {id: {$gt: 1}}, (err, rows)->
      console.log "len", rows
      callback()



module.exports = Test