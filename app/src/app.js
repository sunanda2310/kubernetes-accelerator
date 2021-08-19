const Koa = require('koa');
const Router = require('koa-router');
const logger = require('koa-logger');

const app = new Koa();

// log everything to the console
app.use(logger());

// global error handling
app.use(async (ctx, next) => {
  try {
    await next();
  } catch (err) {
    console.log(err);
    ctx.status = err.status || 500;
    ctx.body = err.message;
    ctx.app.emit('error', err, ctx);
  }
});

// Setup basic routes
const router = new Router();
require('./routes/basic')({ router });

app.use(router.routes());
app.use(router.allowedMethods());

// Setup marvel routes
const marvelRouter = new Router({
  prefix: '/marvel'
});
require('./routes/marvel')({ marvelRouter });

app.use(marvelRouter.routes());
app.use(marvelRouter.allowedMethods());

// Setup NASA routes
const nasaRouter = new Router({
  prefix: '/nasa'
});
require('./routes/nasa')({ nasaRouter });

app.use(nasaRouter.routes());
app.use(nasaRouter.allowedMethods());

const port = process.env.PORT || 3000;
const server = app.listen(port);

module.exports = server;