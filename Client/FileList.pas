unit FileList;

interface

uses
  SysUtils, Classes, Globals, BlankUtils;

type
  TFileList = class (TList)
  private
    function GetFileItem (i: integer): TFileItem;
    function GetFileName(i: integer): string;
    procedure SetFileName(i: integer; const Value: string);
  public
    procedure Clear; override;
    procedure AddFile (AFileName: string);
    procedure DeleteFile (AFileName: string);
    procedure LoadFromFile (AFileName: string);
    procedure LoadFromSimple (AFileName: string);
    procedure LoadFromList (AList: TFileList);
    procedure AddList (AList: TFileList);
    class function FileItemSame (p1, p2: PFileItem): boolean;
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
    New (p);
    p^.FileName:= AFileName;
    p^.PlayTime:= 0;
    Add (p);

    if File_Exists (AFileName) then begin
        p^.FileSize:= File_Size (AFileName, 0);
        p^.DateTime:= File_Age (AFileName);
    end else begin
        p^.FileSize:= 0;
        p^.DateTime:= 0;
    end;
end;

procedure TFileList.DeleteFile (AFileName: string);
var
    i: integer;
    p: PFileItem;
begin
    // AFileName에 해당하는 Item을 모두 Delete한다
    for i:= Count downto 1 do begin
        p:= Items[i-1];
        if (p^.FileName = AFileName) then Delete (i-1);
    end;
end;

procedure TFileList.LoadFromFile (AFileName: string);
var
    i: integer;
    st: TStringList;
    p: PFileItem;
begin
    // 1개 항목이 4줄로 구성된 ListFile로부터 읽어들인다
    // 스케줄은 무시하고 순수하게 파일 목록만 읽어들인다
    if not FileExists (AFileName) then exit;
    st:= TStringList.Create;

    try
        st.LoadFromFile (AFileName);
        if (st.Count <= 1) then exit;

        // 쓸데없는 Line을 제거한다
        for i:= st.Count downto 1 do
        if (st[i-1][1] in ['/','[','(']) then st.Delete(i-1);

        // 파일을 하나씩 FileItem으로 가져오면서 List에 Add한다
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
            if (p^.PlayTime = 0) then p^.PlayTime:= 5;
        end;
    finally
        st.Free;
    end;
end;

procedure TFileList.LoadFromSimple (AFileName: string);
var
    i: integer;
    st: TStringList;
begin
    // 기존 1줄에 1개의 파일명만 있는 TStringList 파일로부터 읽어온다
    // TGetFilesClient에서 PPT+추가파일, PPT+스케줄파일 호환성을 위한 것임
    if not FileExists (AFileName) then exit;
    st:= TStringList.Create;

    try
        // 파일을 하나씩 가져오면서 List에 Add한다
        st.LoadFromFile (AFileName);
        // ShowMessage ('st.Count = ' + inttostr(st.Count));
        if (st.Count > 0) then
        for i:= 1 to st.Count do
        if not (st[i-1][1] in ['/','[','(']) then
        AddFile (st[i-1]);
    finally
        st.Free;
    end;
end;

procedure TFileList.LoadFromList(AList: TFileList);
begin
    // 다른 FileList를 그대로 복사해 온다

    // 몽땅 비운후 AddList 한다
    Clear;
    AddList (AList);
end;

procedure TFileList.AddList(AList: TFileList);
var
    i: integer;
    p, q: PFileItem;
begin
    // 현재 List에 추가로 AList를 덧붙인다
    for i:= 1 to AList.Count do begin
        // 하나씩 Copy해서 Add한다
        p:= AList[i-1];
        new (q);
        Add (q);
        q^:= p^;
    end;
end;

class function TFileList.FileItemSame (p1, p2: PFileItem): boolean;
var
    a1, a2: integer;
begin
    Result:= false;
    // 파일이름, 파일크기가 다르면 다르다
    if (p1^.FileSize <> p2^.FileSize) then exit;
    if (ExtractFileName(p1^.FileName) <> ExtractFileName(p2^.FileName)) then exit;

    // 시간이 2초이상 차이나면 다르다
    a1:= p1^.DateTime;
    a2:= p2^.DateTime;
    if (a1=0) or (a2=0) or (Abs(a2-a1) > 2) then exit;

    // 여기까지 오면 두파일 같다
    Result:= true;
end;

end.

