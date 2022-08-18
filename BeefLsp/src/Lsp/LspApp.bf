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
		public BfCompiler compiler ~ delete _;

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
		}

		public void LoadWorkspace(StringView path) {
			if (mWorkspace.mDir != null) {
				Console.WriteLine("Tried to load a workspace while one is already loaded");
				return;
			}

			mWorkspace.mDir = new String(path);

		    mWorkspace.mName = new String();
		    Path.GetFileName(mWorkspace.mDir, mWorkspace.mName);
		    LoadWorkspace(mVerb);

			WorkspaceLoaded();
			compiler.[Friend]HandleOptions(null, 0);

			Console.WriteLine("Loaded workspace at {}", path);
		}

		public bool InitialParse(BfPassInstance pass) {
			bool worked = true;

			for (let project in mWorkspace.mProjects) {
				SetupBeefProjectSettings(mBfBuildSystem, compiler, project);
				worked &= ParseSourceFiles(mBfBuildSystem, pass, project.mRootFolder);
			}

			return worked;
		}
	}
}