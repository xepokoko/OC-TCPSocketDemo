//
//  ViewController.m
//  Socket编程-客户端
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

@interface ViewController ()<UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, assign) int clientSocketID;
//会话内容
@property (nonatomic, strong) NSMutableArray *messages;

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UITextField *textField;
@property (nonatomic, strong) UIButton *btn;
@property (nonatomic, strong) UIButton *sendBtn;
@property (nonatomic, strong) UIButton *closeBtn;

@end

@implementation ViewController

-(void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.textField resignFirstResponder];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setViews];
}

- (NSMutableArray *)messages {
    if (_messages == nil) {
        _messages = [[NSMutableArray alloc] init];
    }
    return _messages;
}

- (void)setViews {
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HIGHT / 2)];
    self.tableView.delegate = self;
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
    [self.btn setTitle:@"连接" forState:UIControlStateNormal];
    [self.btn addTarget:self action:@selector(initSocket) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview: self.btn];
    
    self.closeBtn = [[UIButton alloc] initWithFrame:CGRectMake(100, 700, 200, 50)];
    [self.closeBtn setBackgroundColor: [UIColor greenColor] ];
    [self.closeBtn setTitle:@"释放" forState:UIControlStateNormal];
    [self.closeBtn addTarget:self action:@selector(closeAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview: self.closeBtn];
}

/// 初始化socket
- (void)initSocket {
    [self.messages removeAllObjects];
    [self.tableView reloadData];
    
    // 第一步：创建socket
    /*
     第一个参数：adress_family: 协议蔟 AF_INET代表IPV4
     第二个参数：数据格式：SOCK_STREAM（TCP)/SOCK_DGRAM（UDP）
     第三个参数：protocol 如果传入0，会根据第二个参数选中合适的协议。
     创建失败：返回-1
     */
    int socketID = socket(AF_INET, SOCK_STREAM, 0);
    self.clientSocketID = socketID;
    if (socketID == -1) {
        NSLog(@"创建socket失败");
        return;
    }
    NSLog(@"创建socket成功");
    
    
    // 连接的参数，确定协议蔟，确定IP和端口
    struct sockaddr_in socketAddr;
    socketAddr.sin_family = AF_INET;
    socketAddr.sin_port = SOCKETPORT;
    socketAddr.sin_addr.s_addr = SOCKETIP;
    
    
    //第二步： 连接
    /*
     参数一：套接字描述符
     参数二：指向数据结构sockaddr的指针，这个数据结构里面包含目的端口和IP
     参数三：参数二中被指向的sockaddr的长度，可以通过sizeof()获得
     成功则返回0，失败返回非0，错误码GetLastError（）
     */
    int result = connect(socketID, (const struct sockaddr *)&socketAddr, sizeof(socketAddr));
    if (result != 0) {
        NSLog(@"连接失败");
        close(socketID); // 直接关闭socket
        return;
    } else {
        // 连接成功的话就开个线程去接受消息，因为recv方法它是阻塞的。
        NSThread *th = [[NSThread alloc] initWithTarget:self selector:@selector(receiveAction) object:nil];
        [th start];
        NSLog(@"连接成功");
    }
}

/// 接收对端消息的逻辑
- (void)receiveAction {
    while (1) {
        /*
         参数一：客户端创建socket留下的那个id
         参数二：接受内容的缓冲区
         参数三：缓冲区长度
         参数四：接受方式：0表示阻塞，必须等服务器返回数据才往下走
         返回值：成功返回读入字节数，失败返回SOCKET_ERROR
        */
        char recv_msg[1024];
        recv(self.clientSocketID, recv_msg, sizeof(recv_msg), 0);
        NSString *str = [NSString stringWithCString:recv_msg encoding:NSUTF8StringEncoding];
        if (str.length != 0) {
            [self.messages addObject: str];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        }
        if (strlen(recv_msg) == 0) {
            break;
        }
        memset(recv_msg, 0, sizeof(recv_msg));
    }
}

/// 发送消息的具体方法
- (void)sendMessage:(NSString *)msg {
    const char *send_Message = [msg cStringUsingEncoding:NSUTF8StringEncoding];
    // send 只负责把用户态缓存拷贝到内核缓存中，所以是无法感知是否成功发送的。 同理recv只负责把内核缓存拷贝到用户态中。
    send(self.clientSocketID, send_Message, strlen(send_Message), 0);
}
/// 发送按钮的点击方法
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
    if (_clientSocketID == 0) {
        NSLog(@"未建立连接");
        return;
    }
    // 关闭socket
    close(self.clientSocketID);
    NSLog(@"连接释放");
    self.clientSocketID = 0;

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
