SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspALCMC1G                                         */
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
/* 13-Jul-2010  SHONG01   1.2 SOS220901 Allocation Strategy requirement */
/*                            for Unilever U2K2 Cut-Over                */
/************************************************************************/

CREATE PROC [dbo].[nspALCMC1G]
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

    Declare @b_debug int,
            @c_ord_lottable03 NVARCHAR(18)

    -- Get OrderKey AND line Number
    DECLARE @c_OrderKey   NVARCHAR(10),
            @c_OrderLineNumber NVARCHAR(5),
            -- SHONG01  
            @c_OrderType  NVARCHAR(10), 
            @c_FilterZone NVARCHAR(200)  

    IF dbo.fnc_RTrim(@c_OtherParms) IS NOT NULL AND dbo.fnc_RTrim(@c_OtherParms) <> ''
    BEGIN
       SELECT @c_OrderKey = LEFT(dbo.fnc_LTrim(@c_OtherParms), 10)
       SELECT @c_OrderLineNumber = SUBSTRING(dbo.fnc_LTrim(@c_OtherParms), 11, 5)

       SELECT @c_ord_lottable03=Lottable03 
       from OrderDetail (NOLOCK)
       where OrderKey = @c_OrderKey
       AND orderlinenumber = @c_OrderLineNumber

       IF ISNULL(RTrim(@c_OrderKey),'') <> ''  
       BEGIN  
          -- SHONG01
          SELECT @c_OrderType = ORDERS.Type   
          FROM   ORDERS (NOLOCK)
          WHERE ORDERS.OrderKey = @c_OrderKey

          SET @c_FilterZone = ''

          IF EXISTS(SELECT 1 FROM CODELKUP WITH (NOLOCK) WHERE ListName = 'U2K2ORDTYP' AND Code = @c_OrderType)
          BEGIN
             SET @c_FilterZone = @c_OrderType
          END
          -- SHONG01
       END 

    END

     IF ISNULL(dbo.fnc_RTRIM(@c_ord_lottable03),'') = 'GOLD'
     BEGIN
          DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
          FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
          QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
          FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK), LOT(NOLOCK), ID(NOLOCK)    
          WHERE LOTxLOCxID.Lot = @c_lot
          AND LOTxLOCxID.Loc = LOC.LOC
          AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
          AND LOTxLOCxID.Sku = SKUxLOC.Sku
          AND LOTxLOCxID.Loc = SKUxLOC.Loc
          AND (LOC.locationtype = 'SELECTIVE' or LOC.locationtype = 'DOUBLEDEEP')
 	       AND LOTXLOCXID.LOT = LOT.LOT --SOS131215 START  
 	       AND LOTXLOCXID.ID  = ID.ID  ---SOS131215 END  
          AND  LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK' AND LOC.LocationFlag <> 'HOLD' --SOS131215 START  
          AND LOC.LocationFlag <> 'DAMAGE'  
          AND LOC.PutAwayZone NOT IN (SELECT CODE FROM CODELKUP WITH (NOLOCK) WHERE ListName = 'U2K2ORDTYP') -- SHONG01
          --AND LOC.Locationflag = 'NONE'   SOS131215 END 
          AND LOC.Facility = @c_Facility
          ORDER BY CASE LOC.Putawayzone WHEN 'GOLDC' THEN 0 WHEN NULL THEN 1 WHEN ' ' THEN 2 ELSE 3 END ASC, LOC.hostwhcode, LOC.LOC
     END
     ELSE  
     IF ISNULL(RTRIM(@c_FilterZone),'') <> '' 
     BEGIN  
          DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
          FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
          QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
          FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK), LOT(NOLOCK), ID(NOLOCK)    
          WHERE LOTxLOCxID.Lot = @c_lot
          AND LOTxLOCxID.Loc = LOC.LOC
          AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
          AND LOTxLOCxID.Sku = SKUxLOC.Sku
          AND LOTxLOCxID.Loc = SKUxLOC.Loc
          AND (LOC.locationtype = 'SELECTIVE' or LOC.locationtype = 'DOUBLEDEEP')
 	       AND LOTXLOCXID.LOT = LOT.LOT --SOS131215 START  
 	       AND LOTXLOCXID.ID  = ID.ID  ---SOS131215 END  
          AND  LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK' AND LOC.LocationFlag <> 'HOLD' --SOS131215 START  
          AND LOC.LocationFlag <> 'DAMAGE'  
          AND LOC.Putawayzone = @c_FilterZone
          AND LOC.Facility = @c_Facility
          ORDER BY CASE LOC.Putawayzone WHEN 'GOLDC' THEN 0 WHEN NULL THEN 1 WHEN ' ' THEN 2 ELSE 3 END ASC, LOC.hostwhcode, LOC.LOC
     END 
     ELSE
     BEGIN
          DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
          FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
          QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
          FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK), LOT(NOLOCK), ID(NOLOCK)    
          WHERE LOTxLOCxID.Lot = @c_lot
          AND LOTxLOCxID.Loc = LOC.LOC
          AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
          AND LOTxLOCxID.Sku = SKUxLOC.Sku
          AND LOTxLOCxID.Loc = SKUxLOC.Loc
          AND (LOC.locationtype = 'SELECTIVE' or LOC.locationtype = 'DOUBLEDEEP')
 	       AND LOTXLOCXID.LOT = LOT.LOT --SOS131215 START  
 	       AND LOTXLOCXID.ID  = ID.ID  ---SOS131215 END  
          AND  LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK' AND LOC.LocationFlag <> 'HOLD' --SOS131215 START  
          AND LOC.LocationFlag <> 'DAMAGE'  
          --AND LOC.Locationflag = 'NONE'   SOS131215 END  
          AND LOC.Facility = @c_Facility
          AND LOC.Putawayzone <> 'GOLD'
          AND LOC.PutAwayZone NOT IN (SELECT CODE FROM CODELKUP WITH (NOLOCK) WHERE ListName = 'U2K2ORDTYP') -- SHONG01
          ORDER BY CASE LOC.Putawayzone WHEN 'GOLDC' THEN 0 WHEN NULL THEN 1 WHEN ' ' THEN 2 ELSE 3 END ASC, LOC.hostwhcode, LOC.LOC
     END
 END

GO