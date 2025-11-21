SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: isp_WMSNTPB_STG_Count                               */
/* Creation Date: 08-OCT-2019                                           */
/* Copyright: IDS                                                       */
/* Written by: AlexKeoh                                                 */
/*                                                                      */
/* Purpose: Daily Count - TPB & WMS Staging                             */
/*                                                                      */
/* Called By: SQL Agent                                                 */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Purposes														*/
/* 2019-OCT-08 Alex     Initial - JIRA #TPB-68                          */
/************************************************************************/
CREATE PROC [dbo].[isp_WMSNTPB_STG_Count](
     @b_Debug                 INT            = 0,
     @c_TPBLinkServer         NVARCHAR(30)   = '',
     @d_CountOnDate           DATETIME       = NULL,
     @c_Country               NVARCHAR(5)    = '',
     @c_Recipients            NVARCHAR(1000) = '',
     @c_CustomEmailSubject    NVARCHAR(200)  = ''
)
AS
BEGIN
   SET NOCOUNT                   ON
   SET ANSI_DEFAULTS             OFF 
   SET QUOTED_IDENTIFIER         OFF
   SET CONCAT_NULL_YIELDS_NULL   OFF
   SET ANSI_NULLS                ON
   SET ANSI_WARNINGS             ON

   DECLARE @c_ExecStatement      NVARCHAR(4000) = ''
         , @c_Arguments          NVARCHAR(1000) = ''

   DECLARE @n_WMSSTG_CNT         INT = 0
         , @n_TPBSTG_CNT         INT = 0
         , @c_FilterFromDate     NVARCHAR(25) = ''
         , @c_FilterToDate       NVARCHAR(25) = ''

         , @c_DBID               NVARCHAR(15) = DB_NAME()
         , @c_TwoDigitCC         NVARCHAR(5) = REPLACE(DB_NAME(), 'WMS', '')

         , @c_EmailSubject       NVARCHAR(100) = ''
         , @c_EmailContent       NVARCHAR(2000) = ''
         , @d_FromDate           DATETIME = NULL
         , @d_ToDate             DATETIME = NULL

   SET @d_FromDate = IIF(@d_CountOnDate IS NULL, GETDATE(), @d_CountOnDate)
   SET @d_ToDate = DATEADD(DAY, 1, @d_FromDate)

   SET @c_FilterFromDate = CONVERT(NVARCHAR, @d_FromDate, 23) -- (yyyy-MM-dd)
   SET @c_FilterToDate = CONVERT(NVARCHAR, @d_ToDate, 23) -- (yyyy-MM-dd)

   IF @b_debug = 1
   BEGIN
      PRINT '@c_FilterFromDate=' + @c_FilterFromDate
   END

   --Get Total From TPB
   SET @c_ExecStatement = 'SELECT @n_TPBSTG_CNT = Total '
                        + 'FROM OPENQUERY '
                        + '(' + @c_TPBLinkServer + ','
                        + '''SELECT COUNT(1) AS "Total" FROM APP_TPB_DATA.TPB_STG_BASE '
                        + 'WHERE COUNTRY = ''''' + @c_Country + ''''' '
                        + 'AND INSERT_DATE >= to_date(''''' + @c_FilterFromDate + ''''',''''YYYY-MM-DD'''') ' 
                        + 'AND INSERT_DATE < to_date(''''' + @c_FilterToDate + ''''',''''YYYY-MM-DD'''') ' 
                        + 'AND DBID = ''''' + @c_DBID + ''''' '
                        + ''')'

   SET @c_Arguments = '@n_TPBSTG_CNT INT OUTPUT'

   EXEC sp_executesql @c_ExecStatement, @c_Arguments, @n_TPBSTG_CNT OUTPUT

   SELECT @n_WMSSTG_CNT = COUNT(1)
   FROM dbo.WMS_TPB_BASE B WITH (NOLOCK)
   WHERE Country = @c_Country
   AND INSERT_DATE >= @c_FilterFromDate
   AND INSERT_DATE < @c_FilterToDate
   AND [DBID] = @c_DBID
   AND EXISTS ( SELECT 1 FROM dbo.TPB_Data_Batch BATCH WITH (NOLOCK)
      WHERE BATCH.Batch_Key = B.BatchNo AND Batch.[Status] = '0' )

   IF @b_debug = 1
   BEGIN
      PRINT '@n_WMSSTG_CNT=' + CONVERT(NVARCHAR, @n_WMSSTG_CNT)
      PRINT '@n_TPBSTG_CNT=' + CONVERT(NVARCHAR, @n_TPBSTG_CNT)
   END

   IF @n_WMSSTG_CNT <> @n_TPBSTG_CNT
   BEGIN
      SET @c_EmailSubject = 'Alert Notification - Daily Count For TPB & WMS STG (' + @c_TwoDigitCC + ')' + @c_CustomEmailSubject
      SET @c_EmailContent = 'Hi, <br><br> This is an auto generated email notification. <br><br>Daily Count (<b>' + @c_FilterFromDate + '</b>) - Not Tally!<br>'
                          + '<b>WMS STAGING (WMS_TPB_BASE) - <span' 
                          + CASE WHEN @n_TPBSTG_CNT > @n_WMSSTG_CNT THEN ' style="color:red;" ' ELSE ''END
                          + '>' 
                          + CONVERT(NVARCHAR, @n_WMSSTG_CNT) + '</span></b>'
                          + '<br><b>TPB STAGING (TPB_STG_BASE) - <span' 
                          + CASE WHEN @n_WMSSTG_CNT > @n_TPBSTG_CNT THEN ' style="color:red;" ' ELSE ''END
                          + '>' 
                          + CONVERT(NVARCHAR, @n_TPBSTG_CNT) + '</span></b>'
                          + '<br><br> Regards,<br>System Administrator<br><b>[This Is an automated email. Please do Not reply.]</b>'
      
      IF @b_debug = 1
      BEGIN
         PRINT '@c_EmailContent=' + @c_EmailContent
      END

      EXEC [msdb].[dbo].[sp_send_dbmail]
         @recipients = @c_Recipients
        ,@subject = @c_EmailSubject
        ,@importance = 'HIGH'
        ,@body = @c_EmailContent
        ,@body_format = 'HTML' 
   END

   QUIT:  
END -- Procedure  

GO