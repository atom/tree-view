require('dotenv').config({silent: true});
const _ = require('underscore-plus');
const gulp = require('gulp');
const gutil = require('gulp-util');
const shell = require('shelljs');
const Client = require('ssh2').Client;
const fs = require('fs');
const os = require('os');
const path = require('path');

gulp.task('default', ['ws:start']);

gulp.task('setup', function() {
  shell.cp('./.env.example', './.env');
});

gulp.task('ws:start', function(done) {
  var conn = new Client();
  var host = process.env.IDE_WS_HOST || 'vm02.students.learn.co';
  var port = process.env.IDE_WS_PORT || 1337;
  var user = process.env.IDE_WS_USER || 'deployer';
  var dir = '/home/' + user + '/websocketd_scripts';
  var cmd = 'sudo su -c \"websocketd --port=' + port + ' --dir=' + dir + '\" ' + user + '\n';

  log('Connecting to ' + host + ' on port ' + port);

  conn.on('ready', function() {
    log('SSH client ready...');
    log('Executing ' + gutil.colors.yellow(cmd.replace('\n', '')) + ' on ' + gutil.colors.magenta(host));

    conn.exec(cmd, function(err, stream) {
      if (err) { throw err; }

      var pids = [];
      var pidsStr = '';

      conn.exec('ps aux | grep \"websocketd --port=' + port + '\" | grep -v grep | awk \'{print $2}\'', function(err, stream) {
        if (err) { throw err }
        stream.on('data', function(data) {
          pids = _.compact(data.toString().split('\n'))
          pidsStr = pids.join(' ')
          log('WebsocketD processes started with pids: ' + pidsStr);
        });
      })

      process.on('SIGINT', function() {
        log('Killing websocket processes ' + pidsStr);
        conn.exec('sudo kill ' + pidsStr, function(err, stream) {
          stream.on('close', function() {
            process.exit(0);
          });
        });
      });

      stream.on('close', function(code) {
        gutil.log('SSH stream closed with code ' + code);
        conn.end();
      }).on('data', function(data) {
        process.stdout.write('[' + gutil.colors.magenta(host) + '] ' + gutil.colors.blue(data));
      }).stderr.on('data', function(data) {
        process.stderr.write('[' + gutil.colors.magenta(host) + '] ' + gutil.colors.red(data));
      });
    })
  }).connect({
    host: host,
    username: process.env['USER'],
    agent: process.env.SSH_AUTH_SOCK
  });
});

function log (msg) {
  gutil.log(gutil.colors.green(msg));
}

function exec (cmd, opts, cb) {
  opts || (opts = {});

  _.defaults(opts, {
    name: cmd,
    async: false
  });

  gutil.log(gutil.colors.green('Executing ') + gutil.colors.yellow(cmd));

  var child = shell.exec(cmd, {async: opts.async}, cb);

  if (opts.async) {
    child.stdout.on('data', function(data) {
      process.stdout.write(gutil.colors.green(opts.name + ': ') + data);
    });

    child.stderr.on('data', function(data) {
      process.stderr.write(gutil.colors.green(opts.name + ': ') + data);
    });
  }
}
