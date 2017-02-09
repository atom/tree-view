const gulp = require('gulp');
const fs = require('fs');

gulp.task('mirage', function() {
  // update package.json
  var pkg = require('./package.json')
  pkg.name = 'mirage'
  pkg.description = 'The learn-ide-tree\'s twin that we use for testing'
  pkg.primaryLearnIDEPackage = 'mastermind'
  pkg.repository = pkg.repository.replace('learn-ide-tree', 'mirage')
  fs.writeFileSync('./package.json', JSON.stringify(pkg, null, '  '))

  // update menus
  var menu = fs.readFileSync('./menus/tree-view.cson', 'utf-8')
  var updated = menu.replace('Learn IDE Tree', 'Mirage')
  fs.writeFileSync('./menus/tree-view.cson', updated)
})

