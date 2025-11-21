SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: nspPRGSK01                                          */  
/* Creation Date:                                                        */  
/* Copyright: LF                                                         */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: 313793-GSK PH Pre-Allocation                                 */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/* PVCS Version: 1.1                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author  Ver   Purposes                                   */ 
/* 17-Jan-2020  Wan01   1.1   Dynamic SQL review, impact SQL cache log   */  
/*************************************************************************/   
CREATE PROC [dbo].[nspPRGSK01]    
   @c_StorerKey NVARCHAR(15) ,    
   @c_SKU NVARCHAR(20) ,    
   @c_LOT NVARCHAR(10) ,    
   @c_Lottable01 NVARCHAR(18) ,    
   @c_Lottable02 NVARCHAR(18) ,    
   @c_Lottable03 NVARCHAR(18) ,    
   @d_Lottable04 DATETIME ,    
   @d_Lottable05 DATETIME ,    
   @c_UOM NVARCHAR(10) ,    
   @c_Facility NVARCHAR(10)  ,  -- added By Ricky for IDSV5    
   @n_UOMBase INT ,    
   @n_QtyLeftToFulfill INT,    
   @c_OtherParms NVARCHAR(20) = ''     
AS    
BEGIN  
    SET NOCOUNT ON     
      
    DECLARE @n_Shelflife              INT  
           ,@n_SkuShelflife           INT  
           ,@c_Condition              NVARCHAR(MAX)  
           ,@c_UOMBase                NVARCHAR(10)    
           ,@c_SQL                    NVARCHAR(MAX)
         ,  @c_SQLParms               NVARCHAR(4000) = ''        --(Wan01)  

    DECLARE @c_OrderKey     NVARCHAR(10)  
           ,@c_OrderType    NVARCHAR(10)  
           ,@c_StrategyType NVARCHAR(10)  
           ,@c_HostWHCode   NVARCHAR(18)  
           ,@c_OrderLineNumber NVARCHAR(5)
           ,@c_Lottable04Label NVARCHAR(20)
           ,@n_StorerMinShelflife INT
      
    SET @c_UOMBase = RTRIM(CAST(@n_uombase AS NVARCHAR(10)))    
    SET @c_Condition = ''    
    SET @c_StrategyType = 'NORMAL'               
    SET @n_Shelflife = 0
    SET @c_SQL = ''
      
    IF ISNULL(LTRIM(RTRIM(@c_LOT)) ,'') <> ''  
    AND LEFT(@c_LOT ,1) <> '*'  
    BEGIN  
        /* Get Storer Minimum Shelf Life */    

        SELECT @n_Shelflife = ((ISNULL(Sku.Shelflife, 0) * ISNULL(Storer.MinShelflife,0)/100) * -1)
        FROM Sku (nolock) 
        JOIN Storer (nolock) ON SKU.Storerkey = Storer.Storerkey
        JOIN Lot (nolock) ON Sku.Storerkey = Lot.Storerkey AND Sku.Sku = Lot.Sku
        WHERE Lot.Lot = @c_lot
        --AND Sku.Facility = @c_facility  
                   
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
            AND    DATEADD(DAY ,@n_Shelflife ,Lotattribute.Lottable04) > GETDATE()  
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
                                       
            SELECT @c_OrderType = ORDERS.Type, @c_HostWHCode = ORDERDETAIL.Userdefine01,
                   @n_StorerMinShelflife = ISNULL(STORER.MinShelflife,0)
            FROM   ORDERS WITH (NOLOCK)  
            JOIN   ORDERDETAIL WITH (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey
            LEFT JOIN STORER WITH (NOLOCK) ON ORDERS.Consigneekey = STORER.Storerkey
            WHERE  ORDERS.OrderKey = @c_OrderKey
            AND ORDERDETAIL.OrderLineNumber = @c_OrderLineNumber
            
            IF EXISTS(SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'ORDERTYPE' AND Code = @c_OrderType AND Long = 'REPLEN')
                SET @c_StrategyType = 'REPLEN'
            ELSE
               SET @c_StrategyType = 'NORMAL'                                                        
        END                     
        
        SELECT @c_Lottable04Label = Lottable04Label
        FROM SKU(NOLOCK)
        WHERE Storerkey = @c_Storerkey
        AND Sku = @c_Sku

        IF ISNULL(RTRIM(@c_Lottable01), '') <> ''  
        BEGIN  
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable01 = @c_Lottable01 "  
        END    

        IF ISNULL(RTRIM(@c_Lottable02), '') <> ''  
        BEGIN  
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable02 = @c_Lottable02 "  
        END    

        IF ISNULL(RTRIM(@c_Lottable03), '') <> ''  
        BEGIN  
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable03 = @c_Lottable03 "  
        END    

        IF CONVERT(char(10), @d_Lottable05, 103) <> "01/01/1900" AND @d_Lottable05 IS NOT NULL
        BEGIN
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable05 = @d_Lottable05 "
        END
        
        IF LEFT(@c_lot,1) = '*'
        BEGIN
           SET @n_Shelflife = CONVERT(int, SUBSTRING(@c_lot, 2, 9))      
           SET @n_SkuShelflife = @n_Shelflife   
            
          --SELECT @c_Condition = RTRIM(@c_Condition) + " AND convert(char(8),Lotattribute.Lottable04, 112) >= N'"  + convert(char(8), DateAdd(DAY, @n_shelflife, getdate()), 112) + "'"
        END
        ELSE
        BEGIN            
          --IF ISNULL(@n_StorerMinShelflife,0) = 0
             --SET @n_StorerMinShelflife = 100
             
           SELECT @n_Shelflife = ((ISNULL(Sku.Shelflife, 0) * ISNULL(@n_StorerMinShelflife ,0)/100)), -- * -1)
                  @n_SkuShelflife = ISNULL(Sku.Shelflife, 0)
           FROM Sku (nolock) 
           WHERE Sku.Storerkey = @c_Storerkey
           AND Sku.Sku = @c_Sku
           --AND Sku.Facility = @c_facility  
            
             --SELECT @c_Condition = RTRIM(@c_Condition) + " AND DATEADD(DAY, " + RTRIM(CAST(@n_Shelflife AS NVARCHAR)) + ", Lotattribute.Lottable04) > GETDATE() "                                     
        END           

        IF @n_Shelflife IS NULL    
           SELECT @n_Shelflife = 0

        IF @n_SkuShelflife IS NULL    
           SELECT @n_SkuShelflife = 0
        
        --IF @n_Shelflife > 0
        --BEGIN
           IF @c_Lottable04Label = 'EXP_DATE'
                  SELECT @c_Condition = RTRIM(@c_Condition) + " AND DATEDIFF(DAY, GETDATE(), Lotattribute.Lottable04) > @n_Shelflife "
               ELSE IF @c_Lottable04Label = 'PRODN_DATE' --AND @n_Shelflife > 0
                SELECT @c_Condition = RTRIM(@c_Condition) + " AND DATEADD(DAY, @n_SkuShelflife, Lotattribute.Lottable04) >= GETDATE() "                                      
            --END
            --ELSE
            --BEGIN
                 --IF @c_Lottable04Label = 'EXP_DATE'
                  --SELECT @c_Condition = RTRIM(@c_Condition) + " AND DATEDIFF(DAY, GETDATE(), Lotattribute.Lottable04) > 0 " 
            --END                   

        SELECT @c_condition = RTRIM(@c_Condition) + " GROUP BY LOT.StorerKey, LOT.Sku, LOT.Lot, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05 "   
        SELECT @c_condition = RTRIM(@c_Condition) + 
              " HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) >= @n_UOMBase "   
                
        IF @c_StrategyType = 'NORMAL'
           SELECT @c_Condition = RTRIM(@c_Condition) + " ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOT.Lot "                            
        ELSE
           SELECT @c_Condition = RTRIM(@c_Condition) + " ORDER BY LOTATTRIBUTE.Lottable04 DESC, LOTATTRIBUTE.Lottable05, LOT.Lot "                          

        SELECT @c_SQL = " DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +   
                 " SELECT LOT.StorerKey, LOT.SKU, LOT.LOT, " +   
                 " QTYAVAILABLE = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(ISNULL(LOT.QTYPREALLOCATED, 0)) " +     
                 " FROM LOTxLOCxID (NOLOCK) " +   
                 " JOIN LOT (NOLOCK) ON LOT.LOT = LOTxLOCxID.Lot " +   
                 " JOIN LOTATTRIBUTE (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT " +   
                 " JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc " +   
                 " JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID " +   
                 " JOIN SKUxLOC (NOLOCK) ON SKUxLOC.StorerKey = LOTxLOCxID.StorerKey " +   
                 " AND SKUxLOC.SKU = LOTxLOCxID.SKU " +   
                 " AND SKUxLOC.LOC = LOTxLOCxID.LOC " +   
                 " WHERE LOT.StorerKey = @c_StorerKey " +  
                 " AND LOT.SKU = @c_SKU " +   
                 " AND LOT.STATUS = 'OK' " +   
                 " AND ID.STATUS <> 'HOLD' " +   
                 " AND LOC.Status = 'OK' " +   
                 " AND LOC.Facility = @c_Facility " +   
                 " AND LOC.LocationFlag <> 'HOLD' " +   
                 " AND LOC.LocationFlag <> 'DAMAGE' " +   
                 " AND LOC.HostWHCode = @c_HostWHCode " +   
                 @c_Condition  
         --(Wan01) - START  
         --EXEC (@c_SQL)                     
          SET @c_SQLParms= N'@c_facility   NVARCHAR(5)'
                              + ',@c_storerkey  NVARCHAR(15)'
                              + ',@c_SKU        NVARCHAR(20)'
                              + ',@c_Lottable01 NVARCHAR(18)'
                              + ',@c_Lottable02 NVARCHAR(18)'
                              + ',@c_Lottable03 NVARCHAR(18)'
                              + ',@d_lottable04 datetime'
                              + ',@d_lottable05 datetime'
                              + ',@c_HostWHCode NVARCHAR(18)'
                              + ',@n_Shelflife     int'
                              + ',@n_SkuShelflife  int'
                              + ',@n_UOMBase       int'
                    
      
         EXEC sp_ExecuteSQL @c_SQL, @c_SQLParms, @c_facility, @c_storerkey, @c_SKU 
                           ,@c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05
                           ,@c_HostWHCode, @n_Shelflife, @n_SkuShelflife, @n_UOMBase  
         --(Wan01) - END  

    END  
END    

GO