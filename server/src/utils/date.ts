export function getYearWeek(date: Date = new Date()) {
  const target = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  const dayNum = (target.getUTCDay() + 6) % 7; // Monday=0
  target.setUTCDate(target.getUTCDate() - dayNum + 3);
  const firstThursday = new Date(Date.UTC(target.getUTCFullYear(), 0, 4));
  const diff = target.getTime() - firstThursday.getTime();
  const week = 1 + Math.round((diff / 86400000 - 3) / 7);
  const year = target.getUTCFullYear();
  return {
    year,
    week,
    weekKey: `W${String(week).padStart(2, '0')}`,
  };
}
