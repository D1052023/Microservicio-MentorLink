-- Enable RLS & set secret
ALTER DATABASE postgres SET "app.jwt_secret" TO 'super-secret-jwt-token-with-at-least-32-characters-long';

CREATE TABLE public.perfiles (
  id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL PRIMARY KEY,
  nombre text NOT NULL, bio text,
  rol text CHECK (rol IN ('mentor', 'estudiante')) NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE public.sesiones (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  mentor_id uuid REFERENCES public.perfiles(id) ON DELETE CASCADE NOT NULL,
  estudiante_id uuid REFERENCES public.perfiles(id) ON DELETE CASCADE NOT NULL,
  fecha timestamp with time zone NOT NULL,
  estado text CHECK (estado IN ('pendiente','confirmada','cancelada','completada')) DEFAULT 'pendiente' NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE public.mensajes (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  sesion_id uuid REFERENCES public.sesiones(id) ON DELETE CASCADE NOT NULL,
  remitente_id uuid REFERENCES public.perfiles(id) ON DELETE CASCADE NOT NULL,
  contenido text NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.perfiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sesiones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mensajes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Ver perfiles" ON public.perfiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Insertar perfil" ON public.perfiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);
CREATE POLICY "Actualizar perfil" ON public.perfiles FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

CREATE POLICY "Ver sesiones" ON public.sesiones FOR SELECT TO authenticated USING (auth.uid() IN (mentor_id, estudiante_id));
CREATE POLICY "Solicitar sesión" ON public.sesiones FOR INSERT TO authenticated WITH CHECK (auth.uid() = estudiante_id);
CREATE POLICY "Actualizar sesión" ON public.sesiones FOR UPDATE TO authenticated USING (auth.uid() IN (mentor_id, estudiante_id)) WITH CHECK (auth.uid() IN (mentor_id, estudiante_id));

CREATE POLICY "Ver mensajes" ON public.mensajes FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.sesiones s WHERE s.id = mensajes.sesion_id AND auth.uid() IN (s.mentor_id, s.estudiante_id)));
CREATE POLICY "Enviar mensajes" ON public.mensajes FOR INSERT TO authenticated WITH CHECK (auth.uid() = remitente_id AND EXISTS (SELECT 1 FROM public.sesiones s WHERE s.id = mensajes.sesion_id AND auth.uid() IN (s.mentor_id, s.estudiante_id)));

CREATE INDEX idx_perf_rol ON public.perfiles(rol);
CREATE INDEX idx_ses_ment ON public.sesiones(mentor_id);
CREATE INDEX idx_ses_est ON public.sesiones(estudiante_id);
CREATE INDEX idx_msg_ses ON public.mensajes(sesion_id);
