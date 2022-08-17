using System;
using System.IO;
using System.Threading;

using IDE;
using IDE.Compiler;
using Beefy.utils;
using Beefy.widgets;

namespace BeefLsp {
	class LspApp : IDEApp {
		public override void Init()	{
			if (mConfigName.IsEmpty) mConfigName.Set("Debug");
			if (mPlatformName.IsEmpty) mPlatformName.Set(sPlatform64Name);

			mMainThread = Thread.CurrentThread;

			base.Init();

			mSettings.Load();
			mSettings.Apply();

			mInitialized = true;
			CreateBfSystems();

			if (mWorkspace.mDir == null) {
				mWorkspace.mDir = new String();
				Directory.GetCurrentDirectory(mWorkspace.mDir);
			}

			if (mWorkspace.mDir != null) {
			    mWorkspace.mName = new String();
			    Path.GetFileName(mWorkspace.mDir, mWorkspace.mName);
			    LoadWorkspace(mVerb);                
			}

			if (mFailed) return;
			WorkspaceLoaded();

			//Compile(.Normal, null);

			mBfBuildSystem.Lock(0);

			let project = FindProjectByName("BeefLsp");

			var pass = mBfBuildSystem.CreatePassInstance("Test");
			bool worked = InitialParse(pass);
			PrintErrors(pass);

			ProjectSource source = (.) project.mRootFolder.mChildItems[1];
			//GetEditData(source, false);

			IdSpan charIdData;
			String sourceString = scope .();
			bool omd = FindProjectSourceContent(source, out charIdData, true, sourceString, null);

			let parser = mBfBuildSystem.CreateParser(source);
			parser.SetIsClassifying();
			parser.SetSource(sourceString, source.mName, 1);

			BfResolvePassData passData = parser.CreateResolvePassData(.Classify);

			parser.SetAutocomplete(12);

			pass = mBfBuildSystem.CreatePassInstance("OMG");

			bool idk1 = parser.Parse(pass, false);
			bool idk2 = parser.Reduce(pass);
			bool idk3 = parser.BuildDefs(pass, passData, true);

			PrintErrors(pass);

			//EditWidgetContent.CharData[] charData = scope .[4096];
			//parser.ClassifySource(charData, false);

			//parser.CreateClassifier(pass, passData, charData);
			//parser.FinishClassifier(passData);

			let passData2 = BfResolvePassData.Create(.Classify);

			parser.CreateClassifier(pass, passData, scope EditWidgetContent.CharData[4096]);
			bool uhh = mBfBuildCompiler.ClassifySource(pass, passData2);
			parser.FinishClassifier(passData);

			String str = scope .();
			mBfBuildCompiler.GetAutocompleteInfo(str);

			idk1 = idk1;
		}

		private bool InitialParse(BfPassInstance pass) {
			bool worked = true;

			for (let project in mWorkspace.mProjects) {
				worked &= ParseSourceFiles(mBfBuildSystem, pass, project.mRootFolder);
			}

			return worked;
		}

		private void PrintErrors(BfPassInstance pass) {
			let count = pass.GetErrorCount();

			for (int i < count) {
				BfPassInstance.BfError error = scope .();
				pass.GetErrorData(0, error, true);

				Console.WriteLine("Error at line {}: {}", error.mLine, error.mError);
			}
		}
	}
}