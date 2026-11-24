-- ============================================================================
-- ENTRE NOS - FASE 4 (PARTE 1): ESQUEMA RELACIONAL, TRIGGERS Y FUNCIONES RPC
-- PostgreSQL 15+ / Supabase
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ----------------------------------------------------------------------------
-- 1. TIPOS ENUMERADOS (DOMINIO ESTRICTO)
-- ----------------------------------------------------------------------------
DO $$ BEGIN
  CREATE TYPE public.member_role AS ENUM ('admin', 'member');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.member_status AS ENUM ('pending', 'approved', 'rejected', 'blocked', 'removed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.post_kind AS ENUM ('text', 'media', 'poll', 'shared');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.media_kind AS ENUM ('image', 'video');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.story_kind AS ENUM ('text', 'image', 'video');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.chat_kind AS ENUM ('group', 'direct');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.msg_kind AS ENUM ('text', 'image', 'audio');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.msg_status AS ENUM ('sent', 'delivered', 'read');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.capsule_scope AS ENUM ('circle', 'private', 'selected');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.notif_kind AS ENUM (
    'new_post',
    'new_comment',
    'new_reaction',
    'new_message',
    'new_poll',
    'capsule_unlocked',
    'join_request',
    'membership_approved'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ----------------------------------------------------------------------------
-- 2. TABLAS PRINCIPALES (3FN)
-- ----------------------------------------------------------------------------

-- Perfiles de usuario vinculados 1:1 con auth.users
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  full_name TEXT NOT NULL CHECK (char_length(trim(full_name)) >= 2),
  nickname VARCHAR(30) NOT NULL CHECK (char_length(trim(nickname)) >= 2),
  bio TEXT DEFAULT '',
  avatar_path TEXT,
  avatar_config JSONB NOT NULL DEFAULT '{"bg":"#171717","accent":"#F5F5F5"}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_nickname_lower
  ON public.profiles (lower(nickname));

-- Círculo privado único (ENTRE NOS)
CREATE TABLE IF NOT EXISTS public.circle (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL DEFAULT 'ENTRE NOS',
  slogan TEXT NOT NULL DEFAULT 'Lo que pasa entre nosotros',
  max_members INT NOT NULL DEFAULT 30 CHECK (max_members > 0 AND max_members <= 30),
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Membresías y roles dentro del círculo
CREATE TABLE IF NOT EXISTS public.memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  circle_id UUID NOT NULL REFERENCES public.circle(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role public.member_role NOT NULL DEFAULT 'member',
  status public.member_status NOT NULL DEFAULT 'pending',
  invited_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  joined_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_circle_user UNIQUE (circle_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_memberships_user_status
  ON public.memberships (user_id, status);

-- Códigos de invitación generados por el administrador
CREATE TABLE IF NOT EXISTS public.invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  circle_id UUID NOT NULL REFERENCES public.circle(id) ON DELETE CASCADE,
  code VARCHAR(16) NOT NULL,
  created_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  max_uses INT NOT NULL DEFAULT 1 CHECK (max_uses > 0 AND max_uses <= 30),
  uses_count INT NOT NULL DEFAULT 0 CHECK (uses_count >= 0 AND uses_count <= max_uses),
  auto_approve BOOLEAN NOT NULL DEFAULT false,
  expires_at TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_invitations_code_upper
  ON public.invitations (upper(code));

-- Publicaciones del feed cronológico
CREATE TABLE IF NOT EXISTS public.posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  circle_id UUID NOT NULL REFERENCES public.circle(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content TEXT DEFAULT '',
  post_type public.post_kind NOT NULL DEFAULT 'text',
  shared_post_id UUID REFERENCES public.posts(id) ON DELETE SET NULL,
  is_memory BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_posts_circle_created
  ON public.posts (circle_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_memories
  ON public.posts (circle_id, is_memory, created_at DESC)
  WHERE is_memory = true;

-- Archivos multimedia asociados a publicaciones
CREATE TABLE IF NOT EXISTS public.post_media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  storage_path TEXT NOT NULL,
  media_type public.media_kind NOT NULL,
  aspect_ratio REAL DEFAULT 0.8,
  duration_sec INT,
  thumbnail_path TEXT,
  order_index INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_post_media_post_order
  ON public.post_media (post_id, order_index ASC);

-- Comentarios en publicaciones
CREATE TABLE IF NOT EXISTS public.comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES public.comments(id) ON DELETE CASCADE,
  content TEXT NOT NULL CHECK (char_length(trim(content)) >= 1),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_comments_post_created
  ON public.comments (post_id, created_at ASC);

-- Reacciones por publicación (1 reacción activa por usuario y post)
CREATE TABLE IF NOT EXISTS public.reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  emoji VARCHAR(16) NOT NULL DEFAULT '❤️',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_post_user_reaction UNIQUE (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_reactions_post
  ON public.reactions (post_id);

-- Publicaciones guardadas en favoritos personales
CREATE TABLE IF NOT EXISTS public.saved_posts (
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, post_id)
);

-- Momentos (historias temporales de 24 horas + archivo personal)
CREATE TABLE IF NOT EXISTS public.stories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  circle_id UUID NOT NULL REFERENCES public.circle(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  media_type public.story_kind NOT NULL DEFAULT 'image',
  storage_path TEXT,
  text_content TEXT,
  bg_hex VARCHAR(9) DEFAULT '#171717',
  is_archived BOOLEAN NOT NULL DEFAULT true,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '24 hours'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_stories_active
  ON public.stories (expires_at DESC, author_id);

-- Registro de visualización de Momentos
CREATE TABLE IF NOT EXISTS public.story_views (
  story_id UUID NOT NULL REFERENCES public.stories(id) ON DELETE CASCADE,
  viewer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  viewed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (story_id, viewer_id)
);

-- Conversaciones (grupal principal y chats privados 1:1)
CREATE TABLE IF NOT EXISTS public.conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  circle_id UUID NOT NULL REFERENCES public.circle(id) ON DELETE CASCADE,
  type public.chat_kind NOT NULL DEFAULT 'direct',
  title TEXT,
  last_message_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_conversations_last_msg
  ON public.conversations (last_message_at DESC);

-- Participantes autorizados por conversación
CREATE TABLE IF NOT EXISTS public.conversation_members (
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  last_read_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (conversation_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_conv_members_user
  ON public.conversation_members (user_id);

-- Mensajes persistentes en tiempo real
CREATE TABLE IF NOT EXISTS public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  message_type public.msg_kind NOT NULL DEFAULT 'text',
  content TEXT DEFAULT '',
  media_path TEXT,
  audio_duration_ms INT,
  status public.msg_status NOT NULL DEFAULT 'sent',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_messages_conv_created
  ON public.messages (conversation_id, created_at DESC);

-- Encuestas del grupo
CREATE TABLE IF NOT EXISTS public.polls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL UNIQUE REFERENCES public.posts(id) ON DELETE CASCADE,
  question TEXT NOT NULL CHECK (char_length(trim(question)) >= 3),
  allows_multiple BOOLEAN NOT NULL DEFAULT false,
  ends_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.poll_options (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id UUID NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
  option_text TEXT NOT NULL CHECK (char_length(trim(option_text)) >= 1),
  order_index INT NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_poll_options_poll
  ON public.poll_options (poll_id, order_index ASC);

CREATE TABLE IF NOT EXISTS public.poll_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id UUID NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
  option_id UUID NOT NULL REFERENCES public.poll_options(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_poll_option_user UNIQUE (option_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_poll_votes_poll
  ON public.poll_votes (poll_id);

-- Cápsulas del tiempo con bloqueo temporal estricto
CREATE TABLE IF NOT EXISTS public.capsules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  circle_id UUID NOT NULL REFERENCES public.circle(id) ON DELETE CASCADE,
  creator_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL CHECK (char_length(trim(title)) >= 2),
  message TEXT DEFAULT '',
  media_path TEXT,
  media_type public.media_kind,
  visibility public.capsule_scope NOT NULL DEFAULT 'circle',
  allowed_users UUID[] NOT NULL DEFAULT '{}',
  unlock_at TIMESTAMPTZ NOT NULL,
  notified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_capsule_future_unlock CHECK (unlock_at > created_at)
);

CREATE INDEX IF NOT EXISTS idx_capsules_unlock
  ON public.capsules (unlock_at ASC);

-- Notificaciones internas del círculo
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  type public.notif_kind NOT NULL,
  reference_id UUID,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_recipient
  ON public.notifications (recipient_id, is_read, created_at DESC);

-- Dispositivos registrados para FCM (Android) / APNs (iOS)
CREATE TABLE IF NOT EXISTS public.user_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL UNIQUE,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Reportes internos de contenido
CREATE TABLE IF NOT EXISTS public.content_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  reporter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason TEXT NOT NULL CHECK (char_length(trim(reason)) >= 3),
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'reviewed', 'dismissed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_report_post_user UNIQUE (post_id, reporter_id)
);

-- ----------------------------------------------------------------------------
-- 3. DATOS INICIALES SINGLETON DEL CÍRCULO Y CHAT GRUPAL
-- ----------------------------------------------------------------------------
INSERT INTO public.circle (id, name, slogan, max_members)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'ENTRE NOS',
  'Lo que pasa entre nosotros',
  30
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.conversations (id, circle_id, type, title)
VALUES (
  '00000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000001',
  'group',
  'ENTRE NOS · El Círculo'
)
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 4. FUNCIONES DE SEGURIDAD (ANTI-RECURSIÓN RLS)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_approved_member(p_uid UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.memberships m
    WHERE m.circle_id = '00000000-0000-0000-0000-000000000001'
      AND m.user_id = p_uid
      AND m.status = 'approved'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_circle_admin(p_uid UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.memberships m
    WHERE m.circle_id = '00000000-0000-0000-0000-000000000001'
      AND m.user_id = p_uid
      AND m.role = 'admin'
      AND m.status = 'approved'
  );
$$;

-- ----------------------------------------------------------------------------
-- 5. TRIGGERS DE INTEGRIDAD Y AUTOMATIZACIÓN
-- ----------------------------------------------------------------------------

-- Crea perfil automáticamente al registrarse en Supabase Auth
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_full_name TEXT;
  v_base_nick TEXT;
  v_final_nick TEXT;
BEGIN
  v_full_name := COALESCE(
    NULLIF(trim(NEW.raw_user_meta_data->>'full_name'), ''),
    split_part(COALESCE(NEW.email, 'integrante'), '@', 1)
  );

  v_base_nick := regexp_replace(
    lower(COALESCE(
      NULLIF(trim(NEW.raw_user_meta_data->>'nickname'), ''),
      split_part(COALESCE(NEW.email, 'user'), '@', 1)
    )),
    '[^a-z0-9_]',
    '',
    'g'
  );

  IF char_length(v_base_nick) < 2 THEN
    v_base_nick := 'amigo';
  END IF;

  v_final_nick := left(v_base_nick, 24);
  IF EXISTS (SELECT 1 FROM public.profiles WHERE lower(nickname) = lower(v_final_nick)) THEN
    v_final_nick := left(v_base_nick, 19) || '_' || substr(replace(NEW.id::text, '-', ''), 1, 4);
  END IF;

  INSERT INTO public.profiles (id, email, full_name, nickname)
  VALUES (NEW.id, COALESCE(NEW.email, ''), v_full_name, v_final_nick)
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

-- Garantiza el límite estricto de 30 integrantes aprobados
CREATE OR REPLACE FUNCTION public.enforce_circle_member_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_count INT;
  v_max_members INT;
BEGIN
  IF NEW.status = 'approved' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'approved') THEN
    SELECT max_members INTO v_max_members
    FROM public.circle
    WHERE id = NEW.circle_id;

    SELECT COUNT(*) INTO v_current_count
    FROM public.memberships
    WHERE circle_id = NEW.circle_id
      AND status = 'approved'
      AND user_id <> NEW.user_id;

    IF v_current_count >= COALESCE(v_max_members, 30) THEN
      RAISE EXCEPTION 'circle_full: El círculo privado ya alcanzó el límite de % integrantes.', COALESCE(v_max_members, 30);
    END IF;
  END IF;

  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_member_limit ON public.memberships;
CREATE TRIGGER trg_enforce_member_limit
  BEFORE INSERT OR UPDATE ON public.memberships
  FOR EACH ROW EXECUTE FUNCTION public.enforce_circle_member_limit();

-- Actualiza last_message_at en conversaciones cuando llega un mensaje nuevo
CREATE OR REPLACE FUNCTION public.update_conversation_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.conversations
  SET last_message_at = NEW.created_at
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_message_updates_conversation ON public.messages;
CREATE TRIGGER trg_message_updates_conversation
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.update_conversation_timestamp();

-- ----------------------------------------------------------------------------
-- 6. FUNCIONES RPC TRANSACCIONALES
-- ----------------------------------------------------------------------------

-- Reclama el rol de Administrador Inicial (solo funciona una única vez si aún no hay admin)
CREATE OR REPLACE FUNCTION public.claim_initial_admin()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_circle_id UUID := '00000000-0000-0000-0000-000000000001';
  v_group_chat UUID := '00000000-0000-0000-0000-000000000002';
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF EXISTS (SELECT 1 FROM public.memberships WHERE circle_id = v_circle_id AND role = 'admin' AND status = 'approved') THEN
    RAISE EXCEPTION 'admin_already_exists';
  END IF;

  INSERT INTO public.memberships (circle_id, user_id, role, status, joined_at)
  VALUES (v_circle_id, v_uid, 'admin', 'approved', now())
  ON CONFLICT (circle_id, user_id)
  DO UPDATE SET role = 'admin', status = 'approved', joined_at = now();

  UPDATE public.circle SET created_by = v_uid WHERE id = v_circle_id;

  INSERT INTO public.conversation_members (conversation_id, user_id)
  VALUES (v_group_chat, v_uid)
  ON CONFLICT DO NOTHING;

  RETURN jsonb_build_object('role', 'admin', 'status', 'approved');
END;
$$;

-- Canjea un código de invitación de forma atómica
CREATE OR REPLACE FUNCTION public.redeem_invitation_code(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_inv public.invitations%ROWTYPE;
  v_new_status public.member_status;
  v_group_chat UUID := '00000000-0000-0000-0000-000000000002';
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT * INTO v_inv
  FROM public.invitations
  WHERE upper(code) = upper(trim(p_code))
    AND is_active = true
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_invitation: Código de invitación no válido.';
  END IF;

  IF v_inv.expires_at IS NOT NULL AND v_inv.expires_at <= now() THEN
    RAISE EXCEPTION 'invalid_invitation: El código de invitación ha expirado.';
  END IF;

  IF v_inv.uses_count >= v_inv.max_uses THEN
    RAISE EXCEPTION 'invalid_invitation: Este código ya alcanzó su límite de usos.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.memberships
    WHERE circle_id = v_inv.circle_id
      AND user_id = v_uid
      AND status = 'blocked'
  ) THEN
    RAISE EXCEPTION 'user_blocked: No puedes ingresar a este círculo.';
  END IF;

  v_new_status := CASE WHEN v_inv.auto_approve THEN 'approved' ELSE 'pending' END;

  INSERT INTO public.memberships (circle_id, user_id, role, status, invited_by, joined_at)
  VALUES (
    v_inv.circle_id,
    v_uid,
    'member',
    v_new_status,
    v_inv.created_by,
    CASE WHEN v_inv.auto_approve THEN now() ELSE NULL END
  )
  ON CONFLICT (circle_id, user_id)
  DO UPDATE SET
    status = v_new_status,
    invited_by = v_inv.created_by,
    joined_at = CASE WHEN v_inv.auto_approve THEN now() ELSE memberships.joined_at END;

  UPDATE public.invitations
  SET uses_count = uses_count + 1,
      is_active = (uses_count + 1) < max_uses
  WHERE id = v_inv.id;

  IF v_new_status = 'approved' THEN
    INSERT INTO public.conversation_members (conversation_id, user_id)
    VALUES (v_group_chat, v_uid)
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN jsonb_build_object(
    'status', v_new_status::text,
    'auto_approved', v_inv.auto_approve
  );
END;
$$;

-- Gestión administrativa de miembros (aprobar, rechazar, expulsar, bloquear)
CREATE OR REPLACE FUNCTION public.admin_manage_member(p_target_user UUID, p_action TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin UUID := auth.uid();
  v_circle_id UUID := '00000000-0000-0000-0000-000000000001';
  v_group_chat UUID := '00000000-0000-0000-0000-000000000002';
  v_next_status public.member_status;
BEGIN
  IF NOT public.is_circle_admin(v_admin) THEN
    RAISE EXCEPTION 'not_authorized: Solo el administrador puede gestionar integrantes.';
  END IF;

  IF p_target_user = v_admin AND p_action IN ('remove', 'block', 'reject') THEN
    RAISE EXCEPTION 'invalid_action: No puedes expulsarte o bloquearte a ti mismo.';
  END IF;

  v_next_status := CASE p_action
    WHEN 'approve' THEN 'approved'::public.member_status
    WHEN 'reject' THEN 'rejected'::public.member_status
    WHEN 'remove' THEN 'removed'::public.member_status
    WHEN 'block' THEN 'blocked'::public.member_status
    ELSE NULL
  END;

  IF v_next_status IS NULL THEN
    RAISE EXCEPTION 'invalid_action: Acción no soportada.';
  END IF;

  UPDATE public.memberships
  SET status = v_next_status,
      joined_at = CASE WHEN v_next_status = 'approved' THEN COALESCE(joined_at, now()) ELSE joined_at END
  WHERE circle_id = v_circle_id
    AND user_id = p_target_user;

  IF v_next_status = 'approved' THEN
    INSERT INTO public.conversation_members (conversation_id, user_id)
    VALUES (v_group_chat, p_target_user)
    ON CONFLICT DO NOTHING;
  ELSE
    DELETE FROM public.conversation_members
    WHERE user_id = p_target_user;
  END IF;

  RETURN jsonb_build_object('user_id', p_target_user, 'status', v_next_status::text);
END;
$$;

-- Obtiene o crea sin duplicados un chat privado 1:1 entre dos amigos aprobados
CREATE OR REPLACE FUNCTION public.get_or_create_direct_chat(p_other_user UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me UUID := auth.uid();
  v_circle_id UUID := '00000000-0000-0000-0000-000000000001';
  v_conv_id UUID;
BEGIN
  IF NOT public.is_approved_member(v_me) OR NOT public.is_approved_member(p_other_user) THEN
    RAISE EXCEPTION 'not_authorized: Ambos usuarios deben ser miembros aprobados.';
  END IF;

  IF v_me = p_other_user THEN
    RAISE EXCEPTION 'invalid_chat: No puedes iniciar un chat privado contigo mismo.';
  END IF;

  SELECT c.id INTO v_conv_id
  FROM public.conversations c
  JOIN public.conversation_members cm1 ON cm1.conversation_id = c.id AND cm1.user_id = v_me
  JOIN public.conversation_members cm2 ON cm2.conversation_id = c.id AND cm2.user_id = p_other_user
  WHERE c.type = 'direct'
  LIMIT 1;

  IF v_conv_id IS NOT NULL THEN
    RETURN v_conv_id;
  END IF;

  INSERT INTO public.conversations (circle_id, type)
  VALUES (v_circle_id, 'direct')
  RETURNING id INTO v_conv_id;

  INSERT INTO public.conversation_members (conversation_id, user_id)
  VALUES (v_conv_id, v_me), (v_conv_id, p_other_user);

  RETURN v_conv_id;
END;
$$;

-- Votación atómica en encuestas con control estricto de votos duplicados
CREATE OR REPLACE FUNCTION public.cast_poll_vote(p_poll_id UUID, p_option_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_allows_multiple BOOLEAN;
  v_ends_at TIMESTAMPTZ;
BEGIN
  IF NOT public.is_approved_member(v_uid) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  SELECT allows_multiple, ends_at
  INTO v_allows_multiple, v_ends_at
  FROM public.polls
  WHERE id = p_poll_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'poll_not_found';
  END IF;

  IF v_ends_at IS NOT NULL AND v_ends_at <= now() THEN
    RAISE EXCEPTION 'poll_closed: Esta encuesta ya finalizó.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.poll_options
    WHERE id = p_option_id AND poll_id = p_poll_id
  ) THEN
    RAISE EXCEPTION 'invalid_option';
  END IF;

  IF NOT v_allows_multiple THEN
    DELETE FROM public.poll_votes
    WHERE poll_id = p_poll_id AND user_id = v_uid;

    INSERT INTO public.poll_votes (poll_id, option_id, user_id)
    VALUES (p_poll_id, p_option_id, v_uid);
  ELSE
    IF EXISTS (
      SELECT 1 FROM public.poll_votes
      WHERE poll_id = p_poll_id AND option_id = p_option_id AND user_id = v_uid
    ) THEN
      DELETE FROM public.poll_votes
      WHERE poll_id = p_poll_id AND option_id = p_option_id AND user_id = v_uid;
    ELSE
      INSERT INTO public.poll_votes (poll_id, option_id, user_id)
      VALUES (p_poll_id, p_option_id, v_uid);
    END IF;
  END IF;
END;
$$;

-- Resumen Anual estadístico real del grupo
CREATE OR REPLACE FUNCTION public.get_annual_summary(p_year INT)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_circle_id UUID := '00000000-0000-0000-0000-000000000001';
  v_total_posts INT;
  v_total_photos INT;
  v_total_videos INT;
  v_total_memories INT;
  v_top_day TEXT;
  v_top_posts JSONB;
BEGIN
  IF NOT public.is_approved_member(v_uid) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  SELECT COUNT(*) INTO v_total_posts
  FROM public.posts
  WHERE circle_id = v_circle_id
    AND EXTRACT(YEAR FROM created_at) = p_year;

  SELECT COUNT(*) INTO v_total_photos
  FROM public.post_media pm
  JOIN public.posts p ON p.id = pm.post_id
  WHERE p.circle_id = v_circle_id
    AND pm.media_type = 'image'
    AND EXTRACT(YEAR FROM p.created_at) = p_year;

  SELECT COUNT(*) INTO v_total_videos
  FROM public.post_media pm
  JOIN public.posts p ON p.id = pm.post_id
  WHERE p.circle_id = v_circle_id
    AND pm.media_type = 'video'
    AND EXTRACT(YEAR FROM p.created_at) = p_year;

  SELECT COUNT(*) INTO v_total_memories
  FROM public.posts
  WHERE circle_id = v_circle_id
    AND is_memory = true
    AND EXTRACT(YEAR FROM created_at) = p_year;

  SELECT to_char(date_trunc('day', created_at), 'YYYY-MM-DD') INTO v_top_day
  FROM public.posts
  WHERE circle_id = v_circle_id
    AND EXTRACT(YEAR FROM created_at) = p_year
  GROUP BY 1
  ORDER BY COUNT(*) DESC
  LIMIT 1;

  SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) INTO v_top_posts
  FROM (
    SELECT
      p.id,
      p.content,
      p.created_at,
      pr.nickname AS author_nickname,
      COUNT(r.id) AS reactions_count
    FROM public.posts p
    JOIN public.profiles pr ON pr.id = p.author_id
    LEFT JOIN public.reactions r ON r.post_id = p.id
    WHERE p.circle_id = v_circle_id
      AND EXTRACT(YEAR FROM p.created_at) = p_year
    GROUP BY p.id, pr.nickname
    ORDER BY reactions_count DESC, p.created_at DESC
    LIMIT 5
  ) t;

  RETURN jsonb_build_object(
    'year', p_year,
    'total_posts', v_total_posts,
    'total_photos', v_total_photos,
    'total_videos', v_total_videos,
    'total_memories', v_total_memories,
    'most_active_date', v_top_day,
    'top_posts', v_top_posts
  );
END;
$$;