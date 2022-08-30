namespace BeefLsp;

using System;
using System.IO;
using System.Collections;

using IDE;
using IDE.Compiler;

class LspFileWatcher {
	private List<FileSystemWatcher> watchers = new .() ~ DeleteContainerAndItems!(_);
	public delegate void(BfPassInstance pass) parseCallback ~ delete _;

	private void OnCreated(String path) {
		if (!path.EndsWith(".bf")) return;

		// Get parent folder
		String parentPath = Path.GetDirectoryPath(path, .. scope .());
		ProjectFolder parentFolder = LspApp.APP.FindProjectFolder(parentPath);

		// Create parent folder
		if (parentFolder == null) parentFolder = CreateParentFolder(parentPath);

		// Notify about file create
		LspApp.APP.OnWatchedFileChanged(parentFolder, .FileCreated, path);
	}

	private ProjectFolder CreateParentFolder(String path) {
		// Get parent folder
		String parentPath = Path.GetDirectoryPath(path, .. scope .());
		ProjectFolder parentFolder = LspApp.APP.FindProjectFolder(parentPath);

		// Create parent folder
		if (parentFolder == null) parentFolder = CreateParentFolder(parentPath);

		// Create folder
		LspApp.APP.OnWatchedFileChanged(parentFolder, .DirectoryCreated, path);

		return LspApp.APP.FindProjectFolder(path);
	}

	private void OnDeleted(String path) {
		if (!path.EndsWith(".bf")) return;

		// Get parent folder
		String parentPath = Path.GetDirectoryPath(path, .. scope .());

		ProjectFolder parentFolder = LspApp.APP.FindProjectFolder(parentPath);
		if (parentFolder == null) return;

		// Get item being deleted
		ProjectSource item = LspApp.APP.FindProjectSourceItem(path);
		if (item == null) return;

		// Delete item
		parentFolder.RemoveChild(item);
		delete LspApp.APP.mBfBuildSystem.FileRemoved(item);
		LspApp.APP.mBfBuildSystem.RemoveDeletedParsers();
		item.ReleaseLastRef();

		// Delete folder if empty
		// TODO: Deleting the folder causes Attempted to access deleted object error because the mChildItems list is deleted sooner than it is iterated over to remove file watchers
		//DeleteFolderIfEmpty(parentFolder);
		
		// Parse workspace and report errors
		Parse();
	}

	private void DeleteFolderIfEmpty(ProjectFolder folder) {
		// Check if empty
		if (!folder.mChildItems.IsEmpty) return;
		
		// Remove from parent
		ProjectFolder parent = folder.mParentFolder;
		parent.RemoveChild(folder);

		// Delete parent if empty
		DeleteFolderIfEmpty(parent);

		// Release last reference
		folder.ReleaseLastRef();
	}

	private void OnRenamed(String newPath, String oldPath) {
		// Get item being renamed
		ProjectFileItem item = LspApp.APP.FindProjectFileItem(oldPath);
		if (item == null) return;

		// Rename item
		item.Rename(Path.GetFileName(newPath, .. scope .()));
		if (item is ProjectSource) LspApp.APP.mBfBuildSystem.FileRenamed((.) item, oldPath, newPath);
	}

	private void Parse() {
		LspApp.APP.LockSystem!();

		BfPassInstance pass = LspApp.APP.mBfBuildSystem.CreatePassInstance("Parse");
		defer delete pass;

		BfResolvePassData passData = .Create(.None);
		defer delete passData;

		LspApp.APP.compiler.ClassifySource(pass, passData);

		parseCallback(pass);
	}

	public bool Watch(String path) {
		FileSystemWatcher watcher = new .(path);
		watcher.IncludeSubdirectories = true;
		
		if (watcher.StartRaisingEvents() == .Err) {
			delete watcher;
			return false;
		}

		watcher.OnCreated.Add(new (filePath) => OnCreated(Path.InternalCombine(.. scope .(), path, filePath)));
		watcher.OnDeleted.Add(new (filePath) => OnDeleted(Path.InternalCombine(.. scope .(), path, filePath)));
		watcher.OnRenamed.Add(new (newName, oldName) => OnRenamed(Path.InternalCombine(.. scope .(), path, oldName), Path.InternalCombine(.. scope .(), path, newName)));

		watchers.Add(watcher);
		return true;
	}
}