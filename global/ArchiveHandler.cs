using System;
using Godot;
using System.IO;
using System.Threading;
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
		var worker = new Thread(() => ExtractArchiveWorker(sourcePath, destPath, archiveIsDb, this));
		worker.Start();
	}

	private static void ExtractArchiveWorker(string sourcePath, string destPath, bool archiveIsDb, GodotObject parent)
	{
		var err = "";
		GD.Print($"C#: Extracting!! {sourcePath} >> {destPath}");
		try
		{
			var archive = ArchiveFactory.Open(sourcePath);
			var reader = archive.ExtractAllEntries();
			reader.WriteAllToDirectory(destPath, new ExtractionOptions() { ExtractFullPath = true, Overwrite = true });
		}
		catch (Exception e)
		{
			err = $"Extraction failed: {e.Message}";
		}
		
		GD.Print("C#: Done.");
		parent.CallDeferred("emit_signal", SignalName.ExtractionComplete, err, destPath, archiveIsDb);
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
