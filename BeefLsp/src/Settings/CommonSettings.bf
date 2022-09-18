namespace BeefLsp;

using System;
using System.Collections;

using IDE;

enum TargetType {
	case ConsoleApplication,
		 GuiApplication,
		 Library,
		 CustomBuild,
		 Test;

	public Project.TargetType To() {
		switch (this) {
		case .ConsoleApplication:	return .BeefConsoleApplication;
		case .GuiApplication:		return .BeefGUIApplication;
		case .Library:				return .BeefLib;
		case .CustomBuild:			return .CustomBuild;
		case .Test:					return .BeefTest;
		}
	}

	public static TargetType From(Project.TargetType type) {
		switch (type) {
		case .BeefGUIApplication:	return .GuiApplication;
		case .BeefLib:				return .Library;
		case .CustomBuild:			return .CustomBuild;
		case .BeefTest:				return .Test;
		default:					return .ConsoleApplication;
		}
	}

	public override void ToString(String str) {
		switch (this) {
		case .ConsoleApplication:	str.Append("Console Application");
		case .GuiApplication:		str.Append("GUI Application");
		case .Library:				str.Append("Library");
		case .CustomBuild:			str.Append("Custom Build");
		case .Test:					str.Append("Test");
		}
	}
}

enum RelocModel {
	case NotSet,
		 Static, 
		 PIC, 
		 DynamicNoPIC,
		 ROPI,
		 RWPI, 
		 ROPI_RWPI;

	public override void ToString(String str) {
		switch (this) {
		case .NotSet:		str.Append("Not Set");
		case .Static:		str.Append("Static");
		case .PIC:			str.Append("PIC");
		case .DynamicNoPIC:	str.Append("Dynamic No PIC");
		case .ROPI:			str.Append("ROPI");
		case .RWPI:			str.Append("RWPI");
		case .ROPI_RWPI:	str.Append("ROPI RWPI");
		}
	}
}

enum PICLevel {
	case NotSet,
		 Not,
		 Small, 
		 Big;

	public override void ToString(String str) {
		switch (this) {
		case .NotSet:	str.Append("Not Set");
		case .Not:		str.Append("Not");
		case .Small:	str.Append("Small");
		case .Big:		str.Append("Big");
		}
	}
}

enum OptimizationLevel {
	case NotSet,
		 O0,
		 O1,
		 O2,
		 O3,
		 Og,
		 OgPlus;

	public BuildOptions.BfOptimizationLevel? To() {
		return this == .NotSet ? null : (.) (this - 1);
	}

	public static OptimizationLevel From(BuildOptions.BfOptimizationLevel? level) {
		return level.HasValue ? (.) (level.Value + 1) : .NotSet;
	}

	public override void ToString(String str) {
		switch (this) {
		case .NotSet:	str.Append("Not Set");
		case .O0:		str.Append("O0");
		case .O1:		str.Append("O1");
		case .O2:		str.Append("O2");
		case .O3:		str.Append("O3");
		case .Og:		str.Append("Og");
		case .OgPlus:	str.Append("Og+");
		}
	}
}

enum BuildType {
	case Normal,
		 Test,
		 StaticLib,
		 DynamicLib,
		 Intermediate,
		 NotSupported;

	public override void ToString(String str) {
		switch (this) {
		case .Normal:		str.Append("Normal");
		case .Test:			str.Append("Test");
		case .StaticLib:	str.Append("Static Lib");
		case .DynamicLib:   str.Append("Dynamic Lib");
		case .Intermediate:	str.Append("Intermediate");
		case .NotSupported:	str.Append("Not Supported");
		}
	}
}

enum CLibrary {
	case None,
		 Dynamic,
		 Static,
		 DynamicDebug,
		 StaticDebug,
		 SystemMSVCRT;

	public override void ToString(String str) {
		switch (this) {
		case .None:			str.Append("None");
		case .Dynamic:		str.Append("Dynamic");
		case .Static:		str.Append("Static");
		case .DynamicDebug:	str.Append("Dynamic Debug");
		case .StaticDebug:	str.Append("Static Debug");
		case .SystemMSVCRT:	str.Append("System MSVCRT");
		}
	}
}

enum BeefLibrary {
	case Dynamic,
		 DynamicDebug,
		 Static;

	public override void ToString(String str) {
		switch (this) {
		case .Dynamic:		str.Append("Dynamic");
		case .DynamicDebug:	str.Append("Dynamic Debug");
		case .Static:		str.Append("Static");
		}
	}
}

enum BuildCommandTrigger {
	case Never,
		 IfFilesChanged,
		 Always;

	public override void ToString(String str) {
		switch (this) {
		case .Never:			str.Append("Never");
		case .IfFilesChanged:	str.Append("If Files Changed");
		case .Always:			str.Append("Always");
		}
	}
}

enum SIMDInstructions {
	case NotSet,
    	 None,
    	 MMX,
    	 SSE,
    	 SSE2,
    	 SSE3,
    	 SSE4,
    	 SSE41,
    	 AVX,
    	 AVX2;

	public BuildOptions.SIMDSetting? To() {
		return this == .NotSet ? null : (.) (this - 1);
	}

	public static SIMDInstructions From(BuildOptions.SIMDSetting? simd) {
		return simd.HasValue ? (.) (simd.Value + 1) : .NotSet;
	}

	public override void ToString(String str) {
		switch (this) {
		case .NotSet:	str.Append("Not Set");
		case .None:		str.Append("None");
		case .MMX:		str.Append("MMX");
		case .SSE:		str.Append("SSE");
		case .SSE2:		str.Append("SSE2");
		case .SSE3:		str.Append("SSE3");
		case .SSE4:		str.Append("SSE4");
		case .SSE41:	str.Append("SSE41");
		case .AVX:		str.Append("AVX");
		case .AVX2:		str.Append("AVX2");
		}
	}
}

enum DebugInfo {
	case NotSet,
    	 No,
    	 Yes,
    	 LinesOnly;

	public BuildOptions.EmitDebugInfo? To() {
		return this == .NotSet ? null : (.) (this - 1);
	}

	public static DebugInfo From(BuildOptions.EmitDebugInfo? info) {
		return info.HasValue ? (.) (info + 1) : .NotSet;
	}

	public override void ToString(String str) {
		switch (this) {
		case .NotSet:		str.Append("Not Set");
		case .No:			str.Append("No");
		case .Yes:			str.Append("Yes");
		case .LinesOnly:	str.Append("Lines Only");
		}
	}
}

enum TriStateBool {
	case NotSet,
		 No,
		 Yes;

	public bool? To() {
		switch (this) {
		case .NotSet:	return null;
		case .No:		return false;
		case .Yes:		return true;
		}
	}

	public static TriStateBool From(bool? value) {
		if (value.HasValue) return value.Value ? .Yes : .No;
		return .NotSet;
	}

	public override void ToString(String str) {
		switch (this) {
		case .NotSet:	str.Append("Not Set");
		case .No:		str.Append("No");
		case .Yes:		str.Append("Yes");
		}
	}
}

enum AlwaysInclude {
	case NotSet,
		 No,
		 IncludeType,
		 AssumeInstantiated,
		 IncludeAll,
		 IncludeFiltered;

	public override void ToString(String str) {
		switch (this) {
		case .NotSet:				str.Append("Not Set");
		case .No:					str.Append("No");
		case .IncludeType:			str.Append("Include Type");
		case .AssumeInstantiated:	str.Append("Assume Instantiated");
		case .IncludeAll:			str.Append("Include All");
		case .IncludeFiltered:		str.Append("Include Filtered");
		}
	}
}

enum ToolsetType {
	case GNU,
		 Microsoft,
		 LLVM;

	public override void ToString(String str) {
		switch (this) {
		case .GNU:			str.Append("GNU");
		case .Microsoft:	str.Append("Microsoft");
		case .LLVM:			str.Append("LLVM");
		}
	}
}

enum WorkspaceBuildType {
	case Normal,
		 Test;

	public override void ToString(String str) {
		switch (this) {
		case .Normal:	str.Append("Normal");
		case .Test:		str.Append("Test");
		}
	}
}

enum IntermediateType {
    case Object,
    	 IRCode,
    	 ObjectAndIRCode,
		 Bitcode,
		 BitcodeAndIRCode;

	public override void ToString(String str) {
		switch (this) {
		case .Object:			str.Append("Object");
		case .IRCode:			str.Append("IR Code");
		case .ObjectAndIRCode:	str.Append("Object and IR Code");
		case .Bitcode:			str.Append("Bitcode");
		case .BitcodeAndIRCode:	str.Append("Bitcode and IR Code");
		}
	}
}

enum LTOType {
	case None,
		 Thin;

	public override void ToString(String str) {
		str.Append(this == .None ? "None" : "Thin");
	}
}

enum WorkspaceDebugInfo {
	case No,
    	 Yes,
    	 LinesOnly;

	public override void ToString(String str) {
		switch (this) {
		case .No:			str.Append("No");
		case .Yes:			str.Append("Yes");
		case .LinesOnly:	str.Append("Lines Only");
		}
	}
}

enum AllocType {
	case CRT,
		 Debug,
		 Stomp,
		 JEMalloc,
		 JEMalloc_Debug,
		 TCMalloc,
		 TCMalloc_Debug,
		 Custom;

	public override void ToString(String str) {
		switch (this) {
		case .CRT:				str.Append("CRT");
		case .Debug:			str.Append("Debug");
		case .Stomp:			str.Append("Stomp");
		case .JEMalloc:			str.Append("JEMalloc");
		case .JEMalloc_Debug:	str.Append("JEMalloc Debug");
		case .TCMalloc:			str.Append("TCMalloc");
		case .TCMalloc_Debug:	str.Append("TCMalloc Debug");
		case .Custom:			str.Append("Custom");
		}
	}
}

class ReflectSettings {
	public AlwaysInclude alwaysInclude;
	public TriStateBool dynamicBoxing;
	public TriStateBool staticFields;
	public TriStateBool nonStaticFields;
	public TriStateBool staticMethods;
	public TriStateBool nonStaticMethods;
	public TriStateBool constructors;
	public String methodFilter = new .() ~ delete _;
}

static class CommonSettings {
	private static ReflectSettings REFLECT_SETTINGS = new .() ~ delete _;

	public static ObjectListSetting<T, DistinctBuildOptions> CreateDistinctBuildOptionsSetting<T>(Getter<T, List<DistinctBuildOptions>> getter, Setter<T, List<DistinctBuildOptions>> setter) {
		return new ObjectListSetting<T, DistinctBuildOptions>(
			"Distinct Build Options",
			getter,
			setter,

			new StringSetting<DistinctBuildOptions>(
				"Filter",
				new (options) => options.mFilter,
				new (options, value) => options.mFilter.Set(value)
			),
			new EnumSetting<DistinctBuildOptions, SIMDInstructions>(
				"SIMD Instructions",
				new (options) => SIMDInstructions.From(options.mBfSIMDSetting),
				new (options, value) => options.mBfSIMDSetting = value.To()
			),
			new EnumSetting<DistinctBuildOptions, OptimizationLevel>(
				"Optimization Level",
				new (options) => OptimizationLevel.From(options.mBfOptimizationLevel),
				new (options, value) => options.mBfOptimizationLevel = value.To()
			),
			new EnumSetting<DistinctBuildOptions, DebugInfo>(
				"Debug Info",
				new (options) => DebugInfo.From(options.mEmitDebugInfo),
				new (options, value) => options.mEmitDebugInfo = value.To()
			),
			new EnumSetting<DistinctBuildOptions, TriStateBool>(
				"Runtime Checks",
				new (options) => TriStateBool.From(options.mRuntimeChecks),
				new (options, value) => options.mRuntimeChecks = value.To()
			),
			new EnumSetting<DistinctBuildOptions, TriStateBool>(
				"Dynamic Cast Check",
				new (options) => TriStateBool.From(options.mEmitDynamicCastCheck),
				new (options, value) => options.mEmitDynamicCastCheck = value.To()
			),
			new EnumSetting<DistinctBuildOptions, TriStateBool>(
				"Object Access Check",
				new (options) => TriStateBool.From(options.mEmitObjectAccessCheck),
				new (options, value) => options.mEmitObjectAccessCheck = value.To()
			),
			new EnumSetting<DistinctBuildOptions, TriStateBool>(
				"Arithmetic Check",
				new (options) => TriStateBool.From(options.mArithmeticCheck),
				new (options, value) => options.mArithmeticCheck = value.To()
			),
			new IntSetting<DistinctBuildOptions>(
				"Alloc Stack trace Depth",
				new (options) => options.mAllocStackTraceDepth.HasValue ? options.mAllocStackTraceDepth.Value : -1,
				new (options, value) => options.mAllocStackTraceDepth = value == -1 ? null : value
			),
			new ObjectSetting<DistinctBuildOptions, ReflectSettings>(
				"Reflect",
				new (options) => {
					REFLECT_SETTINGS.alwaysInclude = (.) options.mReflectAlwaysInclude;
					REFLECT_SETTINGS.dynamicBoxing = .From(options.mReflectBoxing);
					REFLECT_SETTINGS.staticFields = .From(options.mReflectStaticFields);
					REFLECT_SETTINGS.nonStaticFields = .From(options.mReflectNonStaticFields);
					REFLECT_SETTINGS.staticMethods = .From(options.mReflectStaticMethods);
					REFLECT_SETTINGS.nonStaticMethods = .From(options.mReflectNonStaticMethods);
					REFLECT_SETTINGS.constructors = .From(options.mReflectConstructors);
					REFLECT_SETTINGS.methodFilter.Set(options.mReflectMethodFilter);

					return REFLECT_SETTINGS;
				},
				new (options, value) => {
					options.mReflectAlwaysInclude = (.) value.alwaysInclude;
					options.mReflectBoxing = value.dynamicBoxing.To();
					options.mReflectStaticFields = value.staticFields.To();
					options.mReflectNonStaticFields = value.nonStaticFields.To();
					options.mReflectStaticMethods = value.staticMethods.To();
					options.mReflectNonStaticMethods = value.nonStaticMethods.To();
					options.mReflectConstructors = value.constructors.To();
					options.mReflectMethodFilter.Set(value.methodFilter);
				},

				new EnumSetting<ReflectSettings, AlwaysInclude>(
					"Always Include",
					new (settings) => settings.alwaysInclude,
					new (settings, value) => settings.alwaysInclude = value
				),
				new EnumSetting<ReflectSettings, TriStateBool>(
					"Dynamic Boxes",
					new (settings) => settings.dynamicBoxing,
					new (settings, value) => settings.dynamicBoxing = value
				),
				new EnumSetting<ReflectSettings, TriStateBool>(
					"Static Fields",
					new (settings) => settings.staticFields,
					new (settings, value) => settings.staticFields = value
				),
				new EnumSetting<ReflectSettings, TriStateBool>(
					"Non-Static Fields",
					new (settings) => settings.nonStaticFields,
					new (settings, value) => settings.nonStaticFields = value
				),
				new EnumSetting<ReflectSettings, TriStateBool>(
					"Static Methods",
					new (settings) => settings.staticMethods,
					new (settings, value) => settings.staticMethods = value
				),
				new EnumSetting<ReflectSettings, TriStateBool>(
					"Non-Static Methods",
					new (settings) => settings.nonStaticMethods,
					new (settings, value) => settings.nonStaticMethods = value
				),
				new EnumSetting<ReflectSettings, TriStateBool>(
					"Constructors",
					new (settings) => settings.constructors,
					new (settings, value) => settings.constructors = value
				),
				new StringSetting<ReflectSettings>(
					"Method Filter",
					new (settings) => settings.methodFilter,
					new (settings, value) => settings.methodFilter.Set(value)
				)
			)
		);
	}

	public static void CopyListValues(List<String> from, List<String> to) {
		to.ClearAndDeleteItems();

		for (let string in from) {
			to.Add(new .(string));
		}
	}

	public static void CopyListValues(List<DistinctBuildOptions> from, List<DistinctBuildOptions> to) {
		to.ClearAndDeleteItems();

		for (let options in from) {
			to.Add(options.Duplicate());
		}
	}
}