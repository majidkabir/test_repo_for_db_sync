SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspALLOR02                                         */
/* Creation Date: 21-NOV-2014                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 324093-Loreal PH Strategy - Allocate from Pick              */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver. Purposes                                   */
/* 27-Feb-2017  TLTING  1.1  Variable Nvarchar                          */
/************************************************************************/

CREATE PROC [dbo].[nspALLOR02] 
@c_lot NVARCHAR(10) ,
@c_uom NVARCHAR(10) ,
@c_HostWHCode NVARCHAR(10),
@c_Facility NVARCHAR(5),
@n_uombase int ,
@n_qtylefttofulfill int,
@c_OtherParms NVARCHAR(20) = ''         
AS
BEGIN
   SET NOCOUNT ON 
   
	 DECLARE @c_OrderKey        NVARCHAR(10),
	         @c_OrderLineNumber NVARCHAR(5),
	         @c_storerkey       NVARCHAR(15),
	         @c_Sku             NVARCHAR(20),
	         @c_Lottable03      NVARCHAR(18)
	         
   SELECT @c_storerkey = Storerkey, 
	        @c_Sku = Sku
	 FROM LOT (NOLOCK)
	 WHERE Lot = @c_Lot               
	                     
   IF LEN(@c_OtherParms) > 0  -- when storerconfig 'Orderinfo4Allocation' is turned on
   BEGIN        
      SET @c_OrderKey = LEFT(@c_OtherParms,10)         
      SET @c_OrderLineNumber = SUBSTRING(@c_OtherParms,11,5)
      
      SELECT @c_Lottable03 = Lottable03
      FROM ORDERDETAIL(NOLOCK)
      WHERE Orderkey = @c_Orderkey
      AND OrderLineNumber = @c_OrderLineNumber
   END  
         
   DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
   FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
          QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
   FROM LOTxLOCxID (NOLOCK)
   JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC
   JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Storerkey = SKUxLOC.Storerkey AND LOTxLOCxID.Sku = SKUxLOC.Sku
                            AND LOTxLOCxID.Loc = SKUxLOC.Loc
   JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID 
   JOIN LOT (NOLOCK) ON LOTXLOCXID.LOT = LOT.LOT
   WHERE LOTxLOCxID.Lot = @c_lot
   AND ID.Status <> 'HOLD'
   AND LOC.Facility = @c_Facility
   AND LOC.Locationflag <> 'HOLD'
   AND LOC.Locationflag <> 'DAMAGE'
   AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase
   AND LOC.Status <> 'HOLD'
   AND LOT.STATUS <> 'HOLD'
   AND SKUxLOC.LocationType IN ('PICK', 'CASE')
   AND LOC.HostWHCode = @c_Lottable03
   ORDER BY LOC.LogicalLocation, LOC.LOC
END

GO