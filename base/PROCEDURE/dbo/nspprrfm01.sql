SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: nspPRRFM01                                          */  
/* Creation Date: 09-DEC-2014                                            */  
/* Copyright: LF                                                         */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: 327559-RFM PH Pre-Allocation                                 */  
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
/* Date         Author   Ver  Purposes                                   */
/* 17-Jan-2020  Wan01    1.1  Dynamic SQL review, impact SQL cache log   */  
/*************************************************************************/   
CREATE PROC [dbo].[nspPRRFM01]    
   @c_StorerKey NVARCHAR(15) ,    
   @c_SKU NVARCHAR(20) ,    
   @c_LOT NVARCHAR(10) ,    
   @c_Lottable01 NVARCHAR(18) ,    
   @c_Lottable02 NVARCHAR(18) ,    
   @c_Lottable03 NVARCHAR(18) ,    
   @d_Lottable04 DATETIME ,    
   @d_Lottable05 DATETIME ,    
   @c_UOM NVARCHAR(10) ,    
   @c_Facility NVARCHAR(10) ,      
   @n_UOMBase INT ,    
   @n_QtyLeftToFulfill INT,    
   @c_OtherParms NVARCHAR(20) = ''     
AS    
BEGIN  
   SET NOCOUNT ON     
      
   DECLARE @n_SkuShelflife          INT  
         , @c_Condition             NVARCHAR(MAX)  
         , @c_UOMBase               NVARCHAR(10)    
         , @c_SQL                   NVARCHAR(MAX)
         , @c_SQLParms              NVARCHAR(4000) = ''        --(Wan01)   

    DECLARE @c_OrderKey     NVARCHAR(10)  
           ,@c_OrderType    NVARCHAR(10)  
           ,@c_StrategyType NVARCHAR(10)  
           ,@c_HostWHCode   NVARCHAR(18)  
           ,@c_OrderLineNumber NVARCHAR(5)
           ,@n_StorerMinShelflife INT
      
    SET @c_UOMBase = RTRIM(CAST(@n_uombase AS NVARCHAR(10)))    
    SET @c_Condition = ''    
    SET @c_StrategyType = 'NORMAL'               
    SET @c_SQL = ''
      
    IF ISNULL(LTRIM(RTRIM(@c_LOT)) ,'') <> ''  
    AND LEFT(@c_LOT ,1) <> '*'  
    BEGIN  
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
            
            IF EXISTS(SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'ORDERTYPE' AND Code = @c_OrderType AND Long = 'REPLEN' AND StorerKey = @c_StorerKey  )
                SET @c_StrategyType = 'REPLEN'
            ELSE
               SET @c_StrategyType = 'NORMAL'                                                        
        END                     
        
        IF ISNULL(RTRIM(@c_Lottable01), '') <> ''  
        BEGIN             
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable01 = @c_Lottable01 "  
        END    

        IF ISNULL(RTRIM(@c_HostWHCode), '') <> ''  
        BEGIN  
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND LOC.HostWHCode = @c_HostWHCode "             
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
                      
        SELECT @n_SkuShelflife = CASE WHEN ISNUMERIC(Busr6) = 1 THEN CAST(Busr6 AS INT) ELSE 0 END
        FROM Sku (nolock) 
        WHERE Sku.Storerkey = @c_Storerkey
        AND Sku.Sku = @c_Sku

        IF @n_StorerMinShelflife IS NULL    
           SELECT @n_StorerMinShelflife = 0

        IF @n_SkuShelflife IS NULL    
           SELECT @n_SkuShelflife = 0

        IF CONVERT(char(10), @d_Lottable04, 103) <> "01/01/1900" AND @d_Lottable04 IS NOT NULL
        BEGIN
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable04 = @d_Lottable04 "
        END
        ELSE
        BEGIN
           IF @n_StorerMinShelflife > 0         
               SELECT @c_Condition = RTRIM(@c_Condition) + " AND DATEDIFF(DAY, GETDATE(), Lotattribute.Lottable04) > @n_StorerMinShelflife "
           ELSE IF @n_SkuShelflife > 0             
               SELECT @c_Condition = RTRIM(@c_Condition) + " AND DATEDIFF(DAY, GETDATE(), Lotattribute.Lottable04) > @n_SkuShelflife "
            ELSE
               SELECT @c_Condition = RTRIM(@c_Condition) + " AND DATEDIFF(DAY, GETDATE(), Lotattribute.Lottable04) > 0 "
        END          
                     
        SELECT @c_condition = RTRIM(@c_Condition) + " GROUP BY LOT.StorerKey, LOT.Sku, LOT.Lot, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOC.LocationType "   
        SELECT @c_condition = RTRIM(@c_Condition) + 
              " HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) >= @n_UOMBase"  
                
        IF @c_UOM = '1' 
        BEGIN
            SELECT @c_Condition = RTRIM(@c_Condition) + " ORDER BY Case When LOC.LocationType NOT IN ('PICK','CASE') THEN 0 ELSE 1 END, "
        END           
        ELSE
        BEGIN
            SELECT @c_Condition = RTRIM(@c_Condition) + " ORDER BY Case When LOC.LocationType IN ('PICK','CASE') THEN 0 ELSE 1 END, "
        END
   
        IF @c_StrategyType = 'NORMAL'
           SELECT @c_Condition = RTRIM(@c_Condition) + " LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOT.Lot "                            
        ELSE
           SELECT @c_Condition = RTRIM(@c_Condition) + " LOTATTRIBUTE.Lottable04 DESC, LOTATTRIBUTE.Lottable05, LOT.Lot "                          
                      

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
                        + ',@n_StorerMinShelflife  int'
                        + ',@n_SkuShelflife        int'
                        + ',@n_UOMBase    int'
                    
   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParms, @c_facility, @c_storerkey, @c_SKU 
                     ,@c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05
                     ,@c_HostWHCode, @n_StorerMinShelflife, @n_SkuShelflife, @n_UOMBase  
   --(Wan01) - END  
         
    END  
END    

GO