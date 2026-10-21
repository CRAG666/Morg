// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get themeLight => 'Tema claro';

  @override
  String get themeDark => 'Tema oscuro';

  @override
  String saveFailed(String error) {
    return 'No se pudo guardar: $error';
  }

  @override
  String get unsavedChangesTitle => 'Cambios sin guardar';

  @override
  String get discardChangesQuestion => '¿Descartar los cambios?';

  @override
  String get keepEditing => 'Seguir editando';

  @override
  String get discard => 'Descartar';

  @override
  String get save => 'Guardar';

  @override
  String themeImported(String name) {
    return 'Tema \"$name\" importado. Úsalo con \"theme\": \"$name\".';
  }

  @override
  String get pickThemeFile => 'Tema exportado (.json)';

  @override
  String get resetConfigTitle => 'Restaurar configuración';

  @override
  String get resetConfigBody =>
      'Se reemplazará morg.json por la configuración por defecto.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get reset => 'Restaurar';

  @override
  String get settings => 'Ajustes';

  @override
  String get editConfig => 'Editar configuración';

  @override
  String get editConfigSubtitle =>
      'morg.json — misma estructura que neorg.setup()';

  @override
  String get importTheme => 'Importar tema de Neovim';

  @override
  String currentTheme(String name) {
    return 'Tema actual: $name';
  }

  @override
  String get restoreDefaults => 'Restaurar configuración por defecto';

  @override
  String couldNotOpen(String target) {
    return 'No se pudo abrir $target';
  }

  @override
  String couldNotOpenBecause(String target, String error) {
    return 'No se pudo abrir $target: $error';
  }

  @override
  String notFound(String location) {
    return 'No se encontró «$location»';
  }

  @override
  String unsupportedLink(String target) {
    return 'Destino no soportado: $target';
  }

  @override
  String get noteMissingTitle => 'La nota no existe';

  @override
  String createNoteQuestion(String path, String location) {
    return '¿Crear $path en $location?';
  }

  @override
  String get create => 'Crear';

  @override
  String get edit => 'Editar';

  @override
  String couldNotRead(String error) {
    return 'No se pudo leer: $error';
  }

  @override
  String couldNotReadAt(String location, String error) {
    return 'No se pudo leer $location:\n$error';
  }

  @override
  String get newNote => 'Nueva nota';

  @override
  String get newNoteHint => 'nombre o carpeta/nombre';

  @override
  String get index => 'Índice';

  @override
  String get journalToday => 'Diario de hoy';

  @override
  String get syncConflict => 'Conflicto de Syncthing';

  @override
  String get workspaceName => 'Nombre del workspace';

  @override
  String get workspaceNameHint => 'el mismo que en Neovim, p. ej. notas';

  @override
  String get add => 'Añadir';

  @override
  String removeWorkspace(String name) {
    return 'Quitar «$name»';
  }

  @override
  String get removeWorkspaceBody =>
      'Se quita de morg.json. Los archivos no se borran.';

  @override
  String get remove => 'Quitar';

  @override
  String get fileAccess => 'Acceso a archivos';

  @override
  String get fileAccessBody =>
      'Necesario para workspaces locales; los de la nube no lo requieren.';

  @override
  String get grant => 'Conceder';

  @override
  String get workspaces => 'Workspaces';

  @override
  String get workspaceMissing =>
      'No está en este teléfono · toca para elegir su carpeta';

  @override
  String get openFile => 'Abrir archivo…';

  @override
  String get pickNorgFile => 'Abrir archivo Norg';

  @override
  String get alsoFromCloud => 'También desde la nube';

  @override
  String get norgGuide => 'Ayuda de Neorg';

  @override
  String get importConfig => 'Importar configuración';

  @override
  String get importConfigSubtitle =>
      'Reemplaza morg.json por un archivo, p. ej. de tus notas sincronizadas';

  @override
  String get pickConfigFile => 'Archivo de configuración (morg.json)';

  @override
  String get configImported => 'Configuración importada';

  @override
  String invalidFile(String error) {
    return 'Archivo inválido: $error';
  }

  @override
  String get themeSystem => 'Tema del sistema';

  @override
  String get addWorkspace => 'Añadir workspace';

  @override
  String get noWorkspaces =>
      'Aún no hay workspaces. Toca «Añadir workspace» y elige la carpeta de tus notas.';

  @override
  String get browseFiles => 'Explorar archivos';

  @override
  String get changeFolder => 'Cambiar carpeta';

  @override
  String get rename => 'Renombrar';

  @override
  String noIndexTitle(String file) {
    return 'No hay $file';
  }

  @override
  String get noIndexBody =>
      '¿Crearlo, como el índice de Neorg, o explorar los archivos del workspace?';

  @override
  String get appearance => 'Apariencia';

  @override
  String get themeMode => 'Tema';

  @override
  String get colorscheme => 'Colorscheme';

  @override
  String get rendering => 'Renderizado (core.concealer)';

  @override
  String get headingIcons => 'Iconos de encabezados (uno por nivel)';

  @override
  String get listIcons => 'Iconos de listas';

  @override
  String get quoteIcons => 'Iconos de citas';

  @override
  String get hideCodeTags => 'Ocultar las líneas @code y @end';

  @override
  String get notesSection => 'Notas';

  @override
  String get author => 'Autor (metagen)';

  @override
  String get indexFile => 'Archivo índice';

  @override
  String get defaultWorkspace => 'Workspace predeterminado';

  @override
  String get none => 'Ninguno';

  @override
  String get journal => 'Diario';

  @override
  String get journalFolder => 'Carpeta del diario';

  @override
  String get journalStrategy => 'Ruta de cada entrada';

  @override
  String get strategyNested => '2026/10/20.norg';

  @override
  String get strategyFlat => '2026-10-20.norg';

  @override
  String get journalTemplate => 'Archivo de plantilla';

  @override
  String get useTemplate => 'Usar la plantilla';

  @override
  String get advanced => 'Avanzado';

  @override
  String get defaultSetting => 'Por defecto';

  @override
  String get language => 'Idioma';

  @override
  String get systemLanguage => 'Sistema';

  @override
  String get norgCheatsheet => 'Guía rápida de Neorg';

  @override
  String get todoUndone => 'Sin hacer';

  @override
  String get todoDone => 'Hecha';

  @override
  String get todoNeedsInput => 'Necesita más información';

  @override
  String get todoUrgent => 'Urgente';

  @override
  String get todoRecurring => 'Recurrente';

  @override
  String get todoPending => 'En curso';

  @override
  String get todoOnHold => 'En espera';

  @override
  String get todoCancelled => 'Cancelada';

  @override
  String get agenda => 'Agenda';

  @override
  String get clear => 'Borrar';

  @override
  String get delete => 'Eliminar';

  @override
  String get deleted => 'Eliminado';

  @override
  String get promote => 'Subir de nivel';

  @override
  String get demote => 'Bajar de nivel';

  @override
  String get moveUp => 'Mover arriba';

  @override
  String get moveDown => 'Mover abajo';

  @override
  String get toOrdered => 'Convertir en lista numerada';

  @override
  String get toUnordered => 'Convertir en lista con viñetas';

  @override
  String get makeTask => 'Convertir en tarea';

  @override
  String get focus => 'Enfocar';

  @override
  String get unfocus => 'Salir del enfoque';

  @override
  String focusedOn(String title) {
    return 'Enfocado en $title';
  }

  @override
  String get dueDate => 'Fecha límite…';

  @override
  String get removeDueDate => 'Quitar fecha límite';

  @override
  String dueOn(String date) {
    return 'Vence $date';
  }

  @override
  String startsOn(String date) {
    return 'Empieza $date';
  }

  @override
  String happensOn(String date) {
    return 'El $date';
  }

  @override
  String priority(String priority) {
    return 'Prioridad $priority';
  }

  @override
  String get exportMarkdown => 'Exportar a Markdown';

  @override
  String get exported => 'Exportado';

  @override
  String get journalOnDate => 'Diario de otra fecha…';

  @override
  String get previousDay => 'Día anterior';

  @override
  String get nextDay => 'Día siguiente';

  @override
  String get noDatedTasks =>
      'Aún no hay tareas con fecha. Mantén presionado el ( ) de una tarea para ponerle fecha límite.';

  @override
  String get noResults => 'Sin resultados';

  @override
  String get outline => 'Índice';

  @override
  String get overdue => 'Vencidas';

  @override
  String get today => 'Hoy';

  @override
  String get tomorrow => 'Mañana';

  @override
  String get redo => 'Rehacer';

  @override
  String get undo => 'Deshacer';

  @override
  String get replace => 'Reemplazar';

  @override
  String replaceFileQuestion(String file) {
    return '$file ya existe. ¿Reemplazarlo?';
  }

  @override
  String get search => 'Buscar';

  @override
  String searchHint(String workspace) {
    return 'Buscar en $workspace';
  }

  @override
  String get summary => 'Resumen del workspace';

  @override
  String get tasks => 'Tareas';

  @override
  String get uncategorized => 'Sin categoría';

  @override
  String get formatOnEdit => 'Formatear las líneas editadas';

  @override
  String get dedentExcess => 'Quitar sangría de más';

  @override
  String get formatFile => 'Formatear archivo';

  @override
  String get formatted => 'Formateado';
}
