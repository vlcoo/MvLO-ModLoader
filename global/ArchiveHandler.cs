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
	public delegate void ExtractionCompleteEventHandler(string message, string path, bool archiveWasDb, int archiveSizeMb);

	public void ExtractArchive(string sourcePath, string destPath, bool archiveIsDb)
	{
		var worker = new Thread(() => ExtractArchiveWorker(sourcePath, destPath, archiveIsDb, this));
		worker.Start();
	}

	private static void ExtractArchiveWorker(string sourcePath, string destPath, bool archiveIsDb, GodotObject parent)
	{
		var err = "";
		var archiveSize = 0;
		GD.Print($"C#: Extracting {sourcePath} >> {destPath}...");
		try
		{
			var archive = ArchiveFactory.Open(sourcePath);
			var reader = archive.ExtractAllEntries();
			reader.WriteAllToDirectory(destPath, new ExtractionOptions() { ExtractFullPath = true, Overwrite = true });
			archiveSize = Mathf.FloorToInt(archive.TotalUncompressSize/1024.0/1024.0);
			archive.Dispose();
			OS.MoveToTrash(sourcePath);
		}
		catch (Exception e)
		{
			err = $"Extraction failed: {e.Message}";
		}
		
		GD.Print("C#: Done.");
		parent.CallDeferred("emit_signal", SignalName.ExtractionComplete, err, destPath, archiveIsDb, archiveSize);
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
