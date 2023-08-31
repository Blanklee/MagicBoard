unit ScheduleManager;

interface

uses
  Windows, SysUtils, Classes, ExtCtrls, BlankUtils, Globals, FileList;

type
  // ������ ������ Class
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
    CurDate: string;	// �����
    CurTime: string;	// �ú�
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
// ���⼭���� TScheduleList �Լ�
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
// ���⼭���� TScheduleManager Event �����Լ�
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
// ���⼭���� TScheduleManager �ʱ�ȭ �Լ�
// ----------------------------------------------------------------

constructor TScheduleManager.Create;
begin
    inherited Create;

    ShortDateFormat:= 'yyyy.mm.dd';
    CurDate:= '';
    CurTime:= '';
    CurIndex:= 0;
    InSchedule:= false;

    // ������ �� ������
    FFileList:= TFileList.Create;
    FScheduleList:= TScheduleList.Create;

    // ��1�ʸ��� ������ Timer
    Timer1:= TTimer.Create (nil);
    Timer1.Enabled:= false;
    Timer1.Interval:= 1000;
    Timer1.OnTimer:= Timer1Timer;

    // ��11�ʸ��� ������ Timer
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
// ���⼭���� TScheduleManager ���� �Լ�
// ----------------------------------------------------------------

procedure TScheduleManager.LoadFromFile;
var
    i: integer;
    s: string;
    st: TStringList;
    ps: PScheduleItem;
    pf: PFileItem;
begin
    // �ʱ�ȭ �� ����Ȯ��
    Timer1.Enabled:= false;
    Timer11.Enabled:= false;
    FScheduleList.Clear;
    FFileList.Clear;
    CurIndex:= 0;
    if not File_Exists (FolderName+AlbumFileName) then exit;

    // AlbumList File�κ��� �о�鿩 ���� DB���� �����Ѵ�
    st:= TStringList.Create;
    try
        st.LoadFromFile(FolderName+AlbumFileName);
        if (st.Count < 4) then exit;
        TriggerMemoOut (AlbumFileName + ' �б����, ' + inttostr(st.Count) + '��');

        // �⺻��� ���
        New (ps);
        ps^.DateTime:= '0';
        ps^.FileList:= TFileList.Create;
        FScheduleList.Add (ps);

        // ������ �ϳ��� �������鼭 ���� ���������� Update�Ѵ�
        repeat
            s:= trim(st[0]); st.Delete(0);
            if (s[1]='/') then continue

            // '��¥+�ð�' ���·� ����: [2014.05.01 09:30]
            else if (s[1]='[') then begin
                New (ps);
                ps^.DateTime:= s;
                ps^.FileList:= TFileList.Create;
                FScheduleList.Add (ps);
            end

            // ��������� ���ϸ� ��´�
            else if FileKind(s) = non then continue

            // ���������� FileList�� �߰�
            else begin
                New (pf);
                // �����θ� Client�� �°� ����
                pf^.FileName:= FolderName + ExtractFileName(s);
                pf^.FileSize:= File_Size (s, 0);
                pf^.DateTime:= File_Age (s);
                pf^.PlayTime:= strtoint32 (st[2], 0);
                ps^.FileList.Add (pf);

                // ó�� �Ϸ�� ������ ������ ������
                st.Delete(0);
                st.Delete(0);
                st.Delete(0);
            end;
        until (st.Count = 0);
    finally
        st.Free;
    end;

    // FileList �׸��� �ϳ��� ���� �͵��� ���������� (�⺻������ ����)
    for i:= FScheduleList.Count-1 downto 1 do
        if (FScheduleList.FileList[i].Count = 0) then
        FScheduleList.DeleteItem (i);

    // ��� ������ �˻縦 �ѹ� ���ش�, ��ĳ�� �ش�� ��� ���ۼ�
    TriggerMemoOut (AlbumFileName + ' �б�Ϸ�, ' + inttostr(FScheduleList.Count) + '���� ������');
    Timer11Timer (Self);

    // �⺻��ϸ� �ִٸ� �װɷ� ����Ѵ� (Timer11���� ó���ȵ���)
    if (FFileList.Count = 0) then begin
        TriggerMemoOut ('--�⺻��ϸ� �־� �⺻��� ����');
        FFileList.LoadFromList (FScheduleList.FileList[0]);
        // Event�� �߻����� �⺻����� �����ϰ� ���ش�
        TriggerSchedule (Self);
    end;

    // �������� Timer�� ���� �������� ��� �˻��Ѵ�
    if (FScheduleList.Count > 1) then begin
        TriggerMemoOut ('--�������� 1���̻� ����, Timer�� Check ����..');
        Timer1.Enabled:= true;
        Timer11.Enabled:= true;
    end;
end;


procedure TScheduleManager.GetCurrentTime;
var
    MyNow: TDateTime;
begin
    MyNow:= now;

    // ���� ��¥�� ǥ���� �ش�.
    ShortDateFormat:= 'yyyy.mm.dd';
    CurDate:= datetostr (MyNow);

    // ���� �ð��� ǥ���� �ش�.
    // ShortDateFormat:= 'hh:nn:ss';
    ShortDateFormat:= 'hh:nn';
    CurTime:= datetostr (MyNow);
end;


procedure TScheduleManager.Timer1Timer (Sender: TObject);
begin
    // �ܼ��� MainForm���� ����ð��� �ʴ����� ǥ������ �뵵�� Ȱ��
    GetCurrentTime;
    TriggerEverySecond (CurDate, CurTime);
end;


procedure TScheduleManager.Timer11Timer (Sender: TObject);
var
    CurDateTime: string;
    i,j: integer;
begin
    // ���� ��¥/�ð��� Schedule�� �ش��ϸ� Event �߻�

    // ���� ��¥/�ð��� ����´�.
    GetCurrentTime;
    CurDateTime:= '['+CurDate+' '+CurTime+']';
    TriggerEverySecond11 (Sender);

    // ���� or �������� ã�ƿ´�, �⺻��� ����
    j:= 0;
    for i:= 1 to FScheduleList.Count-1 do begin
        if (FScheduleList.DateTime[i] <= CurDateTime)
        then j:= i
        else break;
    end;

    // ����׿� �����
    // TriggerMemoOut ('Timer11: j='+inttostr(j)+', CurIndex='+inttostr(CurIndex));

    if (j > CurIndex) then begin
        // ���̻� �ʿ���� ���Ÿ���� ������ ������
        for i:= j-1 downto 1 do FScheduleList.DeleteItem (i);
        CurIndex:= 1;

        // ���ο� List�� ����� = �⺻��� + �����
        FFileList.Clear;
        FFileList.LoadFromList (FScheduleList.FileList[0]);
        FFileList.AddList (FScheduleList.FileList[1]);

        // Event�� �߻����� ���ο� List�� �����ϰ� ���ش�
        TriggerSchedule (Self);
    end;
end;

end.

