// =========================== // 개포히치하이커스 — 크론 작업 정의 //
=========================== // openclaw.json의 cron 섹션에 병합하여 사용 // 각
에이전트의 workspace에 cron.json을 두는 방식이 아닌, // AGENTS.md 프롬프트에서
크론 작업 지침을 포함하는 방식 권장. // // OpenClaw에서 크론은 config에서
활성화하고, // 에이전트별 크론 작업은 AGENTS.md의 지침으로 수행됨. // // 참고:
https://docs.openclaw.ai/automation/cron-jobs // // ─── PM_Agent 크론 ─── //
schedule: "0 9 * * 1-5" (평일 09:00) // task: 전체 에이전트 상태 점검. 진행 중인
작업 요약 후 #pm-strategy에 일일 리포트 올려. // // schedule: "0 18 * * 1-5"
(평일 18:00)\
// task: 오늘 완료된 작업, 미완료 작업, 내일 예정을 요약하여 #pm-strategy에 마감
보고 올려. // // ─── QA_Agent 크론 ─── // schedule: "*/30 9-18 * * 1-5" (업무
시간 30분마다) // task: 라이브 서비스 헬스체크. 이상 있으면 #alerts에 알림. //
// ─── Research_Agent 크론 ─── // schedule: "0 10 * * 1" (매주 월요일 10:00) //
task: 주간 그로스 리포트 작성. 유입/전환/매출 지표 분석 후 #collab-bridge에
공유. // // schedule: "0 15 * * 1-5" (평일 15:00) // task: 고객 리뷰 및 경쟁사
동향 모니터링. 이슈 있으면 @PM_Agent에 보고.
