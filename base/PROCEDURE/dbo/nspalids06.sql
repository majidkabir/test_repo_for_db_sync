SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspALIDS06 																				*/
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
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
/* Date         Author        Purposes                                  */
/* 26-Jul-2005  June			   SOS38045 - bug fix zero Qtyavail return	*/
/* 26-Apr-2015  TLTING01 1.1  Add Other Parameter default value         */ 
/*	                                                                     */
/************************************************************************/

CREATE PROC    [dbo].[nspALIDS06]
   @c_lot NVARCHAR(10) ,
   @c_uom NVARCHAR(10) ,
   --@c_sectionkey NVARCHAR(3),
   --@c_oskey NVARCHAR(10),
   @c_HostWHCode NVARCHAR(10),
   @c_Facility NVARCHAR(5),
   @n_uombase int ,
   @n_qtylefttofulfill int,  
   @c_OtherParms NVARCHAR(200) = ''
AS
BEGIN 
   SET NOCOUNT ON 
    
   

   DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
   FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
   QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
   FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK), ID (nolock)
   WHERE LOTxLOCxID.Lot = @c_lot
     AND LOTxLOCxID.Loc = LOC.LOC
     AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
     AND LOTxLOCxID.Sku = SKUxLOC.Sku
     AND LOTxLOCxID.Loc = SKUxLOC.Loc
     AND LOTxLOCxID.id = ID.id
     AND id.status = 'OK'
     AND SKUxLOC.Locationtype <> "OTHER"
     AND LOC.Facility = @c_Facility 
     AND LOC.Locationflag <>"HOLD"
     AND LOC.Locationflag <> "DAMAGE"
     AND LOC.Status <> "HOLD"
     AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0 -- SOS38045
   ORDER BY LogicalLocation, LOC.LOC 
END

GO