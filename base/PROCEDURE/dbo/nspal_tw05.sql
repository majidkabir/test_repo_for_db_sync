SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspAL_TW05                                         */
/* Creation Date: 28-Sep-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-18018 - Filter LocationCategory                         */
/*          Copy from nspAL01_08                                        */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver Purposes                                    */
/* 28-Sep-2021  WLChooi 1.0 DevOps Combine Script                       */
/************************************************************************/
CREATE PROC [dbo].[nspAL_TW05]
     @c_lot                NVARCHAR(10)
   , @c_uom                NVARCHAR(10)
   , @c_HostWHCode         NVARCHAR(10)
   , @c_Facility           NVARCHAR(5)
   , @n_uombase            INT
   , @n_qtylefttofulfill   INT
   , @c_OtherParms         NVARCHAR(200) = ''
AS
BEGIN
   SET NOCOUNT ON                     
   SET ANSI_NULLS OFF                    
   SET QUOTED_IDENTIFIER OFF                     
   SET CONCAT_NULL_YIELDS_NULL OFF   

   DECLARE @b_debug          Int      
         , @nMinShelfLife    INT   
      
   SELECT @b_debug = 0      
      
   -- Get OrderKey and line Number      
   DECLARE @c_OrderKey         NVARCHAR(10)      
         , @c_OrderLineNumber  NVARCHAR(5) 
         , @c_LocationCategory NVARCHAR(255) = ''
         , @c_Storerkey        NVARCHAR(15)

   SELECT @c_Storerkey = Storerkey
   FROM LOT (NOLOCK)
   WHERE Lot = @c_Lot

   SELECT @c_LocationCategory = ISNULL(CL.Code2,'')
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.LISTNAME = 'PKCODECFG'
   AND CL.Code = 'FILTERLOCCATEGRY'
   AND CL.Short = 'Y'
   AND CL.Storerkey = @c_StorerKey
   
   IF ISNULL(@c_LocationCategory,'') <> ''
   BEGIN
      IF dbo.fnc_RTrim(@c_HostWHCode) IS NOT NULL AND dbo.fnc_RTrim(@c_HostWHCode) <> ''
      BEGIN
         DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID,
         QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
         FROM LOTxLOCxID (NOLOCK) 
         JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
         JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID) 
         WHERE LOTxLOCxID.Lot = @c_lot
         AND LOC.Locationflag <> 'HOLD'
         AND LOC.Locationflag <> 'DAMAGE'
         AND LOC.Status <> 'HOLD'
         AND LOC.Facility = @c_Facility
         AND ID.STATUS <> 'HOLD'
         AND LOC.HostWhCode = @c_HostWHCode
         AND LOC.LocationCategory NOT IN (SELECT DISTINCT ColValue FROM dbo.fnc_delimsplit (',', TRIM(@c_LocationCategory) ) ) 
         ORDER BY LOC.LOC
      END
      ELSE
      BEGIN
         DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID,
         QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
         FROM LOTxLOCxID (NOLOCK) 
         JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
         JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID) 
         WHERE LOTxLOCxID.Lot = @c_lot
         AND LOC.Locationflag <> 'HOLD'
         AND LOC.Locationflag <> 'DAMAGE'
         AND LOC.Status <> 'HOLD'
         AND LOC.Facility = @c_Facility
         AND ID.STATUS <> 'HOLD'
         AND LOC.LocationCategory NOT IN (SELECT DISTINCT ColValue FROM dbo.fnc_delimsplit (',', TRIM(@c_LocationCategory) ) ) 
         ORDER BY LOC.LOC
      END
   END
   ELSE
   BEGIN
      IF dbo.fnc_RTrim(@c_HostWHCode) IS NOT NULL AND dbo.fnc_RTrim(@c_HostWHCode) <> ''
      BEGIN
         DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID,
         QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
         FROM LOTxLOCxID (NOLOCK) 
         JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
         JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID) 
         WHERE LOTxLOCxID.Lot = @c_lot
         AND LOC.Locationflag <> 'HOLD'
         AND LOC.Locationflag <> 'DAMAGE'
         AND LOC.Status <> 'HOLD'
         AND LOC.Facility = @c_Facility
         AND ID.STATUS <> 'HOLD'
         AND LOC.HostWhCode = @c_HostWHCode
         ORDER BY LOC.LOC
      END
      ELSE
      BEGIN
         DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID,
         QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'
         FROM LOTxLOCxID (NOLOCK) 
         JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
         JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID) 
         WHERE LOTxLOCxID.Lot = @c_lot
         AND LOC.Locationflag <> 'HOLD'
         AND LOC.Locationflag <> 'DAMAGE'
         AND LOC.Status <> 'HOLD'
         AND LOC.Facility = @c_Facility
         AND ID.STATUS <> 'HOLD'
         ORDER BY LOC.LOC
      END
   END
END

GO