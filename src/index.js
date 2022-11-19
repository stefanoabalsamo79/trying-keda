const express = require('express')
const promMid = require('express-prometheus-middleware')
const app = express()

const PORT = process.env.PORT || 3000

app.use(promMid({
  metricsPath: '/metrics',
  collectDefaultMetrics: true,
  requestCountBuckets: [200],
}))

app.get('/', (req, res) => {
  console.log('GET /')
  res.json({ message: 'All good so far' })
})

app.listen(PORT, () => {
  console.log(`Example api is listening on ${PORT}`)
})