Net = require 'net'
Util = require "util"
Fs = require 'fs'
Express = require 'express'
Sys = require 'sys'
Exec = require('child_process').exec
HipChat = require 'node-hipchat'

hipchat = new HipChat(process.env.HIPCHAT_TOKEN)
channel_name = process.env.DEBOT_CHANNEL or 'default'
debot_name = process.env.DEBOT_NAME or 'Debot'

app = Express()
app.use Express.bodyParser()

deploying = []

hipchat.postMessage
  room: channel_name
  from: debot_name
  message: 'Bootup ok... waiting cmds'
  color: 'purple'

app.get '/deploy', (req,res) ->
  console.log(req.query)
  if (req.query.what)
    what = req.query.what
    params = req.query.params
    if deploying[ what ] == true
      hipchat.postMessage
        room: channel_name
        from: debot_name
        message: 'Cannot deploy, already deploying ' + req.query.what
        color: 'red'
      res.json
        error: true
      return

    deploying[ what ] = true

    hipchat.postMessage
      room: channel_name
      from: debot_name
      message: 'Deploying ' + what
      color: 'yellow'

    deploy_script = null
    try
      deploy_script = new (require "./scripts/" + req.query.what + ".coffee")()
    catch error
      setTimeout( ->
        hipchat.postMessage
          room: channel_name
          from: debot_name
          message: 'No deployment script for ' + req.query.what
          color: 'red'
        deploying[ what ] = false
        res.json
          error: true
      , 500)

    if deploy_script
      res.json
        success: true
      deploy_script.execute params,  (error) ->
        if error
          hipchat.postMessage
            room: channel_name
            from: debot_name
            message: 'Error deploying ' + req.query.what + '. ' + error
            color: 'red'
        else
          hipchat.postMessage
            room: channel_name
            from: debot_name
            message: 'Deployment of ' + req.query.what + ' finished'
            color: 'green'
      
        deploying[ what ] = false
      delete require.cache[require.resolve("./scripts/" + req.query.what + ".coffee")]
  else
    deploying[ what ] = false
    res.json
      error: true

app.listen(5600)
