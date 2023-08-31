unit FileList;

interface

uses
  SysUtils, Classes, Math, Globals, BlankUtils;

type
  TFileList = class (TList)
  private
    FJpgTime: integer;
    function GetPFileItem (i: integer): PFileItem;
    function GetFileItem (i: integer): TFileItem;
    function GetFileName(i: integer): string;
    procedure SetFileName(i: integer; const Value: string);
  public
    procedure Clear; override;
    procedure AddFile (AFileName: string);
    procedure DeleteItem (Index: Integer);
    procedure LoadFromFile (AFileName: string);
    function FindItem (AFileName: string): integer;
    property JpgTime: integer read FJpgTime;
    property PFileItems[i: integer]: PFileItem read GetPFileItem;
    property FileItems[i: integer]: TFileItem read GetFileItem;
    property FileNames[i: integer]: string read GetFileName write SetFileName;
  end;

implementation

procedure TFileList.Clear;
var
    i: integer;
    p: PFileItem;
begin
    for i:= 1 to Count do begin
        p:= Items[i-1];
        Dispose (p);
    end;
    inherited Clear;
end;

function TFileList.GetFileItem (i: integer): TFileItem;
var
    p: PFileItem;
begin
    p:= Items[i];
    Result:= p^;
end;

function TFileList.GetPFileItem(i: integer): PFileItem;
begin
    Result:= Items[i];
end;

function TFileList.GetFileName(i: integer): string;
begin
    if (i < 0) or (i >= Count) then Result:= ''
    else Result:= PFileItem(Items[i])^.FileName;
end;

procedure TFileList.SetFileName(i: integer; const Value: string);
begin
    if (i < 0) or (i >= Count) then exit;
    PFileItem(Items[i])^.FileName:= Value;
end;

procedure TFileList.AddFile (AFileName: string);
var
    p: PFileItem;
begin
    // 파일에 해당하는 FileItem을 만들어 List에 추가한다
    if not FileExists (AFileName) then exit;
    New (p);
    p^.FileName:= AFileName;
    p^.FileSize:= Math.Max (0, File_Size(AFileName));
    p^.DateTime:= FileAge (AFileName);
    p^.PlayTime:= 0;
    p^.GroupNode:= nil;
    Add (p);
end;

procedure TFileList.DeleteItem (Index: Integer);
var
    p: PFileItem;
begin
    p:= Items[Index];
    Dispose (p);
    Delete (Index);
end;

procedure TFileList.LoadFromFile (AFileName: string);
var
    i: integer;
    s: string;
    st: TStringList;
    p: PFileItem;
begin
    // 저장된 List가 있으면 불러온다
    if not FileExists (AFileName) then exit;
    st:= TStringList.Create;

    try
        st.LoadFromFile (AFileName);
        if (st.Count <= 1 ) then exit;

        // 맨첫줄은 JPG 재생시간
        FJpgTime:= 0;
        if (pos('/JpgTime=', st[0]) = 1) then begin
            s:= st[0];
            s:= Copy (s, pos('=',s), 99);
            FJpgTime:= strtoint32 (s, 5);
            st.Delete (0);
        end;

        // 파일을 하나씩 가져오면서 List에 Add한다 ------------- 스케줄 관련 수정할것
        for i:= 1 to st.Count do
        if (i mod 4 = 1) then begin
            New (p);
            p^.FileName:= st[i-1];
            p^.FileSize:= strtoint64 (st[i], 0);
            p^.DateTime:= strtoint32 (st[i+1], 0);
            p^.PlayTime:= strtoint32 (st[i+2], 0);
            Add (p);

            // 이미지파일 기본재생시간 설정
            if (FileKind(p^.FileName) = img) then
            if (p^.PlayTime = 0) then
            p^.PlayTime:= FJpgTime;
        end;
    finally
        st.Free;
    end;
end;

function TFileList.FindItem (AFileName: string): integer;
var
    i: integer;
    p: PFileItem;
begin
    // AFileName에 해당하는 FileItem이 List에 있는지 뒤져 Index를 Return
    Result:= -1;
    for i:= 1 to Count do begin
        p:= Items[i-1];
        if (p^.FileName = AFileName) then begin
            Result:= i-1;
            exit;
        end;
    end;
end;

end.

