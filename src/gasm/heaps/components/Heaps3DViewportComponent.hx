package gasm.heaps.components;

import gasm.core.Component;
import gasm.core.components.AppModelComponent;
import gasm.core.enums.ComponentType;
import gasm.core.utils.Assert;
import gasm.heaps.components.HeapsScene3DComponent;
import h3d.Vector;

class Heaps3DViewportComponent extends Component {
	public var fov(default, set):Float;
	public var fovRatio(default, set):Float;

	var _config:Heaps3DViewportConfig;
	var _scale:Float;
	var _s3d:h3d.scene.Scene;
	var _hasBounds = false;
	var _appModel:AppModelComponent;

	public function new(config:Heaps3DViewportConfig) {
		_config = config;
		componentType = ComponentType.Actor;
	}

	public function getSizeAtZ(z:Float) {
		var a = _s3d.camera.unproject(1.0, 1.0, z);
		var b = _s3d.camera.unproject(-1.0, -1.0, z);
		return new h3d.Vector(Math.abs(a.x - b.x), Math.abs(a.y - b.y), z);
	}

	override public function init() {
		_appModel = owner.getFromParents(AppModelComponent);
		_s3d = owner.getFromParents(HeapsScene3DComponent).scene3d;
		final cam = _s3d.camera;
		cam.pos = _config.cameraPos;
		if (_config.rightHanded) {
			cam.rightHanded = true;
			cam.up = new h3d.Vector(0, 1, 0);
		}
		cam.target = _config.cameraTarget;
		cam.zNear = _config.zNear;
		cam.zFar = _config.zFar;

		if (_config.fov != null) {
			fov = _config.fov;
			fovRatio = _config.fovRatio;
		}

		if (_config.boundsObject != null) {
			_s3d.visible = false;
		}
	}

	function set_fov(val:Float) {
		fov = val;
		_s3d.camera.setFovX(fov, fovRatio);
		return val;
	}

	function set_fovRatio(val:Float) {
		Assert.that(fov != null, 'Trying to set fovRatio without a set fov');
		fovRatio = val;
		fov = fov;
		return val;
	}

	override public function update(dt:Float) {
		if (!_hasBounds && _config.boundsObject != null) {
			var bounds = _config.boundsObject.getBounds();
			// Empty bounds has values between -1e20 and 1e20
			if (bounds.xMin != 1e20) {
				_s3d.visible = true;
				var top = bounds.ySize;
				var right = bounds.xSize;
				var w = _config.bounds2d.width / _appModel.pixelRatio;
				var h = _config.bounds2d.height / _appModel.pixelRatio;
				var wFactor = top / w;
				var hFactor = right / h;
				var wRatio = w * wFactor * _config.boundsMult.x;
				var hRatio = h * hFactor * _config.boundsMult.y;
				var ratio = Math.min(wRatio, hRatio);
				if (_scale != ratio) {
					_s3d.setScale(ratio);
					_s3d.camera.update();
					_scale = ratio;
					if (fov != null) {
						fovRatio = ratio;
					}
				}
				_hasBounds = true;
			}
		}
	}
}

@:structInit
class Heaps3DViewportConfig {
	public var boundsObject:h3d.scene.Object = null;
	public var boundsMult = new Vector(1, 1);
	public var bounds2d:h2d.col.Bounds = null;
	public var cameraPos = new Vector(2, 3, 4);
	public var cameraTarget = new Vector(-0.00001);
	public var zNear = 1.0;
	public var zFar = 100.0;
	public var fov:Null<Float> = null;
	public var fovRatio:Float = 4 / 3;
	public var rightHanded = true;
}
