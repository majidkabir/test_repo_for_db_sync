SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspAL_SG08                                         */
/* Creation Date: 29-Mar-2021                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-16523 SG PMS sort by lowest qty available               */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/
CREATE PROC    [dbo].[nspAL_SG08]
   @c_lot NVARCHAR(10) ,
   @c_uom NVARCHAR(10) ,
   @c_HostWHCode NVARCHAR(10),
   @c_Facility NVARCHAR(5),
   @n_uombase int ,
   @n_qtylefttofulfill int,  
   @c_OtherParms NVARCHAR(200) = ''
AS
BEGIN
   SET NOCOUNT ON
   
   DECLARE @c_LoosePltFirst NVARCHAR(1)
   
   SET @c_LoosePltFirst = 'N'
   
   IF EXISTS(SELECT 1 FROM ORDERS(NOLOCK) WHERE Orderkey = LEFT(@c_OtherParms, 10) AND Consigneekey NOT IN('PMS','PMS1'))
   BEGIN 
      SET @c_LoosePltFirst = 'Y'
   END        
   
   DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
   FOR SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID,
   QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
   FROM LOTxLOCxID (NOLOCK) 
   JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
   JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID) 
   JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT)
   JOIN SKU (NOLOCK) ON (LOTxLOCxID.Storerkey = SKU.Storerkey AND LOTxLOCxID.Sku = SKU.Sku)
   JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
   WHERE LOTxLOCxID.Lot = @c_lot
   AND LOC.Locationflag = 'NONE'
   AND LOC.Status <> 'HOLD'
   AND LOC.Facility = @c_Facility
   AND ID.STATUS <> 'HOLD'
   AND LOT.STATUS <> 'HOLD' 
   AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0 
   ORDER BY CASE WHEN PACK.Casecnt > 0 AND @c_LoosePltFirst = 'Y' THEN CASE WHEN (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) % CAST(PACK.Casecnt AS INT) > 0 THEN 1 ELSE 2 END ELSE 3 END, 
         CASE WHEN PACK.Casecnt > 0 AND @c_LoosePltFirst = 'N' THEN CASE WHEN (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) % CAST(PACK.Casecnt AS INT) = 0 THEN 1 ELSE 2 END ELSE 3 END,   
         QTYAVAILABLE, LOC.LogicalLocation, LOC.LOC
END

GO