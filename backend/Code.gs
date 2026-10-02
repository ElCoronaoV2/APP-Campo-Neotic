/**
 * voz-campo - Backend Google Apps Script
 *
 * Recibe registros desde la app móvil y los escribe en Google Sheets.
 *
 * SETUP (una sola vez):
 *   1. Crear Google Sheet "voz-campo-data" con pestañas:
 *      Registros | Socios | Fincas_Pueblos | Preguntas
 *   2. Copiar ID de la Sheet (parte entre /d/ y /edit en la URL)
 *      y pegarlo en SHEET_ID más abajo.
 *   3. Elegir un API_TOKEN robusto y pegarlo en API_TOKEN más abajo.
 *   4. Deploy: clasp push && clasp deploy
 *
 * ENDPOINTS:
 *   POST /exec       -> crear registro (envía la app móvil)
 *   GET  /exec?op=preguntas    -> lista de preguntas del cuestionario
 *   GET  /exec?op=socios&numSocio=NNNN  -> validación de socio
 *   GET  /exec?op=fincas&numSocio=NNNN  -> fincas del socio (cache offline)
 */

// ============================================================
// CONFIGURACIÓN - EDITAR ANTES DE DESPLEGAR
// ============================================================

const SHEET_ID = '1mC-nV6IelemZDPMZZaGzq6nhoJei5tqnHKnUXJVDk5c';
const API_TOKEN = '458bc7cef5e97c6b5681c7ede1c0a33131ba3ed15b98354837952babaff120ca';

// ============================================================

function doPost(e) {
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);

  try {
    const body = JSON.parse(e.postData.contents);

    if (body.token !== API_TOKEN) {
      return jsonResponse({ error: 'unauthorized' }, 401);
    }

    const op = body.op || 'crear_registro';
    switch (op) {
      case 'crear_registro':
        return crearRegistro(body);
      case 'crear_socio':
        return crearSocio(body);
      default:
        return jsonResponse({ error: 'unknown_op', op: op }, 400);
    }
  } catch (err) {
    return jsonResponse({ error: String(err) }, 500);
  } finally {
    lock.releaseLock();
  }
}

function doGet(e) {
  try {
    const op = e.parameter.op;
    if (!op) return jsonResponse({ error: 'missing_op' }, 400);

    if (e.parameter.token !== API_TOKEN) {
      return jsonResponse({ error: 'unauthorized' }, 401);
    }

    switch (op) {
      case 'preguntas':
        return listarPreguntas();
      case 'socios':
        return buscarSocio(e.parameter.numSocio, e.parameter.pin);
      case 'fincas':
        return listarFincas(e.parameter.numSocio);
      case 'debug_socios':
        return debugSocios();
      default:
        return jsonResponse({ error: 'unknown_op', op: op }, 400);
    }
  } catch (err) {
    return jsonResponse({ error: String(err) }, 500);
  }
}

// ============================================================
// HANDLERS
// ============================================================

function crearRegistro(body) {
  const ss = SpreadsheetApp.openById(SHEET_ID);
  const sheet = ss.getSheetByName('Registros');
  if (!sheet) return jsonResponse({ error: 'sheet_Registros_missing' }, 500);

  const lastRow = sheet.getLastRow();
  const lastId = lastRow > 1 ? Number(sheet.getRange(lastRow, 1).getValue()) || 0 : 0;
  const newId = lastId + 1;

  const r = body.respuestas || {};
  const m = body.metadatosVoz || {};

  const row = [
    newId,
    body.fechaHora || new Date().toISOString(),
    body.usuario || '',
    r.numSocio || body.usuario || '',
    r.pueblo || '',
    r.finca || '',
    r.hectareas !== undefined ? r.hectareas : '',
    r.tipoTratamiento || '',
    m.pueblo_original_audio || '',
    m.finca_teaxt_original || '',
    m.confianza_fuzzy !== undefined ? m.confianza_fuzzy : '',
    m.modo_entrada || '',
    body.coordenadasGps || '',
    body.dispositivo || '',
    'Validado'
  ];

  sheet.appendRow(row);

  return jsonResponse({ status: 'ok', id: newId });
}

function listarPreguntas() {
  const ss = SpreadsheetApp.openById(SHEET_ID);
  const sheet = ss.getSheetByName('Preguntas');
  if (!sheet) return jsonResponse({ preguntas: [] });

  const data = sheet.getDataRange().getValues();
  if (data.length < 2) return jsonResponse({ preguntas: [] });

  const headers = data[0];
  const preguntas = [];
  for (let i = 1; i < data.length; i++) {
    const row = data[i];
    const obj = {};
    headers.forEach((h, idx) => { obj[h] = row[idx]; });
    if (obj.Orden) preguntas.push(obj);
  }
  preguntas.sort((a, b) => Number(a.Orden) - Number(b.Orden));

  return jsonResponse({ preguntas: preguntas });
}

function buscarSocio(numSocio, pin) {
  if (!numSocio) return jsonResponse({ error: 'missing_numSocio' }, 400);
  const ss = SpreadsheetApp.openById(SHEET_ID);
  const sheet = ss.getSheetByName('Socios');
  if (!sheet) return jsonResponse({ error: 'sheet_Socios_missing' }, 500);

  const data = sheet.getDataRange().getValues();
  if (data.length < 2) return jsonResponse({ found: false });

  for (let i = 1; i < data.length; i++) {
    if (String(data[i][0]).replace(/^0+/, '') === String(numSocio).replace(/^0+/, '')) {
      const socio = {
        numSocio: data[i][0],
        nombre: data[i][1],
        activo: data[i][4]
      };
      if (pin !== undefined) {
        const stored = String(data[i][2] || '');
        socio.pin_ok = (stored !== "" && stored === pin);
      }
      return jsonResponse({ socio: socio });
    }
  }
  return jsonResponse({ found: false });
}

function listarFincas(numSocio) {
  const ss = SpreadsheetApp.openById(SHEET_ID);
  const sheet = ss.getSheetByName('Fincas_Pueblos');
  if (!sheet) return jsonResponse({ fincas: [] });

  const data = sheet.getDataRange().getValues();
  if (data.length < 2) return jsonResponse({ fincas: [] });

  const fincas = [];
  for (let i = 1; i < data.length; i++) {
    const row = data[i];
    const prop = String(row[2] || '');
    if (prop === 'TODOS' || prop === String(numSocio) || numSocio === undefined) {
      fincas.push({
        nombre_oficial: row[0],
        variantes: String(row[1] || '').split(';').map(s => s.trim()).filter(Boolean),
        numSocio: row[2]
      });
    }
  }
  return jsonResponse({ fincas: fincas });
}

function crearSocio(body) {
  Logger.log('crearSocio INICIO body=' + JSON.stringify(body));
  try {
    const ss = SpreadsheetApp.openById(SHEET_ID);
    let sheet = ss.getSheetByName('Socios');

    Logger.log('sheet tras getByName: ' + (sheet ? sheet.getName() : 'NULL'));

    // Auto-crear pestaña si no existe
    if (!sheet) {
      sheet = ss.insertSheet('Socios');
      Logger.log('pestana Socios creada');
    }

    // Auto-crear cabeceras si la pestana esta vacia
    if (sheet.getLastRow() === 0) {
      sheet.appendRow(['NumSocio', 'Nombre', 'PIN', 'PueblosHabituales', 'Activo']);
      Logger.log('cabeceras creadas');
    }

    const numSocio = String(body.numSocio || '').trim();
    const nombre = String(body.nombre || '').trim();
    const pin = String(body.pin || '');
    const pueblosHabituales = String(body.pueblosHabituales || '');
    const activo = String(body.activo || 'Si');

    if (!numSocio || !nombre) {
      Logger.log('error: missing numSocio or nombre');
      return jsonResponse({ error: 'missing_numSocio_or_nombre' }, 400);
    }

    // Buscar socio existente por numSocio
    const data = sheet.getDataRange().getValues();
    let existingRow = -1;
    for (let i = 1; i < data.length; i++) {
      if (String(data[i][0]) === numSocio) {
        existingRow = i + 1; // 1-indexed
        break;
      }
    }

    const row = [numSocio, nombre, pin, pueblosHabituales, activo];

    if (existingRow > 0) {
      sheet.getRange(existingRow, 1, 1, 5).setValues([row]);
      Logger.log('socio actualizado fila=' + existingRow);
      return jsonResponse({ status: 'ok', action: 'updated', numSocio: numSocio });
    } else {
      sheet.appendRow(row);
      Logger.log('socio creado fila=' + sheet.getLastRow());
      return jsonResponse({ status: 'ok', action: 'created', numSocio: numSocio });
    }
  } catch (err) {
    Logger.log('ERROR crearSocio: ' + String(err));
    return jsonResponse({ error: String(err) }, 500);
  }
}

function debugSocios() {
  const ss = SpreadsheetApp.openById(SHEET_ID);
  const sheets = ss.getSheets().map(function(s) { return s.getName(); });
  Logger.log('Pestanas encontradas: ' + JSON.stringify(sheets));
  const sheet = ss.getSheetByName('Socios');
  if (!sheet) {
    Logger.log('ERROR: pestana Socios no existe');
    return;
  }
  const lastRow = sheet.getLastRow();
  const lastCol = sheet.getLastColumn();
  Logger.log('lastRow=' + lastRow + ' lastCol=' + lastCol);
  if (lastRow > 0) {
    const maxR = Math.min(lastRow, 5);
    const maxC = Math.max(lastCol, 5);
    const data = sheet.getRange(1, 1, maxR, maxC).getValues();
    for (var i = 0; i < data.length; i++) {
      Logger.log('Fila ' + (i+1) + ': ' + JSON.stringify(data[i]));
    }
  } else {
    Logger.log('La pestana Socios esta vacia (0 filas)');
  }
}

// ============================================================
// HELPERS
// ============================================================

function jsonResponse(obj, status) {
  const output = ContentService.createTextOutput(JSON.stringify(obj));
  output.setMimeType(ContentService.MimeType.JSON);
  if (status) console.log('status', status);
  return output;
}

// ============================================================
// HEALTH CHECK (opcional)
// ============================================================

function doGet_health() {
  return jsonResponse({ status: 'ok', version: '0.1.0-mvp' });
}