SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispCheckLotQtyOnHold                               */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:- Email Alert for incorrect LOT.QtyOnHold (SOS# 295314)      */
/*         - Modify from stored proc ispReCalculateQtyOnHold.           */
/*                                                                      */
/* Return Status: None                                                  */
/*                                                                      */
/* Called By: SQL Schedule Job                                          */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/*                                                                      */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispCheckLotQtyOnHold]
   @c_Recipients   NVARCHAR(255) = ''
 , @b_debug        INT = 0
 , @b_UpdateFlag   INT = 0
AS
   SET NOCOUNT ON
   SET ANSI_NULLS ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @c_Lot             NVARCHAR(10)
      , @n_TotQtyHoldById  INT
      , @n_TotQtyHoldByLoc INT
      , @n_LotQtyOnHold    INT
      , @c_Subject         NVARCHAR(255)

SET @c_Lot = ''
SET @n_TotQtyHoldById  = 0
SET @n_TotQtyHoldByLoc = 0
SET @n_LotQtyOnHold    = 0

SET @c_Subject = 'Unmatch LOT QtyOnHold Alert: ' + @@ServerName

CREATE TABLE #LOT
      ( SeqNo        INT IDENTITY(1,1) NOT NULL
      , Lot          NVARCHAR(10) NULL
      , StorerKey    NVARCHAR(15) NULL
      , Sku          NVARCHAR(20) NULL
      , Qty          INT NULL
      , QtyOnHoldLot INT NULL
      , QtyHoldById  INT NULL
      , QtyHoldByLoc INT NULL )

DECLARE CUR_LOT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT LOT.Lot
   FROM LOT WITH (NOLOCK)
   WHERE QtyOnHold <> 0
   UNION
   SELECT DISTINCT LOT.Lot
   FROM LOT WITH (NOLOCK)
   JOIN LOTxLOCxID L WITH (NOLOCK) ON L.Lot = LOT.Lot
   JOIN LOC WITH (NOLOCK) ON L.Loc = LOC.Loc
   WHERE (LOC.Status = 'HOLD' OR LOC.LocationFlag = 'HOLD')
   AND   LOT.QtyOnHold = 0
   UNION
   SELECT DISTINCT LOT.Lot
   FROM LOT WITH (NOLOCK)
   JOIN LOTxLOCxID L WITH (NOLOCK) ON L.Lot = LOT.Lot
   JOIN ID WITH (NOLOCK) ON L.ID = ID.Id
   WHERE (ID.Status = 'HOLD')
   AND   LOT.QtyOnHold = 0
   ORDER BY LOT

OPEN CUR_LOT
FETCH NEXT FROM CUR_LOT INTO @c_Lot

WHILE @@FETCH_STATUS <> -1
BEGIN
   -- Get total qty on-hold where this ID not exists in LOC that Held
   SELECT @n_TotQtyHoldById = ISNULL(SUM(LLI.Qty),0)
   FROM LOTxLOCxID LLI WITH (NOLOCK)
   JOIN LOC WITH (NOLOCK) ON (LLI.Loc = LOC.Loc)
   JOIN ID ID WITH (NOLOCK) ON (LLI.Id = ID.Id)
   WHERE LLI.Loc = LOC.Loc
   AND LLI.Id = ID.Id
   AND ID.Status = 'HOLD'
   AND LOC.Status = 'OK'
   AND LLI.Lot = @c_Lot
   AND LLI.Qty > 0
   AND ID.Id <> ''

   SELECT @n_TotQtyHoldByLoc = ISNULL(SUM(LLI.Qty),0)
   FROM LOTxLOCxID LLI WITH (NOLOCK)
   JOIN LOC WITH (NOLOCK) ON LLI.Loc = LOC.Loc
   WHERE (LOC.Status <> 'OK' OR LOC.LocationFlag = 'HOLD' OR LOC.LocationFlag = 'DAMAGE')
   AND LLI.Lot = @c_Lot
   AND LLI.Qty > 0

   SELECT @n_LotQtyOnHold = ISNULL(QtyOnHold, 0)
   FROM LOT WITH (NOLOCK)
   WHERE Lot = @c_Lot

   IF @b_debug = 1
   BEGIN
      SELECT @c_Lot '@c_Lot', @n_TotQtyHoldByLoc '@n_TotQtyHoldByLoc', @n_TotQtyHoldById '@n_TotQtyHoldById', @n_LotQtyOnHold '@n_LotQtyOnHold'
   END

   IF ISNULL(@n_LotQtyOnHold, 0) <> (ISNULL(@n_TotQtyHoldById, 0) + ISNULL(@n_TotQtyHoldByLoc, 0))
   BEGIN
      INSERT INTO #LOT (Lot, StorerKey, Sku, Qty, QtyOnHoldLot, QtyHoldById, QtyHoldByLoc)
      SELECT Lot, StorerKey, Sku, Qty, QtyOnHold
           , ISNULL(@n_TotQtyHoldById, 0) AS QtyHoldById
           , ISNULL(@n_TotQtyHoldByLoc, 0) AS QtyHoldByLoc
      FROM   LOT WITH (NOLOCK)
      WHERE  LOT = @c_Lot

      IF @b_UpdateFlag = 1 -- Allow sp to update LOT table
      BEGIN
         UPDATE LOT WITH (ROWLOCK)
         SET QtyOnHold = ISNULL(@n_TotQtyHoldById,0) + ISNULL(@n_TotQtyHoldByLoc,0)
         --, ArchiveCop = NULL
         WHERE LOT = @c_Lot
      END
   END

   FETCH NEXT FROM CUR_LOT INTO @c_Lot
END
CLOSE CUR_LOT
DEALLOCATE CUR_LOT

IF @b_debug = 1
BEGIN
   SELECT * FROM #LOT
END

IF EXISTS (SELECT 1 FROM #LOT)
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
       N'<BODY><FONT FACE="Arial">The following Lot was hold with unmatch <B><FONT COLOR="Red">QtyOnHold</FONT></B>:</FONT><BR><BR>' +
       N'<TABLE BORDER="1" CELLSPACING="0" CELLPADDING="3">' +
       N'<TR BGCOLOR=#3BB9FF><TH>No</TH><TH>Lot</TH><TH>StorerKey</TH><TH>Sku</TH><TH>Lot<BR>Qty</TH><TH>Lot<BR>QtyOnHold</TH><TH>LOTxLOCxID<BR>QtyHoldById</TH><TH>LOTxLOCxID<BR>QtyHoldByLoc</TH></TR>' +
       CAST ( ( SELECT TD = SeqNo, '',
                       TD = Lot, '',
                       'TD/@align' = 'center',
                       TD = StorerKey, '',
                       'TD/@align' = 'center',
                       TD = Sku, '',
                       'TD/@align' = 'center',
                       TD = Qty, '',
                       'TD/@align' = 'center',
                       TD = QtyOnHoldLot, '',
                       'TD/@align' = 'center',
                       TD = QtyHoldById, '',
                       'TD/@align' = 'center',
                       TD = QtyHoldByLoc, ''
                FROM #LOT WITH (NOLOCK)
           FOR XML PATH('TR'), TYPE
       ) AS NVARCHAR(MAX) ) +
       N'</TABLE></BODY>'

   IF ISNULL(RTRIM(@c_Recipients),'') <> ''
   BEGIN
      EXEC msdb.dbo.sp_send_dbmail
           @recipients  = @c_Recipients,
           @subject     = @c_Subject,
           @body        = @tableHTML,
           @body_format = 'HTML';
   END
END

IF ISNULL(OBJECT_ID('tempdb..#LOT'),'') <> ''
BEGIN
   DROP TABLE #LOT
END

GO