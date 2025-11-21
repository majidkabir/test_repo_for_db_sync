SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspALCMC04                                         */
/* Creation Date: 27-Aug-2013                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/*  Purpose: Copy and modified from NSPALSTD01                          */ 
/*         : IDSPH: CPPI Strategy                                       */ 
/*         : IF ORder Qty is Full Pallet , stock takes from 'PALLET'    */
/*         : locationtype                                               */
/*         : IF Order Qty is CASE, stock takes from 'CASE' locationtype */
/*         : IF order Qty is loose, stock takes from 'PICK' locationtype*/
/*         : OTHERWISE take from BULK Location (LocationTYPE <> 'PALLET'*/
/*         : , <> 'CASE', <> 'PICK')                                    */
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
/* 28-Mar-2018  NJOW01  1.0  WMS-4188 deduct QtyReplen                  */ 
/************************************************************************/

CREATE PROC [dbo].[nspALCMC04]
 @c_lot NVARCHAR(10) ,
 @c_uom NVARCHAR(10) ,
 @c_HostWHCode NVARCHAR(10),
 @c_Facility NVARCHAR(5),
 @n_uombase int ,
 @n_qtylefttofulfill int
 AS
 BEGIN
   SET NOCOUNT ON 
    
   
    DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
    SELECT LOTxLOCxID.LOC 
         , LOTxLOCxID.ID 
         , QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTXLOCXID.QTYREPLEN) 
         , '1'
    FROM LOT        WITH (NOLOCK)
    JOIN LOTxLOCxID WITH (NOLOCK) ON (LOT.Lot = LOTxLOCxID.Lot)
    JOIN LOC        WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
    JOIN ID         WITH (NOLOCK) ON (LOTXLOCXID.ID = ID.ID)
    WHERE LOT.Lot = @c_lot
    AND LOT.STATUS = 'OK'
    AND ID.STATUS  = 'OK'
    AND LOC.Locationflag <> 'HOLD' 
    AND LOC.Locationflag <> 'DAMAGE'
    AND LOC.STATUS = 'OK'  
    AND LOC.Facility = @c_Facility
    AND LOC.LocationType = CASE @c_UOM WHEN '1' THEN 'PALLET'
                                       WHEN '2' THEN 'CASE'
                                       WHEN '6' THEN 'PICK'
                                       END
    ORDER BY LOC.LOC
 END

GO