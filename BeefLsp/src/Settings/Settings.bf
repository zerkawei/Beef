namespace BeefLsp;

using System;
using System.Collections;

using IDE;

typealias Getter<T, V> = delegate V(T target);
typealias Setter<T, V> = delegate void(T target, V value);

class SettingGroup<T> {
	public int id;
	public StringView name;

	private bool configuration, platform;
	private List<ISetting<T>> settings = new .() ~ DeleteContainerAndItems!(_);
	
	public this(int id, StringView name, bool configuration, bool platform) {
		this.id = id;
		this.name = name;
		this.configuration = configuration;
		this.platform = platform;
	}

	public void Add(ISetting<T> setting) {
		settings.Add(setting);
	}

	public void Clear() {
		settings.ClearAndDeleteItems();
	}

	public bool Set(T target, StringView settingName, Json value) {
		for (let setting in settings) {
			if (setting.Name != settingName) continue;

			setting.FromJsonValue(target, value);
			return true;
		}

		return false;
	}

	public Json ToJsonSchema() {
		Json json = .Object();

		json["id"] = .Number(id);
		json["name"] = .String(name);
		json["configuration"] = .Bool(configuration);
		json["platform"] = .Bool(platform);

		Json settingsJson = .Array();
		json["settings"] = settingsJson;

		for (let setting in settings) {
			settingsJson.Add(setting.ToJsonSchema());
		}

		return json;
	}

	public Json ToJsonValues(T target) {
		Json json = .Object();

		json["id"] = .Number(id);

		Json settingsJson = .Object();
		json["settings"] = settingsJson;

		for (let setting in settings) {
			settingsJson[setting.Name] = setting.ToJsonValue(target);
		}

		return json;
	}

	public void FromJsonValues(T target, Json json) {
		for (let pair in json.AsObject) {
			for (let setting in settings) {
				if (setting.Name == pair.key) {
					setting.FromJsonValue(target, pair.value);
					break;
				}
			}
		}
	}
}

interface ISetting<T> {
	public StringView Name { get; };

	public Json ToJsonSchema();

	public abstract Json ToJsonValue(T target);
	public abstract void FromJsonValue(T target, Json json);
}

abstract class Setting<T, V> : ISetting<T> {
	public StringView type;
	public String name ~ delete _;

	private Getter<T, V> getter ~ delete _;
	private Setter<T, V> setter ~ delete _;

	protected this(StringView type, StringView name, Getter<T, V> getter, Setter<T, V> setter) {
		this.type = type;
		this.name = new .(name);
		this.getter = getter;
		this.setter = setter;
	}

	public StringView Name => name;

	public V Get(T target) => getter(target);
	public void Set(T target, V value) => setter(target, value);

	public Json ToJsonSchema() {
		Json json = .Object();

		json["type"] = .String(type);
		json["name"] = .String(name);

		ToJsonSchemaCustom(json);
		return json;
	}

	public abstract Json ToJsonValue(T target);
	public abstract void FromJsonValue(T target, Json json);

	protected virtual void ToJsonSchemaCustom(Json json) {}
}

class BoolSetting<T> : Setting<T, bool> {
	public this(StringView name, Getter<T, bool> getter, Setter<T, bool> setter) : base("bool", name, getter, setter) {}

	public override Json ToJsonValue(T target) {
		return .Bool(Get(target));
	}

	public override void FromJsonValue(T target, Json json) {
		Set(target, json.AsBool);
	}
}

class IntSetting<T> : Setting<T, int32> {
	private bool negativeEqualsNotSet;

	public this(StringView name, Getter<T, int32> getter, Setter<T, int32> setter, bool negativeEqualsNotSet = false) : base("int", name, getter, setter) {
		this.negativeEqualsNotSet = negativeEqualsNotSet;
	}

	protected override void ToJsonSchemaCustom(Json json) {
		json["negativeEqualsNotSet"] = .Bool(negativeEqualsNotSet);
	}

	public override Json ToJsonValue(T target) {
		return .Number(Get(target));
	}

	public override void FromJsonValue(T target, Json json) {
		Set(target, (.) json.AsNumber);
	}
}

enum StringSettingType {
	Plain,
	File,
	Folder
}

class StringSetting<T> : Setting<T, StringView> {
	public StringSettingType stringType;

	public this(StringView name, Getter<T, StringView> getter, Setter<T, StringView> setter, StringSettingType type = .Plain) : base("string", name, getter, setter) {
		this.stringType = type;
	}

	protected override void ToJsonSchemaCustom(Json json) {
		json["stringType"] = .String(stringType.ToString(.. scope .()));
	}

	public override Json ToJsonValue(T target) {
		return .String(Get(target));
	}

	public override void FromJsonValue(T target, Json json) {
		Set(target, json.AsString);
	}
}

class EnumSetting<T, E> : Setting<T, E> where E : enum {
	public this(StringView name, Getter<T, E> getter, Setter<T, E> setter) : base("enum", name, getter, setter) {}

	protected override void ToJsonSchemaCustom(Json json) {
		Json values = .Array();
		json["values"] = values;

		for (let value in Enum.GetValues<E>()) {
			values.Add(.String(value.ToString(.. scope .())));
		}
	}

	public override Json ToJsonValue(T target) {
		return .String(Get(target).ToString(.. scope .()));
	}

	public override void FromJsonValue(T target, Json json) {
		String str = scope .();

		for (let value in Enum.GetValues<E>()) {
			value.ToString(str);

			if (str == json.AsString) {
				Set(target, value);
				break;
			}

			str.Clear();
		}
	}
}

class StringListSetting<T> : Setting<T, List<String>> {
	public this(StringView name, Getter<T, List<String>> getter, Setter<T, List<String>> setter) : base("string-list", name, getter, setter) {}

	public override Json ToJsonValue(T target) {
		Json json = .Array();

		for (let string in Get(target)) {
			json.Add(.String(string));
		}

		return json;
	}

	public override void FromJsonValue(T target, Json json) {
		List<String> list = scope .(json.AsArray.Count);

		for (let value in json.AsArray) {
			list.Add(scope:: .(value.AsString));
		}

		Set(target, list);
	}
}

class ObjectSetting<T, O> : Setting<T, O> where O : class, new {
	private ISetting<O>[] settings ~ DeleteContainerAndItems!(_);

	public this(StringView name, Getter<T, O> getter, Setter<T, O> setter, params ISetting<O>[] settings) : base("object", name, getter, setter) {
		this.settings = new .[settings.Count];
		settings.CopyTo(this.settings);
	}

	protected override void ToJsonSchemaCustom(Json json) {
		Json settingsJson = .Array();
		json["settings"] = settingsJson;

		for (let setting in settings) {
			settingsJson.Add(setting.ToJsonSchema());
		}
	}

	public override Json ToJsonValue(T target) {
		Json json = .Object();
		O object = Get(target);

		for (let setting in settings) {
			json[setting.Name] = setting.ToJsonValue(object);
		}

		return json;
	}

	public override void FromJsonValue(T target, Json json) {
		O object = scope .();
		
		for (let pair in json.AsObject) {
			for (let setting in settings) {
				if (setting.Name == pair.key) {
					setting.FromJsonValue(object, pair.value);
					break;
				}
			}
		}

		Set(target, object);
	}
}

class ObjectListSetting<T, O> : Setting<T, List<O>> where O : class, new {
	private ISetting<O>[] settings ~ DeleteContainerAndItems!(_);

	public this(StringView name, Getter<T, List<O>> getter, Setter<T, List<O>> setter, params ISetting<O>[] settings) : base("object-list", name, getter, setter) {
		this.settings = new .[settings.Count];
		settings.CopyTo(this.settings);
	}

	protected override void ToJsonSchemaCustom(Json json) {
		// Settings
		Json settingsJson = .Array();
		json["settings"] = settingsJson;

		for (let setting in settings) {
			settingsJson.Add(setting.ToJsonSchema());
		}

		// Default values
		O object = scope .();

		Json defaultValues = .Object();
		json["defaultValues"] = defaultValues;

		for (let setting in settings) {
			defaultValues[setting.Name] = setting.ToJsonValue(object);
		}
	}

	public override Json ToJsonValue(T target) {
		Json json = .Array();

		for (let object in Get(target)) {
			Json objectJson = .Object();
			json.Add(objectJson);

			for (let setting in settings) {
				objectJson[setting.Name] = setting.ToJsonValue(object);
			}
		}

		return json;
	}

	public override void FromJsonValue(T target, Json json) {
		List<O> list = scope .(json.AsArray.Count);

		for (let objectJson in json.AsArray) {
			O object = scope:: .();

			for (let pair in objectJson.AsObject) {
				for (let setting in settings) {
					if (setting.Name == pair.key) {
						setting.FromJsonValue(object, pair.value);
						break;
					}
				}
			}

			list.Add(object);
		}

		Set(target, list);
	}
}