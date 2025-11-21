SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspALTWHT1                                         */
/* Creation Date: 21-Jul-2015                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 346270-TW HHT-Allocation from bulk                          */
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
/* Date         Author   Purposes                                       */
/* 26-Nov-2019  Wan01    1.3 Dynamic SQL review, impact SQL cache log   */ 
/************************************************************************/

CREATE PROC [dbo].[nspALTWHT1]
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
   
   DECLARE @c_Condition NVARCHAR(1500)

   DECLARE @c_SQL       NVARCHAR(3999)  = ''       --(Wan01)   
         , @c_SQLParm   NVARCHAR(3999)  = ''       --(Wan01)             
   
   IF ISNULL(@c_HostWHCode,'') <> ''
   BEGIN
        SELECT @c_Condition = RTRIM(ISNULL(@c_Condition,'')) + " AND LOC.HostWhCode = RTRIM(ISNULL(@c_HostWHCode,'')) " --(Wan01)       
   END 
   
   IF @c_UOM = '1'
   BEGIN
        SELECT @c_Condition = RTRIM(ISNULL(@c_Condition,'')) + " AND SKUXLOC.LocationType NOT IN('PICK','CASE') "      
        SELECT @c_Condition = RTRIM(ISNULL(@c_Condition,'')) + " AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase" --(Wan01)
        SELECT @c_Condition = RTRIM(ISNULL(@c_Condition,'')) + " ORDER BY LOC.LogicalLocation, LOC.LOC "   
   END
   ELSE
   BEGIN
        SELECT @c_Condition = RTRIM(ISNULL(@c_Condition,'')) + " ORDER BY CASE WHEN SKUXLOC.LocationType IN('PICK','CASE') THEN 0 ELSE 1 END,
                                                                          CASE WHEN (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) < PACK.Pallet THEN
                                                                          0 ELSE 1 END, LOC.LogicalLocation, LOC.LOC "    
        --SELECT @c_Condition = RTRIM(ISNULL(@c_Condition,'')) + " ORDER BY CASE WHEN (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) < PACK.Pallet THEN
        --                                                                  0 ELSE 1 END, LOC.LogicalLocation, LOC.LOC "     
   END
   
   SET @c_SQL = "DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR" +
         " SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID, " +
         " QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1' " +
         " FROM LOTxLOCxID (NOLOCK) " +
         " JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC) " +
         " JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID) " +
         " JOIN SKUXLOC (NOLOCK) ON (LOTxLOCxID.Storerkey =  SKUXLOC.Storerkey AND LOTxLOCxID.Sku = SKUXLOC.Sku AND LOTxLOCxID.Loc =  SKUXLOC.Loc) " +
         " JOIN SKU (NOLOCK) ON (LOTxLOCxID.Storerkey =  SKU.Storerkey AND SKU.Sku =  SKUXLOC.Sku) " +
         " JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey) " +
         " WHERE LOTxLOCxID.Lot = @c_lot " +             --(Wan01)
         --" AND SKUXLOC.LocationType NOT IN('PICK','CASE') " +
         " AND LOC.Locationflag <> 'HOLD' "+ 
         " AND LOC.Locationflag <> 'DAMAGE' " +
         " AND LOC.Status <> 'HOLD' " +
         " AND LOC.Facility = @c_Facility " +            --(Wan01)
         " AND ID.STATUS <> 'HOLD' " +
         @c_Condition 
         
      --(Wan01) - START
      SET @c_SQLParm =N' @c_Facility   NVARCHAR(5)'
                     + ',@c_Lot        NVARCHAR(10)'
                     + ',@c_HostWHCode NVARCHAR(10)'     
                     + ',@n_uombase    INT '       
      
      EXEC sp_ExecuteSQL @c_SQL
                     , @c_SQLParm
                     , @c_Facility
                     , @c_Lot
                     , @c_HostWHCode
                     , @n_uombase
      --(Wan01) - END   
END

GO