//
//  ViewController.m
//  FFmpegTest
//
//  Created by weiyun on 2018/1/26.
//  Copyright © 2018年 孙世玉. All rights reserved.
//

#import "ViewController.h"
#import "MoviePlayer.h"
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>

#define LERP(A,B,C) ((A)*(1.0-C)+(B)*C)
#define SCREEN_WIDTH  [UIScreen mainScreen].bounds.size.width
#define SCREEN_HEIGHT [UIScreen mainScreen].bounds.size.height

@interface ViewController ()
@property (nonatomic, strong) MoviePlayer *video;
@property (nonatomic , strong) UIImageView *imageView;
@property (nonatomic , strong) UILabel *fps;
@property (nonatomic , strong) UIButton *playBtn;
@property (nonatomic , strong) UIButton *timerBtn;
@property (nonatomic , strong) UILabel *timerLabel;
@property (nonatomic , assign) float lastFrameTime;
@end

@implementation ViewController

// @synthesize imageView, video;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setUI];
    
}

- (void)playClick:(UIButton *)button
{
    [self.playBtn setEnabled:NO];
    _lastFrameTime = -1;
    
    // seek to 0.0 seconds
    [self.video seekTime:0.0];
    
    
    [NSTimer scheduledTimerWithTimeInterval: 1 / self.video.fps
                                     target:self
                                   selector:@selector(displayNextFrame:)
                                   userInfo:nil
                                    repeats:YES];
}

- (void)timerCilick:(id)sender {
    
    //NSLog(@"current time: %f s",video.currentTime);
    //[video seekTime:150.0];
    //[video replaceTheResources:@"/Users/king/Desktop/Stellar.mp4"];
    if (self.playBtn.enabled) {
        [self.video redialPaly];
        [self playClick:self.playBtn];
    }
}

-(void)displayNextFrame:(NSTimer *)timer {
    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
    //    self.TimerLabel.text = [NSString stringWithFormat:@"%f s",video.currentTime];
    self.timerLabel.text  = [self dealTime:self.video.currentTime];
    if (![self.video stepFrame]) {
        [timer invalidate];
        [self.playBtn setEnabled:YES];
        return;
    }
    
    self.imageView.image = self.video.currentImage;
    
    float frameTime = 1.0 / ([NSDate timeIntervalSinceReferenceDate] - startTime);
    if (_lastFrameTime < 0) {
        _lastFrameTime = frameTime;
    } else {
        _lastFrameTime = LERP(frameTime, _lastFrameTime, 0.8);
    }
    [self.fps setText:[NSString stringWithFormat:@"fps：%.0f",_lastFrameTime]];
}

- (NSString *)dealTime:(double)time {
    
    int tns, thh, tmm, tss;
    tns = time;
    thh = tns / 3600;
    tmm = (tns % 3600) / 60;
    tss = tns % 60;
    
    return [NSString stringWithFormat:@"%02d:%02d:%02d",thh,tmm,tss];
}

- (void)setUI
{
    self.imageView = [[UIImageView alloc] initWithFrame:CGRectMake(20, 20, SCREEN_WIDTH - 40, 400)];
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.view addSubview:self.imageView];
    
    self.playBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 450, 60, 40)];
    [self.playBtn addTarget:self action:@selector(playClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.playBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.playBtn setTitle:@"播放" forState:UIControlStateNormal];
    [self.view addSubview:self.playBtn];
    
    self.fps = [[UILabel alloc] initWithFrame:CGRectMake(150, 450, 80, 40)];
    self.fps.text = @"fps：0";
    [self.view addSubview:self.fps];
    
    self.timerBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 500, 60, 40)];
    [self.timerBtn addTarget:self action:@selector(timerCilick:) forControlEvents:UIControlEventTouchUpInside];
    [self.timerBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.timerBtn setTitle:@"时间" forState:UIControlStateNormal];
    [self.view addSubview:self.timerBtn];
    
    self.timerLabel = [[UILabel alloc] initWithFrame:CGRectMake(150, 500, 80, 40)];
    self.timerLabel.text = @"00:00:00";
    [self.view addSubview:self.timerLabel];
    
    NSString *urlString = @"http://120.25.226.186:32812/resources/videos/minion_01.mp4";
    //播放网络视频
    self.video = [[MoviePlayer alloc] initWithVideo:urlString];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


@end
