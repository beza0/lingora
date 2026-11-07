// pnpm content:validate — yapısal doğrulama ve rapor. Hata varsa çıkış kodu 1.
import { printIssues, run } from "./common.ts";

const partial = process.argv.includes("--partial");
const { report } = run(!partial);
printIssues(report.issues);
console.log("\nToplamlar:", report.totals);
console.log("Benzersiz sözcük/ifade sayısı (alanlar arası ortaklar tek sayılır):", report.uniqueWords);
console.log("Paket başına zorluk dağılımı (zorluk: adet):");
for (const [p, d] of Object.entries(report.difficultyByPack)) console.log("  " + p.padEnd(28), JSON.stringify(d));
const errors = report.issues.filter((i) => i.level === "error").length;
const warnings = report.issues.length - errors;
console.log(`\n${errors} hata, ${warnings} uyarı`);
process.exit(errors ? 1 : 0);
