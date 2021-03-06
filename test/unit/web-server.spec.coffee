require 'core-js'
request = require 'supertest-as-promised'
di = require 'di'
Promise = require 'bluebird'
mocks = require 'mocks'
_ = require('../../lib/helper')._

describe 'web-server', ->

  File = require('../../lib/file')

  EventEmitter = require('events').EventEmitter

  _mocks = {}
  _globals = {__dirname: '/karma/lib'}

  _mocks.fs = mocks.fs.create
    karma:
      static:
        'client.html':  mocks.fs.file(0, 'CLIENT HTML')
    base:
      path:
        'one.js': mocks.fs.file(0, 'js-source')
        'new.js': mocks.fs.file(0, 'new-js-source')

  # NOTE(vojta): only loading once, to speed things up
  # this relies on the fact that none of these tests mutate fs
  m = mocks.loadFile __dirname + '/../../lib/web-server.js', _mocks, _globals

  customFileHandlers = server = emitter = null

  servedFiles = (files) ->
    emitter.emit 'file_list_modified', {included: [], served: files}

  beforeEach ->
    customFileHandlers = []
    emitter = new EventEmitter

    injector = new di.Injector [{
      config: ['value', {basePath: '/base/path', urlRoot: '/'}]
      customFileHandlers: ['value', customFileHandlers],
      emitter: ['value', emitter],
      fileList: ['value', null],
      capturedBrowsers: ['value', null],
      reporter: ['value', null],
      executor: ['value', null]
    }]

    server = injector.invoke m.createWebServer

  it 'should serve client.html', () ->
    servedFiles new Set()

    request(server)
    .get('/')
    .expect(200, 'CLIENT HTML')

  it 'should serve source files', () ->
    servedFiles new Set([new File '/base/path/one.js'])

    request(server)
    .get('/base/one.js')
    .expect(200, 'js-source')

  it 'should serve updated source files on file_list_modified', () ->
    servedFiles new Set([new File '/base/path/one.js'])
    servedFiles new Set([new File '/base/path/new.js'])

    request(server)
    .get('/base/new.js')
    .expect(200, 'new-js-source')

  it 'should load custom handlers', () ->
    servedFiles new Set()

    # TODO(vojta): change this, only keeping because karma-dart is relying on it
    customFileHandlers.push {
      urlRegex: /\/some\/weird/
      handler: (request, response, staticFolder, adapterFolder, baseFolder, urlRoot) ->
        response.writeHead 222
        response.end 'CONTENT'
    }

    request(server)
    .get('/some/weird/url')
    .expect(222, 'CONTENT')

  it 'should serve 404 for non-existing files', () ->
    servedFiles new Set()

    request(server)
    .get('/non/existing.html')
    .expect(404)
