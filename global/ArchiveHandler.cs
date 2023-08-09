using System;
using Godot;
using System.IO;
using Godot.Collections;
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

    public string Err = "";

    public void ExtractArchive(string sourcePath, string destPath)
    {
        GD.Print("C#: Extracting!! " + sourcePath + " >> " + destPath);
        try
        {
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
        }
        catch (Exception e)
        {
            Err = "Unextractable archive.";
            AllDone = true;
        }

        Err = "";
        AllDone = true;
    }

    public Array<string> GetAllFilesInDirectory(string sourcePath)
    {
        Array<string> files = new();
        foreach (string file in Directory.EnumerateFiles(sourcePath, "*.*", SearchOption.AllDirectories))
        {
            files.Add(file);
        }
        return files;
    }
}
