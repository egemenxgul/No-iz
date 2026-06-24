'use client';
import { useEffect, useState, useRef, MouseEvent as ReactMouseEvent } from 'react';
import { webrtcManager, CallState } from '@/lib/webrtc';
import { useI18n } from '@/lib/i18n/I18nContext';
import { useRingtone } from '@/hooks/useRingtone';
import styles from './CallOverlay.module.css';

export default function CallOverlay() {
  const { t } = useI18n();
  const { playRingtone, stopRingtone } = useRingtone();

  const [callState, setCallState] = useState<CallState>({ status: 'idle' });
  const [localStream, setLocalStream] = useState<MediaStream | null>(null);
  const [remoteStream, setRemoteStream] = useState<MediaStream | null>(null);
  const [isPip, setIsPip] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  // Dragging state for PiP
  const [position, setPosition] = useState({ x: window.innerWidth - 264, y: window.innerHeight - 344 });
  const [isDragging, setIsDragging] = useState(false);
  const dragOffset = useRef({ x: 0, y: 0 });

  const localVideoRef = useRef<HTMLVideoElement>(null);
  const remoteVideoRef = useRef<HTMLVideoElement>(null);

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
      }
    };
    webrtcManager.events.onLocalStream = (stream) => {
      setLocalStream(stream);
      if (localVideoRef.current) localVideoRef.current.srcObject = stream;
    };
    webrtcManager.events.onRemoteStream = (stream) => {
      setRemoteStream(stream);
      if (remoteVideoRef.current) remoteVideoRef.current.srcObject = stream;
    };
    webrtcManager.events.onError = (err) => {
      setErrorMsg(err);
      setTimeout(() => setErrorMsg(null), 5000);
    };

    return () => {
      webrtcManager.events = {};
    };
  }, []);

  // Update refs when streams change (React issue with media streams)
  useEffect(() => {
    if (localVideoRef.current && localStream) localVideoRef.current.srcObject = localStream;
    if (remoteVideoRef.current && remoteStream) remoteVideoRef.current.srcObject = remoteStream;
  }, [localStream, remoteStream]);

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
    
    // Bounds check
    const maxX = window.innerWidth - 240; // width
    const maxY = window.innerHeight - 320; // height
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

  // Handle window resize for PiP bounds
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

  if (callState.status === 'idle' && !errorMsg) return null;

  const overlayStyle = isPip ? { left: position.x, top: position.y, cursor: isDragging ? 'grabbing' : 'grab' } : {};

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
            {t('incomingCall') || 'Gelen Arama...'}<br/>
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
              <video ref={remoteVideoRef} autoPlay playsInline className={styles.remoteVideo} />
              <video ref={localVideoRef} autoPlay playsInline muted className={styles.localVideoPip} />
            </div>
          ) : (
            <div className={styles.audioContainer}>
              <div className={styles.pulseAvatar}>{callState.callerName?.[0]?.toUpperCase() || 'A'}</div>
              <div className={styles.callDuration}>
                {callState.status === 'connecting' ? (t('connecting') || 'Bağlanıyor...') : (t('callStarted') || 'Görüşme Başladı')}
              </div>
              <audio ref={remoteVideoRef} autoPlay />
              <audio ref={localVideoRef} autoPlay muted />
            </div>
          )}

          <div className={styles.controls}>
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
