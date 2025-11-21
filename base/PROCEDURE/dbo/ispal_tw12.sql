SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispAL_TW12                                         */
/* Creation Date: 19-JUN-2019                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-9841-TW Allocation for FMCG                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   VER  Purposes                                  */  
/* 23-AUG-2019  NJOW01   1.0  Fix to filter hostwhcode                  */
/* 28-Nov-2019  Wan01    1.1  Dynamic SQL review, impact SQL cache log  */ 
/************************************************************************/

CREATE PROC [dbo].[ispAL_TW12] 
@c_lot NVARCHAR(10) ,
@c_uom NVARCHAR(10) ,
@c_HostWHCode NVARCHAR(10),
@c_Facility NVARCHAR(5),
@n_uombase int ,
@n_qtylefttofulfill int,
@c_OtherParms NVARCHAR(200) = ''         
AS
BEGIN
   SET NOCOUNT ON 
   
	 DECLARE @c_SQLStatement    NVARCHAR(MAX), 
           @c_Condition       NVARCHAR(MAX),
           @c_OrderBy         NVARCHAR(2000)
           
   SELECT @c_OrderBy = " ORDER BY LOC.LogicalLocation, LOC.LOC "

   IF @c_UOM = '1'
      SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'')  + " AND SKUXLOC.LocationType NOT IN ('PICK','CASE') AND LOC.PickZone NOT IN (SELECT PickZone FROM PICKZONE(NOLOCK) WHERE ZoneCategory = 'PC') "   

   IF @c_UOM IN ('2','7')  --For overallocation
   BEGIN
      SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'')  + " AND LOC.PickZone NOT IN (SELECT PickZone FROM PICKZONE(NOLOCK) WHERE ZoneCategory = 'PC') "   
      SELECT @c_OrderBy = " ORDER BY CASE WHEN SKUXLOC.LocationType IN ('PICK','CASE') THEN 1 ELSE 2 END, LOC.LogicalLocation, LOC.LOC "
   END

   IF @c_UOM = '6'
      SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'')  + " AND LOC.PickZone IN (SELECT PickZone FROM PICKZONE(NOLOCK) WHERE ZoneCategory = 'PC') "   
   
   --NJOW01   
   IF ISNULL(@c_HostWHCode,'') <> ''
   BEGIN
      SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'')  + " AND LOC.HostWhCode = RTRIM(@c_HostWHCode) "
   END   

   SELECT @c_SQLStatement  = " DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY " +
                             " FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID, " +
                             "            QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen), '' " +
                             " FROM LOTxLOCxID (NOLOCK) " +
                             " JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC " +
                             " JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Storerkey = SKUxLOC.Storerkey AND LOTxLOCxID.Sku = SKUxLOC.Sku " +
                             "                          AND LOTxLOCxID.Loc = SKUxLOC.Loc " +
                             " JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID " +
                             " WHERE LOTxLOCxID.Lot = @c_lot " +
                             " AND LOC.Facility = @c_Facility " +
                             " AND LOC.Locationflag <>'HOLD' " +
                             " AND LOC.Locationflag <> 'DAMAGE' " +
                             " AND LOC.Status <> 'HOLD' " +
                             " AND ID.Status = 'OK' " +
                             " AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0  " +
                             ISNULL(RTRIM(@c_Condition),'') +
                             ISNULL(RTRIM(@c_OrderBy),'') 
                             
                             
   EXEC sp_executesql @c_SQLStatement,
      N'@c_Lot NVARCHAR(10), @c_Facility NVARCHAR(5), @c_HostWHCode NVARCHAR(10) ',    --(Wan01) 
      @c_Lot,
      @c_Facility
     ,@c_HostWHCode                                                                    --(Wan01)   
                             	                                                     
END

GO