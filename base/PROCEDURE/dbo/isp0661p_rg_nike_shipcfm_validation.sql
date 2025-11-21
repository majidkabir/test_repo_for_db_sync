SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp0661P_RG_NIKE_ShipCfm_Validation                 */
/* Creation Date:                                                       */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: - To ensure qty and pickslip meet IML script requirement.   */
/*          - Optional step and implement when necessary only.          */
/*                                                                      */
/* Called By:  Scheduler job                                            */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Modifications:                                                       */
/* Date         Author    Ver.  Purposes                                */
/* 01-Jun-2017  Leong     1.0   Include Country db name.                */
/* 15-Jul-2019  Leong     1.1   Compare Pick/Pack Qty at sku level.     */
/*                              Retrieve email by new sp ispGetEmail.   */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp0661P_RG_NIKE_ShipCfm_Validation]
     @c_StorerKey NVARCHAR(30)
   , @c_itfDBName NVARCHAR(30)
   , @c_WMSDBName NVARCHAR(30) = ''
   , @b_debug     INT = 0
AS
   SET NOCOUNT ON
   SET ANSI_NULLS ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @c_NSCLogKey      NVARCHAR(10)
      , @c_OrderKey       NVARCHAR(10)
      , @c_TransmitFlag   NVARCHAR(5)
      , @c_ErrorFlag      NVARCHAR(5)
      , @c_ErrMsg         NVARCHAR(30)
      , @c_PickSlipNo     NVARCHAR(10)
      , @c_TableName      NVARCHAR(15)
      , @n_TotalPickQty   INT
      , @n_TotalPackQty   INT
      , @n_RecordCnt      INT
      , @c_Recipients     NVARCHAR(255)
      , @c_RecipientCc    NVARCHAR(255)
      , @c_RecipientBcc   NVARCHAR(255)
      , @c_Subject        NVARCHAR(255)
      , @c_ListName       NVARCHAR(30)
      , @c_DataStream     NVARCHAR(10)
      , @tableHTML        NVARCHAR(MAX)
      , @c_ExecStatements NVARCHAR(4000)
      , @c_ExecArguments  NVARCHAR(4000)

SET @c_ErrMsg       = ''
SET @c_NSCLogKey    = ''
SET @c_OrderKey     = ''
SET @c_TransmitFlag = ''
SET @c_ErrorFlag    = '5'
SET @c_DataStream   = '0661'
SET @c_TableName    = 'NIKEREGORD'
SET @c_ListName     = 'VALIDATE'

SET @c_Subject = UPPER(ISNULL(RTRIM(@c_StorerKey),'')) + ' Ship Confirmation Error [' + @@servername + ' | ' + ISNULL(RTRIM(@c_itfDBName),'') + ' | ' + ISNULL(RTRIM(@c_DataStream),'') + ']'

IF ISNULL(RTRIM(@c_WMSDBName),'') = ''
BEGIN
   SET @c_WMSDBName = DB_NAME()
END

SET @c_ExecStatements = ''
SET @c_ExecStatements = ISNULL(RTRIM(LTRIM(@c_WMSDBName)),'') + '.dbo.' + 'ispGetEmail'

SET @c_Recipients   = ''
SET @c_RecipientCc  = ''
SET @c_RecipientBcc = ''

EXEC @c_ExecStatements @c_TableName, @c_StorerKey, @c_Recipients   OUTPUT, @c_itfDBName, 'EmailTo'
EXEC @c_ExecStatements @c_TableName, @c_StorerKey, @c_RecipientCc  OUTPUT, @c_itfDBName, 'EmailCc'
EXEC @c_ExecStatements @c_TableName, @c_StorerKey, @c_RecipientBcc OUTPUT, @c_itfDBName, 'EmailBcc'

IF @b_debug = 1
BEGIN
   PRINT 'To: '  + @c_Recipients
   PRINT 'Cc: '  + @c_RecipientCc
   PRINT 'Bcc: ' + @c_RecipientBcc
END

IF ISNULL(OBJECT_ID('tempdb..#NSC'),'') <> ''
BEGIN
   DROP TABLE #NSC
END

IF ISNULL(OBJECT_ID('tempdb..#ORD'),'') <> ''
BEGIN
   DROP TABLE #ORD
END

IF ISNULL(OBJECT_ID('tempdb..#PICK'),'') <> ''
BEGIN
   DROP TABLE #PICK
END

IF ISNULL(OBJECT_ID('tempdb..#PACK'),'') <> ''
BEGIN
   DROP TABLE #PACK
END

CREATE TABLE #NSC ( PickSlipNo NVARCHAR(10) NULL
                  , OrderKey   NVARCHAR(10) NULL
                  , StorerKey  NVARCHAR(15) NULL
                  , Sku        NVARCHAR(20) NULL
                  , LabelNo    NVARCHAR(20) NULL
                  , LabelLine  NVARCHAR(5)  NULL
                  , PackQty    NVARCHAR(30) NULL
                  , PickQty    NVARCHAR(30) NULL
                  , ErrMsg     NVARCHAR(30) NULL )

CREATE TABLE #ORD ( OrderKey   NVARCHAR(10) NULL
                  , ErrMsg     NVARCHAR(30) NULL )

CREATE TABLE #PICK ( OrderKey   NVARCHAR(10) NULL
                   , StorerKey  NVARCHAR(15) NULL
                   , Sku        NVARCHAR(20) NULL
                   , PickQty    INT NULL )

CREATE TABLE #PACK ( OrderKey   NVARCHAR(10) NULL
                   , PickSlipNo NVARCHAR(10) NULL
                   , StorerKey  NVARCHAR(15) NULL
                   , Sku        NVARCHAR(20) NULL
                   , LabelNo    NVARCHAR(20) NULL
                   , LabelLine  NVARCHAR(5)  NULL
                   , PackQty    INT NULL )

DECLARE Cur_NSCLog CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT NSCLogKey, Key1, TransmitFlag
   FROM NSCLog WITH (NOLOCK)
   WHERE TableName = @c_TableName
   AND Key3 = @c_StorerKey
   AND TransmitFlag = '0'
   AND CONVERT(NVARCHAR, EditDate, 112) >= CONVERT(NVARCHAR, GETDATE() - 90, 112)
   ORDER BY NSCLogKey

OPEN Cur_NSCLog
FETCH NEXT FROM Cur_NSCLog INTO @c_NSCLogKey, @c_OrderKey, @c_TransmitFlag

WHILE @@FETCH_STATUS <> -1
BEGIN

   SET @n_RecordCnt = 0
   SELECT @n_RecordCnt = COUNT(DISTINCT ISNULL(RTRIM(PickSlipNo),''))
   FROM PackHeader WITH (NOLOCK)
   WHERE OrderKey = @c_OrderKey

   IF @n_RecordCnt = 1 -- 1 Orders = 1 Pickslip only
   BEGIN
      SET @c_PickSlipNo = ''
      SELECT @c_PickSlipNo = ISNULL(RTRIM(PickSlipNo),'')
      FROM PackHeader WITH (NOLOCK)
      WHERE OrderKey = @c_OrderKey

      SET @n_TotalPackQty = 0
      SELECT @n_TotalPackQty = ISNULL(SUM(Qty),0)
      FROM PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @c_PickSlipNo
      AND ISNULL(RTRIM(LabelNo),'') <> ''
      AND ISNULL(RTRIM(LabelLine),'') <> ''

      SET @n_TotalPickQty = 0
      SELECT @n_TotalPickQty = ISNULL(SUM(Qty),0)
      FROM PickDetail WITH (NOLOCK)
      WHERE OrderKey = @c_OrderKey

      TRUNCATE TABLE #PICK
      INSERT INTO #PICK (OrderKey, StorerKey, Sku, PickQty)
      SELECT OrderKey, StorerKey, Sku, SUM(Qty)
      FROM PickDetail WITH (NOLOCK)
      WHERE OrderKey = @c_OrderKey
      GROUP BY OrderKey, StorerKey, Sku

      TRUNCATE TABLE #PACK
      INSERT INTO #PACK (OrderKey, PickSlipNo, StorerKey, Sku, PackQty)
      SELECT H.OrderKey, H.PickSlipNo, D.StorerKey, D.Sku, SUM(D.Qty)
      FROM PackHeader H WITH (NOLOCK)
      JOIN PackDetail D WITH (NOLOCK)
      ON (H.PickSlipNo = D.PickSlipNo)
      WHERE D.PickSlipNo = @c_PickSlipNo
      AND ISNULL(RTRIM(D.LabelNo),'') <> ''
      AND ISNULL(RTRIM(D.LabelLine),'') <> ''
      GROUP BY H.OrderKey, H.PickSlipNo, D.StorerKey, D.Sku

      IF ISNULL(@n_TotalPackQty, 0) <> ISNULL(@n_TotalPickQty, 0)
      BEGIN
         SET @c_ErrMsg = 'Unmatched Orders Pick/Pack Qty'

         UPDATE NSCLog WITH (ROWLOCK)
         SET  TransmitFlag  = @c_ErrorFlag
            , TransmitBatch = @c_ErrMsg
            , EditDate      = GETDATE()
            , EditWho       = SUSER_SNAME()
            , ArchiveCop    = NULL
         WHERE TableName    = @c_TableName
         AND NSCLogKey      = @c_NSCLogKey

         INSERT INTO #NSC (PickSlipNo, OrderKey, StorerKey, Sku, LabelNo, LabelLine, PackQty, PickQty, ErrMsg)
         VALUES (@c_PickSlipNo, @c_OrderKey, '', '', '', '', @n_TotalPackQty, @n_TotalPickQty, @c_ErrMsg)
      END
      ELSE
      BEGIN
         IF EXISTS ( SELECT 1
                     FROM #PICK PD WITH (NOLOCK)
                     LEFT JOIN #PACK PA WITH (NOLOCK)
                     ON (PD.OrderKey = PA.OrderKey AND PD.StorerKey = PA.StorerKey AND PD.Sku = PA.Sku)
                     WHERE ISNULL(PD.PickQty, 0) <> ISNULL(PA.PackQty, 0) )
         BEGIN
            IF @b_debug = 1
            BEGIN
               SELECT '#PICK', * FROM #PICK WITH (NOLOCK)
               ORDER BY OrderKey, StorerKey, Sku

               SELECT '#PACK', * FROM #PACK WITH (NOLOCK)
               ORDER BY OrderKey, StorerKey, Sku
            END

            SET @c_ErrMsg = 'Unmatched Sku Pick/Pack Qty'

            UPDATE NSCLog WITH (ROWLOCK)
            SET  TransmitFlag  = @c_ErrorFlag
               , TransmitBatch = @c_ErrMsg
               , EditDate      = GETDATE()
               , EditWho       = SUSER_SNAME()
               , ArchiveCop    = NULL
            WHERE TableName    = @c_TableName
            AND NSCLogKey      = @c_NSCLogKey

            INSERT INTO #NSC (PickSlipNo, OrderKey, StorerKey, Sku, LabelNo, LabelLine, PackQty, PickQty, ErrMsg)
            SELECT ISNULL(RTRIM(PA.PickSlipNo),''), ISNULL(RTRIM(PD.OrderKey),''), ISNULL(RTRIM(PD.StorerKey),''), ISNULL(RTRIM(PD.Sku),''), '', ''
                 , ISNULL(PA.PackQty,0), ISNULL(PD.PickQty,0), @c_ErrMsg
            FROM #PICK PD WITH (NOLOCK)
            LEFT JOIN #PACK PA WITH (NOLOCK)
            ON (PD.OrderKey = PA.OrderKey AND PD.StorerKey = PA.StorerKey AND PD.Sku = PA.Sku)
            WHERE ISNULL(PD.PickQty, 0) <> ISNULL(PA.PackQty, 0)
         END
      END

      TRUNCATE TABLE #PACK
      INSERT INTO #PACK (OrderKey, PickSlipNo, StorerKey, Sku, LabelNo, LabelLine, PackQty)
      SELECT @c_OrderKey, PickSlipNo, StorerKey, '', LabelNo, LabelLine, SUM(Qty)
      FROM PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @c_PickSlipNo
      AND ISNULL(RTRIM(LTRIM(LabelNo)),'') <> ''
      AND ISNULL(RTRIM(LTRIM(LabelLine)),'') <> ''
      GROUP BY PickSlipNo, StorerKey, LabelNo, LabelLine
      HAVING COUNT(ISNULL(RTRIM(LTRIM(LabelNo)),'') + ISNULL(RTRIM(LTRIM(LabelLine)),'')) > 1

      IF EXISTS (SELECT 1 FROM #PACK WITH (NOLOCK))
      BEGIN
         SET @c_ErrMsg = 'Duplicate LabelNo+LabelLine'

         UPDATE NSCLog WITH (ROWLOCK)
         SET  TransmitFlag  = @c_ErrorFlag
            , TransmitBatch = @c_ErrMsg
            , EditDate      = GETDATE()
            , EditWho       = SUSER_SNAME()
            , ArchiveCop    = NULL
         WHERE TableName    = @c_TableName
         AND NSCLogKey      = @c_NSCLogKey

         INSERT INTO #NSC (PickSlipNo, OrderKey, StorerKey, Sku, LabelNo, LabelLine, PackQty, PickQty, ErrMsg)
         SELECT PickSlipNo, OrderKey, StorerKey, Sku, LabelNo, LabelLine, PackQty, '', @c_ErrMsg
         FROM #PACK WITH (NOLOCK)
         WHERE PickSlipNo = @c_PickSlipNo
      END
   END
   ELSE -- @n_RecordCnt = 1
   BEGIN
      SET @c_ErrMsg = 'Multiple PickslipNo'

      UPDATE NSCLog WITH (ROWLOCK)
      SET  TransmitFlag  = @c_ErrorFlag
         , TransmitBatch = @c_ErrMsg
         , EditDate      = GETDATE()
         , EditWho       = SUSER_SNAME()
         , ArchiveCop    = NULL
      WHERE TableName    = @c_TableName
      AND NSCLogKey      = @c_NSCLogKey

      INSERT INTO #ORD (OrderKey, ErrMsg)
      VALUES (@c_OrderKey, @c_ErrMsg)
   END

   FETCH NEXT FROM Cur_NSCLog INTO @c_NSCLogKey, @c_OrderKey, @c_TransmitFlag
END
CLOSE Cur_NSCLog
DEALLOCATE Cur_NSCLog

IF @b_debug = 1
BEGIN
   SELECT '#NSC', * FROM #NSC WITH (NOLOCK)
   SELECT '#ORD', * FROM #ORD WITH (NOLOCK)
END

IF ISNULL(RTRIM(@c_Recipients),'') <> ''
BEGIN
   IF EXISTS (SELECT 1 FROM #NSC WITH (NOLOCK))
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
          N'<H3>' + UPPER(ISNULL(RTRIM(@c_StorerKey),'')) + ' Unmatched Qty in PackDetail vs PickDetail. DataStream: ' + ISNULL(RTRIM(@c_DataStream),'') + '</H3>' +
          N'<BODY>Please check the record below:<P>' +
          N'<TABLE BORDER="1" CELLSPACING="0" CELLPADDING="5">' +
          N'<TR BGCOLOR=#3BB9FF><TH>PickSlipNo</TH><TH>OrderKey</TH><TH>StorerKey</TH><TH>Sku</TH>' +
          N'<TH>LabelNo</TH><TH>LabelLine</TH><TH>PackQty</TH><TH>PickQty</TH><TH>Error</TH><TH>Date</TH></TR>' +
          CAST ( ( SELECT TD = PickSlipNo, '',
                          TD = OrderKey, '',
                          TD = StorerKey, '',
                          TD = Sku, '',
                          TD = LabelNo, '',
                          TD = LabelLine, '',
                          'TD/@align' = 'CENTER',
                          TD = PackQty, '',
                          'TD/@align' = 'CENTER',
                          TD = PickQty, '',
                          TD = ErrMsg, '',
                          TD = CONVERT(NVARCHAR, GETDATE(), 109), ''
                   FROM #NSC WITH (NOLOCK)
                   ORDER BY PickSlipNo, OrderKey, Sku
              FOR XML PATH('TR'), TYPE
          ) AS NVARCHAR(MAX) ) +
          N'</TABLE><P></BODY>'

      EXEC msdb.dbo.sp_send_dbmail
           @recipients            = @c_Recipients
         , @copy_recipients       = @c_RecipientCc
         , @blind_copy_recipients = @c_RecipientBcc
         , @subject               = @c_Subject
         , @body                  = @tableHTML
         , @body_format           = 'HTML'
   END

   IF EXISTS (SELECT 1 FROM #ORD WITH (NOLOCK))
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
          N'<H3>' + UPPER(ISNULL(RTRIM(@c_StorerKey),'')) + ' Orders with multiple PickSlipNo. DataStream: ' + ISNULL(RTRIM(@c_DataStream),'') + '</H3>' +
          N'<BODY>Please check the record below:<P>' +
          N'<TABLE BORDER="1" CELLSPACING="0" CELLPADDING="5">' +
          N'<TR BGCOLOR=#3BB9FF><TH>OrderKey</TH><TH>Date</TH></TR>' +
          CAST ( ( SELECT TD = OrderKey, '',
                          'TD/@align' = 'CENTER',
                          TD = CONVERT(NVARCHAR, GETDATE(), 109), ''
                   FROM #ORD WITH (NOLOCK)
              FOR XML PATH('TR'), TYPE
          ) AS NVARCHAR(MAX) ) +
          N'</TABLE><P></BODY>'

      EXEC msdb.dbo.sp_send_dbmail
           @recipients            = @c_Recipients
         , @copy_recipients       = @c_RecipientCc
         , @blind_copy_recipients = @c_RecipientBcc
         , @subject               = @c_Subject
         , @body                  = @tableHTML
         , @body_format           = 'HTML'

   END
END -- ISNULL(RTRIM(@c_Recipients),'') <> ''

IF ISNULL(OBJECT_ID('tempdb..#NSC'),'') <> ''
BEGIN
   DROP TABLE #NSC
END

IF ISNULL(OBJECT_ID('tempdb..#ORD'),'') <> ''
BEGIN
   DROP TABLE #ORD
END

IF ISNULL(OBJECT_ID('tempdb..#PICK'),'') <> ''
BEGIN
   DROP TABLE #PICK
END

IF ISNULL(OBJECT_ID('tempdb..#PACK'),'') <> ''
BEGIN
   DROP TABLE #PACK
END

QUIT:


GO