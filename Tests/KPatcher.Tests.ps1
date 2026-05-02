using module '..\KPatcher.psm1'
#Requires -Version 5.1
<#
.SYNOPSIS
    Comprehensive Pester tests for KPatcher PowerShell module.
    All test data is constructed ephemerally in memory - zero external file dependencies.
#>

# PowerShell classes require 'using module' for parse-time type resolution.
# The using statement above makes all classes (ResRef, GFF, TLK, etc.) visible.

Describe 'Common Types' {

    Context 'ResRef' {
        It 'creates with valid string' {
            $rr = [ResRef]::new('test_resref')
            $rr.Value | Should -Be 'test_resref'
        }

        It 'trims whitespace' {
            $rr = [ResRef]::new('  hello  ')
            $rr.Value | Should -Be 'hello'
        }

        It 'allows blank' {
            $rr = [ResRef]::Blank()
            $rr.Value | Should -Be ''
        }

        It 'throws on >16 characters' {
            { [ResRef]::new('12345678901234567') } | Should -Throw
        }

        It 'allows exactly 16 characters' {
            $rr = [ResRef]::new('1234567890123456')
            $rr.Value | Should -Be '1234567890123456'
        }

        It 'equality is case-insensitive' {
            $a = [ResRef]::new('Test')
            $b = [ResRef]::new('test')
            $a.Equals($b) | Should -BeTrue
        }

        It 'ToString returns value' {
            $rr = [ResRef]::new('myres')
            "$rr" | Should -Be 'myres'
        }
    }

    Context 'LocalizedString' {
        It 'creates with stringref' {
            $ls = [LocalizedString]::new(42)
            $ls.StringRef | Should -Be 42
            $ls.Substrings.Count | Should -Be 0
        }

        It 'creates from English text' {
            $ls = [LocalizedString]::FromEnglish('Hello World')
            $ls.StringRef | Should -Be -1
            $id = [LocalizedString]::SubstringId([KLanguage]::English, [Gender]::Male)
            $ls.Substrings[$id] | Should -Be 'Hello World'
        }

        It 'creates invalid' {
            $ls = [LocalizedString]::FromInvalid()
            $ls.StringRef | Should -Be -1
        }

        It 'Get/SetData round-trips' {
            $ls = [LocalizedString]::new(-1)
            $ls.SetData([KLanguage]::French, [Gender]::Female, 'Bonjour')
            $ls.Get([KLanguage]::French, [Gender]::Female) | Should -Be 'Bonjour'
            $ls.Get([KLanguage]::English, [Gender]::Male) | Should -BeNullOrEmpty
        }

        It 'SubstringId computes correctly' {
            [LocalizedString]::SubstringId([KLanguage]::English, [Gender]::Male) | Should -Be 0
            [LocalizedString]::SubstringId([KLanguage]::English, [Gender]::Female) | Should -Be 1
            [LocalizedString]::SubstringId([KLanguage]::French, [Gender]::Male) | Should -Be 2
        }

        It 'equality works' {
            $a = [LocalizedString]::FromEnglish('same')
            $b = [LocalizedString]::FromEnglish('same')
            $a.Equals($b) | Should -BeTrue
        }
    }

    Context 'Vector3' {
        It 'default is zero' {
            $v = [Vector3]::new()
            $v.X | Should -Be 0
            $v.Y | Should -Be 0
            $v.Z | Should -Be 0
        }

        It 'stores values' {
            $v = [Vector3]::new(1.5, 2.5, 3.5)
            $v.X | Should -Be 1.5
            $v.Y | Should -Be 2.5
            $v.Z | Should -Be 3.5
        }

        It 'equality works' {
            $a = [Vector3]::new(1, 2, 3)
            $b = [Vector3]::new(1, 2, 3)
            $a.Equals($b) | Should -BeTrue
        }
    }

    Context 'Vector4' {
        It 'stores values' {
            $v = [Vector4]::new(1, 2, 3, 4)
            $v.X | Should -Be 1
            $v.W | Should -Be 4
        }
    }

    Context 'ResourceType' {
        It 'FromId returns known type' {
            $rt = [ResourceType]::FromId(2058)
            $rt.Extension | Should -Be '2da'
        }

        It 'FromExtension returns known type' {
            $rt = [ResourceType]::FromExtension('utc')
            $rt.TypeId | Should -BeIn @(2033, 2065)
        }

        It 'unknown id returns fallback' {
            $rt = [ResourceType]::FromId(99999)
            $rt.Extension | Should -Be 'unknown'
        }
    }
}

Describe 'BinaryHelper' {

    Context 'Read operations' {
        It 'reads UInt32' {
            $bytes = [System.BitConverter]::GetBytes([uint32]305419896)  # 0x12345678
            $r = [BinaryHelper]::new($bytes)
            $r.ReadUInt32() | Should -Be 305419896
        }

        It 'reads Int32' {
            $bytes = [System.BitConverter]::GetBytes([int]-42)
            $r = [BinaryHelper]::new($bytes)
            $r.ReadInt32() | Should -Be -42
        }

        It 'reads Single' {
            $bytes = [System.BitConverter]::GetBytes([float]3.14)
            $r = [BinaryHelper]::new($bytes)
            [Math]::Round($r.ReadSingle(), 2) | Should -Be 3.14
        }

        It 'reads string' {
            $bytes = [System.Text.Encoding]::ASCII.GetBytes('HELLO')
            $r = [BinaryHelper]::new($bytes)
            $r.ReadString(5) | Should -Be 'HELLO'
        }

        It 'Seek moves position' {
            $bytes = [byte[]](1, 2, 3, 4, 5, 6, 7, 8)
            $r = [BinaryHelper]::new($bytes)
            $r.Seek(4)
            $r.ReadUInt8() | Should -Be 5
        }

        It 'throws on read past end' {
            $r = [BinaryHelper]::new([byte[]](1, 2))
            { $r.ReadBytes(10) } | Should -Throw
        }

        It 'ReadTerminatedString works' {
            $bytes = [System.Text.Encoding]::ASCII.GetBytes("hello`t")
            $r = [BinaryHelper]::new($bytes)
            $r.ReadTerminatedString("`t") | Should -Be 'hello'
        }
    }

    Context 'BinaryBuilder' {
        It 'writes and reads UInt32 roundtrip' {
            $b = [BinaryBuilder]::new()
            $b.WriteUInt32(12345)
            $data = $b.ToArray()
            $b.Dispose()
            $data.Length | Should -Be 4
            [System.BitConverter]::ToUInt32($data, 0) | Should -Be 12345
        }

        It 'writes ASCII string' {
            $b = [BinaryBuilder]::new()
            $b.WriteASCII('TEST')
            $data = $b.ToArray()
            $b.Dispose()
            [System.Text.Encoding]::ASCII.GetString($data) | Should -Be 'TEST'
        }

        It 'WritePaddedASCII pads with nulls' {
            $b = [BinaryBuilder]::new()
            $b.WritePaddedASCII('Hi', 8)
            $data = $b.ToArray()
            $b.Dispose()
            $data.Length | Should -Be 8
            $data[0] | Should -Be ([byte][char]'H')
            $data[1] | Should -Be ([byte][char]'i')
            $data[2] | Should -Be 0
        }
    }
}

Describe 'TwoDA Format' {

    Context 'TwoDA class' {
        It 'creates empty' {
            $t = [TwoDA]::new()
            $t.GetHeight() | Should -Be 0
            $t.GetWidth() | Should -Be 0
        }

        It 'adds columns' {
            $t = [TwoDA]::new()
            $t.AddColumn('Name')
            $t.AddColumn('Value')
            $t.GetWidth() | Should -Be 2
        }

        It 'throws on duplicate column' {
            $t = [TwoDA]::new()
            $t.AddColumn('Col')
            { $t.AddColumn('Col') } | Should -Throw
        }

        It 'adds rows' {
            $t = [TwoDA]::new(@('A', 'B'))
            $t.AddRow('0')
            $t.AddRow('1')
            $t.GetHeight() | Should -Be 2
        }

        It 'sets and gets cell values' {
            $t = [TwoDA]::new(@('Name', 'HP'))
            $t.AddRow('0')
            $t.SetCell(0, 'Name', 'Warrior')
            $t.SetCell(0, 'HP', '100')
            $t.GetCell(0, 'Name') | Should -Be 'Warrior'
            $t.GetCell(0, 'HP') | Should -Be '100'
        }

        It 'GetCellInt works' {
            $t = [TwoDA]::new(@('Val'))
            $t.AddRow('0')
            $t.SetCell(0, 'Val', '42')
            $t.GetCellInt(0, 'Val') | Should -Be 42
        }

        It 'GetCellInt returns null for ****' {
            $t = [TwoDA]::new(@('Val'))
            $t.AddRow('0')
            $t.SetCell(0, 'Val', '****')
            $t.GetCellInt(0, 'Val') | Should -BeNullOrEmpty
        }

        It 'CopyRow duplicates correctly' {
            $t = [TwoDA]::new(@('A'))
            $t.AddRow('0')
            $t.SetCell(0, 'A', 'original')
            $newIdx = $t.CopyRow(0, '1')
            $t.GetCell($newIdx, 'A') | Should -Be 'original'
            $t.GetHeight() | Should -Be 2
        }

        It 'RemoveRow works' {
            $t = [TwoDA]::new(@('X'))
            $t.AddRow('0')
            $t.AddRow('1')
            $t.RemoveRow(0)
            $t.GetHeight() | Should -Be 1
            $t.Labels[0] | Should -Be '1'
        }

        It 'LabelMax returns next integer' {
            $t = [TwoDA]::new(@('A'))
            $t.AddRow('0')
            $t.AddRow('5')
            $t.AddRow('3')
            $t.LabelMax() | Should -Be 6
        }

        It 'GetRowIndex finds by label' {
            $t = [TwoDA]::new(@('Col'))
            $t.AddRow('alpha')
            $t.AddRow('beta')
            $t.GetRowIndex('beta') | Should -Be 1
        }

        It 'GetRowIndex throws for missing label' {
            $t = [TwoDA]::new(@('Col'))
            $t.AddRow('only')
            { $t.GetRowIndex('missing') } | Should -Throw
        }

        It 'AddRowWithCells populates cells' {
            $t = [TwoDA]::new(@('Name', 'Level'))
            $idx = $t.AddRowWithCells('0', @{ Name = 'Jedi'; Level = '20' })
            $t.GetCell($idx, 'Name') | Should -Be 'Jedi'
            $t.GetCell($idx, 'Level') | Should -Be '20'
        }
    }

    Context 'Binary round-trip' {
        It 'empty 2DA round-trips' {
            $t = [TwoDA]::new(@('Col1', 'Col2'))
            $bytes = Write-TwoDA -TwoDA $t
            $t2 = Read-TwoDA -Data $bytes
            $t2.GetWidth() | Should -Be 2
            $t2.GetHeight() | Should -Be 0
            $t2.Headers[0] | Should -Be 'Col1'
            $t2.Headers[1] | Should -Be 'Col2'
        }

        It 'populated 2DA round-trips' {
            $t = [TwoDA]::new(@('label', 'dialog', 'appearance'))
            $t.AddRow('0')
            $t.SetCell(0, 'label', 'Bastila')
            $t.SetCell(0, 'dialog', 'bastila')
            $t.SetCell(0, 'appearance', '4')

            $t.AddRow('1')
            $t.SetCell(1, 'label', 'Carth')
            $t.SetCell(1, 'dialog', 'carth')
            $t.SetCell(1, 'appearance', '7')

            $bytes = Write-TwoDA -TwoDA $t
            $t2 = Read-TwoDA -Data $bytes

            $t2.GetHeight() | Should -Be 2
            $t2.GetWidth()  | Should -Be 3
            $t2.GetCell(0, 'label') | Should -Be 'Bastila'
            $t2.GetCell(1, 'dialog') | Should -Be 'carth'
            $t2.GetCell(1, 'appearance') | Should -Be '7'
            $t2.Labels[0] | Should -Be '0'
            $t2.Labels[1] | Should -Be '1'
        }

        It 'validates header: rejects invalid file type' {
            $badData = [System.Text.Encoding]::ASCII.GetBytes('BAD V2.b')
            { Read-TwoDA -Data $badData } | Should -Throw
        }

        It 'validates version' {
            $badData = [System.Text.Encoding]::ASCII.GetBytes('2DA V9.9')
            { Read-TwoDA -Data $badData } | Should -Throw
        }

        It 'handles empty cell values' {
            $t = [TwoDA]::new(@('A'))
            $t.AddRow('0')
            $t.SetCell(0, 'A', '')
            $bytes = Write-TwoDA -TwoDA $t
            $t2 = Read-TwoDA -Data $bytes
            $t2.GetCell(0, 'A') | Should -Be ''
        }

        It 'deduplicates identical cell values' {
            $t = [TwoDA]::new(@('A', 'B'))
            $t.AddRow('0')
            $t.SetCell(0, 'A', 'same')
            $t.SetCell(0, 'B', 'same')
            $t.AddRow('1')
            $t.SetCell(1, 'A', 'same')
            $t.SetCell(1, 'B', 'different')

            $bytes = Write-TwoDA -TwoDA $t
            $t2 = Read-TwoDA -Data $bytes
            $t2.GetCell(0, 'A') | Should -Be 'same'
            $t2.GetCell(0, 'B') | Should -Be 'same'
            $t2.GetCell(1, 'A') | Should -Be 'same'
            $t2.GetCell(1, 'B') | Should -Be 'different'
        }

        It 'handles many rows' {
            $t = [TwoDA]::new(@('Index', 'Name'))
            for ($i = 0; $i -lt 50; $i++) {
                $t.AddRow("$i")
                $t.SetCell($i, 'Index', "$i")
                $t.SetCell($i, 'Name', "item_$i")
            }

            $bytes = Write-TwoDA -TwoDA $t
            $t2 = Read-TwoDA -Data $bytes

            $t2.GetHeight() | Should -Be 50
            $t2.GetCell(0, 'Name') | Should -Be 'item_0'
            $t2.GetCell(49, 'Name') | Should -Be 'item_49'
        }
    }
}

Describe 'TLK Format' {

    Context 'TLK class' {
        It 'creates empty' {
            $t = [TLK]::new()
            $t.Count() | Should -Be 0
            $t.Language | Should -Be ([KLanguage]::English)
        }

        It 'adds entries' {
            $t = [TLK]::new()
            $idx = $t.Add('Hello', '')
            $idx | Should -Be 0
            $t.Count() | Should -Be 1
            $t.String(0) | Should -Be 'Hello'
        }

        It 'replaces entries' {
            $t = [TLK]::new()
            $t.Add('Original', 'snd_orig')
            $t.Replace(0, 'Modified', 'snd_mod')
            $t.String(0) | Should -Be 'Modified'
        }

        It 'replace with empty text keeps original' {
            $t = [TLK]::new()
            $t.Add('Keep Me', '')
            $t.Replace(0, '', '')
            $t.String(0) | Should -Be 'Keep Me'
        }

        It 'resizes up' {
            $t = [TLK]::new()
            $t.Resize(5)
            $t.Count() | Should -Be 5
            $t.String(0) | Should -Be ''
            $t.String(4) | Should -Be ''
        }

        It 'resizes down' {
            $t = [TLK]::new()
            $t.Add('a', '')
            $t.Add('b', '')
            $t.Add('c', '')
            $t.Resize(1)
            $t.Count() | Should -Be 1
            $t.String(0) | Should -Be 'a'
        }

        It 'Get returns null for out of range' {
            $t = [TLK]::new()
            $t.Get(-1) | Should -BeNullOrEmpty
            $t.Get(100) | Should -BeNullOrEmpty
        }

        It 'Replace throws for out of range' {
            $t = [TLK]::new()
            { $t.Replace(0, 'x', '') } | Should -Throw
        }
    }

    Context 'Binary round-trip' {
        It 'empty TLK round-trips' {
            $t = [TLK]::new([KLanguage]::English)
            $bytes = Write-TLK -TLK $t
            $t2 = Read-TLK -Data $bytes
            $t2.Count() | Should -Be 0
            $t2.Language | Should -Be ([KLanguage]::English)
        }

        It 'TLK with entries round-trips' {
            $t = [TLK]::new([KLanguage]::English)
            $t.Add('Hello World', 'greeting')
            $t.Add('Goodbye World', 'farewell')
            $t.Add('', '')

            $bytes = Write-TLK -TLK $t
            $t2 = Read-TLK -Data $bytes

            $t2.Count() | Should -Be 3
            $t2.String(0) | Should -Be 'Hello World'
            $t2.String(1) | Should -Be 'Goodbye World'
            $t2.String(2) | Should -Be ''
            $t2.Entries[0].Voiceover.Value | Should -Be 'greeting'
            $t2.Entries[1].Voiceover.Value | Should -Be 'farewell'
        }

        It 'validates header' {
            $badData = [System.Text.Encoding]::ASCII.GetBytes('BAD V3.0') + [byte[]]::new(20)
            { Read-TLK -Data $badData } | Should -Throw
        }

        It 'preserves language' {
            $t = [TLK]::new([KLanguage]::French)
            $t.Add('Bonjour', '')
            $bytes = Write-TLK -TLK $t
            $t2 = Read-TLK -Data $bytes
            $t2.Language | Should -Be ([KLanguage]::French)
        }

        It 'entry flags roundtrip' {
            $t = [TLK]::new()
            $entry = [TLKEntry]::new('text', [ResRef]::new('sound'))
            $entry.TextPresent = $true
            $entry.SoundPresent = $true
            $entry.SoundLengthPresent = $false
            $t.Entries.Add($entry)

            $bytes = Write-TLK -TLK $t
            $t2 = Read-TLK -Data $bytes
            $t2.Entries[0].TextPresent | Should -BeTrue
            $t2.Entries[0].SoundPresent | Should -BeTrue
            $t2.Entries[0].SoundLengthPresent | Should -BeFalse
        }

        It 'handles many entries' {
            $t = [TLK]::new()
            for ($i = 0; $i -lt 100; $i++) {
                $t.Add("Entry number $i", '')
            }

            $bytes = Write-TLK -TLK $t
            $t2 = Read-TLK -Data $bytes

            $t2.Count() | Should -Be 100
            $t2.String(0) | Should -Be 'Entry number 0'
            $t2.String(99) | Should -Be 'Entry number 99'
        }
    }
}

Describe 'GFF Format' {

    Context 'GFFStruct' {
        It 'creates with structId' {
            $gs = [GFFStruct]::new(42)
            $gs.StructId | Should -Be 42
            $gs.Count() | Should -Be 0
        }

        It 'sets and gets UInt8' {
            $gs = [GFFStruct]::new()
            $gs.SetUInt8('Level', 20)
            $gs.GetUInt8('Level') | Should -Be 20
        }

        It 'sets and gets Int32' {
            $gs = [GFFStruct]::new()
            $gs.SetInt32('HP', -10)
            $gs.GetInt32('HP') | Should -Be -10
        }

        It 'sets and gets UInt32' {
            $gs = [GFFStruct]::new()
            $gs.SetUInt32('Flags', 0xDEAD)
            $gs.GetUInt32('Flags') | Should -Be 0xDEAD
        }

        It 'sets and gets Single' {
            $gs = [GFFStruct]::new()
            $gs.SetSingle('Speed', [float]3.14)
            [Math]::Round($gs.GetSingle('Speed'), 2) | Should -Be 3.14
        }

        It 'sets and gets String' {
            $gs = [GFFStruct]::new()
            $gs.SetString('Name', 'Bastila')
            $gs.GetString('Name') | Should -Be 'Bastila'
        }

        It 'sets and gets ResRef' {
            $gs = [GFFStruct]::new()
            $gs.SetResRef('Dialog', [ResRef]::new('bastila'))
            $gs.GetResRef('Dialog').Value | Should -Be 'bastila'
        }

        It 'sets and gets LocalizedString' {
            $gs = [GFFStruct]::new()
            $ls = [LocalizedString]::FromEnglish('Greeting')
            $gs.SetLocString('FirstName', $ls)
            $result = $gs.GetLocString('FirstName')
            $result.Get([KLanguage]::English, [Gender]::Male) | Should -Be 'Greeting'
        }

        It 'sets and gets Binary' {
            $gs = [GFFStruct]::new()
            $gs.SetBinary('Data', [byte[]](1, 2, 3, 4))
            $result = $gs.GetBinary('Data')
            $result.Length | Should -Be 4
            $result[0] | Should -Be 1
            $result[3] | Should -Be 4
        }

        It 'sets and gets Vector3' {
            $gs = [GFFStruct]::new()
            $gs.SetVector3('Position', [Vector3]::new(1, 2, 3))
            $v = $gs.GetVector3('Position')
            $v.X | Should -Be 1
            $v.Y | Should -Be 2
            $v.Z | Should -Be 3
        }

        It 'sets and gets Vector4' {
            $gs = [GFFStruct]::new()
            $gs.SetVector4('Orientation', [Vector4]::new(0, 0, 0, 1))
            $v = $gs.GetVector4('Orientation')
            $v.W | Should -Be 1
        }

        It 'Exists checks field presence' {
            $gs = [GFFStruct]::new()
            $gs.SetInt32('X', 1)
            $gs.Exists('X') | Should -BeTrue
            $gs.Exists('Y') | Should -BeFalse
        }

        It 'Remove removes field' {
            $gs = [GFFStruct]::new()
            $gs.SetInt32('X', 1)
            $gs.Remove('X')
            $gs.Exists('X') | Should -BeFalse
            $gs.Count() | Should -Be 0
        }

        It 'GetFieldType returns correct type' {
            $gs = [GFFStruct]::new()
            $gs.SetString('Name', 'test')
            $gs.GetFieldType('Name') | Should -Be ([GFFFieldType]::String)
        }

        It 'GetValue returns null for missing' {
            $gs = [GFFStruct]::new()
            $gs.GetValue('Missing') | Should -BeNullOrEmpty
        }

        It 'nested structs work' {
            $gs = [GFFStruct]::new()
            $child = [GFFStruct]::new(1)
            $child.SetInt32('Value', 42)
            $gs.SetStruct('Child', $child)

            $retrieved = $gs.GetStruct('Child')
            $retrieved.StructId | Should -Be 1
            $retrieved.GetInt32('Value') | Should -Be 42
        }

        It 'GFFList works' {
            $gs = [GFFStruct]::new()
            $list = [GFFList]::new()
            $item1 = [GFFStruct]::new(0)
            $item1.SetString('Name', 'First')
            $list.AddStruct($item1)
            $item2 = [GFFStruct]::new(0)
            $item2.SetString('Name', 'Second')
            $list.AddStruct($item2)

            $gs.SetList('Items', $list)
            $retrieved = $gs.GetList('Items')
            $retrieved.Count() | Should -Be 2
            $retrieved.At(0).GetString('Name') | Should -Be 'First'
            $retrieved.At(1).GetString('Name') | Should -Be 'Second'
        }
    }

    Context 'GFF class' {
        It 'creates with default content' {
            $gff = [GFF]::new()
            $gff.Content | Should -Be ([GFFContent]::GFF)
            $gff.Root.StructId | Should -Be -1
        }

        It 'creates with specific content' {
            $gff = [GFF]::new([GFFContent]::UTC)
            $gff.Content | Should -Be ([GFFContent]::UTC)
        }
    }

    Context 'Binary round-trip' {
        It 'empty root struct round-trips' {
            $gff = [GFF]::new([GFFContent]::UTC)
            $bytes = Write-GFF -GFF $gff
            $gff2 = Read-GFF -Data $bytes
            $gff2.Content | Should -Be ([GFFContent]::UTC)
            $gff2.Root.StructId | Should -Be -1
            $gff2.Root.Count() | Should -Be 0
        }

        It 'single field roundtrips' {
            $gff = [GFF]::new([GFFContent]::UTC)
            $gff.Root.SetInt32('HitPoints', 100)

            $bytes = Write-GFF -GFF $gff
            $gff2 = Read-GFF -Data $bytes

            $gff2.Root.GetInt32('HitPoints') | Should -Be 100
        }

        It 'multiple simple fields roundtrip' {
            $gff = [GFF]::new([GFFContent]::UTI)
            $gff.Root.SetUInt8('BaseItem', 5)
            $gff.Root.SetUInt16('MaxCharges', 10)
            $gff.Root.SetInt32('Cost', 500)
            $gff.Root.SetSingle('Weight', [float]2.5)

            $bytes = Write-GFF -GFF $gff
            $gff2 = Read-GFF -Data $bytes

            $gff2.Root.GetUInt8('BaseItem') | Should -Be 5
            $gff2.Root.GetUInt16('MaxCharges') | Should -Be 10
            $gff2.Root.GetInt32('Cost') | Should -Be 500
            [Math]::Round($gff2.Root.GetSingle('Weight'), 1) | Should -Be 2.5
        }

        It 'complex types roundtrip' {
            $gff = [GFF]::new([GFFContent]::UTC)
            $gff.Root.SetString('Tag', 'npc_bastila')
            $gff.Root.SetResRef('TemplateResRef', [ResRef]::new('p_bastila'))
            $gff.Root.SetLocString('FirstName', [LocalizedString]::FromEnglish('Bastila'))
            $gff.Root.SetBinary('Portrait', [byte[]](0x89, 0x50, 0x4E, 0x47))

            $bytes = Write-GFF -GFF $gff
            $gff2 = Read-GFF -Data $bytes

            $gff2.Root.GetString('Tag') | Should -Be 'npc_bastila'
            $gff2.Root.GetResRef('TemplateResRef').Value | Should -Be 'p_bastila'
            $gff2.Root.GetLocString('FirstName').Get([KLanguage]::English, [Gender]::Male) | Should -Be 'Bastila'
            $bin = $gff2.Root.GetBinary('Portrait')
            $bin.Length | Should -Be 4
            $bin[0] | Should -Be 0x89
        }

        It 'UInt64 and Int64 roundtrip' {
            $gff = [GFF]::new([GFFContent]::GFF)
            $gff.Root.SetUInt64('BigNum', [uint64]1234567890123)
            $gff.Root.SetInt64('NegNum', [long]-9876543210)

            $bytes = Write-GFF -GFF $gff
            $gff2 = Read-GFF -Data $bytes

            $gff2.Root.GetUInt64('BigNum') | Should -Be ([uint64]1234567890123)
            $gff2.Root.GetInt64('NegNum') | Should -Be ([long]-9876543210)
        }

        It 'Double roundtrips' {
            $gff = [GFF]::new([GFFContent]::GFF)
            $gff.Root.SetDouble('Ratio', 3.141592653589793)

            $bytes = Write-GFF -GFF $gff
            $gff2 = Read-GFF -Data $bytes

            $gff2.Root.GetDouble('Ratio') | Should -Be 3.141592653589793
        }

        It 'Vector3 and Vector4 roundtrip' {
            $gff = [GFF]::new([GFFContent]::GIT)
            $gff.Root.SetVector3('Position', [Vector3]::new(1.5, 2.5, 3.5))
            $gff.Root.SetVector4('Orientation', [Vector4]::new(0.1, 0.2, 0.3, 0.9))

            $bytes = Write-GFF -GFF $gff
            $gff2 = Read-GFF -Data $bytes

            $v3 = $gff2.Root.GetVector3('Position')
            $v3.X | Should -Be ([float]1.5)
            $v3.Y | Should -Be ([float]2.5)
            $v3.Z | Should -Be ([float]3.5)

            $v4 = $gff2.Root.GetVector4('Orientation')
            [Math]::Round($v4.X, 1) | Should -Be 0.1
            [Math]::Round($v4.W, 1) | Should -Be 0.9
        }

        It 'nested struct roundtrips' {
            $gff = [GFF]::new([GFFContent]::UTC)
            $gff.Root.SetString('Name', 'Parent')
            $child = [GFFStruct]::new(1)
            $child.SetString('SubName', 'Child')
            $child.SetInt32('SubValue', 42)
            $gff.Root.SetStruct('SubStruct', $child)

            $bytes = Write-GFF -GFF $gff
            $gff2 = Read-GFF -Data $bytes

            $gff2.Root.GetString('Name') | Should -Be 'Parent'
            $sub = $gff2.Root.GetStruct('SubStruct')
            $sub.StructId | Should -Be 1
            $sub.GetString('SubName') | Should -Be 'Child'
            $sub.GetInt32('SubValue') | Should -Be 42
        }

        It 'GFFList roundtrips' {
            $gff = [GFF]::new([GFFContent]::UTC)
            $list = [GFFList]::new()
            for ($i = 0; $i -lt 3; $i++) {
                $item = [GFFStruct]::new($i)
                $item.SetInt32('Index', $i)
                $item.SetString('Label', "item_$i")
                $list.AddStruct($item)
            }
            $gff.Root.SetList('ItemList', $list)

            $bytes = Write-GFF -GFF $gff
            $gff2 = Read-GFF -Data $bytes

            $list2 = $gff2.Root.GetList('ItemList')
            $list2.Count() | Should -Be 3
            $list2.At(0).StructId | Should -Be 0
            $list2.At(0).GetInt32('Index') | Should -Be 0
            $list2.At(0).GetString('Label') | Should -Be 'item_0'
            $list2.At(2).GetInt32('Index') | Should -Be 2
            $list2.At(2).GetString('Label') | Should -Be 'item_2'
        }

        It 'deeply nested structure roundtrips' {
            $gff = [GFF]::new([GFFContent]::DLG)

            # Create a dialog-like structure
            $entryList = [GFFList]::new()
            $entry = [GFFStruct]::new(0)
            $entry.SetLocString('Text', [LocalizedString]::FromEnglish('Hello there'))
            $entry.SetInt32('Speaker', 0)

            $replyList = [GFFList]::new()
            $reply = [GFFStruct]::new(0)
            $reply.SetInt32('Index', 0)
            $replyList.AddStruct($reply)
            $entry.SetList('RepliesList', $replyList)

            $entryList.AddStruct($entry)
            $gff.Root.SetList('EntryList', $entryList)

            $bytes = Write-GFF -GFF $gff
            $gff2 = Read-GFF -Data $bytes

            $entries = $gff2.Root.GetList('EntryList')
            $entries.Count() | Should -Be 1
            $e = $entries.At(0)
            $e.GetLocString('Text').Get([KLanguage]::English, [Gender]::Male) | Should -Be 'Hello there'
            $replies = $e.GetList('RepliesList')
            $replies.Count() | Should -Be 1
            $replies.At(0).GetInt32('Index') | Should -Be 0
        }

        It 'different GFF content types preserve fourCC' {
            foreach ($contentType in @([GFFContent]::UTC, [GFFContent]::UTI, [GFFContent]::DLG, [GFFContent]::ARE)) {
                $gff = [GFF]::new($contentType)
                $gff.Root.SetInt32('Test', 1)
                $bytes = Write-GFF -GFF $gff
                $gff2 = Read-GFF -Data $bytes
                $gff2.Content | Should -Be $contentType -Because "Content type $contentType should roundtrip"
            }
        }

        It 'validates version' {
            # Build a minimal invalid GFF header
            $b = [BinaryBuilder]::new()
            $b.WriteASCII('GFF ')
            $b.WriteASCII('V9.9')
            $b.WriteZeros(48)
            $badData = $b.ToArray()
            $b.Dispose()
            { Read-GFF -Data $badData } | Should -Throw
        }

        It 'handles LocalizedString with multiple substrings' {
            $gff = [GFF]::new([GFFContent]::UTC)
            $ls = [LocalizedString]::new(-1)
            $ls.SetData([KLanguage]::English, [Gender]::Male, 'English Male')
            $ls.SetData([KLanguage]::English, [Gender]::Female, 'English Female')
            $ls.SetData([KLanguage]::French, [Gender]::Male, 'French Male')
            $gff.Root.SetLocString('MultiLang', $ls)

            $bytes = Write-GFF -GFF $gff
            $gff2 = Read-GFF -Data $bytes

            $result = $gff2.Root.GetLocString('MultiLang')
            $result.StringRef | Should -Be -1
            $result.Get([KLanguage]::English, [Gender]::Male) | Should -Be 'English Male'
            $result.Get([KLanguage]::English, [Gender]::Female) | Should -Be 'English Female'
            $result.Get([KLanguage]::French, [Gender]::Male) | Should -Be 'French Male'
        }

        It 'empty list roundtrips' {
            $gff = [GFF]::new([GFFContent]::UTC)
            $gff.Root.SetList('EmptyList', [GFFList]::new())
            $bytes = Write-GFF -GFF $gff
            $gff2 = Read-GFF -Data $bytes
            $gff2.Root.GetList('EmptyList').Count() | Should -Be 0
        }
    }
}

Describe 'ERF Format' {

    Context 'ERF class' {
        It 'creates empty' {
            $erf = [ERF]::new()
            $erf.Count() | Should -Be 0
            $erf.ErfType | Should -Be ([ERFType]::ERF)
        }

        It 'creates with type' {
            $erf = [ERF]::new([ERFType]::MOD)
            $erf.ErfType | Should -Be ([ERFType]::MOD)
        }

        It 'SetData adds resource' {
            $erf = [ERF]::new()
            $rt = [ResourceType]::FromExtension('utc')
            $erf.SetData('test', $rt, [byte[]](1, 2, 3))
            $erf.Count() | Should -Be 1
        }

        It 'Get retrieves data' {
            $erf = [ERF]::new()
            $rt = [ResourceType]::FromExtension('utc')
            $erf.SetData('myres', $rt, [byte[]](10, 20, 30))
            $data = $erf.Get('myres', $rt)
            $data | Should -Not -BeNullOrEmpty
            $data[0] | Should -Be 10
            $data.Length | Should -Be 3
        }

        It 'Get returns null for missing' {
            $erf = [ERF]::new()
            $rt = [ResourceType]::FromExtension('utc')
            $erf.Get('missing', $rt) | Should -BeNullOrEmpty
        }

        It 'SetData updates existing' {
            $erf = [ERF]::new()
            $rt = [ResourceType]::FromExtension('utc')
            $erf.SetData('res', $rt, [byte[]](1))
            $erf.SetData('res', $rt, [byte[]](2))
            $erf.Count() | Should -Be 1
            $data = $erf.Get('res', $rt)
            $data[0] | Should -Be 2
        }

        It 'Remove removes resource' {
            $erf = [ERF]::new()
            $rt = [ResourceType]::FromExtension('utc')
            $erf.SetData('res', $rt, [byte[]](1))
            $erf.Remove('res', $rt)
            $erf.Count() | Should -Be 0
        }
    }

    Context 'Binary round-trip' {
        It 'empty ERF round-trips' {
            $erf = [ERF]::new()
            $bytes = Write-ERF -ERF $erf
            $erf2 = Read-ERF -Data $bytes
            $erf2.Count() | Should -Be 0
            $erf2.ErfType | Should -Be ([ERFType]::ERF)
        }

        It 'ERF with resources round-trips' {
            $erf = [ERF]::new()
            $rtUtc = [ResourceType]::FromExtension('utc')
            $rtUti = [ResourceType]::FromExtension('uti')
            $erf.SetData('creature', $rtUtc, [byte[]](0xDE, 0xAD, 0xBE, 0xEF))
            $erf.SetData('item', $rtUti, [byte[]](0xCA, 0xFE))

            $bytes = Write-ERF -ERF $erf
            $erf2 = Read-ERF -Data $bytes

            $erf2.Count() | Should -Be 2

            $d1 = $erf2.Get('creature', $rtUtc)
            $d1 | Should -Not -BeNullOrEmpty
            $d1.Length | Should -Be 4
            $d1[0] | Should -Be 0xDE

            $d2 = $erf2.Get('item', $rtUti)
            $d2 | Should -Not -BeNullOrEmpty
            $d2.Length | Should -Be 2
            $d2[0] | Should -Be 0xCA
        }

        It 'MOD type preserves' {
            $erf = [ERF]::new([ERFType]::MOD)
            $rt = [ResourceType]::FromExtension('utc')
            $erf.SetData('test', $rt, [byte[]](1))

            $bytes = Write-ERF -ERF $erf
            $erf2 = Read-ERF -Data $bytes
            $erf2.ErfType | Should -Be ([ERFType]::MOD)
        }

        It 'validates header' {
            $badData = [System.Text.Encoding]::ASCII.GetBytes('BAD V1.0') + [byte[]]::new(200)
            { Read-ERF -Data $badData } | Should -Throw
        }

        It 'handles large resource data' {
            $erf = [ERF]::new()
            $rt = [ResourceType]::FromExtension('2da')
            $largeData = [byte[]]::new(10000)
            for ($i = 0; $i -lt $largeData.Length; $i++) { $largeData[$i] = [byte]($i % 256) }
            $erf.SetData('bigfile', $rt, $largeData)

            $bytes = Write-ERF -ERF $erf
            $erf2 = Read-ERF -Data $bytes

            $retrieved = $erf2.Get('bigfile', $rt)
            $retrieved.Length | Should -Be 10000
            $retrieved[0] | Should -Be 0
            $retrieved[255] | Should -Be 255
            $retrieved[256] | Should -Be 0
        }
    }
}

Describe 'RIM Format' {

    Context 'RIM class' {
        It 'creates empty' {
            $rim = [RIM]::new()
            $rim.Count() | Should -Be 0
        }

        It 'SetData/Get works' {
            $rim = [RIM]::new()
            $rt = [ResourceType]::FromExtension('utc')
            $rim.SetData('npc', $rt, [byte[]](1, 2, 3))
            $data = $rim.Get('npc', $rt)
            $data.Length | Should -Be 3
            $data[0] | Should -Be 1
        }

        It 'Remove works' {
            $rim = [RIM]::new()
            $rt = [ResourceType]::FromExtension('utc')
            $rim.SetData('npc', $rt, [byte[]](1))
            $rim.Remove('npc', $rt)
            $rim.Count() | Should -Be 0
        }
    }

    Context 'Binary round-trip' {
        It 'empty RIM round-trips' {
            $rim = [RIM]::new()
            $bytes = Write-RIM -RIM $rim
            $rim2 = Read-RIM -Data $bytes
            $rim2.Count() | Should -Be 0
        }

        It 'RIM with resources round-trips' {
            $rim = [RIM]::new()
            $rt1 = [ResourceType]::FromExtension('utc')
            $rt2 = [ResourceType]::FromExtension('dlg')
            $rim.SetData('creature', $rt1, [byte[]](0xAB, 0xCD))
            $rim.SetData('dialog', $rt2, [byte[]](0xEF, 0x01, 0x23))

            $bytes = Write-RIM -RIM $rim
            $rim2 = Read-RIM -Data $bytes

            $rim2.Count() | Should -Be 2
            $d1 = $rim2.Get('creature', $rt1)
            $d1.Length | Should -Be 2
            $d1[0] | Should -Be 0xAB

            $d2 = $rim2.Get('dialog', $rt2)
            $d2.Length | Should -Be 3
            $d2[2] | Should -Be 0x23
        }

        It 'validates header' {
            $badData = [System.Text.Encoding]::ASCII.GetBytes('BAD V1.0') + [byte[]]::new(200)
            { Read-RIM -Data $badData } | Should -Throw
        }
    }
}

Describe 'SSF Format' {

    Context 'SSF class' {
        It 'creates with all -1' {
            $ssf = [SSF]::new()
            for ($i = 0; $i -lt 28; $i++) {
                $ssf.Sounds[$i] | Should -Be -1
            }
        }

        It 'SetData/Get works' {
            $ssf = [SSF]::new()
            $ssf.SetData([SSFSound]::BATTLE_CRY_1, 100)
            $ssf.Get([SSFSound]::BATTLE_CRY_1) | Should -Be 100
            $ssf.Get([SSFSound]::DEAD) | Should -Be -1
        }
    }

    Context 'Binary round-trip' {
        It 'default SSF round-trips' {
            $ssf = [SSF]::new()
            $bytes = Write-SSF -SSF $ssf
            $ssf2 = Read-SSF -Data $bytes

            for ($i = 0; $i -lt 28; $i++) {
                $ssf2.Sounds[$i] | Should -Be -1
            }
        }

        It 'SSF with data round-trips' {
            $ssf = [SSF]::new()
            $ssf.SetData([SSFSound]::BATTLE_CRY_1, 100)
            $ssf.SetData([SSFSound]::SELECT_1, 200)
            $ssf.SetData([SSFSound]::DEAD, 300)
            $ssf.SetData([SSFSound]::POISONED, 400)

            $bytes = Write-SSF -SSF $ssf
            $ssf2 = Read-SSF -Data $bytes

            $ssf2.Get([SSFSound]::BATTLE_CRY_1) | Should -Be 100
            $ssf2.Get([SSFSound]::SELECT_1) | Should -Be 200
            $ssf2.Get([SSFSound]::DEAD) | Should -Be 300
            $ssf2.Get([SSFSound]::POISONED) | Should -Be 400
            $ssf2.Get([SSFSound]::BATTLE_CRY_2) | Should -Be -1
        }

        It 'validates header' {
            $badData = [System.Text.Encoding]::ASCII.GetBytes('BAD V1.1') + [byte[]]::new(200)
            { Read-SSF -Data $badData } | Should -Throw
        }

        It 'all 28 sound slots roundtrip' {
            $ssf = [SSF]::new()
            for ($i = 0; $i -lt 28; $i++) {
                $ssf.Sounds[$i] = $i * 100
            }

            $bytes = Write-SSF -SSF $ssf
            $ssf2 = Read-SSF -Data $bytes

            for ($i = 0; $i -lt 28; $i++) {
                $ssf2.Sounds[$i] | Should -Be ($i * 100) -Because "Sound slot $i should be $($i * 100)"
            }
        }
    }
}

Describe 'PatcherConfig Reader' {

    Context 'Config parsing' {
        It 'parses Settings section' {
            $tempFile = [System.IO.Path]::GetTempFileName()
            try {
                $iniContent = @"
[Settings]
WindowCaption=My Cool Mod
ConfirmMessage=Install this?
"@
                [System.IO.File]::WriteAllText($tempFile, $iniContent)
                $config = Read-PatcherConfig -Path $tempFile
                $config.WindowTitle | Should -Be 'My Cool Mod'
                $config.ConfirmMessage | Should -Be 'Install this?'
            }
            finally {
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            }
        }

        It 'parses TLKList section' {
            $tempFile = [System.IO.Path]::GetTempFileName()
            try {
                $iniContent = @"
[Settings]
WindowCaption=Test
[TLKList]
49001=Hello World,greeting_snd
49002=Goodbye,farewell_snd
49003=No sound
"@
                [System.IO.File]::WriteAllText($tempFile, $iniContent)
                $config = Read-PatcherConfig -Path $tempFile
                $config.TLKPatch.Entries.Count | Should -Be 3
                $config.TLKPatch.Entries[0].StringRef | Should -Be 49001
                $config.TLKPatch.Entries[0].Text | Should -Be 'Hello World'
                $config.TLKPatch.Entries[0].SoundResref | Should -Be 'greeting_snd'
                $config.TLKPatch.Entries[2].SoundResref | Should -Be ''
            }
            finally {
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            }
        }

        It 'parses InstallList section' {
            $tempFile = [System.IO.Path]::GetTempFileName()
            try {
                $iniContent = @"
[Settings]
WindowCaption=Test
[InstallList]
0=file1.utc
1=file2.dlg
2=file3.2da
"@
                [System.IO.File]::WriteAllText($tempFile, $iniContent)
                $config = Read-PatcherConfig -Path $tempFile
                $config.InstallList.Count | Should -Be 3
                $config.InstallList[0] | Should -Be 'file1.utc'
                $config.InstallList[2] | Should -Be 'file3.2da'
            }
            finally {
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            }
        }

        It 'ignores comments' {
            $tempFile = [System.IO.Path]::GetTempFileName()
            try {
                $iniContent = @"
; This is a comment
# This is also a comment
[Settings]
WindowCaption=Test ; inline on section
"@
                [System.IO.File]::WriteAllText($tempFile, $iniContent)
                $config = Read-PatcherConfig -Path $tempFile
                $config.WindowTitle | Should -Be 'Test'
            }
            finally {
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            }
        }

        It 'handles empty file' {
            $tempFile = [System.IO.Path]::GetTempFileName()
            try {
                [System.IO.File]::WriteAllText($tempFile, '')
                $config = Read-PatcherConfig -Path $tempFile
                $config.WindowTitle | Should -Be 'KPatcher'
            }
            finally {
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe 'Cross-Format Integration' {

    It 'GFF inside ERF roundtrips' {
        # Build a GFF
        $gff = [GFF]::new([GFFContent]::UTC)
        $gff.Root.SetString('Tag', 'test_npc')
        $gff.Root.SetInt32('HitPoints', 50)
        $gffBytes = Write-GFF -GFF $gff

        # Pack into ERF
        $erf = [ERF]::new()
        $rt = [ResourceType]::FromExtension('utc')
        $erf.SetData('test_npc', $rt, $gffBytes)
        $erfBytes = Write-ERF -ERF $erf

        # Unpack
        $erf2 = Read-ERF -Data $erfBytes
        $gffBytes2 = $erf2.Get('test_npc', $rt)
        $gff2 = Read-GFF -Data $gffBytes2

        $gff2.Content | Should -Be ([GFFContent]::UTC)
        $gff2.Root.GetString('Tag') | Should -Be 'test_npc'
        $gff2.Root.GetInt32('HitPoints') | Should -Be 50
    }

    It 'TwoDA inside RIM roundtrips' {
        $twoda = [TwoDA]::new(@('name', 'value'))
        $twoda.AddRow('0')
        $twoda.SetCell(0, 'name', 'test')
        $twoda.SetCell(0, 'value', '42')
        $twodaBytes = Write-TwoDA -TwoDA $twoda

        $rim = [RIM]::new()
        $rt = [ResourceType]::FromExtension('2da')
        $rim.SetData('appearance', $rt, $twodaBytes)
        $rimBytes = Write-RIM -RIM $rim

        $rim2 = Read-RIM -Data $rimBytes
        $twodaBytes2 = $rim2.Get('appearance', $rt)
        $twoda2 = Read-TwoDA -Data $twodaBytes2

        $twoda2.GetCell(0, 'name') | Should -Be 'test'
        $twoda2.GetCell(0, 'value') | Should -Be '42'
    }

    It 'complex KOTOR-like UTC roundtrips' {
        # Build a realistic UTC (creature) file
        $utc = [GFF]::new([GFFContent]::UTC)
        $utc.Root.SetString('Tag', 'p_bastila')
        $utc.Root.SetResRef('TemplateResRef', [ResRef]::new('p_bastila'))
        $utc.Root.SetLocString('FirstName', [LocalizedString]::FromEnglish('Bastila'))
        $utc.Root.SetLocString('LastName', [LocalizedString]::FromEnglish('Shan'))
        $utc.Root.SetUInt8('Race', 6)      # Human
        $utc.Root.SetUInt8('Gender', 1)    # Female
        $utc.Root.SetInt16('HitPoints', 150)
        $utc.Root.SetInt16('CurrentHitPoints', 150)
        $utc.Root.SetInt16('MaxHitPoints', 150)
        $utc.Root.SetUInt8('NaturalAC', 10)
        $utc.Root.SetUInt16('Appearance_Type', 4)
        $utc.Root.SetSingle('ChallengeRating', [float]8.0)

        # Equipment list
        $equipList = [GFFList]::new()
        $item = [GFFStruct]::new(2)
        $item.SetResRef('EquippedRes', [ResRef]::new('g_w_lghtsbr01'))
        $equipList.AddStruct($item)
        $utc.Root.SetList('Equip_ItemList', $equipList)

        # Class list
        $classList = [GFFList]::new()
        $jedi = [GFFStruct]::new(2)
        $jedi.SetInt32('Class', 3)   # Jedi Sentinel
        $jedi.SetInt16('ClassLevel', 6)
        $classList.AddStruct($jedi)
        $utc.Root.SetList('ClassList', $classList)

        $bytes = Write-GFF -GFF $utc
        $utc2 = Read-GFF -Data $bytes

        $utc2.Content | Should -Be ([GFFContent]::UTC)
        $utc2.Root.GetString('Tag') | Should -Be 'p_bastila'
        $utc2.Root.GetLocString('FirstName').Get([KLanguage]::English, [Gender]::Male) | Should -Be 'Bastila'
        $utc2.Root.GetLocString('LastName').Get([KLanguage]::English, [Gender]::Male) | Should -Be 'Shan'
        $utc2.Root.GetUInt8('Gender') | Should -Be 1
        $utc2.Root.GetInt16('HitPoints') | Should -Be 150
        $utc2.Root.GetUInt16('Appearance_Type') | Should -Be 4

        $equip = $utc2.Root.GetList('Equip_ItemList')
        $equip.Count() | Should -Be 1
        $equip.At(0).GetResRef('EquippedRes').Value | Should -Be 'g_w_lghtsbr01'

        $classes = $utc2.Root.GetList('ClassList')
        $classes.Count() | Should -Be 1
        $classes.At(0).GetInt32('Class') | Should -Be 3
        $classes.At(0).GetInt16('ClassLevel') | Should -Be 6
    }
}

Describe 'PatcherMemory' {
    It 'stores and retrieves 2DA memory tokens' {
        $mem = [PatcherMemory]::new()
        $mem.Memory2DA[1] = '42'
        $mem.Memory2DA[2] = 'hello'
        $mem.Memory2DA[1] | Should -Be '42'
        $mem.Memory2DA[2] | Should -Be 'hello'
    }

    It 'stores and retrieves StrRef memory tokens' {
        $mem = [PatcherMemory]::new()
        $mem.MemoryStr[1] = 49001
        $mem.MemoryStr[1] | Should -Be 49001
    }
}
