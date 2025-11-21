SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/ 
/* Object Name: idsALULP02                                                 */
/* Modification History:                                                   */  
/*                                                                         */  
/* Called By:  Exceed                                                      */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Date         Author    Ver.  Purposes                                   */
/* 05-Aug-2002            1.0   Initial revision                           */
/* 16-Dec-2004  wtshong   1.1   Change cursor type                         */
/* 24-Mar-2009  ang       1.2   SOS131215 : Added in Lot, ID, Lot.Status,  */
/*                              ID.Status, Loc.status ='OK'                */
/* 05-Jul-2012  khlim     1.3   SET ANSI_NULLS OFF                         */
/***************************************************************************/ 
CREATE PROC [dbo].[idsALULP02]
       @c_lot NVARCHAR(10) ,
       @c_uom NVARCHAR(10) ,
       @c_HostWHCode NVARCHAR(10),
       @c_Facility NVARCHAR(5),
       @n_uombase int ,
       @n_qtylefttofulfill int
 AS
 BEGIN
    DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
       SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
       QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
       FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK),LOT(NOLOCK), ID(NOLOCK)  
       WHERE LOTxLOCxID.Lot = @c_lot
       AND LOTxLOCxID.Loc = LOC.LOC
       AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
       AND LOTxLOCxID.Sku = SKUxLOC.Sku
       AND LOTxLOCxID.Loc = SKUxLOC.Loc
       AND LOTXLOCXID.LOT = LOT.LOT --SOS131215 START ang01   
       AND LOTXLOCXID.ID  = ID.ID  ---SOS131215 END ang01    
       and (loc.locationtype = 'CASE' or loc.locationtype = 'PICK')
       AND LOT.STATUS = 'OK' --SOS131215 START ang01 
       AND LOC.STATUS = 'OK'
       AND ID.STATUS = 'OK' ---SOS131215 END ang01   
       AND LOC.Locationflag = 'NONE' 
       AND LOC.Facility = @c_Facility
       ORDER BY loc.hostwhcode, LOC.LOC
 END

GO