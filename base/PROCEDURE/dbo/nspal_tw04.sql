SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspAL_TW04                                         */
/* Creation Date: 28-Sep-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-18018 - Filter LocationCategory                         */
/*          Copy from nspAL00002                                        */
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
CREATE PROC [dbo].[nspAL_TW04]
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

   IF ISNULL(RTRIM(@c_OtherParms),'') <> ''      
   BEGIN 
      SET @nMinShelfLife = 0  
      -- 
   END      
   
   SET @c_UOM = '2'
   SET @n_UOMBASE = 0
   SELECT @n_UOMBASE = ISNULL(P.CaseCnt,0) 
   FROM LOT WITH (NOLOCK)
   JOIN SKU s WITH (NOLOCK) ON s.StorerKey = LOT.StorerKey AND s.Sku = LOT.Sku 
   JOIN PACK p WITH (NOLOCK) ON p.PACKKey = s.PACKKey 
   WHERE LOT.Lot = @c_LOT

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
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR       
      SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID,      
             QTYAVAILABLE = CASE   
                  WHEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) -    
                                (LOTXLOCXID.QTYPICKED) ) < @n_UOMBASE    
                            THEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED)   
                              - (LOTXLOCXID.QTYPICKED)  )   
                  WHEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) -   
                                (LOTXLOCXID.QTYPICKED)  ) %   @n_UOMBASE = 0                            
                     THEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED)   
                              - (LOTXLOCXID.QTYPICKED)  )   
                  ELSE   
                     ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED)  )   
                     -  ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED)  ) %    
                     @n_UOMBASE  
                 END              
           , 1     
      FROM LOTxLOCxID (NOLOCK)       
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)       
      JOIN SKUxLOC (NOLOCK) ON (LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND       
                             LOTxLOCxID.SKU = SKUxLOC.SKU AND       
                             LOTxLOCxID.Loc = SKUxLOC.LOC)      
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)       
      WHERE LOTxLOCxID.Lot = @c_lot      
      AND LOC.Locationflag <> 'HOLD'      
      AND LOC.Locationflag <> 'DAMAGE'      
      AND LOC.Status <> 'HOLD'      
      AND LOC.Facility = @c_Facility      
      AND ID.STATUS <> 'HOLD'  
      AND LOC.HostWhCode = CASE WHEN ISNULL(RTRIM(@c_HostWHCode), '') <> '' THEN @c_HostWHCode ELSE LOC.HostWhCode END        
      AND CASE   
               WHEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) -    
                          (LOTXLOCXID.QTYPICKED) ) < @n_UOMBASE    
                      THEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED)   
                        - (LOTXLOCXID.QTYPICKED)  )   
               WHEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) -   
                          (LOTXLOCXID.QTYPICKED)  ) %   @n_UOMBASE = 0                            
                      THEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED)   
                        - (LOTXLOCXID.QTYPICKED)  )   
               ELSE   
                  ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED)  )   
                  -  ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED)  ) %    
                 @n_UOMBASE  
          END > 0 
      AND LOC.LocationCategory NOT IN (SELECT DISTINCT ColValue FROM dbo.fnc_delimsplit (',', TRIM(@c_LocationCategory) ) ) 
      ORDER BY   
         ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED)  ),          
         LOC.LogicalLocation,         
         LOC.LOC
   END
   ELSE
   BEGIN
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR       
      SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID,      
             QTYAVAILABLE = CASE   
                  WHEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) -    
                                (LOTXLOCXID.QTYPICKED) ) < @n_UOMBASE    
                            THEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED)   
                              - (LOTXLOCXID.QTYPICKED)  )   
                  WHEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) -   
                                (LOTXLOCXID.QTYPICKED)  ) %   @n_UOMBASE = 0                            
                     THEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED)   
                              - (LOTXLOCXID.QTYPICKED)  )   
                  ELSE   
                     ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED)  )   
                     -  ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED)  ) %    
                     @n_UOMBASE  
                 END              
           , 1     
      FROM LOTxLOCxID (NOLOCK)       
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)       
      JOIN SKUxLOC (NOLOCK) ON (LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND       
                             LOTxLOCxID.SKU = SKUxLOC.SKU AND       
                             LOTxLOCxID.Loc = SKUxLOC.LOC)      
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)       
      WHERE LOTxLOCxID.Lot = @c_lot      
      AND LOC.Locationflag <> 'HOLD'      
      AND LOC.Locationflag <> 'DAMAGE'      
      AND LOC.Status <> 'HOLD'      
      AND LOC.Facility = @c_Facility      
      AND ID.STATUS <> 'HOLD'  
      AND LOC.HostWhCode = CASE WHEN ISNULL(RTRIM(@c_HostWHCode), '') <> '' THEN @c_HostWHCode ELSE LOC.HostWhCode END        
      AND CASE   
               WHEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) -    
                          (LOTXLOCXID.QTYPICKED) ) < @n_UOMBASE    
                      THEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED)   
                        - (LOTXLOCXID.QTYPICKED)  )   
               WHEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) -   
                          (LOTXLOCXID.QTYPICKED)  ) %   @n_UOMBASE = 0                            
                      THEN ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED)   
                        - (LOTXLOCXID.QTYPICKED)  )   
               ELSE   
                  ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED)  )   
                  -  ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED)  ) %    
                 @n_UOMBASE  
          END > 0 
      ORDER BY   
         ( (LOTXLOCXID.QTY) - (LOTXLOCXID.QTYALLOCATED) - (LOTXLOCXID.QTYPICKED)  ),          
         LOC.LogicalLocation,         
         LOC.LOC
   END 
END

GO