'use client';
import { useEffect, useState, useRef, MouseEvent as ReactMouseEvent } from 'react';
import { webrtcManager, CallState } from '@/lib/webrtc';
import { useI18n } from '@/lib/i18n/I18nContext';
import { useRingtone } from '@/hooks/useRingtone';
import styles from './CallOverlay.module.css';

function VideoTile({ stream, isLocal, muted, isPip }: { stream: MediaStream | null, isLocal: boolean, muted: boolean, isPip?: boolean }) {
  const videoRef = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    if (videoRef.current && stream) {
      videoRef.current.srcObject = stream;
    }
  }, [stream]);

  if (!stream) return null;

  return (
    <video 
      ref={videoRef} 
      autoPlay 
      playsInline 
      muted={muted} 
      className={isLocal ? (isPip ? styles.localVideoPip : styles.localVideoGrid) : styles.remoteVideoGrid} 
    />
  );
}

export default function CallOverlay() {
  const { t } = useI18n();
  const { playRingtone, stopRingtone } = useRingtone();

  const [callState, setCallState] = useState<CallState>({ status: 'idle', remoteStreams: new Map(), participants: [] });
  const [localStream, setLocalStream] = useState<MediaStream | null>(null);
  const [remoteStreamsMap, setRemoteStreamsMap] = useState<Map<string, MediaStream>>(new Map());
  const [isPip, setIsPip] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  
  // Track mute/video status locally
  const [isMuted, setIsMuted] = useState(false);
  const [isVideoOff, setIsVideoOff] = useState(false);

  // Dragging state for PiP
  const [position, setPosition] = useState({ x: typeof window !== 'undefined' ? window.innerWidth - 264 : 0, y: typeof window !== 'undefined' ? window.innerHeight - 344 : 0 });
  const [isDragging, setIsDragging] = useState(false);
  const dragOffset = useRef({ x: 0, y: 0 });

  useEffect(() => {
    webrtcManager.events.onStateChange = (state) => {
      setCallState(state);
      if (state.status === 'ringing') {
        playRingtone();
      } else {
        stopRingtone();
      }
      
      if (state.status === 'ended') {
        setIsPip(false);
        setIsMuted(false);
        setIsVideoOff(false);
      }
    };
    webrtcManager.events.onLocalStream = (stream) => {
      setLocalStream(stream);
    };
    webrtcManager.events.onRemoteStreamsChange = (streams) => {
      setRemoteStreamsMap(streams);
    };
    webrtcManager.events.onError = (err) => {
      setErrorMsg(err);
      setTimeout(() => setErrorMsg(null), 5000);
    };

    return () => {
      webrtcManager.events = {};
    };
  }, [playRingtone, stopRingtone]);

  // PiP Drag Handlers
  const handleMouseDown = (e: ReactMouseEvent) => {
    if (!isPip) return;
    setIsDragging(true);
    dragOffset.current = {
      x: e.clientX - position.x,
      y: e.clientY - position.y
    };
  };

  const handleMouseMove = (e: globalThis.MouseEvent) => {
    if (!isDragging || !isPip) return;
    
    let newX = e.clientX - dragOffset.current.x;
    let newY = e.clientY - dragOffset.current.y;
    
    const maxX = window.innerWidth - 240;
    const maxY = window.innerHeight - 320;
    if (newX < 0) newX = 0;
    if (newX > maxX) newX = maxX;
    if (newY < 0) newY = 0;
    if (newY > maxY) newY = maxY;
    
    setPosition({ x: newX, y: newY });
  };

  const handleMouseUp = () => {
    setIsDragging(false);
  };

  useEffect(() => {
    if (isDragging) {
      window.addEventListener('mousemove', handleMouseMove);
      window.addEventListener('mouseup', handleMouseUp);
    } else {
      window.removeEventListener('mousemove', handleMouseMove);
      window.removeEventListener('mouseup', handleMouseUp);
    }
    return () => {
      window.removeEventListener('mousemove', handleMouseMove);
      window.removeEventListener('mouseup', handleMouseUp);
    };
  }, [isDragging]);

  useEffect(() => {
    const handleResize = () => {
      if (isPip) {
        setPosition(prev => ({
          x: Math.min(prev.x, window.innerWidth - 240),
          y: Math.min(prev.y, window.innerHeight - 320)
        }));
      }
    };
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, [isPip]);

  const toggleMute = () => {
    setIsMuted(prev => {
      webrtcManager.toggleAudio(prev);
      return !prev;
    });
  };

  const toggleVideoOff = () => {
    setIsVideoOff(prev => {
      webrtcManager.toggleVideo(prev);
      return !prev;
    });
  };

  if (callState.status === 'idle' && !errorMsg) return null;

  const overlayStyle = isPip ? { left: position.x, top: position.y, cursor: isDragging ? 'grabbing' : 'grab' } : {};
  const remoteStreamsList = Array.from(remoteStreamsMap.values());
  const gridClass = remoteStreamsList.length > 2 ? styles.gridMany : (remoteStreamsList.length === 2 ? styles.gridTwo : styles.gridOne);

  return (
    <div 
      className={`${styles.overlay} ${isPip ? styles.pip : styles.full} ${isDragging ? styles.dragging : ''}`}
      style={overlayStyle}
      onMouseDown={handleMouseDown}
    >
      {errorMsg && <div className={styles.toast}>{errorMsg}</div>}

      {callState.status === 'ringing' && callState.isIncoming && !isPip && (
        <div className={styles.ringingBox}>
          <div className={styles.callerAvatar}>
            {callState.callerName?.[0]?.toUpperCase() || '?'}
          </div>
          <div className={styles.ringingText}>
            {callState.isGroupCall ? 'Gelen Grup Araması...' : (t('incomingCall') || 'Gelen Arama...')}<br/>
            <strong>{callState.callerName}</strong>
          </div>
          <div className={styles.ringingActions}>
            <button className={styles.btnAccept} onClick={() => webrtcManager.answerCall()}>
              {t('accept') || 'Cevapla'}
            </button>
            <button className={styles.btnReject} onClick={() => webrtcManager.rejectCall()}>
              {t('decline') || 'Reddet'}
            </button>
          </div>
        </div>
      )}

      {/* Main Call View */}
      {(callState.status === 'connecting' || callState.status === 'connected') && (
        <div className={styles.callBox}>
          {callState.isVideo ? (
            <div className={styles.videoContainer}>
              <div className={`${styles.videoGrid} ${gridClass}`}>
                {remoteStreamsList.length === 0 && (
                  <div className={styles.waitingContainer}>
                    <span>Diğer katılımcılar bekleniyor...</span>
                  </div>
                )}
                {remoteStreamsList.map((stream, idx) => (
                  <div key={idx} className={styles.videoCell}>
                    <VideoTile stream={stream} isLocal={false} muted={false} />
                  </div>
                ))}
              </div>
              
              {/* Local video usually in corner for 1-1, or as PIP corner if PIP mode */}
              <div className={isPip ? styles.localVideoPipWrap : styles.localVideoFloatingWrap}>
                 <VideoTile stream={localStream} isLocal={true} muted={true} isPip={isPip} />
              </div>
            </div>
          ) : (
            <div className={styles.audioContainer}>
              <div className={styles.pulseAvatar}>{callState.callerName?.[0]?.toUpperCase() || 'A'}</div>
              <div className={styles.callDuration}>
                {callState.status === 'connecting' ? (t('connecting') || 'Bağlanıyor...') : (t('callStarted') || 'Görüşme Başladı')}
                {callState.isGroupCall && ` (${remoteStreamsList.length + 1} Katılımcı)`}
              </div>
              {remoteStreamsList.map((stream, idx) => (
                <VideoTile key={idx} stream={stream} isLocal={false} muted={false} /> // Using VideoTile for audio streams implicitly
              ))}
            </div>
          )}

          <div className={styles.controls}>
            <button className={`${styles.btnControl} ${isMuted ? styles.controlOff : ''}`} onClick={toggleMute} title="Mikrofonu Kapat/Aç">
              {isMuted ? '🔇' : '🎤'}
            </button>
            {callState.isVideo && (
              <button className={`${styles.btnControl} ${isVideoOff ? styles.controlOff : ''}`} onClick={toggleVideoOff} title="Kamerayı Kapat/Aç">
                {isVideoOff ? '📹 ❌' : '📹'}
              </button>
            )}
            <button className={styles.btnControl} onClick={() => setIsPip(!isPip)} title={isPip ? 'Büyüt' : 'Küçült'}>
              {isPip ? '⤢' : '⤡'}
            </button>
            <button className={styles.btnReject} onClick={() => webrtcManager.endCall()} title={t('endCall') || 'Aramayı Sonlandır'}>
              ✕
            </button>
          </div>
        </div>
      )}

      {callState.status === 'ended' && !isPip && (
        <div className={styles.ringingBox}>
          <div className={styles.ringingText}>{t('callEnded') || 'Görüşme Sonlandı'}</div>
        </div>
      )}
    </div>
  );
}
