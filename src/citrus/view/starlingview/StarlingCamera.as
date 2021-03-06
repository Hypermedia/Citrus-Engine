package citrus.view.starlingview {
	
	import citrus.view.ACitrusCamera;
	
	import starling.display.Sprite;
	
	import flash.geom.Point;
	import citrus.math.MathUtils;
	
	/**
	 * The Camera for the StarlingView.
	 *
	 * TODO LIST (to do after validation)
	 * - more optimization needed.
	 * - port directly to SpriteCamera (no difference)
	 * - take care of Starling's content scale factor for different devices (should need to affect _camProxy.scale maybe)
	 * - needs room for camera effects such as shaking. (which can currently be achieved by shaking the ghostTarget point
	 * internally, or setting a manualPosition externally and shake it... both seem like dodgy approaches though.)
	 */
	public class StarlingCamera extends ACitrusCamera
	{
		/**
		 * should we restrict zoom to bounds?
		 */
		public var restrictZoom:Boolean = false;
		
		/**
		 * the ease factor for zoom
		 */
		public var zoomEasing:Number = 0.05;
		
		/**
		 * the ease factor for rotation
		 */
		public var rotationEasing:Number = 0.05;
		
		/**
		 * _aabb holds the axis aligned bounding box of the camera in rect
		 * and its relative position to it (with offsetX and offsetY)
		 */
		protected var _aabbData:Object = { };
		
		/**
		 * the targeted rotation value.
		 */
		protected var _rotation:Number = 0;
		
		/**
		 * the targeted zoom value.
		 */
		protected var _zoom:Number = 1;
		
		/**
		 * ghostTarget is the eased position of target.
		 */
		protected var _ghostTarget:Point = new Point();
		
		/**
		 * targetPos is used for calculating ghostTarget.
		 * (not sure if really necessary)
		 */
		protected var _targetPos:Point = new Point();
		
		/**
		 * the _camProxy object is used as a container to hold the data to be applied to the _viewroot.
		 * it can be accessible publicly so that debugView can be correctly displaced, rotated and scaled as _viewroot will be.
		 */
		protected var _camProxy:Object = {x: 0, y: 0, offsetX: 0, offsetY: 0, scale: 1, rotation: 0};
		
		public function StarlingCamera(viewRoot:Sprite)
		{
			super(viewRoot);
			
			/*fix for different starling content scale factors. but super has already calculated cameraLensWidth and Height
			so might need to be applied in a different way.
			var ce:CitrusEngine = CitrusEngine.getInstance();
			cameraLensWidth = ce.stage.stageWidth / Starling.contentScaleFactor;
			cameraLensHeight = ce.stage.stageHeight / Starling.contentScaleFactor;*/
			
			_aabbData = MathUtils.createAABBData(0, 0, cameraLensWidth / _camProxy.scale, cameraLensHeight / _camProxy.scale, _camProxy.rotation);
		}
		
		/**
		 * sets the targeted rotation value to angle.
		 * @param	angle in radians.
		 */
		public function setRotation(angle:Number):void
		{
			_rotation = angle;
		}
		
		/**
		 * rotates the camera by the angle.
		 * adds angle to targeted rotation value.
		 * @param	angle in radians.
		 */
		public function rotate(angle:Number):void
		{
			_rotation += angle;
		}
		
		public function getRotation():Number
		{
			return _rotation;
		}
		
		/**
		 * sets the targeted zoom value to factor.
		 * @param	factor
		 */
		public function setZoom(factor:Number):void
		{
			_zoom = factor;
		}
		
		/**
		 * multiplies the targeted zoom value by factor.
		 * @param	factor
		 */
		public function zoom(factor:Number):void
		{
			_zoom *= factor;
		}
		
		public function getZoom():Number
		{
			return _zoom;
		}
		
		public function resetAABBData():void
		{
			_aabbData = MathUtils.createAABBData(_ghostTarget.x , _ghostTarget.y, cameraLensWidth / _camProxy.scale, cameraLensHeight / _camProxy.scale, - _camProxy.rotation);
		}
		
		override public function update():void
		{
			
			var diffRot:Number = _rotation - _camProxy.rotation;
			var velocityRot:Number = diffRot * rotationEasing;
			_camProxy.rotation += velocityRot;
			
			var diffZoom:Number = _zoom - _camProxy.scale;
			var velocityZoom:Number = diffZoom * zoomEasing;
			_camProxy.scale += velocityZoom;
			
			_camProxy.offsetX = offset.x;
			_camProxy.offsetY = offset.y;
			
			var invRotTarget:Point;
			
			if (_target)
			{
				_targetPos.x = _target.x;
				_targetPos.y = _target.y;
				
				var diffX:Number = _targetPos.x - _ghostTarget.x;
				var diffY:Number = _targetPos.y - _ghostTarget.y;
				var velocityX:Number = diffX * easing.x;
				var velocityY:Number = diffY * easing.y;
				
				_ghostTarget.x += velocityX;
				_ghostTarget.y += velocityY;
				
				invRotTarget = rotatePoint(new Point(_ghostTarget.x, _ghostTarget.y), -_camProxy.rotation);
				
				_camProxy.x = -invRotTarget.x * _camProxy.scale;
				_camProxy.y = -invRotTarget.y * _camProxy.scale;
				
			}
			else if (_manualPosition)
			{
				_ghostTarget.x = _manualPosition.x;
				_ghostTarget.y = _manualPosition.y;
				
				invRotTarget = rotatePoint(new Point(_ghostTarget.x, _ghostTarget.y), -_camProxy.rotation);
				
				_camProxy.x = -invRotTarget.x * _camProxy.scale;
				_camProxy.y = -invRotTarget.y * _camProxy.scale;
			}
			
			_camProxy.x += _camProxy.offsetX;
			_camProxy.y += _camProxy.offsetY;
			
			
			//reset AABBData because we changed rotation, zoom and ghost target position.
			resetAABBData();
			
			if (bounds && restrictZoom)
			{
				var lwratio:Number = _aabbData.rect.width*_camProxy.scale / bounds.width;
				var lhratio:Number = _aabbData.rect.height*_camProxy.scale / bounds.height;
				
				if (_aabbData.rect.width > bounds.width)
					_camProxy.scale = _zoom = lwratio;
				else if (_aabbData.rect.height > bounds.height)
					_camProxy.scale = _zoom = lhratio;
				
			}
			
			var rotScaledOffset:Point = rotatePoint(
			new Point(offset.x / _camProxy.scale, offset.y / _camProxy.scale),
			_camProxy.rotation);
			
			// move aabb
			_aabbData.rect.x -= rotScaledOffset.x;
			_aabbData.rect.y -= rotScaledOffset.y;
			
			boundscheck: if ( bounds && !bounds.containsRect(_aabbData.rect) )
			{
				
				var newAABBPos:Point = new Point(_aabbData.rect.x,_aabbData.rect.y);
				
				//x
				if (_aabbData.rect.left <= bounds.left || _aabbData.rect.width >= bounds.width)
					newAABBPos.x = bounds.left;
				else if (_aabbData.rect.right >= bounds.right)
					newAABBPos.x = bounds.right - _aabbData.rect.width;
				
				//y
				if (_aabbData.rect.top <= bounds.top || _aabbData.rect.height >= bounds.height)
					newAABBPos.y = bounds.top;
				else if (_aabbData.rect.bottom >= bounds.bottom)
					newAABBPos.y = bounds.bottom - _aabbData.rect.height;
				
				var newGTPos:Point = new Point(newAABBPos.x, newAABBPos.y);
				
				newGTPos.x -= _aabbData.offsetX;
				newGTPos.y -= _aabbData.offsetY;
				
				newGTPos.x += rotScaledOffset.x;
				newGTPos.y += rotScaledOffset.y;
				
				var invGT:Point = rotatePoint(new Point(newGTPos.x, newGTPos.y), -_camProxy.rotation);
				_camProxy.x = -invGT.x * _camProxy.scale + _camProxy.offsetX;
				_camProxy.y = -invGT.y * _camProxy.scale + _camProxy.offsetY;
				
			}
			
			_viewRoot.scaleX = _viewRoot.scaleY = _camProxy.scale;
			_viewRoot.rotation = _camProxy.rotation;
			
			_viewRoot.x = _camProxy.x;
			_viewRoot.y = _camProxy.y;
			
		}
		
		/**
		 * This function renders what's happening with the camera in screen space.
		 * helped a great deal at figuring out collision with bounds when rotating
		 * which in turn might help anyone implementing AABB collision detection using
		 * the MathUtils.createAABBData method.
		 * @param	sprite a flash display sprite to render to.
		 */
		public function renderDebug(sprite:*):void
		{
			
			sprite.x = cameraLensWidth>>1 - bounds.width>>1;
			sprite.y = cameraLensHeight>>1 - bounds.height>>1;
			sprite.scaleX =  0.2;
			sprite.scaleY = 0.2;
			
			var xo:Number, yo:Number, w:Number, h:Number;
			
			//create AABB of camera
			var AABB:Object = MathUtils.createAABBData(
			
			_ghostTarget.x ,
			_ghostTarget.y ,
			
			cameraLensWidth / _camProxy.scale,
			cameraLensHeight / _camProxy.scale,
			- _camProxy.rotation);
			
			sprite.graphics.clear();
			
			//draw bounds
			sprite.graphics.lineStyle(1, 0xFF0000);
			sprite.graphics.drawRect(
			bounds.left,
			bounds.top,
			bounds.width,
			bounds.height);
			
			//draw targets
			sprite.graphics.lineStyle(20, 0xFF0000);
			if(_target)
				sprite.graphics.drawCircle(_target.x, _target.y, 10);
			sprite.graphics.drawCircle(_ghostTarget.x, _ghostTarget.y, 10);
			
			//rotate and scale offset.
			var rotScaledOffset:Point = rotatePoint(
			new Point(offset.x / _camProxy.scale, offset.y / _camProxy.scale),
			_camProxy.rotation);
			
			//offset aabb rect according to rotated and scaled camera offset
			AABB.rect.x -= rotScaledOffset.x;
			AABB.rect.y -= rotScaledOffset.y;
			
			//draw aabb
			sprite.graphics.lineStyle(1, 0xFFFF00);
			sprite.graphics.drawRect(AABB.rect.x, AABB.rect.y, AABB.rect.width, AABB.rect.height);
			
			var c:Number = Math.cos(_camProxy.rotation);
			var s:Number = Math.sin(_camProxy.rotation);
			
			//draw rotated camera rect
			
			xo =  AABB.rect.x - AABB.offsetX;
			yo =  AABB.rect.y - AABB.offsetY;
			 
			w = cameraLensWidth / _camProxy.scale;
			h = cameraLensHeight / _camProxy.scale;
			
			sprite.graphics.lineStyle(1, 0x00F0FF);
			sprite.graphics.beginFill(0x000000, 0.2);
			sprite.graphics.moveTo(xo,
			yo);
			sprite.graphics.lineTo(
			xo + (w) * c + (0) * s ,
			yo + -(w) * s + (0) * c );
			sprite.graphics.lineTo(
			xo + (w) * c + (h) * s ,
			yo + -(w) * s + (h) * c );
			sprite.graphics.lineTo(
			xo + (0) * c + (h) * s ,
			yo + -(0) * s + (h) * c );
			sprite.graphics.lineTo(xo ,
			yo);
			sprite.graphics.endFill();
			
			if (bounds && !bounds.containsRect(AABB.rect))
			{
				//aabb is out of bounds, draw where it should be if constrained
				
				var newAABBPos:Point = new Point(AABB.rect.x,AABB.rect.y);
				
				//x
				if (AABB.rect.left <= bounds.left)
					newAABBPos.x = bounds.left;
				else if (AABB.rect.right >= bounds.right)
					newAABBPos.x = bounds.right - AABB.rect.width;
				
				//y
				if (AABB.rect.top <= bounds.top)
					newAABBPos.y = bounds.top;
				else if (AABB.rect.bottom >= bounds.bottom)
					newAABBPos.y = bounds.bottom - AABB.rect.height;
				
				sprite.graphics.lineStyle(1, 0xFFFFFF , 0.5);
				sprite.graphics.drawRect(newAABBPos.x, newAABBPos.y, AABB.rect.width, AABB.rect.height);
				
				//then using the new aabb position... draw the camera.
				
				xo =  newAABBPos.x - AABB.offsetX;
				yo =  newAABBPos.y - AABB.offsetY;
				 
				w = cameraLensWidth / _camProxy.scale;
				h = cameraLensHeight / _camProxy.scale;
				
				sprite.graphics.lineStyle(1, 0xFFFFFF, 0.5);
				sprite.graphics.beginFill(0xFFFFFF, 0.1);
				sprite.graphics.moveTo(xo,
				yo);
				sprite.graphics.lineTo(
				xo + (w) * c + (0) * s ,
				yo + -(w) * s + (0) * c );
				sprite.graphics.lineTo(
				xo + (w) * c + (h) * s ,
				yo + -(w) * s + (h) * c );
				sprite.graphics.lineTo(
				xo + (0) * c + (h) * s ,
				yo + -(0) * s + (h) * c );
				sprite.graphics.lineTo(xo ,
				yo);
				sprite.graphics.endFill();
				
				//and so the new position of the camera :
				
				var newGTPos:Point = new Point(newAABBPos.x, newAABBPos.y);
				
				sprite.graphics.lineStyle(20, 0xFFFFFF);
				sprite.graphics.drawCircle(newGTPos.x, newGTPos.y, 10);
				
				newGTPos.x -= AABB.offsetX;
				newGTPos.y -= AABB.offsetY;
				
				sprite.graphics.drawCircle(newGTPos.x, newGTPos.y, 10);
				
				//and we already have the rotated and scaled offset so lets add it.
				
				newGTPos.x += rotScaledOffset.x;
				newGTPos.y += rotScaledOffset.y;
				
				sprite.graphics.drawCircle(newGTPos.x, newGTPos.y, 10);
			
			}
			
		}
		
		/**
		 * The idea of pointFromLocal and pointToLocal was to manually do the calculations
		 * for globalToLocal and localToGlobal and have understandable alternatives.
		 * 
		 * if using globalToLocal from _viewroot inside the update function and before setting viewroot's position
		 * it will then do globalToLocal relative to the previous location and rotation of _viewroot (as
		 * viewroot will not be already moved, scaled and rotated.) 
		 * so it would be one frame behind...
		 */
		
		/**
		 *  equivalent of  globalToLocal.
		 */
		public function pointFromLocal(p:Point):Point
		{
			
			return rotatePoint(
			new Point(
			(p.x - _camProxy.x - _camProxy.offsetX) /_camProxy.scale, 
			(p.y - _camProxy.y - _camProxy.offsetY) /_camProxy.scale)
			, _camProxy.rotation);
			
			//return (_viewRoot as Sprite).globalToLocal(p);
		}
		
		/**
		 *  equivalent of localToGlobal
		 */
		public function pointToLocal(p:Point):Point
		{
			return (_viewRoot as Sprite).localToGlobal(p);
		}
		
		/**
		 * local helper to rotate points - should be moved to MathUtils ?
		 */
		private function rotatePoint(p:Point, a:Number):Point
		{
			var c:Number = Math.cos(a);
			var s:Number = Math.sin(a);
			return new Point(p.x * c + p.y * s, -p.x * s + p.y * c);
		}
		
		/**
		 * camProxy is read only.
		 * contains the data to be applied to container layers (_viewRoot and debug views).
		 */
		public function get camProxy():Object
		{
			return _camProxy;
		}
		
		/**
		 * read-only to get the eased position of the target, which is the actual point the camera
		 * is looking at ( - the offset )
		 */
		public function get ghostTarget():Point
		{
			return _ghostTarget;
		}
		
		override public function set manualPosition(p:Point):void
		{
			_target = null;
			_manualPosition = p;
		}
		
		override public function set target(o:Object):void
		{
			_manualPosition = null;
			_target = o;
		}
	
	}
}
