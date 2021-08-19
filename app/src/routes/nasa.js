const request = require('superagent');

const apiKey = 'DEMO_KEY';
const url = 'https://api.nasa.gov/planetary/apod';

module.exports = ({ nasaRouter }) => {
  nasaRouter.get('/', async (ctx, next) => {
    const metadata = {};
    await request.get(url)
      .query({
        api_key: apiKey
      })
      .then(res => {
        metadata['url'] = res.body.url;
      })
      .catch(err => {
        throw err;
      });
    await request.get(metadata.url)
      .then(res => {
        ctx.set('Content-Type', res.headers['content-type']);
        ctx.set('Content-Length', res.headers['content-length']);
        ctx.body = res.body;
      })
      .catch(err => {
        throw err;
      });
  });
};