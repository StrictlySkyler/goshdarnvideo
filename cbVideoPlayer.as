package
{
    import fl.video.*;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.external.*;
	import flash.utils.Timer;
	import flash.events.TimerEvent;
    import flash.display.Stage;
    import flash.display.StageAlign;
    import flash.display.StageScaleMode;
	
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
        private var wasPlaying:Boolean;
		
		public function CBVideoPlayer() {
			_forceNCManager:fl.video.NCManager;
			stage.scaleMode = StageScaleMode.NO_SCALE;
            stage.align = StageAlign.TOP_LEFT;
            player = new VideoPlayer();
            player.playheadUpdateInterval = 1000;
			player.load(videoPath);
			player.setSize(640, 360); // this should probably come from html tag attributes
			player.x = 0;
			player.y = 0;
            player.autoRewind = true;
			player.addEventListener(VideoEvent.COMPLETE, playerReadyHandler);
            player.addEventListener(VideoEvent.PLAYHEAD_UPDATE, playheadUpdateHandler);
			player.addEventListener(VideoEvent.STATE_CHANGE, stateChangeHandler);
            player.addEventListener(VideoEvent.COMPLETE, playingCompleteHandler);
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
                ExternalInterface.addCallback("isStopped", isStopped);
                ExternalInterface.addCallback("setStopped", setStopped);
				ExternalInterface.addCallback("getVolume", getVolume);
				ExternalInterface.addCallback("setVolume", setVolume);				
				ExternalInterface.addCallback("jumpBack", jumpBack);				
				ExternalInterface.addCallback("jumpForward", jumpForward);
				ExternalInterface.addCallback("rewindStart", rewindStart);				
				ExternalInterface.addCallback("forwardStart", forwardStart);				
				ExternalInterface.addCallback("rewindStop", rewindStop);				
				ExternalInterface.addCallback("forwardStop", forwardStop);								
				ExternalInterface.addCallback("progressBarTo", progressBarTo);
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
			wasPlaying = player.state == VideoState.PLAYING;
            player.pause();
            rewindTimer.start();
		}
		
		public function rewindStop():void {
			rewindTimer.stop();
            if (wasPlaying) {
                player.play();
            }
		}
		
		public function forwardStart():void {
			wasPlaying = player.state == VideoState.PLAYING;
            player.pause();
            forwardTimer.start();
		}
		
		public function forwardStop():void {
			forwardTimer.stop();
            if (wasPlaying) {
                player.play();
            }
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
		}

		public function isStopped():Boolean {
            return player.state == VideoState.STOPPED;
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
		
		public function progressBarTo(time:Number):void {
			if (state == VideoState.SEEKING) {
                return;
            }

            if (time >= player.totalTime) {
				//hackaroo: subtracting the .1 because for some reason when a seek is called with
                //a time exactly or near equaling the total time - it seems to be ignored.
                time = player.totalTime - .1;
			}
            else if (time < 0) {
                time = 0;
            }

            //ExternalInterface.call('console.log(\'--' + time + '\')');
            //ExternalInterface.call('console.log(\'-' + player.playheadTime + '\')');
            //ExternalInterface.call('console.log(\'tot-' + player.totalTime + '\')');
            //ExternalInterface.call('console.log(\'pprevInd: ' + seekpoints.indexOf(previousSeekpoint(player.playheadTime)) + '\')');
            //ExternalInterface.call('console.log(\'nextInd: ' + seekpoints.indexOf(nextSeekpoint(time)) + '\')');

            player.seek(time);

            // If the time will not trigger a playhead update, manually make the call to the js function
            if (seekpoints.indexOf(nextSeekpoint(time)) - seekpoints.indexOf(previousSeekpoint(player.playheadTime)) <= 1)
            {
                ExternalInterface.call('goshDarnVideo.setProgressBar', player.playheadTime, player.totalTime);
            }
		}

		private function roundToNearestDecimal(input:Number, decimalPlace:Number=10):Number {
			return Math.round(input * decimalPlace) / decimalPlace;
		}		

		private function minSecTime(time:Number):String {
			var minutes:Number = Math.floor(time / 60);
			var seconds:Number = time - (minutes * 60);
			
			return String(minutes) + ':' + String(roundToNearestDecimal(seconds, 1));
		}
		
        private function playheadUpdateHandler(event:VideoEvent):void {
            ExternalInterface.call('goshDarnVideo.setTimeText', event.playheadTime, player.totalTime);
            ExternalInterface.call('goshDarnVideo.setProgressBar', event.playheadTime, player.totalTime);
		}

        private function playingCompleteHandler(event:VideoEvent):void {
            ExternalInterface.call('goshDarnVideo.setTimeText', player.totalTime, player.totalTime);
            ExternalInterface.call('goshDarnVideo.setProgressBar', player.totalTime, player.totalTime);
		}

		private function stateChangeHandler(event:VideoEvent):void {
			state = event.state;
		}		
		
		private function metadataRecievedHandler(event:MetadataEvent):void {
			for (var item:Object in event.info.seekpoints) {
				seekpoints.push(event.info.seekpoints[item]['time']);
                //var poo:String = event.info.seekpoints[item]['time'];
                //ExternalInterface.call('console.log(' + poo + ')');
			}
		}

        private function playerReadyHandler(event:VideoEvent):void {
            // Let js know that the player is ready
            ExternalInterface.call('goshDarnVideo.flashVideoPlayerReady()');
        }
	}
}