package
{
    import fl.video.*;	
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.external.*;
	import flash.utils.Timer;
	import flash.events.TimerEvent;
	
	public class CBVideoPlayer extends Sprite 
	{
		private var videoPath:String = "/video1.mp4";
		private var player:VideoPlayer;
		private var muted:Boolean = false;
		private var volumeBeforeMute:Number = 1;
		private var seekpoints:Array = [];
		private var state:String;
		private var rewindTimer:Timer;
		private var forwardTimer:Timer;				
		
		public function CBVideoPlayer() {
			_forceNCManager:fl.video.NCManager;
			player = new VideoPlayer();
            player.playheadUpdateInterval = 1000;
			player.load(videoPath);
			player.setSize(640, 360); // this should probably come from html tag attributes
			player.x = 0;
			player.y = 0;
			player.addEventListener(VideoEvent.PLAYHEAD_UPDATE, playheadUpdateHandler);
			player.addEventListener(VideoEvent.STATE_CHANGE, stateChangeHandler);
			player.addEventListener(MetadataEvent.METADATA_RECEIVED, metadataRecievedHandler);			
			addChild(player);
			
			rewindTimer = new Timer(250);
			rewindTimer.addEventListener(TimerEvent.TIMER, rewindTimerRun);
			
			forwardTimer = new Timer(250);
			forwardTimer.addEventListener(TimerEvent.TIMER, forwardTimerRun);						
			
			if (ExternalInterface.available) {
				ExternalInterface.addCallback("getMuted", getMuted);
				ExternalInterface.addCallback("setMuted", setMuted);
				ExternalInterface.addCallback("getCurrentTime", getCurrentTime);
				ExternalInterface.addCallback("getDuration", getDuration);				
				ExternalInterface.addCallback("getWidth", getWidth);
				ExternalInterface.addCallback("getPaused", getPaused);
				ExternalInterface.addCallback("setPaused", setPaused);
				ExternalInterface.addCallback("setPlaying", setPlaying);
				ExternalInterface.addCallback("setStopped", setStopped);
				ExternalInterface.addCallback("getVolume", getVolume);
				ExternalInterface.addCallback("setVolume", setVolume);				
				ExternalInterface.addCallback("jumpBack", jumpBack);				
				ExternalInterface.addCallback("jumpForward", jumpForward);
				ExternalInterface.addCallback("rewindStart", rewindStart);				
				ExternalInterface.addCallback("forwardStart", forwardStart);				
				ExternalInterface.addCallback("rewindStop", rewindStop);				
				ExternalInterface.addCallback("forwardStop", forwardStop);								
				//ExternalInterface.addCallback("seek", seek);				
			}
		}

		public function getMuted():Boolean {
			return this.muted;
		}
		
		public function setMuted(value:Boolean):void {
			if (value) {
				this.muted = true;
				this.volumeBeforeMute = player.volume;
				player.volume = 0;
			}
			else {
				this.muted = false;
				player.volume = volumeBeforeMute;
			}
		}

		public function rewindStart():void {
			rewindTimer.start();
		}
		
		public function rewindStop():void {
			rewindTimer.stop();
		}
		
		public function forwardStart():void {
			forwardTimer.start();
		}
		
		public function forwardStop():void {
			forwardTimer.stop();
		}		
		
		private function rewindTimerRun(event:TimerEvent):void {
			jumpBack(2);
		}
		
		private function forwardTimerRun(event:TimerEvent):void {
			jumpForward(2);
		}		
		
		public function getCurrentTime():Number {
			return player.playheadTime;
		}

		public function getDuration():Number {
			return player.totalTime;
		}		
				
		public function getWidth():int {
			return player.videoWidth;
		}
		
		public function getPaused():Boolean {
			return player.state == VideoState.PAUSED || player.state == VideoState.STOPPED;
		}		
		
		public function setPaused():void {
			player.pause();
		}		
		
		public function setPlaying():void {
			player.play();
		}
		
		public function setStopped():void {
			player.stop();
			player.seek(0);			
		}
		
		public function getVolume():Number {
			var volLevel:Number;
			
			if (this.muted) {
				volLevel = this.volumeBeforeMute; 
			}
			else {
				volLevel = player.volume;
			}
			
			return volLevel;
		}		
		
		public function setVolume(value:Number):void {
			if (this.muted) {
				this.volumeBeforeMute = value; 
			}
			else {
				player.volume = value;
			}
		}
		
		private function previousSeekpoint(time:Number):Number {
			var value:Number = seekpoints[0];
			
			for (var i:int = seekpoints.length; i>=0; i--) {
				if (time >= seekpoints[i]) {
					value = seekpoints[i];
					break;
				}
			}
			
			return value;
		}
		
		private function nextSeekpoint(time:Number):Number {
			var value:Number = seekpoints[seekpoints.length - 1];
			
			for (var i:int; i<seekpoints.length; i++) {
				if (time <= seekpoints[i]) {
					value = seekpoints[i];
					break;
				}
			}
			
			return value;
		}

		public function jumpBack(amt:Number):void {
			var seekTo:Number = player.playheadTime - amt;
			
			if (seekTo < 0) {
				seekTo = 0;
			}
			
			seekTo = previousSeekpoint(seekTo);
			if (player.playheadTime < seekTo) {
				return;
			}
			else if (state != VideoState.SEEKING && seekTo != player.playheadTime) {
				player.seek(seekTo);
			}
		}
		
		public function jumpForward(amt:Number):void {
			var seekTo:Number = player.playheadTime + amt;
			
			if (seekTo > player.totalTime) {
				seekTo = player.totalTime;
			}
			
			seekTo = nextSeekpoint(seekTo);
			if (player.playheadTime > seekTo) {
				return;
			}
			else if (state != VideoState.SEEKING && seekTo != player.playheadTime) {
				player.seek(seekTo);
			}
		}
		
		/*
		public function seek(time:Number):void {
			player.seek(time);
		}
		*/		

		private function roundToNearestDecimal(input:Number, decimalPlace:Number=10):Number {
			return Math.round(input * decimalPlace) / decimalPlace;
		}		

		private function minSecTime(time:Number):String {
			var minutes:Number = Math.floor(time / 60);
			var seconds:Number = time - (minutes * 60);
			
			return String(minutes) + ':' + String(roundToNearestDecimal(seconds, 1));
		}
		
		private function playheadUpdateHandler(event:VideoEvent):void {
			ExternalInterface.call('setTimeText', event.playheadTime, player.totalTime);
		}

		private function stateChangeHandler(event:VideoEvent):void {
			state = event.state;
		}		
		
		private function metadataRecievedHandler(event:MetadataEvent):void {
			for (var item:Object in event.info.seekpoints) {
				seekpoints.push(event.info.seekpoints[item]['time']);
			}
		}		
	}
}