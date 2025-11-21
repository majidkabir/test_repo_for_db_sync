SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: nspPRTW19                                           */  
/* Creation Date:                                                        */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-15328 TW SHDEC Preallocation strategy                    */  
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
/* 02-Dec-2020  NJOW01   1.0  WMS-15720 revise allocation logic          */
/*************************************************************************/   
CREATE PROC [dbo].[nspPRTW19]    
   @c_StorerKey NVARCHAR(15) ,    
   @c_SKU NVARCHAR(20) ,    
   @c_LOT NVARCHAR(10) ,    
   @c_Lottable01 NVARCHAR(18) ,    
   @c_Lottable02 NVARCHAR(18) ,    
   @c_Lottable03 NVARCHAR(18) ,    
   @d_Lottable04 DATETIME ,    
   @d_Lottable05 DATETIME ,    
   @c_Lottable06 NVARCHAR(30) ,    
   @c_Lottable07 NVARCHAR(30) ,    
   @c_Lottable08 NVARCHAR(30) ,    
   @c_Lottable09 NVARCHAR(30) ,    
   @c_Lottable10 NVARCHAR(30) ,    
   @c_Lottable11 NVARCHAR(30) ,    
   @c_Lottable12 NVARCHAR(30) ,    
   @d_Lottable13 DATETIME ,    
   @d_Lottable14 DATETIME ,    
   @d_Lottable15 DATETIME ,    
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
           ,@dt_LastOrderDate     DATETIME
           ,@n_QtyAvailable       INT
           ,@dt_MinLottable04     DATETIME
      
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
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND ISNULL(LOC.HostWhCode,'') = N'" + RTRIM(@c_Lottable01) + "' "  
        END    
        ELSE
        BEGIN
        	  --NJOW02
        	  IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)  
					             WHERE CL.Storerkey = @c_Storerkey  
					             AND CL.Code = 'NOFILTERHWCODE'  
					             AND CL.Listname = 'PKCODECFG'  
					             AND CL.Long = 'nspPRTW19'  
					             AND ISNULL(CL.Short,'') = 'N') 
					  BEGIN
               SELECT @c_Condition = RTRIM(@c_Condition) + " AND ISNULL(LOC.HostWhCode,'') = N'" + RTRIM(@c_Lottable01) + "' "  					  	
					  END					     
					  ELSE
            BEGIN
               SELECT @c_Condition = RTRIM(@c_Condition) + ' AND LOTTABLE01 = '''' '
            END   
         	  
         	  /*
         	  IF NOT EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
         	                 WHERE CL.Storerkey = @c_Storerkey
         	                 AND CL.Code = 'NOFILTEREMPTYLOT1'
         	                 AND CL.Listname = 'PKCODECFG'
         	                 AND CL.Long = 'nspPRTW19'
         	                 AND ISNULL(CL.Short,'') <> 'N') 
         	  BEGIN              
               SELECT @c_Condition = RTRIM(@c_Condition) + ' AND LOTTABLE01 = '''' '
            END
            */        		
        END

        IF ISNULL(RTRIM(@c_Lottable02), '') <> ''  
        BEGIN  
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable02 = N'" + RTRIM(@c_Lottable02) + "' "  
        END    
        ELSE
        BEGIN
         	  IF NOT EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
         	                 WHERE CL.Storerkey = @c_Storerkey
         	                 AND CL.Code = 'NOFILTEREMPTYLOT2'
         	                 AND CL.Listname = 'PKCODECFG'
         	                 AND CL.Long = 'nspPRTW19'
         	                 AND ISNULL(CL.Short,'') <> 'N') 
         	  BEGIN              
               SELECT @c_Condition = RTRIM(@c_Condition) + ' AND LOTTABLE02 = '''' '
            END        		
        END

        IF ISNULL(RTRIM(@c_Lottable03), '') <> ''  
        BEGIN  
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable03 = N'" + RTRIM(ISNULL(@c_Lottable03,'')) + "' "  
        END  
        ELSE  
        BEGIN
         	  IF NOT EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
         	                 WHERE CL.Storerkey = @c_Storerkey
         	                 AND CL.Code = 'NOFILTEREMPTYLOT3'
         	                 AND CL.Listname = 'PKCODECFG'
         	                 AND CL.Long = 'nspPRTW19'
         	                 AND ISNULL(CL.Short,'') <> 'N') 
         	  BEGIN              
               SELECT @c_Condition = RTRIM(@c_Condition) + ' AND LOTTABLE03 = '''' '
            END        		
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
        ELSE    
        BEGIN
         	  IF NOT EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
         	                 WHERE CL.Storerkey = @c_Storerkey
         	                 AND CL.Code = 'NOFILTEREMPTYLOT6'
         	                 AND CL.Listname = 'PKCODECFG'
         	                 AND CL.Long = 'nspPRTW19'
         	                 AND ISNULL(CL.Short,'') <> 'N') 
         	  BEGIN              
               SELECT @c_Condition = RTRIM(@c_Condition) + ' AND LOTTABLE06 = '''' '
            END        		
        END        
        
        IF ISNULL(RTRIM(@c_Lottable07), '') <> ''  
        BEGIN  
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable07 = N'" + RTRIM(@c_Lottable07) + "' "  
        END    
        ELSE    
        BEGIN
         	  IF NOT EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
         	                 WHERE CL.Storerkey = @c_Storerkey
         	                 AND CL.Code = 'NOFILTEREMPTYLOT7'
         	                 AND CL.Listname = 'PKCODECFG'
         	                 AND CL.Long = 'nspPRTW19'
         	                 AND ISNULL(CL.Short,'') <> 'N') 
         	  BEGIN              
               SELECT @c_Condition = RTRIM(@c_Condition) + ' AND LOTTABLE07 = '''' '
            END        		
        END        

        IF ISNULL(RTRIM(@c_Lottable08), '') <> ''  
        BEGIN  
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable08 = N'" + RTRIM(@c_Lottable08) + "' "  
        END    
        ELSE    
        BEGIN
         	  IF NOT EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
         	                 WHERE CL.Storerkey = @c_Storerkey
         	                 AND CL.Code = 'NOFILTEREMPTYLOT8'
         	                 AND CL.Listname = 'PKCODECFG'
         	                 AND CL.Long = 'nspPRTW19'
         	                 AND ISNULL(CL.Short,'') <> 'N') 
         	  BEGIN              
               SELECT @c_Condition = RTRIM(@c_Condition) + ' AND LOTTABLE08 = '''' '
            END        		
        END        

        IF ISNULL(RTRIM(@c_Lottable09), '') <> ''  
        BEGIN  
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable09 = N'" + RTRIM(@c_Lottable09) + "' "  
        END    
        ELSE    
        BEGIN
         	  IF NOT EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
         	                 WHERE CL.Storerkey = @c_Storerkey
         	                 AND CL.Code = 'NOFILTEREMPTYLOT9'
         	                 AND CL.Listname = 'PKCODECFG'
         	                 AND CL.Long = 'nspPRTW19'
         	                 AND ISNULL(CL.Short,'') <> 'N') 
         	  BEGIN              
               SELECT @c_Condition = RTRIM(@c_Condition) + ' AND LOTTABLE09 = '''' '
            END        		
        END        

        IF ISNULL(RTRIM(@c_Lottable10), '') <> ''  
        BEGIN  
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable10 = N'" + RTRIM(@c_Lottable10) + "' "  
        END    
        ELSE    
        BEGIN
         	  IF NOT EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
         	                 WHERE CL.Storerkey = @c_Storerkey
         	                 AND CL.Code = 'NOFILTEREMPTYLOT10'
         	                 AND CL.Listname = 'PKCODECFG'
         	                 AND CL.Long = 'nspPRTW19'
         	                 AND ISNULL(CL.Short,'') <> 'N') 
         	  BEGIN              
               SELECT @c_Condition = RTRIM(@c_Condition) + ' AND LOTTABLE10 = '''' '
            END        		
        END        

        IF ISNULL(RTRIM(@c_Lottable11), '') <> ''  
        BEGIN  
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable11 = N'" + RTRIM(@c_Lottable11) + "' "  
        END    
        ELSE    
        BEGIN
         	  IF NOT EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
         	                 WHERE CL.Storerkey = @c_Storerkey
         	                 AND CL.Code = 'NOFILTEREMPTYLOT11'
         	                 AND CL.Listname = 'PKCODECFG'
         	                 AND CL.Long = 'nspPRTW19'
         	                 AND ISNULL(CL.Short,'') <> 'N') 
         	  BEGIN              
               SELECT @c_Condition = RTRIM(@c_Condition) + ' AND LOTTABLE11 = '''' '
            END        		
        END        

        IF ISNULL(RTRIM(@c_Lottable12), '') <> ''  
        BEGIN  
            SELECT @c_Condition = RTRIM(@c_Condition) + " AND Lotattribute.Lottable12 = N'" + RTRIM(@c_Lottable12) + "' "  
        END    
        ELSE    
        BEGIN
         	  IF NOT EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
         	                 WHERE CL.Storerkey = @c_Storerkey
         	                 AND CL.Code = 'NOFILTEREMPTYLOT12'
         	                 AND CL.Listname = 'PKCODECFG'
         	                 AND CL.Long = 'nspPRTW19'
         	                 AND ISNULL(CL.Short,'') <> 'N') 
         	  BEGIN              
               SELECT @c_Condition = RTRIM(@c_Condition) + ' AND LOTTABLE12 = '''' '
            END        		
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

        IF @c_UOM = '1' --Pallet
        BEGIN
        	 IF @c_OrderUOM IN('CS','EA') AND @n_OrderQty < @n_UOMBase
        	    SELECT @c_Condition = RTRIM(@c_Condition) + " AND 1 = 2 "   
        END
        ELSE IF @c_UOM = '2' --Case
        BEGIN 
        	 IF @c_OrderUOM IN('CS','EA') AND @n_OrderQty < @n_UOMBase
        	    SELECT @c_Condition = RTRIM(@c_Condition) + " AND 1 = 2 "           	
        END
        ELSE IF @c_UOM = '6' --Each
        BEGIN
        	 IF @c_OrderUOM IN('CS') 
        	    SELECT @c_Condition = RTRIM(@c_Condition) + " AND 1 = 2 "           	
        END                             

        SELECT TOP 1 @dt_LastOrderDate = CONVERT(DATETIME, UDF01)
        FROM CONSIGNEESKU CS (NOLOCK)
        WHERE Consigneekey = @c_ConsigneeKey
        AND Storerkey = @c_Storerkey
        AND SKu = @c_Sku
        AND ISDATE(UDF01) = 1
        ORDER BY UDF01 DESC 

        IF @dt_LastOrderDate IS NULL
        BEGIN     
           SELECT TOP 1 @dt_LastOrderDate = LA.Lottable04
           FROM PREALLOCATEPICKDETAIL PR (NOLOCK)
           JOIN LOTATTRIBUTE LA (NOLOCK) ON PR.Lot = LA.Lot
           WHERE PR.Orderkey = @c_Orderkey
           AND PR.Storerkey = @c_Storerkey
           AND PR.Sku = @c_Sku
           ORDER BY LA.Lottable04
        END
        
        --NJOW01 S                
        IF @dt_LastOrderDate IS NOT NULL
        BEGIN
           SET @c_SQL = 
                 " SELECT @n_QtyAvailable = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), @dt_MinLottable04 = MIN(LOTATTRIBUTE.Lottable04) " +     
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
                 " AND LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED > 0 " +
                 " AND DATEDIFF(month, LOTATTRIBUTE.Lottable04, @dt_LastOrderDate) = 0 " + --find the stock with same expiry month of last order
                 @c_Condition 
           
           EXEC sp_executesql @c_SQL,
              N'@n_QtyAvailable INT OUTPUT, @dt_MinLottable04 DATETIME OUTPUT, @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_Facility NVARCHAR(5), @dt_LastOrderDate DATETIME', 
              @n_QtyAvailable OUTPUT,
              @dt_MinLottable04 OUTPUT,
              @c_Storerkey,
              @c_Sku,
              @c_Facility, 
              @dt_LastOrderDate        	
        END 
        
        IF ISNULL(@n_QtyAvailable,0) < @n_OrderQty  --if the expiry date of same month less than order qty or no last order, find other month
        BEGIN
        	 SET @n_QtyAvailable = 0
           SET @c_SQL = 
                 " SELECT TOP 1 @n_QtyAvailable = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), @dt_MinLottable04 = MIN(LOTATTRIBUTE.Lottable04) " +     
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
                 " AND LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED > 0 " +
                 @c_Condition +
                 " GROUP BY CONVERT(NVARCHAR(6), LOTATTRIBUTE.Lottable04, 112) " +
                 " HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_OrderQty " +
                 " ORDER BY CONVERT(NVARCHAR(6), LOTATTRIBUTE.Lottable04, 112) "
           
           EXEC sp_executesql @c_SQL,
              N'@n_QtyAvailable INT OUTPUT, @dt_MinLottable04 DATETIME OUTPUT, @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_Facility NVARCHAR(5), @dt_LastOrderDate DATETIME, @n_OrderQty INT', 
              @n_QtyAvailable OUTPUT,
              @dt_MinLottable04 OUTPUT,
              @c_Storerkey,
              @c_Sku,
              @c_Facility, 
              @dt_LastOrderDate,
              @n_OrderQty
        END        
        --NJOW01 E       
        
        /* --NJOW01 Removed
        SET @c_SQL = 
              " SELECT TOP 1 @n_QtyAvailable = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), @dt_MinLottable04 = MIN(LOTATTRIBUTE.Lottable04) " +     
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
              " AND LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED > 0 " +
              CASE WHEN @dt_LastOrderDate IS NOT NULL THEN ' AND DATEDIFF(month, LOTATTRIBUTE.Lottable04, @dt_LastOrderDate) = 0 ' ELSE ' ' END  + --find the stock with same expiry month of last order
              @c_Condition +
              CASE WHEN @dt_LastOrderDate IS NULL THEN ' GROUP BY CONVERT(NVARCHAR(6), LOTATTRIBUTE.Lottable04, 112)' ELSE ' ' END +   --if no last order, find the stock with early expiry of same month
              CASE WHEN @dt_LastOrderDate IS NULL THEN ' ORDER BY CONVERT(NVARCHAR(6), LOTATTRIBUTE.Lottable04, 112)' ELSE ' ' END
        
        EXEC sp_executesql @c_SQL,
           N'@n_QtyAvailable INT OUTPUT, @dt_MinLottable04 DATETIME OUTPUT, @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_Facility NVARCHAR(5), @dt_LastOrderDate DATETIME', 
           @n_QtyAvailable OUTPUT,
           @dt_MinLottable04 OUTPUT,
           @c_Storerkey,
           @c_Sku,
           @c_Facility, 
           @dt_LastOrderDate
        */   
        
        --IF @dt_LastOrderDate IS NOT NULL
        --BEGIN                         
           IF ISNULL(@n_QtyAvailable,0) < @n_OrderQty --if the expiry date of same month less than order qty not to allocate
           BEGIN
              DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
                SELECT NULL, NULL, NULL, 0
              
              RETURN              	
           END               
        --END
                
        SELECT @c_SQL = " DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +   
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
                 " AND LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED >= @n_UOMBase "  +
                 CASE WHEN @dt_MinLottable04 IS NOT NULL THEN ' AND DATEDIFF(month, LOTATTRIBUTE.Lottable04, @dt_MinLottable04) = 0 ' ELSE ' ' END  +  --find the stock with same expiry month
                 @c_Condition + 
                 " GROUP BY LOT.StorerKey, LOT.Sku, LOT.Lot, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable04 " +   
                 " HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) >= @n_UOMBase " +   
                 " ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable06 DESC, LOTATTRIBUTE.Lottable05, LOT.Lot "                         	

       EXEC sp_executesql @c_SQL,
          N'@c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_Facility NVARCHAR(5), @n_UOMBase INT, @dt_MinLottable04 DATETIME', 
          @c_Storerkey,
          @c_Sku,
          @c_Facility,
          @n_UOMBase, 
          @dt_MinLottable04 
    END  
END    

GO