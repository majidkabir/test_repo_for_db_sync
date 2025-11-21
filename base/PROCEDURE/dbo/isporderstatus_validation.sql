SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: ispOrderStatus_Validation                           */
/*                                                                      */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: - Verify status between PickDetail vs Orders.               */
/*                                                                      */
/* Called By:  Scheduler job                                            */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Modifications:                                                       */
/* Date         Author    Ver.  Purposes                                */
/* 24-Mov-2015  Leong     1.0   SOS# 356563 created.                    */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispOrderStatus_Validation]
   @c_StorerKey NVARCHAR(15)
 , @c_itfDBName NVARCHAR(30)
 , @b_debug     INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_OrderKey       NVARCHAR(10)
         , @c_PDStatus       NVARCHAR(10)
         , @c_ODStatus       NVARCHAR(10)
         , @c_ListName       NVARCHAR(30)
         , @c_ConfigKey      NVARCHAR(30)
         , @c_EmailSubject   NVARCHAR(255)
         , @c_Recipients     NVARCHAR(255)
         , @tableHTML        NVARCHAR(4000)
         , @c_ExecStatements NVARCHAR(4000)
         , @c_ExecArguments  NVARCHAR(4000)

   SET @c_ListName  = 'VALIDATE'
   SET @c_ConfigKey = 'ORDSTATUS'

   SET @c_EmailSubject = ISNULL(RTRIM(@c_StorerKey),'') + ' Orders Status Error: ' + @@servername

   IF ISNULL(OBJECT_ID('tempdb..#ORD'),'') <> ''
   BEGIN
      DROP TABLE #ORD
   END

   CREATE TABLE #ORD ( OrderKey  NVARCHAR(10) NULL
                     , ODStatus  NVARCHAR(10) NULL
                     , PDStatus  NVARCHAR(10) NULL
                     , StorerKey NVARCHAR(15) NULL
                     , AddDate   DATETIME DEFAULT GETDATE() )

   SET @c_ExecStatements = ''
   SET @c_ExecArguments  = ''
   SET @c_Recipients     = ''
   SET @c_ExecStatements = N'SELECT @c_Recipients = ISNULL(RTRIM(Long),'''') ' -- Retrieve Email
                           + 'FROM ' + ISNULL(RTRIM(@c_itfDBName),'') + '.dbo.CodeLkUp WITH (NOLOCK) '
                           + 'WHERE ListName = ''' + ISNULL(RTRIM(@c_ListName),'') + ''' '
                           + 'AND Code = ''' + ISNULL(RTRIM(@c_ConfigKey),'') + ''' '
                           + 'AND StorerKey = ''' + ISNULL(RTRIM(@c_StorerKey),'') + ''' '

   SET @c_ExecArguments = N'@c_Recipients NVARCHAR(255) OUTPUT'

   EXEC sp_ExecuteSql @c_ExecStatements
                    , @c_ExecArguments
                    , @c_Recipients OUTPUT

   IF @b_debug = 1
   BEGIN
      SELECT @c_Recipients '@c_Recipients'
   END

   DECLARE CUR_Orders CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderKey, MIN(Status) Status
      FROM PickDetail WITH (NOLOCK)
      WHERE StorerKey = ISNULL(RTRIM(@c_StorerKey),'')
      AND Status < '9'
      AND ISNULL(RTRIM(ShipFlag),'') <> 'Y'
      AND DATEDIFF(MINUTE, EditDate, GETDATE()) <= 30
      AND DATEDIFF(SECOND, EditDate, GETDATE()) >= 5
      GROUP BY OrderKey
      ORDER BY OrderKey

   OPEN CUR_Orders
   FETCH NEXT FROM CUR_Orders INTO @c_OrderKey, @c_PDStatus
   WHILE @@FETCH_STATUS <> -1
   BEGIN

   IF @c_PDStatus = '5'
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @c_OrderKey
                     AND Status <> @c_PDStatus) -- Make sure all lines are picked
      BEGIN
         SET @c_ODStatus = ''
         SELECT @c_ODStatus = Status
         FROM Orders WITH (NOLOCK)
         WHERE OrderKey = @c_OrderKey
           AND StorerKey = ISNULL(RTRIM(@c_StorerKey),'')

         IF @b_debug = 1
         BEGIN
            SELECT @c_ODStatus '@c_ODStatus', @c_StorerKey '@c_StorerKey', @c_OrderKey '@c_OrderKey'
         END

         IF @c_ODStatus <> @c_PDStatus
         BEGIN
            INSERT INTO #ORD (OrderKey, ODStatus, PDStatus, StorerKey)
            VALUES (@c_OrderKey, @c_ODStatus, @c_PDStatus, @c_StorerKey)

            UPDATE Orders WITH (ROWLOCK)
            SET Status     = @c_PDStatus
              , TrafficCop = NULL
            WHERE OrderKey = @c_OrderKey

            IF EXISTS ( SELECT 1 FROM StorerConfig WITH (NOLOCK) WHERE StorerKey = @c_StorerKey
                        AND ConfigKey = 'PICKCFMLOG' AND ISNULL(RTRIM(SValue),'') = '1' )
            BEGIN
               EXEC dbo.ispGenTransmitLog3 'PICKCFMLOG', @c_OrderKey, '', @c_StorerKey, '', '','',''
            END
         END
      END -- NOT EXISTS
   END

      FETCH NEXT FROM CUR_Orders INTO @c_OrderKey, @c_PDStatus
   END
   CLOSE CUR_Orders
   DEALLOCATE CUR_Orders

   IF @b_debug = 1
   BEGIN
      SELECT * FROM #ORD
   END

   IF EXISTS (SELECT 1 FROM #ORD) AND ISNULL(RTRIM(@c_Recipients),'') <> ''
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
          N'<TR BGCOLOR=#3BB9FF><TH>StorerKey</TH><TH>OrderKey</TH><TH>Orders<BR>Status</TH><TH>PickDetail<BR>Status</TH><TH>Date</TH></TR>' +
          CAST ( ( SELECT TD = A.StorerKey, '',
                          TD = A.OrderKey, '',
                          TD = A.ODStatus, '',
                          TD = A.PDStatus, '',
                          TD = A.AddDate, ''
                   FROM #ORD A WITH (NOLOCK)
                   ORDER BY A.AddDate
            FOR XML PATH('TR'), TYPE
          ) AS NVARCHAR(MAX) ) +
          N'</TABLE>' ;

      EXEC msdb.dbo.sp_send_dbmail
           @recipients  = @c_Recipients,
           @subject     = @c_EmailSubject,
           @body        = @tableHTML,
           @body_format = 'HTML';
   END
END -- Procedure

GO