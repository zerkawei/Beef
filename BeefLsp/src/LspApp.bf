using System;
using System.IO;
using System.Threading;
using System.Collections;

using IDE;
using IDE.Util;
using IDE.Compiler;
using Beefy.utils;
using Beefy.widgets;

namespace BeefLsp {
	class LspApp : IDEApp {
		public static LspApp APP;

		public BfCompiler compiler ~ delete _;
		public LspFileWatcher fileWatcher  = new .() ~ delete _;

		public override void Init()	{
			if (mConfigName.IsEmpty) mConfigName.Set("Debug");
			if (mPlatformName.IsEmpty) mPlatformName.Set(sPlatform64Name);

			mMainThread = Thread.CurrentThread;

			base.Init();

			mSettings.Load();
			mSettings.Apply();

			mInitialized = true;

			CreateBfSystems();
			compiler = mBfBuildSystem.CreateCompiler(true);

			APP = this;
		}

		public void LoadWorkspace(StringView path) {
			if (mWorkspace.mDir != null) {
				Log.Error("Tried to load a workspace while one is already loaded");
				return;
			}

			mWorkspace.mDir = new String(path);

		    mWorkspace.mName = new String();
		    Path.GetFileName(mWorkspace.mDir, mWorkspace.mName);
		    LoadWorkspace(mVerb);
			LoadWorkspaceUserDataCustom();

			WorkspaceLoaded();

			for (let project in mWorkspace.mProjects) {
				IDEUtils.FixFilePath(project.mProjectDir);
				IDEUtils.FixFilePath(project.mProjectPath);

				if (!fileWatcher.Watch(project.mProjectDir)) {
					Log.Error("Failed to watch project for file changes.");
					return;
				}
			}

			Log.Info("Loaded workspace at {}", path);
		}

		public bool InitialParse(BfPassInstance pass) {
			bool worked = true;

			compiler.[Friend]HandleOptions(null, 0);

			for (let project in mWorkspace.mProjects) {
				SetupBeefProjectSettings(mBfBuildSystem, compiler, project);
				worked &= ParseSourceFiles(mBfBuildSystem, pass, project.mRootFolder);
			}

			return worked;
		}

		private void LoadWorkspaceUserDataCustom() {
			String path = scope .();
			if (![Friend]GetWorkspaceUserDataFileName(path)) {
				Log.Error("Failed to get workspace user data file path");
				return;
			}

			StructuredData sd = scope .();
			if (sd.Load(path) case .Err(let err)) {
				Log.Error("Failed to load workspace user data at '{}': {}", path, err.ToString(.. scope .()));
				return;
			}

			String configName = sd.GetString("LastConfig", .. scope .());
			if (!configName.IsEmpty) mConfigName.Set(configName);

			String platformName = sd.GetString("LastPlatform", .. scope .());
			if (!platformName.IsEmpty) mPlatformName.Set(platformName);
		}

		public void SaveWorkspaceUserDataCustom() {
			String path = scope .();
			if (![Friend]GetWorkspaceUserDataFileName(path)) {
				Log.Error("Failed to get workspace user data file path");
				return;
			}

			StructuredData sd = scope .();
			if (sd.Load(path) case .Err(let err)) {
				Log.Error("Failed to load workspace user data at '{}': {}", path, err.ToString(.. scope .()));
				return;
			}

			Object config;
			sd.TryGet("LastConfig", out config);
			((String) config).Set(mConfigName);

			String data = sd.ToTOML(.. scope .());
			if (!SafeWriteTextFile(path, data, false)) Log.Error("Failed to write workspace suer data at '{}'", path);
		}

		// Logging

		public override void Output(String outStr) {
			Log.Info(outStr);
		}

		public override void OutputSmart(String outStr) {
			Log.Info(outStr);
		}

		public override void Output(String format, params Object[] args) {
			Log.Info(format, params args);
		}

		public override void OutputLine(String format, params Object[] args) {
			Log.Info(format, params args);
		}

		public override void OutputErrorLine(String format, params Object[] args) {
			Log.Error(format, params args);
		}

		public override void OutputWarnLine(String format, params Object[] args) {
			Log.Warning(format, params args);
		}

		public override void OutputLineSmart(String format, params Object[] args) {
			if (format.StartsWith("ERROR:")) Log.Error(format, params args);
			else Log.Info(format, params args);
		}

		public override void OutputFormatted(String str, bool isDbgEvalOutput = false) {
			Log.Info(str);
		}
	}
}