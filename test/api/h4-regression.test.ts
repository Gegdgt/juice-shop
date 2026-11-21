/*
 * Hito 4 · Pruebas de regresión de las correcciones del Equipo azul.
 * Cada bloque repite el PoC del Equipo rojo (Hito 2) contra la API y espera
 * que el ataque falle por el código, más un caso legítimo que tiene que seguir
 * funcionando. Con el código vulnerable estas pruebas fallan.
 *
 *   node --import ./test/api/helpers/test-env.mjs --import tsx --test --test-force-exit test/api/h4-regression.test.ts
 */

import { describe, it, before } from 'node:test'
import assert from 'node:assert/strict'
import request from 'supertest'
import type { Express } from 'express'
import { createTestApp } from './helpers/setup'
import { login } from './helpers/auth'

let app: Express
const json = { 'content-type': 'application/json' }

before(async () => {
  const result = await createTestApp()
  app = result.app
}, { timeout: 60000 })

void describe('H4 Corrección 1 · PoC-01 SQLi en el login (CWE-89)', () => {
  void it('PoC-01: email "\' OR 1=1--" no inicia sesión', async () => {
    const res = await request(app).post('/rest/user/login').set(json)
      .send({ email: '\' OR 1=1--', password: 'x' })
    assert.equal(res.status, 401)
    assert.equal(res.body?.authentication, undefined)
  })

  void it('email conocido con comentario SQL no se salta la contraseña', async () => {
    const res = await request(app).post('/rest/user/login').set(json)
      .send({ email: 'admin@juice-sh.op\'--', password: 'x' })
    assert.equal(res.status, 401)
  })

  void it('UNION SELECT en el email no fabrica un usuario', async () => {
    const res = await request(app).post('/rest/user/login').set(json)
      .send({ email: '\' UNION SELECT * FROM Users--', password: 'x' })
    assert.equal(res.status, 401)
  })

  void it('email que no es texto se rechaza con 401, sin error 500', async () => {
    const res = await request(app).post('/rest/user/login').set(json)
      .send({ email: { $ne: '' }, password: ['x'] })
    assert.equal(res.status, 401)
  })

  void it('login legítimo sigue funcionando', async () => {
    const res = await request(app).post('/rest/user/login').set(json)
      .send({ email: 'jim@juice-sh.op', password: 'ncc-1701' })
    assert.equal(res.status, 200)
    assert.equal(typeof res.body.authentication.token, 'string')
  })

  void it('cuenta con 2FA sigue pidiendo el segundo factor', async () => {
    const res = await request(app).post('/rest/user/login').set(json)
      .send({ email: 'wurstbrot@juice-sh.op', password: 'EinBelegtesBrotMitSchinkenSCHINKEN!' })
    assert.equal(res.status, 401)
    assert.equal(res.body.status, 'totp_token_required')
  })
})

void describe('H4 Corrección 2 · PoC-02 UNION SQLi en la búsqueda (CWE-89)', () => {
  const poc02 = 'qwert\')) UNION SELECT id, email, password, \'4\',\'5\',\'6\',\'7\',\'8\',\'9\',\'10\' FROM Users--'

  void it('PoC-02: el UNION no devuelve correos ni hashes', async () => {
    const res = await request(app).get('/rest/products/search').query({ q: poc02 })
    assert.equal(res.status, 200)
    assert.equal(res.body.data.length, 0)
    assert.ok(!JSON.stringify(res.body).includes('admin@juice-sh.op'))
  })

  void it('comillas y paréntesis no rompen la consulta (sin error SQL 500)', async () => {
    const res = await request(app).get('/rest/products/search').query({ q: '\'))--' })
    assert.equal(res.status, 200)
    assert.equal(res.body.data.length, 0)
  })

  void it('comentar el WHERE no expone productos borrados', async () => {
    const res = await request(app).get('/rest/products/search').query({ q: 'Christmas Super-Surprise-Box (2014 Edition)\'))--' })
    assert.equal(res.status, 200)
    assert.equal(res.body.data.length, 0)
  })

  void it('q repetido (arreglo) se trata como texto, sin error', async () => {
    const res = await request(app).get('/rest/products/search?q=apple&q=banana')
    assert.equal(res.status, 200)
    assert.ok(Array.isArray(res.body.data))
  })

  void it('búsqueda legítima sigue encontrando productos', async () => {
    const res = await request(app).get('/rest/products/search').query({ q: 'apple' })
    assert.equal(res.status, 200)
    assert.ok(res.body.data.length >= 1)
    assert.ok(res.body.data.every((p: { name: string, description: string }) => /apple/i.test(p.name + ' ' + p.description)))
  })
})

void describe('H4 Corrección 3 · PoC-03 IDOR en el carrito (CWE-639)', () => {
  void it('PoC-03: jim no puede leer el carrito 1 (de admin)', async () => {
    const { token } = await login(app, { email: 'jim@juice-sh.op', password: 'ncc-1701' })
    const res = await request(app).get('/rest/basket/1').set({ Authorization: 'Bearer ' + token })
    assert.equal(res.status, 403)
    assert.equal(res.body?.data, undefined)
  })

  void it('jim sí puede leer su propio carrito', async () => {
    const { token, bid } = await login(app, { email: 'jim@juice-sh.op', password: 'ncc-1701' })
    const res = await request(app).get('/rest/basket/' + bid).set({ Authorization: 'Bearer ' + token })
    assert.equal(res.status, 200)
    assert.equal(res.body.data.id, bid)
  })

  void it('un id que no existe no se distingue de uno ajeno', async () => {
    const { token } = await login(app, { email: 'jim@juice-sh.op', password: 'ncc-1701' })
    const res = await request(app).get('/rest/basket/4711').set({ Authorization: 'Bearer ' + token })
    assert.equal(res.status, 403)
  })
})
