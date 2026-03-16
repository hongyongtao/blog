<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:atom="http://www.w3.org/2005/Atom">

  <xsl:output method="html" encoding="UTF-8" indent="yes" />

  <xsl:template match="/">
    <html>
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>
          <xsl:value-of select="/atom:feed/atom:title" />
          <xsl:text> - Atom</xsl:text>
        </title>
        <style>
          :root { color-scheme: light dark; }
          body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "PingFang SC", "Microsoft YaHei", Arial, sans-serif; margin: 0; padding: 24px; line-height: 1.6; }
          .wrap { max-width: 980px; margin: 0 auto; }
          header { margin-bottom: 18px; }
          h1 { font-size: 22px; margin: 0 0 6px; }
          .meta { opacity: 0.75; font-size: 13px; }
          .meta a { color: inherit; }
          ul { list-style: none; padding: 0; margin: 18px 0 0; }
          li { padding: 14px 12px; border: 1px solid rgba(127,127,127,.25); border-radius: 10px; margin-bottom: 12px; }
          .title { font-size: 16px; font-weight: 600; text-decoration: none; }
          .title:hover { text-decoration: underline; }
          .desc { margin-top: 8px; opacity: .9; font-size: 14px; }
          .footer { margin-top: 22px; font-size: 12px; opacity: .7; }
          code { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace; font-size: 0.95em; }
        </style>
      </head>
      <body>
        <div class="wrap">
          <header>
            <h1><xsl:value-of select="/atom:feed/atom:title" /></h1>
            <div class="meta">
              <span>更新：</span><code><xsl:value-of select="/atom:feed/atom:updated" /></code>
              <xsl:text> · </xsl:text>
              <a>
                <xsl:attribute name="href"><xsl:value-of select="/atom:feed/atom:link[not(@rel) or @rel='alternate'][1]/@href" /></xsl:attribute>
                主页
              </a>
              <xsl:text> · </xsl:text>
              <a>
                <xsl:attribute name="href"><xsl:value-of select="/atom:feed/atom:link[@rel='self'][1]/@href" /></xsl:attribute>
                订阅地址（Atom）
              </a>
            </div>
          </header>

          <ul>
            <xsl:for-each select="/atom:feed/atom:entry">
              <li>
                <a class="title">
                  <xsl:attribute name="href"><xsl:value-of select="atom:link[1]/@href" /></xsl:attribute>
                  <xsl:value-of select="atom:title" />
                </a>
                <div class="meta">
                  <span>发布时间：</span><code><xsl:value-of select="atom:published" /></code>
                  <xsl:text> · </xsl:text>
                  <span>更新时间：</span><code><xsl:value-of select="atom:updated" /></code>
                </div>
                <xsl:if test="atom:summary">
                  <div class="desc">
                    <xsl:value-of select="atom:summary" disable-output-escaping="yes" />
                  </div>
                </xsl:if>
              </li>
            </xsl:for-each>
          </ul>

          <div class="footer">
            <div>你看到的是 <code>atom.xml</code> 的可读视图；RSS/Atom 阅读器依然可以正常订阅。</div>
          </div>
        </div>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>

