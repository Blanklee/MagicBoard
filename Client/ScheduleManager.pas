unit ScheduleManager;

interface

uses
  Windows, SysUtils, Classes, ExtCtrls, BlankUtils, Globals, FileList;

type
  // 스케줄 관리용 Class
  TMemoOutEvent = procedure (msg: string) of object;
  TEverySecondEvent = procedure (CurDate, CurTime: string) of object;

  PScheduleItem = ^TScheduleItem;
  TScheduleItem = record
    DateTime: string;
    FileList: TFileList;
  end;

  TScheduleList = class (TList)
  private
    function GetDateTime(i: integer): string;
    function GetFileList(i: integer): TFileList;
  public
    procedure Clear; override;
    procedure DeleteItem (Index: Integer);
    property DateTime[i: integer]: string read GetDateTime;
    property FileList[i: integer]: TFileList read GetFileList;
  end;

  TScheduleManager = class
  private
    Timer1: TTimer;
    Timer11: TTimer;
    CurDate: string;	// 년월일
    CurTime: string;	// 시분
    CurIndex: integer;
    InSchedule: boolean;
    FFileList: TFileList;
    FScheduleList: TScheduleList;
    procedure Timer1Timer (Sender: TObject);
    procedure Timer11Timer (Sender: TObject);
    procedure GetCurrentTime;
  protected
    FOnMemoOut: TMemoOutEvent;
    FOnEverySecond: TEverySecondEvent;
    FOnEverySecond11: TNotifyEvent;
    FOnSchedule: TNotifyEvent;
    procedure TriggerMemoOut (msg: string);
    procedure TriggerEverySecond (CurDate, CurTime: string);
    procedure TriggerEverySecond11 (Sender: TObject);
    procedure TriggerSchedule (Sender: TObject);
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadFromFile;
  published
    property NewList: TFileList read FFileList;
    property OnMemoOut: TMemoOutEvent read FOnMemoOut write FOnMemoOut;
    property OnEverySecond: TEverySecondEvent read FOnEverySecond write FOnEverySecond;
    property OnEverySecond11: TNotifyEvent read FOnEverySecond11 write FOnEverySecond11;
    property OnSchedule: TNotifyEvent read FOnSchedule write FOnSchedule;
  end;


implementation


// ----------------------------------------------------------------
// 여기서부터 TScheduleList 함수
// ----------------------------------------------------------------

procedure TScheduleList.Clear;
var
    i: integer;
    p: PScheduleItem;
begin
    for i:= 1 to Count do begin
        p:= Items[i-1];
        p^.FileList.Free;
        Dispose (p);
    end;
    inherited Clear;
end;


procedure TScheduleList.DeleteItem(Index: Integer);
var
    p: PScheduleItem;
begin
    p:= Items[Index];
    p^.FileList.Free;
    Dispose (p);
    Delete (Index);
end;


function TScheduleList.GetDateTime(i: integer): string;
var
    p: PScheduleItem;
begin
    p:= Items[i];
    Result:= p^.DateTime;
end;


function TScheduleList.GetFileList(i: integer): TFileList;
var
    p: PScheduleItem;
begin
    p:= Items[i];
    Result:= p^.FileList;
end;



// ----------------------------------------------------------------
// 여기서부터 TScheduleManager Event 형식함수
// ----------------------------------------------------------------

procedure TScheduleManager.TriggerMemoOut (msg: string);
begin
    if Assigned (FOnMemoOut) then FOnMemoOut (msg);
end;

procedure TScheduleManager.TriggerEverySecond (CurDate, CurTime: string);
begin
    if Assigned (FOnEverySecond) then FOnEverySecond (CurDate, CurTime);
end;

procedure TScheduleManager.TriggerEverySecond11 (Sender: TObject);
begin
    if Assigned (FOnEverySecond11) then FOnEverySecond11 (Sender);
end;

procedure TScheduleManager.TriggerSchedule (Sender: TObject);
begin
    if Assigned (FOnSchedule) then FOnSchedule (Self);
end;




// ----------------------------------------------------------------
// 여기서부터 TScheduleManager 초기화 함수
// ----------------------------------------------------------------

constructor TScheduleManager.Create;
begin
    inherited Create;

    ShortDateFormat:= 'yyyy.mm.dd';
    CurDate:= '';
    CurTime:= '';
    CurIndex:= 0;
    InSchedule:= false;

    // 스케줄 및 재생목록
    FFileList:= TFileList.Create;
    FScheduleList:= TScheduleList.Create;

    // 매1초마다 들어오는 Timer
    Timer1:= TTimer.Create (nil);
    Timer1.Enabled:= false;
    Timer1.Interval:= 1000;
    Timer1.OnTimer:= Timer1Timer;

    // 매11초마다 들어오는 Timer
    Timer11:= TTimer.Create (nil);
    Timer11.Enabled:= false;
    Timer11.Interval:= 11000;
    Timer11.OnTimer:= Timer11Timer;
end;


destructor TScheduleManager.Destroy;
begin
    Timer1.Free;
    Timer11.Free;
    FScheduleList.Free;
    FFileList.Free;
    inherited Destroy;
end;





// ----------------------------------------------------------------
// 여기서부터 TScheduleManager 내부 함수
// ----------------------------------------------------------------

procedure TScheduleManager.LoadFromFile;
var
    i: integer;
    s: string;
    st: TStringList;
    ps: PScheduleItem;
    pf: PFileItem;
begin
    // 초기화 및 파일확인
    Timer1.Enabled:= false;
    Timer11.Enabled:= false;
    FScheduleList.Clear;
    FFileList.Clear;
    CurIndex:= 0;
    if not File_Exists (FolderName+AlbumFileName) then exit;

    // AlbumList File로부터 읽어들여 내부 DB구조 구성한다
    st:= TStringList.Create;
    try
        st.LoadFromFile(FolderName+AlbumFileName);
        if (st.Count < 4) then exit;
        TriggerMemoOut (AlbumFileName + ' 읽기시작, ' + inttostr(st.Count) + '줄');

        // 기본재생 목록
        New (ps);
        ps^.DateTime:= '0';
        ps^.FileList:= TFileList.Create;
        FScheduleList.Add (ps);

        // 파일을 하나씩 가져오면서 실제 파일정보로 Update한다
        repeat
            s:= trim(st[0]); st.Delete(0);
            if (s[1]='/') then continue

            // '날짜+시간' 형태로 저장: [2014.05.01 09:30]
            else if (s[1]='[') then begin
                New (ps);
                ps^.DateTime:= s;
                ps^.FileList:= TFileList.Create;
                FScheduleList.Add (ps);
            end

            // 재생가능한 파일만 담는다
            else if FileKind(s) = non then continue

            // 파일정보를 FileList에 추가
            else begin
                New (pf);
                // 절대경로를 Client에 맞게 변경
                pf^.FileName:= FolderName + ExtractFileName(s);
                pf^.FileSize:= File_Size (s, 0);
                pf^.DateTime:= File_Age (s);
                pf^.PlayTime:= strtoint32 (st[2], 0);
                ps^.FileList.Add (pf);

                // 처리 완료된 정보는 삭제해 버린다
                st.Delete(0);
                st.Delete(0);
                st.Delete(0);
            end;
        until (st.Count = 0);
    finally
        st.Free;
    end;

    // FileList 항목이 하나도 없는 것들은 날려버린다 (기본스케줄 제외)
    for i:= FScheduleList.Count-1 downto 1 do
        if (FScheduleList.FileList[i].Count = 0) then
        FScheduleList.DeleteItem (i);

    // 즉시 스케줄 검사를 한번 해준다, 스캐줄 해당시 목록 재작성
    TriggerMemoOut (AlbumFileName + ' 읽기완료, ' + inttostr(FScheduleList.Count) + '개의 스케줄');
    Timer11Timer (Self);

    // 기본목록만 있다면 그걸로 재생한다 (Timer11에서 처리안됐음)
    if (FFileList.Count = 0) then begin
        TriggerMemoOut ('--기본목록만 있어 기본목록 적용');
        FFileList.LoadFromList (FScheduleList.FileList[0]);
        // Event를 발생시켜 기본목록을 적용하게 해준다
        TriggerSchedule (Self);
    end;

    // 이제부터 Timer를 통해 스케줄을 계속 검사한다
    if (FScheduleList.Count > 1) then begin
        TriggerMemoOut ('--스케줄이 1개이상 존재, Timer로 Check 시작..');
        Timer1.Enabled:= true;
        Timer11.Enabled:= true;
    end;
end;


procedure TScheduleManager.GetCurrentTime;
var
    MyNow: TDateTime;
begin
    MyNow:= now;

    // 현재 날짜를 표시해 준다.
    ShortDateFormat:= 'yyyy.mm.dd';
    CurDate:= datetostr (MyNow);

    // 현재 시각을 표시해 준다.
    // ShortDateFormat:= 'hh:nn:ss';
    ShortDateFormat:= 'hh:nn';
    CurTime:= datetostr (MyNow);
end;


procedure TScheduleManager.Timer1Timer (Sender: TObject);
begin
    // 단순히 MainForm에서 현재시간을 초단위로 표시해줄 용도로 활용
    GetCurrentTime;
    TriggerEverySecond (CurDate, CurTime);
end;


procedure TScheduleManager.Timer11Timer (Sender: TObject);
var
    CurDateTime: string;
    i,j: integer;
begin
    // 현재 날짜/시간이 Schedule에 해당하면 Event 발생

    // 현재 날짜/시간을 갖고온다.
    GetCurrentTime;
    CurDateTime:= '['+CurDate+' '+CurTime+']';
    TriggerEverySecond11 (Sender);

    // 현재 or 직전까지 찾아온다, 기본목록 제외
    j:= 0;
    for i:= 1 to FScheduleList.Count-1 do begin
        if (FScheduleList.DateTime[i] <= CurDateTime)
        then j:= i
        else break;
    end;

    // 디버그용 값출력
    // TriggerMemoOut ('Timer11: j='+inttostr(j)+', CurIndex='+inttostr(CurIndex));

    if (j > CurIndex) then begin
        // 더이상 필요없는 과거목록은 삭제해 버린다
        for i:= j-1 downto 1 do FScheduleList.DeleteItem (i);
        CurIndex:= 1;

        // 새로운 List를 만든다 = 기본목록 + 새목록
        FFileList.Clear;
        FFileList.LoadFromList (FScheduleList.FileList[0]);
        FFileList.AddList (FScheduleList.FileList[1]);

        // Event를 발생시켜 새로운 List를 적용하게 해준다
        TriggerSchedule (Self);
    end;
end;

end.

