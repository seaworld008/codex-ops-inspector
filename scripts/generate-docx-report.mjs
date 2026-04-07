import fs from "node:fs";
import path from "node:path";
import {
  AlignmentType,
  BorderStyle,
  Document,
  HeadingLevel,
  Packer,
  Paragraph,
  Table,
  TableCell,
  TableRow,
  TextRun,
  WidthType
} from "docx";

const inputPath = process.argv[2] || "reports/ubuntu-inspection-report.md";
const outputPath = process.argv[3] || "reports/ubuntu-inspection-report.docx";

if (!fs.existsSync(inputPath)) {
  console.error(`Input file not found: ${inputPath}`);
  process.exit(1);
}

const markdown = fs.readFileSync(inputPath, "utf8");
const lines = markdown.split(/\r?\n/);

const border = { style: BorderStyle.SINGLE, size: 1, color: "D9D9D9" };
const children = [];

children.push(
  new Paragraph({
    heading: HeadingLevel.TITLE,
    alignment: AlignmentType.CENTER,
    children: [new TextRun({ text: "Ubuntu 巡检报告", bold: true, size: 34 })]
  })
);

children.push(
  new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { after: 300 },
    children: [new TextRun({ text: `来源文件: ${path.basename(inputPath)}`, italics: true, size: 20 })]
  })
);

for (const line of lines) {
  if (!line.trim()) {
    children.push(new Paragraph({ text: "" }));
    continue;
  }

  if (line.startsWith("# ")) {
    children.push(new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun(line.slice(2))] }));
    continue;
  }

  if (line.startsWith("## ")) {
    children.push(new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun(line.slice(3))] }));
    continue;
  }

  if (line.startsWith("### ")) {
    children.push(new Paragraph({ heading: HeadingLevel.HEADING_3, children: [new TextRun(line.slice(4))] }));
    continue;
  }

  if (line.startsWith("- ")) {
    children.push(
      new Paragraph({
        bullet: { level: 0 },
        children: [new TextRun(line.slice(2))]
      })
    );
    continue;
  }

  if (line.includes("|") && !line.startsWith("```")) {
    const cells = line
      .split("|")
      .map((item) => item.trim())
      .filter(Boolean);

    if (cells.length > 1 && !cells.every((cell) => /^-+$/.test(cell.replace(/:/g, "")))) {
      children.push(
        new Table({
          width: { size: 9360, type: WidthType.DXA },
          columnWidths: new Array(cells.length).fill(Math.floor(9360 / cells.length)),
          rows: [
            new TableRow({
              children: cells.map(
                (cell) =>
                  new TableCell({
                    width: { size: Math.floor(9360 / cells.length), type: WidthType.DXA },
                    borders: { top: border, bottom: border, left: border, right: border },
                    children: [new Paragraph(cell)]
                  })
              )
            })
          ]
        })
      );
      continue;
    }
  }

  children.push(
    new Paragraph({
      children: [new TextRun({ text: line, size: 22 })],
      spacing: { after: 120 }
    })
  );
}

const doc = new Document({
  styles: {
    default: {
      document: {
        run: {
          font: "Arial",
          size: 22
        }
      }
    }
  },
  sections: [
    {
      properties: {
        page: {
          size: { width: 12240, height: 15840 },
          margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 }
        }
      },
      children
    }
  ]
});

const buffer = await Packer.toBuffer(doc);
fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, buffer);
console.log(`Wrote ${outputPath}`);
