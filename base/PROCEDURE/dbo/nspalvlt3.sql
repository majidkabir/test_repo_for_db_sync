SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspALVLT                                           */
/*                                                                      */
/* Purpose: Allocating FROM WA / VNA THEN checking FIFO AND THEN PICK   */
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 05-MAY-2024  PPA374  1.0   Violet Allocation                         */
/************************************************************************/
CREATE   PROC [dbo].[nspALVLT3]
   @c_DocumentNo              NVARCHAR(10),
   @c_Facility                NVARCHAR(5),
   @c_StorerKey               NVARCHAR(15),
   @c_SKU                     NVARCHAR(20),
   @c_Lottable01              NVARCHAR(18),
   @c_Lottable02              NVARCHAR(18),
   @c_Lottable03              NVARCHAR(18),
   @d_Lottable04              DATETIME,
   @d_Lottable05              DATETIME,
   @c_Lottable06              NVARCHAR(30),
   @c_Lottable07              NVARCHAR(30),
   @c_Lottable08              NVARCHAR(30),
   @c_Lottable09              NVARCHAR(30),
   @c_Lottable10              NVARCHAR(30),
   @c_Lottable11              NVARCHAR(30),
   @c_Lottable12              NVARCHAR(30),
   @d_Lottable13              DATETIME,
   @d_Lottable14              DATETIME,
   @d_Lottable15              DATETIME,
   @c_UOM                     NVARCHAR(10),
   @c_HostWHCode              NVARCHAR(10),
   @n_UOMBase                 INT,
   @n_QtyLeftToFulfill        INT,
   @c_OtherParms              NVARCHAR(200)=''
AS
BEGIN   
   SET NOCOUNT ON
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
          
   DECLARE 
      @c_SQL                NVARCHAR(MAX),
      @c_SQLParm            NVARCHAR(MAX),
      @n_QtyAvailable       INT,
      @c_LOT                NVARCHAR(10),
      @c_LOC                NVARCHAR(10),
      @c_ID                 NVARCHAR(18),
      @c_OtherValue         NVARCHAR(20),
      @n_QtyToTake          INT,
      @n_StorerMinShelfLife INT,
      @n_LotQtyAvailable    INT,
      @c_ExpireCode         NVARCHAR(30),
      @c_FromDay            NVARCHAR(10),
      @c_ToDay              NVARCHAR(10),
      @c_ShelfLifeRange     NCHAR(1),
      @c_packkey            NVARCHAR(20),
      @n_casecnt            INT,
      @n_LeftQtyToFulfill   INT,
      @n_caseqty            INT
    
   SET @n_QtyAvailable = 0
   SET @c_OtherValue = '1'
   SET @n_QtyToTake = 0
   SET @n_LeftQtyToFulfill = 0
   SET @n_caseqty          = 0
       
   IF @n_UOMBase = 0
     SET @n_UOMBase = 1

   EXEC isp_Init_Allocate_Candidates
    
  /* CREATE TABLE #TMP_LOT (LOT NVARCHAR(10) NULL,
                          QtyAvailable INT NULL DEFAULT(0)) */

   DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT LOT,LOC,ID,QTYAVAILABLE FROM
   (SELECT LOT,LOC,ID,QTYAVAILABLE,minlot, qtyinloc, PutawayZone, Sku, locationtype,
   sum(QTYAVAILABLE)OVER(ORDER BY 
   CASE WHEN qtyinloc = 
   (SELECT OpenQty - QtyAllocated - QtyPicked - QtyPreAllocated - ShippedQty FROM ORDERDETAIL (NOLOCK)
      WHERE OrderKey = left(@c_OtherParms,10) AND orderlinenumber = right(left(@c_OtherParms,15),5)) THEN 1 ELSE 99 END,
   CASE WHEN PutawayZone IN 
   (SELECT code FROM CODELKUP (NOLOCK) WHERE LISTNAME = 'VNAZONHUSQ')
   THEN 1 
   WHEN PutawayZone IN (SELECT code FROM CODELKUP (NOLOCK) WHERE LISTNAME = 'WAZONEHUSQ') THEN 1 ELSE 2 END, minlot, qtyinloc DESC, Loc, Lot)RollingSum
   , (SELECT OpenQty - QtyAllocated - QtyPicked - QtyPreAllocated - ShippedQty FROM ORDERDETAIL (NOLOCK)
      WHERE OrderKey = left(@c_OtherParms,10) AND orderlinenumber = right(left(@c_OtherParms,15),5))TotalQtyToPick
   FROM
   (SELECT LOT,LOC,ID,QTYAVAILABLE,minlot, qtyinloc, PutawayZone, Sku, LocationType FROM
   (SELECT LOC,ID,QTYAVAILABLE,sku,putawayzone,lot,locationtype,min(lot)OVER(PARTITION BY loc,id,sku)minlot,
   (SELECT sum(qty-QtyAllocated-QtyPicked-QtyReplen) FROM LOTxLOCxID (NOLOCK) WHERE qty-QtyAllocated-QtyPicked-QtyReplen > 0 
   AND loc = T1.loc AND id = t1.Id AND t1.sku = sku)qtyinloc FROM
   (SELECT LLI.Loc,LLI.ID,LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - LLI.QtyReplen QTYAVAILABLE,PutawayZone,LLI.LOT
   ,lot.Sku,LocationType
      FROM LOTXLOCXID (NOLOCK) LLI
      JOIN LOC (NOLOCK) ON LLI.LOC = LOC.LOC
      JOIN ID  (NOLOCK) ON LLI.ID = ID.ID
      JOIN LOT (NOLOCK) ON LLI.LOT = LOT.LOT
      WHERE LOC.Facility = @c_Facility
      AND ISNULL(LOC.LocationFlag,'') IN ('','NONE')
      AND LLI.ID NOT IN (SELECT ID FROM INVENTORYHOLD (NOLOCK) WHERE hold = 1 AND ID <>'')
      AND LOC.Loc NOT IN (SELECT LOC FROM INVENTORYHOLD (NOLOCK) WHERE hold = 1 AND LOC <>'')
      AND LOC.Status = 'OK'
      AND ID.Status = 'OK'
      AND LOT.Status = 'OK'
      AND LOC.HOSTWHCODE = (SELECT IIF(ISNULL(UserDefine01,'A')='','A',ISNULL(UserDefine01,'A')) FROM ORDERDETAIL (NOLOCK) WHERE OrderKey = left(@c_OtherParms,10) AND orderlinenumber = right(left(@c_OtherParms,15),5))
      AND lli.sku = (SELECT top 1 sku FROM orderdetail (NOLOCK)WHERE OrderKey = left(@c_OtherParms,10) AND orderlinenumber = right(left(@c_OtherParms,15),5))
      AND LOC.LocationType IN(SELECT Code FROM CODELKUP WITH (NOLOCK) WHERE listname = 'HUSQALLLOC' AND Storerkey = 'HUSQ')
      AND LocationCategory IN(SELECT code2 FROM CODELKUP WITH (NOLOCK) WHERE listname = 'HUSQALLLOC' AND Storerkey = 'HUSQ')
      AND LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - LLI.QtyReplen > 0
      AND (LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - LLI.QtyReplen <= 
      (SELECT OpenQty - QtyAllocated - QtyPicked - ShippedQty FROM ORDERDETAIL (NOLOCK)
      WHERE OrderKey = left(@c_OtherParms,10) AND orderlinenumber = right(left(@c_OtherParms,15),5))
      or LOC.LocationType = 'PICK')
      AND PutawayZone IN (SELECT Code FROM CODELKUP WITH (NOLOCK) WHERE listname = 'HUSQALLZON' AND Storerkey = 'HUSQ'))T1)T2
      WHERE qtyinloc<=
      (SELECT OpenQty - QtyAllocated - QtyPicked - ShippedQty FROM ORDERDETAIL (NOLOCK)
      WHERE OrderKey = left(@c_OtherParms,10) AND orderlinenumber = right(left(@c_OtherParms,15),5))
      or LocationType = 'PICK')T3)T4
      WHERE RollingSum <= TotalQtyToPick or LocationType = 'PICK'
   Order By CASE WHEN qtyinloc = 
   (SELECT OpenQty - QtyAllocated - QtyPicked - QtyPreAllocated - ShippedQty FROM ORDERDETAIL (NOLOCK)
      WHERE OrderKey = left(@c_OtherParms,10) AND orderlinenumber = right(left(@c_OtherParms,15),5)) THEN 1 ELSE 99 END,
   CASE WHEN PutawayZone IN 
   (SELECT code FROM CODELKUP (NOLOCK) WHERE LISTNAME = 'VNAZONHUSQ')
   THEN 1 
   WHEN PutawayZone IN (SELECT code FROM CODELKUP (NOLOCK) WHERE LISTNAME = 'WAZONEHUSQ') THEN 1 ELSE 2 END, minlot, qtyinloc DESC, Loc, Lot

   OPEN CURSOR_AVAILABLE
   FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable

   WHILE (@@FETCH_STATUS <> -1) --AND (@n_QtyLeftToFulfill > 0)
   BEGIN
      EXEC isp_Insert_Allocate_Candidates
         @c_Lot = @c_Lot
         ,@c_Loc = @c_Loc
         ,@c_ID  = @c_ID
         ,@n_QtyAvailable = @n_QtyAvailable
         ,@c_OtherValue = @c_OtherValue

      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable
      END -- END WHILE FOR CURSOR_AVAILABLE
   
   EXIT_SP:
    
   IF CURSOR_STATUS('GLOBAL' , 'CURSOR_AVAILABLE') IN (0 , 1)
   BEGIN
      CLOSE CURSOR_AVAILABLE
      DEALLOCATE CURSOR_AVAILABLE
   END

   EXEC isp_Cursor_Allocate_Candidates
      @n_SkipPreAllocationFlag = 1 

END

GO