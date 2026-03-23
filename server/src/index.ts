import { Hono } from 'hono' import axios from 'axios'

const app = new Hono()
const sunriseUrl = "https://api.sunrise-sunset.org"
const lat = 35.6471805576124
const lng = 139.7004394508032

app.get('/', (c) => {
  return c.text('Hello Youki!')
})

app.get('/sun/', async (c: any) => {
  console.log("Got a request!")
  const requestUrl = `${sunriseUrl}/json?lat=${lat}&lng=${lng}`
  try {
    const response = await axios.get(requestUrl).then((res) => {
      return res.data
    }).catch(err => {err})
    console.log(response)
    return c.json(response)
  }
  catch(err) {
    return err
  }
})

export default app
