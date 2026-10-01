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

const SHEET_ID = 'PEGAR_AQUI_EL_ID_DE_LA_GOOGLE_SHEET';
const API_TOKEN = 'CAMBIAR_POR_TOKEN_SEGURO_DE_32_CHARS_MIN';

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
    if (String(data[i][0]) === String(numSocio)) {
      const socio = {
        numSocio: data[i][0],
        nombre: data[i][1],
        activo: data[i][4]
      };
      if (pin !== undefined) {
        const stored = String(data[i][2] || '');
        socio.pin_ok = stored === '' ? false : (stored === pin || stored === Utilities.computeDigest(...));
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