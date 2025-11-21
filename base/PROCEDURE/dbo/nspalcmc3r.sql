SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspALCMC3R                                         */
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

CREATE PROC [dbo].[nspALCMC3R]
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
    AND LOC.Putawayzone <> 'GOLDC'   -- (SOS#117139)
	 ORDER BY loc.hostwhcode, LOC.LOC
 END

GO