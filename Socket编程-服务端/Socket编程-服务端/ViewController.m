//
//  ViewController.m
//  Socket编程-服务端
//
//  Created by 谢恩平 on 2023/4/7.
//

#import "ViewController.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
//htons: 将一个无符号短整形的主机数值转换为网络字节顺序，不同CPU 是不同顺序的（big-endian大尾顺序， little-endian小尾顺序）
#define SOCKETPORT htons(8040)
// inet_addr: 将一个点分十进制的IP转换成一个长整数整形
#define SOCKETIP inet_addr("127.0.0.1")

#define SCREEN_WIDTH [UIScreen mainScreen].bounds.size.width
#define SCREEN_HIGHT [UIScreen mainScreen].bounds.size.height

@interface ViewController ()<UITableViewDataSource>
@property (nonatomic, assign) int serverSocketID;
@property (nonatomic, assign) int peerSocketId;
@property (nonatomic, strong) NSMutableArray *messages;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UITextField *textField;
@property (nonatomic, strong) UIButton *sendBtn;
@property (nonatomic, strong) UIButton *btn;
@property (nonatomic, strong) UIButton *closeBtn;
@end

@implementation ViewController

- (NSMutableArray *)messages {
    if (_messages == nil ) {
        _messages = [[NSMutableArray alloc] init];
    }
    return _messages;
}
-(void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.textField resignFirstResponder];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setViews];
//    [self initSocketTCP];
}
- (void)setViews {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HIGHT / 2)];
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
    
    self.textField = [[UITextField alloc] initWithFrame:CGRectMake(100, 500, 200, 30)];
    self.textField.backgroundColor = [UIColor lightGrayColor];
    [self.view addSubview: self.textField];
    
    self.sendBtn = [[UIButton alloc] initWithFrame:CGRectMake(100, 550, 200, 50)];
    [self.sendBtn setBackgroundColor: [UIColor greenColor] ];
    [self.sendBtn setTitle:@"发送" forState:UIControlStateNormal];
    [self.sendBtn addTarget:self action:@selector(sendAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview: self.sendBtn];
    
    self.btn = [[UIButton alloc] initWithFrame:CGRectMake(100, 625, 200, 50)];
    [self.btn setBackgroundColor: [UIColor greenColor] ];
    [self.btn setTitle:@"启动监听" forState:UIControlStateNormal];
    [self.btn addTarget:self action:@selector(initSocketTCP) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview: self.btn];
    
    self.closeBtn = [[UIButton alloc] initWithFrame:CGRectMake(100, 700, 200, 50)];
    [self.closeBtn setBackgroundColor: [UIColor greenColor] ];
    [self.closeBtn setTitle:@"释放" forState:UIControlStateNormal];
    [self.closeBtn addTarget:self action:@selector(closeAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview: self.closeBtn];
}


- (void)initSocketTCP {
    int socketID = socket(AF_INET, SOCK_STREAM, 0);
    self.serverSocketID = socketID;
    if (socketID == -1) {
        NSLog(@"socket创建失败");
        return;
    }
    NSLog(@"socket创建成功");
    
    struct sockaddr_in addr;
    //初始化为0
    memset(&addr, 0, sizeof(addr));
    // 指定协议蔟 ，这里是用的是TCP/UDP，就是AF_INET
    addr.sin_family = AF_INET;
    // 指定服务端监听的端口号
    addr.sin_port = SOCKETPORT;
    // 指定监听的IP，当为inaddr_any的时候，表示监听所有的ip
    addr.sin_addr.s_addr = INADDR_ANY;
    
    // 绑定socket的ip和port（condition是一个单纯用来做判断的变量）
    int condition = bind(self.serverSocketID, (const struct sockaddr *)&addr, sizeof(addr));
    
    if (condition != 0) {
        NSLog(@"socket绑定失败, 释放socket");
        close(self.serverSocketID);
        return;
    }
    NSLog(@"socket绑定成功");
    
    // 监听
    condition = listen(socketID, 5);
    
    if (condition != 0) {
        NSLog(@"监听失败");
        return;
    }
    // 开个线程去接受客户端的连接请求，防阻塞主线程
    NSThread *th = [[NSThread alloc] initWithTarget:self selector:@selector(spinToReceiveClient) object:nil];
    [th start];
    
}

- (void)spinToReceiveClient {
    while (1) {
        struct sockaddr_in peerAddr;
        /// 对端的socket id
        int peerSocketId;
        socklen_t addrLen = sizeof(peerAddr);
        
        // 等待客户端的连接，这里是阻塞的。
        peerSocketId = accept(self.serverSocketID, (struct sockaddr *)&peerAddr, &addrLen);
        self.peerSocketId = peerSocketId;
        [self.messages removeAllObjects];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
        if (peerSocketId != -1) {
            // 和客户端同理，开个线程接受消息防阻塞。
            NSThread *th = [[NSThread alloc] initWithBlock:^{
                NSLog(@"接受客户端的连接,客户端IP：%s, 客户端port: %d", inet_ntoa(peerAddr.sin_addr), ntohs(peerAddr.sin_port));
                
                char buffer[1024];
                // 接收来自客户端的信息
                do {
                    recv(peerSocketId, buffer, sizeof(buffer), 0);
                    NSString *str = [NSString stringWithCString:buffer encoding:NSUTF8StringEncoding];
                    if (str.length != 0) {
                        [self.messages addObject:str];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.tableView reloadData];
                        });
                    }
                    if (strlen(buffer) == 0) {
                        break;
                    }
                    // 将buffer的 前sizeof(buffer)位 置为  0。 其实就是将buffer重置为0而已。这里重置是为了到时候close调用后用于打破循环，不然的话这里到时候会死循环，因为只要有一端close，recv就不会再阻塞，buffer的内容就是之前留下来的东西。
                    memset(buffer, 0, sizeof(buffer));

                } while (1);
                NSLog(@"释放本次连接");
                // 根据对端socket来决定释放哪个连接（因为服务端建立多个连接
                close(peerSocketId);
            }];
            [th start];
        }
    }
}



/// 发送消息的具体方法
- (void)sendMessage:(NSString *)msg {
    const char *send_Message = [msg cStringUsingEncoding:NSUTF8StringEncoding];
    // send 只负责把用户态缓存拷贝到内核缓存中，所以是无法感知是否成功发送的。 同理recv只负责把内核缓存拷贝到用户态中。
    send(self.peerSocketId, send_Message, strlen(send_Message), 0);
}

- (void)sendAction: (UIButton *)sender {
    if (self.textField.text.length == 0) {
        NSLog(@"发送消息不能为空");
        return;
    }
    [self sendMessage: self.textField.text];
    // 直接添加数据了，这里暂时不考虑它是否成功到达对端，就不做微信那个小菊花的判断了。
    NSString *str = [self.textField.text copy];
    [self.messages addObject: str];
    [self.tableView reloadData];
    self.textField.text = @"";
}

/// 关闭按钮的具体方法
- (void)closeAction: (UIButton *)sender {
    if (self.peerSocketId == 0) {
        NSLog(@"未建立连接");
        return;
    }
    close(self.peerSocketId);
    NSLog(@"连接释放");
    self.peerSocketId = 0;

}

#pragma mark - Delegate
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.messages.count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *reuseId = @"id";
    
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier: reuseId];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"id"];
    }
    [cell setFrame:CGRectMake(0, 0, SCREEN_WIDTH, 50)];
    cell.textLabel.text = self.messages[indexPath.row];
    
    return cell;
}


@end
