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
    // ���Ͽ� �ش��ϴ� FileItem�� ����� List�� �߰��Ѵ�
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
    // AFileName�� �ش��ϴ� Item�� ��� Delete�Ѵ�
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
    // 1�� �׸��� 4�ٷ� ������ ListFile�κ��� �о���δ�
    // �������� �����ϰ� �����ϰ� ���� ��ϸ� �о���δ�
    if not FileExists (AFileName) then exit;
    st:= TStringList.Create;

    try
        st.LoadFromFile (AFileName);
        if (st.Count <= 1) then exit;

        // �������� Line�� �����Ѵ�
        for i:= st.Count downto 1 do
        if (st[i-1][1] in ['/','[','(']) then st.Delete(i-1);

        // ������ �ϳ��� FileItem���� �������鼭 List�� Add�Ѵ�
        for i:= 1 to st.Count do
        if (i mod 4 = 1) then begin
            New (p);
            p^.FileName:= st[i-1];
            p^.FileSize:= strtoint64 (st[i], 0);
            p^.DateTime:= strtoint32 (st[i+1], 0);
            p^.PlayTime:= strtoint32 (st[i+2], 0);
            Add (p);

            // �̹������� �⺻����ð� ����
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
    // ���� 1�ٿ� 1���� ���ϸ� �ִ� TStringList ���Ϸκ��� �о�´�
    // TGetFilesClient���� PPT+�߰�����, PPT+���������� ȣȯ���� ���� ����
    if not FileExists (AFileName) then exit;
    st:= TStringList.Create;

    try
        // ������ �ϳ��� �������鼭 List�� Add�Ѵ�
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
    // �ٸ� FileList�� �״�� ������ �´�

    // ���� ����� AddList �Ѵ�
    Clear;
    AddList (AList);
end;

procedure TFileList.AddList(AList: TFileList);
var
    i: integer;
    p, q: PFileItem;
begin
    // ���� List�� �߰��� AList�� �����δ�
    for i:= 1 to AList.Count do begin
        // �ϳ��� Copy�ؼ� Add�Ѵ�
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
    // �����̸�, ����ũ�Ⱑ �ٸ��� �ٸ���
    if (p1^.FileSize <> p2^.FileSize) then exit;
    if (ExtractFileName(p1^.FileName) <> ExtractFileName(p2^.FileName)) then exit;

    // �ð��� 2���̻� ���̳��� �ٸ���
    a1:= p1^.DateTime;
    a2:= p2^.DateTime;
    if (a1=0) or (a2=0) or (Abs(a2-a1) > 2) then exit;

    // ������� ���� ������ ����
    Result:= true;
end;

end.

