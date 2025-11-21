SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspALSTD2R                                         */
/* Creation Date: 19-11-2008                                            */
/* Copyright: IDS                                                       */
/* Written by: Vanessa                                                  */
/*                                                                      */
/* Purpose: New Allocation Strategy for GOLD SOS117139                  */
/*                                                                      */
/* Called By: Exceed Allocate Orders                                    */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC    [dbo].[nspALSTD2R]
@c_lot NVARCHAR(10) ,
@c_uom NVARCHAR(10) , 
@c_HostWHCode NVARCHAR(10),
@c_Facility NVARCHAR(5),
@n_uombase int ,
@n_qtylefttofulfill int,
@c_OtherParms NVARCHAR(200)
AS
BEGIN 
   SET NOCOUNT ON 
   
DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK)
WHERE LOTxLOCxID.Lot = @c_lot
AND LOTxLOCxID.Loc = LOC.LOC
AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
AND LOTxLOCxID.Sku = SKUxLOC.Sku
AND LOTxLOCxID.Loc = SKUxLOC.Loc
AND SKUxLOC.Locationtype = "CASE" 
AND LOC.Facility = @c_Facility 
AND LOC.Locationflag <>"HOLD"
AND LOC.Locationflag <> "DAMAGE"
AND LOC.Status <> "HOLD"
AND LOC.Putawayzone <> 'GOLD' -- (SOS#117139)
ORDER BY LOC.LOC
END


GO