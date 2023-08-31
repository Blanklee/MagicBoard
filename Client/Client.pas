unit Client;

interface

uses
  Windows, SysUtils, ExtCtrls, Classes, ScktComp, HttpGet,
  Xdir, BlankUtils, FileList, Globals;

const
  // TAutoConnect에서 사용됨
  MAX_COUNTER = 15;	// FCounter는 0..14를 계속해서 돈다
  MAX_TIMEOUT = 6;	// 6초안에 서버로부터 응답없으면 끊김처리

type
  TCommandEvent = procedure (cmd: String) of object;
  TDoneFileEvent = procedure (cmd, FileName: string) of object;

  // Server로부터 여러개의 파일을 한꺼번에 Download하는 Class
  TGetFilesClient = class
  private
    position: integer;
    State: (Idle, Busy);
    FServer: string;
    FNumber: string;
    FListFile: string;
    FTimer: TTimer;
    FSimpleList: TStringList;   // 파일명만 있는 List용 (AdditionalFileName, ScheduleFileName)
    FAlbumList: TFileList;      // 다운받아야 할 파일목록, Server에서 보낸 ListFile을 읽어들인다
    FCurList: TFileList;        // 현존 파일목록, Folder내 파일을 뒤져 작성한 List
    FHttpGet: THttpGet;
    procedure TriggerMemoOut (msg: string);
    procedure Timer1Timer (Sender: TObject);
    procedure HttpGet1DoneFile (Sender: TObject; FileName: String; FileSize: Integer);
    procedure HttpGet1Error (Sender: TObject);
  protected
    FOnMemoOut: TMemoOutEvent;
    FOnFilesDone: TNotifyEvent;
    procedure SetPort (Value: string);
    procedure SetListFile (const Value: string);
  public
    constructor Create;
    destructor Destroy; override;
    function PrepareDownload: int64;
    procedure Run;
    procedure Stop;
  published
    property OnMemoOut: TMemoOutEvent read FOnMemoOut write FOnMemoOut;
    property OnFilesDone: TNotifyEvent read FOnFilesDone write FOnFilesDone;
    property Server: string read FServer write FServer;
    property Number: string read FNumber write FNumber;
    property Port: string write SetPort;
    property ListFile: string read FListFile write SetListFile;
  end;

  // Server와의 연결을 계속 확인해 주는 Class
  TAutoConnect = class
  private
    FTimeOut: integer;
    FCounter: integer;
    acTimer: TTimer;
    procedure TriggerMemoOut (msg: string);
    procedure acTimerTimer(Sender: TObject);
  protected
    FOnMemoOut: TMemoOutEvent;
    FOnHello: TNotifyEvent;
    FOnClose: TNotifyEvent;
    FOnCheck: TNotifyEvent;
  public
    constructor Create;
    destructor Destroy; override;
    procedure FillAliveFull;
    procedure TryConnectSoon;
    property OnMemoOut: TMemoOutEvent read FOnMemoOut write FOnMemoOut;
    property OnHello: TNotifyEvent read FOnHello write FOnHello;
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
    property OnCheck: TNotifyEvent read FOnCheck write FOnCheck;
  end;

  // Server와 기본적인 통신을 하는 Class
  TClient = class
  private
    FServer: string;		// 접속할 서버
    FServerPort: integer;   // Socket Port (51111)
    FHttpPort: string;		// HttpGet 포트 (8001)
    FNumber: string;		// Client 고유번호(ID)
    FMacAddr: string;		// 내컴퓨터의 Mac Address
    FCommand: string;		// Server로부터 받은 명령어
    FAlbumState: string;    // Album의 운영상태
    Client1: TClientSocket;	// Server로부터 명령을 받는 Socket
    HttpGets: array[1..5] of THttpGet;
    GetFilesClient: TGetFilesClient;	// 파일들 받는 Class
    FAutoConnect: TAutoConnect;         // 자동 재접속 Class
    procedure AutoConnectHello (Sender: TObject);
    procedure AutoConnectClose (Sender: TObject);
    procedure AutoConnectCheck (Sender: TObject);
    procedure Client1Connect(Sender: TObject; Socket: TCustomWinSocket);
    procedure Client1Disconnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure Client1Error(Sender: TObject; Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; var ErrorCode: Integer);
    procedure Client1Read(Sender: TObject; Socket: TCustomWinSocket);
    procedure Client1ProcessCommand (cmd: string; Socket: TCustomWinSocket); virtual;
    procedure HttpGet1Error(Sender: TObject);
    procedure HttpGet1DoneFile(Sender: TObject; FileName: String; FileSize: Integer);
    procedure HttpGet2DoneFile(Sender: TObject; FileName: String; FileSize: Integer);
    procedure HttpGet3DoneFile(Sender: TObject; FileName: String; FileSize: Integer);
    procedure HttpGet4DoneFile(Sender: TObject; FileName: String; FileSize: Integer);
    procedure GetFilesDone (Sender: TObject);
    procedure SendTotalSizeToServer (TotalSize: int64);
  protected
    FOnMemoOut: TMemoOutEvent;
    FOnCommand: TCommandEvent;
    FOnDoneFile: TDoneFileEvent;
    procedure TriggerMemoOut (msg: string);
    procedure TriggerCommand (cmd: string);
    procedure TriggerDoneFile (cmd, FileName: string);
    procedure SetServer (Value: string);
    procedure SetServerPort (Value: integer);
    procedure SetHttpPort (Value: string);
    procedure SetNumber (Value: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure SendTextToServer (msg: string);
  published
    property Server: string read FServer write SetServer;
    property ServerPort: integer read FServerPort write SetServerPort;
    property HttpPort: string read FHttpPort write SetHttpPort;
    property Number: string read FNumber write SetNumber;
    property AlbumState: string read FAlbumState write FAlbumState;
    property OnMemoOut: TMemoOutEvent read FOnMemoOut write FOnMemoOut;
    property OnCommand: TCommandEvent read FOnCommand write FOnCommand;
    property OnDoneFile: TDoneFileEvent read FOnDoneFile write FOnDoneFile;
  end;


implementation



// ----------------------------------------------------------------
// 여기서부터 TGetFilesClient 함수 구현
// ----------------------------------------------------------------
constructor TGetFilesClient.Create;
begin
    inherited Create;
    FServer:= '';
    FNumber:= '';
    FListFile:= '';

    // 계속해서 명령을 내려줄 Main Scheduler 기능
    FTimer:= TTimer.Create (nil);
    FTimer.Interval:= 200;
    FTimer.OnTimer:= Timer1Timer;
    FTimer.Enabled:= false;

    // 다운로드 받아야할 파일목록, 현존파일목록
    FSimpleList:= TStringList.Create;
    FAlbumList:= TFileList.Create;
    FCurList:= TFileList.Create;

    // 다운로드에 활용할 HttpGet
    // 아래와 같이 BinaryData:= True로 해야 웹서버가 중지 상태이거나 파일이 없을때 오류가 제대로 발생한다
    // 아래를 False로 하면 웹서버가 중지 상태일 때 오류 발생없이 0바이트 파일 저장후 넘어가 버린다
    FHttpGet:= THttpGet.Create (nil);
    FHttpGet.BinaryData:= True;
    FHttpGet.Port:= '8001';
    FHttpGet.OnDoneFile:= HttpGet1DoneFile;
    FHttpGet.OnError:= HttpGet1Error;
end;

destructor TGetFilesClient.Destroy;
begin
    FTimer.Free;
    FSimpleList.Free;
    FAlbumList.Free;
    FCurList.Free;
    FHttpGet.Free;
    inherited Destroy;
end;

procedure TGetFilesClient.TriggerMemoOut (msg: string);
begin
    if Assigned (FOnMemoOut) then FOnMemoOut (msg);
end;


procedure TGetFilesClient.SetPort (Value: string);
begin
    FHttpGet.Port:= Value;
end;

procedure TGetFilesClient.SetListFile (const Value: string);
var
    i: integer;
    fname: string;
begin
    FListFile:= Value;  // 절대경로

    // ListFile 로부터 내용을 읽어온다
    FAlbumList.Clear;
    if (FileExists(FListFile)) then
    try
        fname:= ExtractFileName(FListFile);
        // SEND_ALBUM => TFileList로 읽음
        if (fname=AlbumFileName)
            then FAlbumList.LoadFromFile (FListFile) else
        // SEND_ADDFILE, SEND_SCHEDULE => TStringList로 읽음
        if (fname=AdditionalFileName) or (fname=ScheduleFileName)
            then FAlbumList.LoadFromSimple (FListFile);
        TriggerMemoOut ('LoadFromSimple 완료, Count = ' + inttostr(FAlbumList.Count));
    except
        TriggerMemoOut ('LoadFromFile or Simple 도중 뭔가오류');
        FAlbumList.Clear;
    end;

    // 서버에서 작성한 파일목록을 한번좍 출력해 준다
    {$IFOPT D+}
    TriggerMemoOut ('--- 서버로부터 받은 파일목록 ---');
    for i:= 1 to FAlbumList.Count do begin
        TriggerMemoOut (ExtractFileName (FAlbumList.FileNames[i-1]));
    end;
    TriggerMemoOut (' ');
    {$ENDIF}
end;


function TGetFilesClient.PrepareDownload: int64;
var
    i, j: integer;
    Xdir1: TXdir;
begin
    // ------------ 다운로드 준비 ---------------
    // 파일의 날짜와 크기가 같은 것들은 다시받지 않는다
    // 보관할 필요가 없는 파일들은 먼저 지워버리고 받는다
    // Return: 실제로 받아야 할 파일들의 총크기
    // ------------------------------------------

    // 빈파일이 아닌지 검사한다
    Result:= -1;
    if (FAlbumList.Count = 0) then exit;

    // 1) 기존 Files 폴더내 모든 파일목록을 CurList로 가져온다
    Xdir1:= TXdir.Create (nil);
    Xdir1.StartDir:= FolderName;
    FCurList.Clear;
    while Xdir1.Find do if Xdir1.IsFile then
    if (Xdir1.FileName <> FListFile) then
    FCurList.AddFile (Xdir1.FileName);
    Xdir1.Stop;
    Xdir1.Free;

    // 2) AlbumList와 CurList를 비교하여 동일파일이면 Delete
    if (FCurList.Count > 0) then
    for i:= FCurList.Count downto 1 do
    for j:= FAlbumList.Count downto 1 do
    if TFileList.FileItemSame (FCurList[i-1], FAlbumList[j-1]) then
    begin
        FCurList.Delete(i-1);   // 삭제할 목록에서 제외
        FAlbumList.Delete(j-1); // 다운로드 받을 목록에서 제외
        break;
    end;

    // 3) CurList에 남아있는 파일들을 실제로 삭제해 준다 (필요없는 파일들임)
    for i:= 1 to FCurList.Count do
    DeleteFile (FCurList.FileNames[i-1]);

    // 4) FAlbumList에 남아있는 파일들만 모두 다운로드 받으면 된다
    {$IFOPT D+}
    TriggerMemoOut ('--- 다운받아야 할 파일목록 ---');
    for i:= 1 to FAlbumList.Count do begin
        TriggerMemoOut (ExtractFileName (FAlbumList.FileNames[i-1]));
    end;
    TriggerMemoOut (' ');
    {$ENDIF}

    // 5) 총용량을 구해서 Return 한다
    Result:= 0;
    for i:= 1 to FAlbumList.Count do
    Result:= Result + FAlbumList.FileItems[i-1].FileSize;
end;

procedure TGetFilesClient.Run;
begin
    // 이미 실행중이면 멈춘다 (if Running then Stop)
    if (State = Busy) then Stop;

    // 각종 변수 검사
    if (FServer = '') then exit;
    if (FListFile = '') then exit;

    // 첫번째 파일부터 시작한다
    position:= 0;
    // 다운로드를 시작한다
    FTimer.Enabled:= true;
end;


procedure TGetFilesClient.Stop;
begin
    // 모든 작업을 즉시 중지한다
    FTimer.Enabled:= false;
    FHttpGet.Abort;
    State:= Idle;
end;

procedure TGetFilesClient.Timer1Timer (Sender: TObject);
var
    s: string;
begin
    // Timer 함수가 주기적으로 계속하여 다음 작업을 지시한다
    // TriggerMemoOut (#13#10'Timer Enabled');

    // 작업중이면 여기서 일단 빠져나간후 대기한다
    if (State = Busy) then exit;

    // 다 받았으면 마무리를 해준다
    if (position >= FAlbumList.Count) then begin
        FTimer.Enabled:= false;
        if Assigned (FOnFilesDone) then FOnFilesDone (nil);
        exit;
    end;

    // 현재 Pos의 가져올 항목
    s:= FAlbumList.FileNames[position];

    try
        // 공백, 주석, *명령문 Line을 건너뛴다
        if (Trim(s)='') then exit;
        if (s[1] in ['/','*','[','(']) then exit;

        // 이제부터 나 바빠~
        State:= Busy;
        TriggerMemoOut (inttostr(position+1)+'번째 파일 Down시작');

        // 새 파일을 다운로드 받는다
        FHttpGet.URL:= 'http://'+ FServer + '/getfile.html?num='+FNumber+'&pathname='+s;
        FHttpGet.FileName:= FolderName + ExtractFileName (s);
        FHttpGet.GetFile;
    finally
        // 다음 항목으로 넘어간다
        position:= position + 1;
    end;
end;

procedure TGetFilesClient.HttpGet1DoneFile(Sender: TObject; FileName: String; FileSize: Integer);
var
    p: PFileItem;
    FileHandle, Age: integer;
begin
    // 다운로드 완료하면 결과를 출력해 주고 다음 파일로 넘어가도록 해놓는다
    TriggerMemoOut ('-다운로드 완료: ' + ExtractFileName(FileName) + ' ('+inttostr3(FileSize)+' Bytes)');

    if (FileSize < 30) then
        // 잘못된 파일은 삭제해 버린다: 404 Not Found
        DeleteFile (FileName)
    else begin
        // 파일 날짜를 세팅해 준다
        p:= FAlbumList[position-1];
        Age:= p^.DateTime;
        FileHandle:= FileOpen (FileName, fmOpenReadWrite or fmShareDenyNone);
        if (FileSetDate(FileHandle, Age) <> 0) then;
        FileClose (FileHandle);
    end;

    // 다음 파일을 받을 수 있도록 해준다
    FTimer.Interval:= 200;	// 곧바로 작업 시작하세요. 길게하면 파일갯수가 많을때 오래 걸린다.
    State:= Idle;			// 자동으로 다운로드 재시도 계속한다. 다음 파일로 넘어가도 좋다.

    // 다 받았으면 마무리를 해준다
    // if (pos >= FList.Count) then begin
    //	FTimer.Enabled:= false;
    //	if Assigned (FOnFilesDone) then FOnFilesDone (nil);
    //	exit;
    // end;
end;

procedure TGetFilesClient.HttpGet1Error(Sender: TObject);
begin
    // 오류가 나면 일정시간후 같은파일을 재시도한다
    TriggerMemoOut ('Http Get Error');
    FTimer.Interval:= 5000;	// 오류 시에는 5초마다 재시도한다. 짧게 하면 너무 정신없다.
    State:= Idle;			// 자동으로 다운로드 재시도 계속한다
end;





// ----------------------------------------------------------------
// 여기서부터 TAutoConnect 함수 구현
// ----------------------------------------------------------------


constructor TAutoConnect.Create;
begin
    inherited Create;
    FTimeOut:= 0;
    FCounter:= 0;

    // Server와 자동 재접속하는 ActoConnect Timer
    acTimer:= TTimer.Create (nil);
    acTimer.Enabled:= true;
    acTimer.Interval:= 1000;
    acTimer.OnTimer:= acTimerTimer;
end;

destructor TAutoConnect.Destroy;
begin
    acTimer.Free;
    inherited Destroy;
end;

procedure TAutoConnect.TriggerMemoOut (msg: string);
begin
    if Assigned (FOnMemoOut) then FOnMemoOut (msg);
end;

procedure TAutoConnect.FillAliveFull;
begin
    FTimeOut:= MAX_TIMEOUT + 3;
end;

procedure TAutoConnect.TryConnectSoon;
begin
    // 즉시 재접속 시도를 하도록 FCounter를 조정한다
    FTimeOut:= 0;
    FCounter:= 0;
    TriggerMemoOut ('즉시 재접속 시도를 합니다');
end;

procedure TAutoConnect.acTimerTimer(Sender: TObject);
begin
    // 1초에 한번씩 여기로 들어온다.
    FCounter:= FCounter + 1;
    if (FCounter >= MAX_COUNTER) then FCounter:= 0;

    // 생명을 1초에 1씩 감소시킨다
    if (FTimeOut > 0) then FTimeOut:= FTimeOut - 1;

    {$IFOPT D+}
    // TriggerMemoOut (Format('FCounter = %d, FTimeOut = %d', [FCounter, FTimeOut]));
    {$ENDIF}


    // 연결확인: 해제시 재접속 시도
    if (FCounter = 2) then begin
        // TriggerMemoOut ('FCounter = 2, 해제시 재접속 시도');
        if Assigned(FOnCheck) then FOnCheck (Self);
    end

    // 연결시: 연결확인용 Dummy Message 전송
    else if (FCounter = 5) then begin
        // TriggerMemoOut ('FCounter = 5, 연결확인용 Dummy Message 전송');
        if Assigned(FOnHello) then FOnHello (Self);
    end

    // MAX_TIMEOUT내 Server로부터 응답이 없는데 계속 연결된 걸로 인식하면 강제로 해제시킨다
    else if (FCounter = 5 + MAX_TIMEOUT) then begin
        // TriggerMemoOut ('FCounter = 11, 응답이 없는지 Check');
        if (FTimeOut = 0) then
        if Assigned(FOnClose) then FOnClose (Self);
    end;
end;





// ----------------------------------------------------------------
// 여기서부터 TClient 함수 구현
// ----------------------------------------------------------------

procedure TClient.SetServer (Value: string);
begin
    if (FServer <> Value) then begin
        FServer:= Value;
        GetFilesClient.Server:= Value;
        // 연결종료후 서버변경. 재접속은 Timer가 알아서 한다
        if (Client1.Active) then Client1.Close;
        Client1.Address:= Value;
    end;
end;

procedure TClient.SetServerPort (Value: integer);
begin
    if (FServerPort <> Value) then begin
        FServerPort:= Value;
        // 연결종료후 Port변경. 재접속은 Timer가 알아서 한다
        if (Client1.Active) then Client1.Close;
        Client1.Port:= Value;
    end;
end;

procedure TClient.SetHttpPort (Value: string);
var
    i: integer;
begin
    FHttpPort:= Value;
    for i:= 1 to 5 do HttpGets[i].Port:= Value;
    GetFilesClient.Port:= Value;
end;

procedure TClient.SetNumber (Value: string);
begin
    if (FNumber <> Value) then begin
        FNumber:= Value;
        GetFilesClient.Number:= Value;
        // 연결종료후 서버변경. 재접속은 Timer가 알아서 한다
        if (Client1.Active) then Client1.Close;
    end;
end;

procedure TClient.TriggerMemoOut (msg: string);
begin
    if Assigned (FOnMemoOut) then FOnMemoOut (msg);
end;

procedure TClient.TriggerCommand (cmd: string);
begin
    if Assigned (FOnCommand) then FOnCommand (cmd);
end;

procedure TClient.TriggerDoneFile (cmd, FileName: string);
begin
    if Assigned(FOnDoneFile) then FOnDoneFile (cmd, FileName);
end;



// ----------------------------------------------------------------
// 여기서부터 TClient 초기화 및 마무리 함수
// ----------------------------------------------------------------

constructor TClient.Create;
var
    i: integer;
begin
    inherited Create;
    FServer:= '127.0.0.1';
    FServerPort:= 51111;
    FHttpPort:= '8001';
    FNumber:= '1';
    FMacAddr:= GetMacAddress;
    FCommand:= '';
    FAlbumState:= '';

    // 명령어 받는 Socket 생성
    Client1:= TClientSocket.Create (nil);
    Client1.Address:= FServer;
    Client1.Port:= 51111;
    Client1.OnConnect:= Client1Connect;
    Client1.OnDisconnect:= Client1Disconnect;
    Client1.OnError:= Client1Error;
    Client1.OnRead:= Client1Read;

    // 파일 받는 Socket 생성
    for i:= 1 to 5 do begin
        HttpGets[i]:= THttpGet.Create (nil);
        HttpGets[i].Port:= FHttpPort;
        HttpGets[i].BinaryData:= true;
        HttpGets[i].OnError:= HttpGet1Error;
    end;
    HttpGets[1].OnDoneFile := HttpGet1DoneFile;
    HttpGets[2].OnDoneFile := HttpGet2DoneFile;
    HttpGets[3].OnDoneFile := HttpGet3DoneFile;
    HttpGets[4].OnDoneFile := HttpGet4DoneFile;

    // 여러파일 받는 Client 생성
    GetFilesClient:= TGetFilesClient.Create;
    GetFilesClient.Server:= FServer;
    GetFilesClient.Port:= FHttpPort;
    GetFilesClient.Number:= FNumber;
    GetFilesClient.OnMemoOut:= TriggerMemoOut;
    GetFilesClient.OnFilesDone:= GetFilesDone;	// 부가파일 다운완료시 할것들 (생략가능)

    // Server와 자동 재접속하는 ActoConnect 기능
    FAutoConnect:= TAutoConnect.Create;
    FAutoConnect.OnMemoOut:= TriggerMemoOut;
    FAutoConnect.OnHello:= AutoConnectHello;
    FAutoConnect.OnClose:= AutoConnectClose;
    FAutoConnect.OnCheck:= AutoConnectCheck;
end;

destructor TClient.Destroy;
var
    i: integer;
begin
    FAutoConnect.Free;
    FAutoConnect:= nil; // nil안해주면 아래 Client.Close시 재접속시도 오류
    GetFilesClient.Free;
    if Client1.Active then Client1.Close;
    Client1.Free;
    for i:= 1 to 5 do HttpGets[i].Free;
    inherited Destroy;
end;





// ----------------------------------------------------------------
// 여기서부터 TClient Socket 관련 함수
// ----------------------------------------------------------------

procedure TClient.SendTextToServer (msg: string);
begin
    if Client1.Active then
    Client1.Socket.SendText (msg);
end;


procedure TClient.SendTotalSizeToServer(TotalSize: int64);
begin
    TriggerMemoOut ('받아야 할 총용량은 ' + inttostr(TotalSize) + ' Bytes');
    SendTextToServer ('TotalSize='+inttostr(TotalSize));
end;


procedure TClient.AutoConnectHello (Sender: TObject);
begin
    if Client1.Active then begin
        TriggerMemoOut ('연결중: 연결확인용 HellO 전송');
        Client1.Socket.SendText ('HellO');
    end
end;

procedure TClient.AutoConnectClose (Sender: TObject);
begin
    // Socket을 Close하라. 서버응답이 없으니 연결을 끊어라는 뜻
    if Client1.Active then Client1.Close;
end;

procedure TClient.AutoConnectCheck (Sender: TObject);
begin
    if not Client1.Active then
    try
        TriggerMemoOut ('해제중: Server에 재접속 시도');
        Client1.Open;
    except
        TriggerMemoOut ('Try Exception: Server에 접속할 수 없음');
    end;
end;

procedure TClient.Client1Connect(Sender: TObject; Socket: TCustomWinSocket);
begin
    TriggerMemoOut ('Server에 연결되었습니다.');
    if (FAutoConnect <> nil) then FAutoConnect.FillAliveFull;
    Socket.SendText ('num='+FNumber+'&mac='+FMacAddr+'&album='+FAlbumState+'&');
    TriggerMemoOut ('전송: num='+FNumber+'&mac='+FMacAddr+'&album='+FAlbumState+'&');
end;

procedure TClient.Client1Disconnect(Sender: TObject; Socket: TCustomWinSocket);
begin
    TriggerMemoOut ('Server에 연결이 해제되었습니다.');
    if (FAutoConnect <> nil) then   // Destroy에서 Free후 들어올수 있으니까 nil여부 확인
    FAutoConnect.TryConnectSoon;	// 생명이 없음. 새로 접속시도
end;

procedure TClient.Client1Error(Sender: TObject; Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; var ErrorCode: Integer);
begin
    ErrorCode:= 0;		// 더이상 Exception이 발생하지 않게 한다
    TriggerMemoOut ('Server에 연결할 수 없습니다.');
    try Client1.Close; except end;
    // if (FAutoConnect <> nil) then FAutoConnect.TryConnectSoon;
end;

// Server로부터 뭔가 받았다
procedure TClient.Client1Read(Sender: TObject; Socket: TCustomWinSocket);
var
    cmd: string;
begin
    // Server로부터 뭔가 받았다
    if (FAutoConnect <> nil) then FAutoConnect.FillAliveFull;
    cmd:= Socket.ReceiveText;

    // 뭔가 오류메세지가 들어오면 무시한다
    if (length(cmd) < 4) or (length(cmd) > 20) then exit;
    TriggerMemoOut ('명령수신: ' + cmd);
    // GooD은 무시한다. 안그러면 cmd=GooD이 GetFilesDone까지 전달되어 Album 시작이 안된다.
    if (cmd='GooD') then exit;

    // 명령어를 처리한다
    FCommand:= cmd;
    // 다운로드 중이면 중지한다
    GetFilesClient.Stop;
    // MainForm 쪽에서 선처리 해준다
    TriggerCommand (cmd);
    // 명령어를 하나씩 처리한다
    Client1ProcessCommand (cmd, Socket);
end;

// Server로부터 받은 명령어를 처리한다
procedure TClient.Client1ProcessCommand (cmd: string; Socket: TCustomWinSocket);
begin
    // Server에서 나의 Mac Address를 요청 => 바로 통보해 준다
    if (cmd = 'YOUR_MAC') then begin
        Socket.SendText ('num='+FNumber+'&mac='+FMacAddr+'&');
        TriggerMemoOut ('전송: num='+FNumber+'&mac='+FMacAddr+'&');
    end else

    // PPT 파일을 보내온다
    if (cmd = 'SEND_PPT') then begin
        HttpGets[1].Abort;
        HttpGets[1].URL:= 'http://'+FServer+'/ppt.html?num='+FNumber;
        HttpGets[1].FileName:= FolderName+'Screen_t.ppt';
        HttpGets[1].GetFile;
    end else

    // PPTX 파일을 보내온다
    if (cmd = 'SEND_PPTX') then begin
        HttpGets[1].Abort;
        HttpGets[1].URL:= 'http://'+FServer+'/ppt.html?num='+FNumber;
        HttpGets[1].FileName:= FolderName+'Screen_t.pptx';
        HttpGets[1].GetFile;
    end else

    // 추가파일들 보내온다
    if (cmd = 'SEND_ADDLIST') then begin
        // List 다운받고 그이하 진행한다
        HttpGets[2].Abort;
        HttpGets[2].URL:= 'http://' + FServer + '/addlist.html?num='+FNumber;
        HttpGets[2].FileName:= FolderName+AdditionalFileName;
        HttpGets[2].GetFile;
    end else

    // 스케줄 및 관련파일들 보내온다
    if (cmd = 'SEND_SCHEDULE') then begin
        // List 다운받고 그이하 진행한다
        HttpGets[3].Abort;
        HttpGets[3].URL:= 'http://' + FServer + '/schedule.html?num='+FNumber;
        HttpGets[3].FileName:= FolderName+ScheduleFileName;
        HttpGets[3].GetFile;
    end else

    // 매직앨범 보내온다
    if (cmd = 'SEND_ALBUM') then begin
        // List 다운받고 그이하 진행한다
        HttpGets[4].Abort;
        HttpGets[4].URL:= 'http://' + FServer + '/albumlist.html?num='+FNumber;
        HttpGets[4].FileName:= FolderName+AlbumFileName;
        HttpGets[4].GetFile;
    end
end;




// ----------------------------------------------------------------
// 여기서부터 TClient HttpGet 관련 함수
// ----------------------------------------------------------------

procedure TClient.HttpGet1Error(Sender: TObject);
begin
    TriggerMemoOut ('Http 연결안됨');
end;


procedure TClient.HttpGet1DoneFile(Sender: TObject; FileName: String; FileSize: Integer);
var
    ext: string;
begin
    // PPT 파일을 다운로드 받았다. PPT Viewer 프로그램을 실행해 준다
    TriggerMemoOut ('Http Get 완료: FileName = ' + FileName + ', FileSize = ' + inttostr(FileSize));

    // 유효성 검사: 파일이 없는경우 24B짜리 404 Not Found 파일로 저장되며, 삭제해 버린다
    if (FileSize < 25) then begin DeleteFile (FileName); exit; end;

    // 기존 PPT Viewer 프로그램을 종료시킨다
    while CheckProcess ('PPTVIEW.EXE') do begin
        KillProcess ('PPTVIEW.EXE'); Sleep(500);
    end;

    // ppt인지 pptx인지 구분한다
    ext:= LowerCase(ExtractFileExt(FileName));

    // 다운로드받은 파일을 원본 프로그램으로 대체
    try		DeleteFile (FolderName+'Screen1'+ext);
    finally	RenameFile (FolderName+'Screen_t'+ext, FolderName+'Screen1'+ext); end;

    // Server에 파일 다받았다고 통보해 준다
    HttpGets[5].URL:= 'http://' + FServer + '/complete.html?num='+FNumber;
    HttpGets[5].GetString;

    // PPT Viewer 프로그램을 실행시킨다
    TriggerDoneFile (FCommand, 'Screen1'+ext);
end;


procedure TClient.HttpGet2DoneFile(Sender: TObject; FileName: String; FileSize: Integer);
begin
    // SEND_ADDFILE => 추가파일 리스트 다운로드 완료
    TriggerMemoOut ('Http Get 완료: FileName = ' + FileName + ', FileSize = ' + inttostr(FileSize));

    // 하나씩 가져온다. 다되면 OnFilesDone Event 발생, Owner에서 재생시작
    GetFilesClient.ListFile:= FileName;		// 절대경로
    GetFilesClient.Run;
end;


procedure TClient.HttpGet3DoneFile(Sender: TObject; FileName: String; FileSize: Integer);
begin
    // SEND_SCHEDULE => 스케줄파일 리스트 다운로드 완료
    TriggerMemoOut ('Http Get 완료: FileName = ' + FileName + ', FileSize = ' + inttostr(FileSize));

    // 하나씩 가져온다. 다되면 OnFilesDone Event 발생, Owner에서 재생시작
    GetFilesClient.ListFile:= FileName;		// 절대경로
    GetFilesClient.Run;
end;


procedure TClient.HttpGet4DoneFile(Sender: TObject; FileName: String; FileSize: Integer);
var
    TotalSize: int64;
begin
    // SEND_ALBUM => 앨범파일 리스트 다운로드 완료
    TriggerMemoOut ('Http Get 완료: FileName = ' + FileName + ', FileSize = ' + inttostr(FileSize));

    // 하나씩 가져온다. 다되면 OnFilesDone Event 발생, Owner에서 재생시작
    GetFilesClient.ListFile:= FileName;		// 절대경로
    TotalSize:= GetFilesClient.PrepareDownload;

    // 받아야할 총용량: -1이면 진행않음, 0 이상이면 진행
    if (TotalSize >= 0) then begin
        // 서버로 TotalSize 알려주고, 받기 시작한다
        SendTotalSizeToServer (TotalSize);
        GetFilesClient.Run;
    end;
end;


procedure TClient.GetFilesDone (Sender: TObject);
begin
    // 파일을 모두 다운로드 받았다.
    TriggerMemoOut ('--GetFilesDone: 파일을 모두 받았습니다.');

    // Server에 파일 다받았다고 통보해 준다
    HttpGets[5].URL:= 'http://' + FServer + '/complete.html?num='+FNumber;
    HttpGets[5].GetString;

    TriggerMemoOut ('--TriggerDoneFile 호출: ' + FCommand + ', ' + ExtractFileName(GetFilesClient.ListFile));
    TriggerDoneFile (FCommand, ExtractFileName(GetFilesClient.ListFile));
end;

end.

