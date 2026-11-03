// Conexión con Supabase para guardar los puntos online y la clasificación.
// La URL y la clave pública (publishable) no son secretas: es normal que estén
// en una web pública. La seguridad la ponen las funciones de supabase.sql,
// que no dejan leer ni tocar las tablas directamente.
window.SUPABASE_CONFIG = {
  url: "https://mqhymxlsnckamvnigwxy.supabase.co",
  key: "sb_publishable_NfUG6kguqpbBpLF-bQBaFQ_cTop9xpp"
};
