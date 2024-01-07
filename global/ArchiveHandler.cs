using System;
using Godot;
using System.IO;
using Godot.Collections;
using SharpCompress.Archives;
using SharpCompress.Common;
using SharpCompress.Readers;

public partial class ArchiveHandler : Node
{
	[Signal]
	public delegate void ExtractionCompleteEventHandler(string message, string path, bool archiveWasDb);

	public void ExtractArchive(string sourcePath, string destPath, bool archiveIsDb)
	{
		var err = "";
		GD.Print($"C#: Extracting!! {sourcePath} >> {destPath}");
		try
		{
			// Extract archive, no matter if it's zip, 7z or rar:
			var archive = ArchiveFactory.Open(sourcePath);
			foreach (var entry in archive.Entries)
			{
				if (!entry.IsDirectory)
				{
					Console.WriteLine(entry.Key);
					entry.WriteToDirectory(destPath, new ExtractionOptions() { ExtractFullPath = true, Overwrite = true });
				}
			}
		}
		catch (Exception e)
		{
			err = $"Extraction failed: {e.Message}";
		}
		
		EmitSignal(SignalName.ExtractionComplete, err, destPath, archiveIsDb);
		GD.Print("C#: Done.");
	}

	public Array<string> GetAllFilesInDirectory(string sourcePath)
	{
		Array<string> files = new();
		foreach (var file in Directory.EnumerateFiles(sourcePath, "*.*", SearchOption.AllDirectories))
		{
			files.Add(file);
		}
		return files;
	}

	public bool IsArchive(string sourcePath) => ArchiveFactory.IsArchive(sourcePath, out _);
}
