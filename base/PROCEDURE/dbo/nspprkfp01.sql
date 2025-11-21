SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: nspPRKFP01                                         */
/* Creation Date: 31-Mar-2007                                           */
/* Copyright: IDS                                                       */
/* Written by: MaryVong                                                 */
/*                                                                      */
/* Purpose: SOS69386 IDSPH Kraft Preallocate Strategy                   */
/*          Notes: Turn on configkey 'OrderInfo4Preallocation'          */
/*                                                                      */
/* Called By: nspPrealLOCateOrderProcessing		                        */
/*                                                                      */
/* PVCS Version: 1.0		                                                */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 19-Mar-2009  Audrey     SOS131215: add in ID.status = 'OK'           */
/* 10-Jun-2013  NJOW01     280591-Add storerconfig 'NSPPRKFP01_LOT4EXP' */
/*                         to use lottable04 as expiry date to calculate*/ 
/*                         shelflife                                    */
/* 06-Apr-2020  NJOW02     WMS-12817 add lottable 6-15 filter. Calculate*/
/*                         storer.shelflife without percentage by config*/
/************************************************************************/

CREATE PROC [dbo].[nspPRKFP01]
	@c_storerkey NVARCHAR(15),
	@c_sku NVARCHAR(20),
	@c_lot NVARCHAR(10),
	@c_lottable01 NVARCHAR(18),
	@c_lottable02 NVARCHAR(18),
	@c_lottable03 NVARCHAR(18),
	@d_lottable04 datetime,
	@d_lottable05 datetime,
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
	@c_uom NVARCHAR(10),
	@c_facility NVARCHAR(10),
	@n_uombase int,
	@n_qtylefttofulfill int,
	@c_OtherParms NVARCHAR(200)
AS
BEGIN
	
	DECLARE 
		@b_debug   int,
		@c_SQLStmt nvarchar(4000)

	SELECT @b_debug = 0
	SELECT @c_SQLStmt = ''

	DECLARE 
		@c_LimitString  			 	     NVARCHAR(255), -- To limit the where clause based on the user input  
    @c_OrderKey   				 	     NVARCHAR(10),
  	@n_SkuShelfLife 			 	     int,
 		@n_SkuOutgoingShelfLife  	   int, -- SKU.SUSR2
		@n_ConsigneeMinShelfLifePerc int, -- STORER.MinShelfLife (store as percentage, eg. 20 means 20%)
		@n_ConsigneeShelfLife		     int,
		@c_USECONSMINSHELFLIFE       NCHAR(1)

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
  				QtyAvailable = SUM(LOTXLOCXID.Qty-LOTXLOCXID.QtyAllocated-LOTXLOCXID.QtyPicked) - MIN(ISNULL(P.QtyPreallocated, 0))
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
		  	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND Lottable01= N''' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable01)) + ''''  
	      
		  IF @c_lottable02 <> ' '  
		  	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable02= N''' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable02)) + '''' 
	    
		  IF @c_lottable03 <> ' '  
	      	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable03= N''' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable03)) + ''''  
	    
		  IF @d_lottable04 IS NOT NULL AND @d_lottable04 <> '1900-01-01'
		  	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable04 = N''' + dbo.fnc_LTrim(dbo.fnc_RTrim(CONVERT(char(20), @d_lottable04))) + ''''  
	      
		  IF @d_lottable05 IS NOT NULL  AND @d_lottable05 <> '1900-01-01'
		  	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable05= N''' + dbo.fnc_LTrim(dbo.fnc_RTrim(CONVERT(char(20), @d_lottable05))) + ''''  
      
      --NJOW02
		  IF @c_lottable06 <> ' '  
		  	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable06= N''' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable06)) + '''' 
      
		  IF @c_lottable07 <> ' '  
		  	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable06= N''' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable07)) + '''' 
      
		  IF @c_lottable08 <> ' '  
		  	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable08= N''' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable08)) + '''' 
      
		  IF @c_lottable09 <> ' '  
		  	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable09= N''' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable09)) + '''' 
      
		  IF @c_lottable10 <> ' '  
		  	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable10= N''' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable10)) + '''' 
      
		  IF @c_lottable11 <> ' '  
		  	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable11= N''' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable11)) + '''' 
      
		  IF @c_lottable12 <> ' '  
		  	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable12= N''' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable12)) + '''' 
      
		  IF @d_lottable13 IS NOT NULL  AND @d_lottable13 <> '1900-01-01'
		  	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable13= N''' + dbo.fnc_LTrim(dbo.fnc_RTrim(CONVERT(char(20), @d_lottable13))) + ''''  
      
		  IF @d_lottable14 IS NOT NULL  AND @d_lottable14 <> '1900-01-01'
		  	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable14= N''' + dbo.fnc_LTrim(dbo.fnc_RTrim(CONVERT(char(20), @d_lottable14))) + ''''  
      
		  IF @d_lottable15 IS NOT NULL  AND @d_lottable15 <> '1900-01-01'
		  	SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable15= N''' + dbo.fnc_LTrim(dbo.fnc_RTrim(CONVERT(char(20), @d_lottable15))) + ''''  

      --NJOW02
      IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)  
			           WHERE CL.Storerkey = @c_Storerkey  
			           AND CL.Code = 'USECONSMINSHELFLIFE'  
			           AND CL.Listname = 'PKCODECFG'  
			           AND CL.Long = 'nspPRKFP01'  
			           AND ISNULL(CL.Short,'') <> 'N')		          			
         SET @c_USECONSMINSHELFLIFE = 'Y'
      ELSE			
         SET @c_USECONSMINSHELFLIFE = 'N'
     
      -- If no lottables found, only proceed to 
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_LimitString)) = '' OR dbo.fnc_LTrim(dbo.fnc_RTrim(@c_LimitString)) IS NULL 
         OR @c_USECONSMINSHELFLIFE = 'Y'  --NJOW02
      BEGIN
   	  	-- i)   Get SKU.ShelfLife, SKU.SUSR2 (SKU Outgoing ShelfLife)
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

   		-- Get OrderKey - @c_OtherParms pass-in OrderKey and OrderLineNumber	
   		IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_OtherParms)) IS NOT NULL AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_OtherParms)) <> ''
   		BEGIN
   			SELECT @c_OrderKey = LEFT(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_OtherParms)), 10)
   		END
   	
   		-- Get Consignee MinShelfLife (store as int, but calculate in percentage)
   		SELECT @n_ConsigneeMinShelfLifePerc = ISNULL( STORER.MinShelfLife, 0)
   		FROM 	 ORDERS (NOLOCK)
   		JOIN 	 STORER (NOLOCK) ON (ORDERS.ConsigneeKey = STORER.StorerKey)
   		WHERE	 OrderKey = @c_OrderKey
   
   		-- If Consignee MinShelfLife is setup,
     		--	   Rule#2: Lottable04 + (SKU.ShelfLife * (Consignee.MinShelfLife (%) /100) ) >= GetDate()
      	-- Else
   		-- 	Rule#3: Lottable04 + SKU.SUSR2 (Outgoing ShelfLife) >= GetDate()
   		--	Notes: Lottable04 = Production Date
   		
   		IF EXISTS(SELECT 1 FROM STORERCONFIG(NOLOCK) 
   		          WHERE Configkey = 'NSPPRKFP01_LOT4EXP' 
   		          AND Storerkey = @c_Storerkey
   		          AND Svalue = '1')  
   		BEGIN   		
   			 --NJOW01
   		   IF @n_ConsigneeMinShelfLifePerc > 0
   		   BEGIN
   		   	IF @c_USECONSMINSHELFLIFE = 'Y'
   		   	   SELECT @n_ConsigneeShelfLife = @n_ConsigneeMinShelfLifePerc --NJOW02
					ELSE               					                		   	
   		   	   SELECT @n_ConsigneeShelfLife = (@n_SkuShelfLife * @n_ConsigneeMinShelfLifePerc) / 100
   		   	
   		   	SELECT @c_LimitString = dbo.fnc_RTrim(@c_LimitString) + ' AND DATEADD (Day, ' +
   		   									dbo.fnc_RTrim(CAST(@n_ConsigneeShelfLife as NVARCHAR(10))) + ' * -1, Lottable04) >= GetDate() '
   		   END
   		   ELSE
   		   BEGIN
   		   	SELECT @c_LimitString = dbo.fnc_RTrim(@c_LimitString) + ' AND DATEADD (Day, ' +
   		   									dbo.fnc_RTrim(CAST(@n_SkuOutgoingShelfLife as NVARCHAR(10))) + ' * -1, Lottable04) >= GetDate() '		
   		   END
   	  END
   	  ELSE
   	  BEGIN
   		   IF @n_ConsigneeMinShelfLifePerc > 0
   		   BEGIN
   		   	IF @c_USECONSMINSHELFLIFE = 'Y'
   		   	   SELECT @n_ConsigneeShelfLife = @n_ConsigneeMinShelfLifePerc --NJOW02
					ELSE               					                		   	
      		   SELECT @n_ConsigneeShelfLife = (@n_SkuShelfLife * @n_ConsigneeMinShelfLifePerc) / 100

   		   	SELECT @c_LimitString = dbo.fnc_RTrim(@c_LimitString) + ' AND DATEADD (Day, ' +
   		   									dbo.fnc_RTrim(CAST(@n_ConsigneeShelfLife as NVARCHAR(10))) + ', Lottable04) >= GetDate() '
   		   END
   		   ELSE
   		   BEGIN
   		   	SELECT @c_LimitString = dbo.fnc_RTrim(@c_LimitString) + ' AND DATEADD (Day, ' +
   		   									dbo.fnc_RTrim(CAST(@n_SkuOutgoingShelfLife as NVARCHAR(10))) + ', Lottable04) >= GetDate() '		
   		   END
   	  END
   	  
      END -- no lottables found

      -- Form Preallocate cursor
  		SELECT @c_SQLStmt = 'DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR ' +
  			' SELECT LOT.StorerKey, LOT.SKU, LOT.LOT, ' +
  			' QtyAvailable = SUM(LOTXLOCXID.Qty-LOTXLOCXID.QtyAllocated-LOTXLOCXID.QtyPicked) - MIN(ISNULL(P.QtyPreallocated, 0)) ' +
  			' FROM LOTXLOCXID (NOLOCK) ' +
			' JOIN LOT (NOLOCK) ON LOTXLOCXID.LOT = LOT.LOT ' +
  			' JOIN LOTATTRIBUTE (NOLOCK) ON LOTXLOCXID.LOT = LOTATTRIBUTE.LOT ' +
  			' JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC ' +
         ' JOIN ID (NOLOCK) ON LOTXLOCXID.ID = ID.ID ' + ---SOS131215 
         ' LEFT OUTER JOIN (SELECT P.LOT, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) ' +
         '					  FROM   PREALLOCATEPICKDETAIL P (NOLOCK), ORDERS (NOLOCK) ' +
         '					  WHERE  P.Orderkey = ORDERS.OrderKey ' +
         '					  AND    P.StorerKey = N''' + dbo.fnc_RTrim(@c_storerkey) + ''' ' + 
         '					  AND    P.SKU = N''' + dbo.fnc_RTrim(@c_sku) + ''' ' +
         '					  AND    P.Qty > 0 ' +
         '					  GROUP BY P.LOT, ORDERS.Facility) P ON LOTXLOCXID.LOT = P.LOT AND P.Facility = LOC.Facility	' +
  			' WHERE LOTXLOCXID.StorerKey = N''' + dbo.fnc_RTrim(@c_storerkey) + ''' ' +
			'   AND LOTXLOCXID.SKU = N''' + dbo.fnc_RTrim(@c_sku) + ''' ' +
 			'   AND LOTXLOCXID.Qty > 0 ' +
			'	 AND LOT.Status = ''OK'' ' +
			'	 AND LOC.Facility = N''' + dbo.fnc_RTrim(@c_facility) + ''' ' +
  			'	 AND LOC.Status = ''OK'' AND LOC.LocationFlag = ''NONE'' ' +
         '   and ID.Status = ''OK'' ' +   ---SOS131215 
	      dbo.fnc_RTrim(@c_LimitString) + ' ' +
	      ' GROUP BY LOT.StorerKey, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable05 ' + 
	 		' HAVING SUM(LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked) - MIN(ISNULL(P.QtyPreallocated, 0)) > 0 ' +
	 		CASE WHEN @c_USECONSMINSHELFLIFE = 'Y' THEN
	 		     ' ORDER BY LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05, LOTATTRIBUTE.LOTTABLE02, LOT.LOT '  --NJOW02
	 	  ELSE ' ORDER BY LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.LOTTABLE05 ' END

		EXEC (@c_SQLStmt)

		IF @b_debug = 1	PRINT @c_SQLStmt	

  	END
END

GO