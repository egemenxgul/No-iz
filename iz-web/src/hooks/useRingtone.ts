import { useRef, useCallback, useEffect } from 'react';

export function useRingtone() {
  const audioCtxRef = useRef<AudioContext | null>(null);
  const oscillatorRef = useRef<OscillatorNode | null>(null);
  const lfoRef = useRef<OscillatorNode | null>(null);
  const gainRef = useRef<GainNode | null>(null);

  const stopRingtone = useCallback(() => {
    try {
      if (oscillatorRef.current) {
        oscillatorRef.current.stop();
        oscillatorRef.current.disconnect();
      }
      if (lfoRef.current) {
        lfoRef.current.stop();
        lfoRef.current.disconnect();
      }
      if (gainRef.current) {
        gainRef.current.disconnect();
      }
      if (audioCtxRef.current && audioCtxRef.current.state !== 'closed') {
        audioCtxRef.current.close();
      }
    } catch (err) {
      // Ignore errors if already stopped
    } finally {
      oscillatorRef.current = null;
      lfoRef.current = null;
      gainRef.current = null;
      audioCtxRef.current = null;
    }
  }, []);

  const playRingtone = useCallback(() => {
    stopRingtone();

    try {
      const AudioContext = window.AudioContext || (window as any).webkitAudioContext;
      const ctx = new AudioContext();
      audioCtxRef.current = ctx;

      // Create main oscillator for the tone (European/UK style ringtone: 400Hz + 450Hz)
      // To keep it simple, we'll use a single frequency with a tremolo (LFO)
      const osc = ctx.createOscillator();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(440, ctx.currentTime); // 440 Hz
      oscillatorRef.current = osc;

      // Create an LFO to pulse the sound
      const lfo = ctx.createOscillator();
      lfo.type = 'square';
      lfo.frequency.setValueAtTime(10, ctx.currentTime); // 10 pulses per second
      lfoRef.current = lfo;

      // LFO Gain
      const lfoGain = ctx.createGain();
      lfoGain.gain.setValueAtTime(1, ctx.currentTime);
      lfo.connect(lfoGain.gain);

      // Main Gain (volume control and ringing pattern)
      const mainGain = ctx.createGain();
      // European ring: 0.4s on, 0.2s off, 0.4s on, 2.0s off
      // We will emulate a simple repeating pattern using Web Audio scheduling
      // But it's easier to use a setInterval for the pattern to loop it indefinitely
      mainGain.gain.value = 0;
      gainRef.current = mainGain;

      osc.connect(lfoGain);
      lfoGain.connect(mainGain);
      mainGain.connect(ctx.destination);

      osc.start();
      lfo.start();

      // Ringing sequence
      const ringPattern = () => {
        if (!audioCtxRef.current || audioCtxRef.current.state === 'closed') return;
        const now = ctx.currentTime;
        mainGain.gain.setValueAtTime(0, now);
        mainGain.gain.linearRampToValueAtTime(0.5, now + 0.05);
        mainGain.gain.setValueAtTime(0.5, now + 0.4);
        mainGain.gain.linearRampToValueAtTime(0, now + 0.45);
        
        mainGain.gain.setValueAtTime(0, now + 0.6);
        mainGain.gain.linearRampToValueAtTime(0.5, now + 0.65);
        mainGain.gain.setValueAtTime(0.5, now + 1.0);
        mainGain.gain.linearRampToValueAtTime(0, now + 1.05);
      };

      ringPattern();
      // Repeat every 3 seconds
      const intervalId = setInterval(ringPattern, 3000);

      // Clean up interval on close
      const originalStop = stopRingtone;
      return () => {
        clearInterval(intervalId);
        originalStop();
      };
    } catch (err) {
      console.warn('Could not play ringtone', err);
      return stopRingtone;
    }
  }, [stopRingtone]);

  // Clean up on unmount
  useEffect(() => {
    return () => {
      stopRingtone();
    };
  }, [stopRingtone]);

  return { playRingtone, stopRingtone };
}
