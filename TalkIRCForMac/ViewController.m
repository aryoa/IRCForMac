//
//  ViewController.m
//  TalkIRCForMac
//
//  Created by ryo on 2016/04/02.
//  Copyright © 2016年 ryo. All rights reserved.
//

#import "ViewController.h"

static int sendMessage_NoChangeTime = 1;

@interface ViewController()


@property (weak) IBOutlet NSTextField *serverText;
@property (weak) IBOutlet NSTextField *portText;
@property (weak) IBOutlet NSSecureTextField *serverPasswordText;
@property (weak) IBOutlet NSTextField *channelText;
@property (weak) IBOutlet NSTextField *nicknameText;
@property (weak) IBOutlet NSTextField *text;
@property (weak) IBOutlet NSButton *disconnectButton;
@property (weak) IBOutlet NSButton *connectButton;

@property (unsafe_unretained) IBOutlet NSTextView *logTextView;

@property NSInputStream	*inputStream;
@property NSOutputStream	*outputStream;


@property BOOL isChangeText;             // testViewに変化があったかを確認
@property NSTimer *timer;            // 1.0秒毎にタイマーを起動
@property int stopInpuSecond;        // textViewに変化のない時間（秒）



- (IBAction)connect:(id)sender;
- (IBAction)disconnect:(id)sender;
@end
@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    self.text.delegate = self;

    
    [self.disconnectButton setEnabled:NO];
    [self.connectButton setEnabled:YES];
    
    [self.logTextView setEditable:NO];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

- (IBAction)disconnect:(id)sender {
    
    [self.connectButton setEnabled:YES];
    [self.disconnectButton setEnabled:NO];

    [self disconnect];
}

- (IBAction)connect:(id)sender {
    
    
    NSString *message = [self checkInputInfo];
    if (message){
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"入力エラー"];
        [alert setInformativeText:message];
        [alert runModal];

        return;
    }
    [self.connectButton setEnabled:NO];
    [self.disconnectButton setEnabled:YES];
    [self initNetworkCommunication];
    
    // ターマーセット
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                  target:self
                                                selector:@selector(time:)
                                                userInfo:nil
                                                 repeats:YES];
}

- (NSString *)checkInputInfo
{
    NSString * message = nil;
    // サーバーパスワードは空でもいい
    if ([[self.serverText stringValue] length] == 0){
        message = @"サーバーが空です";
    }else if ([[self.portText stringValue] length] == 0){
        message = @"ポートが空です";
    }else if ([self containsOnlyDecimalNumbers:[self.portText stringValue]] == NO){
        message = @"ポートには数値を入力";
    }else if ([[self.channelText stringValue] length] == 0){
        message = @"チャンネルが空です";
    }else if ([[self.nicknameText stringValue] length] == 0){
        message = @"ニックネームが空です";
    }
    return message;
}


/***
 
 引数の文字列が数値のみかをチェック
 ***/
- (BOOL)containsOnlyDecimalNumbers:(NSString *)string
{
    NSCharacterSet *characterSet = [NSCharacterSet characterSetWithCharactersInString:string];
    return [[NSCharacterSet decimalDigitCharacterSet] isSupersetOfSet:characterSet];
}



- (void)disconnect
{
    [self.inputStream close];
    [self.outputStream close];
    
    // タイマーを止める
    //タイマーが動いているときにタイマー停止
    if ([self.timer isValid]) {
        [self.timer invalidate];
    }
}



-(void)time:(NSTimer*)timer{
    
    // 変化があったらIRCサーバーに送信
    if (self.isChangeText == YES){
        self.stopInpuSecond++;
    }
    
    if (self.stopInpuSecond >= sendMessage_NoChangeTime && self.isChangeText == YES){
        // IRCサーバーにメッセージ送信
        NSString *message  = [NSString stringWithFormat:@"%@ :%@ ", [self.channelText stringValue], [self.text stringValue]];
        [self.text setStringValue:@""]; // textフィールドの値をクリア
        [self sendMessageWithCommand:@"PRIVMSG" message:message];
        self.stopInpuSecond = 0;
        self.isChangeText = NO;
    }
    
}

#pragma IRC

- (void) initNetworkCommunication {
    
    
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)[self.serverText stringValue], [[self.portText stringValue] intValue], &readStream, &writeStream);
    
    self.inputStream = (__bridge NSInputStream *)readStream;
    self.outputStream = (__bridge NSOutputStream *)writeStream;
    [self.inputStream setDelegate:self];
    [self.outputStream setDelegate:self];
    [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.inputStream open];
    [self.outputStream open];
    
    // パスワードが0文字なら送信しない
    if ([[self.serverPasswordText stringValue] length] != 0){
        [self sendMessageWithCommand:@"PASS" message:[self.serverPasswordText stringValue]];
    }
    [self sendMessageWithCommand:@"NICK" message:[self.nicknameText stringValue]];
    
    NSString *message  = [NSString stringWithFormat:@"%@ 0 * %@",[self.nicknameText stringValue], [self.nicknameText stringValue]];
    [self sendMessageWithCommand:@"USER" message:message];
    
    [self sendMessageWithCommand:@"JOIN" message:[self.channelText stringValue]];
    
}




- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
//    NSLog(@"stream event %lu", (unsigned long)streamEvent);
    
    switch (streamEvent) {
            
        case NSStreamEventNone:
            NSLog(@"NSStreamEventNone");
            break;
        case NSStreamEventOpenCompleted:
            NSLog(@"Stream opened");
            break;
        case NSStreamEventHasBytesAvailable:
            NSLog(@"NSStreamEventHasBytesAvailable");
            
            if (theStream == self.inputStream) {
                uint8_t buffer[1024];
                long len;
                while ([self.inputStream hasBytesAvailable]) {
                    len = [self.inputStream read:buffer maxLength:sizeof(buffer)];
                    if (len > 0) {
                        NSString *output = [[NSString alloc] initWithBytes:buffer length:len encoding:NSASCIIStringEncoding];

                        // ログ出力
                        [self.logTextView setEditable:YES];
                        [self.logTextView insertText:output];
                        [self.logTextView setEditable:NO];

                        if (nil != output) {
                            
                            if ([output hasPrefix:@"PING"])
                            {
                                NSLog(@"PING");
                                NSString *response60  = [NSString stringWithFormat:@"PONG %@\r\n",[self.serverText stringValue]];
                                NSData *data60 = [[NSData alloc] initWithData:[response60 dataUsingEncoding:NSASCIIStringEncoding]];
                                [self.outputStream write:[data60 bytes] maxLength:[data60 length]];
                                
                            }
                        }
                    }
                }
            }
            
            break;
            
            
        case NSStreamEventErrorOccurred:
            
            // ログ出力
            [self.logTextView setEditable:YES];
            [self.logTextView insertText:@"Can not connect to the host!\n"];
            [self.logTextView setEditable:NO];

            [self disconnect];
            [self.disconnectButton setEnabled:NO];
            [self.connectButton setEnabled:YES];

            break;
            
        case NSStreamEventEndEncountered:
            
            NSLog(@"NSStreamEventEndEncountered");
            
            [theStream close];
            [theStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            theStream = nil;
            
            
            break;
        default:
            NSLog(@"Unknown event");
    }
}


- (void) messageReceived:(NSString *)message {
    
}


-(void)sendMessageWithCommand:command message:message
{
    // メッセージに関しては、ここ参照
    // http://web.archive.org/web/20140504235439/http://www.haun.org/kent/lib/rfc1459-irc-ja.html#c4.4
    NSString *response  = [NSString stringWithFormat:@"%@ %@\r\n", command, message];
    NSData *data;
    if ([command isEqualToString:@"PRIVMSG"]){
        data = [[NSData alloc] initWithData:[response dataUsingEncoding:NSUTF8StringEncoding]];
    }else{
        data = [[NSData alloc] initWithData:[response dataUsingEncoding:NSUTF8StringEncoding]];
        
    }
    [self.outputStream write:[data bytes] maxLength:[data length]];
}


#pragma NSTextField Delegate
- (void)controlTextDidChange:(NSNotification *)notification {
    self.isChangeText = YES;
}

@end
