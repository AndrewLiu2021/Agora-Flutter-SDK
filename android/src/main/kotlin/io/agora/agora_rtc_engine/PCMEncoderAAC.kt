package io.agora.agora_rtc_engine;

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.util.Log
import java.io.IOException
import java.nio.ByteBuffer
import java.util.*

/**
 * @author dashu
 * @date 11/21/20
 * describe:
 *
 */
class PCMEncoderAAC {
    //比特率
//    private val KEY_BIT_RATE = 96000

    //读取数据的最大字节数
//    private val KEY_MAX_INPUT_SIZE = 1024 * 1024

    //声道数
//    private val CHANNEL_COUNT = 2
    private lateinit var mediaCodec: MediaCodec
    private lateinit var encodeInputBuffers: Array<ByteBuffer>
    private lateinit var encodeOutputBuffers: Array<ByteBuffer>
    private lateinit var encodeBufferInfo: MediaCodec.BufferInfo
    private lateinit var encoderListener: EncoderListener
    private var numOfSamples = 0
    private var bytesPerSample = 0
    private var channels = 1
    private var samplesPerSec = 0
    private var sampleRateType = 0

    private constructor()

    /**
     * @param numOfSamples 采样数 320
     * @param bytesPerSample 样本字节数 2
     * @param channels 声道 1 单声道
     * @param samplesPerSec 采样率 32000
     * 获得录制的声音====640,采样数numOfSamples=320,样本字节数bytesPerSample=2,声道channels=1,采样点数samplesPerSec=32000
     */
    constructor(numOfSamples: Int, bytesPerSample: Int, channels: Int, samplesPerSec: Int, encoderListener: EncoderListener) {
        this.encoderListener = encoderListener
        init(numOfSamples, bytesPerSample, channels, samplesPerSec)
    }

    /**
     * 初始化AAC编码器
     * sampleRate=320,bytesPerSample=2,channels=1,samplesPerSec=32000
     */
    private fun init(sampleRate: Int, bytesPerSample: Int, channels: Int, samplesPerSec: Int) {
        Log.d("azhansy", "sampleRate=$sampleRate,bytesPerSample=$bytesPerSample,channels=$channels,samplesPerSec=$samplesPerSec")
        this.numOfSamples = sampleRate
        this.bytesPerSample = bytesPerSample
        this.channels = channels
        this.samplesPerSec = samplesPerSec
        try {
            //参数对应-> mime type、采样率、声道数
            val encodeFormat: MediaFormat = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, samplesPerSec, channels)
            //比特率
            encodeFormat.setInteger(MediaFormat.KEY_BIT_RATE, samplesPerSec)
            //描述要使用的AAC配置文件的键（仅限AAC音频格式）。
            encodeFormat.setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)

            encodeFormat.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, sampleRate)
//            sampleRateType = ADTSUtils.getSampleRateType(sampleRate)
            mediaCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
            mediaCodec.configure(encodeFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        } catch (e: IOException) {
            e.printStackTrace()
        }
        mediaCodec.start()
        encodeInputBuffers = mediaCodec.inputBuffers
        encodeOutputBuffers = mediaCodec.outputBuffers
        encodeBufferInfo = MediaCodec.BufferInfo()
    }

    /**
     * @param data
     */
    fun encodeData(data: ByteArray) {
        //dequeueInputBuffer（time）需要传入一个时间值，-1表示一直等待，0表示不等待有可能会丢帧，其他表示等待多少毫秒
        //获取输入缓存的index
        synchronized(this) {
            val inputIndex = mediaCodec.dequeueInputBuffer(-1)
            if (inputIndex >= 0) {
                val inputByteBuf = encodeInputBuffers[inputIndex]
                inputByteBuf.clear()
                //添加数据
                inputByteBuf.put(data)
                //限制ByteBuffer的访问长度
                inputByteBuf.limit(data.size)
                //把输入缓存塞回去给MediaCodec
                mediaCodec.queueInputBuffer(inputIndex, 0, data.size, 0, 0)
            }
            //获取输出缓存的index
            var outputIndex = mediaCodec.dequeueOutputBuffer(encodeBufferInfo, 0)
            while (outputIndex >= 0) {
                //获取缓存信息的长度
                val byteBufSize = encodeBufferInfo.size
                //添加ADTS头部后的长度
                val bytePacketSize = byteBufSize + 7
                //拿到输出Buffer
                val outPutBuf = encodeOutputBuffers[outputIndex]
                outPutBuf.position(encodeBufferInfo.offset)
                outPutBuf.limit(encodeBufferInfo.offset + encodeBufferInfo.size)
                val aacData = ByteArray(bytePacketSize)
                //添加ADTS头部
                ADTSUtils.addADTStoPacket(aacData, samplesPerSec, bytePacketSize)
                /*
                get（byte[] dst,int offset,int length）:ByteBuffer从position位置开始读，读取length个byte，并写入dst下
                标从offset到offset + length的区域
                 */outPutBuf[aacData, 7, byteBufSize]
                outPutBuf.position(encodeBufferInfo.offset)

                val hashMap = HashMap<String, Any>()
                val list = mutableListOf<Any>()
                //该帧的采样数据
                list.add(aacData)
                //采样数
                list.add(numOfSamples)
                //每个样本的字节数：对于 PCM 来说，一般使用 16 bit，即两个字节
                list.add(bytesPerSample)
                //频道数量 1：单声道  2：双声道
                list.add(channels)
                //每声道每秒的采样点数
                list.add(samplesPerSec)
                hashMap["data"] = list
                //编码成功
                encoderListener.encodeAAC(hashMap)

                //释放
                mediaCodec.releaseOutputBuffer(outputIndex, false)
                outputIndex = mediaCodec.dequeueOutputBuffer(encodeBufferInfo, 0)
            }
        }
    }

}

interface EncoderListener {
    fun encodeAAC(data: HashMap<String, Any>)
}
