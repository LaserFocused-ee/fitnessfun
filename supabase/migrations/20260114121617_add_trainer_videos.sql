-- Add trainer_videos table for video library feature
-- Trainers can upload and manage their own videos

-- ============================================
-- TRAINER VIDEOS
-- ============================================
CREATE TABLE public.trainer_videos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trainer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  storage_path TEXT NOT NULL,
  file_size_bytes BIGINT,
  is_public BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for trainer lookups
CREATE INDEX idx_trainer_videos_trainer ON public.trainer_videos(trainer_id);

-- Enable RLS
ALTER TABLE public.trainer_videos ENABLE ROW LEVEL SECURITY;

-- Trainers can view their own videos (+ public videos in future)
CREATE POLICY "Trainers view own videos"
ON public.trainer_videos FOR SELECT
TO authenticated
USING (trainer_id = auth.uid() OR is_public = true);

-- Trainers can insert their own videos (role check)
CREATE POLICY "Trainers insert videos"
ON public.trainer_videos FOR INSERT
TO authenticated
WITH CHECK (
  trainer_id = auth.uid()
  AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'trainer')
);

-- Trainers can update their own videos
CREATE POLICY "Trainers update own videos"
ON public.trainer_videos FOR UPDATE
TO authenticated
USING (trainer_id = auth.uid());

-- Trainers can delete their own videos
CREATE POLICY "Trainers delete own videos"
ON public.trainer_videos FOR DELETE
TO authenticated
USING (trainer_id = auth.uid());

-- Update timestamp trigger
CREATE TRIGGER update_trainer_videos_updated_at
  BEFORE UPDATE ON public.trainer_videos
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
