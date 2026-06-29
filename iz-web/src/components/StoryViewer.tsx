import { useEffect, useState, useRef, useCallback } from 'react';
import { FriendStoryFeed } from '@/types';
import { api } from '@/lib/api';
import Image from 'next/image';
import styles from './StoryViewer.module.css';

interface StoryViewerProps {
  feed: FriendStoryFeed;
  onClose: () => void;
  onNextFeed?: () => void;
  onPrevFeed?: () => void;
}

export default function StoryViewer({ feed, onClose, onNextFeed, onPrevFeed }: StoryViewerProps) {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [progress, setProgress] = useState(0);
  const [isPaused, setIsPaused] = useState(false);
  const timerRef = useRef<NodeJS.Timeout | undefined>(undefined);

  const story = feed.stories[currentIndex];

  useEffect(() => {
    // Mark story as viewed
    if (story) {
      api.stories.view(story.id).catch((e) => {});
    }
  }, [story]);

  const handleNext = useCallback(() => {
    if (currentIndex < feed.stories.length - 1) {
      setCurrentIndex(i => i + 1);
    } else if (onNextFeed) {
      onNextFeed();
    } else {
      onClose();
    }
  }, [currentIndex, feed.stories.length, onNextFeed, onClose]);

  const handlePrev = () => {
    if (currentIndex > 0) {
      setCurrentIndex(i => i - 1);
    } else if (onPrevFeed) {
      onPrevFeed();
    } else {
      setProgress(0);
    }
  };

  useEffect(() => {
    if (isPaused) {
      clearInterval(timerRef.current);
      return;
    }

    const duration = 5000; // 5 seconds per story
    const step = 50;
    
    timerRef.current = setInterval(() => {
      setProgress(p => {
        if (p >= 100) {
          clearInterval(timerRef.current);
          handleNext();
          return 100;
        }
        return p + (step / duration) * 100;
      });
    }, step);

    return () => clearInterval(timerRef.current);
  }, [currentIndex, isPaused, feed.stories.length, handleNext]);

  useEffect(() => {
    setProgress(0);
  }, [currentIndex]);

  if (!story) return null;

  return (
    <div className={styles.overlay}>
      <div className={styles.viewer}>
        {/* Progress bars */}
        <div className={styles.progressContainer}>
          {feed.stories.map((s, idx) => (
            <div key={s.id} className={styles.progressBarBg}>
              <div 
                className={styles.progressBarFill} 
                style={{ 
                  width: idx < currentIndex ? '100%' : idx === currentIndex ? `${progress}%` : '0%' 
                }} 
              />
            </div>
          ))}
        </div>

        {/* Header */}
        <div className={styles.header}>
          <div className={styles.userInfo}>
            <div className={styles.avatar}>
              {feed.display_name?.[0]?.toUpperCase() || feed.username[0].toUpperCase()}
            </div>
            <div className={styles.meta}>
              <span className={styles.name}>{feed.display_name || feed.username}</span>
              <span className={styles.time}>{new Date(story.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
            </div>
          </div>
          <button className={styles.closeBtn} onClick={onClose}>✕</button>
        </div>

        {/* Media */}
        <div 
          className={styles.mediaContainer}
          onMouseDown={() => setIsPaused(true)}
          onMouseUp={() => setIsPaused(false)}
          onTouchStart={() => setIsPaused(true)}
          onTouchEnd={() => setIsPaused(false)}
        >
          {story.media_type === 'image' ? (
            <Image src={story.media_url} fill style={{objectFit: 'contain'}} className={styles.media} alt={story.caption || 'Story'} />
          ) : (
            <video src={story.media_url} className={styles.media} autoPlay playsInline loop={false} />
          )}

          {/* Navigation Tap Zones */}
          <div className={styles.tapPrev} onClick={handlePrev} />
          <div className={styles.tapNext} onClick={handleNext} />
        </div>

        {/* Caption */}
        {story.caption && (
          <div className={styles.captionContainer}>
            <p className={styles.caption}>{story.caption}</p>
          </div>
        )}
      </div>
    </div>
  );
}
