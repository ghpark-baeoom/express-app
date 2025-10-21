module.exports = {
  apps: [
    {
      name: "express-app", // PM2 프로세스 이름
      script: "dist/server.js", // 실행할 메인 파일 경로
      instances: 2, // 실행할 인스턴스 개수 (무중단 배포를 위해 최소 2개 이상)
      exec_mode: "cluster", // 실행 모드 (cluster: 여러 인스턴스, fork: 단일 인스턴스)
      autorestart: true, // 프로세스 종료 시 자동 재시작
      watch: false, // 파일 변경 감지 후 자동 재시작 (개발: true, 프로덕션: false)
      max_memory_restart: "1G", // 메모리 사용량이 1GB 초과 시 자동 재시작
      node_args: `--env-file=${process.env.HOME}/express-app/.env`, // Node.js 실행 시 전달할 추가 인자 (Ubuntu: /home/ubuntu, AL2023: /home/ec2-user)
      // env: {
      //   NODE_ENV: 'production', // 환경 변수 직접 설정 (현재는 .env 파일 사용)
      //   PORT: 80
      // },
      kill_timeout: 5000, // 종료 시 워커에 줄 최대 정리 시간(ms)
      wait_ready: true, // 앱이 준비될 때까지 대기 (listen 완료 확인) = app이 process.send('ready') 보낼 때까지 대기
      listen_timeout: 10000, // 새 워커가 listen할 때까지 최대 대기(ms)
      shutdown_with_message: true, // 🔥 pm2가 shutdown 메시지 전송(for pm2 gracefulReload)
    },
  ],
};
