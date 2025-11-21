SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--
-- Definition for stored procedure isp_WTC_SOHRecon2_Export : 
--

/************************************************************************/
/* SP: isp_WTC_SOHRecon2_Export                                         */
/* Creation Date: 1                                                     */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: DTS Interface                                             */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */ 
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 04/10/2005   Vicky         SOS#40608 - Add in condition clause for   */
/*                                        Qty available computation     */
/************************************************************************/

CREATE PROC [dbo].[isp_WTC_SOHRecon2_Export](
   @c_SourceDBName   NVARCHAR(20)
,  @c_StorerKey      NVARCHAR(15)
,  @b_Success        int         OUTPUT
,  @n_Err            int         OUTPUT
,  @c_ErrMsg         NVARCHAR(250)   OUTPUT
)
AS
BEGIN
   -- Rewrite on 7Oct04 (SOS27353)

   DECLARE  @c_ExecStatements     NVARCHAR(4000)

   SET NOCOUNT ON

   IF ISNULL(@c_SourceDBName, '') = '' OR ISNULL(@c_StorerKey, '') = ''
      RETURN

   CREATE TABLE #TempSOH (
      SNAPSHOTDATE    DATETIME,
      Facility        NVARCHAR(8),
      Stock_Type      NVARCHAR(10),
      SKU             NVARCHAR(20),
      ExpiryDate      DATETIME,
      ReceiptDate     DATETIME,
      TOTALSOH        INT,
      AVAILSOH        INT,
      AllocatedQty    INT,
      PickedQTY       INT,
      QtyonHold       INT,
      INQtyonOrder    INT,
      OUTQtyonOrder   INT,
      Batch           NVARCHAR(10),
      BatchLineNumber INT IDENTITY (1, 1) NOT NULL,
      Action          NVARCHAR(1),
      ProcessSource   NVARCHAR(1) 
   )


   SELECT @c_ExecStatements = ''
   SELECT @c_ExecStatements =
         ' INSERT INTO #TempSOH (SNAPSHOTDATE, Facility, Stock_Type, SKU, ExpiryDate,' +
                               ' ReceiptDate, TOTALSOH, AVAILSOH, AllocatedQty, PickedQTY,' +
                               ' QtyonHold, INQtyonOrder, OUTQtyonOrder, Batch, Action, ProcessSource)' +
         ' SELECT SNAPSHOTDATE    = CONVERT(DATETIME, CONVERT(CHAR(8), GETDATE(), 112)),' +
                ' Facility        = SUBSTRING(LOC.LOC,2,1),' +
                ' Stock_Type      = CASE WHEN LOC.PutawayZone LIKE "%XD%" THEN "XDOCK" ELSE "INDENT" END,' +
                ' SKU             = LOTxLOCxID.Sku,' +
                ' ExpiryDate      = CONVERT(DATETIME, CONVERT(CHAR(8), LOTATTRIBUTE.Lottable04, 112)),' +
                ' ReceiptDate     = CONVERT(DATETIME, CONVERT(CHAR(8), LOTATTRIBUTE.Lottable05, 112)),' +
                ' TOTALSOH        = SUM(LOTxLOCxID.Qty),' +
--                 ' AVAILSOH        = SUM(CASE WHEN NOT (LOC.LocationFlag IN ("HOLD", "DAMAGE") AND LOC.PutawayZone NOT LIKE "%XD%")' +
--                                            ' THEN LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPickInProcess - LOTxLOCxID.Qtypicked' +
--                                            ' ELSE 0 END),' +
                -- Modified By Vicky on 4th Oct 2005 for SOS#40608
                ' AVAILSOH        = SUM(CASE WHEN (LOC.LocationFlag NOT IN ("HOLD", "DAMAGE")) AND LOC.LocationType = "OTHER"' +
                                           ' THEN LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.Qtypicked ' + -- End modified Vicky
                                           ' WHEN NOT (LOC.LocationFlag IN ("HOLD", "DAMAGE") AND LOC.LocationType <> "IDZ")' +
                                           ' THEN LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPickInProcess - LOTxLOCxID.Qtypicked' +
                                           ' ELSE 0 END),' + 
                ' AllocatedQty    = SUM(LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPickInProcess),' +
                ' PickedQTY       = SUM(LOTxLOCxID.Qtypicked),' +
--                 ' QtyonHold       = SUM(CASE WHEN LOC.LocationFlag IN ("HOLD", "DAMAGE") AND LOC.PutawayZone NOT LIKE "%XD%"' +
--                                            ' THEN LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPickInProcess - LOTxLOCxID.Qtypicked' +
--                                            ' ELSE 0 END),' +  
                -- Modified By Vicky on 4th Oct 2005 for SOS#40608
                ' QtyonHold       = SUM(CASE WHEN LOC.LocationFlag IN ("HOLD", "DAMAGE") AND LOC.LocationType <> "IDZ"' +
                                           ' THEN LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPickInProcess - LOTxLOCxID.Qtypicked' +
                                           ' ELSE 0 END),' + 
                ' INQtyonOrder    = 0,' +
                ' OUTQtyonOrder   = 0,' +
                ' Batch           = CONVERT(CHAR(6),GETDATE(),12)+SUBSTRING(CONVERT(CHAR(8),GETDATE(),8),1,2)+SUBSTRING(CONVERT(CHAR(8),GETDATE(),8),4,2),' +
                ' Action          = "A",' +
                ' ProcessSource   = "Y"' +
         ' FROM ' + dbo.fnc_RTRIM(@c_SourceDBName) + '..LOTxLOCxID LOTxLOCxID (NOLOCK)' +
         ' JOIN ' + dbo.fnc_RTRIM(@c_SourceDBName) + '..LOC LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc' +
         ' JOIN ' + dbo.fnc_RTRIM(@c_SourceDBName) + '..LOTATTRIBUTE LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.Lot = LOTATTRIBUTE.Lot' +
         ' WHERE LOTxLOCxID.StorerKey = "11315" AND LOTxLOCxID.Qty>0' +
         ' GROUP BY SUBSTRING(LOC.LOC,2,1),' +
                 ' CASE WHEN LOC.PutawayZone LIKE "%XD%" THEN "XDOCK" ELSE "INDENT" END,' +
                 ' LOTxLOCxID.Sku,' +
                 ' CONVERT(DATETIME, CONVERT(CHAR(8), LOTATTRIBUTE.Lottable04, 112)),' +
                 ' CONVERT(DATETIME, CONVERT(CHAR(8), LOTATTRIBUTE.Lottable05, 112))' +
         ' ORDER BY Facility, Stock_Type, SKU, ExpiryDate, ReceiptDate'


   EXEC sp_executesql @c_ExecStatements

   SELECT @n_Err = @@ERROR
   IF @n_Err <> 0
   BEGIN
      SELECT @c_ErrMsg = 'DB Error ' + dbo.fnc_RTRIM(CONVERT(CHAR(5), @n_Err)) + '. Create SOH temp file error!'
      RETURN
   END

   IF EXISTS(SELECT 1 FROM #TempSOH (NOLOCK))
   BEGIN
      BEGIN TRAN

      INSERT WTCSOHRECON2
             (SNAPSHOTDATE, Facility, Stock_Type, SKU, Expirydate, Receiptdate, TOTALSOH, AVAILSOH,ALLOCATEDQTY,
              PickedQty, QtyonHold, INQtyonOrder, OUTQtyonOrder, Batch, BatchLineNumber, Action, ProcessSource)
       SELECT SNAPSHOTDATE, Facility, Stock_Type, SKU, ExpiryDate, ReceiptDate, TOTALSOH, AVAILSOH, ALLOCATEDQTY,
              PickedQty, QtyonHold, INQtyonOrder, OUTQtyonOrder, Batch, BatchLineNumber, Action, ProcessSource
         FROM #TempSOH
        ORDER BY BatchLineNumber

      SELECT @n_Err = @@ERROR
      IF @n_Err <> 0
      BEGIN
         ROLLBACK TRAN
         SELECT @c_ErrMsg = 'DB Error ' + dbo.fnc_RTRIM(CONVERT(CHAR(5), @n_Err)) + '. Insert WTCSOHRECON2 error!'
         RETURN
      END

      COMMIT TRAN
   END
END

GO