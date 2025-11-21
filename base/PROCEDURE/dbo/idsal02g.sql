SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Stored Procedure: idsAL02G                                           */  
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
CREATE PROC    idsAL02G  
 @c_lot NVARCHAR(10) ,  
 @c_uom NVARCHAR(10) ,  
 @c_HostWHCode NVARCHAR(10),  
 @c_facility NVARCHAR(5),  
 @n_uombase int ,  
 @n_qtylefttofulfill int,  
 @c_OtherParms NVARCHAR(200)  
 AS  
 BEGIN  
   SET NOCOUNT ON  
  
    Declare @b_debug int,  
            @c_ord_lottable03 NVARCHAR(18)  
  
    -- Get OrderKey and line Number  
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
       and orderlinenumber = @c_OrderLineNumber  

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
       DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   
          SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,  
                 QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'  
          FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)  
          WHERE LOTxLOCxID.Lot = @c_lot  
          AND LOTxLOCxID.Loc = LOC.LOC  
          AND LOTxLOCxID.ID = ID.ID  
          AND ID.Status <> "HOLD"  
          AND LOC.Locationflag <> "HOLD"  
          AND LOC.Locationflag <> "DAMAGE"  
          AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase  
          AND LOC.Status <> "HOLD"  
          and loc.facility = @c_facility   
          AND LOC.PutAwayZone NOT IN (SELECT CODE FROM CODELKUP WITH (NOLOCK) WHERE ListName = 'U2K2ORDTYP') -- SHONG01
          AND (LOC.locationtype = 'DOUBLEDEEP' OR LOC.locationtype = 'SELECTIVE' or LOC.locationtype = 'DRIVEIN')  
          ORDER BY CASE LOC.Putawayzone WHEN 'GOLD' THEN 0 WHEN NULL THEN 1 WHEN ' ' THEN 2 ELSE 3 END ASC, LOC.locationtype, LOTxLOCxID.LOC  
     END  
     ELSE  
     IF ISNULL(RTRIM(@c_FilterZone),'') <> '' 
     BEGIN  
        DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   
          SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,  
                 QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'  
          FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)  
          WHERE LOTxLOCxID.Lot = @c_lot  
          AND LOTxLOCxID.Loc = LOC.LOC  
          AND LOTxLOCxID.ID = ID.ID  
          AND ID.Status <> "HOLD"  
          AND LOC.Locationflag <> "HOLD"  
          AND LOC.Locationflag <> "DAMAGE"  
          AND LOC.Putawayzone = @c_FilterZone
          AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase  
          AND LOC.Status <> "HOLD"  
          AND LOC.Facility = @c_facility   
          AND (LOC.locationtype = 'DOUBLEDEEP' OR LOC.locationtype = 'SELECTIVE' or LOC.locationtype = 'DRIVEIN')  
          ORDER BY CASE LOC.Putawayzone WHEN 'GOLD' THEN 0 WHEN NULL THEN 1 WHEN ' ' THEN 2 ELSE 3 END ASC, LOC.locationtype, LOTxLOCxID.LOC  
    END       
    ELSE
    BEGIN  
        DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   
          SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,  
                 QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'  
          FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)  
          WHERE LOTxLOCxID.Lot = @c_lot  
          AND LOTxLOCxID.Loc = LOC.LOC  
          AND LOTxLOCxID.ID = ID.ID  
          AND ID.Status <> "HOLD"  
          AND LOC.Locationflag <> "HOLD"  
          AND LOC.Locationflag <> "DAMAGE"  
          AND LOC.Putawayzone <> "GOLD"
          AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase  
          AND LOC.Status <> "HOLD"  
          AND LOC.Facility = @c_facility   
          AND LOC.PutAwayZone NOT IN (SELECT CODE FROM CODELKUP WITH (NOLOCK) WHERE ListName = 'U2K2ORDTYP') -- SHONG01
          AND (LOC.locationtype = 'DOUBLEDEEP' OR LOC.locationtype = 'SELECTIVE' or LOC.locationtype = 'DRIVEIN')  
          ORDER BY CASE LOC.Putawayzone WHEN 'GOLD' THEN 0 WHEN NULL THEN 1 WHEN ' ' THEN 2 ELSE 3 END ASC, LOC.locationtype, LOTxLOCxID.LOC  
    END       
END  

GO