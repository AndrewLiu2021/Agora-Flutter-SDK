package io.agora.agora_rtc_engine;

import android.util.SparseIntArray;

import java.nio.ByteBuffer;

/**
 * @author dashu
 * @date 11/23/20
 * describe:
 */
class ADTSUtils {
    private static final SparseIntArray SAMPLE_RATE_TYPE;

    static {
        SAMPLE_RATE_TYPE = new SparseIntArray();
        SAMPLE_RATE_TYPE.put(96000, 0);
        SAMPLE_RATE_TYPE.put(88200, 1);
        SAMPLE_RATE_TYPE.put(64000, 2);
        SAMPLE_RATE_TYPE.put(48000, 3);
        SAMPLE_RATE_TYPE.put(44100, 4);
        SAMPLE_RATE_TYPE.put(32000, 5);
        SAMPLE_RATE_TYPE.put(24000, 6);
        SAMPLE_RATE_TYPE.put(22050, 7);
        SAMPLE_RATE_TYPE.put(16000, 8);
        SAMPLE_RATE_TYPE.put(12000, 9);
        SAMPLE_RATE_TYPE.put(11025, 10);
        SAMPLE_RATE_TYPE.put(8000, 11);
        SAMPLE_RATE_TYPE.put(7350, 12);
    }

    private static int getSampleRateType(int sampleRate) {
        int value = SAMPLE_RATE_TYPE.get(sampleRate, -1);
        if (value == -1) {
            String msg = "sampleRate:" + sampleRate + " is not supported";
            throw new IllegalArgumentException(msg);
        }
        return value;
    }

    public static void addADTStoPacket(byte[] packet, int sampleRate, int packetLen) {
        int profile = 2; // AAC LC
        int freqIdx = getSampleRateType(sampleRate);
        int chanCfg = 2; // CPE

        packet[0] = (byte) 0xFF;
        packet[1] = (byte) 0xF9;
        packet[2] = (byte) (((profile - 1) << 6) + (freqIdx << 2) + (chanCfg >> 2));
        packet[3] = (byte) (((chanCfg & 3) << 6) + (packetLen >> 11));
        packet[4] = (byte) ((packetLen & 0x7FF) >> 3);
        packet[5] = (byte) (((packetLen & 7) << 5) + 0x1F);
        packet[6] = (byte) 0xFC;
    }

  public static byte[] bytebuffer2ByteArray(ByteBuffer buffer) {

    //重置 limit 和postion 值
    //buffer.flip();
    //获取buffer中有效大小
    int len=buffer.limit() - buffer.position();

    byte [] bytes= new byte[len];

    for (int i = 0; i < bytes.length; i++) {
      bytes[i]=buffer.get();
    }

    return bytes;
  }

}
