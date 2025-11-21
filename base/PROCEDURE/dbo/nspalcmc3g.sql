SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspALCMC3G                                         */
/* Creation Date: 29-Aug-2007                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 29-Aug-2007	 James			SOS83546 - modified from nspALCMC01       */
/*                            ignore location type when allocating      */
/* 19-Nov-2008   Vanessa      SOS#117139 Add checking Loc.Putawayzone<>'GOLDC' */
/************************************************************************/

CREATE PROC [dbo].[nspALCMC3G]
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

    -- Get OrderKey and line Number
    DECLARE @c_OrderKey   NVARCHAR(10),
            @c_OrderLineNumber NVARCHAR(5)

    IF dbo.fnc_RTrim(@c_OtherParms) IS NOT NULL AND dbo.fnc_RTrim(@c_OtherParms) <> ''
    BEGIN
       SELECT @c_OrderKey = LEFT(dbo.fnc_LTrim(@c_OtherParms), 10)
       SELECT @c_OrderLineNumber = SUBSTRING(dbo.fnc_LTrim(@c_OtherParms), 11, 5)

       SELECT @c_ord_lottable03=Lottable03 
       from OrderDetail (NOLOCK)
       where OrderKey = @c_OrderKey
       and orderlinenumber = @c_OrderLineNumber
    END

    IF ISNULL(dbo.fnc_RTRIM(@c_ord_lottable03),'') = 'GOLD'
    BEGIN
	    DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
	    SELECT 
	 	   LOTxLOCxID.LOC, 
	 	   LOTxLOCxID.ID,
	 	   QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), 
	 	   '1'
	    FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK)
	    WHERE LOTxLOCxID.Lot = @c_lot
	    AND LOTxLOCxID.Loc = LOC.LOC
	    AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
	    AND LOTxLOCxID.Sku = SKUxLOC.Sku
	    AND LOTxLOCxID.Loc = SKUxLOC.Loc
	    AND LOC.Locationflag = 'NONE' 
	    AND LOC.Facility = @c_Facility
	    ORDER BY CASE LOC.Putawayzone WHEN 'GOLDC' THEN 0 WHEN NULL THEN 1 WHEN ' ' THEN 2 ELSE 3 END ASC, loc.hostwhcode, LOC.LOC
    END
    ELSE
    BEGIN
	    DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
	    SELECT 
	 	   LOTxLOCxID.LOC, 
	 	   LOTxLOCxID.ID,
	 	   QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), 
	 	   '1'
	    FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK)
	    WHERE LOTxLOCxID.Lot = @c_lot
	    AND LOTxLOCxID.Loc = LOC.LOC
	    AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey
	    AND LOTxLOCxID.Sku = SKUxLOC.Sku
	    AND LOTxLOCxID.Loc = SKUxLOC.Loc
	    AND LOC.Locationflag = 'NONE' 
	    AND LOC.Facility = @c_Facility
       AND LOC.Putawayzone <> 'GOLD'
	    ORDER BY CASE LOC.Putawayzone WHEN 'GOLDC' THEN 0 WHEN NULL THEN 1 WHEN ' ' THEN 2 ELSE 3 END ASC, loc.hostwhcode, LOC.LOC
    END
 END

GO