const request = require('superagent');
const md5 = require('md5');

const publicKey = process.env.MARVEL_PUBLIC_KEY || '<MARVEL_PUBLIC_KEY_404>';
const privateKey = process.env.MARVEL_PRIVATE_KEY || '<MARVEL_PRIVATE_KEY_404>';

const url = 'http://gateway.marvel.com/v1/public/characters';
const alphabet = 'abcdefghijklmnopqrstuvwxyz';

module.exports = ({ marvelRouter }) => {
  marvelRouter.get('/', (ctx, next) => { ctx.body = 'Superhero landing!'; });

  marvelRouter.get('/random', async (ctx, next) => {
    const timestamp = Date.now() + '';
    const hash = md5(timestamp + privateKey + publicKey);

    await request.get(url)
      .query({
        nameStartsWith: alphabet[Math.floor(Math.random() * alphabet.length)],
        ts: timestamp,
        apikey: publicKey,
        hash: hash
      })
      .then(res => {
        ctx.body = res.body;
      })
      .catch(err => {
        throw err;
      });
  });
};