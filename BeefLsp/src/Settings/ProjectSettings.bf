namespace BeefLsp;

using System;
using System.Collections;

using static BeefLsp.CommonSettings;
using IDE;

static class ProjectSettings {
	public struct Target : this(Project project, StringView configuration, StringView platform) {
		public Project.Options Options => project.GetOptions(scope .(configuration), scope .(platform), true);
	}

	private static Dictionary<int, SettingGroup<Target>> GROUPS = new .() ~ DeleteDictionaryAndValues!(_);

	private static SettingGroup<Target> PROJECT = NewGroup("Project", false, false);
	private static SettingGroup<Target> DEPENDENCIES = NewGroup("Dependencies", false, false);
	private static SettingGroup<Target> BEEF_G = NewGroup("Beef", false, false);
	
	private static SettingGroup<Target> PLATFORM_WINDOWS = NewGroup("Platform", false, true);
	private static SettingGroup<Target> PLATFORM_LINUX = NewGroup("Platform", false, true);
	private static SettingGroup<Target> PLATFORM_WASM = NewGroup("Platform", false, true);
	
	private static SettingGroup<Target> BEEF_T = NewGroup("Beef", true, true);
	private static SettingGroup<Target> BUILD = NewGroup("Build", true, true);
	private static SettingGroup<Target> DEBUGGING = NewGroup("Debugging", true, true);

	private static Workspace LAST_WORKSPACE = null;
	private static Project LAST_PROJECT = null;

	public static void Loop(Workspace workspace, Project project, delegate void(SettingGroup<Target> group) callback) {
		Setup(workspace, project);

		callback(PROJECT);
		callback(DEPENDENCIES);
		callback(BEEF_G);

		// TODO: Detect the target platform from the currently selected platform in the editor
		/*Workspace.PlatformType platform = .GetFromName(platformName);
		switch (platform) {
		case .Windows:	callback(PLATFORM_WINDOWS);
		case .Linux:	callback(PLATFORM_LINUX);
		case .Wasm:		callback(PLATFORM_WASM);
		default:
		}*/
#if BF_PLATFORM_WINDOWS
		callback(PLATFORM_WINDOWS);
#elif BF_PLATFORM_LINUX		
		callback(PLATFORM_LINUX);
#endif

		callback(BEEF_T);
		callback(BUILD);
		callback(DEBUGGING);
	}

	public static bool Set(Workspace workspace, Project project, Target target, int groupId, StringView projectName, Json value) {
		Setup(workspace, project);

		SettingGroup<Target> group = GROUPS.GetValueOrDefault(groupId);
		if (group != null) return group.Set(target, projectName, value);

		return false;
	}

	private static void Setup(Workspace workspace, Project project) {
		// Return if setup is not needed
		if (LAST_WORKSPACE == workspace && LAST_PROJECT == project) return;

		LAST_WORKSPACE = workspace;
		LAST_PROJECT = project;

		// Setup
		DEPENDENCIES.Clear();

		for (let proj in workspace.mProjects) {
			if (proj == project) continue;

			DEPENDENCIES.Add(new BoolSetting<Target>(
				proj.mProjectName,
				new (target) => target.project.HasDependency(proj.mProjectName),
				new (target, value) => {
					bool has = target.project.HasDependency(proj.mProjectName);

					if (has && !value) {
						for (let dependency in target.project.mDependencies) {
							if (dependency.mProjectName == proj.mProjectName) {
								@dependency.Remove();
								delete dependency;

								break;
							}
						}
					}
					else if (!has && value) {
						Project.Dependency dependency = new .();
						dependency.mVerSpec = .SemVer(new .("*"));
						dependency.mProjectName = new .(proj.mProjectName);
						
						target.project.mDependencies.Add(dependency);
					}
				}
			));
		}
	}

	private static SettingGroup<Target> NewGroup(StringView name, bool configuration, bool platform) {
		SettingGroup<Target> group = new .(GROUPS.Count, name, configuration, platform);

		GROUPS[group.id] = group;
		return group;
	}
	
	static this() {
		// Project
		PROJECT.Add(new EnumSetting<Target, TargetType>(
			"Target Type",
			new (target) => TargetType.From(target.project.mGeneralOptions.mTargetType),
			new (target, value) => target.project.mGeneralOptions.mTargetType = value.To()
		));

		PROJECT.Add(new StringListSetting<Target>(
			"Project Name Aliases",
			new (target) => target.project.mGeneralOptions.mAliases,
			new (target, value) => CopyListValues(value, target.project.mGeneralOptions.mAliases)
		));

		// Beef General
		BEEF_G.Add(new StringSetting<Target>(
			"Startup Object",
			new (target) => target.project.mBeefGlobalOptions.mStartupObject,
			new (target, value) => target.project.mBeefGlobalOptions.mStartupObject.Set(value)
		));

		BEEF_G.Add(new StringSetting<Target>(
			"Default Namespace",
			new (target) => target.project.mBeefGlobalOptions.mDefaultNamespace,
			new (target, value) => target.project.mBeefGlobalOptions.mDefaultNamespace.Set(value)
		));

		BEEF_G.Add(new StringListSetting<Target>(
			"Preprocessor Macros",
			new (target) => target.project.mBeefGlobalOptions.mPreprocessorMacros,
			new (target, value) => CopyListValues(value, target.project.mBeefGlobalOptions.mPreprocessorMacros)
		));
		
		BEEF_G.Add(CreateDistinctBuildOptionsSetting<Target>(
			new (target) => target.project.mBeefGlobalOptions.mDistinctBuildOptions,
			new (target, values) => CopyListValues(values, target.project.mBeefGlobalOptions.mDistinctBuildOptions)
		));

		// Platform Windows
		PLATFORM_WINDOWS.Add(new StringSetting<Target>(
			"Resources/Icon File",
			new (target) => target.project.mWindowsOptions.mIconFile,
			new (target, value) => target.project.mWindowsOptions.mIconFile.Set(value)
		));

		PLATFORM_WINDOWS.Add(new StringSetting<Target>(
			"Resources/Manifest File",
			new (target) => target.project.mWindowsOptions.mManifestFile,
			new (target, value) => target.project.mWindowsOptions.mManifestFile.Set(value)
		));

		PLATFORM_WINDOWS.Add(new StringSetting<Target>(
			"Version/Description",
			new (target) => target.project.mWindowsOptions.mDescription,
			new (target, value) => target.project.mWindowsOptions.mDescription.Set(value)
		));

		PLATFORM_WINDOWS.Add(new StringSetting<Target>(
			"Version/Comments",
			new (target) => target.project.mWindowsOptions.mComments,
			new (target, value) => target.project.mWindowsOptions.mComments.Set(value)
		));

		PLATFORM_WINDOWS.Add(new StringSetting<Target>(
			"Version/Company",
			new (target) => target.project.mWindowsOptions.mCompany,
			new (target, value) => target.project.mWindowsOptions.mCompany.Set(value)
		));

		PLATFORM_WINDOWS.Add(new StringSetting<Target>(
			"Version/Product",
			new (target) => target.project.mWindowsOptions.mProduct,
			new (target, value) => target.project.mWindowsOptions.mProduct.Set(value)
		));

		PLATFORM_WINDOWS.Add(new StringSetting<Target>(
			"Version/Copyright",
			new (target) => target.project.mWindowsOptions.mCopyright,
			new (target, value) => target.project.mWindowsOptions.mCopyright.Set(value)
		));

		PLATFORM_WINDOWS.Add(new StringSetting<Target>(
			"Version/File Version",
			new (target) => target.project.mWindowsOptions.mFileVersion,
			new (target, value) => target.project.mWindowsOptions.mFileVersion.Set(value)
		));

		PLATFORM_WINDOWS.Add(new StringSetting<Target>(
			"Version/Product Version",
			new (target) => target.project.mWindowsOptions.mProductVersion,
			new (target, value) => target.project.mWindowsOptions.mProductVersion.Set(value)
		));

		// Platform Linux
		PLATFORM_LINUX.Add(new StringSetting<Target>(
			"Options",
			new (target) => target.project.mLinuxOptions.mOptions,
			new (target, value) => target.project.mLinuxOptions.mOptions.Set(value)
		));

		// Platform WASM
		PLATFORM_WASM.Add(new BoolSetting<Target>(
			"Enable Threads",
			new (target) => target.project.mWasmOptions.mEnableThreads,
			new (target, value) => target.project.mWasmOptions.mEnableThreads = value
		));

		// Beef Targeted
		BEEF_T.Add(new StringListSetting<Target>(
			"General/Preprocessor Macros",
			new (target) => target.Options.mBeefOptions.mPreprocessorMacros,
			new (target, value) => CopyListValues(value, target.Options.mBeefOptions.mPreprocessorMacros)
		));

		BEEF_T.Add(new EnumSetting<Target, RelocModel>(
			"Code Generation/Reloc Model",
			new (target) => (RelocModel) target.Options.mBeefOptions.mRelocType,
			new (target, value) => target.Options.mBeefOptions.mRelocType = (.) value
		));

		BEEF_T.Add(new EnumSetting<Target, PICLevel>(
			"Code Generation/PIC Level",
			new (target) => (PICLevel) target.Options.mBeefOptions.mPICLevel,
			new (target, value) => target.Options.mBeefOptions.mPICLevel = (.) value
		));

		BEEF_T.Add(new EnumSetting<Target, OptimizationLevel>(
			"Code Generation/Optimization Level",
			new (target) => OptimizationLevel.From(target.Options.mBeefOptions.mOptimizationLevel),
			new (target, value) => target.Options.mBeefOptions.mOptimizationLevel = value.To()
		));

		BEEF_T.Add(new BoolSetting<Target>(
			"Code Generation/Vectorize Loops",
			new (target) => target.Options.mBeefOptions.mVectorizeLoops,
			new (target, value) => target.Options.mBeefOptions.mVectorizeLoops = value
		));

		BEEF_T.Add(new BoolSetting<Target>(
			"Code Generation/Vectorize SLP",
			new (target) => target.Options.mBeefOptions.mVectorizeSLP,
			new (target, value) => target.Options.mBeefOptions.mVectorizeSLP = value
		));
		
		BEEF_T.Add(CreateDistinctBuildOptionsSetting<Target>(
			new (target) => target.Options.mBeefOptions.mDistinctBuildOptions,
			new (target, values) => CopyListValues(values, target.Options.mBeefOptions.mDistinctBuildOptions)
		));

		// Build
		BUILD.Add(new EnumSetting<Target, BuildType>(
			"Build Type",
			new (target) => (BuildType) target.Options.mBuildOptions.mBuildKind,
			new (target, value) => target.Options.mBuildOptions.mBuildKind = (.) value
		));

		BUILD.Add(new StringSetting<Target>(
			"Target Directory",
			new (target) => target.Options.mBuildOptions.mTargetDirectory,
			new (target, value) => target.Options.mBuildOptions.mTargetDirectory.Set(value)
		));

		BUILD.Add(new StringSetting<Target>(
			"Target Name",
			new (target) => target.Options.mBuildOptions.mTargetName,
			new (target, value) => target.Options.mBuildOptions.mTargetName.Set(value)
		));

		BUILD.Add(new StringSetting<Target>(
			"Other Build Flags",
			new (target) => target.Options.mBuildOptions.mOtherLinkFlags,
			new (target, value) => target.Options.mBuildOptions.mOtherLinkFlags.Set(value)
		));

		BUILD.Add(new EnumSetting<Target, CLibrary>(
			"C Library",
			new (target) => (CLibrary) target.Options.mBuildOptions.mCLibType,
			new (target, value) => target.Options.mBuildOptions.mCLibType = (.) value
		));

		BUILD.Add(new EnumSetting<Target, BeefLibrary>(
			"Beef Library",
			new (target) => (BeefLibrary) target.Options.mBuildOptions.mBeefLibType,
			new (target, value) => target.Options.mBuildOptions.mBeefLibType = (.) value
		));

		BUILD.Add(new IntSetting<Target>(
			"Stack Size",
			new (target) => target.Options.mBuildOptions.mStackSize,
			new (target, value) => target.Options.mBuildOptions.mStackSize = value
		));

		BUILD.Add(new StringListSetting<Target>(
			"Additional Lib Paths",
			new (target) => target.Options.mBuildOptions.mLibPaths,
			new (target, value) => CopyListValues(value, target.Options.mBuildOptions.mLibPaths)
		));

		BUILD.Add(new StringListSetting<Target>(
			"Rebuild Dependencies",
			new (target) => target.Options.mBuildOptions.mLinkDependencies,
			new (target, value) => CopyListValues(value, target.Options.mBuildOptions.mLinkDependencies)
		));

		BUILD.Add(new StringListSetting<Target>(
			"Prebuild Commands",
			new (target) => target.Options.mBuildOptions.mPreBuildCmds,
			new (target, value) => CopyListValues(value, target.Options.mBuildOptions.mPreBuildCmds)
		));

		BUILD.Add(new StringListSetting<Target>(
			"Postbuild Commands",
			new (target) => target.Options.mBuildOptions.mPostBuildCmds,
			new (target, value) => CopyListValues(value, target.Options.mBuildOptions.mPostBuildCmds)
		));

		BUILD.Add(new StringListSetting<Target>(
			"Clean Commands",
			new (target) => target.Options.mBuildOptions.mCleanCmds,
			new (target, value) => CopyListValues(value, target.Options.mBuildOptions.mCleanCmds)
		));

		BUILD.Add(new EnumSetting<Target, BuildCommandTrigger>(
			"Build Commands on Compile",
			new (target) => (BuildCommandTrigger) target.Options.mBuildOptions.mBuildCommandsOnCompile,
			new (target, value) => target.Options.mBuildOptions.mBuildCommandsOnCompile = (.) value
		));

		BUILD.Add(new EnumSetting<Target, BuildCommandTrigger>(
			"Build Commands on Run",
			new (target) => (BuildCommandTrigger) target.Options.mBuildOptions.mBuildCommandsOnRun,
			new (target, value) => target.Options.mBuildOptions.mBuildCommandsOnRun = (.) value
		));

		// Debugging
		DEBUGGING.Add(new StringSetting<Target>(
			"Command",
			new (target) => target.Options.mDebugOptions.mCommand,
			new (target, value) => target.Options.mDebugOptions.mCommand.Set(value),
			.File
		));

		DEBUGGING.Add(new StringSetting<Target>(
			"Command Arguments",
			new (target) => target.Options.mDebugOptions.mCommandArguments,
			new (target, value) => target.Options.mDebugOptions.mCommandArguments.Set(value)
		));

		DEBUGGING.Add(new StringSetting<Target>(
			"Working Directory",
			new (target) => target.Options.mDebugOptions.mWorkingDirectory,
			new (target, value) => target.Options.mDebugOptions.mWorkingDirectory.Set(value),
			.Folder
		));

		DEBUGGING.Add(new StringListSetting<Target>(
			"Environment Variables",
			new (target) => target.Options.mDebugOptions.mEnvironmentVars,
			new (target, value) => CopyListValues(value, target.Options.mDebugOptions.mEnvironmentVars)
		));
	}
}