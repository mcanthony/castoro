minimist = require 'minimist'
ChromecastWrapper = require './chromecast_wrapper'
HttpServer = require './http_server'
RemoteController = require './remote_controller'

argv = minimist(process.argv)

conf =
  input: argv.input
  ip: argv.ip
  mode: argv.mode
  help: argv.help
  port: argv['port'] || 8123
  cli_controller: argv['cli-controller']
  verbose: argv.verbose

help = """
  castoro --input path.to.file.mkv \
    --ip [ip of your machine] \
    --port [http port to use] \
    --mode [original|stream-transcode|transcode] \
    --cli-controller
    --verbose
    """

if conf.help then return console.log help

chromecastWrapper = new ChromecastWrapper(conf.ip, conf.port)
httpServer = new HttpServer conf.input, conf.port, conf.mode, conf.verbose

switchToTranscoded = () ->
  chromecastWrapper.getStatus (status) ->
    console.log 'Switching to transcoded file'
    httpServer.mode = 'transcode'
    chromecastWrapper.play status.currentTime

if conf.mode == 'transcode'
  httpServer.mode = 'stream-transcode'
  ffmpeg = require 'fluent-ffmpeg'
  ff = ffmpeg(conf.input, {})
  ff.inputOptions('-fix_sub_duration')
  ff.inputOptions('-threads 16')
  ff.videoCodec('copy')
  ff.audioCodec('libfaac').audioBitrate('320k')
  ff.toFormat("matroska")
  ff.output('/tmp/target.mkv')
  ff.on('end', switchToTranscoded)
  ff.on('start', (command) -> console.log "Launching transcode: ", command)
  ff.on('progress', (progress) -> console.log 'Transcoding progress', progress.percent )
  ff.run()

if conf.cli_controller
  delayed = -> new RemoteController(chromecastWrapper)
  setTimeout delayed, 1000

  
