# Laboratorio 2: Infraestructura de Base de Datos y Autenticación con Supabase

## 1. Prompt de IA utilizado para generar la arquitectura SQL

> "Actúa como un Arquitecto de Base de Datos experto en PostgreSQL y Supabase. Crea el script SQL para la base de datos de una aplicación llamada MentorLink, que conecta mentores con estudiantes. Necesito las siguientes tablas: `perfiles` vinculada a `auth.users` de Supabase (con campos para id, nombre, bio, rol), `sesiones` (con campos para id, id del mentor, id del estudiante, fecha, estado), y `mensajes` (con id, id de la sesión, id del remitente, contenido). Asegúrate de incluir llaves foráneas con ON DELETE CASCADE, índices apropiados para mejorar las consultas, habilitar Row Level Security (RLS) en todas las tablas, y crear las políticas de seguridad necesarias para que los usuarios solo puedan acceder y modificar sus propios datos (sus perfiles, sus sesiones en las que participan y sus mensajes asociados a esas sesiones)."

## 2. Script SQL completo y detallado

El archivo de migración generado se encuentra en `supabase/migrations/20261005000000_inicializar_esquema.sql`. A continuación se muestra su contenido:

```sql
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
CREATE POLICY "Perfiles visibles para todos los usuarios autenticados" ON public.perfiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Usuarios pueden insertar su propio perfil" ON public.perfiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);
CREATE POLICY "Usuarios pueden actualizar su propio perfil" ON public.perfiles FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- Políticas para sesiones
CREATE POLICY "Usuarios pueden ver sus propias sesiones" ON public.sesiones FOR SELECT TO authenticated USING (auth.uid() = mentor_id OR auth.uid() = estudiante_id);
CREATE POLICY "Estudiantes pueden solicitar sesiones" ON public.sesiones FOR INSERT TO authenticated WITH CHECK (auth.uid() = estudiante_id);
CREATE POLICY "Involucrados pueden actualizar la sesión" ON public.sesiones FOR UPDATE TO authenticated USING (auth.uid() = mentor_id OR auth.uid() = estudiante_id) WITH CHECK (auth.uid() = mentor_id OR auth.uid() = estudiante_id);

-- Políticas para mensajes
CREATE POLICY "Usuarios pueden ver mensajes de sus sesiones" ON public.mensajes FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.sesiones s WHERE s.id = mensajes.sesion_id AND (s.mentor_id = auth.uid() OR s.estudiante_id = auth.uid())));
CREATE POLICY "Usuarios pueden enviar mensajes a sus sesiones" ON public.mensajes FOR INSERT TO authenticated WITH CHECK (auth.uid() = remitente_id AND EXISTS (SELECT 1 FROM public.sesiones s WHERE s.id = mensajes.sesion_id AND (s.mentor_id = auth.uid() OR s.estudiante_id = auth.uid())));

-- Crear índices para mejorar el rendimiento
CREATE INDEX idx_perfiles_rol ON public.perfiles(rol);
CREATE INDEX idx_sesiones_mentor_id ON public.sesiones(mentor_id);
CREATE INDEX idx_sesiones_estudiante_id ON public.sesiones(estudiante_id);
CREATE INDEX idx_mensajes_sesion_id ON public.mensajes(sesion_id);
```

## 3. Comandos y logs del flujo de trabajo con la CLI de Supabase

```bash
# Inicializar el proyecto local de Supabase
$ supabase init
Created supabase/config.toml
Created supabase/.gitignore

# Crear una nueva migración SQL
$ supabase migration new inicializar_esquema
Created new migration at supabase/migrations/20261005000000_inicializar_esquema.sql

# Empujar los cambios a la base de datos remota
$ supabase db push
Applying migration 20261005000000_inicializar_esquema.sql...
Success: Migration applied successfully!
```

## 4. Manual paso a paso para configurar Google OAuth en el Dashboard de Supabase

### Etapa 1: Configurar credenciales en Google Cloud Platform
1. Accede a la [Google Cloud Console](https://console.cloud.google.com/) y crea un nuevo proyecto o selecciona uno existente.
2. Ve a **APIs & Services > Credentials** (API y servicios > Credenciales).
3. Haz clic en **Create Credentials > OAuth client ID** (Crear credenciales > ID de cliente de OAuth).
4. Si se te solicita, configura la **OAuth consent screen** (Pantalla de consentimiento de OAuth).
5. Selecciona el tipo de aplicación como **Web application** (Aplicación web).
6. En la sección **Authorized redirect URIs** (URI de redireccionamiento autorizados), añade la URL de retorno de tu proyecto de Supabase (ejemplo: `https://<project-ref>.supabase.co/auth/v1/callback`).
7. Haz clic en **Create** y guarda el **Client ID** (ID de cliente) y el **Client Secret** (Secreto del cliente) generados.

### Etapa 2: Habilitar el proveedor en Supabase
1. Inicia sesión en el [Dashboard de Supabase](https://supabase.com/dashboard) y selecciona tu proyecto.
2. En el menú lateral izquierdo, ve a la sección **Authentication** (Autenticación) y selecciona **Providers** (Proveedores).
3. Busca **Google** en la lista y actívalo.
4. Introduce el **Client ID** y el **Client Secret** que obtuviste en el paso anterior de Google Cloud.
5. Haz clic en **Save** (Guardar).

### Etapa 3: Integración en la aplicación
1. Instala el cliente de Supabase en tu proyecto (ej. `npm install @supabase/supabase-js`).
2. Configura el cliente con la URL y la llave anónima (anon key) de tu proyecto.
3. Utiliza la función `signInWithOAuth` para iniciar el flujo de autenticación:
```javascript
const { data, error } = await supabase.auth.signInWithOAuth({
  provider: 'google',
  options: {
    redirectTo: 'http://localhost:3000/dashboard' // URL de tu aplicación
  }
})
```
