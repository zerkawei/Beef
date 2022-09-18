namespace BeefLsp;

using System;
using System.Collections;

using static BeefLsp.CommonSettings;
using IDE;

static class WorkspaceSettings {
	public struct Target : this(Workspace workspace, StringView configuration, StringView platform) {
		public Workspace.Options Options => workspace.GetOptions(scope .(configuration), scope .(platform));
	}

	private static Dictionary<int, SettingGroup<Target>> GROUPS = new .() ~ DeleteDictionaryAndValues!(_);

	private static SettingGroup<Target> BEEF_G = NewGroup("Beef", false, false);

	private static SettingGroup<Target> BEEF_T = NewGroup("Beef", true, true);
	private static SettingGroup<Target> BUILD = NewGroup("Build", true, true);

	public static void Loop(delegate void(SettingGroup<Target> group) callback) {
		callback(BEEF_G);

		callback(BEEF_T);
		callback(BUILD);
	}

	public static bool Set(Target target, int groupId, StringView projectName, Json value) {
		SettingGroup<Target> group = GROUPS.GetValueOrDefault(groupId);
		if (group != null) return group.Set(target, projectName, value);

		return false;
	}

	private static SettingGroup<Target> NewGroup(StringView name, bool configuration, bool platform) {
		SettingGroup<Target> group = new .(GROUPS.Count, name, configuration, platform);

		GROUPS[group.id] = group;
		return group;
	}

	static this() {
		// Beef General
		BEEF_G.Add(new StringListSetting<Target>(
			"Preprocessor Macros",
			new (target) => target.workspace.mBeefGlobalOptions.mPreprocessorMacros,
			new (target, value) => CopyListValues(value, target.workspace.mBeefGlobalOptions.mPreprocessorMacros)
		));
		
		BEEF_G.Add(CreateDistinctBuildOptionsSetting<Target>(
			new (target) => target.workspace.mBeefGlobalOptions.mDistinctBuildOptions,
			new (target, value) => CopyListValues(value, target.workspace.mBeefGlobalOptions.mDistinctBuildOptions)
		));

		// Beef Targeted
		BEEF_T.Add(new StringListSetting<Target>(
			"General/Preprocessor Macros",
			new (target) => target.Options.mPreprocessorMacros,
			new (target, value) => CopyListValues(value, target.Options.mPreprocessorMacros)
		));

		BEEF_T.Add(new BoolSetting<Target>(
			"General/Incremental Build",
			new (target) => target.Options.mIncrementalBuild,
			new (target, value) => target.Options.mIncrementalBuild = value
		));

		BEEF_T.Add(new EnumSetting<Target, IntermediateType>(
			"General/Intermediate Type",
			new (target) => (IntermediateType) target.Options.mIntermediateType,
			new (target, value) => target.Options.mIntermediateType = (.) value
		));

		BEEF_T.Add(new EnumSetting<Target, AllocType>(
			"General/Memory Allocator",
			new (target) => (AllocType) target.Options.mAllocType,
			new (target, value) => target.Options.mAllocType = (.) value
		));

		BEEF_T.Add(new StringSetting<Target>(
			"General/Custom Memory Allocator - Malloc",
			new (target) => target.Options.mAllocMalloc,
			new (target, value) => target.Options.mAllocMalloc.Set(value)
		));

		BEEF_T.Add(new StringSetting<Target>(
			"General/Custom Memory Allocator - Free",
			new (target) => target.Options.mAllocFree,
			new (target, value) => target.Options.mAllocFree.Set(value)
		));

		BEEF_T.Add(new StringSetting<Target>(
			"General/Target Triple",
			new (target) => target.Options.mTargetTriple,
			new (target, value) => target.Options.mTargetTriple.Set(value)
		));

		BEEF_T.Add(new StringSetting<Target>(
			"General/Target CPU",
			new (target) => target.Options.mTargetCPU,
			new (target, value) => target.Options.mTargetCPU.Set(value)
		));

		BEEF_T.Add(new EnumSetting<Target, SIMDInstructions>(
			"General/SIMD Instructions",
			new (target) => (SIMDInstructions) target.Options.mBfSIMDSetting,
			new (target, value) => target.Options.mBfSIMDSetting = (.) value
		));

		BEEF_T.Add(new EnumSetting<Target, OptimizationLevel>(
			"General/Optimization Level",
			new (target) => (OptimizationLevel) target.Options.mBfOptimizationLevel,
			new (target, value) => target.Options.mBfOptimizationLevel = (.) value
		));

		BEEF_T.Add(new EnumSetting<Target, LTOType>(
			"General/LTO Type",
			new (target) => (LTOType) target.Options.mLTOType,
			new (target, value) => target.Options.mLTOType = (.) value
		));

		BEEF_T.Add(new BoolSetting<Target>(
			"General/No Omit Frame Pointers",
			new (target) => target.Options.mNoOmitFramePointers,
			new (target, value) => target.Options.mNoOmitFramePointers = value
		));

		BEEF_T.Add(new BoolSetting<Target>(
			"General/Large Strings",
			new (target) => target.Options.mLargeStrings,
			new (target, value) => target.Options.mLargeStrings = value
		));

		BEEF_T.Add(new BoolSetting<Target>(
			"General/Large Collections",
			new (target) => target.Options.mLargeCollections,
			new (target, value) => target.Options.mLargeCollections = value
		));

		BEEF_T.Add(new EnumSetting<Target, WorkspaceDebugInfo>(
			"Debug/Debug Info",
			new (target) => (WorkspaceDebugInfo) target.Options.mEmitDebugInfo,
			new (target, value) => target.Options.mEmitDebugInfo = (.) value
		));

		BEEF_T.Add(new BoolSetting<Target>(
			"Debug/Runtime Checks",
			new (target) => target.Options.mRuntimeChecks,
			new (target, value) => target.Options.mRuntimeChecks = value
		));

		BEEF_T.Add(new BoolSetting<Target>(
			"Debug/Dynamic Cast Check",
			new (target) => target.Options.mEmitDynamicCastCheck,
			new (target, value) => target.Options.mEmitDynamicCastCheck = value
		));

		BEEF_T.Add(new BoolSetting<Target>(
			"Debug/Object Debug Flags",
			new (target) => target.Options.mEnableObjectDebugFlags,
			new (target, value) => target.Options.mEnableObjectDebugFlags = value
		));

		BEEF_T.Add(new BoolSetting<Target>(
			"Debug/Object Access Check",
			new (target) => target.Options.mEmitObjectAccessCheck,
			new (target, value) => target.Options.mEmitObjectAccessCheck = value
		));

		BEEF_T.Add(new BoolSetting<Target>(
			"Debug/Arithmetic Check",
			new (target) => target.Options.mArithmeticCheck,
			new (target, value) => target.Options.mArithmeticCheck = value
		));

		BEEF_T.Add(new BoolSetting<Target>(
			"Debug/Realtime Leak Check",
			new (target) => target.Options.mEnableRealtimeLeakCheck,
			new (target, value) => target.Options.mEnableRealtimeLeakCheck = value
		));

		BEEF_T.Add(new BoolSetting<Target>(
			"Debug/Enable Hot Compilation",
			new (target) => target.Options.mAllowHotSwapping,
			new (target, value) => target.Options.mAllowHotSwapping = value
		));

		BEEF_T.Add(new IntSetting<Target>(
			"Debug/Alloc Stack Trace Depth",
			new (target) => target.Options.mAllocStackTraceDepth,
			new (target, value) => target.Options.mAllocStackTraceDepth = value
		));

		// Build
		BUILD.Add(new EnumSetting<Target, ToolsetType>(
			"Toolset",
			new (target) => (ToolsetType) target.Options.mToolsetType,
			new (target, value) => target.Options.mToolsetType = (.) value
		));

		BUILD.Add(new EnumSetting<Target, WorkspaceBuildType>(
			"Build Type",
			new (target) => (WorkspaceBuildType) target.Options.mBuildKind,
			new (target, value) => target.Options.mBuildKind = (.) value
		));
	}
}