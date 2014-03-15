# {{{1 Boilerplate
# predicates that can be optimised away by uglifyjs
if typeof isNodeJs == "undefined" or typeof runTest == "undefined" then do ->
  root = if typeof window == "undefined" then global else window
  root.isNodeJs = (typeof process != "undefined") if typeof isNodeJs == "undefined"
  root.isPhoneGap = typeof document.ondeviceready != "undefined" if typeof isPhoneGap == "undefined"
  root.runTest = true if typeof runTest == "undefined"
# use - require/window.global with non-require name to avoid being processed in firefox plugins
use = if isNodeJs then ((module) -> require module) else ((module) -> window[module]) 
# execute main
onReady = (fn) ->
  if isNodeJs
    process.nextTick fn
  else
    if document.readystate != "complete" then fn() else setTimeout (-> onReady fn), 17 
# {{{1 logging
fs = require "fs"
child_process = require "child_process"
logStream = undefined
logFileName = undefined
logToFile = (arr, cb) ->
  now = (new Date()).toISOString()
  name = "../logs/log-#{now.slice(0,10)}.log"
  if name != logFileName
    if logStream
      oldfile = logFileName
      logStream.on "close", ->
        child_process.exec "xz #{oldfile}"
      logStream.end()
    logStream = fs.createWriteStream name, {flags : "a"}
    logFileName = name
  logStream.write "#{JSON.stringify [now].concat arr}\n", "utf8", cb


# {{{1 server

routes =
  api:
    log: (req, res, data) ->
      logToFile
        url: req.url
        headers: req.headers
        remoteAddress: req.connection.remoteAddress
        logData: data
      res.writeHead 200,
        connection: "keep-alive"
      res.end "ok"

port = process.env.API_PORT || 4444

http = require "http"
server = http.createServer (req, res) ->
  logToFile [req.url, req.headers]
  data = ""
  req.setEncoding "ascii"
  req.on "data", (chunk) ->
    data += chunk
  req.on "end", ->
    route = routes
    for part in req.url.split("/").filter((a)->a)
      route = route[part]
      if typeof route == "function"
        return route(req, res, data)
      if typeof route == "undefined"
        res.writeHead 404, {}
        res.end "404 not found"
        return
    res.writeHead 404, {}
    res.end "404 not found"

server.listen port, "localhost"

onReady ->
  logToFile ["server started"]
  console.log "serving on port #{port}"

quit = ->
  process.exit(1)

process.on "uncaughtException", window.onerror = (args...) ->
  logToFile ["error occured", String(args)], quit
# {{{1 keyval store

keyvalListeners = {}
stopListen = (listener) ->
  for keyval in listener.listen
    keyvalListeners[keyval] = keyvalListeners.filter((listener2) -> listener2 != listener)

routes.api.keyval =
  set: (req, res, data) ->
    urlparts = req.url.split "/"
    key = urlparts[urlparts.length - 1]
    data = JSON.parse data
    return res.end "not an object" if !data || typeof data != "object"
    localforage.getItem key, (val) ->
      return res.end JSON.stringify val if val && val.version && data.version != val.version
      data.version = Date.now()
      localforage.setItem key, data, ->
        res.end String(data.version)
      if keyvalListeners[key]
        listeners = keyvalListeners[key]
        for listener in listeners
          listener.res.end "[#{JSON.stringify key},#{JSON.stringify data}]"

  get: (req, res, data) ->
    urlparts = req.url.split "/"
    key = urlparts[urlparts.length - 1]
    localforage.getItem key, (val) ->
      return res.end JSON.stringify(val)

  subscribe: (req, res, data) ->
    res.setTimeout 0
    data = JSON.parse data
    keys = Object.keys data
    listener =
      listen: keys
      res: res
    for key in keys
      keyvalListeners[key] ?= []
      keyvalListeners[key].push listener

    res.on "finish", ->
      stopListen listener

    subscribe = () ->
      if keys.length
        key = keys.pop()
        console.log key
        localforage.getItem key, (val) ->
          if val.version != data[key]
            listener.res.end "[#{JSON.stringify key},#{JSON.stringify val}]"
          else
            subscribe()
    subscribe()

