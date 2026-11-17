-- ==============================================================================
-- SQL Policy untuk Bucket Supabase Storage: 'kosfinder-demo'
-- Worksheet 10: Advanced Mobile Features & Device Integration (Praktik 5)
-- ==============================================================================

-- 1. Buat bucket 'kosfinder-demo' jika belum tersedia (dapat diset public: true)
INSERT INTO storage.buckets (id, name, public)
VALUES ('kosfinder-demo', 'kosfinder-demo', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Pastikan Row Level Security (RLS) aktif pada storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 3. Kebijakan INSERT:
-- Mengizinkan role 'authenticated' (termasuk anonymous sign-in) mengunggah file
-- HANYA jika prefix folder path pertama cocok dengan UID pengguna yang sedang login.
DROP POLICY IF EXISTS "Allow authenticated upload to own folder" ON storage.objects;
CREATE POLICY "Allow authenticated upload to own folder"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'kosfinder-demo'
  AND (storage.foldername(name))[1] = (select auth.uid()::text)
);

-- 4. Kebijakan SELECT:
-- Mengizinkan akses publik untuk membaca/mengunduh foto dari bucket 'kosfinder-demo'
DROP POLICY IF EXISTS "Allow public read access to kosfinder-demo" ON storage.objects;
CREATE POLICY "Allow public read access to kosfinder-demo"
ON storage.objects
FOR SELECT
TO public
USING (
  bucket_id = 'kosfinder-demo'
);

