import { remove } from 'fs-extra/esm'
import { Instance as ParseTorrent } from 'parse-torrent'
import { join } from 'path'
import { sha256 } from '@peertube/peertube-node-utils'
import { ResultList } from '@peertube/peertube-models'
import { CONFIG } from '../initializers/config.js'
import { randomBytesPromise } from './core-utils.js'
import { logger } from './logger.js'
//-------------------------------------------------------------------------------------------------
// VBML
import express from 'express'
import { readFileSync } from 'fs'
import { HttpStatusCode } from '@peertube/peertube-models'
//-------------------------------------------------------------------------------------------------

function deleteFileAndCatch (path: string) {
  remove(path)
    .catch(err => logger.error('Cannot delete the file %s asynchronously.', path, { err }))
}

async function generateRandomString (size: number) {
  const raw = await randomBytesPromise(size)

  return raw.toString('hex')
}

interface FormattableToJSON<U, V> {
  toFormattedJSON (args?: U): V
}

function getFormattedObjects<U, V, T extends FormattableToJSON<U, V>> (objects: T[], objectsTotal: number, formattedArg?: U) {
  const formattedObjects = objects.map(o => o.toFormattedJSON(formattedArg))

  return {
    total: objectsTotal,
    data: formattedObjects
  } as ResultList<V>
}

function generateVideoImportTmpPath (target: string | ParseTorrent, extension = '.mp4') {
  const id = typeof target === 'string'
    ? target
    : target.infoHash

  const hash = sha256(id)
  return join(CONFIG.STORAGE.TMP_DIR, `${hash}-import${extension}`)
}

function getSecureTorrentName (originalName: string) {
  return sha256(originalName) + '.torrent'
}

/**
 * From a filename like "ede4cba5-742b-46fa-a388-9a6eb3a3aeb3.mp4", returns
 * only the "ede4cba5-742b-46fa-a388-9a6eb3a3aeb3" part. If the filename does
 * not contain a UUID, returns null.
 */
function getUUIDFromFilename (filename: string) {
  const regex = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/
  const result = filename.match(regex)

  if (!result || Array.isArray(result) === false) return null

  return result[0]
}

//-------------------------------------------------------------------------------------------------
// VBML
//-------------------------------------------------------------------------------------------------

function checkVbmlType(path: string, res: express.Response )
{
  let type = getVbmlValue(readFileSync(path).toString('utf-8'), "type")

  if (type != "track" && type != "hub" && type != "channel" && type != "interactive")
  {
    res.fail(
    {
      status: HttpStatusCode.FORBIDDEN_403,
      message: 'VBML type should be track, hub, channel or interactive'
    })

    return false
  }
  else return true;
}

function getVbmlValue(text: string, key: string)
{
  let indexA = text.indexOf(key + ": ");

  if (indexA == -1) return "";

  indexA += key.length + 2;

  var indexB = text.indexOf('\n', indexA);

  if (indexB == -1) return "";

  return text.substring(indexA, indexB).trim();
}

//-------------------------------------------------------------------------------------------------

// ---------------------------------------------------------------------------

export {
  deleteFileAndCatch,
  generateRandomString,
  getFormattedObjects,
  getSecureTorrentName,
  generateVideoImportTmpPath,
  getUUIDFromFilename,
  //-----------------------------------------------------------------------------------------------
  // VBML
  checkVbmlType,
  getVbmlValue
}
