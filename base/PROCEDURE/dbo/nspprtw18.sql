SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: nspPRTW18                                           */  
/* Creation Date: 19-Jun-2019                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-9841-TW Pre-Allocation for FMCG                          */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */ 
/* 20-ARP-2023  NJOW01   1.0  WMS-22321 allow filter empty lottable02    */
/*                            configure by codelkup                      */
/*************************************************************************/   
CREATE   PROC [dbo].[nspPRTW18]    
   @c_StorerKey NVARCHAR(15) ,    
   @c_SKU NVARCHAR(20) ,    
   @c_LOT NVARCHAR(10) ,    
   @c_Lottable01 NVARCHAR(18) ,    
   @c_Lottable02 NVARCHAR(18) ,    
   @c_Lottable03 NVARCHAR(18) ,    
   @d_Lottable04 DATETIME ,    
   @d_Lottable05 DATETIME , 
   @c_lottable06 NVARCHAR(30),
   @c_lottable07 NVARCHAR(30),
   @c_lottable08 NVARCHAR(30),
   @c_lottable09 NVARCHAR(30),
   @c_lottable10 NVARCHAR(30),
   @c_lottable11 NVARCHAR(30),
   @c_lottable12 NVARCHAR(30),
   @d_lottable13 datetime,
   @d_lottable14 datetime,
   @d_lottable15 datetime,      
   @c_UOM NVARCHAR(10) ,    
   @c_Facility NVARCHAR(10)  ,    
   @n_UOMBase INT ,    
   @n_QtyLeftToFulfill INT,    
   @c_OtherParms NVARCHAR(20) = ''     
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
           ,@c_OrderBy            NVARCHAR(2000)
           ,@c_GroupBy            NVARCHAR(2000)
      
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

        IF ISNULL(RTRIM(@c_Lottable01), '') <> ''   
        BEGIN  
           SELECT  @c_Condition = RTRIM(@c_Condition) + " AND LOC.HostWhCode = N'" + RTRIM(@c_Lottable01) + "' "  
        END                       
        IF ISNULL(RTRIM(@c_Lottable02), '') <> ''  
        BEGIN  
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable02 = N'" + RTRIM(@c_Lottable02) + "' "  
        END    
        ELSE
        BEGIN --NJOW01
         	  IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
         	             WHERE CL.Storerkey = @c_Storerkey
         	             AND CL.Code = 'NOFILTEREMPTYLOT2'
         	             AND CL.Listname = 'PKCODECFG'
         	             AND CL.Long = 'nspPRTW18'
         	             AND ISNULL(CL.Short,'') = 'N') 
         	  BEGIN              
               SELECT @c_Condition = RTRIM(@c_Condition) + ' AND Lotattribute.Lottable02 = '''' '
            END        		
        END        
        
        IF ISNULL(RTRIM(@c_Lottable03), '') <> ''  
        BEGIN  
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable03 = N'" + RTRIM(ISNULL(@c_Lottable03,'')) + "' "  
        END            
        IF CONVERT(NVARCHAR(8),@d_Lottable04, 112) <> "19000101" AND @d_Lottable04 IS NOT NULL  
        BEGIN
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND CONVERT(NVARCHAR(10),Lotattribute.Lottable04, 112) = N'" + RTRIM(CONVERT( NVARCHAR(8), @d_Lottable04, 112)) + "' "
        END
        ELSE IF @n_ConsigneeMinShelfLife <> 0
        BEGIN
		   		  SELECT @c_Condition = RTRIM(@c_Condition) + " AND DATEADD(DAY, " + RTRIM(CAST(@n_ConsigneeMinShelfLife AS NVARCHAR)) + ", Lotattribute.Lottable04) > GETDATE() " 			   		          	  
        END

        IF CONVERT(NVARCHAR(8),@d_Lottable05, 112) <> "19000101" AND @d_Lottable05 IS NOT NULL  
        BEGIN
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND CONVERT(NVARCHAR(10),Lotattribute.Lottable05, 112) = N'" + RTRIM(CONVERT( NVARCHAR(8), @d_Lottable05, 112)) + "' "
        END

        IF ISNULL(RTRIM(@c_Lottable06), '') <> ''  
        BEGIN  
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable06 = N'" + RTRIM(@c_Lottable06) + "' "  
        END    
        IF ISNULL(RTRIM(@c_Lottable07), '') <> ''  
        BEGIN  
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable07 = N'" + RTRIM(@c_Lottable07) + "' "  
        END    
        IF ISNULL(RTRIM(@c_Lottable08), '') <> ''  
        BEGIN  
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable08 = N'" + RTRIM(@c_Lottable08) + "' "  
        END    
        IF ISNULL(RTRIM(@c_Lottable09), '') <> ''  
        BEGIN  
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable09 = N'" + RTRIM(@c_Lottable09) + "' "  
        END    
        IF ISNULL(RTRIM(@c_Lottable10), '') <> ''  
        BEGIN  
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable10 = N'" + RTRIM(@c_Lottable10) + "' "  
        END    
        IF ISNULL(RTRIM(@c_Lottable11), '') <> ''  
        BEGIN  
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable11 = N'" + RTRIM(@c_Lottable11) + "' "  
        END    
        IF ISNULL(RTRIM(@c_Lottable12), '') <> ''  
        BEGIN  
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable12 = N'" + RTRIM(@c_Lottable12) + "' "  
        END    
        IF CONVERT(NVARCHAR(8),@d_Lottable13, 112) <> "19000101" AND @d_Lottable13 IS NOT NULL  
        BEGIN
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND CONVERT(NVARCHAR(10),Lotattribute.Lottable13, 112) = N'" + RTRIM(CONVERT( NVARCHAR(8), @d_Lottable13, 112)) + "' "
        END
        IF CONVERT(NVARCHAR(8),@d_Lottable14, 112) <> "19000101" AND @d_Lottable14 IS NOT NULL  
        BEGIN
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND CONVERT(NVARCHAR(10),Lotattribute.Lottable14, 112) = N'" + RTRIM(CONVERT( NVARCHAR(8), @d_Lottable14, 112)) + "' "
        END
        IF CONVERT(NVARCHAR(8),@d_Lottable15, 112) <> "19000101" AND @d_Lottable15 IS NOT NULL  
        BEGIN
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND CONVERT(NVARCHAR(10),Lotattribute.Lottable15, 112) = N'" + RTRIM(CONVERT( NVARCHAR(8), @d_Lottable15, 112)) + "' "
        END
        
        /*        
        IF @c_UOM = '1' --Pallet
        BEGIN
        	 IF @n_OrderQty < @n_UOMBase AND @c_OrderUOM IN('CS','EA')
        	    SELECT @c_Condition = RTRIM(@c_Condition) + " AND 1 = 2 "   
        END
        ELSE IF @c_UOM = '2' --Case
        BEGIN 
        	 IF @n_OrderQty < @n_UOMBase AND @c_OrderUOM IN('CS','EA')
        	    SELECT @c_Condition = RTRIM(@c_Condition) + " AND 1 = 2 "           	
        END
        ELSE IF @c_UOM = '6' --Each
        BEGIN
        	 IF @c_OrderUOM IN('CS') 
        	    SELECT @c_Condition = RTRIM(@c_Condition) + " AND 1 = 2 "           	
        END
        */
        
        SELECT @c_OrderBy = ' ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable06 DESC, LOTATTRIBUTE.Lottable05, LOT.Lot '
        SELECT @c_GroupBy = ' GROUP BY LOT.StorerKey, LOT.Sku, LOT.Lot, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable05 '
        
        IF @c_UOM = '1'
      	    SELECT @c_Condition = RTRIM(@c_Condition) + " AND SKUXLOC.LocationType NOT IN ('PICK','CASE') AND LOC.PickZone NOT IN (SELECT PickZone FROM PICKZONE(NOLOCK) WHERE ZoneCategory = 'PC') "   

        IF @c_UOM IN ('2','7')  --For overallocation
        BEGIN
      	    SELECT @c_Condition = RTRIM(@c_Condition) + " AND LOC.PickZone NOT IN (SELECT PickZone FROM PICKZONE(NOLOCK) WHERE ZoneCategory = 'PC') "   
            SELECT @c_OrderBy = " ORDER BY CASE WHEN SKUXLOC.LocationType IN ('PICK','CASE') THEN '1' ELSE '2' END, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable06 DESC, LOTATTRIBUTE.Lottable05, LOT.Lot "
            SELECT @c_GroupBy = " GROUP BY LOT.StorerKey, LOT.Sku, LOT.Lot, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable05, CASE WHEN SKUXLOC.LocationType IN ('PICK','CASE') THEN '1' ELSE '2' END "
      	END

        IF @c_UOM = '6'
      	    SELECT @c_Condition = RTRIM(@c_Condition) + " AND LOC.PickZone IN (SELECT PickZone FROM PICKZONE(NOLOCK) WHERE ZoneCategory = 'PC') "   
                
        SELECT @c_SQL = " DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +   
                 " SELECT LOT.StorerKey, LOT.SKU, LOT.LOT, " +   
                 " QTYAVAILABLE = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +     
                 " FROM LOTxLOCxID (NOLOCK) " +   
                 " JOIN LOT (NOLOCK) ON LOTxLOCxID.Lot = LOT.Lot " +                                               
                 " JOIN LOTATTRIBUTE (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT " +   
                 " JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc " +    
                 " JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID " +   
                 " JOIN SKUxLOC (NOLOCK) ON SKUxLOC.StorerKey = LOTxLOCxID.StorerKey " +   
                 " AND SKUxLOC.SKU = LOTxLOCxID.SKU " +   
                 " AND SKUxLOC.LOC = LOTxLOCxID.LOC " +   
                 " LEFT OUTER JOIN (SELECT p.lot, ORDERS.facility, QtyPreallocated = SUM(p.Qty) " +         
                 "       FROM PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK) " +
                 "       WHERE p.Orderkey = ORDERS.Orderkey " +         
                 "       AND   p.Storerkey = @c_storerkey " +         
                 "       AND   p.SKU = @c_SKU " +    
                 CASE WHEN @c_UOM = '6' THEN " AND P.UOM = '6' " ELSE " " END +    
                 "       GROUP BY p.Lot, ORDERS.Facility) p ON LOTXLOCXID.Lot = p.Lot " +         
                 "                                          AND p.Facility = LOC.Facility " +
                 " WHERE LOT.StorerKey = @c_StorerKey " +  
                 " AND LOT.SKU = @c_SKU " +   
                 " AND LOT.STATUS = 'OK' " +   
                 " AND ID.STATUS <> 'HOLD' " +   
                 " AND LOC.Status = 'OK' " +   
                 " AND LOC.Facility = @c_Facility " +   
                 " AND LOC.LocationFlag <> 'HOLD' " +   
                 " AND LOC.LocationFlag <> 'DAMAGE' " +   
                 " AND LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED >= @n_UOMBase " +
                 @c_Condition + 
                 @c_GroupBy +   
                 " HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED,0)) >= @n_UOMBase " +   
                 RTRIM(ISNULL(@c_OrderBy,''))                       	

        EXEC sp_executesql @c_SQL,
           N'@c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_Facility NVARCHAR(5), @n_UOMBase INT ', 
           @c_Storerkey,
           @c_Sku,
           @c_Facility,
           @n_UOMBase
    END  
END    

GO