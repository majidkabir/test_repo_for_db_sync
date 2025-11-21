SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose: To check Qty between OrderDetail & PickDetail before              */
/*          Split Shipment.                                                   */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author       Purposes                                     */
/* 21-Nov-2012 1.0  James        Created.                                     */
/* 03-Dec-2012 1.0  Leong        Script enhancement.                          */
/******************************************************************************/

CREATE PROC [dbo].[isp_CreateMBOL_WCS_Sortation_Check]
(
   @cJOBNo     NVARCHAR(10),
   @cListTo    NVARCHAR(MAX) = '',
   @cListCc    NVARCHAR(MAX) = '',
   @nErr       INT          OUTPUT,
   @cErrMsg    NVARCHAR(250) OUTPUT
)  AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cDoor       NVARCHAR(10)
         , @cMBOLKey    NVARCHAR(10)
         , @nSeqNoStart INT
         , @nSeqNoEnd   INT
         , @nTRK_RowRef INT
         , @cLaneNo     NVARCHAR(10)
         , @cSubject    NVARCHAR(255)
         , @cMBOLList   NVARCHAR(255)
         , @nContinue   INT

   SET @cSubject  = 'Orders Integrity Error For Split Shipment [ JobNo: ' + @cJOBNo + ' ]' + ' @ ' + @@servername
   SET @cMBOLList = ''
   SET @nErr      = 0
   SET @cErrMsg   = ''
   SET @nContinue = 1

   CREATE TABLE #W (
        CaseId          NVARCHAR(20) NULL
      , OrderKey        NVARCHAR(10) NULL
      , OrderLineNumber NVARCHAR(5)  NULL
      , Sku             NVARCHAR(20) NULL
      , PD_QtyAllocated INT NULL
      , PD_QtyPicked    INT NULL
      , PD_QtyShipped   INT NULL
      )

   CREATE TABLE #O (
        OrderKey        NVARCHAR(10) NULL
      , OrderLineNumber NVARCHAR(5)  NULL
      , Sku             NVARCHAR(20) NULL
      , OD_QtyAllocated INT NULL
      , OD_QtyPicked    INT NULL
      , OD_QtyShipped   INT NULL
      )

   CREATE TABLE #RESULT (
        OrderKey        NVARCHAR(10) NULL
      , OrderLineNumber NVARCHAR(5)  NULL
      , Sku             NVARCHAR(20) NULL
      , OD_QtyAllocated INT NULL
      , OD_QtyPicked    INT NULL
      , PD_QtyAllocated INT NULL
      , PD_QtyPicked    INT NULL
      )

   SELECT @cDoor = Short
   FROM CodeLkUp WITH (NOLOCK)
   WHERE ListName = 'SPLTSHPMNT'
   AND Code = @cJOBNo

   -- Loop each MBOL
   DECLARE CUR_MBOL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT T.MBOLKey,
            (SELECT SeqNo FROM WCS_SORTATION WITH (NOLOCK) WHERE (LabelNo = T.RefNo)) AS SeqNoStart,
            (SELECT SeqNo FROM WCS_SORTATION WITH (NOLOCK) WHERE (LabelNo = T.URNNo)) AS SeqNoEnd,
            T.RowRef,
            (SELECT LP_LaneNumber FROM WCS_SORTATION WITH (NOLOCK) WHERE (LabelNo = T.RefNo)) AS LaneNumber
      FROM rdt.RDTScanToTruck T WITH (NOLOCK)
      JOIN MBOL WITH (NOLOCK) ON (T.MBOLKey = MBOL.MBOLKey)
      WHERE T.Status = '3'
      AND   T.Door = @cDoor
      ORDER BY T.RowRef

   OPEN CUR_MBOL
   FETCH NEXT FROM CUR_MBOL INTO @cMBOLKey, @nSeqNoStart, @nSeqNoEnd, @nTRK_RowRef, @cLaneNo

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      -- WCS Detail
      INSERT INTO #W (CaseId, OrderKey, OrderLineNumber, Sku, PD_QtyAllocated, PD_QtyPicked, PD_QtyShipped)
      SELECT PD.CaseId
           , PD.OrderKey, PD.OrderLineNumber, PD.Sku
           , CASE WHEN PD.Status <= '4' THEN ISNULL(SUM(PD.Qty), 0) ELSE 0 END
           , CASE WHEN PD.Status = '5' THEN ISNULL(SUM(PD.Qty), 0) ELSE 0 END
           , CASE WHEN PD.Status = '9' THEN ISNULL(SUM(PD.Qty), 0) ELSE 0 END
      FROM WCS_Sortation WCS WITH (NOLOCK)
      JOIN PickDetail PD WITH (NOLOCK)
      ON (WCS.LabelNo = PD.CaseId)
      WHERE WCS.SeqNo BETWEEN @nSeqNoStart AND @nSeqNoEnd
      AND WCS.Status <> '9'
      AND WCS.LP_LaneNumber = @cLaneNo
      GROUP BY PD.CaseId, PD.OrderKey, PD.OrderLineNumber, PD.Sku, PD.Status
      ORDER BY PD.OrderKey, PD.OrderLineNumber

      SELECT @cMBOLList = ISNULL(RTRIM(@cMBOLKey),'') + ' . ' + @cMBOLList

      FETCH NEXT FROM CUR_MBOL INTO @cMBOLKey, @nSeqNoStart, @nSeqNoEnd, @nTRK_RowRef, @cLaneNo
   END
   CLOSE CUR_MBOL
   DEALLOCATE CUR_MBOL

   -- OrderDetail
   INSERT INTO #O(OrderKey, OrderLineNumber, Sku, OD_QtyAllocated, OD_QtyPicked, OD_QtyShipped)
   SELECT OD.OrderKey, OD.OrderLineNumber, OD.Sku
       , ISNULL(SUM(OD.QtyAllocated), 0)
       , ISNULL(SUM(OD.QtyPicked), 0)
       , ISNULL(SUM(OD.ShippedQty), 0)
   FROM OrderDetail OD WITH (NOLOCK)
   JOIN (SELECT DISTINCT OrderKey, OrderLineNumber, Sku FROM #W) W
   ON (W.OrderKey = OD.OrderKey AND W.OrderLineNumber = OD.OrderLineNumber AND W.Sku = OD.Sku)
   GROUP BY OD.OrderKey, OD.OrderLineNumber, OD.Sku

   -- Compare WCS vs PickDetail vs OrderDetail
   INSERT INTO #RESULT ( OrderKey, OrderLineNumber, Sku
                    , OD_QtyAllocated, OD_QtyPicked, PD_QtyAllocated, PD_QtyPicked )
   SELECT A.OrderKey, A.OrderLineNumber, A.Sku
        , B.OD_QtyAllocated, B.OD_QtyPicked
        , SUM(A.PD_QtyAllocated)PD_QtyAllocated
        , SUM(A.PD_QtyPicked)PD_QtyPicked
   FROM #W A WITH (NOLOCK)
   JOIN #O B WITH (NOLOCK)
   ON (A.OrderKey = B.OrderKey AND A.OrderLineNumber = B.OrderLineNumber AND A.Sku = B.Sku)
   GROUP BY A.OrderKey, A.OrderLineNumber, A.Sku
          , B.OD_QtyAllocated, B.OD_QtyPicked, B.OD_QtyShipped
   HAVING (SUM(A.PD_QtyAllocated) > B.OD_QtyAllocated)
   OR (SUM(A.PD_QtyPicked) > B.OD_QtyPicked)

   IF EXISTS (SELECT 1 FROM #RESULT WITH (NOLOCK) WHERE ISNULL(RTRIM(OrderKey),'') <> '')
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
          N'<H3>' + @cSubject + '</H3>' +
          N'<BODY><P ALIGN="LEFT">Split Shipment Error [ Door: '+ ISNULL(RTRIM(@cDoor),'') + ', MBOL: ' + ISNULL(RTRIM(@cMBOLList),'') + ' ]</P></BODY>' +
          N'<TABLE BORDER="1" CELLSPACING="0" CELLPADDING="3">' +
          N'<TR BGCOLOR=#3BB9FF><TH>OrderKey</TH><TH>Order<BR>Line #</TH><TH>Sku</TH><TH>OrderDetail<BR>QtyAllocated</TH><TH>OrderDetail<BR>QtyPicked</TH><TH>PickDetail<BR>QtyAllocated</TH><TH>PickDetail<BR>QtyPicked</TH></TR>' +
          CAST ( ( SELECT TD = OrderKey, '',
                          'TD/@align' = 'center',
                          TD = OrderLineNumber, '',
                          'TD/@align' = 'center',
                          TD = Sku, '',
                          'TD/@align' = 'center',
                          TD = OD_QtyAllocated, '',
                          'TD/@align' = 'center',
                          TD = OD_QtyPicked, '',
                          'TD/@align' = 'center',
                          TD = PD_QtyAllocated, '',
                          'TD/@align' = 'center',
                          TD = PD_QtyPicked, ''
                   FROM #RESULT WITH (NOLOCK)
              FOR XML PATH('TR'), TYPE
          ) AS NVARCHAR(MAX) ) +
          N'</TABLE>' ;

      EXEC msdb.dbo.sp_send_dbmail
           @recipients      = @cListTo,
           @copy_recipients = @cListCc,
           @subject         = @cSubject,
           @body            = @tableHTML,
           @body_format     = 'HTML';

      SELECT @nContinue = 3
      SELECT @nErr = 79100
      SELECT @cErrMsg = 'NSQL ' + CONVERT(CHAR(5), ISNULL(@nErr, 0)) +
                        ': Orders Integrity Error For Split Shipment. (isp_CreateMBOL_WCS_Sortation_Check)'
      GOTO QUIT
   END
   ELSE
   BEGIN
      SELECT @nContinue = 1
      GOTO QUIT
   END

QUIT:
   IF OBJECT_ID('tempdb..#W') IS NOT NULL
   BEGIN
      DROP TABLE #W
   END

   IF OBJECT_ID('tempdb..#O') IS NOT NULL
   BEGIN
      DROP TABLE #O
   END

   IF OBJECT_ID('tempdb..#RESULT') IS NOT NULL
   BEGIN
      DROP TABLE #RESULT
   END

   IF @nContinue = 3
   BEGIN
      EXECUTE nsp_LogError @nErr, @cErrMsg, 'isp_CreateMBOL_WCS_Sortation_Check'
      RAISERROR (@cErrmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @nErr = 0
      RETURN
   END
END -- Procedure

GO