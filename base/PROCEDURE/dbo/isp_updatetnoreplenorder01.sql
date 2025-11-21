SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_UpdatetNoReplenOrder01                         */  
/* Creation Date: 24-APR-2021                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-16874 CN Sanrio update non-replen flag to orders not    */  
/*          require replenishment.                                      */
/* Called By:                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/************************************************************************/  
CREATE PROCEDURE [dbo].[isp_UpdatetNoReplenOrder01]   
     @c_Storerkey        NVARCHAR(15)  
   , @c_Facility         NVARCHAR(25)  
   , @d_StartDate        DATETIME
   , @d_EndDate          DATETIME    
AS        
BEGIN       
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue INT,
           @b_Success INT,
           @b_debug INT,
           @n_Err INT,
           @c_ErrMsg NVARCHAR(250),
           @n_StartTCnt INT,
           @c_SQL NVARCHAR(4000),                  
           @c_SQLParm NVARCHAR(4000),
           @c_SortBy NVARCHAR(2000),
           @n_RowID INT,
           @n_RowID2 INT,
           @c_Orderkey NVARCHAR(10),
           @c_Sku NVARCHAR(20),
           @n_OrderQty INT,
           @n_OpenQty INT,
           @c_QtyAvailable INT,
           @n_QtyTake INT,
           @n_OrderFulfillCnt INT,
           @c_Allocated NVARCHAR(5),
           @c_condition NVARCHAR(4000)
   
   DECLARE @c_Lottable01 NVARCHAR(18),              @c_Lottable02 NVARCHAR(18),
           @c_Lottable03 NVARCHAR(18),              @d_Lottable04 DATETIME,
           @d_Lottable05 DATETIME,
           @c_Lottable06 NVARCHAR(30),              @c_Lottable07 NVARCHAR(30),
           @c_Lottable08 NVARCHAR(30),              @c_Lottable09 NVARCHAR(30), 
           @c_Lottable10 NVARCHAR(30),              @c_Lottable11 NVARCHAR(30), 
           @c_Lottable12 NVARCHAR(30),              
           @d_Lottable13 DATETIME,                  @d_Lottable14 DATETIME, 
           @d_Lottable15 DATETIME,                  @c_Lottable13 NVARCHAR(30),              
           @c_Lottable14 NVARCHAR(30),              @c_Lottable15 NVARCHAR(30)
    
   SELECT @n_continue = 1, @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_StartTCnt = @@TRANCOUNT, @b_debug = 0
   SET @n_OrderFulfillCnt = 0
   
   IF @@TRANCOUNT = 0
      BEGIN TRAN 
      
   --Initialization
   IF @n_continue IN(1,2)
   BEGIN
      CREATE TABLE #TMP_ORDERS (RowID INT IDENTITY(1,1), 
                                Orderkey NVARCHAR(10), 
                                OrderQty INT, 
                                Allocated NVARCHAR(5) DEFAULT('N'))
      
      CREATE TABLE #TMP_INV (RowID INT IDENTITY(1,1),
                             Storerkey NVARCHAR(15), 
                             Sku NVARCHAR(20),
                             Lot NVARCHAR(10),
                             Qty INT,
                             QtyAllocated INT DEFAULT(0))
   END
     
   --Get data
   IF @n_continue IN(1,2)
   BEGIN
   	  --Get Orders
   	  SET @c_Condition = ''
   	  SELECT TOP 1 @c_condition = NOTES
   	  FROM CODELKUP (NOLOCK)
   	  WHERE Long = 'r_dw_updatenoreplenorder01'
   	  AND Storerkey = @c_Storerkey
   	  AND Code = 'ORDERCONDITION'
   	  AND ISNULL(Short,'') <> 'N'
   	  AND Listname = 'REPORTCFG'
   	  
   	  IF ISNULL(@c_Condition,'') <> ''
   	  BEGIN
   	     IF LEFT(LTRIM(@c_Condition), 4) <> 'AND '
   	        SET @c_Condition = 'AND ' + @c_Condition
   	  END
   	  
   	  SET @c_SortBy = ''
   	  SELECT TOP 1 @c_SortBy = NOTES   --e.g  MIN(ORDERS.Priority), MIN(ORDERS.Orderkey), MIN(ORDERS.AddDate)
   	  FROM CODELKUP (NOLOCK)
   	  WHERE Long = 'r_dw_updatenoreplenorder01'
   	  AND Storerkey = @c_Storerkey
   	  AND Code = 'ORDERSORTING'
   	  AND ISNULL(Short,'') <> 'N'
   	  AND Listname = 'REPORTCFG'
   	  
   	  IF ISNULL(@c_SortBy,'') <> ''
   	  BEGIN
   	     IF LEFT(LTRIM(@c_SortBy), 9) <> 'ORDER BY '
   	        SET @c_SortBy = 'ORDER BY ' + @c_SortBy
   	  END
   	  ELSE
   	  BEGIN
   	     SET @c_SortBy = 'ORDER BY ORDERS.Priority, ORDERS.AddDate, ORDERS.Orderkey' 
   	  END
   	  
   	  IF @b_debug = 1
   	  BEGIN
   	  	PRINT 'ORDERCONDITION: ' + @c_Condition
   	  	PRINT 'ORDERSORTING: ' + @c_SortBy
   	  	PRINT 'Date: ' + CAST(@d_StartDate AS NVARCHAR) + ' To ' + CAST(@d_EndDate AS NVARCHAR)
   	  END
   	     	      	  
      SET @c_SQL = N'      	  
   	     INSERT INTO #TMP_ORDERS (Orderkey, OrderQty, Allocated)
   	     SELECT ORDERS.Orderkey, SUM(ORDERDETAIL.OpenQty), ''N''
   	     FROM ORDERS (NOLOCK)
   	     JOIN ORDERDETAIL (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey
   	     WHERE ORDERS.Storerkey = @c_Storerkey
   	     AND ORDERS.Facility = @c_Facility
   	     AND ORDERS.Status = ''0''    	     
   	     --AND DATEDIFF(day, @d_StartDate, ORDERS.AddDate) >= 0 
   	     --AND DATEDIFF(day, ORDERS.AddDate, @d_EndDate) >= 0 
   	     AND ORDERS.Adddate BETWEEN @d_StartDate AND @d_EndDate ' +
   	     ISNULL(@c_Condition,'') + 
   	   ' GROUP BY ORDERS.Orderkey, ORDERS.DocType, ORDERS.AddDate, ORDERS.Priority ' +
   	     ISNULL(@c_SortBy,'')

      SET @c_SQLParm =  N'@c_StorerKey NVARCHAR(15), @c_Facility NVARCHAR(5), @d_StartDate DATETIME, @d_EndDate DATETIME' 
         
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_StorerKey, @c_Facility, @d_StartDate, @d_EndDate     	     	  
         	
   	  --Get Inventory
   	  SET @c_Condition = ''
   	  SELECT TOP 1 @c_condition = NOTES  --e.g.  SKUXLOC.LocationType IN('PICK','CASE') AND LOC.LocLevel = 1
   	  FROM CODELKUP (NOLOCK)
   	  WHERE Long = 'r_dw_updatenoreplenorder01'
   	  AND Storerkey = @c_Storerkey
   	  AND Code = 'PICKCONDITION'
   	  AND ISNULL(Short,'') <> 'N'
   	  AND Listname = 'REPORTCFG'
   	  
   	  IF ISNULL(@c_Condition,'') <> ''
   	  BEGIN
   	     IF LEFT(LTRIM(@c_Condition), 4) <> 'AND '
   	        SET @c_Condition = 'AND ' + @c_Condition
   	  END 
   	  ELSE
   	  BEGIN
   	     SET @c_condition = 'AND SKUXLOC.LocationType IN(''PICK'',''CASE'')'
   	  END
      	  
      SET @c_SQL = N'      	  
   	     INSERT INTO #TMP_INV (Storerkey, Sku, Lot, Qty, QtyAllocated)
   	     SELECT LOTXLOCXID.Storerkey, LOTXLOCXID.Sku, LOTXLOCXID.Lot, SUM(LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyReplen), 0
   	     FROM LOTXLOCXID (NOLOCK)
   	     JOIN LOT (NOLOCK) ON LOTXLOCXID.Lot = LOT.Lot
   	     JOIN LOC (NOLOCK) ON LOTXLOCXID.Loc = LOC.Loc
   	     JOIN ID (NOLOCK) ON LOTXLOCXID.Id = ID.Id
   	     JOIN SKUXLOC (NOLOCK) ON LOTXLOCXID.Storerkey = SKUXLOC.Storerkey AND LOTXLOCXID.Sku = SKUXLOC.Sku AND LOTXLOCXID.Loc = SKUXLOC.Loc
   	     JOIN (SELECT DISTINCT OD.Storerkey, OD.Sku 
   	           FROM #TMP_ORDERS O
   	           JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey) AS ITEM ON LOTXLOCXID.Storerkey = ITEM.Storerkey AND LOTXLOCXID.Sku = ITEM.Sku
   	     WHERE LOC.LocationFlag = ''NONE''
   	     AND LOC.Status = ''OK''
   	     AND ID.Status = ''OK''
   	     AND LOC.Status = ''OK''
   	     AND LOTXLOCXID.Storerkey = @c_Storerkey
   	     AND LOC.Facility = @c_Facility ' +
   	     ISNULL(@c_Condition,'') + 
   	   ' GROUP BY LOTXLOCXID.Storerkey, LOTXLOCXID.Sku, LOTXLOCXID.Lot
   	     HAVING SUM(LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyReplen) > 0   	
   	     ORDER BY LOTXLOCXID.Storerkey, LOTXLOCXID.Sku, LOTXLOCXID.Lot '     	      

         SET @c_SQLParm =  N'@c_StorerKey NVARCHAR(15), @c_Facility NVARCHAR(5)' 
         
         EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_StorerKey, @c_Facility     	     	  

      IF @b_debug = 1
   	  BEGIN
     	   PRINT 'PICKCONDITION: ' + @c_Condition
   	  	 SELECT * FROM #TMP_ORDERS
   	  	 SELECT * FROM #TMP_INV 
   	  END         
   END  
   
   --Check order fulfillment
   IF @n_continue IN(1,2)
   BEGIN
   	  --Loop order
      DECLARE CUR_ORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
        SELECT O.RowID, O.Orderkey, O.OrderQty
        FROM #TMP_ORDERS O
        ORDER BY O.RowID   	
     
      OPEN CUR_ORDER  
      
      FETCH NEXT FROM CUR_ORDER INTO @n_RowID, @c_Orderkey, @n_OrderQty
      
      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)            
      BEGIN
      	 --Loop order -> order line by lottable
      	 DECLARE CUR_ORDERLINE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      	    SELECT OD.Storerkey, OD.Sku, 
                   OD.Lottable01, OD.Lottable02, OD.Lottable03, OD.Lottable04, OD.Lottable05,
                   OD.Lottable06, OD.Lottable07, OD.Lottable08, OD.Lottable09, OD.Lottable10,       
                   OD.Lottable11, OD.Lottable12, OD.Lottable13, OD.Lottable14, OD.Lottable15,
                   SUM(OD.OpenQty) AS OpenQty
      	    FROM ORDERDETAIL OD (NOLOCK) 
      	    WHERE OD.Orderkey = @c_Orderkey      
      	    GROUP BY OD.Storerkey, OD.Sku, 
                     OD.Lottable01, OD.Lottable02, OD.Lottable03, OD.Lottable04, OD.Lottable05,
                     OD.Lottable06, OD.Lottable07, OD.Lottable08, OD.Lottable09, OD.Lottable10,       
                     OD.Lottable11, OD.Lottable12, OD.Lottable13, OD.Lottable14, OD.Lottable15      	 
                     
         OPEN CUR_ORDERLINE  
         
         FETCH NEXT FROM CUR_ORDERLINE INTO @c_Storerkey, @c_Sku, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04,
                                            @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,      
                                            @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15, @n_OpenQty     
                  
         WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)            
         BEGIN
         	  --Loop order -> order line -> inventory
         	  SET @c_SQL = N'   
         	     DECLARE CUR_INV CURSOR FAST_FORWARD READ_ONLY FOR
         	        SELECT RowId, (TI.Qty -  TI.QtyAllocated) AS QtyAvailable
         	        FROM #TMP_INV TI
         	        JOIN LOTATTRIBUTE LA (NOLOCK) ON TI.Lot = LA.Lot   
         	        WHERE TI.Storerkey = @c_Storerkey
         	        AND TI.Sku = @c_Sku
         	        AND TI.Qty - TI.QtyAllocated > 0 ' +
                  CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' END +
                  CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' END +
                  CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' END +
                  CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101' AND @d_Lottable04 IS NOT NULL THEN ' AND LA.Lottable04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) ' ELSE ' ' END +
                  CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable05 ,112) <> '19000101' AND @d_Lottable05 IS NOT NULL THEN ' AND LA.Lottable05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) ' ELSE ' ' END +
                  CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06 ' END +
                  CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07 ' END +
                  CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08 ' END +
                  CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09 ' END +
                  CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10 ' END +
                  CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11 ' END +
                  CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12 ' END +
                  CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101' AND @d_Lottable13 IS NOT NULL THEN ' AND LA.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' ELSE ' ' END +
                  CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101' AND @d_Lottable14 IS NOT NULL THEN ' AND LA.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' ELSE ' ' END +
                  CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101' AND @d_Lottable15 IS NOT NULL THEN ' AND LA.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' ELSE ' ' END +
                ' ORDER BY TI.RowID '
         
            SET @c_SQLParm =  N'@c_StorerKey NVARCHAR(15), @c_SKU NVARCHAR(20), ' +
                               '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME, ' +
                               '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), ' +
                               '@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME ' 

            EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                      @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12,
                      @d_Lottable13, @d_Lottable14, @d_Lottable15        
                       	     
            OPEN CUR_INV  
            
            FETCH NEXT FROM CUR_INV INTO @n_RowId2, @c_QtyAvailable                                               
                                                               
            WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2) AND @n_OpenQty > 0            
            BEGIN
            	 IF @c_QtyAvailable > @n_OpenQty
            	    SET @n_QtyTake = @n_OpenQty
            	 ELSE
            	    SET @n_QtyTake = @c_QtyAvailable
            	 
            	 SET @n_OpenQty = @n_OpenQty - @n_QtyTake
            	 SET @n_OrderQty = @n_OrderQty - @n_QtyTake
            	 
            	 UPDATE #TMP_INV 
            	 SET QtyAllocated = QtyAllocated + @n_QtyTake
            	 WHERE RowID = @n_RowId2            	       

               FETCH NEXT FROM CUR_INV INTO @n_RowId2, @c_QtyAvailable                                                           	
            END
            CLOSE CUR_INV
            DEALLOCATE CUR_INV
            
            IF @n_OpenQty > 0  --if any line can't fulfill skip to next order
               GOTO NEXT_ORDER            
         	           	           	  
            FETCH NEXT FROM CUR_ORDERLINE INTO @c_Storerkey, @c_Sku, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04,
                                               @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,      
                                               @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15, @n_OpenQty              	
         END         
         NEXT_ORDER:         
         CLOSE CUR_ORDERLINE
         DEALLOCATE CUR_ORDERLINE
         
         IF @n_OrderQty > 0
         BEGIN
            --rollback current order qtyallocated if cannot fulfill
            UPDATE #TMP_INV
            SET QtyAllocated = 0
            WHERE QtyAllocated > 0         	  
         END
         ELSE
         BEGIN            
            --confirm current order qtyallocated and deduct from qty
            UPDATE #TMP_INV
            SET Qty = Qty - QtyAllocated
            WHERE QtyAllocated > 0
            
            --clear qty allocated for current order after deduct from qty
            UPDATE #TMP_INV
            SET QtyAllocated = 0
            WHERE QtyAllocated > 0
            
            --mark the order as fully allocted
            UPDATE #TMP_ORDERS
            SET Allocated = 'Y'
            WHERE RowID = @n_RowID
         END
                                               
         FETCH NEXT FROM CUR_ORDER INTO @n_RowID, @c_Orderkey, @n_OrderQty
      END
      CLOSE CUR_ORDER
      DEALLOCATE CUR_ORDER                     
   END
   
   --Update fulfilled order
   IF @n_continue IN(1,2)
   BEGIN   	  
      DECLARE CUR_ORDER_UPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
        SELECT O.Orderkey, O.Allocated
        FROM #TMP_ORDERS O
        JOIN ORDERS (NOLOCK) ON O.Orderkey = ORDERS.Orderkey
        WHERE (O.Allocated = 'Y'
             OR ORDERS.Userdefine10 = 'NOREPLEN')
        ORDER BY O.RowID   	
      
      OPEN CUR_ORDER_UPD  
      
      FETCH NEXT FROM CUR_ORDER_UPD INTO @c_Orderkey, @c_Allocated
      
      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)            
      BEGIN
         IF @c_Allocated = 'Y'
         BEGIN
      	    UPDATE ORDERS WITH (ROWLOCK)
      	    SET Userdefine10 = 'NOREPLEN',
      	        Trafficcop = NULL      	    
      	    WHERE Orderkey = @c_Orderkey
      	    
      	    SELECT @n_Err =  @@ERROR 
      	    
            IF @n_Err <> 0 
            BEGIN
               SET @n_Continue = 3    
               SET @n_Err = 63500    
               SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Update Failed On Table ORDERS. (isp_UpdatetNoReplenOrder01)'
            END
            ELSE
              SET @n_OrderFulfillCnt = @n_OrderFulfillCnt + 1
         END
         ELSE
         BEGIN
      	    UPDATE ORDERS WITH (ROWLOCK)
      	    SET Userdefine10 = '',
      	        Trafficcop = NULL      	    
      	    WHERE Orderkey = @c_Orderkey
      	    
      	    SELECT @n_Err =  @@ERROR 
      	    
            IF @n_Err <> 0 
            BEGIN
               SET @n_Continue = 3    
               SET @n_Err = 63510    
               SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Update Failed On Table ORDERS. (isp_UpdatetNoReplenOrder01)'
            END
         END                   
      	
         FETCH NEXT FROM CUR_ORDER_UPD INTO @c_Orderkey, @c_Allocated      	
      END
      CLOSE CUR_ORDER_UPD
      DEALLOCATE CUR_ORDER_UPD        	
   END
      
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN         	 
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      SELECT 'Error: No order is updated.'
      UNION ALL
      SELECT @c_ErrMsg

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_UpdatetNoReplenOrder01'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      
      SELECT RTRIM(CAST(@n_OrderFulfillCnt AS NVARCHAR)) + ' orders are updated as NOREPLEN at ORDERS.Userdefine10.'      
   END      
END  

GO