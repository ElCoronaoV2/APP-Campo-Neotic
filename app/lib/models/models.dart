// voz-campo MVP - Models
// Modelos de datos compartidos por toda la app.

class Socio {
  final String numSocio;
  final String nombre;
  final bool activo;

  const Socio({
    required this.numSocio,
    required this.nombre,
    required this.activo,
  });

  factory Socio.fromJson(Map<String, dynamic> json) => Socio(
        numSocio: json['numSocio']?.toString() ?? '',
        nombre: json['nombre']?.toString() ?? '',
        activo: json['activo']?.toString().toLowerCase() == 'si' ||
            json['activo'] == true,
      );

  Map<String, dynamic> toJson() => {
        'numSocio': numSocio,
        'nombre': nombre,
        'activo': activo,
      };
}

class Pregunta {
  final int orden;
  final String texto;
  final String tipo;
  final bool obligatoria;

  const Pregunta({
    required this.orden,
    required this.texto,
    required this.tipo,
    required this.obligatoria,
  });

  factory Pregunta.fromJson(Map<String, dynamic> json) => Pregunta(
        orden: int.tryParse(json['Orden']?.toString() ?? '0') ?? 0,
        texto: json['Texto']?.toString() ?? '',
        tipo: json['Tipo']?.toString() ?? 'texto',
        obligatoria: (json['Obligatoria']?.toString() ?? 'Si').toLowerCase() == 'si',
      );

  Map<String, dynamic> toJson() => {
        'Orden': orden,
        'Texto': texto,
        'Tipo': tipo,
        'Obligatoria': obligatoria ? 'Si' : 'No',
      };
}

class Respuesta {
  final String preguntaTipo;
  final String valorNormalizado;
  final String textoOriginal;
  final double confianza;

  const Respuesta({
    required this.preguntaTipo,
    required this.valorNormalizado,
    required this.textoOriginal,
    required this.confianza,
  });

  Map<String, dynamic> toJson() => {
        preguntaTipo: valorNormalizado,
      };
}

class Registro {
  final String usuario;
  final DateTime fechaHora;
  final String? coordenadasGps;
  final Map<String, String> respuestas;
  final Map<String, String> textoOriginal;
  final Map<String, double> confianza;
  final String dispositivo;

  const Registro({
    required this.usuario,
    required this.fechaHora,
    required this.coordenadasGps,
    required this.respuestas,
    required this.textoOriginal,
    required this.confianza,
    required this.dispositivo,
  });

  Map<String, dynamic> toJson() => {
        'usuario': usuario,
        'fechaHora': fechaHora.toIso8601String(),
        'coordenadasGps': coordenadasGps ?? '',
        'respuestas': respuestas,
        'metadatosVoz': {
          for (final k in textoOriginal.keys)
            '${k}_original': textoOriginal[k],
          'confianza_fuzzy':
              confianza.isNotEmpty ? confianza.values.first : 0.0,
          'modo_entrada': 'voz_asistida',
        },
        'dispositivo': dispositivo,
      };
}

class Finca {
  final String nombreOficial;
  final List<String> variantes;
  final String numSocio;

  const Finca({
    required this.nombreOficial,
    required this.variantes,
    required this.numSocio,
  });

  factory Finca.fromJson(Map<String, dynamic> json) => Finca(
        nombreOficial: json['nombre_oficial']?.toString() ?? '',
        variantes: (json['variantes'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        numSocio: json['numSocio']?.toString() ?? '',
      );
}

class Municipio {
  final String id;
  final String nombreOficial;
  final String provincia;
  final String comunidad;
  final List<String> variantes;

  const Municipio({
    required this.id,
    required this.nombreOficial,
    required this.provincia,
    required this.comunidad,
    required this.variantes,
  });

  factory Municipio.fromJson(Map<String, dynamic> json) => Municipio(
        id: json['id']?.toString() ?? '',
        nombreOficial: json['nombre_oficial']?.toString() ?? '',
        provincia: json['provincia']?.toString() ?? '',
        comunidad: json['comunidad']?.toString() ?? '',
        variantes: (json['variantes'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
}