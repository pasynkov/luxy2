gulp = require "gulp"
coffeeify = require "gulp-coffeeify"
shopConfig = require("./config/default/config").shop
replace = require "gulp-replace-task"

gulp.task "coffee", ->
  gulp.src("./static/coffee/*.coffee")
  .pipe coffeeify()
  .pipe replace({
    patterns: [{
      match: "shopConfig"
      replacement: JSON.stringify shopConfig
    }]
  })
  .pipe gulp.dest "./static/js/"

gulp.task "watch", ->
  gulp.watch "static/coffee/*.coffee", ["coffee"]


