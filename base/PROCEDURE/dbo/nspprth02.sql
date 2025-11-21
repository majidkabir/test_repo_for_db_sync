SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPRTH02                                          */
/* Creation Date: 17-JUN-2019                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-9194 TH YVES preallocation                              */
/*          copy from nspPRTH01                                         */
/*                                                                      */
/* Called By: nspOrderProcessing                                        */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver. Purposes                                   */
/* 14-Sep-2020  SPChin  1.1  INC1189002 - Bug Fixed                     */
/************************************************************************/

CREATE PROC [dbo].[nspPRTH02]
         @c_Storerkey   NVARCHAR(15) 
      ,  @c_Sku         NVARCHAR(20) 
      ,  @c_Lot         NVARCHAR(10) 
      ,  @c_Lottable01  NVARCHAR(18) 
      ,  @c_Lottable02  NVARCHAR(18) 
      ,  @c_Lottable03  NVARCHAR(18) 
      ,  @d_Lottable04  DATETIME 
      ,  @d_Lottable05  DATETIME  
      ,  @c_lottable06 NVARCHAR(30)   
      ,  @c_lottable07 NVARCHAR(30)   
      ,  @c_lottable08 NVARCHAR(30)  
      ,  @c_lottable09 NVARCHAR(30)  
      ,  @c_lottable10 NVARCHAR(30)  
      ,  @c_lottable11 NVARCHAR(30)  
      ,  @c_lottable12 NVARCHAR(30)  
      ,  @d_lottable13 DATETIME     
      ,  @d_lottable14 DATETIME       
      ,  @d_lottable15 DATETIME     
      ,  @c_UOM         NVARCHAR(10)  
      ,  @c_Facility    NVARCHAR(5)     -- added By Vicky for IDSV5 
      ,  @n_UOMBase     INT  
      ,  @n_QtyLeftToFulfill INT
      ,  @c_OtherParms  NVARCHAR(200) = ''

AS
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @b_Success                  INT
         , @n_Err                      INT
         , @c_ErrMsg                   NVARCHAR(255)
         , @n_StorerMinShelfLife       INT
         , @c_AllocateByConsNewExpiry  NVARCHAR(10)
         , @c_FromTableJoin            NVARCHAR(500)
         , @c_Where                    NVARCHAR(500)
         , @c_Condition                NVARCHAR(510)
         , @c_SQLStatement             NVARCHAR(4000) 
         , @n_QtyToTake                INT
         , @n_QtyAvailable             INT
         , @c_SQL                      NVARCHAR(MAX)
         --, @c_ODUserdefine02           NVARCHAR(18)
         --, @n_MinQty                   INT
         --, @n_PreallocatedQty          INT
         --, @n_AllocatedQty             INT
         , @c_Lottable04Label          NVARCHAR(10)

   --NJOW01
   DECLARE @c_Orderkey            NVARCHAR(10),
           @c_OrderLineNumber     NVARCHAR(5),
           @c_ID                  NVARCHAR(18),                                 
           @n_OutGoingShelfLife   INT,
           @n_ConsShelfLife       INT,
           @n_Shelflife           INT,
		       @c_SetSortingRule      NVARCHAR(10),       --CS01       
		       @c_SortBy              NVARCHAR(4000),     --CS01
		       @c_ExecStatements      NVARCHAR(4000),     --CS01    
		       @c_ExecArguments       NVARCHAR(4000)      --CS01

   SELECT  @n_StorerMinShelfLife = 0,
           @n_OutGoingShelfLife = 0,
           @n_ConsShelfLife = 0,
           @n_Shelflife = 0

   SET @c_AllocateByConsNewExpiry= ''
   SET @c_FromTableJoin          = ''
   SET @c_Where                  = ''
   SET @c_Condition              = ''
   SET @c_SQLStatement           = ''
   SET @c_SortBy                 = ''
   SET @c_SQL                    = ''
   
   IF @n_UOMBase = 0
   BEGIN
      DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT TOP 0 NULL, NULL, NULL, NULL 
      RETURN
   END

   --CS01 Start

   IF EXISTS(SELECT 1 FROM CODELKUP (NOLOCK)  
            WHERE ListName = 'PKCODECFG'  
            AND Storerkey = @c_Storerkey  
            AND Code = 'SetSortingRule'  
            AND Long = 'nspPRTH02'  
            AND ISNULL(Short,'') <> 'N')  
   BEGIN
      SET @c_SetSortingRule = 'Y'  
   END
   ELSE  
   BEGIN
      SET @c_SetSortingRule = 'N'  
  END

   --CS01 End

   --NJOW01
   IF LEN(@c_OtherParms) > 0 
   BEGIN
   	  SELECT @c_Orderkey = LEFT(@c_OtherParms, 10)
   	  SELECT @c_OrderLineNumber = SUBSTRING(@c_OtherParms, 11, 5)
   	  
   	  SELECT @c_ID = ID
          	 --@c_ODUserdefine02 = Userdefine02
   	  FROM ORDERDETAIL(NOLOCK)
   	  WHERE Orderkey = @c_Orderkey
   	  AND OrderLineNumber = @c_OrderLineNumber   	  
   	  
   	  /*
   	  IF ISNULL(@c_ODUserdefine02,'') <> ''
   	  BEGIN
   	  	 SELECT @n_PreallocatedQty = SUM(Qty)
   	  	 FROM PREALLOCATEPICKDETAIL (NOLOCK)
   	  	 WHERE Orderkey = @c_Orderkey
   	  	 AND Sku = @c_Sku
   	  	 
   	  	 SELECT @n_MinQty = MIN(SKUSET.Qty), @n_AllocatedQty = MAX(SKUSET.AllocatedQty)
   	  	 FROM (SELECT SKU, SUM(OpenQty) AS Qty, 
   	  	       SUM(QtyAllocated + QtyPicked) AS AllocatedQty
   	           FROM ORDERDETAIL (NOLOCK)
   	           WHERE Orderkey = @c_Orderkey
   	           AND Userdefine02 = @c_ODUserdefine02
   	           GROUP BY Sku) AS SKUSET
   	           
   	     IF @n_AllocatedQty > 0 AND @n_AllocatedQty < @n_MinQty
   	        SET @n_MinQty = @n_AllocatedQty
   	           
   	     IF @n_MinQty < 5 
   	     BEGIN
            DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
            SELECT TOP 0 NULL, NULL, NULL, NULL 
            RETURN   	     	
   	     END
   	     ELSE IF @n_MinQty < @n_QtyLeftToFulfill
   	     BEGIN
   	        SET @n_QtyLeftToFulfill = @n_MinQty - ISNULL(@n_PreallocatedQty,0)  --cater for multi line per sku
   	     END
   	  END
   	  */
   END

   --IF ISNULL(RTRIM(@c_Lot),'') = '' 
   --BEGIN
      /* Get Storer Minimum Shelf Life */
      SELECT @n_StorerMinShelfLife = ((SKU.Shelflife * STORER.MinShelflife/100) * -1),
             @n_OutGoingShelfLife = ISNULL(CASE WHEN ISNUMERIC(SKU.Susr2) = 1 THEN
                                         CAST(SKU.Susr2 AS INT)
                                     ELSE 0 END, 0) * -1,  --NJOW01
             @c_Lottable04Label = ISNULL(SKU.LOTTABLE04LABEL, '')                        
      FROM STORER WITH (NOLOCK)
      JOIN SKU WITH (NOLOCK) ON (STORER.Storerkey = SKU.Storerkey)
      WHERE STORER.Storerkey = @c_Storerkey
      --AND SKU.Facility = @c_Facility --INC1189002
      AND SKU.SKU = @c_Sku             --INC1189002

      IF @n_StorerMinShelfLife IS NULL SET @n_StorerMinShelfLife = 0
   
      -- Min Shelf Life Checking
      IF ISNULL(RTRIM(@c_Lottable04Label),'') <> ''
      BEGIN
         IF LEFT(ISNULL(LTRIM(RTRIM(@c_lot)),''), 1) = '*'
         BEGIN
            SELECT @n_shelflife = CONVERT(INT, SUBSTRING(@c_lot, 2, 9))

            -- Add by June 08.Dec.2003 (SOS17522), requested by Tomy to treat 1 - 60 as months & > 60 as days
            DECLARE @c_MinShelfLife60Mth NVARCHAR(1)
            SELECT @c_MinShelfLife60Mth = '0'
            SELECT @b_success = 0
            EXECUTE nspGetRight NULL,                       -- Facility
                             @c_storerkey,                  -- Storer
                             NULL,                          -- Sku
                             'MinShelfLife60Mth',
                             @b_success           OUTPUT,
                             @c_MinShelfLife60Mth OUTPUT,
                             @n_err               OUTPUT,
                             @c_errmsg            OUTPUT
            IF @b_success <> 1
            BEGIN
               SELECT @c_errmsg = 'nspPreAllocateOrderProcessing : ' + ISNULL(RTRIM(@c_errmsg),'')
            END

            IF @c_MinShelfLife60Mth = '1'
            BEGIN
               SELECT @c_Condition = @c_Condition + " AND CONVERT(CHAR(8),LOTATTRIBUTE.Lottable04, 112) >= N'"  + CONVERT(CHAR(8), DATEADD(DAY, @n_shelflife, GETDATE()), 112) + "' "
            END
            ELSE
            BEGIN
               IF @n_shelflife < 13
                  SELECT @c_Condition = @c_Condition + " AND CONVERT(CHAR(8),LOTATTRIBUTE.Lottable04, 112) >= N'"  + CONVERT(CHAR(8), DATEADD(MONTH, @n_shelflife, GETDATE()), 112) + "'"
               ELSE
                  SELECT @c_Condition = @c_Condition + " AND CONVERT(CHAR(8),LOTATTRIBUTE.Lottable04, 112) >= N'"  + CONVERT(CHAR(8), DATEADD(DAY, @n_shelflife, GETDATE()), 112) + "'"
            END
         END
         --ELSE
         --BEGIN
            -- IF Shelf Life not provided, filter Lottable04 < Today date
         --   SELECT @c_Condition = @c_Condition + " AND CONVERT(CHAR(8),LOTATTRIBUTE.Lottable04, 112) >= N'" + CONVERT(CHAR(8), GETDATE(), 112) + "'"
         --END
         
         SET @n_shelflife = 0
      END                                                        
   
      --NJOW01 Start
      SELECT TOP 1 @n_ConsShelfLife = ISNULL(D.Shelflife,0) * -1
      FROM ORDERS O (NOLOCK)
      JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
      JOIN STORER S (NOLOCK) ON O.Consigneekey = S.Storerkey
      JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
      JOIN DOCLKUP D(NOLOCK) ON S.CustomerGroupCode = D.ConsigneeGroup AND SKU.SkuGroup = D.SkuGroup         
      WHERE O.Orderkey = @c_Orderkey
      AND OD.Sku = @c_Sku

      IF @n_ConsShelfLife <> 0
         SELECT @n_Shelflife = @n_ConsShelfLife
      ELSE IF @n_OutGoingShelfLife <> 0 
         SELECT @n_Shelflife = @n_OutGoingShelfLife       
      ELSE IF @n_StorerMinShelfLife <> 0
         SELECT @n_Shelflife = @n_StorerMinShelfLife       
      ELSE
         SELECT @n_Shelflife = 0                       
      --NJOW01 End      
      
      --INC0411478 (START)  
      IF ISNULL(RTRIM(@c_Lottable01),'') <> ''    
      BEGIN  
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE01 = N''' + RTRIM(@c_Lottable01) + ''''  
      END  
      IF ISNULL(RTRIM(@c_Lottable02),'') <> ''   
      BEGIN  
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE02 = N''' + RTRIM(@c_Lottable02) + ''''  
      END  
      IF ISNULL(RTRIM(@c_Lottable03),'') <> ''   
      BEGIN  
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE03 = N''' + RTRIM(@c_Lottable03) + ''''  
      END  
      IF CONVERT(NVARCHAR(10), @d_Lottable04, 103) <> '01/01/1900' AND @d_Lottable04 IS NOT NULL  
      BEGIN  
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE04 = ''' + CONVERT(NVARCHAR(20), @d_Lottable04, 106) + ''''  
      END  
      IF CONVERT(NVARCHAR(10), @d_Lottable05, 103) <> '01/01/1900' AND @d_Lottable05 IS NOT NULL  
      BEGIN  
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE05 = ''' + CONVERT(NVARCHAR(20), @d_Lottable05, 106) + ''''  
      END  
        
      --NJOW01  
      IF ISNULL(RTRIM(@c_Lottable06),'') <> ''   
      BEGIN  
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE06 = N''' + RTRIM(@c_Lottable03) + ''''  
      END  
      IF ISNULL(RTRIM(@c_Lottable07),'') <> ''   
      BEGIN  
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE07 = N''' + RTRIM(@c_Lottable03) + ''''  
      END  
      IF ISNULL(RTRIM(@c_Lottable08),'') <> ''   
      BEGIN  
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE08 = N''' + RTRIM(@c_Lottable03) + ''''  
      END  
      IF ISNULL(RTRIM(@c_Lottable09),'') <> ''   
      BEGIN  
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE09 = N''' + RTRIM(@c_Lottable03) + ''''  
      END  
      IF ISNULL(RTRIM(@c_Lottable10),'') <> ''   
      BEGIN  
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE10 = N''' + RTRIM(@c_Lottable03) + ''''  
      END  
      IF ISNULL(RTRIM(@c_Lottable11),'') <> ''   
      BEGIN  
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE11 = N''' + RTRIM(@c_Lottable03) + ''''  
      END  
      IF ISNULL(RTRIM(@c_Lottable12),'') <> ''   
      BEGIN  
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE12 = N''' + RTRIM(@c_Lottable03) + ''''  
      END  
      IF CONVERT(NVARCHAR(10), @d_Lottable13, 103) <> '01/01/1900' AND @d_Lottable13 IS NOT NULL  
      BEGIN  
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE13 = ''' + CONVERT(NVARCHAR(20), @d_Lottable13, 106) + ''''  
      END  
      IF CONVERT(NVARCHAR(10), @d_Lottable14, 103) <> '01/01/1900' AND @d_Lottable14 IS NOT NULL  
      BEGIN  
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE14 = ''' + CONVERT(NVARCHAR(20), @d_Lottable14, 106) + ''''  
      END  
      IF CONVERT(NVARCHAR(10), @d_Lottable15, 103) <> '01/01/1900' AND @d_Lottable15 IS NOT NULL  
      BEGIN  
         SET @c_Condition = @c_Condition + ' AND LOTATTRIBUTE.LOTTABLE15 = ''' + CONVERT(NVARCHAR(20), @d_Lottable15, 106) + ''''  
      END  
      --INC0411478 (END)

      --NJOW01
      IF @n_ShelfLife <> 0
      BEGIN
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND DateAdd(Day, ' + CAST(@n_ShelfLife AS NVARCHAR(10)) + ', Lotattribute.Lottable04) > GetDate() ' 
      END       
      IF ISNULL(@c_ID,'') <> ''
      BEGIN
      	 SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND LOTxLOCxID.Id = N''' + RTRIM(@c_ID) + ''' '
      END

      /*
      IF @n_StorerMinShelfLife <> 0
      BEGIN
         SET @c_Condition = @c_Condition + ' AND DateAdd(Day, ' + CONVERT(NVARCHAR(10),@n_StorerMinShelfLife) 
                          + ', LOTATTRIBUTE.Lottable04) > GetDate()' 
      END 
      */

	    --CS01 Start
	    IF @c_SetSortingRule='N'
	    BEGIN
	       SET @c_SortBy = ' ORDER BY LOTATTRIBUTE.Lottable04, LOT.Lot' 
      END
	    ELSE
	    BEGIN
	       SET @c_SortBy = ' ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02,LOT.Lot'
	    END
	    --CS01 End

      SET @b_success = 0
      EXECUTE dbo.nspGetRight @c_facility
            ,  @c_Storerkey                     -- Storerkey
            ,  NULL                             -- Sku
            ,  'AllocateByConsNewExpiry'        -- Configkey
            ,  @b_Success                 OUTPUT
            ,  @c_AllocateByConsNewExpiry OUTPUT 
            ,  @n_Err                     OUTPUT
            ,  @c_errmsg                  OUTPUT
      
      IF @c_AllocateByConsNewExpiry = '1' 
         AND EXISTS (SELECT 1  
                     FROM STORER WITH (NOLOCK)
                     JOIN ORDERS WITH (NOLOCK) ON (STORER.Storerkey = ORDERS.Consigneekey)
                     WHERE ORDERS.Orderkey = LEFT(RTRIM(@c_OtherParms),10)
                     AND STORER.SUSR1 = 'nspPRTH02')
      BEGIN
         SET @c_FromTableJoin = ' FROM ORDERS WITH (NOLOCK)'
                      + ' JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)'
                      + ' JOIN LOTATTRIBUTE WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = LOTATTRIBUTE.Storerkey)' 
                      +                                 ' AND(ORDERDETAIL.Sku = LOTATTRIBUTE.Sku)'
                      + ' LEFT JOIN CONSIGNEESKU WITH (NOLOCK) ON (ORDERS.Consigneekey = CONSIGNEESKU.Consigneekey)'
                      +                                 ' AND(LOTATTRIBUTE.Sku = CONSIGNEESKU.ConsigneeSku)'
         SET @c_Where = ' WHERE ORDERS.Orderkey = ''' + LEFT(RTRIM(@c_OtherParms),10) + ''''  
                      + ' AND ORDERDETAIL.OrderLineNumber = ''' + SUBSTRING(RTRIM(@c_OtherParms),11,5) + '''' 
                      + ' AND LOTATTRIBUTE.Storerkey = N''' + RTRIM(@c_Storerkey) + ''''
                      + ' AND(LOTATTRIBUTE.Lottable04 >= ISNULL(CONSIGNEESKU.AddDate,CONVERT(DATETIME,''19000101'')))'

      END
      ELSE
      BEGIN
         SET @c_FromTableJoin = ' FROM LOTATTRIBUTE WITH (NOLOCK)' 
         SET @c_Where = ' WHERE LOTATTRIBUTE.Storerkey = N''' + RTRIM(@c_Storerkey) + '''' 

      END
       
      SET @c_SQLStatement =  N' DECLARE CURSOR_LOTAVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR'  
         + ' SELECT LOT.Storerkey, LOT.Sku, LOT.Lot,'  
         + ' QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED)'
         +              ' - MAX(LOT.QTYPREALLOCATED) )'  
         + @c_FromTableJoin
         + ' JOIN LOT         WITH (NOLOCK) ON (LOTATTRIBUTE.Lot = LOT.Lot) AND (LOT.STATUS = ''OK'')'
         + ' JOIN LOTxLOCxID  WITH (NOLOCK) ON (LOT.LOT = LOTxLOCxID.Lot)'
         + ' JOIN LOC         WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc) AND (LOC.STATUS = ''OK'')'
         +                                 'AND(LOC.LocationFlag = ''NONE'')'
         + ' JOIN ID          WITH (NOLOCK) ON (LOTxLOCxID.Id = ID.Id)'
         +                                 'AND(ID.STATUS = ''OK'')'
         + @c_Where 
         + ' AND   LOTATTRIBUTE.Sku = N''' + RTRIM(@c_Sku) + '''' 
         + ' AND   LOC.Facility = N''' + RTRIM(@c_Facility) + '''' 
         + @c_Condition 
         + ' GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable04,LOTATTRIBUTE.Lottable02'
         + ' HAVING SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED)'
         +      ' - MAX(LOT.QTYPREALLOCATED) > 0 ' 
		 + CHAR(13) + @c_SortBy 

      EXEC(@c_SQLStatement)
        

      OPEN CURSOR_LOTAVAILABLE                    
      
      FETCH NEXT FROM CURSOR_LOTAVAILABLE INTO @c_Storerkey, @c_Sku, @c_LOT, @n_QtyAvailable   
             
      WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)          
      BEGIN                            	                  
         IF @n_QtyLeftToFulfill >= @n_QtyAvailable
         BEGIN
         		 SET @n_QtyToTake = Floor(@n_QtyAvailable / @n_UOMBase) * @n_UOMBase
         END
         ELSE
         BEGIN
         	   SET @n_QtyToTake = Floor(@n_QtyLeftToFulfill / @n_UOMBase) * @n_UOMBase
         END     	 
                  
         IF @n_QtyToTake > 0
         BEGIN         	
            IF ISNULL(@c_SQL,'') = ''
            BEGIN
               SET @c_SQL = N'   
                     DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   
                     SELECT '''  + @c_Storerkey + ''', ''' + @c_Sku + ''', ''' + @c_Lot + ''', ''' + CAST(@n_QtyToTake AS NVARCHAR(10)) + ''' '
            END
            ELSE
            BEGIN
               SET @c_SQL = @c_SQL + N'  
                     UNION ALL
                     SELECT '''  + @c_Storerkey + ''', ''' + @c_Sku + ''', ''' + @c_Lot + ''', ''' + CAST(@n_QtyToTake AS NVARCHAR(10)) + '''  '
            END
            SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake       
         END
               
         FETCH NEXT FROM CURSOR_LOTAVAILABLE INTO @c_Storerkey, @c_Sku, @c_LOT, @n_QtyAvailable   
      END -- END WHILE FOR CURSOR_AVAILABLE          
      CLOSE CURSOR_LOTAVAILABLE
      DEALLOCATE CURSOR_LOTAVAILABLE          

      IF ISNULL(@c_SQL,'') <> ''
      BEGIN
         EXEC sp_ExecuteSQL @c_SQL
      END
      ELSE
      BEGIN
         DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT TOP 0 NULL, NULL, NULL, NULL 
      END
                                                                                	  
	  --	print @c_SQLStatement
	  --CS01 End
   --END   
END

GO