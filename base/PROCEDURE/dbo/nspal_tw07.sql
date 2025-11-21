SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspAL_TW07                                         */
/* Creation Date: 28-Sep-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-18018 - Filter LocationCategory                         */
/*          Copy from nspAL_TW07                                        */
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
CREATE PROC [dbo].[nspAL_TW07]
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
      IF (dbo.fnc_RTrim(@c_HostWHCode) IS NOT NULL AND dbo.fnc_RTrim(@c_HostWHCode) <> '') 
          OR (EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)  
                          WHERE CL.Storerkey = @c_Storerkey  
                          AND CL.Code = 'NOFILTERHWCODE'  
                          AND CL.Listname = 'PKCODECFG'  
                          AND CL.Long = 'nspAL_TW07'  
                          AND ISNULL(CL.Short,'') = 'N'))  --NJOW01
      BEGIN  
         DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR    
         SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,  
         QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'  
         FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK), SKUxLOC (NOLOCK)  
         WHERE LOTxLOCxID.Lot = @c_lot  
         AND LOTxLOCxID.Loc = LOC.LOC  
         AND LOTxLOCxID.Loc = SKUxLOC.Loc  
         AND LOTxLOCxID.Sku = SKUxLOC.Sku  
         AND LOTxLOCxID.ID = ID.ID  
         AND ID.Status <> 'HOLD'  
         AND LOC.Facility = @c_Facility   
         AND LOC.Locationflag <> 'HOLD'  
         AND LOC.Locationflag <> 'DAMAGE'  
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase  
         AND LOC.Status <> 'HOLD'  
         AND SKUxLOC.LocationType NOT IN ('PICK', 'CASE')  
         AND ISNULL(LOC.HostWhCode,'') = @c_HostWHCode  
         AND LOC.LocationCategory NOT IN (SELECT DISTINCT ColValue FROM dbo.fnc_delimsplit (',', TRIM(@c_LocationCategory) ) ) 
         ORDER BY LOTxLOCxID.LOC  
      END  
      ELSE  
      BEGIN  
         DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR    
         SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,  
         QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'  
         FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK), SKUxLOC (NOLOCK)  
         WHERE LOTxLOCxID.Lot = @c_lot  
         AND LOTxLOCxID.Loc = LOC.LOC  
         AND LOTxLOCxID.Loc = SKUxLOC.Loc  
         AND LOTxLOCxID.Sku = SKUxLOC.Sku  
         AND LOTxLOCxID.ID = ID.ID  
         AND ID.Status <> 'HOLD'  
         AND LOC.Facility = @c_Facility   
         AND LOC.Locationflag <> 'HOLD'  
         AND LOC.Locationflag <> 'DAMAGE'  
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase  
         AND LOC.Status <> 'HOLD'  
         AND SKUxLOC.LocationType NOT IN ('PICK', 'CASE')  
         AND LOC.LocationCategory NOT IN (SELECT DISTINCT ColValue FROM dbo.fnc_delimsplit (',', TRIM(@c_LocationCategory) ) ) 
         ORDER BY LOTxLOCxID.LOC  
      END  
   END
   ELSE
   BEGIN
      IF (dbo.fnc_RTrim(@c_HostWHCode) IS NOT NULL AND dbo.fnc_RTrim(@c_HostWHCode) <> '') 
          OR (EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)  
                          WHERE CL.Storerkey = @c_Storerkey  
                          AND CL.Code = 'NOFILTERHWCODE'  
                          AND CL.Listname = 'PKCODECFG'  
                          AND CL.Long = 'nspAL_TW07'  
                          AND ISNULL(CL.Short,'') = 'N'))  --NJOW01
      BEGIN  
         DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR    
         SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,  
         QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'  
         FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK), SKUxLOC (NOLOCK)  
         WHERE LOTxLOCxID.Lot = @c_lot  
         AND LOTxLOCxID.Loc = LOC.LOC  
         AND LOTxLOCxID.Loc = SKUxLOC.Loc  
         AND LOTxLOCxID.Sku = SKUxLOC.Sku  
         AND LOTxLOCxID.ID = ID.ID  
         AND ID.Status <> 'HOLD'  
         AND LOC.Facility = @c_Facility   
         AND LOC.Locationflag <> 'HOLD'  
         AND LOC.Locationflag <> 'DAMAGE'  
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase  
         AND LOC.Status <> 'HOLD'  
         AND SKUxLOC.LocationType NOT IN ('PICK', 'CASE')  
         AND ISNULL(LOC.HostWhCode,'') = @c_HostWHCode  
         ORDER BY LOTxLOCxID.LOC  
      END  
      ELSE  
      BEGIN  
         DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR    
         SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,  
         QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1'  
         FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK), SKUxLOC (NOLOCK)  
         WHERE LOTxLOCxID.Lot = @c_lot  
         AND LOTxLOCxID.Loc = LOC.LOC  
         AND LOTxLOCxID.Loc = SKUxLOC.Loc  
         AND LOTxLOCxID.Sku = SKUxLOC.Sku  
         AND LOTxLOCxID.ID = ID.ID  
         AND ID.Status <> 'HOLD'  
         AND LOC.Facility = @c_Facility   
         AND LOC.Locationflag <> 'HOLD'  
         AND LOC.Locationflag <> 'DAMAGE'  
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase  
         AND LOC.Status <> 'HOLD'  
         AND SKUxLOC.LocationType NOT IN ('PICK', 'CASE')  
         ORDER BY LOTxLOCxID.LOC  
      END
   END 
END

GO