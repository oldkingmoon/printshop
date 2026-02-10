import "./globals.css";

export const metadata = {
  title: "PrintShop - 智能印刷报价系统",
  description: "上传设计稿，AI自动识别并匹配印刷产品",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="zh">
      <body>{children}</body>
    </html>
  );
}
