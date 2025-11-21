SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: nspPRTWPG4                                         */    
/* Creation Date:                                                       */    
/* Copyright: LF Logistics                                              */    
/* Written by: Shong                                                    */    
/*                                                                      */    
/* Purpose: Sort by Lottable04, Lottable05                              */    
/*          Getting from Location with Full Pallet Only                 */    
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
/* Date         Author  Ver.  Purposes                                  */    
/* 10-Feb-2014  Shong   1.0   P&G VIP Handling                          */  
/* 19-Sep-2016  NJOW01  1.1   WMS-248 case from pick and bulk           */
/* 22-Sep-2021  WLChooi 1.2   DEVOPS Combine Script                     */
/* 22-Sep-2021  WLChooi 1.3   WMS-18018 - Filter LocationCategory based */
/*                            on Codelkup (WL01)                        */
/************************************************************************/  
CREATE PROC [dbo].[nspPRTWPG4] (      
   @c_StorerKey NVARCHAR(15) ,        
   @c_SKU NVARCHAR(20) ,        
   @c_LOT NVARCHAR(10) ,        
   @c_Lottable01 NVARCHAR(18) ,        
   @c_Lottable02 NVARCHAR(18) ,        
   @c_Lottable03 NVARCHAR(18) ,        
   @d_Lottable04 datetime ,        
   @d_Lottable05 datetime ,        
   @c_UOM NVARCHAR(10) ,        
   @c_Facility NVARCHAR(10)  ,  -- added By Ricky for IDSV5        
   @n_UOMBase int ,        
   @n_QtyLeftToFulfill int,        
   @c_OtherParms NVARCHAR(20) = '' 
)        
AS        
BEGIN        
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF         
              
   DECLARE @n_ConsigneeMinShelfLife int,        
           @c_Condition NVARCHAR(MAX),         
           @c_UOMBase   NVARCHAR(10)        
           
   SET @c_UOMBase = RTRIM(CAST ( @n_uombase AS NVARCHAR(10)))        

   --WL01 S
   DECLARE @c_LocationCategory       NVARCHAR(255) = ''
   
   SELECT @c_LocationCategory = ISNULL(CL.Code2,'')
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.LISTNAME = 'PKCODECFG'
   AND CL.Code = 'FILTERLOCCATEGRY'
   AND CL.Short = 'Y'
   AND CL.Storerkey = @c_StorerKey
   --WL01 E 
        
   IF ISNULL(LTRIM(RTRIM(@c_LOT)) ,'') <> '' AND LEFT(@c_LOT ,1) <> '*'        
   BEGIN        
        
      /* Get Storer Minimum Shelf Life */        
      SELECT @n_ConsigneeMinShelfLife = ISNULL(Storer.MinShelflife, 0)        
      FROM   STORER (NOLOCK)        
      WHERE  StorerKey = @c_Lottable03        
        
      SELECT @n_ConsigneeMinShelfLife = ((ISNULL(Sku.Shelflife,0) * @n_ConsigneeMinShelfLife /100) * -1)        
      FROM  Sku (NOLOCK)        
      WHERE Sku.Sku = @c_SKU        
      AND   Sku.StorerKey = @c_StorerKey        
        
      DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY        
      FOR         
      SELECT LOT.StorerKey,LOT.SKU,LOT.LOT ,        
      QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)        
      FROM LOT (NOLOCK), Lotattribute (NOLOCK), LOTxLOCxID (NOLOCK), LOC (NOLOCK)         
      WHERE LOT.LOT = @c_LOT         
      AND Lot.Lot = Lotattribute.Lot         
      AND LOTxLOCxID.Lot = LOT.LOT        
      AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT        
      AND LOTxLOCxID.LOC = LOC.LOC        
      AND LOC.Facility = @c_Facility        
      AND DateAdd(Day, @n_ConsigneeMinShelfLife, Lotattribute.Lottable04) > GetDate()         
      ORDER BY Lotattribute.Lottable04, Lot.Lot        
        
   END        
   ELSE        
   BEGIN        
        
      IF @c_UOM = '7' AND LEFT(RTRIM(@c_LOT),1) <> '*'        
      BEGIN        
         DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR         
         SELECT LOT.StorerKey, LOT.SKU, LOT.LOT, 0          
         FROM LOT WITH (NOLOCK)         
         WHERE 1=2                  
        
         GOTO EXIT_SP        
      END        
        
      BEGIN        
         DECLARE @c_OrderKey  NVARCHAR(10),         
                 @c_OrderType NVARCHAR(10)        
                 
         IF LEN(@c_OtherParms) > 0         
         BEGIN        
            SET @c_OrderKey = LEFT(@c_OtherParms,10)         
                    
            SET @c_OrderType = ''        
            SELECT @c_OrderType = TYPE         
            FROM   ORDERS WITH (NOLOCK)        
            WHERE  OrderKey = @c_OrderKey        
                    
            IF @c_OrderType = 'VAS'        
            BEGIN        
               SELECT @c_Condition = RTRIM(@c_Condition) + " AND RIGHT(RTRIM(Lotattribute.Lottable02),1) <> 'Z' "         
            END        
         END        
      END 
      
      --WL01 S
      IF ISNULL(@c_LocationCategory,'') <> ''
      BEGIN
         SELECT @c_Condition = RTRIM(@c_Condition) +
                               ' AND LOC.LocationCategory NOT IN (SELECT DISTINCT ColValue FROM dbo.fnc_delimsplit ('','', N''' + @c_LocationCategory + ''') ) '
      END
      --WL01 E       
              
      IF LEN(ISNULL(RTRIM(@c_LOT),'')) > 1 AND LEFT(@c_LOT,1) = '*'        
      BEGIN                  
         -- Minimum Shelf Life provided  
         SELECT @n_ConsigneeMinShelfLife = CASE WHEN ISNUMERIC(RIGHT(RTRIM(@c_LOT), LEN(RTRIM(@c_LOT)) - 1)) = 1         
                                                   THEN CAST(RIGHT(RTRIM(@c_LOT), LEN(RTRIM(@c_LOT)) - 1) AS INT) * -1        
                                                ELSE 0        
                                           END    
      END       
      IF ISNULL(@n_ConsigneeMinShelfLife,0) = 0        
      BEGIN  
         /* Get Storer Minimum Shelf Life */        
         /* Lottable03 = Consignee Key */      
         SELECT @n_ConsigneeMinShelfLife = ISNULL(Storer.MinShelflife, 0)        
         FROM   STORER (NOLOCK)         
         WHERE  StorerKey = RTRIM(@c_Lottable03)         
        
         SELECT @n_ConsigneeMinShelfLife = ((ISNULL(Sku.Shelflife,0) * @n_ConsigneeMinShelfLife /100) * -1)        
         FROM  Sku (NOLOCK)        
         WHERE Sku.Sku = @c_SKU        
         AND   Sku.StorerKey = @c_StorerKey         
        
         IF @n_ConsigneeMinShelfLife IS NULL        
            SELECT @n_ConsigneeMinShelfLife = 0         
      END              
           
      -- Lottable01 is used for loc.HostWhCode -- modified by Jeff        
      IF ISNULL(RTRIM(@c_Lottable01),'') <> '' AND @c_Lottable01 IS NOT NULL        
      BEGIN           SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOC.HostWhCode = N'" + ISNULL(RTRIM(@c_Lottable01),'') + "' "        
      END        
        
      IF ISNULL(RTRIM(@c_Lottable02),'') <> '' AND @c_Lottable02 IS NOT NULL        
      BEGIN        
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND Lottable02 = N'" + ISNULL(RTRIM(@c_Lottable02),'') + "' "        
      END        
        
      IF CONVERT(char(8), @d_Lottable04, 112) <> '19000101' AND @d_Lottable04 IS NOT NULL        
      BEGIN        
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND (Lotattribute.Lottable04 >= N'" + RTRIM(CONVERT(char(8), @d_Lottable04, 112)) + "') "         
      END        
      ELSE        
      BEGIN        
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND (DateAdd(Day, " + CAST(@n_ConsigneeMinShelfLife AS NVARCHAR(10)) + ", Lotattribute.Lottable04) > GetDate() "         
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " OR Lotattribute.Lottable04 IS NULL) "        
      END        
        
      SELECT @c_condition = ISNULL(RTRIM(@c_Condition),'') + " GROUP BY LOT.StorerKey, LOT.Sku, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOT.Lot "        
      SELECT @c_condition = ISNULL(RTRIM(@c_Condition),'') + " HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) >= " + RTRIM(CAST ( @n_uombase AS NVARCHAR(10))) + " "          
              
     ---remove by NJOW01
     ---IF @n_ConsigneeMinShelfLife = 0
     ---BEGIN
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition) ,'') + 
                " ORDER BY LOTATTRIBUTE.Lottable04, LOT.Lot, SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) "
     ---END
     ---ELSE
     ---BEGIN
         /*SELECT @c_Condition = ISNULL(RTRIM(@c_Condition) ,'') + 
                " ORDER BY SUM( " + 
                "  CASE WHEN SKUxLOC.LocationType NOT IN ('CASE' ,'PICK') THEN 0 " + 
                "       WHEN SKUxLOC.LocationType IN ('CASE' ,'PICK') THEN 1 " + 
                "       ELSE 2 END), " + 
                "       LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOT.Lot, SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) "*/
      ---   SELECT @c_Condition = ISNULL(RTRIM(@c_Condition) ,'') +   
      ---          " ORDER BY SUM( " +   
      ---          "  CASE WHEN SKUxLOC.LocationType NOT IN ('CASE' ,'PICK') THEN 0 " +   
      ---         "       WHEN SKUxLOC.LocationType IN ('CASE' ,'PICK') AND ISNULL(bulkloc.lot,'')='' THEN 1 " +    --NJOW
      ---          "       WHEN SKUxLOC.LocationType IN ('CASE' ,'PICK') AND ISNULL(bulkloc.lot,'')<>'' THEN 0 " +   --NJOW
      ---          "       ELSE 2 END), " +   
      ---          "       LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOT.Lot, SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) "  
      ---END  
        
        
                
      EXEC (" DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +        
       " SELECT LOT.StorerKey, LOT.SKU, LOT.LOT, "  +       
      --" QTYAVAILABLE = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) " +         
       " QTYAVAILABLE = CASE WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) < " + @c_UOMBase +          
       "      THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +          
       "      WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) % " + @c_UOMBase + " = 0 " +          
       " THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +          
       "      ELSE   " +          
       "        SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +          
       "        - ((SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))) % " + @c_UOMBase + ") " +          
       "      END " +           
       " FROM LOTxLOCxID (NOLOCK) " +        
       " JOIN LOT (NOLOCK) ON LOT.LOT = LOTxLOCxID.Lot " +          
       " JOIN LOTATTRIBUTE (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT " +          
       " JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc " +         
       " JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID " +         
       " JOIN SKUxLOC (NOLOCK) ON SKUxLOC.StorerKey = LOTxLOCxID.StorerKey " +        
       " AND SKUxLOC.SKU = LOTxLOCxID.SKU " +        
       " AND SKUxLOC.LOC = LOTxLOCxID.LOC " +          
       " LEFT OUTER JOIN (SELECT PP.lot, ORDERS.facility, QtyPreallocated = SUM(PP.Qty) " +         
       "                   FROM PreallocatePickdetail PP (NOLOCK), ORDERS (NOLOCK) " +        
       "                   WHERE PP.Orderkey = ORDERS.Orderkey " +        
       "                   AND   PP.Storerkey = N'" + @c_StorerKey + "' " +         
       "                   AND   PP.SKU = N'" + @c_SKU + "' " +          
       "                   GROUP BY PP.Lot, ORDERS.Facility) p ON LOTxLOCxID.Lot = p.Lot AND p.Facility = LOC.Facility " +        
       " LEFT OUTER JOIN (SELECT DISTINCT LLI.Lot FROM LOTXLOCXID LLI (NOLOCK) JOIN SKUXLOC SL ON LLI.Storerkey = SL.Storerkey " +  --NJOW
       "                                                              AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc " +  --NJOW
       "                  WHERE SL.Locationtype NOT IN ('PICK','CASE') " +  --NJOW             
       "                  AND LLI.Storerkey = N'" + @c_StorerKey + "' " +  --NJOW      
       "                  AND LLI.Sku = N'" + @c_SKU + "' "+ --NJOW
       "                  AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) > 0) bulkloc ON LOTXLOCXID.Lot = bulkloc.lot "  + --NJOW  
       " WHERE LOT.StorerKey = N'" + @c_StorerKey + "' " +        
       " AND LOT.SKU = N'" + @c_SKU + "' " +        
       " AND LOT.STATUS = 'OK' " +        
       " AND ID.STATUS <> 'HOLD' " +          
       " AND LOC.Status = 'OK' " +         
       " AND LOC.Facility = N'" + @c_Facility + "' " +        
       " AND LOC.LocationFlag <> 'HOLD' " +        
       " AND LOC.LocationFlag <> 'DAMAGE' " +        
       " AND LOTxLOCxID.StorerKey = N'" + @c_StorerKey + "' " +        
       " AND LOTxLOCxID.SKU = N'" + @c_SKU + "' " +         
       " AND LOTATTRIBUTE.StorerKey = N'" + @c_StorerKey + "' " +        
      @c_Condition  )         
        
   END        
   EXIT_SP:        
END   

GO