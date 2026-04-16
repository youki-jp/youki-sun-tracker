import { Hono } from 'hono'
import axios from 'axios'

const app = new Hono()
const sunriseUrl = 'https://api.sunrisesunset.io/json'
const port = Number(process.env.PORT ?? 3000)
const hostname = process.env.HOST ?? '0.0.0.0'

app.get('/', (c) => {
  return c.text('Hello Youki!')
})

app.get('/sun', async (c) => {
  const lat = c.req.query('lat')
  const lng = c.req.query('lng')

  console.log('[GET /sun] Incoming request', {
    lat,
    lng,
    userAgent: c.req.header('user-agent') ?? 'unknown'
  })

  if (!lat || !lng) {
    console.warn('[GET /sun] Missing lat/lng query parameters')
    return c.json({ error: 'lat and lng are required query parameters.' }, 400)
  }

  const requestUrl = `${sunriseUrl}?lat=${lat}&lng=${lng}&formatted=0`

  console.log('[GET /sun] Upstream request URL', requestUrl)

  try {
    const response = await axios.get(requestUrl)
    console.log('[GET /sun] Upstream status', response.status)
    console.log('[GET /sun] Upstream response body', JSON.stringify(response.data, null, 2))
    return c.json(response.data)
  } catch (error) {
    console.error('Sun API request failed', error)
    return c.json({ error: 'Unable to fetch sunrise and sunset data.' }, 502)
  }
})

export default {
  hostname,
  port,
  fetch: app.fetch
}
