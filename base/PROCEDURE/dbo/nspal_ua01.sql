SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspAL_UA01                                         */
/* Creation Date: 12-Jun-2015                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 342109-CN Under Armour (UA) Allocation Strategy             */
/*          Allocate case/loose from bulk                               */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver. Purposes                                   */
/* 28-Aug-2015  NJOW01  1.0  Fix last carton short allocate due to      */
/*                           pending replen by other wave               */
/* 27-Feb-2017  TLTING  1.1  Variable Nvarchar                          */
/* 10-Jul-2018  NJOW02  1.2  WMS-5692 Change lot sorting by locationgroup*/
/*                           for full case. CN only.                    */
/* 10-Sep-2021  NJOW03  1.3  WMS-17912 new logic for HK UA. filter      */
/*                           location type OTHER for UOM 2              */
/* 16-Oct-2021  NJOW03  1.3  DEVOPS combine script                      */
/************************************************************************/

CREATE PROC [dbo].[nspAL_UA01] 
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
   
	 DECLARE @c_OrderKey     NVARCHAR(10),
	         @c_OrderLineNumber NVARCHAR(5),
           @c_countryflag     NVARCHAR(10) --NJOW02
   
   --NJOW02        
   SELECT @c_countryflag = NSQLValue
   FROM NSQLCONFIG (NOLOCK)
   WHERE Configkey = 'Country'        
	                     
   IF LEN(@c_OtherParms) > 0  -- when storerconfig 'Orderinfo4Allocation' is turned on
   BEGIN        
      SET @c_OrderKey = LEFT(@c_OtherParms,10)         
      SET @c_OrderLineNumber = SUBSTRING(@c_OtherParms,11,5)
   END   
   
   IF @c_UOM  = '6'  -- allocate last carton pending replen by other wave.
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
      FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC
      JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Storerkey = SKUxLOC.Storerkey AND LOTxLOCxID.Sku = SKUxLOC.Sku
                               AND LOTxLOCxID.Loc = SKUxLOC.Loc
      JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID 
      WHERE LOTxLOCxID.Lot = @c_lot
      AND LOC.Facility = @c_Facility
      AND LOC.Locationflag <>'HOLD'
      AND LOC.Locationflag <> 'DAMAGE'
      AND LOC.Status <> 'HOLD'
      AND ID.Status = 'OK'
      --AND SKUXLOC.Locationtype NOT IN ('PICK','CASE') 
      --AND LOC.Locationtype NOT IN ('DYNPPICK')       
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0 
      ORDER BY CASE WHEN LOC.LocationType = 'DYNPPICK' THEN 0 ELSE 1 END, 3, LOC.LogicalLocation, LOC.LOC   	
   END
   ELSE IF @c_UOM  = '2' AND @c_countryflag = 'CN'
   BEGIN
   	  --NJOW02
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
      FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen), '1'
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC
      JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Storerkey = SKUxLOC.Storerkey AND LOTxLOCxID.Sku = SKUxLOC.Sku
                               AND LOTxLOCxID.Loc = SKUxLOC.Loc
      JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID 
      WHERE LOTxLOCxID.Lot = @c_lot
      AND LOC.Facility = @c_Facility
      AND LOC.Locationflag <>'HOLD'
      AND LOC.Locationflag <> 'DAMAGE'
      AND LOC.Status <> 'HOLD'
      AND ID.Status = 'OK'
      AND SKUXLOC.Locationtype NOT IN ('PICK','CASE') 
      AND LOC.Locationtype NOT IN ('DYNPPICK')       
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0 
      ORDER BY LOC.LocationGroup, LOC.LocLevel, QTYAVAILABLE, LOC.LogicalLocation, LOC.LOC   	
   END
   ELSE IF @c_UOM  = '2' AND @c_countryflag = 'HK'  --NJOW03
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
      FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen), '1'
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC
      JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Storerkey = SKUxLOC.Storerkey AND LOTxLOCxID.Sku = SKUxLOC.Sku
                               AND LOTxLOCxID.Loc = SKUxLOC.Loc
      JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID 
      WHERE LOTxLOCxID.Lot = @c_lot
      AND LOC.Facility = @c_Facility
      AND LOC.Locationflag <>'HOLD'
      AND LOC.Locationflag <> 'DAMAGE'
      AND LOC.Status <> 'HOLD'
      AND ID.Status = 'OK'
      --AND SKUXLOC.Locationtype NOT IN ('PICK','CASE') 
      AND LOC.Locationtype = 'OTHER'       
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0 
      ORDER BY 3, LOC.LogicalLocation, LOC.LOC   	   	
   END
   ELSE
   BEGIN --UOM 7 or 2(non CN)
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
      FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
      QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen), '1'
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC
      JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Storerkey = SKUxLOC.Storerkey AND LOTxLOCxID.Sku = SKUxLOC.Sku
                               AND LOTxLOCxID.Loc = SKUxLOC.Loc
      JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID 
      WHERE LOTxLOCxID.Lot = @c_lot
      AND LOC.Facility = @c_Facility
      AND LOC.Locationflag <>'HOLD'
      AND LOC.Locationflag <> 'DAMAGE'
      AND LOC.Status <> 'HOLD'
      AND ID.Status = 'OK'
      AND SKUXLOC.Locationtype NOT IN ('PICK','CASE') 
      AND LOC.Locationtype NOT IN ('DYNPPICK')       
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0 
      ORDER BY 3, LOC.LogicalLocation, LOC.LOC   	
   END
   
END

GO