SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspPR_PH02                                         */
/* Creation Date: 28-Nov-2016                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-684 PH Mondelez Allocation Based on ConsigneeSKU        */
/*          Modified from nspPRKFP01 - SOS69386                         */
/*          Notes: Turn on configkey 'OrderInfo4Preallocation'          */
/*                                                                      */
/* Called By: nspPrealLOCateOrderProcessing		                          */
/*                                                                      */
/* PVCS Version: 1.0		                                                */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 21-Nov-2019  TLTING  1.1   Dynamic SQL review, impact SQL cache log  */ 
/************************************************************************/

CREATE PROC [dbo].[nspPR_PH02]
	@c_storerkey NVARCHAR(15),
	@c_sku NVARCHAR(20),
	@c_lot NVARCHAR(10),
	@c_lottable01 NVARCHAR(18),
	@c_lottable02 NVARCHAR(18),
	@c_lottable03 NVARCHAR(18),
	@d_lottable04 DATETIME,
	@d_lottable05 DATETIME,
	@c_lottable06 NVARCHAR(30),
	@c_lottable07 NVARCHAR(30),
	@c_lottable08 NVARCHAR(30),
	@c_lottable09 NVARCHAR(30),
	@c_lottable10 NVARCHAR(30),
	@c_lottable11 NVARCHAR(30),
	@c_lottable12 NVARCHAR(30),
	@d_lottable13 DATETIME,
	@d_lottable14 DATETIME,
	@d_lottable15 DATETIME,
	@c_uom NVARCHAR(10),
	@c_facility NVARCHAR(10),
	@n_uombase INT,
	@n_qtylefttofulfill INT,
	@c_OtherParms NVARCHAR(200)
AS
BEGIN	
	DECLARE 
		@b_debug                    INT,
		@c_SQLStmt                  NVARCHAR(4000),
      @c_SQLParm                 NVARCHAR(4000),
	   @b_Success                  INT,
      @n_Err                      INT,
      @c_ErrMsg                   NVARCHAR(255),
      @c_AllocateByConsNewExpiry  NVARCHAR(10),
      @c_FromTableJoin            NVARCHAR(500),
      @c_Where                    NVARCHAR(500),
		@c_LimitString  			 	     NVARCHAR(255), -- To limit the where clause based on the user input  
      @c_OrderKey   				 	     NVARCHAR(10),
      @c_OrderLineNumber           NVARCHAR(5),
  	   @n_SkuShelfLife 			 	     INT,
 		@n_SkuOutgoingShelfLife  	   INT, -- SKU.SUSR2
		@n_ConsigneeMinShelfLifePerc INT, -- STORER.MinShelfLife (store as percentage, eg. 20 means 20%)
		@n_ConsigneeShelfLife		     INT,
		@c_Consigneekey              NVARCHAR(15),
		@c_ConSusr1                  NVARCHAR(10)
		
	SELECT @b_debug = 0
	SELECT @c_SQLStmt = ''
	SELECT @c_errmsg = '', @n_err = 0, @b_success = 0, @c_FromTableJoin = '', @c_Where = '', @c_LimitString = '', @c_ConSusr1 = ''


   /******************************************************************************************/
	/* Allocation priority																				         */
   /* ===================                                                                    */
   /* Rule#1: Specific Lot                                                                   */
   /* Rule#2: Lottable04 + (SKU.ShelfLife * (Consignee.MinShelfLife (%) /100) ) >= GetDate() */
   /* Rule#3: Lottable04 + SKU.SUSR2 (Outgoing ShelfLife) >= GetDate()                       */
   /******************************************************************************************/

	  -- If @c_LOT is not null
  	IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_LOT)) IS NOT NULL
  	BEGIN
  		DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
  			SELECT LOT.StorerKey, LOT.SKU, LOT.LOT, 
  				     QtyAvailable = SUM(LOTXLOCXID.Qty-LOTXLOCXID.QtyAllocated-LOTXLOCXID.QtyPicked-LOTXLOCXID.QtyReplen) - MIN(ISNULL(P.QtyPreallocated, 0))
  			FROM LOTXLOCXID (NOLOCK) 
			  JOIN LOT (NOLOCK) ON LOTXLOCXID.LOT = LOT.LOT
  			JOIN LOTATTRIBUTE (NOLOCK) ON LOTXLOCXID.LOT = LOTATTRIBUTE.LOT
  			JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC
         JOIN ID (NOLOCK) ON LOTXLOCXID.ID = ID.ID ---SOS131215   
         LEFT OUTER JOIN (SELECT P.LOT, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) 
         					       FROM   PREALLOCATEPICKDETAIL P (NOLOCK), ORDERS (NOLOCK) 
         					       WHERE  P.Orderkey = ORDERS.Orderkey 
         					       AND    P.StorerKey = dbo.fnc_RTrim(@c_storerkey)
         					       AND    P.SKU = dbo.fnc_RTrim(@c_sku)
         					       AND    P.Qty > 0
         					       GROUP BY P.LOT, ORDERS.Facility) P ON LOTXLOCXID.LOT = P.LOT AND P.Facility = LOC.Facility	
  			WHERE LOTXLOCXID.LOT = @c_LOT
 				AND LOTXLOCXID.Qty > 0
				AND LOT.Status = 'OK'
         AND ID.Status = 'OK' ---SOS131215 
				AND LOC.Facility = dbo.fnc_RTrim(@c_facility)
  		   AND LOC.Status = 'OK' AND LOC.LocationFlag = 'NONE'
  			GROUP BY LOT.StorerKey, LOT.SKU, LOT.LOT
         HAVING SUM(LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked) - MIN(ISNULL(P.QtyPreallocated, 0)) > 0
  	  END
	  ELSE
	  BEGIN
       SELECT @c_LimitString = ''
    
       -- Rule#1: Allocate specific LOT
	     -- Get lottables
	  	 IF @c_lottable01 <> ' '  
	  	 	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND Lottable01= @c_lottable01  '  
	       
	  	 IF @c_lottable02 <> ' '  
	  	 	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable02= @c_lottable02 ' 
	     
	  	 IF @c_lottable03 <> ' '  
	       	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable03= @c_lottable03 '  
	     
	  	 IF @d_lottable04 IS NOT NULL AND @d_lottable04 <> '1900-01-01'
	  	 	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable04 = @d_lottable04 '  
	       
	  	 IF @d_lottable05 IS NOT NULL  AND @d_lottable05 <> '1900-01-01'
	  	 	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable05= @d_lottable05 '  

	  	 IF @c_lottable06 <> ' '  
	       	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable06= @c_lottable06 '  

	  	 IF @c_lottable07 <> ' '  
	       	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable07= @c_lottable07 '  

	  	 IF @c_lottable08 <> ' '  
	       	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable08= @c_lottable08 '   

	  	 IF @c_lottable09 <> ' '  
	       	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable09= @c_lottable09 '  

	  	 IF @c_lottable10 <> ' '  
	       	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable10= @c_lottable10 '  

	  	 IF @c_lottable11 <> ' '  
	       	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable11= @c_lottable11 '  

	  	 IF @c_lottable12 <> ' '  
	       	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable12= @c_lottable12 '  

	  	 IF @d_lottable13 IS NOT NULL AND @d_lottable13 <> '1900-01-01'
	  	 	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable13 = @d_lottable13 '  

	  	 IF @d_lottable14 IS NOT NULL AND @d_lottable14 <> '1900-01-01'
	  	 	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable14 = @d_lottable14 '  

	  	 IF @d_lottable15 IS NOT NULL AND @d_lottable15 <> '1900-01-01'
	  	 	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable15 = @d_lottable15 '  

     	 -- Get OrderKey - @c_OtherParms pass-in OrderKey and OrderLineNumber	
     	 IF ISNULL(@c_OtherParms,'') <> ''
     	 BEGIN
     	    SELECT @c_OrderKey = LEFT(LTRIM(@c_OtherParms), 10)
     	    SELECT @c_OrderLineNumber = SUBSTRING(RTRIM(@c_OtherParms),11,5)
     	    
     	    SELECT TOP 1 @c_Consigneekey = ORDERS.Consigneekey,
     	                 @c_ConSusr1 = STORER.Susr1
     	    FROM ORDERS(NOLOCK)
     	    JOIN STORER (NOLOCK)ON ORDERS.Consigneekey = STORER.Storerkey
     	    WHERE ORDERS.Orderkey = @c_Orderkey
     	 END
         
       -- If no lottables found, only proceed to 
       IF ISNULL(@c_LimitString,'') = ''
       BEGIN
     	  	--  i)   Get SKU.ShelfLife, SKU.SUSR2 (SKU Outgoing ShelfLife)
     		  --	ii)  Get OrderKey from @c_OtherParms
     	  	--	iii) Get ConsigneeKey from Order, then get Storer.MinShelfLife (where storer = consignee)
    
     	  	-- Get SKU ShelfLife, SKU Outgoing ShelfLife(SKU.SUSR2)
     	  	SELECT @n_SkuShelfLife = SKU.Shelflife, 
     			       @n_SkuOutgoingShelfLife = ISNULL( CAST( SKU.SUSR2 as int), 0)
     	  	FROM  SKU (NOLOCK)
     	  	WHERE SKU.StorerKey = dbo.fnc_RTrim(@c_storerkey)
     			AND SKU.SKU = dbo.fnc_RTrim(@c_sku)
     	 
     		  IF dbo.fnc_LTrim(dbo.fnc_RTrim(@n_SkuShelfLife)) IS NULL 
     		  	SELECT @n_SkuShelfLife = 0

     		  IF dbo.fnc_LTrim(dbo.fnc_RTrim(@n_SkuOutgoingShelfLife)) IS NULL 
     		  	SELECT @n_SkuOutgoingShelfLife = 0
         	
     		  -- Get Consignee MinShelfLife (store as int, but calculate in percentage)
     		  SELECT @n_ConsigneeMinShelfLifePerc = ISNULL( STORER.MinShelfLife, 0)
     		  FROM 	 ORDERS (NOLOCK)
     		  JOIN 	 STORER (NOLOCK) ON (ORDERS.ConsigneeKey = STORER.StorerKey)
     		  WHERE	 OrderKey = @c_OrderKey

     		  IF dbo.fnc_LTrim(dbo.fnc_RTrim(@n_ConsigneeMinShelfLifePerc)) IS NULL 
     		  	SELECT @n_ConsigneeMinShelfLifePerc = 0
          
     		  -- If Consignee MinShelfLife is setup,
       	  --	  Rule#2: Lottable04 + (SKU.ShelfLife * (Consignee.MinShelfLife (%) /100) ) >= GetDate()
          --  Else
     		  -- 	Rule#3: Lottable04 + SKU.SUSR2 (Outgoing ShelfLife) >= GetDate()
     		  --	Notes: Lottable04 = Production Date
     		
     		  IF EXISTS(SELECT 1 FROM STORERCONFIG(NOLOCK) 
     		            WHERE Configkey = 'nspPR_PH02_LOT4EXP' 
     		            AND Storerkey = @c_Storerkey
     		            AND Svalue = '1')  
     		  BEGIN   		
     		     /*IF @n_ConsigneeMinShelfLifePerc > 0
     		     BEGIN
     		     	SELECT @n_ConsigneeShelfLife = (@n_SkuShelfLife * @n_ConsigneeMinShelfLifePerc) / 100
     		     	SELECT @c_LimitString = ' AND DATEADD (Day, ' +
     		     									dbo.fnc_RTrim(CAST(@n_ConsigneeShelfLife as NVARCHAR(10))) + ' * -1, Lottable04) >= GetDate() '
     		     END
     		     ELSE
     		     BEGIN
     		     	  SELECT @c_LimitString = ' AND DATEADD (Day, ' +
     		     									dbo.fnc_RTrim(CAST(@n_SkuOutgoingShelfLife as NVARCHAR(10))) + ' * -1, Lottable04) >= GetDate() '		
     		     END*/
  		     	 IF @n_ConsigneeMinShelfLifePerc > 0
  		     	 BEGIN
              	SELECT @n_ConsigneeShelfLife = @n_SkuShelfLife - @n_ConsigneeMinShelfLifePerc
      		     	SELECT @c_LimitString = ' AND DATEADD (Day, ( @n_ConsigneeShelfLife * -1), Lottable04) >= GetDate() '     		     
 		     		 END
     		     ELSE IF @n_SkuOutgoingShelfLife > 0
     		     BEGIN
     		     	  SELECT @c_LimitString = ' AND DATEADD (Day, (@n_SkuOutgoingShelfLife * -1), Lottable04) >= GetDate() '		
  	     		 END							
     	    END
     	    ELSE
     	    BEGIN
     		     /*IF @n_ConsigneeMinShelfLifePerc > 0
     		     BEGIN
     		     	  SELECT @n_ConsigneeShelfLife = (@n_SkuShelfLife * @n_ConsigneeMinShelfLifePerc) / 100
     		     	  SELECT @c_LimitString = ' AND DATEADD (Day, ' +
     		     	  								dbo.fnc_RTrim(CAST(@n_ConsigneeShelfLife as NVARCHAR(10))) + ', Lottable04) >= GetDate() '
     		     END
     		     ELSE
     		     BEGIN
     		     	  SELECT @c_LimitString = ' AND DATEADD (Day, ' +
     		     	  								dbo.fnc_RTrim(CAST(@n_SkuOutgoingShelfLife as NVARCHAR(10))) + ', Lottable04) >= GetDate() '		
     		     END*/
  		     	 IF @n_ConsigneeMinShelfLifePerc > 0
  		     	 BEGIN
    		     	  SELECT @n_ConsigneeShelfLife = @n_SkuShelfLife - @n_ConsigneeMinShelfLifePerc
     		        SELECT @c_LimitString = ' AND DATEADD (Day, @n_ConsigneeShelfLife, Lottable04) >= GetDate() '     		     
     		     END     		     
     		     ELSE IF @n_SkuOutgoingShelfLife > 0
     		     BEGIN
  		     	    SELECT @c_LimitString = ' AND DATEADD (Day, @n_SkuOutgoingShelfLife, Lottable04) >= GetDate() '		
     		     END
     	    END     	  
       END -- no lottables found
       
       SET @b_success = 0
       EXECUTE dbo.nspGetRight @c_facility
            ,  @c_Storerkey                     -- Storerkey
            ,  NULL                             -- Sku
            ,  'AllocateByConsNewExpiry'        -- Configkey
            ,  @b_Success                 OUTPUT
            ,  @c_AllocateByConsNewExpiry OUTPUT 
            ,  @n_Err                     OUTPUT
            ,  @c_errmsg                  OUTPUT

       IF ISNULL(@c_AllocateByConsNewExpiry,'') = '1' AND ISNULL(@c_Consigneekey,'') <> '' AND ISNULL(@c_ConSusr1 ,'') IN('Y','nspPRTH01')
       BEGIN
          SELECT @c_FromTableJoin = ' LEFT JOIN CONSIGNEESKU WITH (NOLOCK) ON (CONSIGNEESKU.Consigneekey = @c_Consigneekey ) '
                                                              +  ' AND (CONSIGNEESKU.ConsigneeSku = LOT.Sku) '
          SELECT @c_Where = ' AND (LOTATTRIBUTE.Lottable04 >= ISNULL(CONSIGNEESKU.AddDate,CONVERT(DATETIME,''19000101''))) '       
       END
    
       -- Form Preallocate cursor
    	 SELECT @c_SQLStmt = 'DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR ' +
    	 ' SELECT LOT.StorerKey, LOT.SKU, LOT.LOT, ' +
    	 ' QtyAvailable = SUM(LOTXLOCXID.Qty-LOTXLOCXID.QtyAllocated-LOTXLOCXID.QtyPicked-LOTXLOCXID.QtyReplen) - MIN(ISNULL(P.QtyPreallocated, 0)) ' +
    	 ' FROM LOTXLOCXID (NOLOCK) ' +
	  	 ' JOIN LOT (NOLOCK) ON LOTXLOCXID.LOT = LOT.LOT ' +
    	 ' JOIN LOTATTRIBUTE (NOLOCK) ON LOTXLOCXID.LOT = LOTATTRIBUTE.LOT ' +
    	 ' JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC ' +
       ' JOIN ID (NOLOCK) ON LOTXLOCXID.ID = ID.ID ' +  
       ' LEFT OUTER JOIN (SELECT P.LOT, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) ' +
       '					  FROM   PREALLOCATEPICKDETAIL P (NOLOCK), ORDERS (NOLOCK) ' +
       '					  WHERE  P.Orderkey = ORDERS.OrderKey ' +
       '					  AND    P.StorerKey = @c_storerkey ' + 
       '					  AND    P.SKU = @c_sku ' +
       '					  AND    P.Qty > 0 ' +
       '					  GROUP BY P.LOT, ORDERS.Facility) P ON LOTXLOCXID.LOT = P.LOT AND P.Facility = LOC.Facility ' +
       RTRIM(@c_FromTableJoin) + ' ' +
    	 ' WHERE LOTXLOCXID.StorerKey = @c_storerkey ' +
	  	 ' AND LOTXLOCXID.SKU = @c_sku ' +
 	  	 ' AND LOTXLOCXID.Qty > 0 ' +
	  	 ' AND LOT.Status = ''OK'' ' +
	  	 ' AND LOC.Facility = @c_facility ' +
    	 ' AND LOC.Status = ''OK'' AND LOC.LocationFlag = ''NONE'' ' +
       ' AND ID.Status = ''OK'' ' +   
       RTRIM(@c_Where) +  ' ' +
       RTRIM(@c_LimitString) + ' ' +
	     ' GROUP BY LOT.StorerKey, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable05 ' + 
	   	 ' HAVING SUM(LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyReplen) - MIN(ISNULL(P.QtyPreallocated, 0)) > 0 ' +
	     ' ORDER BY LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.Lottable05 '
    
--	  	 EXEC (@c_SQLStmt)


      SET @c_SQLParm =  N'@c_facility   NVARCHAR(5),  @c_storerkey  NVARCHAR(15), @c_SKU        NVARCHAR(20), ' +   
         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), ' +
            '@c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME,     @d_Lottable05 DATETIME,  ' +
            '@c_Lottable06 NVARCHAR(30), ' +
            '@c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), ' + 
            '@c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), ' + 
            '@d_Lottable13 DATETIME,     @d_Lottable14 DATETIME,     @d_Lottable15 DATETIME, ' +
            '@c_Consigneekey Nvarchar(15), @n_ConsigneeShelfLife INT, @n_SkuOutgoingShelfLife INT  '     
      
      EXEC sp_ExecuteSQL @c_SQLStmt, @c_SQLParm, @c_facility, @c_storerkey, @c_SKU,  @c_Lottable01, @c_Lottable02, @c_Lottable03,
                        @d_Lottable04, @d_Lottable05,  @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09, 
                         @c_Lottable10, @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,  
                         @c_Consigneekey, @n_ConsigneeShelfLife , @n_SkuOutgoingShelfLife  


    
	  	 IF @b_debug = 1	PRINT @c_SQLStmt	    
    END
END

GO