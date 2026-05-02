#Requires -Version 5.1
<#
.SYNOPSIS
    KPatcher PowerShell - Pure PowerShell port of KPatcher for KOTOR mod installation.
.DESCRIPTION
    Reads/writes BioWare Aurora engine formats: GFF, 2DA, TLK, ERF, RIM, SSF.
    Parses TSLPatcher changes.ini configs and applies mod patches.
    Zero external dependencies.
#>

Set-StrictMode -Version Latest

#region ===== Enums and Constants =====

enum GFFFieldType {
    UInt8  = 0
    Int8   = 1
    UInt16 = 2
    Int16  = 3
    UInt32 = 4
    Int32  = 5
    UInt64 = 6
    Int64  = 7
    Single = 8
    Double = 9
    String = 10
    ResRef = 11
    LocalizedString = 12
    Binary = 13
    Struct = 14
    List   = 15
    Vector4 = 16
    Vector3 = 17
}

enum GFFContent {
    GFF; BIC; UTC; UTI; UTP; UTM; UTS; UTT; UTW; UTD; UTE
    ARE; DLG; GIT; IFO; JRL; PTH; FAC; GUI; INV; PT; GVT; NFO
}

enum ERFType { ERF; MOD }

enum SSFSound {
    BATTLE_CRY_1 = 0;  BATTLE_CRY_2 = 1;  BATTLE_CRY_3 = 2
    BATTLE_CRY_4 = 3;  BATTLE_CRY_5 = 4;  BATTLE_CRY_6 = 5
    SELECT_1 = 6;      SELECT_2 = 7;       SELECT_3 = 8
    ATTACK_GRUNT_1 = 9; ATTACK_GRUNT_2 = 10; ATTACK_GRUNT_3 = 11
    PAIN_GRUNT_1 = 12; PAIN_GRUNT_2 = 13;  LOW_HEALTH = 14
    DEAD = 15;         CRITICAL_HIT = 16;  TARGET_IMMUNE = 17
    LAY_MINE = 18;     DISARM_MINE = 19;   BEGIN_STEALTH = 20
    BEGIN_SEARCH = 21; BEGIN_UNLOCK = 22;   UNLOCK_FAILED = 23
    UNLOCK_SUCCESS = 24; SEPARATED_FROM_PARTY = 25
    REJOINED_PARTY = 26; POISONED = 27
}

enum KLanguage {
    English = 0; French = 1; German = 2; Italian = 3; Spanish = 4
    Polish = 5; Korean = 128; ChineseTraditional = 129; ChineseSimplified = 130
    Japanese = 131
}

enum Gender { Male = 0; Female = 1 }

#endregion

#region ===== ResourceType =====

class ResourceType {
    [int]    $TypeId
    [string] $Extension
    [string] $Category

    ResourceType([int]$id, [string]$ext, [string]$cat) {
        $this.TypeId    = $id
        $this.Extension = $ext
        $this.Category  = $cat
    }

    [bool] Equals([object]$other) {
        if ($other -is [ResourceType]) { return $this.TypeId -eq $other.TypeId }
        return $false
    }
    [int] GetHashCode() { return $this.TypeId }
    [string] ToString() { return $this.Extension }

    static [hashtable] $_map = $null

    static [void] _Init() {
        if ([ResourceType]::_map) { return }
        [ResourceType]::_map = @{}
        $defs = @(
            @(0,    'res',  'Misc'),   @(1,    'bmp',  'Image'),  @(2,    'mve',  'Video')
            @(3,    'tga',  'Image'),  @(4,    'wav',  'Audio'),  @(6,    'plt',  'Image')
            @(7,    'ini',  'Text'),   @(8,    'mp3',  'Audio'),  @(9,    'mpg',  'Video')
            @(10,   'txt',  'Text'),   @(2000, 'lyt',  'Text'),   @(2001, 'vis',  'Text')
            @(2002, 'rim',  'Archive'),@(2003, 'pth',  'GFF'),    @(2005, 'lip',  'Misc')
            @(2007, 'bwm',  'Model'), @(2008, 'txb',  'Texture'),@(2009, 'tpc',  'Texture')
            @(2010, 'mdx',  'Model'), @(2011, 'rsv',  'Misc'),   @(2012, 'sig',  'Misc')
            @(2013, 'xbx',  'Misc'),  @(2022, 'env',  'Misc'),   @(2023, 'cbx',  'Misc')
            @(2024, 'shd',  'Shader'),@(2025, 'wfx',  'Misc'),   @(2029, 'ltr',  'Misc')
            @(2030, 'gff',  'GFF'),   @(2031, 'fac',  'GFF'),    @(2032, 'nte',  'GFF')
            @(2033, 'utc',  'GFF'),   @(2034, 'dlg',  'GFF'),    @(2035, 'itp',  'GFF')
            @(2036, 'utt',  'GFF'),   @(2037, 'dds',  'Texture'),@(2038, 'uts',  'GFF')
            @(2039, 'ltr',  'Misc'),  @(2040, 'gff',  'GFF'),    @(2041, 'fac',  'GFF')
            @(2042, 'ute',  'GFF'),   @(2043, 'utd',  'GFF'),    @(2044, 'utp',  'GFF')
            @(2045, 'dft',  'Misc'),  @(2046, 'gic',  'GFF'),    @(2047, 'gui',  'GFF')
            @(2048, 'css',  'Misc'),  @(2049, 'ccs',  'Misc'),   @(2050, 'htm',  'Text')
            @(2051, 'tms',  'Misc'),  @(2052, 'res',  'Misc'),   @(2053, 'pth',  'GFF')
            @(2054, 'are',  'GFF'),   @(2055, 'ifo',  'GFF'),    @(2056, 'bic',  'GFF')
            @(2057, 'wok',  'Model'), @(2058, '2da',  'TwoDA'),  @(2059, 'tlk',  'TLK')
            @(2060, 'txi',  'Text'), @(2061, 'git',  'GFF'),    @(2062, 'bti',  'GFF')
            @(2063, 'uti',  'GFF'),  @(2064, 'btc',  'GFF'),    @(2065, 'utc',  'GFF')
            @(2066, 'dlg',  'GFF'),  @(2067, 'itp',  'GFF'),    @(2068, 'utt',  'GFF')
            @(2069, 'dds',  'Texture'),@(2070, 'bts',  'GFF'),   @(2071, 'uts',  'GFF')
            @(2072, 'ltr',  'Misc'), @(2073, 'gff',  'GFF'),    @(2074, 'fac',  'GFF')
            @(2075, 'bte',  'GFF'), @(2076, 'ute',  'GFF'),     @(2077, 'btd',  'GFF')
            @(2078, 'utd',  'GFF'), @(2079, 'btp',  'GFF'),     @(2080, 'utp',  'GFF')
            @(2081, 'dft',  'Misc'),@(2082, 'gic',  'GFF'),     @(2083, 'gui',  'GFF')
            @(2084, 'utm',  'GFF'), @(2085, 'btm',  'GFF'),     @(2086, 'jrl',  'GFF')
            @(2090, 'utw',  'GFF'), @(2091, 'btw',  'GFF'),     @(2092, 'ssf',  'SSF')
            @(2093, 'ndb',  'Misc'),@(2094, 'ptm',  'Misc'),    @(2095, 'ptt',  'Misc')
            @(3000, 'ncs',  'Script'),@(3001, 'nss',  'Script'), @(3003, 'mdl',  'Model')
            @(3004, 'erf',  'Archive'),@(3007, 'mod',  'Archive'),@(9999, 'inv',  'Misc')
        )
        foreach ($d in $defs) {
            $rt = [ResourceType]::new($d[0], $d[1], $d[2])
            [ResourceType]::_map[$d[0]] = $rt
        }
    }

    static [ResourceType] FromId([int]$id) {
        [ResourceType]::_Init()
        if ([ResourceType]::_map.ContainsKey($id)) { return [ResourceType]::_map[$id] }
        return [ResourceType]::new($id, 'unknown', 'Unknown')
    }

    static [ResourceType] FromExtension([string]$ext) {
        [ResourceType]::_Init()
        $ext = $ext.TrimStart('.').ToLowerInvariant()
        foreach ($rt in [ResourceType]::_map.Values) {
            if ($rt.Extension -eq $ext) { return $rt }
        }
        return [ResourceType]::new(-1, $ext, 'Unknown')
    }
}

#endregion

#region ===== ResRef =====

class ResRef {
    [string] $Value

    ResRef([string]$text) {
        $text = if ($text) { $text.Trim() } else { '' }
        if ($text.Length -gt 16) { throw "ResRef '$text' exceeds 16 characters" }
        $this.Value = $text
    }

    static [ResRef] Blank() { return [ResRef]::new('') }

    [string] ToString() { return $this.Value }

    [bool] Equals([object]$other) {
        if ($other -is [ResRef])  { return $this.Value -eq $other.Value }
        if ($other -is [string])  { return $this.Value -eq $other }
        return $false
    }
    [int] GetHashCode() { return $this.Value.ToLowerInvariant().GetHashCode() }
}

#endregion

#region ===== LocalizedString =====

class LocalizedString {
    [int] $StringRef
    [hashtable] $Substrings  # key = substringId (lang*2+gender), value = string

    LocalizedString([int]$stringRef) {
        $this.StringRef  = $stringRef
        $this.Substrings = @{}
    }

    static [LocalizedString] FromInvalid() { return [LocalizedString]::new(-1) }

    static [LocalizedString] FromEnglish([string]$text) {
        $ls = [LocalizedString]::new(-1)
        $ls.SetData([KLanguage]::English, [Gender]::Male, $text)
        return $ls
    }

    static [int] SubstringId([KLanguage]$lang, [Gender]$gender) {
        return [int]$lang * 2 + [int]$gender
    }

    [void] SetData([KLanguage]$lang, [Gender]$gender, [string]$text) {
        $id = [LocalizedString]::SubstringId($lang, $gender)
        $this.Substrings[$id] = $text
    }

    [string] Get([KLanguage]$lang, [Gender]$gender) {
        $id = [LocalizedString]::SubstringId($lang, $gender)
        if ($this.Substrings.ContainsKey($id)) { return $this.Substrings[$id] }
        return $null
    }

    [bool] Equals([object]$other) {
        if ($other -isnot [LocalizedString]) { return $false }
        $o = [LocalizedString]$other
        if ($this.StringRef -ne $o.StringRef) { return $false }
        if ($this.Substrings.Count -ne $o.Substrings.Count) { return $false }
        foreach ($k in $this.Substrings.Keys) {
            if (-not $o.Substrings.ContainsKey($k)) { return $false }
            if ($this.Substrings[$k] -ne $o.Substrings[$k]) { return $false }
        }
        return $true
    }
    [int] GetHashCode() { return $this.StringRef }

    [string] ToString() {
        if ($this.StringRef -ge 0) { return $this.StringRef.ToString() }
        $engId = [LocalizedString]::SubstringId([KLanguage]::English, [Gender]::Male)
        if ($this.Substrings.ContainsKey($engId)) { return $this.Substrings[$engId] }
        foreach ($v in $this.Substrings.Values) { return $v }
        return '-1'
    }
}

#endregion

#region ===== Vector Types =====

class Vector3 {
    [float] $X; [float] $Y; [float] $Z
    Vector3()                           { $this.X = 0; $this.Y = 0; $this.Z = 0 }
    Vector3([float]$x,[float]$y,[float]$z) { $this.X = $x; $this.Y = $y; $this.Z = $z }
    [string] ToString() { return "($($this.X), $($this.Y), $($this.Z))" }
    [bool] Equals([object]$o) {
        if ($o -isnot [Vector3]) { return $false }
        return $this.X -eq $o.X -and $this.Y -eq $o.Y -and $this.Z -eq $o.Z
    }
    [int] GetHashCode() { return "$($this.X),$($this.Y),$($this.Z)".GetHashCode() }
}

class Vector4 {
    [float] $X; [float] $Y; [float] $Z; [float] $W
    Vector4()                                        { $this.X=0;$this.Y=0;$this.Z=0;$this.W=0 }
    Vector4([float]$x,[float]$y,[float]$z,[float]$w) { $this.X=$x;$this.Y=$y;$this.Z=$z;$this.W=$w }
    [string] ToString() { return "($($this.X), $($this.Y), $($this.Z), $($this.W))" }
    [bool] Equals([object]$o) {
        if ($o -isnot [Vector4]) { return $false }
        return $this.X -eq $o.X -and $this.Y -eq $o.Y -and $this.Z -eq $o.Z -and $this.W -eq $o.W
    }
    [int] GetHashCode() { return "$($this.X),$($this.Y),$($this.Z),$($this.W)".GetHashCode() }
}

#endregion

#region ===== ResourceIdentifier =====

class ResourceIdentifier {
    [string]       $ResName
    [ResourceType] $ResType

    ResourceIdentifier([string]$name, [ResourceType]$type) {
        $this.ResName = $name.ToLowerInvariant()
        $this.ResType = $type
    }

    [bool] Equals([object]$other) {
        if ($other -isnot [ResourceIdentifier]) { return $false }
        return $this.ResName -eq $other.ResName -and $this.ResType.TypeId -eq $other.ResType.TypeId
    }
    [int] GetHashCode() { return "$($this.ResName)_$($this.ResType.TypeId)".GetHashCode() }
    [string] ToString() { return "$($this.ResName).$($this.ResType.Extension)" }
}

#endregion

#region ===== BinaryHelper =====

class BinaryHelper {
    [byte[]] $Data
    [int]    $Position

    BinaryHelper([byte[]]$data) {
        $this.Data     = $data
        $this.Position = 0
    }

    [void] Seek([int]$pos)         { $this.Position = $pos }
    [void] SeekRelative([int]$off) { $this.Position += $off }
    [int]  Size()                  { return $this.Data.Length }

    [byte[]] ReadBytes([int]$count) {
        if ($this.Position + $count -gt $this.Data.Length) {
            throw "Unexpected end of data at position $($this.Position), wanted $count bytes, have $($this.Data.Length - $this.Position)"
        }
        $result = [byte[]]::new($count)
        [System.Array]::Copy($this.Data, $this.Position, $result, 0, $count)
        $this.Position += $count
        return $result
    }

    [byte]   ReadUInt8()  { return $this.ReadBytes(1)[0] }
    [uint]   ReadUInt16() { return [System.BitConverter]::ToUInt16($this.ReadBytes(2), 0) }
    [uint]   ReadUInt32() { return [System.BitConverter]::ToUInt32($this.ReadBytes(4), 0) }
    [uint64] ReadUInt64() { return [System.BitConverter]::ToUInt64($this.ReadBytes(8), 0) }
    [int]    ReadInt32()  { return [System.BitConverter]::ToInt32($this.ReadBytes(4), 0) }
    [long]   ReadInt64()  { return [System.BitConverter]::ToInt64($this.ReadBytes(8), 0) }
    [float]  ReadSingle() { return [System.BitConverter]::ToSingle($this.ReadBytes(4), 0) }
    [double] ReadDouble() { return [System.BitConverter]::ToDouble($this.ReadBytes(8), 0) }

    [string] ReadString([int]$length) {
        $bytes = $this.ReadBytes($length)
        return [System.Text.Encoding]::ASCII.GetString($bytes)
    }

    [string] ReadTerminatedString([char]$terminator) {
        $sb = [System.Text.StringBuilder]::new()
        while ($true) {
            $b = $this.ReadUInt8()
            if ([char]$b -eq $terminator) { break }
            [void]$sb.Append([char]$b)
        }
        return $sb.ToString()
    }

    [byte] Peek() {
        $b = $this.Data[$this.Position]
        return $b
    }

    # Read a LocalizedString from GFF field data
    [LocalizedString] ReadLocalizedString() {
        $totalSize = $this.ReadUInt32()
        $stringRef = $this.ReadInt32()
        $stringCount = $this.ReadUInt32()

        $ls = [LocalizedString]::new($stringRef)

        for ($i = 0; $i -lt $stringCount; $i++) {
            $substringId = $this.ReadInt32()
            $strLen = $this.ReadInt32()
            $strBytes = $this.ReadBytes($strLen)
            $text = [System.Text.Encoding]::UTF8.GetString($strBytes)
            $ls.Substrings[$substringId] = $text
        }
        return $ls
    }

    [Vector3] ReadVector3() {
        $x = $this.ReadSingle()
        $y = $this.ReadSingle()
        $z = $this.ReadSingle()
        return [Vector3]::new($x, $y, $z)
    }

    [Vector4] ReadVector4() {
        $x = $this.ReadSingle()
        $y = $this.ReadSingle()
        $z = $this.ReadSingle()
        $w = $this.ReadSingle()
        return [Vector4]::new($x, $y, $z, $w)
    }
}

# Write helper - builds byte arrays
class BinaryBuilder {
    [System.IO.MemoryStream] $Stream

    BinaryBuilder() {
        $this.Stream = [System.IO.MemoryStream]::new()
    }

    [void] WriteBytes([byte[]]$bytes) { $this.Stream.Write($bytes, 0, $bytes.Length) }
    [void] WriteUInt8([byte]$v) { $this.Stream.WriteByte($v) }

    [void] WriteUInt16([uint16]$v) {
        $this.WriteBytes([System.BitConverter]::GetBytes([uint16]$v))
    }
    [void] WriteUInt32([uint32]$v) {
        $this.WriteBytes([System.BitConverter]::GetBytes([uint32]$v))
    }
    [void] WriteInt32([int]$v) {
        $this.WriteBytes([System.BitConverter]::GetBytes([int]$v))
    }
    [void] WriteUInt64([uint64]$v) {
        $this.WriteBytes([System.BitConverter]::GetBytes([uint64]$v))
    }
    [void] WriteInt64([long]$v) {
        $this.WriteBytes([System.BitConverter]::GetBytes([long]$v))
    }
    [void] WriteSingle([float]$v) {
        $this.WriteBytes([System.BitConverter]::GetBytes([float]$v))
    }
    [void] WriteDouble([double]$v) {
        $this.WriteBytes([System.BitConverter]::GetBytes([double]$v))
    }

    [void] WriteASCII([string]$s) {
        $this.WriteBytes([System.Text.Encoding]::ASCII.GetBytes($s))
    }

    [void] WritePaddedASCII([string]$s, [int]$length) {
        $bytes = [byte[]]::new($length)
        $src = [System.Text.Encoding]::ASCII.GetBytes($s)
        $copyLen = [Math]::Min($src.Length, $length)
        [System.Array]::Copy($src, $bytes, $copyLen)
        $this.WriteBytes($bytes)
    }

    [void] WriteLocalizedString([LocalizedString]$ls) {
        $inner = [BinaryBuilder]::new()
        $inner.WriteInt32($ls.StringRef)
        $inner.WriteUInt32([uint32]$ls.Substrings.Count)
        foreach ($key in ($ls.Substrings.Keys | Sort-Object)) {
            $inner.WriteInt32([int]$key)
            $textBytes = [System.Text.Encoding]::UTF8.GetBytes($ls.Substrings[$key])
            $inner.WriteInt32($textBytes.Length)
            $inner.WriteBytes($textBytes)
        }
        $innerData = $inner.ToArray()
        $this.WriteUInt32([uint32]$innerData.Length)
        $this.WriteBytes($innerData)
    }

    [void] WriteVector3([Vector3]$v) {
        $this.WriteSingle($v.X); $this.WriteSingle($v.Y); $this.WriteSingle($v.Z)
    }

    [void] WriteVector4([Vector4]$v) {
        $this.WriteSingle($v.X); $this.WriteSingle($v.Y); $this.WriteSingle($v.Z); $this.WriteSingle($v.W)
    }

    [void] WriteZeros([int]$count) { $this.WriteBytes([byte[]]::new($count)) }

    [int] Length() { return [int]$this.Stream.Length }

    [byte[]] ToArray() { return $this.Stream.ToArray() }

    [void] Dispose() { $this.Stream.Dispose() }
}

# Seekable binary builder (for GFF writer which needs random access)
class SeekableBinaryBuilder {
    [byte[]] $Buffer
    [int]    $Pos
    [int]    $Used

    SeekableBinaryBuilder([int]$initialSize) {
        $this.Buffer = [byte[]]::new($initialSize)
        $this.Pos = 0
        $this.Used = 0
    }

    [void] EnsureCapacity([int]$needed) {
        $required = $this.Pos + $needed
        if ($required -gt $this.Buffer.Length) {
            $newSize = [Math]::Max($this.Buffer.Length * 2, $required)
            $newBuf = [byte[]]::new($newSize)
            [System.Array]::Copy($this.Buffer, $newBuf, $this.Used)
            $this.Buffer = $newBuf
        }
    }

    [void] WriteBytes([byte[]]$bytes) {
        $this.EnsureCapacity($bytes.Length)
        [System.Array]::Copy($bytes, 0, $this.Buffer, $this.Pos, $bytes.Length)
        $this.Pos += $bytes.Length
        if ($this.Pos -gt $this.Used) { $this.Used = $this.Pos }
    }

    [void] WriteUInt32([uint32]$v) { $this.WriteBytes([System.BitConverter]::GetBytes([uint32]$v)) }
    [void] WriteInt32([int]$v) { $this.WriteBytes([System.BitConverter]::GetBytes([int]$v)) }

    [void] Seek([int]$pos) { $this.Pos = $pos }
    [int]  Position()      { return $this.Pos }
    [int]  Size()          { return $this.Used }

    [byte[]] Data() {
        $result = [byte[]]::new($this.Used)
        [System.Array]::Copy($this.Buffer, $result, $this.Used)
        return $result
    }
}

#endregion

#region ===== TwoDA =====

class TwoDARow {
    [string]    $Label
    [hashtable] $Cells  # header -> value

    TwoDARow([string]$label) {
        $this.Label = $label
        $this.Cells = @{}
    }

    [string] GetString([string]$header) {
        if ($this.Cells.ContainsKey($header)) { return $this.Cells[$header] }
        throw "Header '$header' not found in row '$($this.Label)'"
    }

    [void] SetString([string]$header, [string]$value) {
        $this.Cells[$header] = $value
    }
}

class TwoDA {
    [System.Collections.Generic.List[string]]    $Headers
    [System.Collections.Generic.List[string]]    $Labels
    [System.Collections.Generic.List[hashtable]] $Rows  # each is header->value

    TwoDA() {
        $this.Headers = [System.Collections.Generic.List[string]]::new()
        $this.Labels  = [System.Collections.Generic.List[string]]::new()
        $this.Rows    = [System.Collections.Generic.List[hashtable]]::new()
    }

    TwoDA([string[]]$headers) {
        $this.Headers = [System.Collections.Generic.List[string]]::new()
        $this.Labels  = [System.Collections.Generic.List[string]]::new()
        $this.Rows    = [System.Collections.Generic.List[hashtable]]::new()
        foreach ($h in $headers) { $this.Headers.Add($h) }
    }

    [int] GetHeight() { return $this.Rows.Count }
    [int] GetWidth()  { return $this.Headers.Count }

    [void] AddColumn([string]$header) {
        if ($this.Headers.Contains($header)) { throw "Header '$header' already exists" }
        $this.Headers.Add($header)
        foreach ($row in $this.Rows) { $row[$header] = '' }
    }

    [int] AddRow([string]$label) {
        if (-not $label) { $label = $this.LabelMax().ToString() }
        $row = @{}
        foreach ($h in $this.Headers) { $row[$h] = '' }
        $this.Rows.Add($row)
        $this.Labels.Add($label)
        return $this.Rows.Count - 1
    }

    [int] AddRowWithCells([string]$label, [hashtable]$cells) {
        $idx = $this.AddRow($label)
        if ($cells) {
            foreach ($key in $cells.Keys) {
                if ($this.Headers.Contains($key)) {
                    $this.Rows[$idx][$key] = "$($cells[$key])"
                }
            }
        }
        return $idx
    }

    [int] CopyRow([int]$sourceIndex, [string]$newLabel) {
        $srcRow = $this.Rows[$sourceIndex]
        $newRow = @{}
        foreach ($h in $this.Headers) { $newRow[$h] = $srcRow[$h] }
        $this.Rows.Add($newRow)
        $lbl = if ($newLabel) { $newLabel } else { $this.Labels[$sourceIndex] }
        $this.Labels.Add($lbl)
        return $this.Rows.Count - 1
    }

    [void] RemoveRow([int]$index) {
        $this.Rows.RemoveAt($index)
        $this.Labels.RemoveAt($index)
    }

    [int] LabelMax() {
        $max = -1
        foreach ($l in $this.Labels) {
            $val = 0
            if ([int]::TryParse($l, [ref]$val)) {
                if ($val -gt $max) { $max = $val }
            }
        }
        return $max + 1
    }

    [string] GetCell([int]$row, [string]$header) {
        return $this.Rows[$row][$header]
    }

    [void] SetCell([int]$row, [string]$header, [string]$value) {
        if (-not $this.Headers.Contains($header)) { throw "Header '$header' does not exist" }
        $this.Rows[$row][$header] = $value
    }

    [nullable[int]] GetCellInt([int]$row, [string]$header) {
        $val = $this.GetCell($row, $header)
        if ([string]::IsNullOrWhiteSpace($val) -or $val -eq '****') { return $null }
        $result = 0
        if ([int]::TryParse($val, [ref]$result)) { return $result }
        return $null
    }

    [int] GetRowIndex([string]$label) {
        for ($i = 0; $i -lt $this.Labels.Count; $i++) {
            if ($this.Labels[$i] -eq $label) { return $i }
        }
        throw "Row label '$label' not found"
    }

    [TwoDARow] GetRow([int]$index) {
        $r = [TwoDARow]::new($this.Labels[$index])
        foreach ($h in $this.Headers) { $r.Cells[$h] = $this.Rows[$index][$h] }
        return $r
    }

    [byte[]] ToBytes() { return Write-TwoDA -TwoDA $this }

    static [TwoDA] FromBytes([byte[]]$data) { return Read-TwoDA -Data $data }
}

function Read-TwoDA {
    [CmdletBinding()]
    param([byte[]]$Data)

    $r = [BinaryHelper]::new($Data)
    $fileType = $r.ReadString(4)
    $fileVersion = $r.ReadString(4)

    if ($fileType -ne '2DA ') { throw 'Invalid 2DA file type' }
    if ($fileVersion -ne 'V2.b') { throw 'Unsupported 2DA version' }

    [void]$r.ReadUInt8()  # newline

    $twoda = [TwoDA]::new()

    # Read column headers
    while ($r.Peek() -ne 0) {
        $header = $r.ReadTerminatedString("`t")
        $twoda.Headers.Add($header)
    }
    [void]$r.ReadUInt8()  # null terminator

    # Row count and labels
    $rowCount = $r.ReadUInt32()
    $columnCount = $twoda.GetWidth()

    for ($i = 0; $i -lt $rowCount; $i++) {
        $label = $r.ReadTerminatedString("`t")
        $twoda.Labels.Add($label)
        $row = @{}
        foreach ($h in $twoda.Headers) { $row[$h] = '' }
        $twoda.Rows.Add($row)
    }

    # Cell offsets
    $cellCount = $rowCount * $columnCount
    $cellOffsets = [System.Collections.Generic.List[int]]::new()
    for ($i = 0; $i -lt $cellCount; $i++) {
        $cellOffsets.Add($r.ReadUInt16())
    }

    [void]$r.ReadUInt16()  # data size
    $cellDataOffset = $r.Position

    # Read cell values
    for ($i = 0; $i -lt $cellCount; $i++) {
        $colIdx = $i % $columnCount
        $rowIdx = [Math]::Floor($i / $columnCount)
        $header = $twoda.Headers[$colIdx]
        $r.Seek($cellDataOffset + $cellOffsets[$i])
        $value = $r.ReadTerminatedString([char]0)
        $twoda.Rows[$rowIdx][$header] = $value
    }

    return $twoda
}

function Write-TwoDA {
    [CmdletBinding()]
    param([TwoDA]$TwoDA)

    $b = [BinaryBuilder]::new()
    $b.WriteASCII('2DA ')
    $b.WriteASCII('V2.b')
    $b.WriteASCII("`n")

    # Column headers
    foreach ($h in $TwoDA.Headers) {
        $b.WriteASCII("$h`t")
    }
    $b.WriteUInt8(0)

    # Row count
    $b.WriteUInt32([uint32]$TwoDA.GetHeight())

    # Row labels
    foreach ($l in $TwoDA.Labels) {
        $b.WriteASCII("$l`t")
    }

    # Build cell data with dedup
    $values = [System.Collections.Generic.List[string]]::new()
    $valueOffsets = [System.Collections.Generic.List[int]]::new()
    $cellOffsets = [System.Collections.Generic.List[int]]::new()

    for ($rowIdx = 0; $rowIdx -lt $TwoDA.GetHeight(); $rowIdx++) {
        foreach ($h in $TwoDA.Headers) {
            $val = "$($TwoDA.Rows[$rowIdx][$h])`0"
            $existIdx = $values.IndexOf($val)
            if ($existIdx -lt 0) {
                $off = 0
                if ($values.Count -gt 0) {
                    $off = $valueOffsets[$values.Count - 1] + $values[$values.Count - 1].Length
                }
                $values.Add($val)
                $valueOffsets.Add($off)
                $existIdx = $values.Count - 1
            }
            $cellOffsets.Add($valueOffsets[$existIdx])
        }
    }

    # Write cell offsets
    foreach ($co in $cellOffsets) {
        $b.WriteUInt16([uint16]$co)
    }

    # Data size
    $dataSize = 0
    foreach ($v in $values) { $dataSize += $v.Length }
    $b.WriteUInt16([uint16]$dataSize)

    # Write cell values
    foreach ($v in $values) {
        $b.WriteASCII($v)
    }

    $result = $b.ToArray()
    $b.Dispose()
    return $result
}

#endregion

#region ===== TLK =====

class TLKEntry {
    [bool]   $TextPresent
    [bool]   $SoundPresent
    [bool]   $SoundLengthPresent
    [string] $Text
    [ResRef] $Voiceover
    [float]  $SoundLength

    TLKEntry() {
        $this.TextPresent = $false
        $this.SoundPresent = $false
        $this.SoundLengthPresent = $false
        $this.Text = ''
        $this.Voiceover = [ResRef]::Blank()
        $this.SoundLength = 0
    }

    TLKEntry([string]$text, [ResRef]$voiceover) {
        $this.Text = $text
        $this.Voiceover = $voiceover
        $this.TextPresent = $text.Length -gt 0
        $this.SoundPresent = $voiceover.Value.Length -gt 0
        $this.SoundLengthPresent = $false
        $this.SoundLength = 0
    }
}

class TLK {
    [System.Collections.Generic.List[TLKEntry]] $Entries
    [KLanguage] $Language

    TLK() {
        $this.Entries  = [System.Collections.Generic.List[TLKEntry]]::new()
        $this.Language = [KLanguage]::English
    }

    TLK([KLanguage]$lang) {
        $this.Entries  = [System.Collections.Generic.List[TLKEntry]]::new()
        $this.Language = $lang
    }

    [int] Count() { return $this.Entries.Count }

    [TLKEntry] Get([int]$stringref) {
        if ($stringref -ge 0 -and $stringref -lt $this.Entries.Count) { return $this.Entries[$stringref] }
        return $null
    }

    [string] String([int]$stringref) {
        $e = $this.Get($stringref)
        if ($e) { return $e.Text }
        return ''
    }

    [int] Add([string]$text, [string]$soundResref) {
        $sr = if ($soundResref) { [ResRef]::new($soundResref) } else { [ResRef]::Blank() }
        $entry = [TLKEntry]::new($text, $sr)
        $this.Entries.Add($entry)
        return $this.Entries.Count - 1
    }

    [void] Replace([int]$stringref, [string]$text, [string]$soundResref) {
        if ($stringref -lt 0 -or $stringref -ge $this.Entries.Count) {
            throw "Cannot replace nonexistent stringref: $stringref"
        }
        $old = $this.Entries[$stringref]
        $newText = if ([string]::IsNullOrEmpty($text)) { $old.Text } else { $text }
        $newSound = if ([string]::IsNullOrEmpty($soundResref)) { $old.Voiceover } else { [ResRef]::new($soundResref) }
        $this.Entries[$stringref] = [TLKEntry]::new($newText, $newSound)
    }

    [void] Resize([int]$size) {
        while ($this.Entries.Count -lt $size) {
            $this.Entries.Add([TLKEntry]::new('', [ResRef]::Blank()))
        }
        if ($this.Entries.Count -gt $size) {
            $this.Entries.RemoveRange($size, $this.Entries.Count - $size)
        }
    }

    [byte[]] ToBytes() { return Write-TLK -TLK $this }
    static [TLK] FromBytes([byte[]]$data) { return Read-TLK -Data $data }
}

function Read-TLK {
    [CmdletBinding()]
    param([byte[]]$Data)

    $r = [BinaryHelper]::new($Data)
    $fileType = $r.ReadString(4)
    $fileVersion = $r.ReadString(4)

    if ($fileType -ne 'TLK ') { throw 'Invalid TLK file' }
    if ($fileVersion -ne 'V3.0') { throw 'Unsupported TLK version' }

    $languageId = $r.ReadUInt32()
    $stringCount = $r.ReadUInt32()
    $textsOffset = $r.ReadUInt32()

    $tlk = [TLK]::new([KLanguage]$languageId)
    $tlk.Resize([int]$stringCount)

    # Read entry headers
    $textHeaders = [System.Collections.Generic.List[int[]]]::new()
    for ($i = 0; $i -lt $stringCount; $i++) {
        $flags = $r.ReadUInt32()
        $soundResref = $r.ReadString(16).TrimEnd([char]0)
        [void]$r.ReadUInt32()  # volume variance
        [void]$r.ReadUInt32()  # pitch variance
        $textOffset = $r.ReadUInt32()
        $textLength = $r.ReadUInt32()
        $soundLength = $r.ReadSingle()

        $entry = $tlk.Entries[$i]
        $entry.TextPresent = ($flags -band 0x0001) -ne 0
        $entry.SoundPresent = ($flags -band 0x0002) -ne 0
        $entry.SoundLengthPresent = ($flags -band 0x0004) -ne 0
        $entry.Voiceover = [ResRef]::new($soundResref)
        $entry.SoundLength = $soundLength

        $textHeaders.Add(@([int]$textOffset, [int]$textLength))
    }

    # Read text data
    for ($i = 0; $i -lt $stringCount; $i++) {
        $offset = $textHeaders[$i][0]
        $length = $textHeaders[$i][1]
        $r.Seek([int]$textsOffset + $offset)
        $textBytes = $r.ReadBytes($length)
        $tlk.Entries[$i].Text = [System.Text.Encoding]::GetEncoding('windows-1252').GetString($textBytes)
    }

    return $tlk
}

function Write-TLK {
    [CmdletBinding()]
    param([TLK]$TLK)

    $b = [BinaryBuilder]::new()

    $encoding = [System.Text.Encoding]::GetEncoding('windows-1252')

    # Header
    $b.WriteASCII('TLK ')
    $b.WriteASCII('V3.0')
    $b.WriteUInt32([uint32][int]$TLK.Language)
    $b.WriteUInt32([uint32]$TLK.Entries.Count)

    # Entries offset = header(20) + entries(40 each)
    $entriesOffset = 20 + $TLK.Entries.Count * 40
    $b.WriteUInt32([uint32]$entriesOffset)

    # Write entry headers
    $textOffset = 0
    foreach ($entry in $TLK.Entries) {
        $textBytes = $encoding.GetBytes($entry.Text)
        $flags = [uint32]0
        if ($entry.TextPresent)        { $flags = $flags -bor 0x0001 }
        if ($entry.SoundPresent)       { $flags = $flags -bor 0x0002 }
        if ($entry.SoundLengthPresent) { $flags = $flags -bor 0x0004 }

        $b.WriteUInt32($flags)
        $b.WritePaddedASCII($entry.Voiceover.Value, 16)
        $b.WriteUInt32(0)  # volume
        $b.WriteUInt32(0)  # pitch
        $b.WriteUInt32([uint32]$textOffset)
        $b.WriteUInt32([uint32]$textBytes.Length)
        $b.WriteUInt32(0)  # sound length

        $textOffset += $textBytes.Length
    }

    # Write text data
    foreach ($entry in $TLK.Entries) {
        $textBytes = $encoding.GetBytes($entry.Text)
        $b.WriteBytes($textBytes)
    }

    $result = $b.ToArray()
    $b.Dispose()
    return $result
}

#endregion

#region ===== GFF =====

class GFFField {
    [GFFFieldType] $FieldType
    [object]       $Value

    GFFField([GFFFieldType]$type, [object]$value) {
        $this.FieldType = $type
        $this.Value     = $value
    }
}

class GFFList {
    [System.Collections.Generic.List[GFFStruct]] $Items

    GFFList() {
        $this.Items = [System.Collections.Generic.List[GFFStruct]]::new()
    }

    [int] Count() { return $this.Items.Count }

    [GFFStruct] At([int]$index) { return $this.Items[$index] }

    [void] Add([int]$structId) {
        $this.Items.Add([GFFStruct]::new($structId))
    }

    [void] AddStruct([GFFStruct]$s) {
        $this.Items.Add($s)
    }
}

class GFFStruct {
    [int] $StructId
    [ordered] $Fields  # ordered hashtable of label -> GFFField

    GFFStruct() {
        $this.StructId = 0
        $this.Fields = [ordered]@{}
    }

    GFFStruct([int]$structId) {
        $this.StructId = $structId
        $this.Fields = [ordered]@{}
    }

    [int] Count() { return $this.Fields.Count }

    [bool] Exists([string]$label) { return $this.Fields.Contains($label) }

    [void] Remove([string]$label) { $this.Fields.Remove($label) }

    [GFFFieldType] GetFieldType([string]$label) {
        if ($this.Fields.Contains($label)) { return $this.Fields[$label].FieldType }
        return $null
    }

    [object] GetValue([string]$label) {
        if ($this.Fields.Contains($label)) { return $this.Fields[$label].Value }
        return $null
    }

    # Type-specific getters
    [byte]    GetUInt8([string]$l)   { $v = $this.GetValue($l); return [byte]$(if($null -ne $v){$v}else{0}) }
    [sbyte]   GetInt8([string]$l)    { $v = $this.GetValue($l); return [sbyte]$(if($null -ne $v){$v}else{0}) }
    [uint16]  GetUInt16([string]$l)  { $v = $this.GetValue($l); return [uint16]$(if($null -ne $v){$v}else{0}) }
    [int16]   GetInt16([string]$l)   { $v = $this.GetValue($l); return [int16]$(if($null -ne $v){$v}else{0}) }
    [uint32]  GetUInt32([string]$l)  { $v = $this.GetValue($l); return [uint32]$(if($null -ne $v){$v}else{0}) }
    [int]     GetInt32([string]$l)   { $v = $this.GetValue($l); return [int]$(if($null -ne $v){$v}else{0}) }
    [uint64]  GetUInt64([string]$l)  { $v = $this.GetValue($l); return [uint64]$(if($null -ne $v){$v}else{0}) }
    [long]    GetInt64([string]$l)   { $v = $this.GetValue($l); return [long]$(if($null -ne $v){$v}else{0}) }
    [float]   GetSingle([string]$l)  { $v = $this.GetValue($l); return [float]$(if($null -ne $v){$v}else{0}) }
    [double]  GetDouble([string]$l)  { $v = $this.GetValue($l); return [double]$(if($null -ne $v){$v}else{0}) }
    [string]  GetString([string]$l)  { $v = $this.GetValue($l); return $(if($null -ne $v){"$v"}else{''}) }
    [ResRef]  GetResRef([string]$l)  { $v = $this.GetValue($l); return $(if($v -is [ResRef]){$v}else{[ResRef]::Blank()}) }
    [byte[]]  GetBinary([string]$l)  { $v = $this.GetValue($l); return $(if($v -is [byte[]]){$v}else{[byte[]]::new(0)}) }

    [LocalizedString] GetLocString([string]$l) {
        $v = $this.GetValue($l)
        return $(if($v -is [LocalizedString]){$v}else{[LocalizedString]::FromInvalid()})
    }
    [Vector3] GetVector3([string]$l) {
        $v = $this.GetValue($l)
        return $(if($v -is [Vector3]){$v}else{[Vector3]::new()})
    }
    [Vector4] GetVector4([string]$l) {
        $v = $this.GetValue($l)
        return $(if($v -is [Vector4]){$v}else{[Vector4]::new()})
    }
    [GFFStruct] GetStruct([string]$l) {
        $v = $this.GetValue($l)
        return $(if($v -is [GFFStruct]){$v}else{[GFFStruct]::new()})
    }
    [GFFList] GetList([string]$l) {
        $v = $this.GetValue($l)
        return $(if($v -is [GFFList]){$v}else{[GFFList]::new()})
    }

    # Type-specific setters
    [void] SetUInt8([string]$l, [byte]$v)     { $this.Fields[$l] = [GFFField]::new([GFFFieldType]::UInt8, $v) }
    [void] SetInt8([string]$l, [sbyte]$v)     { $this.Fields[$l] = [GFFField]::new([GFFFieldType]::Int8, $v) }
    [void] SetUInt16([string]$l, [uint16]$v)  { $this.Fields[$l] = [GFFField]::new([GFFFieldType]::UInt16, $v) }
    [void] SetInt16([string]$l, [int16]$v)    { $this.Fields[$l] = [GFFField]::new([GFFFieldType]::Int16, $v) }
    [void] SetUInt32([string]$l, [uint32]$v)  { $this.Fields[$l] = [GFFField]::new([GFFFieldType]::UInt32, $v) }
    [void] SetInt32([string]$l, [int]$v)      { $this.Fields[$l] = [GFFField]::new([GFFFieldType]::Int32, $v) }
    [void] SetUInt64([string]$l, [uint64]$v)  { $this.Fields[$l] = [GFFField]::new([GFFFieldType]::UInt64, $v) }
    [void] SetInt64([string]$l, [long]$v)     { $this.Fields[$l] = [GFFField]::new([GFFFieldType]::Int64, $v) }
    [void] SetSingle([string]$l, [float]$v)   { $this.Fields[$l] = [GFFField]::new([GFFFieldType]::Single, $v) }
    [void] SetDouble([string]$l, [double]$v)  { $this.Fields[$l] = [GFFField]::new([GFFFieldType]::Double, $v) }
    [void] SetString([string]$l, [string]$v)  { $this.Fields[$l] = [GFFField]::new([GFFFieldType]::String, $v) }
    [void] SetResRef([string]$l, [ResRef]$v)  { $this.Fields[$l] = [GFFField]::new([GFFFieldType]::ResRef, $v) }
    [void] SetLocString([string]$l, [LocalizedString]$v) { $this.Fields[$l] = [GFFField]::new([GFFFieldType]::LocalizedString, $v) }
    [void] SetBinary([string]$l, [byte[]]$v)  { $this.Fields[$l] = [GFFField]::new([GFFFieldType]::Binary, $v) }
    [void] SetVector3([string]$l, [Vector3]$v) { $this.Fields[$l] = [GFFField]::new([GFFFieldType]::Vector3, $v) }
    [void] SetVector4([string]$l, [Vector4]$v) { $this.Fields[$l] = [GFFField]::new([GFFFieldType]::Vector4, $v) }
    [void] SetStruct([string]$l, [GFFStruct]$v) { $this.Fields[$l] = [GFFField]::new([GFFFieldType]::Struct, $v) }
    [void] SetList([string]$l, [GFFList]$v)   { $this.Fields[$l] = [GFFField]::new([GFFFieldType]::List, $v) }

    [void] SetField([string]$label, [GFFFieldType]$type, [object]$value) {
        $this.Fields[$label] = [GFFField]::new($type, $value)
    }
}

class GFF {
    [GFFContent] $Content
    [GFFStruct]  $Root

    GFF() {
        $this.Content = [GFFContent]::GFF
        $this.Root = [GFFStruct]::new(-1)
    }

    GFF([GFFContent]$content) {
        $this.Content = $content
        $this.Root = [GFFStruct]::new(-1)
    }

    [byte[]] ToBytes() { return Write-GFF -GFF $this }
    static [GFF] FromBytes([byte[]]$data) { return Read-GFF -Data $data }
}

# GFFContent FourCC mapping
$script:GFFContentFourCC = @{
    [GFFContent]::GFF = 'GFF '
    [GFFContent]::BIC = 'BIC '
    [GFFContent]::UTC = 'UTC '
    [GFFContent]::UTI = 'UTI '
    [GFFContent]::UTP = 'UTP '
    [GFFContent]::UTM = 'UTM '
    [GFFContent]::UTS = 'UTS '
    [GFFContent]::UTT = 'UTT '
    [GFFContent]::UTW = 'UTW '
    [GFFContent]::UTD = 'UTD '
    [GFFContent]::UTE = 'UTE '
    [GFFContent]::ARE = 'ARE '
    [GFFContent]::DLG = 'DLG '
    [GFFContent]::GIT = 'GIT '
    [GFFContent]::IFO = 'IFO '
    [GFFContent]::JRL = 'JRL '
    [GFFContent]::PTH = 'PTH '
    [GFFContent]::FAC = 'FAC '
    [GFFContent]::GUI = 'GUI '
    [GFFContent]::INV = 'INV '
    [GFFContent]::PT  = 'PT  '
    [GFFContent]::GVT = 'GVT '
    [GFFContent]::NFO = 'NFO '
}

$script:GFFComplexFields = @(
    [GFFFieldType]::UInt64, [GFFFieldType]::Int64, [GFFFieldType]::Double,
    [GFFFieldType]::String, [GFFFieldType]::ResRef, [GFFFieldType]::LocalizedString,
    [GFFFieldType]::Binary, [GFFFieldType]::Vector3, [GFFFieldType]::Vector4
)

function Read-GFF {
    [CmdletBinding()]
    param([byte[]]$Data)

    $r = [BinaryHelper]::new($Data)
    $fileType    = $r.ReadString(4)
    $fileVersion = $r.ReadString(4)

    if ($fileVersion -ne 'V3.2') { throw "Unsupported GFF version: $fileVersion" }

    # Determine content type from fourCC
    $content = [GFFContent]::GFF
    foreach ($key in $script:GFFContentFourCC.Keys) {
        if ($script:GFFContentFourCC[$key] -eq $fileType) { $content = $key; break }
    }

    $gff = [GFF]::new($content)

    $structOffset       = $r.ReadUInt32()
    [void]$r.ReadUInt32()  # struct count
    $fieldOffset        = $r.ReadUInt32()
    [void]$r.ReadUInt32()  # field count
    $labelOffset        = $r.ReadUInt32()
    $labelCount         = $r.ReadUInt32()
    $fieldDataOffset    = $r.ReadUInt32()
    [void]$r.ReadUInt32()  # field data count
    $fieldIndicesOffset = $r.ReadUInt32()
    [void]$r.ReadUInt32()  # field indices count
    $listIndicesOffset  = $r.ReadUInt32()
    [void]$r.ReadUInt32()  # list indices count

    # Read labels
    $labels = [System.Collections.Generic.List[string]]::new()
    $r.Seek([int]$labelOffset)
    for ($i = 0; $i -lt $labelCount; $i++) {
        $labels.Add($r.ReadString(16).TrimEnd([char]0))
    }

    # Recursive struct loader
    $loadStruct = $null
    $loadField = $null
    $loadList = $null

    $loadStruct = {
        param([GFFStruct]$gs, [int]$structIndex)
        $structPos = [int]$structOffset + $structIndex * 12
        $r.Seek($structPos)
        $gs.StructId = $r.ReadInt32()
        $dataVal = $r.ReadUInt32()
        $fieldCount = $r.ReadUInt32()

        if ($fieldCount -eq 1) {
            & $loadField $gs ([int]$dataVal)
        }
        elseif ($fieldCount -gt 1) {
            $indicesPos = [int]$fieldIndicesOffset + [int]$dataVal
            $r.Seek($indicesPos)
            $indices = [System.Collections.Generic.List[int]]::new()
            for ($fi = 0; $fi -lt $fieldCount; $fi++) {
                $indices.Add([int]$r.ReadUInt32())
            }
            foreach ($idx in $indices) {
                & $loadField $gs $idx
            }
        }
    }

    $loadField = {
        param([GFFStruct]$gs, [int]$fieldIndex)
        $fieldPos = [int]$fieldOffset + $fieldIndex * 12
        $r.Seek($fieldPos)

        $fieldTypeId = $r.ReadUInt32()
        $labelId = $r.ReadUInt32()
        $ft = [GFFFieldType]$fieldTypeId
        $label = $labels[[int]$labelId]

        if ($ft -in $script:GFFComplexFields) {
            $offset = $r.ReadUInt32()
            $r.Seek([int]$fieldDataOffset + [int]$offset)

            switch ($ft) {
                ([GFFFieldType]::UInt64) { $gs.SetUInt64($label, $r.ReadUInt64()) }
                ([GFFFieldType]::Int64)  { $gs.SetInt64($label, $r.ReadInt64()) }
                ([GFFFieldType]::Double) { $gs.SetDouble($label, $r.ReadDouble()) }
                ([GFFFieldType]::String) {
                    $len = $r.ReadUInt32()
                    $str = $r.ReadString([int]$len).TrimEnd([char]0)
                    $gs.SetString($label, $str)
                }
                ([GFFFieldType]::ResRef) {
                    $len = $r.ReadUInt8()
                    $str = $r.ReadString([int]$len).Trim()
                    $gs.SetResRef($label, [ResRef]::new($str))
                }
                ([GFFFieldType]::LocalizedString) {
                    $gs.SetLocString($label, $r.ReadLocalizedString())
                }
                ([GFFFieldType]::Binary) {
                    $len = $r.ReadUInt32()
                    $gs.SetBinary($label, $r.ReadBytes([int]$len))
                }
                ([GFFFieldType]::Vector3) { $gs.SetVector3($label, $r.ReadVector3()) }
                ([GFFFieldType]::Vector4) { $gs.SetVector4($label, $r.ReadVector4()) }
            }
        }
        elseif ($ft -eq [GFFFieldType]::Struct) {
            $structIdx = $r.ReadUInt32()
            $child = [GFFStruct]::new()
            & $loadStruct $child ([int]$structIdx)
            $gs.SetStruct($label, $child)
        }
        elseif ($ft -eq [GFFFieldType]::List) {
            $listOffset = $r.ReadUInt32()
            $r.Seek([int]$listIndicesOffset + [int]$listOffset)
            $listCount = $r.ReadUInt32()
            $listStructIndices = [System.Collections.Generic.List[int]]::new()
            for ($li = 0; $li -lt $listCount; $li++) {
                $listStructIndices.Add([int]$r.ReadUInt32())
            }
            $gffList = [GFFList]::new()
            foreach ($si in $listStructIndices) {
                $child = [GFFStruct]::new()
                & $loadStruct $child $si
                $gffList.AddStruct($child)
            }
            $gs.SetList($label, $gffList)
        }
        else {
            # Simple inline types
            switch ($ft) {
                ([GFFFieldType]::UInt8)  { $v = $r.ReadUInt32(); $gs.SetUInt8($label, [byte]($v -band 0xFF)) }
                ([GFFFieldType]::Int8)   { $v = $r.ReadInt32();  $gs.SetInt8($label, [sbyte]($v -band 0xFF)) }
                ([GFFFieldType]::UInt16) { $v = $r.ReadUInt32(); $gs.SetUInt16($label, [uint16]($v -band 0xFFFF)) }
                ([GFFFieldType]::Int16)  { $v = $r.ReadInt32();  $gs.SetInt16($label, [int16]($v -band 0xFFFF)) }
                ([GFFFieldType]::UInt32) { $gs.SetUInt32($label, $r.ReadUInt32()) }
                ([GFFFieldType]::Int32)  { $gs.SetInt32($label, $r.ReadInt32()) }
                ([GFFFieldType]::Single) { $gs.SetSingle($label, $r.ReadSingle()) }
            }
        }
    }

    & $loadStruct $gff.Root 0
    return $gff
}

function Write-GFF {
    [CmdletBinding()]
    param([GFF]$GFF)

    # Use seekable builders for sections that need random access
    $structBuf  = [SeekableBinaryBuilder]::new(4096)
    $fieldBuf   = [SeekableBinaryBuilder]::new(4096)
    $fdataBuf   = [SeekableBinaryBuilder]::new(4096)
    $findicesBuf = [SeekableBinaryBuilder]::new(4096)
    $lindicesBuf = [SeekableBinaryBuilder]::new(4096)
    $labelsList = [System.Collections.Generic.List[string]]::new()
    $state = @{ StructCount = 0; FieldCount = 0 }

    $getLabelIndex = {
        param([string]$label)
        $idx = $labelsList.IndexOf($label)
        if ($idx -ge 0) { return $idx }
        $labelsList.Add($label)
        return $labelsList.Count - 1
    }

    $buildStruct = $null
    $buildField = $null
    $buildList = $null

    $buildStruct = {
        param([GFFStruct]$gs)
        $state.StructCount++

        $sid = $gs.StructId
        if ($sid -eq -1) { $structBuf.WriteBytes([byte[]](0xFF,0xFF,0xFF,0xFF)) }
        else { $structBuf.WriteUInt32([uint32]$sid) }

        $fc = $gs.Count()

        if ($fc -eq 0) {
            $structBuf.WriteBytes([byte[]](0xFF,0xFF,0xFF,0xFF))
            $structBuf.WriteUInt32(0)
        }
        elseif ($fc -eq 1) {
            $structBuf.WriteUInt32([uint32]$state.FieldCount)
            $structBuf.WriteUInt32([uint32]$fc)
            foreach ($key in $gs.Fields.Keys) {
                $f = $gs.Fields[$key]
                & $buildField $key $f.Value $f.FieldType
            }
        }
        else {
            # Multiple fields - write indices
            $indicesStart = $findicesBuf.Size()
            $structBuf.WriteUInt32([uint32]$indicesStart)
            $structBuf.WriteUInt32([uint32]$fc)

            # Reserve space
            $findicesBuf.Seek($findicesBuf.Size())
            for ($i = 0; $i -lt $fc; $i++) { $findicesBuf.WriteUInt32(0) }

            $idx = 0
            foreach ($key in $gs.Fields.Keys) {
                $f = $gs.Fields[$key]
                $curPos = $findicesBuf.Position()
                $findicesBuf.Seek($indicesStart + $idx * 4)
                $findicesBuf.WriteUInt32([uint32]$state.FieldCount)
                $findicesBuf.Seek($curPos)
                & $buildField $key $f.Value $f.FieldType
                $idx++
            }
        }
    }

    $buildField = {
        param([string]$label, [object]$value, [GFFFieldType]$ft)
        $state.FieldCount++
        $fieldBuf.WriteUInt32([uint32][int]$ft)
        $fieldBuf.WriteUInt32([uint32](& $getLabelIndex $label))

        if ($ft -in $script:GFFComplexFields) {
            $fieldBuf.WriteUInt32([uint32]$fdataBuf.Size())
            $fdataBuf.Seek($fdataBuf.Size())

            switch ($ft) {
                ([GFFFieldType]::UInt64) {
                    $fdataBuf.WriteBytes([System.BitConverter]::GetBytes([uint64]$value))
                }
                ([GFFFieldType]::Int64) {
                    $fdataBuf.WriteBytes([System.BitConverter]::GetBytes([long]$value))
                }
                ([GFFFieldType]::Double) {
                    $fdataBuf.WriteBytes([System.BitConverter]::GetBytes([double]$value))
                }
                ([GFFFieldType]::String) {
                    $strBytes = [System.Text.Encoding]::ASCII.GetBytes("$value")
                    $fdataBuf.WriteUInt32([uint32]$strBytes.Length)
                    $fdataBuf.WriteBytes($strBytes)
                }
                ([GFFFieldType]::ResRef) {
                    $rrStr = "$value"
                    $rrBytes = [System.Text.Encoding]::ASCII.GetBytes($rrStr)
                    $b = [byte[]]@($rrBytes.Length)
                    $fdataBuf.WriteBytes($b)
                    $fdataBuf.WriteBytes($rrBytes)
                }
                ([GFFFieldType]::LocalizedString) {
                    $ls = [LocalizedString]$value
                    $inner = [BinaryBuilder]::new()
                    $inner.WriteInt32($ls.StringRef)
                    $inner.WriteUInt32([uint32]$ls.Substrings.Count)
                    foreach ($k in ($ls.Substrings.Keys | Sort-Object)) {
                        $inner.WriteInt32([int]$k)
                        $tb = [System.Text.Encoding]::UTF8.GetBytes($ls.Substrings[$k])
                        $inner.WriteInt32($tb.Length)
                        $inner.WriteBytes($tb)
                    }
                    $innerData = $inner.ToArray()
                    $inner.Dispose()
                    $fdataBuf.WriteUInt32([uint32]$innerData.Length)
                    $fdataBuf.WriteBytes($innerData)
                }
                ([GFFFieldType]::Binary) {
                    $binData = [byte[]]$value
                    $fdataBuf.WriteUInt32([uint32]$binData.Length)
                    $fdataBuf.WriteBytes($binData)
                }
                ([GFFFieldType]::Vector3) {
                    $v3 = [Vector3]$value
                    $fdataBuf.WriteBytes([System.BitConverter]::GetBytes([float]$v3.X))
                    $fdataBuf.WriteBytes([System.BitConverter]::GetBytes([float]$v3.Y))
                    $fdataBuf.WriteBytes([System.BitConverter]::GetBytes([float]$v3.Z))
                }
                ([GFFFieldType]::Vector4) {
                    $v4 = [Vector4]$value
                    $fdataBuf.WriteBytes([System.BitConverter]::GetBytes([float]$v4.X))
                    $fdataBuf.WriteBytes([System.BitConverter]::GetBytes([float]$v4.Y))
                    $fdataBuf.WriteBytes([System.BitConverter]::GetBytes([float]$v4.Z))
                    $fdataBuf.WriteBytes([System.BitConverter]::GetBytes([float]$v4.W))
                }
            }
        }
        elseif ($ft -eq [GFFFieldType]::Struct) {
            $fieldBuf.WriteUInt32([uint32]$state.StructCount)
            & $buildStruct ([GFFStruct]$value)
        }
        elseif ($ft -eq [GFFFieldType]::List) {
            $fieldBuf.WriteUInt32([uint32]$lindicesBuf.Size())
            $gList = [GFFList]$value
            $lindicesBuf.Seek($lindicesBuf.Size())
            $lindicesBuf.WriteUInt32([uint32]$gList.Count())
            $indexStart = $lindicesBuf.Position()
            for ($i = 0; $i -lt $gList.Count(); $i++) { $lindicesBuf.WriteUInt32(0) }
            for ($i = 0; $i -lt $gList.Count(); $i++) {
                $cp = $lindicesBuf.Position()
                $lindicesBuf.Seek($indexStart + $i * 4)
                $lindicesBuf.WriteUInt32([uint32]$state.StructCount)
                $lindicesBuf.Seek($cp)
                & $buildStruct ($gList.At($i))
            }
        }
        else {
            # Simple inline types
            switch ($ft) {
                ([GFFFieldType]::UInt8)  { $fieldBuf.WriteUInt32([uint32][byte]$value) }
                ([GFFFieldType]::Int8)   { $fieldBuf.WriteInt32([int][sbyte]$value) }
                ([GFFFieldType]::UInt16) { $fieldBuf.WriteUInt32([uint32][uint16]$value) }
                ([GFFFieldType]::Int16)  { $fieldBuf.WriteInt32([int][int16]$value) }
                ([GFFFieldType]::UInt32) { $fieldBuf.WriteUInt32([uint32]$value) }
                ([GFFFieldType]::Int32)  { $fieldBuf.WriteInt32([int]$value) }
                ([GFFFieldType]::Single) {
                    $fieldBuf.WriteBytes([System.BitConverter]::GetBytes([float]$value))
                }
            }
        }
    }

    & $buildStruct $GFF.Root

    # Assemble file
    $headerSize = 56
    $structData = $structBuf.Data()
    $fieldData = $fieldBuf.Data()
    $fdataData = $fdataBuf.Data()
    $findicesData = $findicesBuf.Data()
    $lindicesData = $lindicesBuf.Data()

    $structOff = $headerSize
    $structCnt = $structData.Length / 12
    $fieldOff = $structOff + $structData.Length
    $fieldCnt = $fieldData.Length / 12
    $labelOff = $fieldOff + $fieldData.Length
    $labelCnt = $labelsList.Count
    $fdataOff = $labelOff + $labelCnt * 16
    $fdataCnt = $fdataData.Length
    $findicesOff = $fdataOff + $fdataData.Length
    $findicesCnt = $findicesData.Length
    $lindicesOff = $findicesOff + $findicesData.Length
    $lindicesCnt = $lindicesData.Length

    $fourCC = $script:GFFContentFourCC[$GFF.Content]
    if (-not $fourCC) { $fourCC = 'GFF ' }

    $out = [BinaryBuilder]::new()
    $out.WriteASCII($fourCC)
    $out.WriteASCII('V3.2')
    $out.WriteUInt32([uint32]$structOff)
    $out.WriteUInt32([uint32]$structCnt)
    $out.WriteUInt32([uint32]$fieldOff)
    $out.WriteUInt32([uint32]$fieldCnt)
    $out.WriteUInt32([uint32]$labelOff)
    $out.WriteUInt32([uint32]$labelCnt)
    $out.WriteUInt32([uint32]$fdataOff)
    $out.WriteUInt32([uint32]$fdataCnt)
    $out.WriteUInt32([uint32]$findicesOff)
    $out.WriteUInt32([uint32]$findicesCnt)
    $out.WriteUInt32([uint32]$lindicesOff)
    $out.WriteUInt32([uint32]$lindicesCnt)

    $out.WriteBytes($structData)
    $out.WriteBytes($fieldData)

    # Labels
    foreach ($lbl in $labelsList) {
        $bytes = [byte[]]::new(16)
        $src = [System.Text.Encoding]::ASCII.GetBytes($lbl)
        $copyLen = [Math]::Min($src.Length, 16)
        [System.Array]::Copy($src, $bytes, $copyLen)
        $out.WriteBytes($bytes)
    }

    $out.WriteBytes($fdataData)
    $out.WriteBytes($findicesData)
    $out.WriteBytes($lindicesData)

    $result = $out.ToArray()
    $out.Dispose()
    return $result
}

#endregion

#region ===== ERF =====

class ERFResource {
    [ResRef]       $ResRef
    [ResourceType] $ResType
    [byte[]]       $Data

    ERFResource([ResRef]$rr, [ResourceType]$rt, [byte[]]$data) {
        $this.ResRef  = $rr
        $this.ResType = $rt
        $this.Data    = $data
    }

    [string] ToString() { return "$($this.ResRef.Value).$($this.ResType.Extension)" }
}

class ERF {
    [System.Collections.Generic.List[ERFResource]] $Resources
    [ERFType] $ErfType
    [bool]    $IsSaveErf

    ERF() {
        $this.Resources = [System.Collections.Generic.List[ERFResource]]::new()
        $this.ErfType   = [ERFType]::ERF
        $this.IsSaveErf = $false
    }

    ERF([ERFType]$type) {
        $this.Resources = [System.Collections.Generic.List[ERFResource]]::new()
        $this.ErfType   = $type
        $this.IsSaveErf = $false
    }

    [int] Count() { return $this.Resources.Count }

    [void] SetData([string]$resname, [ResourceType]$restype, [byte[]]$data) {
        $rr = [ResRef]::new($resname)
        # Find existing
        for ($i = 0; $i -lt $this.Resources.Count; $i++) {
            $res = $this.Resources[$i]
            if ($res.ResRef.Value -eq $resname -and $res.ResType.TypeId -eq $restype.TypeId) {
                $res.Data = $data
                return
            }
        }
        $this.Resources.Add([ERFResource]::new($rr, $restype, $data))
    }

    [byte[]] Get([string]$resname, [ResourceType]$restype) {
        foreach ($res in $this.Resources) {
            if ($res.ResRef.Value -eq $resname -and $res.ResType.TypeId -eq $restype.TypeId) {
                return $res.Data
            }
        }
        return $null
    }

    [void] Remove([string]$resname, [ResourceType]$restype) {
        for ($i = $this.Resources.Count - 1; $i -ge 0; $i--) {
            $res = $this.Resources[$i]
            if ($res.ResRef.Value -eq $resname -and $res.ResType.TypeId -eq $restype.TypeId) {
                $this.Resources.RemoveAt($i)
            }
        }
    }

    [byte[]] ToBytes() { return Write-ERF -ERF $this }
    static [ERF] FromBytes([byte[]]$data) { return Read-ERF -Data $data }
}

function Read-ERF {
    [CmdletBinding()]
    param([byte[]]$Data)

    $r = [BinaryHelper]::new($Data)
    $fileType = $r.ReadString(4)
    $fileVersion = $r.ReadString(4)

    if ($fileVersion -ne 'V1.0') { throw "Unsupported ERF version: $fileVersion" }

    $erfType = [ERFType]::ERF
    if ($fileType -eq 'MOD ') { $erfType = [ERFType]::MOD }
    elseif ($fileType -ne 'ERF ') { throw "Invalid ERF file type: $fileType" }

    $erf = [ERF]::new($erfType)

    $r.SeekRelative(8)  # skip
    $entryCount = $r.ReadUInt32()
    $r.SeekRelative(4)  # skip
    $offsetToKeys = $r.ReadUInt32()
    $offsetToResources = $r.ReadUInt32()
    $r.SeekRelative(8)  # skip
    $descStrref = $r.ReadUInt32()

    if ($descStrref -eq 0 -and $erfType -eq [ERFType]::MOD) { $erf.IsSaveErf = $true }

    $resrefs = [System.Collections.Generic.List[string]]::new()
    $resids = [System.Collections.Generic.List[uint32]]::new()
    $restypes = [System.Collections.Generic.List[uint16]]::new()

    $r.Seek([int]$offsetToKeys)
    for ($i = 0; $i -lt $entryCount; $i++) {
        $rr = $r.ReadString(16).TrimEnd([char]0).ToLowerInvariant()
        $resrefs.Add($rr)
        $resids.Add($r.ReadUInt32())
        $restypes.Add($r.ReadUInt16())
        $r.SeekRelative(2)
    }

    $resoffsets = [System.Collections.Generic.List[uint32]]::new()
    $ressizes = [System.Collections.Generic.List[uint32]]::new()

    $r.Seek([int]$offsetToResources)
    for ($i = 0; $i -lt $entryCount; $i++) {
        $resoffsets.Add($r.ReadUInt32())
        $ressizes.Add($r.ReadUInt32())
    }

    for ($i = 0; $i -lt $entryCount; $i++) {
        $r.Seek([int]$resoffsets[$i])
        $resdata = $r.ReadBytes([int]$ressizes[$i])
        $rt = [ResourceType]::FromId([int]$restypes[$i])
        $erf.SetData($resrefs[$i], $rt, $resdata)
    }

    return $erf
}

function Write-ERF {
    [CmdletBinding()]
    param([ERF]$ERF)

    $b = [BinaryBuilder]::new()

    $fourCC = if ($ERF.ErfType -eq [ERFType]::MOD) { 'MOD ' } else { 'ERF ' }
    $b.WriteASCII($fourCC)
    $b.WriteASCII('V1.0')

    $entryCount = $ERF.Count()
    $headerSize = 160
    $offsetToKeys = $headerSize
    $keySize = 24  # 16+4+2+2
    $offsetToResInfo = $offsetToKeys + $entryCount * $keySize
    $resInfoSize = 8
    $offsetToResData = $offsetToResInfo + $entryCount * $resInfoSize

    $b.WriteUInt32(0)  # lang count
    $b.WriteUInt32(0)  # loc string size
    $b.WriteUInt32([uint32]$entryCount)
    $b.WriteUInt32([uint32]$offsetToKeys)
    $b.WriteUInt32([uint32]$offsetToKeys)
    $b.WriteUInt32([uint32]$offsetToResInfo)
    $b.WriteUInt32([uint32](Get-Date).Year)
    $b.WriteUInt32([uint32](Get-Date).DayOfYear)
    $b.WriteBytes([byte[]](0xFF,0xFF,0xFF,0xFF))  # desc strref

    # Pad to 160
    $written = 4+4+4+4+4+4+4+4+4+4+4  # 44 bytes
    $b.WriteZeros(160 - $written)

    # Keys
    $currentId = [uint32]0
    foreach ($res in $ERF.Resources) {
        $b.WritePaddedASCII($res.ResRef.Value, 16)
        $b.WriteUInt32($currentId)
        $b.WriteUInt16([uint16]$res.ResType.TypeId)
        $b.WriteUInt16(0)
        $currentId++
    }

    # Resource info
    $currentOffset = [uint32]$offsetToResData
    foreach ($res in $ERF.Resources) {
        $b.WriteUInt32($currentOffset)
        $b.WriteUInt32([uint32]$res.Data.Length)
        $currentOffset += [uint32]$res.Data.Length
    }

    # Resource data
    foreach ($res in $ERF.Resources) {
        $b.WriteBytes($res.Data)
    }

    $result = $b.ToArray()
    $b.Dispose()
    return $result
}

#endregion

#region ===== RIM =====

class RIMResource {
    [ResRef]       $ResRef
    [ResourceType] $ResType
    [byte[]]       $Data

    RIMResource([ResRef]$rr, [ResourceType]$rt, [byte[]]$data) {
        $this.ResRef  = $rr
        $this.ResType = $rt
        $this.Data    = $data
    }

    [string] ToString() { return "$($this.ResRef.Value).$($this.ResType.Extension)" }
}

class RIM {
    [System.Collections.Generic.List[RIMResource]] $Resources

    RIM() {
        $this.Resources = [System.Collections.Generic.List[RIMResource]]::new()
    }

    [int] Count() { return $this.Resources.Count }

    [void] SetData([string]$resname, [ResourceType]$restype, [byte[]]$data) {
        for ($i = 0; $i -lt $this.Resources.Count; $i++) {
            $res = $this.Resources[$i]
            if ($res.ResRef.Value -eq $resname -and $res.ResType.TypeId -eq $restype.TypeId) {
                $res.Data = $data
                return
            }
        }
        $this.Resources.Add([RIMResource]::new([ResRef]::new($resname), $restype, $data))
    }

    [byte[]] Get([string]$resname, [ResourceType]$restype) {
        foreach ($res in $this.Resources) {
            if ($res.ResRef.Value -eq $resname -and $res.ResType.TypeId -eq $restype.TypeId) {
                return $res.Data
            }
        }
        return $null
    }

    [void] Remove([string]$resname, [ResourceType]$restype) {
        for ($i = $this.Resources.Count - 1; $i -ge 0; $i--) {
            $res = $this.Resources[$i]
            if ($res.ResRef.Value -eq $resname -and $res.ResType.TypeId -eq $restype.TypeId) {
                $this.Resources.RemoveAt($i)
            }
        }
    }

    [byte[]] ToBytes() { return Write-RIM -RIM $this }
    static [RIM] FromBytes([byte[]]$data) { return Read-RIM -Data $data }
}

function Read-RIM {
    [CmdletBinding()]
    param([byte[]]$Data)

    $r = [BinaryHelper]::new($Data)
    $fileType = $r.ReadString(4)
    $fileVersion = $r.ReadString(4)

    if ($fileType -ne 'RIM ') { throw 'Invalid RIM file type' }
    if ($fileVersion -ne 'V1.0') { throw 'Unsupported RIM version' }

    $rim = [RIM]::new()
    $r.SeekRelative(4)  # skip
    $entryCount = $r.ReadUInt32()
    $offsetToKeys = $r.ReadUInt32()

    $resrefs = [System.Collections.Generic.List[string]]::new()
    $restypes = [System.Collections.Generic.List[uint32]]::new()
    $resoffsets = [System.Collections.Generic.List[uint32]]::new()
    $ressizes = [System.Collections.Generic.List[uint32]]::new()

    $r.Seek([int]$offsetToKeys)
    for ($i = 0; $i -lt $entryCount; $i++) {
        $rr = $r.ReadString(16).TrimEnd([char]0).ToLowerInvariant()
        $resrefs.Add($rr)
        $restypes.Add($r.ReadUInt32())
        [void]$r.ReadUInt32()  # resid
        $resoffsets.Add($r.ReadUInt32())
        $ressizes.Add($r.ReadUInt32())
    }

    for ($i = 0; $i -lt $entryCount; $i++) {
        $r.Seek([int]$resoffsets[$i])
        $resdata = $r.ReadBytes([int]$ressizes[$i])
        $rt = [ResourceType]::FromId([int]$restypes[$i])
        $rim.SetData($resrefs[$i], $rt, $resdata)
    }

    return $rim
}

function Write-RIM {
    [CmdletBinding()]
    param([RIM]$RIM)

    $b = [BinaryBuilder]::new()
    $b.WriteASCII('RIM ')
    $b.WriteASCII('V1.0')

    $entryCount = $RIM.Count()
    $offsetToKeys = 120

    $b.WriteUInt32(0)  # reserved
    $b.WriteUInt32([uint32]$entryCount)
    $b.WriteUInt32([uint32]$offsetToKeys)

    # Pad to 120 bytes: wrote 4+4+4+4+4 = 20 bytes
    $b.WriteZeros(100)

    # Calculate data offset
    $keySize = 32  # 16+4+4+4+4
    $offsetToData = $offsetToKeys + $entryCount * $keySize

    $currentOffset = [uint32]$offsetToData
    $currentId = [uint32]0
    foreach ($res in $RIM.Resources) {
        $b.WritePaddedASCII($res.ResRef.Value, 16)
        $b.WriteUInt32([uint32]$res.ResType.TypeId)
        $b.WriteUInt32($currentId)
        $b.WriteUInt32($currentOffset)
        $b.WriteUInt32([uint32]$res.Data.Length)
        $currentOffset += [uint32]$res.Data.Length
        $currentId++
    }

    foreach ($res in $RIM.Resources) {
        $b.WriteBytes($res.Data)
    }

    $result = $b.ToArray()
    $b.Dispose()
    return $result
}

#endregion

#region ===== SSF =====

class SSF {
    [int[]] $Sounds  # 28 entries, -1 = no sound

    SSF() {
        $this.Sounds = [int[]]::new(28)
        for ($i = 0; $i -lt 28; $i++) { $this.Sounds[$i] = -1 }
    }

    [void] SetData([SSFSound]$sound, [int]$stringref) {
        $this.Sounds[[int]$sound] = $stringref
    }

    [int] Get([SSFSound]$sound) {
        return $this.Sounds[[int]$sound]
    }

    [byte[]] ToBytes() { return Write-SSF -SSF $this }
    static [SSF] FromBytes([byte[]]$data) { return Read-SSF -Data $data }
}

function Read-SSF {
    [CmdletBinding()]
    param([byte[]]$Data)

    $r = [BinaryHelper]::new($Data)
    $fileType = $r.ReadString(4)
    $fileVersion = $r.ReadString(4)

    if ($fileType -ne 'SSF ') { throw 'Invalid SSF file' }
    if ($fileVersion -ne 'V1.1') { throw 'Unsupported SSF version' }

    $soundsOffset = $r.ReadUInt32()
    $r.Seek([int]$soundsOffset)

    $ssf = [SSF]::new()
    for ($i = 0; $i -lt 28; $i++) {
        $val = $r.ReadUInt32()
        if ($val -eq [uint32]::MaxValue) {
            $intVal = -1
        }
        elseif ($val -gt [uint32][int]::MaxValue) {
            throw "SSF stringref value $val exceeds Int32.MaxValue"
        }
        else {
            $intVal = [int]$val
        }
        $ssf.Sounds[$i] = $intVal
    }

    return $ssf
}

function Write-SSF {
    [CmdletBinding()]
    param([SSF]$SSF)

    $b = [BinaryBuilder]::new()
    $b.WriteASCII('SSF ')
    $b.WriteASCII('V1.1')
    $b.WriteUInt32(12)  # sounds offset

    for ($i = 0; $i -lt 28; $i++) {
        $val = $SSF.Sounds[$i]
        if ($val -eq -1) { $b.WriteBytes([byte[]](0xFF,0xFF,0xFF,0xFF)) }
        else { $b.WriteUInt32([uint32]$val) }
    }

    # 12 padding entries
    for ($i = 0; $i -lt 12; $i++) { $b.WriteBytes([byte[]](0xFF,0xFF,0xFF,0xFF)) }

    $result = $b.ToArray()
    $b.Dispose()
    return $result
}

#endregion

#region ===== INI Config Reader (changes.ini) =====

class PatcherMemory {
    [hashtable] $Memory2DA  # int -> string
    [hashtable] $MemoryStr  # int -> int

    PatcherMemory() {
        $this.Memory2DA = @{}
        $this.MemoryStr = @{}
    }
}

class Modification2DA {
    [string]    $FileName
    [bool]      $Replace
    [System.Collections.Generic.List[hashtable]] $AddRows
    [System.Collections.Generic.List[hashtable]] $ChangeRows
    [System.Collections.Generic.List[hashtable]] $CopyRows
    [System.Collections.Generic.List[hashtable]] $AddColumns

    Modification2DA([string]$fileName, [bool]$replace) {
        $this.FileName   = $fileName
        $this.Replace    = $replace
        $this.AddRows    = [System.Collections.Generic.List[hashtable]]::new()
        $this.ChangeRows = [System.Collections.Generic.List[hashtable]]::new()
        $this.CopyRows   = [System.Collections.Generic.List[hashtable]]::new()
        $this.AddColumns = [System.Collections.Generic.List[hashtable]]::new()
    }
}

class ModificationGFF {
    [string]    $FileName
    [bool]      $Replace
    [System.Collections.Generic.List[hashtable]] $Modifications

    ModificationGFF([string]$fileName, [bool]$replace) {
        $this.FileName      = $fileName
        $this.Replace       = $replace
        $this.Modifications = [System.Collections.Generic.List[hashtable]]::new()
    }
}

class ModificationTLK {
    [System.Collections.Generic.List[hashtable]] $Entries  # @{ StringRef; Text; SoundResref }

    ModificationTLK() {
        $this.Entries = [System.Collections.Generic.List[hashtable]]::new()
    }
}

class ModificationSSF {
    [string]    $FileName
    [System.Collections.Generic.List[hashtable]] $Modifications  # @{ Sound; StringRef }

    ModificationSSF([string]$fileName) {
        $this.FileName      = $fileName
        $this.Modifications = [System.Collections.Generic.List[hashtable]]::new()
    }
}

class PatcherConfig {
    [string]    $WindowTitle
    [string]    $ConfirmMessage
    [int]       $GameNumber
    [System.Collections.Generic.List[string]]           $RequiredFiles
    [System.Collections.Generic.List[string]]           $InstallList
    [System.Collections.Generic.List[Modification2DA]]  $TwoDAPatches
    [System.Collections.Generic.List[ModificationGFF]]  $GFFPatches
    [ModificationTLK]                                   $TLKPatch
    [System.Collections.Generic.List[ModificationSSF]]  $SSFPatches

    PatcherConfig() {
        $this.WindowTitle   = 'KPatcher'
        $this.ConfirmMessage = ''
        $this.GameNumber    = 1
        $this.RequiredFiles = [System.Collections.Generic.List[string]]::new()
        $this.InstallList   = [System.Collections.Generic.List[string]]::new()
        $this.TwoDAPatches  = [System.Collections.Generic.List[Modification2DA]]::new()
        $this.GFFPatches    = [System.Collections.Generic.List[ModificationGFF]]::new()
        $this.TLKPatch      = [ModificationTLK]::new()
        $this.SSFPatches    = [System.Collections.Generic.List[ModificationSSF]]::new()
    }
}

function Read-PatcherConfig {
    <#
    .SYNOPSIS
        Parses a TSLPatcher changes.ini file into a PatcherConfig object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $config = [PatcherConfig]::new()

    # Read and preprocess INI
    $rawLines = [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $rawLines) {
        $trimmed = $line.TrimStart()
        if ($trimmed.StartsWith(';') -or $trimmed.StartsWith('#') -or [string]::IsNullOrWhiteSpace($trimmed)) { continue }
        # Remove inline comments on section headers
        if ($trimmed.StartsWith('[')) {
            $commentIdx = $trimmed.IndexOf(';')
            if ($commentIdx -gt 0) { $trimmed = $trimmed.Substring(0, $commentIdx).TrimEnd() }
            $commentIdx = $trimmed.IndexOf('#')
            if ($commentIdx -gt 0) { $trimmed = $trimmed.Substring(0, $commentIdx).TrimEnd() }
        }
        $lines.Add($trimmed)
    }

    # Parse into sections
    $sections = [ordered]@{}
    $currentSection = $null
    foreach ($line in $lines) {
        if ($line -match '^\[([^\]]+)\]') {
            $currentSection = $Matches[1]
            if (-not $sections.Contains($currentSection)) {
                $sections[$currentSection] = [System.Collections.Generic.List[string]]::new()
            }
        }
        elseif ($null -ne $currentSection) {
            $sections[$currentSection].Add($line)
        }
    }

    # [Settings] section
    if ($sections.Contains('Settings')) {
        foreach ($line in $sections['Settings']) {
            if ($line -match '^WindowCaption\s*=\s*(.+)') {
                $val = $Matches[1]
                $semiIdx = $val.IndexOf(';')
                if ($semiIdx -ge 0) { $val = $val.Substring(0, $semiIdx) }
                $config.WindowTitle = $val.Trim()
            }
            elseif ($line -match '^ConfirmMessage\s*=\s*(.+)') {
                $val = $Matches[1]
                $semiIdx = $val.IndexOf(';')
                if ($semiIdx -ge 0) { $val = $val.Substring(0, $semiIdx) }
                $config.ConfirmMessage = $val.Trim()
            }
        }
    }

    # [TLKList] section
    if ($sections.Contains('TLKList')) {
        foreach ($line in $sections['TLKList']) {
            if ($line -match '^(\d+)\s*=\s*(.+)') {
                $parts = $Matches[2].Split(',', 2)
                $text = $parts[0].Trim()
                $sound = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }
                $config.TLKPatch.Entries.Add(@{
                    StringRef     = [int]$Matches[1]
                    Text          = $text
                    SoundResref   = $sound
                })
            }
        }
    }

    # [InstallList] section
    if ($sections.Contains('InstallList')) {
        foreach ($line in $sections['InstallList']) {
            if ($line -match '=\s*(.+)') {
                $config.InstallList.Add($Matches[1].Trim())
            }
        }
    }

    # [2DAList] section
    if ($sections.Contains('2DAList')) {
        foreach ($line in $sections['2DAList']) {
            if ($line -match '^(?:(\w):)?(.+)') {
                $prefix = $Matches[1]
                $fileName = $Matches[2].Trim()
                $replace = $prefix -eq 'b'
                $mod = [Modification2DA]::new($fileName, $replace)
                $config.TwoDAPatches.Add($mod)

                # Parse corresponding modification sections
                $addRowSec = "2DAMEMORY$($config.TwoDAPatches.Count - 1)"
                # Look for AddRow/ChangeRow sections specific to this file
            }
        }
    }

    # [GFFList] section
    if ($sections.Contains('GFFList')) {
        foreach ($line in $sections['GFFList']) {
            if ($line -match '^(?:(\w):)?(.+)') {
                $prefix = $Matches[1]
                $fileName = $Matches[2].Trim()
                $replace = $prefix -eq 'r'
                $mod = [ModificationGFF]::new($fileName, $replace)
                $config.GFFPatches.Add($mod)
            }
        }
    }

    # [SSFList] section
    if ($sections.Contains('SSFList')) {
        foreach ($line in $sections['SSFList']) {
            if ($line -match '=\s*(.+)') {
                $fileName = $Matches[1].Trim()
                $mod = [ModificationSSF]::new($fileName)
                $config.SSFPatches.Add($mod)
            }
        }
    }

    return $config
}

#endregion

#region ===== Patching Engine =====

function Install-KPatcherMod {
    <#
    .SYNOPSIS
        Installs a KOTOR mod using a changes.ini config.
    .PARAMETER ModPath
        Path to the mod's tslpatchdata directory.
    .PARAMETER GamePath
        Path to the KOTOR game directory.
    .PARAMETER ConfigPath
        Path to changes.ini. If not specified, looks in ModPath.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ModPath,
        [Parameter(Mandatory)][string]$GamePath,
        [string]$ConfigPath
    )

    # Resolve config path
    if (-not $ConfigPath) {
        $ConfigPath = Join-Path $ModPath 'changes.ini'
        if (-not (Test-Path $ConfigPath)) {
            $ConfigPath = Join-Path $ModPath 'tslpatchdata' 'changes.ini'
        }
    }

    if (-not (Test-Path $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }

    $config = Read-PatcherConfig -Path $ConfigPath
    $memory = [PatcherMemory]::new()
    $overridePath = Join-Path $GamePath 'Override'

    if (-not (Test-Path $overridePath)) {
        [void](New-Item -ItemType Directory -Path $overridePath -Force)
    }

    # Backup
    $backupDir = Join-Path $GamePath "backup" (Get-Date -Format 'yyyy-MM-dd_HH.mm.ss')
    [void](New-Item -ItemType Directory -Path $backupDir -Force)

    Write-Verbose "Installing mod: $($config.WindowTitle)"

    # Install copied files
    foreach ($file in $config.InstallList) {
        $src = Join-Path $ModPath $file
        if (Test-Path $src) {
            $dst = Join-Path $overridePath $file
            # Backup if exists
            if (Test-Path $dst) {
                Copy-Item $dst (Join-Path $backupDir $file) -Force
            }
            Copy-Item $src $dst -Force
            Write-Verbose "Copied: $file"
        }
    }

    # Apply TLK patches
    if ($config.TLKPatch.Entries.Count -gt 0) {
        $tlkPath = Join-Path $GamePath 'dialog.tlk'
        if (Test-Path $tlkPath) {
            $tlkData = [System.IO.File]::ReadAllBytes($tlkPath)
            Copy-Item $tlkPath (Join-Path $backupDir 'dialog.tlk') -Force
            $tlk = [TLK]::FromBytes($tlkData)

            foreach ($entry in $config.TLKPatch.Entries) {
                $strRef = $entry.StringRef
                if ($strRef -ge $tlk.Count()) {
                    $tlk.Resize($strRef + 1)
                }
                $tlk.Replace($strRef, $entry.Text, $entry.SoundResref)
                Write-Verbose "TLK: Modified stringref $strRef"
            }

            $newTlkData = $tlk.ToBytes()
            [System.IO.File]::WriteAllBytes($tlkPath, $newTlkData)
        }
    }

    Write-Verbose "Mod installation complete."
    return @{ BackupDir = $backupDir; Config = $config }
}

#endregion

#region ===== Exports =====

# Export all public functions
Export-ModuleMember -Function @(
    'Read-TwoDA', 'Write-TwoDA',
    'Read-TLK', 'Write-TLK',
    'Read-GFF', 'Write-GFF',
    'Read-ERF', 'Write-ERF',
    'Read-RIM', 'Write-RIM',
    'Read-SSF', 'Write-SSF',
    'Read-PatcherConfig',
    'Install-KPatcherMod'
)

#endregion
