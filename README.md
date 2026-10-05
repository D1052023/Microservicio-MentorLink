# Microservicio-MentorLink

## Evidencia de ejecución con Supabase CLI

A continuación se muestra el log detallado de los comandos ejecutados para inicializar el proyecto, crear la migración y aplicarla en la base de datos remota de Supabase:

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