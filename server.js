const http = require('http');
const { Server } = require('socket.io');

const server = http.createServer();
const io = new Server(server, {
  cors: { origin: "*" }
});

io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  socket.on('admin_flash', () => {
    console.log('FLASH COMMAND SENT');
    io.emit('flash_trigger'); // Рассылаем всем гостям
  });
});

server.listen(process.env.PORT || 3000);
