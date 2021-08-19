module.exports = ({ router }) => {
  router.get('/', (ctx, next) => { ctx.body = 'Hello Viral World!'; });
};