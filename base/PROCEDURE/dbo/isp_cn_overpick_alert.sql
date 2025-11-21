SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_CN_OverPick_Alert                               */
/* Creation Date:                                                       */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: - Email alert when PickDetail Qty > OrderDetail             */
/*                                                                      */
/* Called By:  Scheduler job                                            */
/*                                                                      */
/* PVCS Version:                                                        */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Modifications:                                                       */
/* Date         Author    Ver.  Purposes                                */
/* 14-Mar-2017  Leong     1.0   IN00289179 - For monitor only.          */
/*                                         - rdt_579ExtSort01           */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_CN_OverPick_Alert]
   @c_StorerKey NVARCHAR(15)
 , @b_debug INT = 0
AS
   SET NOCOUNT ON
   SET ANSI_NULLS ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_ExecStatements NVARCHAR(MAX)
         , @c_ExecArguments  NVARCHAR(MAX)
         , @c_DBName         NVARCHAR(30)
         , @c_ListName       NVARCHAR(30)
         , @c_ConfigKey      NVARCHAR(30)
         , @c_Recipients     NVARCHAR(255)
         , @c_EmailSubject   NVARCHAR(255)
         , @tableHTML        NVARCHAR(MAX)

   SET @c_ConfigKey = 'PICKQTY'
   SET @c_ListName  = 'VALIDATE'
   SET @c_DBName    = 'CNDTSITF'

   SET @c_EmailSubject = '[ERROR] CN ' + @c_StorerKey + ' PickDetail Qty > OrderDetail Qty: ' + @@servername

   SET @c_ExecStatements = ''
   SET @c_ExecArguments = ''
   SET @c_ExecStatements = N'SELECT @c_Recipients = ISNULL(RTRIM(Long),'''') ' -- Retrieve Email
                           + 'FROM ' + @c_DBName + '.dbo.CodeLkUp WITH (NOLOCK) '
                           + 'WHERE ListName = ''' + ISNULL(RTRIM(@c_ListName),'') + ''' '
                           + 'AND Code = ''' + ISNULL(RTRIM(@c_ConfigKey),'') + ''' '
                           + 'AND StorerKey = ''' + ISNULL(RTRIM(@c_StorerKey),'') + ''' '

   SET @c_ExecArguments = N'@c_Recipients NVARCHAR(255) OUTPUT'

   EXEC sp_ExecuteSql @c_ExecStatements
                    , @c_ExecArguments
                    , @c_Recipients OUTPUT

   IF ISNULL(OBJECT_ID('tempdb..#OVERPICK'),'') <> ''
   BEGIN
      DROP TABLE #OVERPICK
   END

   IF ISNULL(OBJECT_ID('tempdb..#ORD'),'') <> ''
   BEGIN
      DROP TABLE #ORD
   END

   CREATE TABLE #OVERPICK (
        OrderKey     NVARCHAR(10) NULL
      , Status       NVARCHAR(10) NULL
      , Sku          NVARCHAR(20) NULL
      , PickQty      INT NULL
      , OpenQty      INT NULL
      , QtyAllocated INT NULL
      , QtyPicked    INT NULL
      )

   CREATE TABLE #ORD (
      OrderKey NVARCHAR(10) NULL
      )

   IF @c_StorerKey = 'CONVERSE'
   BEGIN
      INSERT INTO #ORD (OrderKey)
      SELECT DISTINCT OrderKey
      FROM PickDetail WITH (NOLOCK)
      WHERE StorerKey = @c_StorerKey
      AND CaseId = 'SORTED' -- RDT_Fn579
      AND Status < '5'
      AND DATEDIFF(MINUTE, EditDate, GETDATE()) > 3
   END
   ELSE
   BEGIN
      INSERT INTO #ORD (OrderKey)
      SELECT DISTINCT OrderKey
      FROM Orders WITH (NOLOCK)
      WHERE StorerKey = @c_StorerKey
      AND Status BETWEEN '1' AND '4'
      AND ISNULL(RTRIM(DocType),'') <> 'E' -- Normal Orders
      AND DATEDIFF(MINUTE, EditDate, GETDATE()) > 3
   END

   INSERT INTO #OVERPICK (OrderKey, Status, Sku, PickQty, OpenQty, QtyAllocated, QtyPicked)
   SELECT P.OrderKey, P.Status, P.Sku, SUM(P.Qty) AS PickQty
        , O.OpenQty, O.QtyAllocated, O.QtyPicked
   FROM PickDetail P WITH (NOLOCK)
   JOIN (
         SELECT OrderKey, Sku, SUM(OpenQty) AS OpenQty, SUM(QtyAllocated) AS QtyAllocated, SUM(QtyPicked) AS QtyPicked
         FROM OrderDetail WITH (NOLOCK)
         WHERE StorerKey = @c_StorerKey AND OrderKey IN ( SELECT OrderKey FROM #ORD WITH (NOLOCK) )
         GROUP BY OrderKey, Sku
         ) AS O
   ON (P.OrderKey = O.OrderKey AND P.Sku = O.Sku)
   WHERE P.StorerKey = @c_StorerKey AND P.OrderKey IN ( SELECT OrderKey FROM #ORD WITH (NOLOCK) )
   GROUP BY P.OrderKey, P.Status, P.Sku
          , O.OpenQty, O.QtyAllocated, O.QtyPicked
   HAVING SUM(P.Qty) > O.OpenQty
   ORDER BY P.OrderKey, P.Status, P.Sku

   IF @b_debug = '1'
   BEGIN
      SELECT @c_StorerKey '@c_StorerKey'
      SELECT @c_Recipients '@c_Recipients'
      SELECT * FROM #OVERPICK
   END

   IF EXISTS (SELECT 1 FROM #OVERPICK) AND ISNULL(RTRIM(@c_Recipients),'') <> ''
   BEGIN
      SET @tableHTML =
          N'<STYLE TYPE="text/css"> ' + CHAR(13) +
          N'<!--' + CHAR(13) +
          N'TR{font-family: Arial; font-size: 10pt;}' + CHAR(13) +
          N'TD{font-family: Arial; font-size: 9pt;}' + CHAR(13) +
          N'H3{font-family: Arial; font-size: 12pt;}' + CHAR(13) +
          N'BODY{font-family: Arial; font-size: 9pt;}' + CHAR(13) +
          N'--->' + CHAR(13) +
          N'</STYLE>' + CHAR(13) +
          N'<H3>' + @c_EmailSubject + '</H3>' +
          N'<BODY><P ALIGN="LEFT">Please check the following Orders:</P></BODY>' +
          N'<TABLE BORDER="1" CELLSPACING="0" CELLPADDING="3">' +
          N'<TR BGCOLOR=#3BB9FF><TH>OrderKey</TH><TH>PickDetail<BR>Status</TH><TH>Sku</TH>' +
          N'<TH>PickDetail<BR>Qty</TH><TH>OrderDetail<BR>OpenQty</TH><TH>OrderDetail<BR>QtyAllocated</TH><TH>OrderDetail<BR>QtyPicked</TH></TR>' +
          CAST ( ( SELECT TD = A.OrderKey, '',
                          'TD/@align' = 'center',
                          TD = A.Status, '',
                          TD = A.Sku, '',
                          TD = A.PickQty, '',
                          TD = A.OpenQty, '',
                          TD = A.QtyAllocated, '',
                          TD = A.QtyPicked, ''
                   FROM #OVERPICK A WITH (NOLOCK)
                   ORDER BY A.OrderKey, A.Sku
            FOR XML PATH('TR'), TYPE
          ) AS NVARCHAR(MAX) ) +
          N'</TABLE>' ;

      EXEC msdb.dbo.sp_send_dbmail
           @recipients  = @c_Recipients,
           @subject     = @c_EmailSubject,
           @importance  = 'High',
           @body        = @tableHTML,
           @body_format = 'HTML';
   END

GO