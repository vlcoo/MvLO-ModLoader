using Godot;
using System.IO;
using SharpCompress.Common;
using SharpCompress.Readers;

public partial class ArchiveHandler : Node
{
    private bool _allDone;
    public bool AllDone
    {
        get
        {
            switch (_allDone)
            {
                case false:
                    return false;
                case true:
                    _allDone = false;
                    return true;
            }
        }
        set => _allDone = value;
    }

    public void ExtractArchive(string sourcePath, string destPath)
    {
        GD.Print("C#: Extracting " + sourcePath + " to " + destPath + "!");
        using (Stream stream = File.OpenRead(sourcePath))
        using (var reader = ReaderFactory.Open(stream))
        {
            while (reader.MoveToNextEntry())
            {
                if (reader.Entry.IsDirectory) continue;
                reader.WriteEntryToDirectory(destPath, new ExtractionOptions()
                {
                    ExtractFullPath = true,
                    Overwrite = true
                });
            }
        }

        AllDone = true;
    }
}
