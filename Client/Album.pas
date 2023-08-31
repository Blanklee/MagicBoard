unit Album;

interface

uses
  Windows, SysUtils, StdCtrls, ExtCtrls, Classes, Forms, OleCtrls, WMPLib_TLB,
  ShellApi, Jpeg, Xdir, BlankUtils, Globals, FileList, ScheduleManager;

type
  // 아무 컨텐츠도 없을때 화면표시용 로고라벨 표시
  TLogoPlayer = class
  private
    FlogoLabel: TLabel;
    FWidth, FHeight: integer;
    FTimer: TTimer;
    procedure FTimerTimer(Sender: TObject);
  protected
    procedure RunLogoLabel; virtual;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    property Logo: TLabel read FLogoLabel write FlogoLabel;
    property Width: integer read FWidth write FWidth;
    property Height: integer read FHeight write FHeight;
  end;


  // PPT 재생을 관리하는 class
  TPptPlayer = class
  private
    FpptvPath: string;       // PowerPoint Viewer 실행파일이 있는 폴더
    FHandle: THandle;        // PPT 파일재생을 하는 Viewer 프로그램의 Handle
    function GetRunning: boolean;
    procedure KillViewer;
  protected
    FOnMemoOut: TMemoOutEvent;
    procedure TriggerMemoOut (msg: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run (FileName: string);
    procedure RunFiles;
    procedure Stop;
    property OnMemoOut: TMemoOutEvent read FOnMemoOut write FOnMemoOut;
    property Running: boolean read GetRunning;
  end;


  // 포항 경북과학고용: PPT를 일별로 스케줄링
  TPptScheduler = class
  private
    FOldDate: string;
    FPptPlayer: TPptPlayer;
    FTimer: TTimer;
    function GetRunning: boolean;
    procedure FTimerTimer(Sender: TObject);
    procedure RunPptSchedule;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    property Player: TPptPlayer read FPptPlayer write FPptPlayer;
    property Running: boolean read GetRunning;
  end;


  // MagicInfo 재생을 관리하는 class
  TMagicInfoPlayer = class
  private
    FUseMagicInfo: string;
    function GetRunning: boolean;
  public
    procedure Run (cmd: string);
    procedure Stop;
    property Running: boolean read GetRunning;
    property UseMagicInfo: string read FUseMagicInfo write FUseMagicInfo;
  end;


  // 앨범재생 Main Class
  TAlbum = class
  private
    Fstate: TFileKind;              // 현재 재생되고 있는 미디어 종류
    FImage: TImage;                 // 여기에 이미지를 재생한다
    FWMP: TWindowsMediaPlayer;      // 여기에 동영상을 재생한다
    FjpgTime: integer;              // 이미지를 몇초마다 넘길 것인가
    FpptTime: integer;              // PPT 파일을 얼마동안 재생할 것인가
    Fsec: integer;                  // Timer함수 진입시 1씩 증가
    FTimer: TTimer;                 // Run 함수 실행시 FTimer가 Enable됨
    FIndex: integer;                // FFileList[FIndex]로 사용
    FFileList: TFileList;           // 파일리스트
    Xdir1: TXdir;                   // PlayList 사용않을시 Xdir 활용
    logoPlayer: TLogoPlayer;
    pptPlayer: TPptPlayer;
    pptScheduler: TPptScheduler;
    miPlayer: TMagicInfoPlayer;
    scManager: TScheduleManager;
    function GetLogo: TLabel;
    procedure SetLogo(const Value: TLabel);
    function GetMagicInfo: string;
    procedure SetMagicInfo(const Value: string);
    procedure SetContentsFolder (Value: string);
    procedure TriggerMemoOut (msg: string);
    procedure TriggerAlbumState (AState: string; ARunning: boolean);
    procedure GetNextFile (var AFileItem: TFileItem);
    procedure StopMovie;
    procedure RunAlbumList (Sender: TObject); // FTimer를 Enable시킴
    procedure Timer1Timer (Sender: TObject);
  protected
    FOnMemoOut: TMemoOutEvent;      // 메모장 등에 디버깅 메세지 출력
    FOnAlbumState: TMemoOutEvent;   // 무엇을 시작했는지 운영상태를 MainForm으로 알린다
    FOnImageFile: TMemoOutEvent;    // 화면 하단에 이미지파일 이름 출력
  public
    constructor Create;
    destructor Destroy; override;
    procedure InitialLaunch;        // 프로그램 처음 실행시 적절한 초도실행
    procedure Continue;             // FTimer를 Enable시킨다. 재생중인 avi는 Play됨
    procedure Pause;                // FTimer를 Disable시킨다. 재생중인 img는 유지, avi는 Pause됨
    procedure Stop (cmd: string);   // 모든 재생을 멈추고 검은 화면을 표시한다.
    procedure RunPpt (FileName: string);    // Screen1.ppt 또는 Screen1.pptx 실행
    procedure StopPpt;
    procedure RunPptFiles;          // SEND_ADDLIST List 실행
    procedure RunPptSchedule;       // SEND_SCHEDULE List 실행
    procedure RunMagicInfo (cmd: string);   // MagicInfo Pro 또는 Premium 실행
    procedure StopMagicInfo;        // MagicInfo 종료
    procedure RunAlbum;             // SEND_ALBUM List 실행, AlbumList 읽어들여 스케줄 따라 재생시작
    procedure PlayNextFile;         // 다음 파일을 재생한다 (PlayList 또는 Xdir)
  published
    property Logo: TLabel read GetLogo write SetLogo;
    property Image: TImage read FImage write FImage;
    property WMPlayer: TWindowsMediaPlayer read FWMP write FWMP;
    property MagicInfo: string read GetMagicInfo write SetMagicInfo;
    property OnMemoOut: TMemoOutEvent read FOnMemoOut write FOnMemoOut;
    property OnAlbumState: TMemoOutEvent read FOnAlbumState write FOnAlbumState;
    property OnImageFile: TMemoOutEvent read FOnImageFile write FOnImageFile;
  end;


implementation


// ----------------------------------------------------------------
// 여기서부터 TLogoPlayer 구현함수
// ----------------------------------------------------------------

constructor TLogoPlayer.Create;
begin
    inherited Create;
    FlogoLabel:= nil;
    FWidth:= Screen.Width;
    FHeight:= Screen.Height;
    Randomize;

    FTimer:= TTimer.Create (nil);
    FTimer.Enabled:= true;
    FTimer.Interval:= 60000;
    FTimer.OnTimer:= FTimerTimer;
end;


destructor TLogoPlayer.Destroy;
begin
    FTimer.Free;
    inherited Destroy;
end;


procedure TLogoPlayer.RunLogoLabel;
begin
    // 매직게시판 로고를 화면 여기저기로 보여준다
    FlogoLabel.Hide;
    FlogoLabel.Left:= Random (FWidth - FlogoLabel.Width);
    FlogoLabel.Top:= Random (FHeight - FlogoLabel.Height);
    FlogoLabel.Font.Color:= Random ($CCCCCC);
    FlogoLabel.Show;
end;


procedure TLogoPlayer.FTimerTimer(Sender: TObject);
begin
    if (FWidth=0) or (FHeight=0) then exit;
    RunLogoLabel;
end;


procedure TLogoPlayer.Start;
begin
    FLogoLabel.Show;
    FTimer.Enabled:= true;
    // WriteLogFile ('C:\111.txt', 'TLogoPlayer.Start 들어왔음');
end;


procedure TLogoPlayer.Stop;
begin
    FTimer.Enabled:= false;
    FLogoLabel.Hide;
    // WriteLogFile ('C:\111.txt', 'TLogoPlayer.Stop 들어왔음');
end;




// ----------------------------------------------------------------
// 여기서부터 TPptScheduler 구현함수
// ----------------------------------------------------------------

constructor TPptScheduler.Create;
begin
    inherited Create;
    ShortDateFormat:= 'yyyy-mm-dd';
    FOldDate:= DateToStr (now);
    FPptPlayer:= nil;

    FTimer:= TTimer.Create (nil);
    FTimer.Enabled:= true;
    FTimer.Interval:= 60000;
    FTimer.OnTimer:= FTimerTimer;
end;


destructor TPptScheduler.Destroy;
begin
    FTimer.Free;
    inherited Destroy;
end;


function TPptScheduler.GetRunning: boolean;
begin
    Result:= FTimer.Enabled;
end;


procedure TPptScheduler.FTimerTimer(Sender: TObject);
var
    CurDate: string;
begin
    // 1분에 한번씩 여기로 들어와 날짜가 바뀌었는지 Check한다
    ShortDateFormat:= 'yyyy-mm-dd';
    CurDate:= DateToStr(now);
    if (CurDate = FOldDate) then exit;
    FOldDate:= CurDate;

    // TriggerMemoOut ('날짜가 변경되었음, 스케줄 Check중..');
    RunPptSchedule;
end;


procedure TPptScheduler.Start;
begin
    FTimer.Enabled:= true;
    RunPptSchedule;
end;


procedure TPptScheduler.Stop;
begin
    FTimer.Enabled:= false;
end;


procedure TPptScheduler.RunPptSchedule;
var
    i,j: integer;
    List: TstringList;
    s,t,fn,ext: string;
begin
    // List 파일이 존재하는지 Check
    if (FPptPlayer = nil) then exit;
    if not FileExists (FolderName+ScheduleFileName) then exit;

    // List를 읽어들인다
    List:= TStringList.Create;
    try List.LoadFromFile (FolderName+ScheduleFileName); except end;

    // 오늘 날짜로 된 string을 찾는다
    ShortDateFormat:= 'yyyy-mm-dd';
    s:= '/'+datetostr(now);
    i:= List.IndexOf(s);

    // 오늘 날짜가 없으면 직전 날짜를 찾는다
    if (i<0) then
    for j:= 1 to List.Count do begin
        t:= List[j-1];
        if (t[1] = '/') then
        if (t <= s) then i:= j-1;
    end;

    // 일단 기존의 PPT를 종료한다
    FPptPlayer.KillViewer;

    if (i < 0) then begin
        // 스케줄이 미래날짜만 있으면 i=-1임, 재생할게 없음
        // TriggerMemoOut ('아직 날짜가 안되어 재생할 파일이 없습니다')
    end
    else begin
        // 바로 다음줄에 있는 string을 가져온다
        i:= i + 1;
        if (i < List.Count) then begin
            // ppt 파일이 있으면 재생을 시작한다
            fn:= List[i];
            ext:= LowerCase (ExtractFileExt (fn));
            if (ext='.ppt') or (ext='.pptx')
            then FPptPlayer.Run (ExtractFileName (fn))
        end;
    end;

    List.Free;

    // PPT 실행여부에 따라 Logo를 보이거나 숨긴다
    // if FpptPlayer.Running then logoPlayer.Stop
    // else logoPlayer.Start;
end;





// ----------------------------------------------------------------
// 여기서부터 TPptPlayer 구현함수
// ----------------------------------------------------------------

constructor TPptPlayer.Create;
begin
    inherited Create;
    FHandle:= 0;

    // PPT Viewer 2003, 2007, 2010에 따라 실행파일 경로가 달라진다
    FpptvPath:= '';
    if FileExists (ProgramFiles+'Microsoft Office\PowerPoint Viewer\PPTVIEW.EXE') then    // 2003
    FpptvPath:=    ProgramFiles+'Microsoft Office\PowerPoint Viewer\' else
    if FileExists (ProgramFiles+'Microsoft Office\Office12\PPTVIEW.EXE') then    // 2007
    FpptvPath:=    ProgramFiles+'Microsoft Office\Office12\' else
    if FileExists (ProgramFiles+'Microsoft Office\Office14\PPTVIEW.EXE') then    // 2010
    FpptvPath:=    ProgramFiles+'Microsoft Office\Office14\';
end;


destructor TPptPlayer.Destroy;
begin
    inherited Destroy;
end;


function TPptPlayer.GetRunning: boolean;
begin
    Result:= CheckProcess ('PPTVIEW.EXE');
    // Result:= (FHandle > 32);    // KillViewer 말고 정상종료시 잘못된값 리턴
end;


procedure TPptPlayer.TriggerMemoOut(msg: string);
begin
    if Assigned (FOnMemoOut) then FOnMemoOut (msg);
end;


procedure TPptPlayer.Run (FileName: string);
begin
    // 기존 PPT Viewer 프로그램을 종료시킨다
    KillViewer;

    // ppt 또는 pptx 중에 1개만 놔두고 삭제한다
    if (FileName='Screen1.ppt') then if FileExists (FolderName+'Screen1.pptx') then DeleteFile (FolderName+'Screen1.pptx');
    if (FileName='Screen1.pptx') then if FileExists (FolderName+'Screen1.ppt') then DeleteFile (FolderName+'Screen1.ppt');

    // 새 ppt 파일로 프로그램 재시작: 아래처럼 하면 PPT Viewer 시작시 로고화면 뜬다
    // ShellExecute (0, nil, PChar('Screen1.ppt'), nil, nil, SW_NORMAL);

    // 아래와 같이 /S 옵션을 붙여주면 로고화면 없이 PPT를 띄울수 있다
    if (FpptvPath = '') then TriggerMemoOut ('PPT 뷰어 프로그램이 설치되어 있지 않습니다.')
    else if (not FileExists (FolderName+FileName)) then TriggerMemoOut ('PPT 파일이 없습니다.')
    else FHandle:= ShellExecute (0, nil, PChar(FpptvPath+'PPTVIEW.EXE'), PChar('/S /F  "' + FolderName+FileName + '"'), nil, SW_NORMAL);
end;


procedure TPptPlayer.RunFiles;
var
    i, c: integer;
    List: TstringList;
    fn, ext: string;
begin
    // List 파일이 존재하는지 Check
    if not FileExists (FolderName+AdditionalFileName) then exit;

    // List를 읽어들인다
    List:= TStringList.Create;

    try
        try
            List.LoadFromFile (FolderName+AdditionalFileName);
        except
            exit;
        end;

        c:= List.Count;
        for i:= 1 to c do begin
            // ppt 파일이 있으면 재생을 시작한다
            ext:= LowerCase (ExtractFileExt (List[i-1]));
            if (ext='.ppt') or (ext='.pptx') then begin
                // 기존 PPT Viewer 프로그램을 종료시킨다
                KillViewer;

                // 기존 ppt 파일을 대체
                // PPT 또는 PPTX 파일이 포함돼 있으면 Screen1.ppt(x)로 Rename후 재생을 한다
                fn:= ExtractFileName (List[i-1]);
                try        DeleteFile (FolderName+'Screen1'+ext);
                finally    RenameFile (FolderName+fn, FolderName+'Screen1'+ext); end;

                // PPT Viewer 프로그램을 실행시킨다
                Run ('Screen1'+ext);
                break;
            end;
        end;
    finally
        List.Free;
    end;
end;


procedure TPptPlayer.Stop;
begin
    KillViewer;
    // 기존의 PPT 관련 파일을 모조리 지운다
    DeleteFile (FolderName+'Screen1.ppt');
    DeleteFile (FolderName+'Screen1.pptx');
end;


procedure TPptPlayer.KillViewer;
begin
    if Running then
    while CheckProcess ('PPTVIEW.EXE') do begin
        KillProcess ('PPTVIEW.EXE'); Sleep(500);
    end;
    FHandle:= 0;
end;





// ----------------------------------------------------------------
// 여기서부터 TMagicInfoPlayer 구현함수
// ----------------------------------------------------------------

function TMagicInfoPlayer.GetRunning: boolean;
begin
    Result:= CheckProcess ('mnMain.exe') or CheckProcess ('MpWatcher.exe');
end;


procedure TMagicInfoPlayer.Run (cmd: string);
begin
    // 매직인포가 이미 실행중이면 나간다
    if Running then exit;
    if (cmd = 'RUN_MIP' ) then UseMagicInfo:= 'Pro';
    if (cmd = 'RUN_MIIP') then UseMagicInfo:= 'Premium';

    // 매직인포 Pro를 실행해 준다
    if (cmd = 'Pro') or (cmd = 'RUN_MIP') then
    if not CheckProcess ('mnMain.exe') then begin
        ShellExecute (0, nil, PChar(ProgramFiles+'samsung\MagicInfoPro\mnMain.exe'),
        nil, PChar(ProgramFiles+'samsung\MagicInfoPro'), SW_NORMAL);
    end else
    if not CheckProcess ('SignageScheduler.exe') then begin
        ShellExecute (0, nil, PChar(ProgramFiles+'samsung\MagicInfoPro\SignageScheduler.exe'),
        nil, PChar(ProgramFiles+'samsung\MagicInfoPro'), SW_NORMAL);
    end;

    // 매직인포i Premium을 실행해 준다
    if (cmd = 'Premium') or (cmd = 'RUN_MIIP') then
    if not CheckProcess ('MpWatcher.exe') then begin
        ShellExecute (0, nil, PChar(ProgramFiles+'MagicInfo Premium\i Player\MpWatcher.exe'),
        nil, PChar(ProgramFiles+'MagicInfo Premium\i Player'), SW_NORMAL);    // v2.0 최신버전
        ShellExecute (0, nil, PChar(ProgramFiles+'MagicInfo-i Premium\Client\MpWatcher.exe'),
        nil, PChar(ProgramFiles+'MagicInfo-i Premium\Client'), SW_NORMAL);    // v1.0 번들버전
    end;
end;


procedure TMagicInfoPlayer.Stop;
begin
    // 매직인포 Pro가 실행중이 아니라면 나간다
    // if (UseMagicInfo = 'nil') then exit;

    // 그런데 User가 직접 실행했을 수도 있다.
    // 또한 Tray에는 살아있고 ESC 눌러 바탕화면을 나왔을 수도 있다.
    // 따라서 현재상태 Check없이 무조건! 종료시킨다
    UseMagicInfo:= 'nil';

    // 매직인포 Pro를 종료시킨다
    // if (UseMagicInfo = 'Pro') then ......... 현재상태 Check하지 않고 무조건 Kill
    if CheckProcess ('mnMain.exe') then begin
        KillProcess ('mnMain.exe');
        KillProcess ('dispticker.exe');
        KillProcess ('SignageScheduler.exe');
        while CheckProcess ('mnMain.exe') do Sleep(500);
        while CheckProcess ('dispticker.exe') do Sleep(500);
        while CheckProcess ('SignageScheduler.exe') do Sleep(500);
    end;

    // 매직인포i Premium을 종료시킨다
    // if (UseMagicInfo = 'Premium') then ......... 현재상태 Check하지 않고 무조건 Kill
    if CheckProcess ('MpWatcher.exe') then begin
        KillProcess ('MpWatcher.exe');
        KillProcess ('MpAgent.exe');
        KillProcess ('MpDLAgent.exe');
        KillProcess ('MpTicker.exe');
        KillProcess ('MpPlayer.exe');
        KillProcess ('MpFileTransfer.exe');
        KillProcess ('MpDLFileTransfer.exe');
        KillProcess ('winvnc.exe');
        while CheckProcess ('MpWatcher.exe') do Sleep(500);
        while CheckProcess ('MpAgent.exe') do Sleep(500);
        while CheckProcess ('MpDLAgent.exe') do Sleep(500);
        while CheckProcess ('MpTicke.exe') do Sleep(500);
        while CheckProcess ('MpPlayer.exe') do Sleep(500);
        while CheckProcess ('MpFileTransfer.exe') do Sleep(500);
        while CheckProcess ('MpDLFileTransfer.exe') do Sleep(500);
        while CheckProcess ('winvnc.exe') do Sleep(500);
    end;

    // 매직인포에 의해 PPTVIEW가 실행되고 있다면 종료시킨다
    while CheckProcess ('PPTVIEW.EXE') do begin
        KillProcess ('PPTVIEW.EXE'); Sleep(500);
    end;
end;






// ----------------------------------------------------------------------------
// 여기서부터 TAlbum Class
// ----------------------------------------------------------------------------

function TAlbum.GetLogo: TLabel;
begin
    Result:= logoPlayer.Logo;
end;

procedure TAlbum.SetLogo(const Value: TLabel);
begin
    logoPlayer.Logo:= Value;
    logoPlayer.Start;   // 여기서 해야 한다!
end;

function TAlbum.GetMagicInfo: string;
begin
    Result:= miPlayer.UseMagicInfo;
end;

procedure TAlbum.SetMagicInfo(const Value: string);
begin
    miPlayer.UseMagicInfo:= Value;
end;


procedure TAlbum.SetContentsFolder (Value: string);
begin
    if (Value = Xdir1.StartDir) then exit;
    if (Value[length(Value)]<>'\') then Value:= Value + '\';
    Xdir1.Stop; Xdir1.StartDir:= Value;
    Fstate:= non;    // 바뀐 폴더에서 즉시 새로 시작하게 한다 (Timer1에서 처리)
end;


procedure TAlbum.TriggerMemoOut(msg: string);
begin
    if Assigned (FOnMemoOut) then FOnMemoOut (msg);
end;

procedure TAlbum.TriggerAlbumState (AState: string; ARunning: boolean);
const
    LastState: string = ' ';
begin
    // LogoPlayer는 PlayNextFile의 맨끝에서 하고 있으므로 여기서 하면 이중으로 하게됨, 따라서 주석처리
    // if ARunning then logoPlayer.Stop else logoPlayer.Start;

    // Network 부하를 줄이기 위해, State가 변경되었을 경우에만 Server로 통보한다
    if not ARunning then AState:= '';
    if (AState <> LastState) then begin
        LastState:= AState;
        if Assigned (FOnAlbumState) then FOnAlbumState (AState);
    end;
end;


constructor TAlbum.Create;
begin
    inherited Create;
    Fstate:= non;
    FIndex:= -1;
    FFileList:= TFileList.Create;

    Xdir1:= TXdir.Create (nil);
    Xdir1.Recursive:= true;
    SetContentsFolder (FolderName);

    logoPlayer:= TLogoPlayer.Create;
    // logoPlayer.Start; .....................> 여기서 하면 오류난다!!!
    pptPlayer:= TPptPlayer.Create;
    pptPlayer.OnMemoOut:= TriggerMemoOut;
    pptScheduler:= TPptScheduler.Create;
    pptScheduler.Player:= pptPlayer;
    miPlayer:= TMagicInfoPlayer.Create;
    miPlayer.UseMagicInfo:= 'nil';
    // mp:= TMediaPlayer.Create(nil);
    // mp.Visible:= false;

    // 스케줄 관리용 Class 생성
    scManager:= TScheduleManager.Create;
    scManager.OnSchedule:= RunAlbumList;
    scManager.OnMemoOut:= TriggerMemoOut;

    // FileList 하나씩 재생용
    FTimer:= TTimer.Create (nil);
    FTimer.Interval:= 1000;
    FTimer.OnTimer:= Timer1Timer;
    FTimer.Enabled:= false;
end;


destructor TAlbum.Destroy;
begin
    FTimer.Free;
    scManager.Free;

    miPlayer.Free;
    pptScheduler.Free;
    pptPlayer.Free;
    logoPlayer.Free;
    
    Xdir1.Free;
    FFileList.Free;
    inherited Destroy;
end;


procedure TAlbum.InitialLaunch;
var
    umi: string;
begin
    umi:= miPlayer.UseMagicInfo;
    // 우선순위: MagicInfo > PPT스케줄 > PPT추가파일 > Screen.pptx > AlbumFileList
    if (umi <> 'nil') then RunMagicInfo (umi)
    else if FileExists(FolderName+ScheduleFileName) then RunPptSchedule
    else if FileExists(FolderName+AdditionalFileName) then RunPptFiles
    else if FileExists(FolderName+'Screen1.ppt' ) then RunPpt ('Screen1.ppt' )
    else if FileExists(FolderName+'Screen1.pptx') then RunPpt ('Screen1.pptx')
    else RunAlbum;
end;




// ----------------------------------------------------------------------------
// 여기서부터 PPT 및 MagicInfo 재생 관련 함수
// ----------------------------------------------------------------------------

procedure TAlbum.Continue;
begin
    FTimer.Enabled:= true;
    if (FState = avi) then FWMP.controls.play;
end;

procedure TAlbum.Pause;
begin
    FTimer.Enabled:= false;
    if (FState = avi) then FWMP.controls.pause;
end;


procedure TAlbum.Stop (cmd: string);
begin
    // Stop All Players
    FTimer.Enabled:= false;
    if (Fstate = avi) then StopMovie;
    FImage.Hide;
    pptPlayer.Stop;
    pptScheduler.Stop;
    miPlayer.Stop;
    logoPlayer.Start;
    Fstate:= non;

    // 폴더내 파일을 모조리 삭제한다
    // SEND_ALBUM 명령일 경우 같은파일 또받을것 대비해서 놔둔다
    if (cmd <> 'SEND_ALBUM') then begin
        Delete_Files (AlbumFileName);
        Delete_Files (AdditionalFileName);
        Delete_Files (ScheduleFileName);
    end;
end;

procedure TAlbum.StopMovie;
begin
    // 동영상 중지후 Hide
    FWMP.close;
    FWMP.Url:= '';
    FWMP.Hide;
end;


procedure TAlbum.RunPpt (FileName: string);
begin
    pptPlayer.Run (FileName);
    TriggerAlbumState ('PPT 1개', pptPlayer.Running);
end;

procedure TAlbum.StopPpt;
begin
    pptPlayer.Stop;
    TriggerAlbumState ('', false);
end;

procedure TAlbum.RunPptFiles;
begin
    pptPlayer.RunFiles;
    TriggerAlbumState ('PPT추가파일', pptPlayer.Running);
end;

procedure TAlbum.RunPptSchedule;
begin
    pptScheduler.Start;
    TriggerAlbumState ('PPT스케줄', pptScheduler.Running);
end;


procedure TAlbum.RunMagicInfo (cmd: string);
begin
    miPlayer.Run (cmd);
    TriggerAlbumState ('매직인포', miPlayer.Running);
end;


procedure TAlbum.StopMagicInfo;
begin
    miPlayer.Stop;
    TriggerAlbumState ('', false);
end;


procedure TAlbum.RunAlbumList (Sender: TObject);
var
    i: integer;
begin
    // scManager.OnSchedule 이벤트에 의해 호출되는 함수
    if (logoPlayer.Logo = nil) then exit;
    if not Assigned(FImage) then exit;
    if not Assigned(FWMP) then exit;

    // 기존내용: AlbumFileName을 읽어들인다
    // LoadPlayList;  // 스케줄기능 없을때

    // 여기변경: scManager가 새로 생성해낸 FileList로부터 읽어들인다
    FFileList.LoadFromList (scManager.NewList);
    // 바뀐 리스트로 즉시 새로 시작하게 한다 (Timer => PlayNextFile에서 처리)
    FIndex:= -1;

    {$IFOPT D+}
    // 새로운 List를 좍한번 출력해 준다
    TriggerMemoOut ('---스케줄에 의한 새로운 AlbumList 적용');
    TriggerMemoOut (inttostr(FFileList.Count) + '개의 파일목록 사용.'#13#10);
    for i:= 1 to FFileList.Count do begin
        TriggerMemoOut (Format('[%d] %s',[i, FFileList.FileItems[i-1].FileName]));
    end;
    {$ENDIF}

    // Timer를 켜놓으면 자동으로 하나씩 실행된다
    FTimer.Enabled:= (FFileList.Count > 0);
    
    // TriggerAlbumState ('앨범재생', FTimer.Enabled); => 이렇게 하면 '파일없음' 통보를 못한다
    if (FFileList.Count > 0) then
        TriggerAlbumState ('앨범재생', true)
    else begin
        TriggerAlbumState ('파일없음', true);
        logoPlayer.Start;
    end;
end;


procedure TAlbum.RunAlbum;
begin
    // 이함수는 시작점임
    // from InitialLaunch (프로그램 시작시)
    // from ClientForm1   (파일 다운로드 완료시)

    TriggerMemoOut ('--TAlbum.RunAlbum에서 scManager.LoadFromFile 호출');
    scManager.LoadFromFile;
    // 이걸로 끝: TStringList로 읽어 내부 DB구조 구성
    // 나머지는 scManager 내부의 Timer에 의해 자동 처리된다
end;



// ----------------------------------------------------------------------------
// 여기서부터 PlayList 재생 관련 함수
// ----------------------------------------------------------------------------

procedure TAlbum.GetNextFile (var AFileItem: TFileItem);
begin
    AFileItem.FileName:= '';
    AFileItem.FileSize:= 0;
    AFileItem.PlayTime:= 0;
    if (FFileList.Count = 0) then exit;

    // PlayList에 있는 다음 항목을 갖고온다
    FIndex:= FIndex + 1;
    if (FIndex >= FFileList.Count) then FIndex:= 0;
    AFileItem.FileName:= FFileList.FileNames[FIndex];
    AFileItem.PlayTime:= FFileList.FileItems[FIndex].PlayTime;
end;


procedure TAlbum.PlayNextFile;
var
    FItem: TFileItem;
    FKind: TFileKind;
    ext: string;
begin
    // 재생할 파일이 없으면 나간다
    if (FFileList.Count = 0) then exit;

    // 파일이 1개 뿐이고 이미 재생중이면 나간다
    if (FFileList.Count = 1) then
    if (FIndex >= 0) then exit;

    // 현재상태 초기화: ppt는 무조건 죽인다. 나머지는 다음 파일에 따라 처리한다 
    // if (Fstate = avi) then StopMovie;
    if (Fstate = ppt) then pptPlayer.KillViewer;
    // Fstate:= non;    // 여기서 non 해버리면 아래 FKind에 따라 처리안됨

    // 다음 파일을 가져온다.
    GetNextFile (FItem);

    // 이상이 없는지 확인한다
    if (FItem.FileName = '') or (File_Size(FItem.FileName) < 30) then begin
        TriggerMemoOut ('잘못된 파일, List에서 제외: ' + ExtractFileName (FItem.FileName));
        // 잘못된 파일 or '404 Not Found' => 삭제해 버린다
        FFileList.DeleteFile (FItem.FileName);
        FIndex:= FIndex-1;
        logoPlayer.Start;

        if (Fstate = avi) then StopMovie;   // Fstate에 앞서 종료한다
        Fstate:= non;   // 이걸 해줘야 Timer1에서 다음 파일을 재생한다
        exit;
    end;

    // 파일의 종류 판별
    TriggerMemoOut ('PlayNextFile: ' + ExtractFileName (FItem.FileName));
    FKind:= FileKind (FItem.FileName);

    // Server로 Album State를 ext로 통보
    ext:= UpperCase (ExtractFileExt (FItem.FileName));
    if (ext[1]='.') then Delete (ext, 1, 1);

    // 이미지 파일인 경우
    if (FKind = img) then begin
        if (Fstate = avi) then StopMovie;
        Fstate:= img;
        Fsec:= 0;
        if (FItem.PlayTime > 0) then FjpgTime:= FItem.PlayTime else FjpgTime:= 5;
        FImage.Show;

        try
            FImage.Picture.LoadFromFile (FItem.FileName);
            if Assigned (FOnImageFile) then FOnImageFile (ExtractFileName (FItem.FileName));
         // TriggerAlbumState (ext, FImage.Visible);    // Server로 상태통보
            TriggerAlbumState (ext+' 재생', true);
        except
            TriggerMemoOut ('파일오류: ' + ExtractFileName (FItem.FileName));
            FImage.Hide;
            FState:= non;
            FjpgTime:= 0;
        end;
    end

    // PowerPoint 파일인 경우
    else if (FKind = ppt) then begin
        if (Fstate = avi) then StopMovie;
        FState:= ppt;
        FImage.Hide;
        Fsec:= 0;
        if (FItem.PlayTime > 0) then FpptTime:= FItem.PlayTime else FpptTime:= 60;

        // PPT Viewer를 실행해 준다. 실행오류시 바로 Skip시킨다
        pptPlayer.Run (ExtractFileName (FItem.FileName));
        if pptPlayer.Running then Fstate:= ppt else FpptTime:= 1;
        TriggerAlbumState (ext+' 재생', pptPlayer.Running);     // Server로 상태통보
    end

    // 동영상 파일인 경우
    else if (FKind = avi) then begin
        Fstate:= avi;
        FImage.Hide;
        FWMP.Show;

        // 파일이 1개 뿐이라면 무한반복하고 아니면 1회만 재생한다
        if (FFileList.Count = 1) then FWMP.settings.setMode('loop', true)
        else FWMP.settings.setMode('loop', false);

        FWMP.URL:= FItem.FileName;    // 자동재생
     // FWMP.controls.play;

        TriggerAlbumState (ext+' 재생', true);
     // TriggerAlbumState (ext, FWMP.playState=wmppsPlaying);
    end

    // 재생할 파일이 없다
    else Fstate:= non;

    // 현재 재생상태에 따라 Logo를 보이거나 숨긴다
    if (Fstate = non) then logoPlayer.Start
    else logoPlayer.Stop;
end;


procedure TAlbum.Timer1Timer (Sender: TObject);
const
    lastState: WMPPlayState = wmppsUndefined;
begin
    // 여긴 1초마다 들어와서 필요한 일을 처리한다
    Fsec:= Fsec + 1;

    // 처음 들어온 상태라면 다음파일 재생
    if (Fstate = non) then PlayNextFile;

    // 그림을 보여주고 있노라면 재생시간(기본5초) 경과후 다음파일 재생
    if (Fstate = img) then
    if (Fsec > FjpgTime) then PlayNextFile;

    // 영상을 보여주고 있노라면 다 재생후 다음파일 재생
    if (Fstate = avi) then
    if (lastState <> FWMP.playState) then begin
        // 상태가 바뀐 경우에만 처리
        lastState:= FWMP.playState;
        if (FWMP.playState = wmppsStopped) then PlayNextFile;
    end;

    // PPT를 보여주고 있노라면 필요시간 재생후 다음파일 재생
    if (Fstate = ppt) then
    if (pptPlayer.Running = false) or (Fsec > FpptTime) then PlayNextFile;
end;

end.

