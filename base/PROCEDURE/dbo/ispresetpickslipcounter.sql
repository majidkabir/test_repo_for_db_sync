SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: ispResetPickslipCounter                             */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: - To tally the PickHeaderKey vs nCounter table.             */
/*          - Setup email addresses in CodeLkUp.ListName = 'VALIDATE'   */
/*                                                                      */
/* Called By:  Scheduler job                                            */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Modifications:                                                       */
/* Date         Author    Ver.  Purposes                                */
/* 03-JAN-2013  Leong     1.0   SOS#265314 - Created.                   */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispResetPickslipCounter]
     @b_debug     INT = 0
   , @b_Success   INT = 0 OUTPUT
   , @n_Err       INT = 0 OUTPUT
   , @c_ErrMsg    NVARCHAR(250) = '' OUTPUT
AS
   SET NOCOUNT ON
   SET ANSI_NULLS ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @n_KeyCount       INT
      , @n_MaxPickSlipNo  INT
      , @c_MaxPickSlipNo  NVARCHAR(18)
      , @c_KeyName        NVARCHAR(30)
      , @c_Recipients     NVARCHAR(255)
      , @c_Subject        NVARCHAR(255)
      , @c_StorerKey      NVARCHAR(15)
      , @c_ExecStatements NVARCHAR(4000)
      , @c_ExecArguments  NVARCHAR(4000)
      , @c_ListName       NVARCHAR(30)
      , @n_Continue       INT
      , @n_StartTCnt      INT

SET @n_Continue  = 1
SET @n_StartTCnt = @@TRANCOUNT

SET @c_ListName  = 'VALIDATE'
SET @c_StorerKey = 'ALL'

IF ISNULL(OBJECT_ID('tempdb..#PSlip'),'') <> ''
BEGIN
   DROP TABLE #PSlip
END

CREATE TABLE #PSlip
   ( KeyName    NVARCHAR(30) NULL
   , KeyCount   INT NULL
   , PickSlipNo NVARCHAR(18) NULL
   , AddDate    DATETIME NULL )

SET @n_KeyCount      = 0
SET @n_MaxPickSlipNo = 0
SET @c_MaxPickSlipNo = ''
SET @c_KeyName    = 'PICKSLIP'
SET @c_Subject    = 'Unmatch PickSlipNo vs KeyCount: ' + @@ServerName

SELECT @c_MaxPickSlipNo = MAX(SUBSTRING(PickHeaderKey, 2, LEN(LTRIM(RTRIM(PickHeaderKey))) - 1))
FROM PickHeader WITH (NOLOCK)

IF ISNUMERIC(@c_MaxPickSlipNo) = 1
BEGIN
   -- SELECT @n_MaxPickSlipNo = CAST(@c_MaxPickSlipNo AS INT)
   SELECT @n_MaxPickSlipNo = CAST(MAX(SUBSTRING(PickHeaderKey, 2, LEN(LTRIM(RTRIM(PickHeaderKey))) - 1)) AS INT)
   FROM PickHeader WITH (NOLOCK)

   SELECT @n_KeyCount = KeyCount
   FROM nCounter WITH (NOLOCK)
   WHERE KeyName = @c_KeyName

   IF ISNULL(@n_KeyCount, 0) < ISNULL(@n_MaxPickSlipNo, 0)
   BEGIN
      BEGIN TRAN
      UPDATE nCounter WITH (ROWLOCK)
         SET KeyCount = @n_MaxPickSlipNo
      WHERE KeyName = @c_KeyName

      INSERT INTO #PSlip(KeyName, KeyCount, PickSlipNo, AddDate)
      VALUES (@c_KeyName, @n_KeyCount, @n_MaxPickSlipNo, GETDATE())

      IF @@ERROR = 0
      BEGIN
         WHILE @@TRANCOUNT > 0
            COMMIT TRAN
      END
      ELSE
      BEGIN
         SELECT @n_Continue = 3
         SELECT @n_Err = 61000
         SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_Err,0))
                          + ': Update records in nCounter failed. (ispResetPickslipCounter)'
         GOTO QUIT
      END

   END
END
ELSE
BEGIN
   INSERT INTO #PSlip(KeyName, KeyCount, PickSlipNo, AddDate)
   VALUES ('Fail To Lookup Numeric P.Slip', @n_KeyCount, @c_MaxPickSlipNo, GETDATE())
END

IF @b_debug = 1
BEGIN
   SELECT * FROM #PSlip
END

IF @n_Continue = 1 OR @n_Continue = 2
BEGIN
   SET @c_ExecStatements = ''
   SET @c_ExecArguments = ''
   SET @c_ExecStatements = N'SELECT @c_Recipients = ISNULL(RTRIM(Long),'''') ' -- Retrieve Email
                           + 'FROM CodeLkUp WITH (NOLOCK) '
                           + 'WHERE ListName = ''' + ISNULL(RTRIM(@c_ListName),'') + ''' '
                           + 'AND Code = ''' + ISNULL(RTRIM(@c_KeyName),'') + ''' '
                           + 'AND StorerKey = ''' + ISNULL(RTRIM(@c_StorerKey),'') + ''' '

   SET @c_ExecArguments = N'@c_Recipients NVARCHAR(255) OUTPUT'

   EXEC sp_ExecuteSql @c_ExecStatements
                    , @c_ExecArguments
                    , @c_Recipients OUTPUT

   IF @b_debug = 1
   BEGIN
      SELECT @c_Recipients '@c_Recipients'
   END

   IF EXISTS (SELECT 1 FROM #PSlip) AND ISNULL(RTRIM(@c_Recipients),'') <> ''
   BEGIN
      DECLARE @tableHTML NVARCHAR(MAX);
      SET @tableHTML =
          N'<STYLE TYPE="text/css"> ' + CHAR(13) +
          N'<!--' + CHAR(13) +
          N'TR{font-family: Arial; font-size: 10pt;}' + CHAR(13) +
          N'TD{font-family: Arial; font-size: 9pt;}' + CHAR(13) +
          N'H3{font-family: Arial; font-size: 12pt;}' + CHAR(13) +
          N'BODY{font-family: Arial; font-size: 9pt;}' + CHAR(13) +
          N'--->' + CHAR(13) +
          N'</STYLE>' + CHAR(13) +
          N'<H3>' + @c_Subject + '</H3>' +
          N'<BODY><FONT FACE="Arial">Please check the following records:</FONT><P>' +
          N'<TABLE BORDER="1" CELLSPACING="0" CELLPADDING="3">' +
          N'<TR BGCOLOR=#3BB9FF><TH>KeyName</TH><TH>KeyCount</TH><TH>Max PickSlipNo</TH><TH>Date</TH></TR>' +
          CAST ( ( SELECT TD = KeyName, '',
                          'TD/@align' = 'CENTER',
                          TD = KeyCount, '',
                          'TD/@align' = 'CENTER',
                          TD = PickSlipNo, '',
                          'TD/@align' = 'CENTER',
                          TD = CONVERT(NVARCHAR, AddDate, 113), ''
                   FROM #PSlip WITH (NOLOCK)
              FOR XML PATH('TR'), TYPE
          ) AS NVARCHAR(MAX) ) +
          N'</TABLE></BODY>'

      EXEC msdb.dbo.sp_send_dbmail
           @recipients  = @c_Recipients,
           @subject     = @c_Subject,
           @body        = @tableHTML,
           @body_format = 'HTML';
   END

   IF ISNULL(OBJECT_ID('tempdb..#PSlip'),'') <> ''
   BEGIN
      DROP TABLE #PSlip
   END
END

QUIT:
WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN TRAN

IF @n_Continue = 3 -- Error Occured - Process And Return
BEGIN
   SELECT @b_success = 0
   IF @@TRANCOUNT > @n_StartTCnt
   BEGIN
      ROLLBACK TRAN
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
   EXECUTE dbo.nsp_LogError @n_Err, @c_ErrMsg, 'ispResetPickslipCounter'
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   RETURN
END
ELSE
BEGIN
   SELECT @b_success = 1
   WHILE @@TRANCOUNT > @n_StartTCnt
   BEGIN
      COMMIT TRAN
   END
   RETURN
END

GO