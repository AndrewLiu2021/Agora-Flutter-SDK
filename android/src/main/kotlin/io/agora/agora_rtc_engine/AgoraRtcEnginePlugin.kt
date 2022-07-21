package io.agora.agora_rtc_engine

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import io.agora.agora_rtc_engine.ADTSUtils.bytebuffer2ByteArray
import io.agora.iris.base.IrisEventHandler
import io.agora.iris.rtc.IrisRtcEngine
import io.agora.rtc.AudioFrame
import io.agora.rtc.IAudioFrameObserver
import io.agora.rtc.IAudioFrameObserver.POSITION_RECORD
import io.agora.rtc.RtcEngine
import io.agora.rtc.audio.AudioParams
import io.agora.rtc.base.RtcEnginePlugin
import io.agora.rtc.base.RtcEngineRegistry
import io.flutter.BuildConfig
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.*
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import io.flutter.plugin.platform.PlatformViewRegistry
import kotlin.math.abs


internal class EventHandler(private val eventSink: EventChannel.EventSink?) : IrisEventHandler {
  private val handler = Handler(Looper.getMainLooper())
  override fun OnEvent(event: String?, data: String?) {
    handler.post {
      eventSink?.success(mapOf("methodName" to event, "data" to data))
    }
  }

  override fun OnEvent(event: String?, data: String?, buffer: ByteArray?) {
    handler.post {
      eventSink?.success(mapOf("methodName" to event, "data" to data, "buffer" to buffer))
    }
  }
}

interface OpenEncodeDataListener {
  fun openEncodeData(boolean: Boolean)
}

open class CallApiMethodCallHandler(
  protected val irisRtcEngine: IrisRtcEngine,
) : MethodCallHandler {

  protected open fun callApi(apiType: Int, params: String?, sb: StringBuffer): Int {
    val ret = irisRtcEngine.callApi(apiType, params, sb)
    if (apiType == 0) {
      RtcEngineRegistry.instance.onRtcEngineCreated(irisRtcEngine.rtcEngine as RtcEngine?)
    }
    if (apiType == 1) {
      RtcEngineRegistry.instance.onRtcEngineDestroyed()
    }

    return ret
  }

  protected open fun callApiWithBuffer(
    apiType: Int,
    params: String?,
    buffer: ByteArray?,
    sb: StringBuffer): Int {
    return irisRtcEngine.callApi(apiType, params, buffer, sb)
  }

  protected open fun callApiError(ret: Int): String {
    val description = StringBuffer()
    irisRtcEngine.callApi(
      132,
      "{\"code\":" + abs(ret) + "}",
      description
    )
    return description.toString()
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    val apiType = call.argument<Int>("apiType")
    val params = call.argument<String>("params")
    val sb = StringBuffer()

    if (BuildConfig.DEBUG) {
      when (call.method) {
        "getIrisRtcEngineIntPtr" -> {
          result.success(irisRtcEngine.nativeHandle)
          return
        }
        "forceDestroyIrisRtcEngine" -> {
          irisRtcEngine.destroy()
          result.success(true)
          return
        }
      }
    }

    if (BuildConfig.DEBUG && "getIrisRtcEngineIntPtr" == call.method) {
      result.success(irisRtcEngine.nativeHandle)
      return
    }
    try {
      val ret = when (call.method) {
        "callApi" -> {
          callApi(apiType!!, params, sb)
        }
        "callApiWithBuffer" -> {
          val buffer = call.argument<ByteArray>("buffer")
          callApiWithBuffer(apiType!!, params, buffer, sb)
        }
        else -> {
          // This should not occur
          -1
        }
      }

      if (ret == 0) {
        if (sb.isEmpty()) {
          result.success(null)
        } else {
          result.success(sb.toString())
        }
      } else if (ret > 0) {
        result.success(ret)
      } else {
        val errorMsg = callApiError(ret)
        result.error(ret.toString(), errorMsg, null)
      }
    } catch (e: Exception) {
      result.error("", e.message ?: "", null)
    }
  }
}

/** AgoraRtcEnginePlugin */
class AgoraRtcEnginePlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
  private var registrar: Registrar? = null
  private var binding: FlutterPlugin.FlutterPluginBinding? = null
  private lateinit var applicationContext: Context

  private lateinit var irisRtcEngine: IrisRtcEngine

  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var methodChannel: MethodChannel
  private lateinit var eventChannel: EventChannel

  private var eventSink: EventChannel.EventSink? = null
  //  private val managerAgoraTextureView = RtcEngineManager { methodName, data -> emit(methodName, data) }
  private val handler = Handler(Looper.getMainLooper())
  private lateinit var rtcChannelPlugin: AgoraRtcChannelPlugin;// = AgoraRtcChannelPlugin(irisRtcEngine)
  private lateinit var callApiMethodCallHandler: CallApiMethodCallHandler
  private var _openEncodeData = false

  // This static function is optional and equivalent to onAttachedToEngine. It supports the old
  // pre-Flutter-1.12 Android projects. You are encouraged to continue supporting
  // plugin registration via this function while apps migrate to use the new Android APIs
  // post-flutter-1.12 via https://flutter.dev/go/android-project-migration.
  //
  // It is encouraged to share logic between onAttachedToEngine and registerWith to keep
  // them functionally equivalent. Only one of onAttachedToEngine or registerWith will be called
  // depending on the user's project. onAttachedToEngine or registerWith must both be defined
  // in the same class.
  companion object {
    @JvmStatic
    fun registerWith(registrar: Registrar) {
      AgoraRtcEnginePlugin().apply {
        this.registrar = registrar

        initPlugin(registrar.context(), registrar.messenger(), registrar.platformViewRegistry())
      }
    }
  }

  private fun initPlugin(
    context: Context,
    binaryMessenger: BinaryMessenger,
    platformViewRegistry: PlatformViewRegistry
  ) {
    Log.e("Agora","initPlugin")
    applicationContext = context.applicationContext
    irisRtcEngine = IrisRtcEngine(applicationContext)
    methodChannel = MethodChannel(binaryMessenger, "agora_rtc_engine")
    methodChannel.setMethodCallHandler(this)
    eventChannel = EventChannel(binaryMessenger, "agora_rtc_engine/events")
    eventChannel.setStreamHandler(this)
    callApiMethodCallHandler = CallApiMethodCallHandler(irisRtcEngine)

    platformViewRegistry.registerViewFactory(
      "AgoraSurfaceView",
      AgoraSurfaceViewFactory(binaryMessenger, irisRtcEngine)
    )
    platformViewRegistry.registerViewFactory(
      "AgoraTextureView",
      AgoraTextureViewFactory(binaryMessenger, irisRtcEngine)
    )

    rtcChannelPlugin = AgoraRtcChannelPlugin(irisRtcEngine)

    rtcChannelPlugin.initPlugin(binaryMessenger)
    RtcEnginePlugin.Registrant.register(_etcEnginePlugin)
  }



  var audioFrameObserver = false
  private val listener = object : EncoderListener {
    override fun encodeAAC(data: List<Any>) {
//      Log.d("charco","encodeAAC ${data.size}")
      handler.post {
        eventSink?.success(mapOf("methodName" to "RecordFrameEvent", "data" to data))
      }
    }
  }

  private  val _etcEnginePlugin : RtcEnginePlugin  =  object : RtcEnginePlugin {
    override fun onRtcEngineCreated(rtcEngine: RtcEngine?) {
      if(audioFrameObserver){
        return
      }
      audioFrameObserver = true;
      val registerAudioFrameObserver = rtcEngine?.registerAudioFrameObserver(mAudioFrameObserver)
//      Log.d("charco","registerAudioFrameObserver $registerAudioFrameObserver $rtcEngine")
    }

    override fun onRtcEngineDestroyed() {}
  }

  //flutter 不支持 https://github.com/AgoraIO/Flutter-SDK/issues/141
  private val mAudioFrameObserver: IAudioFrameObserver = object : IAudioFrameObserver {

    override fun onRecordFrame(audioFrame: AudioFrame?): Boolean {
      if( _openEncodeData &&  audioFrame != null){
        val byteArray = bytebuffer2ByteArray(audioFrame.samples)
        AudioRecordUtil.encodeData(byteArray, audioFrame.numOfSamples, audioFrame.bytesPerSample, audioFrame.channels, audioFrame.samplesPerSec, listener)
      }

//      Log.e("charco","onRecordFrame, " +
//        "audioFrame?.samples?.hasArray() = ${audioFrame?.samples?.hasArray()} " +
//        "audioFrame.numOfSamples  =  ${audioFrame?.numOfSamples}," +
//        "audioFrame.bytesPerSample =  ${audioFrame?.bytesPerSample}," +
//        "audioFrame.channels  =  ${audioFrame?.channels}, " +
//        "audioFrame?.samplesPerSec  =  ${audioFrame?.samplesPerSec} ")
      return true
    }

    override fun onPlaybackFrame(audioFrame: AudioFrame?): Boolean {
//      Log.e("charco","onPlaybackFrame")
      return false
    }

    override fun onPlaybackFrameBeforeMixing(audioFrame: AudioFrame?, uid: Int): Boolean {
//      Log.e("charco","onPlaybackFrameBeforeMixing")
      return false
    }

    override fun onMixedFrame(audioFrame: AudioFrame?): Boolean {
//      Log.e("charco","onMixedFrame")
      return false
    }

    override fun isMultipleChannelFrameWanted(): Boolean {
//      Log.e("charco","isMultipleChannelFrameWanted")
      return false
    }

    override fun onPlaybackFrameBeforeMixingEx(
      audioFrame: AudioFrame?,
      uid: Int,
      channelId: String?
    ): Boolean {
//      Log.e("charco","onPlaybackFrameBeforeMixingEx")
      return false
    }

    override fun getObservedAudioFramePosition(): Int {
      return POSITION_RECORD
    }

    override fun getRecordAudioParams(): AudioParams {
//      Log.e("charco","getRecordAudioParams")
      return AudioParams(32000,1,0,1024)
    }

    override fun getPlaybackAudioParams(): AudioParams {
//      Log.e("charco","getPlaybackAudioParams")
      return AudioParams(32000,1,0,1024)
    }

    override fun getMixedAudioParams(): AudioParams {
//      Log.e("charco","getMixedAudioParams")
      return AudioParams(32000,1,0,1024)
    }

  }


  override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    this.binding = binding
//    rtcChannelPlugin.onAttachedToEngine(binding)
    initPlugin(binding.applicationContext, binding.binaryMessenger, binding.platformViewRegistry)
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    rtcChannelPlugin.onDetachedFromEngine(binding)
    methodChannel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)

    irisRtcEngine.destroy()
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    eventSink = events
    irisRtcEngine.setEventHandler(EventHandler(eventSink))
  }

  override fun onCancel(arguments: Any?) {
    irisRtcEngine.setEventHandler(null)
    eventSink = null
  }

//  private fun emit(methodName: String, data: Map<String, Any?>?) {
//    handler.post {
//      val event: MutableMap<String, Any?> = mutableMapOf("methodName" to methodName)
//      data?.let { event.putAll(it) }
//      eventSink?.success(event)
//    }
//  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
//    val textureRegistry = registrar?.textures() ?: binding?.textureRegistry
//    val messenger = registrar?.messenger() ?: binding?.binaryMessenger

    // Iris supported
    when (call.method) {
      "createTextureRender" -> {
        result.notImplemented()
        return
      }
      "destroyTextureRender" -> {
        result.notImplemented()
        return
      }
      "getAssetAbsolutePath" -> {
        getAssetAbsolutePath(call, result)
        return
      }
      "openEncodeData" ->{
        val boolean = call.argument<Boolean>("openEncodeData")
        if(boolean != null)
          _openEncodeData = boolean
        return
      }
      else -> {
        callApiMethodCallHandler.onMethodCall(call, result)
      }
    }

  }

  private fun getAssetAbsolutePath(call: MethodCall, result: Result) {
    call.arguments<String>()?.let {
      val assetKey = registrar?.lookupKeyForAsset(it)
        ?: binding?.flutterAssets?.getAssetFilePathByName(it)
      try {
        applicationContext.assets.openFd(assetKey!!).close()
        result.success("/assets/$assetKey")
      } catch (e: Exception) {
        result.error(e.javaClass.simpleName, e.message, e.cause)
      }
      return@getAssetAbsolutePath
    }
    result.error(IllegalArgumentException::class.simpleName ?: "IllegalArgumentException", "The parameter should not be null", null)
  }
}
