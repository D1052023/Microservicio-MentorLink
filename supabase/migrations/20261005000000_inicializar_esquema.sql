-- Enable RLS
ALTER DATABASE postgres SET "app.jwt_secret" TO 'super-secret-jwt-token-with-at-least-32-characters-long';

-- Crear la tabla perfiles
CREATE TABLE public.perfiles (
  id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL PRIMARY KEY,
  nombre text NOT NULL,
  bio text,
  rol text CHECK (rol IN ('mentor', 'estudiante')) NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Crear la tabla sesiones
CREATE TABLE public.sesiones (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  mentor_id uuid REFERENCES public.perfiles(id) ON DELETE CASCADE NOT NULL,
  estudiante_id uuid REFERENCES public.perfiles(id) ON DELETE CASCADE NOT NULL,
  fecha timestamp with time zone NOT NULL,
  estado text CHECK (estado IN ('pendiente', 'confirmada', 'cancelada', 'completada')) DEFAULT 'pendiente' NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Crear la tabla mensajes
CREATE TABLE public.mensajes (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  sesion_id uuid REFERENCES public.sesiones(id) ON DELETE CASCADE NOT NULL,
  remitente_id uuid REFERENCES public.perfiles(id) ON DELETE CASCADE NOT NULL,
  contenido text NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Habilitar RLS en todas las tablas
ALTER TABLE public.perfiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sesiones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mensajes ENABLE ROW LEVEL SECURITY;

-- Políticas para perfiles
-- Los usuarios pueden ver todos los perfiles (o solo algunos dependiendo del caso de uso, aquí asumo todos para que puedan buscar mentores)
CREATE POLICY "Perfiles visibles para todos los usuarios autenticados"
ON public.perfiles FOR SELECT
TO authenticated
USING (true);

-- Los usuarios solo pueden insertar, actualizar o eliminar su propio perfil
CREATE POLICY "Usuarios pueden insertar su propio perfil"
ON public.perfiles FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

CREATE POLICY "Usuarios pueden actualizar su propio perfil"
ON public.perfiles FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Políticas para sesiones
-- Los usuarios pueden ver sesiones donde sean el mentor o el estudiante
CREATE POLICY "Usuarios pueden ver sus propias sesiones"
ON public.sesiones FOR SELECT
TO authenticated
USING (auth.uid() = mentor_id OR auth.uid() = estudiante_id);

-- Solo estudiantes pueden solicitar (insertar) sesiones (asumiendo este flujo)
CREATE POLICY "Estudiantes pueden solicitar sesiones"
ON public.sesiones FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = estudiante_id);

-- Los involucrados pueden actualizar el estado de la sesión
CREATE POLICY "Involucrados pueden actualizar la sesión"
ON public.sesiones FOR UPDATE
TO authenticated
USING (auth.uid() = mentor_id OR auth.uid() = estudiante_id)
WITH CHECK (auth.uid() = mentor_id OR auth.uid() = estudiante_id);

-- Políticas para mensajes
-- Los usuarios pueden ver mensajes de las sesiones en las que participan
CREATE POLICY "Usuarios pueden ver mensajes de sus sesiones"
ON public.mensajes FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.sesiones s
    WHERE s.id = mensajes.sesion_id
    AND (s.mentor_id = auth.uid() OR s.estudiante_id = auth.uid())
  )
);

-- Los usuarios pueden enviar mensajes a las sesiones en las que participan
CREATE POLICY "Usuarios pueden enviar mensajes a sus sesiones"
ON public.mensajes FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = remitente_id AND
  EXISTS (
    SELECT 1 FROM public.sesiones s
    WHERE s.id = mensajes.sesion_id
    AND (s.mentor_id = auth.uid() OR s.estudiante_id = auth.uid())
  )
);

-- Crear índices para mejorar el rendimiento
CREATE INDEX idx_perfiles_rol ON public.perfiles(rol);
CREATE INDEX idx_sesiones_mentor_id ON public.sesiones(mentor_id);
CREATE INDEX idx_sesiones_estudiante_id ON public.sesiones(estudiante_id);
CREATE INDEX idx_mensajes_sesion_id ON public.mensajes(sesion_id);
