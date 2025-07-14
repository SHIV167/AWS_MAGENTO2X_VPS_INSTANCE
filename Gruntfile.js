module.exports = function(grunt) {
  // Automatically load required grunt tasks
  require('load-grunt-tasks')(grunt);
  // Show elapsed time at the end
  require('time-grunt')(grunt);

  // Project configuration
  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
    less: {
      theme: {
        files: {
          // Compile _extend.less to CSS file in web/css directory
          'src/app/design/frontend/Shiv/ayurveda/web/css/source/_extend.css': 'src/app/design/frontend/Shiv/ayurveda/web/css/source/_extend.less'
        }
      }
    },
    watch: {
      styles: {
        files: ['src/app/design/frontend/Shiv/ayurveda/web/css/source/**/*.less'],
        tasks: ['less:theme'],
        options: {
          spawn: false,
        }
      }
    }
  });
};
