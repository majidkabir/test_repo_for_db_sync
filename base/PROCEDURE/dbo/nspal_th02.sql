SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspAL_TH02                                         */
/* Creation Date: 01-APR-2014                                           */
/* Copyright: LF                                                        */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#306941 - FBR-TH WMS Allocation Strategy-FIFO order      */
/*          by ID Descending                                            */
/*          1) Order By Loc, ID DESC If UOM = 1                         */
/*          2) Order By Loc, QtyAvailable, ID DESC IF UOM = 6           */
/*                                                                      */
/* Called By: nspLoadProcessing		                                    */
/*                                                                      */
/* PVCS Version: 1.0		                                                */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author Ver. Purposes                                    */
/************************************************************************/

CREATE PROC [dbo].[nspAL_TH02]
@c_lot NVARCHAR(10) ,
@c_uom NVARCHAR(10) ,
@c_HostWHCode NVARCHAR(10),
@c_Facility NVARCHAR(5),
@n_uombase int ,
@n_qtylefttofulfill int,
@c_OtherParms NVARCHAR(20) = ''         
AS
BEGIN
   SET NOCOUNT ON 
    
   DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY
   FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,
   QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
   FROM LOTxLOCxID WITH (NOLOCK)
   JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
   JOIN ID  WITH (NOLOCK) ON (LOTxLOCxID.ID = ID.ID)
   WHERE LOTxLOCxID.Lot = @c_lot
   AND ID.Status <> 'HOLD'
   AND LOC.Locationflag <> 'HOLD'
   AND LOC.Locationflag <> 'DAMAGE'
   AND 1 = CASE WHEN @c_uom = 1 AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) = @n_uombase THEN 1
                WHEN @c_uom = 6 AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >=@n_uombase THEN 1
                ELSE 2 END
   AND LOC.Status <> 'HOLD'
   AND LOC.Facility = @c_Facility
   ORDER BY LOTxLOCxID.Loc                      --Order By Loc 
         ,  CASE WHEN @c_uom = 1 
                 THEN 0 
                 ELSE (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) * (-1) 
                 END DESC
          , LOTxLOCxID.ID DESC

END


GO