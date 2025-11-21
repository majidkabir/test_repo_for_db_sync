SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: nspPRTW17                                           */  
/* Creation Date: 09-Apr-2019                                            */  
/*                                                                       */
/* Copyright: LF                                                         */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-8600 TW-LOR Preallocation strategy                       */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/* PVCS Version: 1.2                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */ 
/* 15-Aug-2019  WLChooi  1.1 WMS-10216 Add lottable06-15, exclude empty  */ 
/*                           lottable02 filter by codelkup config (WL01) */
/* 26-Nov-2019  Wan01    1.2 Dynamic SQL review, impact SQL cache log    */ 
/* 03-Feb-2021  WLChooi  1.3 WMS-16191 Add Filter by SKUxLOC.LocationType*/
/*                           (WL02)                                      */
/* 18-Feb-2021  WLChooi  1.3 WMS-16191 Add Checking on LocationType(WL03)*/
/*************************************************************************/   
CREATE PROC [dbo].[nspPRTW17]    
   @c_StorerKey NVARCHAR(15) ,    
   @c_SKU NVARCHAR(20) ,    
   @c_LOT NVARCHAR(10) ,    
   @c_Lottable01 NVARCHAR(18) ,    
   @c_Lottable02 NVARCHAR(18) ,    
   @c_Lottable03 NVARCHAR(18) ,    
   @d_Lottable04 DATETIME ,    
   @d_Lottable05 DATETIME ,  
   @c_lottable06 NVARCHAR(30),  --WL01 Start
   @c_lottable07 NVARCHAR(30),
   @c_lottable08 NVARCHAR(30),
   @c_lottable09 NVARCHAR(30),
   @c_lottable10 NVARCHAR(30),
   @c_lottable11 NVARCHAR(30),
   @c_lottable12 NVARCHAR(30),
   @d_lottable13 datetime,
   @d_lottable14 datetime,
   @d_lottable15 datetime,     --WL01 End  
   @c_UOM NVARCHAR(10) ,    
   @c_Facility NVARCHAR(10)  ,    
   @n_UOMBase INT ,    
   @n_QtyLeftToFulfill INT,    
   @c_OtherParms NVARCHAR(200) = ''     
AS    
BEGIN  
    SET NOCOUNT ON     
      
    DECLARE @n_ConsigneeMinShelfLife  INT  
           ,@c_Condition              NVARCHAR(MAX)  
           ,@c_UOMBase                NVARCHAR(10)    
           ,@c_SQL                    NVARCHAR(MAX)          

    DECLARE @c_OrderKey           NVARCHAR(10)  
           ,@c_OrderLineNumber    NVARCHAR(5)
           ,@c_Consigneekey       NVARCHAR(15)
           ,@n_OrderQty           INT
           ,@c_OrderUOM           NVARCHAR(10)
           ,@n_OrderMinShelfLife  INT
           ,@n_MultiLocType       INT = 0   --WL03
           ,@c_QtyAvailableString NVARCHAR(4000) = ''   --WL03

   DECLARE @c_SQLParms  NVARCHAR(3999)  = ''       --(Wan01)
      
    SET @c_UOMBase = RTRIM(CAST(@n_uombase AS NVARCHAR(10)))    
    SET @c_Condition = ''    
    SET @c_SQL = ''
      
    IF ISNULL(LTRIM(RTRIM(@c_LOT)) ,'') <> ''  
    AND LEFT(@c_LOT ,1) <> '*'  
    BEGIN  
        SELECT @n_ConsigneeMinShelfLife = ((ISNULL(Sku.Shelflife, 0) * ISNULL(Storer.MinShelflife,0)/100) * -1)
        FROM Sku (nolock) 
        JOIN Storer (nolock) ON SKU.Storerkey = Storer.Storerkey
        JOIN Lot (nolock) ON Sku.Storerkey = Lot.Storerkey AND Sku.Sku = Lot.Sku
        WHERE Lot.Lot = @c_lot
                   
        DECLARE PREALLOCATE_CURSOR_CANDIDATES  CURSOR FAST_FORWARD READ_ONLY   
        FOR  
            SELECT LOT.StorerKey  
                  ,LOT.SKU  
                  ,LOT.LOT  
                  ,QTYAVAILABLE  = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)  
            FROM   LOT(NOLOCK)  
                  ,Lotattribute                (NOLOCK)  
                  ,LOTxLOCxID                  (NOLOCK)  
                  ,LOC                         (NOLOCK)  
            WHERE  LOT.LOT = @c_LOT  
            AND    Lot.Lot = Lotattribute.Lot  
            AND    LOTxLOCxID.Lot = LOT.LOT  
            AND    LOTxLOCxID.LOT = LOTATTRIBUTE.LOT  
            AND    LOTxLOCxID.LOC = LOC.LOC  
            AND    LOC.Facility = @c_Facility  
            AND    DATEADD(DAY ,@n_ConsigneeMinShelfLife ,Lotattribute.Lottable04) > GETDATE()  
            ORDER BY  
                   Lotattribute.Lottable04  
                  ,LOT.Lot  
    END  
    ELSE  
    BEGIN          
        IF LEN(@c_OtherParms) > 0  
        BEGIN  
            SET @c_OrderKey = LEFT(@c_OtherParms, 10)
            SET @c_OrderLineNumber = SUBSTRING(@c_OtherParms, 11, 5)                                           
            
            SELECT @c_ConsigneeKey = ORDERS.consigneekey
            FROM ORDERS (NOLOCK)
            WHERE ORDERS.orderkey = @c_Orderkey

            SELECT @n_OrderQty = ORDERDETAIL.OpenQty, 
                   @c_OrderUOM = ORDERDETAIL.UOM,
                   @n_OrderMinShelfLife = ISNULL(ORDERDETAIL.MinShelfLife,0)
            FROM ORDERDETAIL (NOLOCK)
            WHERE ORDERDETAIL.orderkey = @c_Orderkey
            AND ORDERDETAIL.OrderLineNumber = @c_OrderLineNumber
            
            IF ISNULL(@n_OrderMinShelfLife,0) <> 0
            BEGIN
                SELECT @n_ConsigneeMinShelfLife = @n_OrderMinShelfLife * -1
            END
            ELSE
            BEGIN
               SELECT @n_ConsigneeMinShelfLife = ISNULL(Storer.MinShelflife, 0)  
                     FROM   STORER (NOLOCK)
                     WHERE  STORERKEY = @c_ConsigneeKey
               
               SELECT @n_ConsigneeMinShelfLife = ((ISNULL(Sku.Shelflife, 0) * ISNULL(@n_ConsigneeMinShelfLife,0)/100) * -1)
               FROM Sku (nolock) 
               WHERE Sku.Storerkey = @c_Storerkey
               AND Sku.Sku = @c_Sku
            END
        END                     

        IF @n_ConsigneeMinShelfLife IS NULL    
           SELECT @n_ConsigneeMinShelfLife = 0

        IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) <> '' AND @c_Lottable01 IS NOT NULL  
        BEGIN  
           SELECT @c_Condition = " AND LOC.HostWhCode = RTRIM(@c_Lottable01) "                                                                                   --(Wan01)  
        END  
            
        IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) <> '' AND @c_Lottable02 IS NOT NULL  
        BEGIN  
           SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE02 = RTRIM(@c_Lottable02) "                                                         --(Wan01)
        END  
        
        IF CONVERT(NVARCHAR(8),@d_Lottable04, 112) <> "19000101" AND @d_Lottable04 IS NOT NULL  
        BEGIN
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND CONVERT(NVARCHAR(10),Lotattribute.Lottable04, 112) = RTRIM(CONVERT( NVARCHAR(8), @d_Lottable04, 112)) "   --(Wan01)
        END
        ELSE IF @n_ConsigneeMinShelfLife <> 0
        BEGIN
                 SELECT @c_Condition = RTRIM(@c_Condition) + " AND DATEADD(DAY, @n_ConsigneeMinShelfLife, Lotattribute.Lottable04) > GETDATE() "                        --(Wan01)                                
        END

        IF CONVERT(NVARCHAR(8),@d_Lottable05, 112) <> "19000101" AND @d_Lottable05 IS NOT NULL  
        BEGIN
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND CONVERT(NVARCHAR(10),Lotattribute.Lottable05, 112) = RTRIM(CONVERT( NVARCHAR(8), @d_Lottable05, 112)) "   --(Wan01)
        END

        --WL01 Start
        IF ISNULL(@c_Lottable10,'') <> '' 
        BEGIN
           SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOTTABLE10 = RTRIM(@c_Lottable10) '                                                                --(Wan01)
        END
        ELSE
        BEGIN
           IF NOT EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
                          WHERE CL.Storerkey = @c_Storerkey
                          AND CL.Code = 'NOFILTEREMPTYLOT10'
                          AND CL.Listname = 'PKCODECFG' 
                          AND CL.Long = 'nspPRTW17'
                          AND CL.Code2 = 'nspPRTW17'
                          AND ISNULL(CL.Short,'') <> 'N')
           BEGIN
              SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOTTABLE10 = '''' '
           END
        END
        --WL01 End

        --WL03 S
        SELECT @n_MultiLocType  = COUNT(DISTINCT LocationType) 
        FROM SKUxLOC (NOLOCK)
        WHERE LocationType IN ('CASE','PICK') 
        AND SKU = @c_SKU AND StorerKey = @c_StorerKey
        
        SET @c_QtyAvailableString = " QTYAVAILABLE = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(ISNULL(LOT.QTYPREALLOCATED, 0)) "
        
        IF @n_MultiLocType >= 2
        BEGIN
           SET @c_QtyAvailableString = " QTYAVAILABLE = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) "
        END
        --WL03 E
        
        IF @c_UOM = '1' --Pallet
        BEGIN
           IF @c_OrderUOM IN('CS','EA') AND @n_OrderQty < @n_UOMBase
              SELECT @c_Condition = RTRIM(@c_Condition) + " AND 1 = 2 "   
        END
        ELSE IF @c_UOM = '2' --Case
        BEGIN 
           IF @n_MultiLocType >= 2   --WL03
              SELECT @c_Condition = RTRIM(@c_Condition) + ' AND SKUxLOC.LocationType <> ''PICK'' '   --WL02
           
           IF @c_OrderUOM IN('CS','EA') AND @n_OrderQty < @n_UOMBase
              SELECT @c_Condition = RTRIM(@c_Condition) + " AND 1 = 2 "              
        END
        ELSE IF @c_UOM = '6' --Each
        BEGIN
        	  --WL03 S
        	  IF @n_MultiLocType >= 2
        	  BEGIN
        	     SET @n_uombase = 1   --WL02
        	     SELECT @c_Condition = RTRIM(@c_Condition) + ' AND SKUxLOC.LocationType <> ''CASE'' '   --WL02
        	  END
        	  --WL03 E
        	  
           IF @c_OrderUOM IN('CS') 
              SELECT @c_Condition = RTRIM(@c_Condition) + " AND 1 = 2 "              
        END
                
        SELECT @c_SQL = " DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +   
                 " SELECT LOT.StorerKey, LOT.SKU, LOT.LOT, " +   
                 --" QTYAVAILABLE = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) " + -- - MIN(ISNULL(LOT.QTYPREALLOCATED, 0)) " +  --WL02   --WL03 
                 @c_QtyAvailableString +   --WL03
                 " FROM LOTxLOCxID (NOLOCK) " +   
                 " JOIN LOT (NOLOCK) ON LOT.LOT = LOTxLOCxID.Lot " +   
                 " JOIN LOTATTRIBUTE (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT " +   
                 " JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc " +   
                 " JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID " +   
                 " JOIN SKUxLOC (NOLOCK) ON SKUxLOC.StorerKey = LOTxLOCxID.StorerKey " +   
                 " AND SKUxLOC.SKU = LOTxLOCxID.SKU " +   
                 " AND SKUxLOC.LOC = LOTxLOCxID.LOC " +   
                 " WHERE LOT.StorerKey = RTRIM(@c_StorerKey) " +                                                                             --(Wan01) 
                 " AND LOT.SKU = RTRIM(@c_SKU) " +                                                                                           --(Wan01)
                 " AND LOT.STATUS = 'OK' " +   
                 " AND ID.STATUS <> 'HOLD' " +   
                 " AND LOC.Status = 'OK' " +   
                 " AND LOC.Facility = RTRIM(@c_Facility) " +                                                                                 --(Wan01)       
                 " AND LOC.LocationFlag <> 'HOLD' " +   
                 " AND LOC.LocationFlag <> 'DAMAGE' " +   
                 " AND LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED >= @n_uombase " +                                     --(Wan01)
                 @c_Condition + 
                 " GROUP BY LOT.StorerKey, LOT.Sku, LOT.Lot, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOTATTRIBUTE.Lottable06 " +   
                 --" HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) >= @n_uombase " +  --(Wan01)   --WL02  
                 " HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase " +   --WL02 
                 " ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable06 DESC, LOTATTRIBUTE.Lottable05, LOT.Lot "                           

        --(Wan01) - START
      SET @c_SQLParms=N' @c_Facility   NVARCHAR(5)'
                     + ',@c_Storerkey  NVARCHAR(15)'
                     + ',@c_SKU        NVARCHAR(20)'     
                     + ',@c_Lottable01 NVARCHAR(18)'
                     + ',@c_Lottable02 NVARCHAR(18)' 
                     + ',@d_Lottable04 DATETIME'
                     + ',@d_Lottable05 DATETIME'
                     + ',@c_Lottable10 NVARCHAR(30)' 
                     + ',@n_ConsigneeMinShelfLife INT '   
                     + ',@n_uombase INT '                           
      
      EXEC sp_ExecuteSQL @c_SQL
                     , @c_SQLParms
                     , @c_Facility
                     , @c_Storerkey
                     , @c_SKU
                     , @c_Lottable01
                     , @c_Lottable02
                     , @d_Lottable04
                     , @d_Lottable05
                     , @c_Lottable10
                     , @n_ConsigneeMinShelfLife
                     , @n_uombase
      --(Wan01) - END
    END  
END    

GO