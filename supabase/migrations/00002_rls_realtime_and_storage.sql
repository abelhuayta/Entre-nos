-- ============================================================================
-- ENTRE NOS - FASE 4 (PARTE 2): POLÍTICAS RLS, CÁPSULAS SEGURAS,
-- SUPABASE REALTIME Y STORAGE PRIVADO
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. ACTIVACIÓN OBLIGATORIA DE ROW LEVEL SECURITY (ZERO-TRUST)
-- ----------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.circle ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.story_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.capsules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_reports ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 2. POLÍTICAS RLS POR TABLA
-- ----------------------------------------------------------------------------

-- PROFILES: solo el dueño o miembros aprobados del círculo pueden leer; solo el dueño edita
CREATE POLICY "profiles_select_self_or_member" ON public.profiles
  FOR SELECT TO authenticated
  USING (id = auth.uid() OR public.is_approved_member(auth.uid()));

CREATE POLICY "profiles_update_self" ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- CIRCLE: solo miembros aprobados leen metadatos del círculo
CREATE POLICY "circle_select_member" ON public.circle
  FOR SELECT TO authenticated
  USING (public.is_approved_member(auth.uid()));

-- MEMBERSHIPS: usuario lee su propio estado; miembros aprobados ven la lista del grupo; admin gestiona
CREATE POLICY "memberships_select" ON public.memberships
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_approved_member(auth.uid()));

CREATE POLICY "memberships_admin_update" ON public.memberships
  FOR UPDATE TO authenticated
  USING (public.is_circle_admin(auth.uid()));

-- INVITATIONS: únicamente el administrador puede ver, crear y revocar invitaciones
CREATE POLICY "invitations_admin_all" ON public.invitations
  FOR ALL TO authenticated
  USING (public.is_circle_admin(auth.uid()))
  WITH CHECK (public.is_circle_admin(auth.uid()));

-- POSTS: solo miembros aprobados leen y publican; solo autor o admin eliminan
CREATE POLICY "posts_select_member" ON public.posts
  FOR SELECT TO authenticated
  USING (public.is_approved_member(auth.uid()));

CREATE POLICY "posts_insert_member" ON public.posts
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_approved_member(auth.uid())
    AND author_id = auth.uid()
  );

CREATE POLICY "posts_update_author" ON public.posts
  FOR UPDATE TO authenticated
  USING (author_id = auth.uid() AND public.is_approved_member(auth.uid()))
  WITH CHECK (author_id = auth.uid());

CREATE POLICY "posts_delete_author_or_admin" ON public.posts
  FOR DELETE TO authenticated
  USING (
    public.is_approved_member(auth.uid())
    AND (author_id = auth.uid() OR public.is_circle_admin(auth.uid()))
  );

-- POST_MEDIA
CREATE POLICY "post_media_select_member" ON public.post_media
  FOR SELECT TO authenticated
  USING (public.is_approved_member(auth.uid()));

CREATE POLICY "post_media_insert_author" ON public.post_media
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_approved_member(auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.posts p
      WHERE p.id = post_id AND p.author_id = auth.uid()
    )
  );

-- COMMENTS
CREATE POLICY "comments_select_member" ON public.comments
  FOR SELECT TO authenticated
  USING (public.is_approved_member(auth.uid()));

CREATE POLICY "comments_insert_member" ON public.comments
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_approved_member(auth.uid())
    AND author_id = auth.uid()
  );

CREATE POLICY "comments_delete_author_or_admin" ON public.comments
  FOR DELETE TO authenticated
  USING (
    public.is_approved_member(auth.uid())
    AND (author_id = auth.uid() OR public.is_circle_admin(auth.uid()))
  );

-- REACTIONS
CREATE POLICY "reactions_select_member" ON public.reactions
  FOR SELECT TO authenticated
  USING (public.is_approved_member(auth.uid()));

CREATE POLICY "reactions_manage_self" ON public.reactions
  FOR ALL TO authenticated
  USING (public.is_approved_member(auth.uid()) AND user_id = auth.uid())
  WITH CHECK (public.is_approved_member(auth.uid()) AND user_id = auth.uid());

-- SAVED_POSTS (privado por integrante)
CREATE POLICY "saved_posts_self" ON public.saved_posts
  FOR ALL TO authenticated
  USING (public.is_approved_member(auth.uid()) AND user_id = auth.uid())
  WITH CHECK (public.is_approved_member(auth.uid()) AND user_id = auth.uid());

-- STORIES (visibles para el grupo durante 24h; archivadas solo visibles para su autor)
CREATE POLICY "stories_select_active_or_owner" ON public.stories
  FOR SELECT TO authenticated
  USING (
    public.is_approved_member(auth.uid())
    AND (expires_at > now() OR author_id = auth.uid())
  );

CREATE POLICY "stories_insert_member" ON public.stories
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_approved_member(auth.uid())
    AND author_id = auth.uid()
  );

CREATE POLICY "stories_delete_author" ON public.stories
  FOR DELETE TO authenticated
  USING (author_id = auth.uid());

-- STORY_VIEWS
CREATE POLICY "story_views_select" ON public.story_views
  FOR SELECT TO authenticated
  USING (
    public.is_approved_member(auth.uid())
    AND (
      viewer_id = auth.uid()
      OR EXISTS (SELECT 1 FROM public.stories s WHERE s.id = story_id AND s.author_id = auth.uid())
    )
  );

CREATE POLICY "story_views_insert_member" ON public.story_views
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_approved_member(auth.uid())
    AND viewer_id = auth.uid()
  );

-- CONVERSATIONS & CONVERSATION_MEMBERS (aislamiento estricto de chats privados)
CREATE POLICY "conversations_select_participant" ON public.conversations
  FOR SELECT TO authenticated
  USING (
    public.is_approved_member(auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.conversation_members cm
      WHERE cm.conversation_id = id AND cm.user_id = auth.uid()
    )
  );

CREATE POLICY "conv_members_select_participant" ON public.conversation_members
  FOR SELECT TO authenticated
  USING (
    public.is_approved_member(auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.conversation_members cm
      WHERE cm.conversation_id = conversation_id AND cm.user_id = auth.uid()
    )
  );

CREATE POLICY "conv_members_update_self_read" ON public.conversation_members
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid() AND public.is_approved_member(auth.uid()))
  WITH CHECK (user_id = auth.uid());

-- MESSAGES
CREATE POLICY "messages_select_participant" ON public.messages
  FOR SELECT TO authenticated
  USING (
    public.is_approved_member(auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.conversation_members cm
      WHERE cm.conversation_id = conversation_id AND cm.user_id = auth.uid()
    )
  );

CREATE POLICY "messages_insert_participant" ON public.messages
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_approved_member(auth.uid())
    AND sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.conversation_members cm
      WHERE cm.conversation_id = conversation_id AND cm.user_id = auth.uid()
    )
  );

-- POLLS, OPTIONS & VOTES
CREATE POLICY "polls_select_member" ON public.polls
  FOR SELECT TO authenticated
  USING (public.is_approved_member(auth.uid()));

CREATE POLICY "polls_insert_author" ON public.polls
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_approved_member(auth.uid())
    AND EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post_id AND p.author_id = auth.uid())
  );

CREATE POLICY "poll_options_select_member" ON public.poll_options
  FOR SELECT TO authenticated
  USING (public.is_approved_member(auth.uid()));

CREATE POLICY "poll_options_insert_author" ON public.poll_options
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_approved_member(auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.polls pl
      JOIN public.posts p ON p.id = pl.post_id
      WHERE pl.id = poll_id AND p.author_id = auth.uid()
    )
  );

CREATE POLICY "poll_votes_select_member" ON public.poll_votes
  FOR SELECT TO authenticated
  USING (public.is_approved_member(auth.uid()));

-- CAPSULES: bloqueo estricto en servidor antes de unlock_at
CREATE POLICY "capsules_select_unlocked_only" ON public.capsules
  FOR SELECT TO authenticated
  USING (
    public.is_approved_member(auth.uid())
    AND (
      (creator_id = auth.uid() AND visibility = 'private')
      OR (
        now() >= unlock_at
        AND (
          visibility = 'circle'
          OR creator_id = auth.uid()
          OR (visibility = 'selected' AND auth.uid() = ANY(allowed_users))
        )
      )
    )
  );

CREATE POLICY "capsules_insert_member" ON public.capsules
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_approved_member(auth.uid())
    AND creator_id = auth.uid()
  );

-- Vista segura para mostrar el listado y cuenta regresiva de cápsulas selladas
-- sin exponer jamás el mensaje ni la ruta multimedia antes de unlock_at
CREATE OR REPLACE VIEW public.capsules_locked_feed
WITH (security_invoker = false)
AS
SELECT
  c.id,
  c.circle_id,
  c.creator_id,
  c.title,
  c.visibility,
  c.unlock_at,
  c.created_at,
  (now() >= c.unlock_at) AS is_unlocked
FROM public.capsules c
WHERE public.is_approved_member(auth.uid())
  AND (
    c.visibility = 'circle'
    OR c.creator_id = auth.uid()
    OR (c.visibility = 'selected' AND auth.uid() = ANY(c.allowed_users))
  );

GRANT SELECT ON public.capsules_locked_feed TO authenticated;

-- NOTIFICATIONS
CREATE POLICY "notifications_self" ON public.notifications
  FOR ALL TO authenticated
  USING (recipient_id = auth.uid())
  WITH CHECK (recipient_id = auth.uid());

-- USER_DEVICES
CREATE POLICY "user_devices_self" ON public.user_devices
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- CONTENT_REPORTS
CREATE POLICY "reports_insert_member" ON public.content_reports
  FOR INSERT TO authenticated
  WITH CHECK (public.is_approved_member(auth.uid()) AND reporter_id = auth.uid());

CREATE POLICY "reports_select_admin" ON public.content_reports
  FOR SELECT TO authenticated
  USING (public.is_circle_admin(auth.uid()));

-- ----------------------------------------------------------------------------
-- 3. SUPABASE REALTIME (PUBLICACIÓN EN TIEMPO REAL)
-- ----------------------------------------------------------------------------
DO $$
DECLARE
  v_table TEXT;
  v_tables TEXT[] := ARRAY[
    'memberships',
    'posts',
    'comments',
    'reactions',
    'stories',
    'conversations',
    'messages',
    'poll_votes',
    'notifications'
  ];
BEGIN
  FOREACH v_table IN ARRAY v_tables LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = v_table
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', v_table);
    END IF;
  END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- 4. BUCKETS 100% PRIVADOS EN SUPABASE STORAGE
-- ----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES
  ('avatars', 'avatars', false, 5242880),          -- 5 MB
  ('posts_media', 'posts_media', false, 52428800),  -- 50 MB
  ('stories_media', 'stories_media', false, 31457280), -- 30 MB
  ('chat_media', 'chat_media', false, 26214400),    -- 25 MB
  ('capsules_media', 'capsules_media', false, 52428800) -- 50 MB
ON CONFLICT (id) DO UPDATE SET public = false;

-- Lectura de archivos privados: exclusivamente miembros aprobados del círculo
CREATE POLICY "storage_select_approved_members" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id IN ('avatars', 'posts_media', 'stories_media', 'chat_media', 'capsules_media')
    AND public.is_approved_member(auth.uid())
  );

-- Subida de archivos: solo miembros aprobados dentro de su carpeta <user_id>/...
CREATE POLICY "storage_insert_own_folder" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id IN ('avatars', 'posts_media', 'stories_media', 'chat_media', 'capsules_media')
    AND public.is_approved_member(auth.uid())
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Eliminación de archivos propios
CREATE POLICY "storage_delete_own_folder" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id IN ('avatars', 'posts_media', 'stories_media', 'chat_media', 'capsules_media')
    AND (storage.foldername(name))[1] = auth.uid()::text
  );