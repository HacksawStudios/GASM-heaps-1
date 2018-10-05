package gasm.heaps;

import hacksaw.core.data.GameConfig;
import tweenx909.TweenX;
import hxd.Charset;
import gasm.assets.Loader.AssetType;
import gasm.assets.Loader;
import gasm.core.components.AppModelComponent;
import gasm.core.Context;
import gasm.core.Engine;
import gasm.core.Entity;
import gasm.core.IEngine;
import gasm.core.ISystem;
import gasm.heaps.components.HeapsSpriteComponent;
import gasm.heaps.systems.HeapsCoreSystem;
import gasm.heaps.systems.HeapsRenderingSystem;
import gasm.heaps.systems.HeapsSoundSystem;
import gasm.heaps.data.Atlas;
import hxd.App;

/**
 * ...
 * @author Leo Bergman
 */
class HeapsContext extends App implements Context {
	public var baseEntity(get, null):Entity;
	public var systems(default, null):Array<ISystem>;
	public var appModel(default, null):AppModelComponent;

	var _engine:IEngine;
	var _core:ISystem;
	var _renderer:ISystem;
	var _sound:ISystem;
	// Populate in subclass with bindings to asset containers
	var _assetContainers:AssetContainers;
	var _assetConfig:AssetConfig;
	var _soundSupport:Bool;

	public function new(?core:ISystem, ?renderer:ISystem, ?sound:ISystem, ?engine:IEngine) {
		_core = core;
		_renderer = renderer;
		_sound = sound;
		_engine = engine;
		super();

		appModel = new AppModelComponent();
		_assetConfig = {};
	}

	public function preload(progress:Int->Void, done:Void->Void) {
		#if js
		_soundSupport = (Reflect.field(js.Browser.window, "AudioContext") != null || Reflect.field(js.Browser.window, "webkitAudioContext") != null);
		if (_soundSupport) {
			var myAudio:js.html.AudioElement = cast js.Browser.document.createElement('audio');
			if (myAudio.canPlayType != null) {
				var canPlayMp4 = myAudio.canPlayType('video/mp4');
				var canPlayWebm = myAudio.canPlayType('audio/webm; codecs="vorbis"');
				var supported = {webm: canPlayWebm, mp4: canPlayMp4};
				var ext:String = switch (supported) {
					case {webm: 'probably'}: '.webm';
					case {webm: 'maybe', mp4: 'probably'}: '.mp4';
					case {webm: 'maybe', mp4: 'maybe'}: '.webm';
					case {webm: 'maybe', mp4: ''}: '.webm';
					case {webm: '', mp4: 'maybe'}: '.mp4';
					case {webm: '', mp4: 'probably'}: '.mp4';
					default: null;
				}
				if (ext == null) {
					_soundSupport = false;
					trace('Neither webm or m4a supported, no audio will play');
				} else {
					_soundSupport = true;
					_assetConfig.formats = [{type: AssetType.Sound, extension: ext}];
				}
			}
		}
		#end
		engine.render(this);
		var bitmapFonts = new haxe.ds.StringMap<haxe.io.Bytes>();
		var atlases = new haxe.ds.StringMap<haxe.io.Bytes>();
		var loader = new Loader('assets/desc.json', _assetConfig);
		loader.onReady = function() {
			for (img in Type.getClassFields(_assetContainers.images)) {
				loader.queueItem(img, AssetType.Image);
			}
			if (_soundSupport) {
				for (snd in Type.getClassFields(_assetContainers.sounds)) {
					loader.queueItem(snd, AssetType.Sound);
				}
			}
			for (fnt in Type.getClassFields(hacksaw.core.data.FontList)) {
				loader.queueItem(fnt, AssetType.Font);
			}
			for (bmFnt in Type.getClassFields(_assetContainers.bitmapFonts)) {
				loader.queueItem(bmFnt, AssetType.BitmapFont);
			}
			for (atlas in Type.getClassFields(_assetContainers.atlases)) {
				loader.queueItem(atlas, AssetType.Atlas);
			}
			for (gradient in Type.getClassFields(_assetContainers.gradients)) {
				loader.queueItem(gradient, AssetType.Gradient);
			}
			for (config in Reflect.fields(_assetContainers.brandingConfigs)) {
				loader.queueItem(config, AssetType.Config);
			}
			loader.load();
		}
		loader.onComplete = function() {
			haxe.Timer.delay(done, 0);
		}
		loader.onProgress = function(percent:Int) {
			progress(percent);
			engine.render(this);
		}
		loader.onError = function(error:String) {
			throw error;
		}
		loader.addHandler(AssetType.Image, function(item:HandlerItem) {
			Reflect.setField(_assetContainers.images, item.id, hxd.res.Any.fromBytes('${item.path}', item.data).toTile());
		});

		loader.addHandler(AssetType.Sound, function(item:HandlerItem) {
			#if byteSounds
			Reflect.setField(_assetContainers.sounds, item.id, item.data);
			#else
			Reflect.setField(_assetContainers.sounds, item.id, hxd.res.Any.fromBytes('sound/${item.id}', item.data).toSound());
			#end
		});

		loader.addHandler(AssetType.Font, function(item:HandlerItem) {
			#if (heaps > "1.1.0")
			var fnt = hxd.res.Any.fromBytes('font/${item.id}', item.data).to(hxd.res.Font);
			#else
			var fnt = hxd.res.Any.fromBytes('font/${item.id}', item.data).toFont();
			#end
			if (fnt != null) {
				_assetContainers.fonts.set(item.id, fnt);
			} else {
				throw 'Unable to parse font ' + item.id;
			}
		});

		loader.addHandler(AssetType.BitmapFont, function(item:HandlerItem) {
			if (bitmapFonts.exists(item.id)) {
				var bmImg = bitmapFonts.get(item.id);
				var font = parseFont(item.id, item.data, bmImg);
				Reflect.setField(_assetContainers.fonts, item.id, font);
			} else {
				bitmapFonts.set(item.id, item.data);
			}
		});

		loader.addHandler(AssetType.BitmapFontImage, function(item:HandlerItem) {
			if (bitmapFonts.exists(item.id)) {
				var bmFont = bitmapFonts.get(item.id);
				var font = parseFont(item.id, bmFont, item.data);
				Reflect.setField(_assetContainers.fonts, item.id, font);
			} else {
				bitmapFonts.set(item.id, item.data);
			}
		});

		loader.addHandler(AssetType.Atlas, function(item:HandlerItem) {
			if (atlases.exists(item.id)) {
				var atlasImg = atlases.get(item.id);
				var atlas = parseAtlas(item.id, item.data, atlasImg);
				Reflect.setField(_assetContainers.atlases, item.id, atlas);
			} else {
				atlases.set(item.id, item.data);
			}
		});
		loader.addHandler(AssetType.Gradient, function(item:HandlerItem) {
			var grd = hxd.res.Any.fromBytes('${item.path}', item.data).to(hxd.res.Gradients);
			Reflect.setField(_assetContainers.gradients, item.id, grd);
		});

		loader.addHandler(AssetType.AtlasImage, function(item:HandlerItem) {
			if (atlases.exists(item.id)) {
				var atlasDef = atlases.get(item.id);
				var atlas = parseAtlas(item.id, atlasDef, item.data);
				Reflect.setField(_assetContainers.atlases, item.id, atlas);
			} else {
				atlases.set(item.id, item.data);
			}
		});

		loader.addHandler(AssetType.Config, function(item:HandlerItem) {
			switch (item.id) {
				case 'gameconfig':
					var data = haxe.Json.parse(item.data.toString());
					Reflect.setField(_assetContainers.brandingConfigs, item.id, data);
				default:
					null;
			}
		});
	}

	override function init() {
		_core = _core != null ? _core : new HeapsCoreSystem(s2d);
		_renderer = _renderer != null ? _renderer : new HeapsRenderingSystem(s2d);
		_sound = _sound != null ? _sound : new HeapsSoundSystem();
		systems = [_core, _renderer, _sound];
		_engine = _engine != null ? _engine : new Engine(systems);

		#if js
		var hidden:String = null;
		var visibilityChange:String = null;
		if (js.Browser.document.hidden != null) { // Opera 12.10 and Firefox 18 and later support
			hidden = "hidden";
			visibilityChange = "visibilitychange";
		} else if (Reflect.field(js.Browser.document, 'msHidden') != null) {
			hidden = "msHidden";
			visibilityChange = "msvisibilitychange";
		} else if (Reflect.field(js.Browser.document, 'webkitHidden') != null) {
			hidden = "webkitHidden";
			visibilityChange = "webkitvisibilitychange";
		}
		var handleVisibilityChange = function() {
			appModel.frozen = Reflect.field(js.Browser.document, hidden);
		}
		js.Browser.document.addEventListener(visibilityChange, handleVisibilityChange, false);
		appModel.frozen = Reflect.field(js.Browser.document, hidden);
		#end

		var comp = new HeapsSpriteComponent(cast s2d);
		baseEntity.add(comp);
		baseEntity.add(appModel);
		onResize();
	}

	override function onResize() {
		var stage = hxd.Stage.getInstance();
		appModel.stageSize.x = stage.width;
		appModel.stageSize.y = stage.height;
		appModel.resizeSignal.emit({width: appModel.stageSize.x, height: appModel.stageSize.y});
	}

	override function update(dt:Float) {
		if (!appModel.frozen) {
			_engine.tick();
		}
	}

	function parseAtlas(id:String, definition:haxe.io.Bytes, image:haxe.io.Bytes):Atlas {
		var file = hxd.res.Any.fromBytes('font/$id', image).toTile();
		var atlas:Atlas = {
			tile: file,
			contents: new Map(),
			tiles: [],
		}
		var lines = definition.toString().split("\n");
		while (lines.length > 0) {
			var line = StringTools.trim(lines.shift());
			if (line == "")
				continue;
			while (lines.length > 0) {
				var line = StringTools.trim(lines.shift());
				if (line == "")
					break;
				var prop = line.split(": ");
				if (prop.length > 1)
					continue;
				var key = line;
				var tileX = 0, tileY = 0, tileW = 0, tileH = 0, tileDX = 0, tileDY = 0, origW = 0, origH = 0, index = 0;
				while (lines.length > 0) {
					var line = StringTools.trim(lines.shift());
					var prop = line.split(": ");
					if (prop.length == 1) {
						lines.unshift(line);
						break;
					}
					var v = prop[1];
					switch (prop[0]) {
						case "rotate":
							if (v == "true")
								throw "Rotation not supported in atlas";
						case "xy":
							var vals = v.split(", ");
							tileX = Std.parseInt(vals[0]);
							tileY = Std.parseInt(vals[1]);
						case "size":
							var vals = v.split(", ");
							tileW = Std.parseInt(vals[0]);
							tileH = Std.parseInt(vals[1]);
						case "offset":
							var vals = v.split(", ");
							tileDX = Std.parseInt(vals[0]);
							tileDY = Std.parseInt(vals[1]);
						case "orig":
							var vals = v.split(", ");
							origW = Std.parseInt(vals[0]);
							origH = Std.parseInt(vals[1]);
						case "index":
							index = Std.parseInt(v);
							if (index < 0)
								index = 0;
						default:
							trace("Unknown prop " + prop[0]);
					}
				}
				// offset is bottom-relative
				tileDY = origH - (tileH + tileDY);

				var t = file.sub(tileX, tileY, tileW, tileH, tileDX, tileDY);
				var tl = atlas.contents.get(key);
				if (tl == null) {
					tl = [];
					atlas.contents.set(key, tl);
				}
				tl[index] = {t: t, width: origW, height: origH};
			}
		}

		var tiles:Array<h2d.Tile> = [];
		for (tile in Reflect.fields(atlas.contents)) {
			var tileData:h2d.Tile = Reflect.field(atlas.contents, tile);
			var fields:Array<String> = Reflect.fields(tileData);
			for (a in fields) {
				var d:Array<Dynamic> = Reflect.field(tileData, a);
				for (t in d) {
					tiles.push(Reflect.field(t, 't'));
				}
			}
		}
		atlas.tiles = tiles;
		return atlas;
	}

	@:access(h2d.Font)
	function parseFont(id:String, definition:haxe.io.Bytes, image:haxe.io.Bytes):h2d.Font {
		// Taken from https://github.com/HeapsIO/heaps/blob/master/hxd/res/BitmapFont.hx since there seems to be no way to parse bitmap font without using heaps resrouce system directly.
		var xml = new haxe.xml.Fast(Xml.parse(definition.toString()).firstElement());
		var tile = hxd.res.Any.fromBytes('font/$id', image).toTile();
		var glyphs = new Map();
		var size = Std.parseInt(xml.att.size);
		var lineHeight = Std.parseInt(xml.att.height);
		var name = xml.att.family;
		for (c in xml.elements) {
			var r = c.att.rect.split(" ");
			var o = c.att.offset.split(" ");
			var t = tile.sub(Std.parseInt(r[0]), Std.parseInt(r[1]), Std.parseInt(r[2]), Std.parseInt(r[3]), Std.parseInt(o[0]), Std.parseInt(o[1]));
			var fc = new h2d.Font.FontChar(t, Std.parseInt(c.att.width) - 1);
			for (k in c.elements)
				fc.addKerning(k.att.id.charCodeAt(0), Std.parseInt(k.att.advance));
			var code = c.att.code;
			if (StringTools.startsWith(code, "&#"))
				glyphs.set(Std.parseInt(code.substr(2, code.length - 3)), fc);
			else
				glyphs.set(c.att.code.charCodeAt(0), fc);
		}
		if (glyphs.get(" ".code) == null)
			glyphs.set(" ".code, new h2d.Font.FontChar(tile.sub(0, 0, 0, 0), size >> 1));

		var font = new h2d.Font(name, size);
		font.glyphs = glyphs;
		font.lineHeight = lineHeight;
		font.tile = tile;

		var padding = 0;
		var space = glyphs.get(" ".code);
		if (space != null)
			padding = (space.t.height >> 1);

		var a = glyphs.get("A".code);
		if (a == null)
			a = glyphs.get("a".code);
		if (a == null)
			a = glyphs.get("0".code); // numerical only
		if (a == null)
			font.baseLine = font.lineHeight - 2 - padding;
		else
			font.baseLine = a.t.dy + a.t.height - padding;

		return font;
	}

	public function get_baseEntity():Entity {
		return _engine.baseEntity;
	}
}

typedef AssetContainers = {
	?images:Dynamic,
	?sounds:Dynamic,
	?fonts:haxe.ds.StringMap<hxd.res.Font>,
	?bitmapFonts:Dynamic,
	?atlases:Dynamic,
	?gradients:Dynamic,
	?configs:Dynamic,
	?brandingConfigs:BrandingConfigs,
}

typedef BrandingConfigs = {
	gameconfig:Dynamic,
	sounds:Dynamic,
	pools:Dynamic,
	events:Dynamic,
	groups:Dynamic
}
