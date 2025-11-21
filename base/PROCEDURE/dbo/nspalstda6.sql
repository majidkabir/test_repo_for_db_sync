SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspALSTDA6                                         */
/* Creation Date: 05-Aug-2002                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
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
/* Date         Author    Ver. Purposes                                 */
/* 14-Oct-2004	Mohit			     Change cursor type								        */
/* 18-Jul-2005	Loon				   Add Drop Object statement					      */
/* 11-Aug-2005	MaryVong		   Remove SET ANSI WARNINGS which caused    */
/*									       	   error in DX								              */
/* 21-Mar-2006  Shong          Check ID.Status = HOLD & Qty Available   */
/* 2015-09-29   NJOW01    1.6  345748 - add other param                 */  
/************************************************************************/
CREATE PROC  [dbo].[nspALSTDA6]  -- Rename From IDSSG and IDSMY:nspALSTD06
@c_lot NVARCHAR(10) ,
@c_uom NVARCHAR(10) ,
--@c_sectionkey NVARCHAR(3),
--@c_oskey NVARCHAR(10),
@c_HostWHCode NVARCHAR(10),
@c_Facility NVARCHAR(5),
@n_uombase int ,
@n_qtylefttofulfill int,
@c_OtherParms NVARCHAR(200)=''               
AS
BEGIN
   SET NOCOUNT ON 
    
   

   DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
   FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
   QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
   FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK), ID (NOLOCK)
   WHERE LOTxLOCxID.Lot = @c_lot
   AND LOTxLOCxID.Loc = LOC.LOC
   AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
   AND LOTxLOCxID.Sku = SKUxLOC.Sku
   AND LOTxLOCxID.Loc = SKUxLOC.Loc
   AND SKUxLOC.Locationtype ="PICK"
   AND LOC.Facility = @c_Facility
   AND LOC.Locationflag <>"HOLD"
   AND LOC.Locationflag <> "DAMAGE"
   AND LOC.Status <> "HOLD"
   AND LOTxLOCxID.ID = ID.ID -- Shong20060321
   AND ID.Status = 'OK'      -- Shong20060321  
   AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0 -- Shong20060321   
   ORDER BY LOC.LOC
END



GO