//
//  MoviePlayer.m
//  FFmpegTest
//
//  Created by weiyun on 2018/1/29.
//  Copyright © 2018年 孙世玉. All rights reserved.
//

#import "MoviePlayer.h"

@interface MoviePlayer ()
@property (nonatomic , copy) NSString *currentPath;
@end

@implementation MoviePlayer
{
    AVFormatContext     *aFormatCtx;
    AVCodecContext      *aCodecCtx;
    AVFrame             *aFrame;
    AVStream            *stream;
    AVPacket            aPacket;
    AVPicture           aPicture;
    int                 videoStream;
    double              fps;
    BOOL                isReleaseResources;
}

- (instancetype)initWithVideo:(NSString *)moviePath {
    
    if (!(self=[super init])) return nil;
    if ([self initializeResources:[moviePath UTF8String]]) {
        self.currentPath = [moviePath copy];
        return self;
    } else {
        return nil;
    }
}
- (BOOL)initializeResources:(const char *)filePath {
    
    isReleaseResources = NO;
    AVCodec *pCodec;
    // 注册所有解码器
    avcodec_register_all();
    av_register_all();
    avformat_network_init();
    // 打开视频文件
    if (avformat_open_input(&aFormatCtx, filePath, NULL, NULL) != 0) {
        NSLog(@"打开文件失败");
        goto initError;
    }
    // 检查数据流
    if (avformat_find_stream_info(aFormatCtx, NULL) < 0) {
        NSLog(@"检查数据流失败");
        goto initError;
    }
    // 根据数据流,找到第一个视频流
    if ((videoStream = av_find_best_stream(aFormatCtx, AVMEDIA_TYPE_VIDEO, -1, -1, &pCodec, 0)) < 0) {
        NSLog(@"没有找到第一个视频流");
        goto initError;
    }
    // 获取视频流的编解码上下文的指针
    stream      = aFormatCtx->streams[videoStream];
    aCodecCtx  = stream->codec;
#if DEBUG
    // 打印视频流的详细信息
    av_dump_format(aFormatCtx, videoStream, filePath, 0);
#endif
    if(stream->avg_frame_rate.den && stream->avg_frame_rate.num) {
        fps = av_q2d(stream->avg_frame_rate);
    } else { fps = 30; }
    // 查找解码器
    pCodec = avcodec_find_decoder(aCodecCtx->codec_id);
    if (pCodec == NULL) {
        NSLog(@"没有找到解码器");
        goto initError;
    }
    // 打开解码器
    if(avcodec_open2(aCodecCtx, pCodec, NULL) < 0) {
        NSLog(@"打开解码器失败");
        goto initError;
    }
    // 分配视频帧
    aFrame = av_frame_alloc();
    _outputWidth = aCodecCtx->width;
    _outputHeight = aCodecCtx->height;
    return YES;
initError:
    return NO;
}

- (void)seekTime:(double)seconds
{
    AVRational timeBase = aFormatCtx->streams[videoStream]->time_base;
    int64_t targetFrame = (int64_t)((double)timeBase.den / timeBase.num * seconds);
    avformat_seek_file(aFormatCtx, videoStream, 0, targetFrame, targetFrame, AVSEEK_FLAG_FRAME);
    avcodec_flush_buffers(aCodecCtx);
}

- (BOOL)stepFrame {
    int frameFinished = 0;
    while (!frameFinished && av_read_frame(aFormatCtx, &aPacket) >= 0) {
        if (aPacket.stream_index == videoStream) {
            //avcodec_send_packet(aCodecCtx, &aPacket);
            //avcodec_receive_frame(aCodecCtx, aFrame);
// 已废弃
            avcodec_decode_video2(aCodecCtx,
                                  aFrame,
                                  &frameFinished,
                                  &aPacket);
        }
    }
    if (frameFinished == 0 && isReleaseResources == NO) {
        [self releaseResources];
    }
    return frameFinished != 0;
}

- (void)replaceTheResources:(NSString *)moviePath {
    if (!isReleaseResources) {
        [self releaseResources];
    }
    self.currentPath = [moviePath copy];
    [self initializeResources:[moviePath UTF8String]];
}
- (void)redialPaly {
    [self initializeResources:[self.currentPath UTF8String]];
}

#pragma mark ------------------------------------
#pragma mark  重写属性访问方法
-(void)setOutputWidth:(int)newValue {
    if (_outputWidth == newValue) return;
    _outputWidth = newValue;
}
-(void)setOutputHeight:(int)newValue {
    if (_outputHeight == newValue) return;
    _outputHeight = newValue;
}
-(UIImage *)currentImage {
    if (!aFrame->data[0]) return nil;
    return [self imageFromAVPicture];
}
-(double)duration {
    return (double)aFormatCtx->duration / AV_TIME_BASE;
}
- (double)currentTime {
    AVRational timeBase = aFormatCtx->streams[videoStream]->time_base;
    return aPacket.pts * (double)timeBase.num / timeBase.den;
}
- (int)sourceWidth {
    return aCodecCtx->width;
}
- (int)sourceHeight {
    return aCodecCtx->height;
}
- (double)fps {
    return fps;
}
#pragma mark --------------------------
#pragma mark - 内部方法
- (UIImage *)imageFromAVPicture
{
    avpicture_free(&aPicture);
    avpicture_alloc(&aPicture, AV_PIX_FMT_RGB24, _outputWidth, _outputHeight);
    struct SwsContext * imgConvertCtx = sws_getContext(aFrame->width,
                                                       aFrame->height,
                                                       AV_PIX_FMT_YUV420P,
                                                       _outputWidth,
                                                       _outputHeight,
                                                       AV_PIX_FMT_RGB24,
                                                       SWS_FAST_BILINEAR,
                                                       NULL,
                                                       NULL,
                                                       NULL);
    if(imgConvertCtx == nil) return nil;
    sws_scale(imgConvertCtx,
              aFrame->data,
              aFrame->linesize,
              0,
              aFrame->height,
              aPicture.data,
              aPicture.linesize);
    sws_freeContext(imgConvertCtx);
    
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CFDataRef data = CFDataCreate(kCFAllocatorDefault,
                                  aPicture.data[0],
                                  aPicture.linesize[0] * _outputHeight);
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImage = CGImageCreate(_outputWidth,
                                       _outputHeight,
                                       8,
                                       24,
                                       aPicture.linesize[0],
                                       colorSpace,
                                       bitmapInfo,
                                       provider,
                                       NULL,
                                       NO,
                                       kCGRenderingIntentDefault);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    CFRelease(data);
    
    return image;
}

#pragma mark --------------------------
#pragma mark - 释放资源
- (void)releaseResources {
    NSLog(@"释放资源");
    //    SJLogFunc
    isReleaseResources = YES;
    // 释放RGB
    avpicture_free(&aPicture);
    // 释放frame
    av_packet_unref(&aPacket);
    // 释放YUV frame
    av_free(aFrame);
    // 关闭解码器
    if (aCodecCtx) avcodec_close(aCodecCtx);
    // 关闭文件
    if (aFormatCtx) avformat_close_input(&aFormatCtx);
    avformat_network_deinit();
}
@end
