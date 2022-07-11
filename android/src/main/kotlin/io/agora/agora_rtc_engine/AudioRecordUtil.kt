package io.agora.agora_rtc_engine;

/**
 * @author dashu
 * @date 11/21/20
 * describe:
 *
 */
class AudioRecordUtil {


    companion object {
        private var pcmEncoderAAC: PCMEncoderAAC? = null

        fun encodeData(byteArray: ByteArray, numOfSamples: Int, bytesPerSample: Int, channels: Int, samplesPerSec: Int, encoderListener: EncoderListener): Boolean {
            if (null == pcmEncoderAAC) {
                synchronized(this) {
                    if (null == pcmEncoderAAC) {
                        pcmEncoderAAC = PCMEncoderAAC(numOfSamples, bytesPerSample, channels, samplesPerSec, encoderListener)
                    }
                }
            }
            pcmEncoderAAC!!.encodeData(byteArray)
            return true
        }
    }
}
