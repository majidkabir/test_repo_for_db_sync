SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/***************************************************************************/    
/* Stored Procedure: isp_PickLocInvCheckList                               */    
/* Creation Date: 28-Aug-2018                                              */    
/* Copyright: LFL                                                          */    
/* Written by:                                                             */    
/*                                                                         */    
/* Purpose: WMS-6825 TW Pick Loc Inventory Check List                      */    
/*                                                                         */    
/*                                                                         */    
/* Called By: r_dw_picklocinvchecklist                                     */    
/*                                                                         */    
/* PVCS Version: 1.0                                                       */    
/*                                                                         */    
/* Version: 7.0                                                            */    
/*                                                                         */    
/* Data Modifications:                                                     */    
/*                                                                         */    
/* Updates:                                                                */    
/* Date         Author  Ver   Purposes                                     */    
/***************************************************************************/    
CREATE PROC [dbo].[isp_PickLocInvCheckList]    
           @c_StorerKey        NVARCHAR(15) 
AS    
BEGIN    
   SET NOCOUNT ON     
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @b_debug INT
          ,@n_continue int    
          ,@b_success   INT  
          ,@n_err       INT  
          ,@c_errmsg    NVARCHAR(255)  
  
   DECLARE @c_CurrSKU NVARCHAR(20)  
          ,@c_CurrStorer NVARCHAR(15)  
          ,@c_CurrLoc NVARCHAR(10)  
          ,@c_HostWHCode NVARCHAR(10)
          ,@c_SQL NVARCHAR(MAX)
          ,@n_QtyLocationMinimum INT
          ,@n_QtyLocationLimit INT
          ,@c_facility NVARCHAR(5)
          ,@n_BalQty INT
          ,@n_OverAllocateQty INT
                
   DECLARE @c_NoMixLottable01 NCHAR(1),
           @c_NoMixLottable02 NCHAR(1),
           @c_NoMixLottable03 NCHAR(1),
           @c_NoMixLottable04 NCHAR(1),
           @c_NoMixLottable05 NCHAR(1),
           @c_NoMixLottable06 NCHAR(1),
           @c_NoMixLottable07 NCHAR(1),
           @c_NoMixLottable08 NCHAR(1),
           @c_NoMixLottable09 NCHAR(1),
           @c_NoMixLottable10 NCHAR(1),
           @c_NoMixLottable11 NCHAR(1),
           @c_NoMixLottable12 NCHAR(1),
           @c_NoMixLottable13 NCHAR(1),
           @c_NoMixLottable14 NCHAR(1),
           @c_NoMixLottable15 NCHAR(1),
           @c_CurrLottable01 NVARCHAR(18),
           @c_CurrLottable02 NVARCHAR(18),
           @c_CurrLottable03 NVARCHAR(18),
           @dt_CurrLottable04 DATETIME,
           @dt_CurrLottable05 DATETIME,
           @c_CurrLottable06 NVARCHAR(30),
           @c_CurrLottable07 NVARCHAR(30),
           @c_CurrLottable08 NVARCHAR(30),
           @c_CurrLottable09 NVARCHAR(30),
           @c_CurrLottable10 NVARCHAR(30),
           @c_CurrLottable11 NVARCHAR(30),
           @c_CurrLottable12 NVARCHAR(30),
           @dt_CurrLottable13 DATETIME,
           @dt_CurrLottable14 DATETIME,
           @dt_CurrLottable15 DATETIME,
           @n_QtyAvailable INT
                                                             
   SELECT @n_continue=1, @n_err = 0, @b_success = 1, @c_errmsg = '', @b_debug = 0
       
   CREATE TABLE #BELOWMINSTOCK (Storerkey NVARCHAR(15) NULL, 
                                Sku NVARCHAR(15) NULL, 
                                Descr NVARCHAR(60) NULL,
                                Lottable02 NVARCHAR(18) NULL, 
                                Lottable04 DATETIME NULL, 
                                Lottable05 DATETIME NULL, 
                                Loc NVARCHAR(10) NULL, 
                                TotalCase INT NULL, 
                                TotalPiece INT NULL, 
                                TotalQty INT NULL)
     
   DECLARE CUR_SKUXLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT SKUxLOC.Storerkey, SKUxLOC.Sku, SKUxLOC.Loc, LOC.Facility,
             (SKUxLOC.Qty - SKUxLOC.QtyPicked) AS BalQty,  
             SKUxLOC.QtyLocationMinimum,
             SKUxLOC.QtyLocationLimit,      
             LOC.HostWHCode,
             LOC.NoMixLottable01, 
             LOC.NoMixLottable02, 
             LOC.NoMixLottable03, 
             LOC.NoMixLottable04, 
             LOC.NoMixLottable05, 
             LOC.NoMixLottable06, 
             LOC.NoMixLottable07, 
             LOC.NoMixLottable08, 
             LOC.NoMixLottable09, 
             LOC.NoMixLottable10, 
             LOC.NoMixLottable11, 
             LOC.NoMixLottable12, 
             LOC.NoMixLottable13, 
             LOC.NoMixLottable14, 
             LOC.NoMixLottable15,
             SKUXLoc.QtyExpected 
      From SKUxLOC (NOLOCK)   
      JOIN LOC (NOLOCK) ON SKUxLOC.LOC = LOC.LOC  
      JOIN SKU (NOLOCK) ON SKU.StorerKey = SKUxLOC.StorerKey    
                               AND  SKU.SKU = SKUxLOC.SKU
      JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey   
      OUTER APPLY dbo.fnc_skuxloc_extended(SKUxLOC.StorerKey, SKUxLOC.Sku, SKUxLOC.Loc) AS EXT                               
      WHERE SKUxLOC.LocationType IN('PICK','CASE')    
      AND SKUxLOC.StorerKey = @c_Storerkey
      AND (SKUxLOC.Qty - SKUxLOC.QtyAllocated) + ISNULL(EXT.PendingMoveIn,0) < SKUxLOC.QtyLocationMinimum
      AND (LOC.NoMixLottable01 = '1'
           OR LOC.NoMixLottable01 = '1'
           OR LOC.NoMixLottable02 = '1'
           OR LOC.NoMixLottable03 = '1'
           OR LOC.NoMixLottable04 = '1'
           OR LOC.NoMixLottable05 = '1'
           OR LOC.NoMixLottable06 = '1'
           OR LOC.NoMixLottable07 = '1'
           OR LOC.NoMixLottable08 = '1'
           OR LOC.NoMixLottable09 = '1'
           OR LOC.NoMixLottable10 = '1'
           OR LOC.NoMixLottable11 = '1'
           OR LOC.NoMixLottable12 = '1'
           OR LOC.NoMixLottable13 = '1'
           OR LOC.NoMixLottable14 = '1'
           OR LOC.NoMixLottable15 = '1')
      ORDER BY SKUxLOC.Storerkey, SKUxLOC.Sku, SKUxLOC.Loc

      OPEN CUR_SKUXLOC  
      
      FETCH NEXT FROM CUR_SKUXLOC INTO @c_CurrStorer, @c_CurrSKU, @c_CurrLoc, @c_Facility, @n_BalQty, @n_QtyLocationMinimum, @n_QtyLocationLimit, @c_HostWHCode, 
                                       @c_NoMixLottable01, @c_NoMixLottable02, @c_NoMixLottable03, @c_NoMixLottable04, @c_NoMixLottable05, @c_NoMixLottable06, @c_NoMixLottable07,
                                       @c_NoMixLottable08, @c_NoMixLottable09, @c_NoMixLottable10, @c_NoMixLottable11, @c_NoMixLottable12, @c_NoMixLottable13, @c_NoMixLottable14, @c_NoMixLottable15,
                                       @n_OverAllocateQty
                                             
      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
      BEGIN         
      	 IF @b_debug = 1
      	 BEGIN
      	 	 PRINT ''
      	 	 PRINT '-----------Start---------'
      	   PRINT '@c_CurrStorer=' + @c_currStorer + ' @c_CurrSku=' + @c_CurrSku + ' @c_CurrLoc=' + @c_CurrLoc + ' @n_BalQty=' + CAST(@n_BalQty AS NVARCHAR) 
      	   PRINT '@n_QtyLocationMinimum=' + CAST(@n_QtyLocationMinimum AS NVARCHAR) + ' @n_QtyLocationLimit=' + CAST(@n_QtyLocationLimit AS NVARCHAR) + ' @n_OverAllocateQty=' + CAST(@n_OverAllocateQty AS NVARCHAR)
      	   PRINT '@c_NoMixLottable1-15=' + @c_NoMixLottable01+@c_NoMixLottable02+@c_NoMixLottable03+@c_NoMixLottable04+@c_NoMixLottable05+@c_NoMixLottable06+@c_NoMixLottable07+
                  @c_NoMixLottable08+@c_NoMixLottable09+@c_NoMixLottable10+@c_NoMixLottable11+@c_NoMixLottable12+@c_NoMixLottable13+@c_NoMixLottable14+@c_NoMixLottable15
      	 END  

      	 IF @n_BalQty > 0 OR @n_OverAllocateQty > 0
      	 BEGIN
      	    SELECT TOP 1 @c_CurrLottable01 = LA.Lottable01,
      	                 @c_CurrLottable02 = LA.Lottable02,
      	                 @c_CurrLottable03 = LA.Lottable03,
      	                 @dt_CurrLottable04 = LA.Lottable04,
      	                 @dt_CurrLottable05 = LA.Lottable05,
      	                 @c_CurrLottable06 = LA.Lottable06,
      	                 @c_CurrLottable07 = LA.Lottable07,
      	                 @c_CurrLottable08 = LA.Lottable08,
      	                 @c_CurrLottable09 = LA.Lottable09,
      	                 @c_CurrLottable10 = LA.Lottable10,
      	                 @c_CurrLottable11 = LA.Lottable11,
      	                 @c_CurrLottable12 = LA.Lottable12,
      	                 @dt_CurrLottable13 = LA.Lottable13,
      	                 @dt_CurrLottable14 = LA.Lottable14,
      	                 @dt_CurrLottable15 = LA.Lottable15
      	    FROM LOTXLOCXID LLI (NOLOCK)
      	    JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
      	    WHERE LLI.Storerkey = @c_CurrStorer
      	    AND LLI.Sku = @c_CurrSku
      	    AND LLI.Loc = @c_Currloc
      	    AND (LLI.Qty - LLI.QtyPicked > 0 OR LLI.QtyExpected > 0 )
      	    ORDER BY LLI.Qtyexpected DESC, LLI.Qty DESC
      	    
         	  IF @b_debug = 1
         	     PRINT '@c_Currlottable1-15=' + @c_CurrLottable01+','+@c_CurrLottable02+','+@c_CurrLottable03+','+CONVERT(NVARCHAR,@dt_CurrLottable04,112)+','+CONVERT(NVARCHAR,@dt_CurrLottable05,112)+','+@c_CurrLottable06+','+@c_CurrLottable07+','+
                     @c_CurrLottable08+','+@c_CurrLottable09+','+@c_CurrLottable10+','+@c_CurrLottable11+','+@c_CurrLottable12+','+CONVERT(NVARCHAR,@dt_CurrLottable13,112)+','+CONVERT(NVARCHAR,@dt_CurrLottable14,112)+','+ CONVERT(NVARCHAR,@dt_CurrLottable15,12)      	    
      	 END
      	          
         SET @c_SQL = N'      	 
            SELECT @n_QtyAvailable  = SUM(LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated - LLI.QtyReplen)
            FROM LOTxLOCxID LLI(NOLOCK)    
            JOIN SKUXLOC (NOLOCK) ON LLI.Storerkey = SKUXLOC.Storerkey and LLI.Sku = SKUXLOC.Sku AND LLI.Loc = SKUXLOC.Loc
            JOIN LOC (NOLOCK) ON LLI.LOC = LOC.LOC    
            JOIN LOTATTRIBUTE (NOLOCK) ON LLI.LOT = LOTATTRIBUTE.LOT    
            JOIN LOT (NOLOCK) ON LLI.LOT = LOT.Lot    
            LEFT OUTER JOIN ID (NOLOCK) ON LLI.ID  = ID.ID    
            WHERE LLI.StorerKey = @c_CurrStorer    
            AND LLI.SKU = @c_CurrSKU    
            AND LOC.LocationFlag <> ''DAMAGE''    
            AND LOC.LocationFlag <> ''HOLD''    
            AND LOC.Status <> ''HOLD''    
            AND LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated - LLI.QtyReplen > 0    
            AND LLI.QtyExpected = 0 
            AND LLI.LOC <> @c_CurrLoc    
            AND SKUXLOC.LocationType NOT IN(''PICK'',''CASE'')
            AND LOT.Status     = ''OK''     
            AND ISNULL(ID.Status ,'''') <> ''HOLD'' ' + 
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable01 = '1' THEN ' AND LOTATTRIBUTE.Lottable01 = @c_currLottable01 ' ELSE '' END +          
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable02 = '1' THEN ' AND LOTATTRIBUTE.Lottable02 = @c_currLottable02 ' ELSE '' END +          
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable03 = '1' THEN ' AND LOTATTRIBUTE.Lottable03 = @c_currLottable03 ' ELSE '' END +          
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable04 = '1' THEN ' AND CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable04,112) = CONVERT(NVARCHAR,@dt_currLottable04,112) ' ELSE '' END +          
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable05 = '1' THEN ' AND CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable05,112) = CONVERT(NVARCHAR,@dt_currLottable05,112) ' ELSE '' END +          
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable06 = '1' THEN ' AND LOTATTRIBUTE.Lottable06 = @c_currLottable06 ' ELSE '' END +          
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable07 = '1' THEN ' AND LOTATTRIBUTE.Lottable07 = @c_currLottable07 ' ELSE '' END +          
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable08 = '1' THEN ' AND LOTATTRIBUTE.Lottable08 = @c_currLottable08 ' ELSE '' END +          
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable09 = '1' THEN ' AND LOTATTRIBUTE.Lottable09 = @c_currLottable09 ' ELSE '' END +          
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable10 = '1' THEN ' AND LOTATTRIBUTE.Lottable10 = @c_currLottable10 ' ELSE '' END +          
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable11 = '1' THEN ' AND LOTATTRIBUTE.Lottable11 = @c_currLottable11 ' ELSE '' END +          
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable12 = '1' THEN ' AND LOTATTRIBUTE.Lottable12 = @c_currLottable12 ' ELSE '' END +          
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable13 = '1' THEN ' AND CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable13,112) = CONVERT(NVARCHAR,@dt_currLottable13,112) ' ELSE '' END +          
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable14 = '1' THEN ' AND CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable14,112) = CONVERT(NVARCHAR,@dt_currLottable14,112) ' ELSE '' END +          
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable15 = '1' THEN ' AND CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable15,112) = CONVERT(NVARCHAR,@dt_currLottable15,112) ' ELSE '' END 
            
         SET @n_QtyAvailable = 0   
         EXEC sp_executesql @c_SQL,
             N'@n_QtyAvailable INT OUTPUT, @c_CurrStorer NVARCHAR(15), @c_CurrSku NVARCHAR(20), @c_CurrLoc NVARCHAR(10), 
               @c_CurrLottable01 NVARCHAR(18), @c_CurrLottable02 NVARCHAR(18), @c_CurrLottable03 NVARCHAR(18), @dt_CurrLottable04 DATETIME, @dt_CurrLottable05 DATETIME,
               @c_CurrLottable06 NVARCHAR(30), @c_CurrLottable07 NVARCHAR(30), @c_CurrLottable08 NVARCHAR(30), @c_CurrLottable09 NVARCHAR(30), @c_CurrLottable10 NVARCHAR(30),
               @c_CurrLottable11 NVARCHAR(30), @c_CurrLottable12 NVARCHAR(30), @dt_CurrLottable13 DATETIME, @dt_CurrLottable14 DATETIME, @dt_CurrLottable15 DATETIME',
             @n_QtyAvailable OUTPUT,
             @c_CurrStorer,
             @c_CurrSku,
             @c_CurrLoc,
             @c_CurrLottable01,
             @c_CurrLottable02,
             @c_CurrLottable03,
             @dt_CurrLottable04,
             @dt_CurrLottable05,
             @c_CurrLottable06,
             @c_CurrLottable07,
             @c_CurrLottable08,
             @c_CurrLottable09,
             @c_CurrLottable10,
             @c_CurrLottable11,
             @c_CurrLottable12,
             @dt_CurrLottable13,
             @dt_CurrLottable14,
             @dt_CurrLottable15
             
             IF @b_debug = 1
                PRINT '@n_QtyAvailable=' + CAST(@n_QtyAvailable AS NVARCHAR)
             
             IF @n_QtyAvailable < @n_QtyLocationMinimum
             BEGIN 
                SET @c_SQL = N'      	 
             	  INSERT INTO #BELOWMINSTOCK (Storerkey, Sku, Descr, Lottable02, Lottable04, Lottable05, Loc, TotalCase, TotalPiece, TotalQty)
                   SELECT LLI.Storerkey, LLI.Sku, SKU.Descr, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LLI.Loc,
                          CASE WHEN PACK.Casecnt > 0 THEN FLOOR(SUM(LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated - LLI.QtyReplen) / PACK.CaseCnt) ELSE 0 END,
                          CASE WHEN PACK.Casecnt > 0 THEN SUM(LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated - LLI.QtyReplen) % CAST(PACK.CaseCnt AS INT) ELSE 0 END,                                                    
                          SUM(LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated - LLI.QtyReplen)
                   FROM LOTxLOCxID LLI(NOLOCK)    
                   JOIN SKUXLOC (NOLOCK) ON LLI.Storerkey = SKUXLOC.Storerkey and LLI.Sku = SKUXLOC.Sku AND LLI.Loc = SKUXLOC.Loc
                   JOIN LOC (NOLOCK) ON LLI.LOC = LOC.LOC    
                   JOIN LOTATTRIBUTE (NOLOCK) ON LLI.LOT = LOTATTRIBUTE.LOT                       
                   JOIN LOT (NOLOCK) ON LLI.LOT = LOT.Lot    
                   JOIN SKU (NOLOCK) ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku
                   JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey 
                   LEFT OUTER JOIN ID (NOLOCK) ON LLI.ID  = ID.ID    
                   WHERE LLI.StorerKey = @c_CurrStorer    
                   AND LLI.SKU = @c_CurrSKU    
                   AND LOC.LocationFlag <> ''DAMAGE''    
                   AND LOC.LocationFlag <> ''HOLD''    
                   AND LOC.Status <> ''HOLD''    
                   AND LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated - LLI.QtyReplen > 0    
                   --AND LLI.QtyExpected = 0 
                   --AND LLI.LOC <> @c_CurrLoc    
                   --AND SKUXLOC.LocationType NOT IN(''PICK'',''CASE'')
                   AND LOT.Status     = ''OK''     
                   AND ISNULL(ID.Status ,'''') <> ''HOLD'' ' + 
                   CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable01 = '1' THEN ' AND LOTATTRIBUTE.Lottable01 = @c_currLottable01 ' ELSE '' END +          
                   CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable02 = '1' THEN ' AND LOTATTRIBUTE.Lottable02 = @c_currLottable02 ' ELSE '' END +          
                   CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable03 = '1' THEN ' AND LOTATTRIBUTE.Lottable03 = @c_currLottable03 ' ELSE '' END +          
                   CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable04 = '1' THEN ' AND CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable04,112) = CONVERT(NVARCHAR,@dt_currLottable04,112) ' ELSE '' END +          
                   CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable05 = '1' THEN ' AND CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable05,112) = CONVERT(NVARCHAR,@dt_currLottable05,112) ' ELSE '' END +          
                   CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable06 = '1' THEN ' AND LOTATTRIBUTE.Lottable06 = @c_currLottable06 ' ELSE '' END +          
                   CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable07 = '1' THEN ' AND LOTATTRIBUTE.Lottable07 = @c_currLottable07 ' ELSE '' END +          
                   CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable08 = '1' THEN ' AND LOTATTRIBUTE.Lottable08 = @c_currLottable08 ' ELSE '' END +          
                   CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable09 = '1' THEN ' AND LOTATTRIBUTE.Lottable09 = @c_currLottable09 ' ELSE '' END +          
                   CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable10 = '1' THEN ' AND LOTATTRIBUTE.Lottable10 = @c_currLottable10 ' ELSE '' END +          
                   CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable11 = '1' THEN ' AND LOTATTRIBUTE.Lottable11 = @c_currLottable11 ' ELSE '' END +          
                   CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable12 = '1' THEN ' AND LOTATTRIBUTE.Lottable12 = @c_currLottable12 ' ELSE '' END +          
                   CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable13 = '1' THEN ' AND CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable13,112) = CONVERT(NVARCHAR,@dt_currLottable13,112) ' ELSE '' END +          
                   CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable14 = '1' THEN ' AND CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable14,112) = CONVERT(NVARCHAR,@dt_currLottable14,112) ' ELSE '' END +          
                   CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable15 = '1' THEN ' AND CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable15,112) = CONVERT(NVARCHAR,@dt_currLottable15,112) ' ELSE '' END + 
                 ' GROUP BY LLI.Storerkey, LLI.Sku, SKU.Descr, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LLI.Loc, PACK.Casecnt '         

                 EXEC sp_executesql @c_SQL,
                     N'@c_CurrStorer NVARCHAR(15), @c_CurrSku NVARCHAR(20), @c_CurrLoc NVARCHAR(10), 
                       @c_CurrLottable01 NVARCHAR(18), @c_CurrLottable02 NVARCHAR(18), @c_CurrLottable03 NVARCHAR(18), @dt_CurrLottable04 DATETIME, @dt_CurrLottable05 DATETIME,
                       @c_CurrLottable06 NVARCHAR(30), @c_CurrLottable07 NVARCHAR(30), @c_CurrLottable08 NVARCHAR(30), @c_CurrLottable09 NVARCHAR(30), @c_CurrLottable10 NVARCHAR(30),
                       @c_CurrLottable11 NVARCHAR(30), @c_CurrLottable12 NVARCHAR(30), @dt_CurrLottable13 DATETIME, @dt_CurrLottable14 DATETIME, @dt_CurrLottable15 DATETIME',
                     @c_CurrStorer,
                     @c_CurrSku,
                     @c_CurrLoc,
                     @c_CurrLottable01,
                     @c_CurrLottable02,
                     @c_CurrLottable03,
                     @dt_CurrLottable04,
                     @dt_CurrLottable05,
                     @c_CurrLottable06,
                     @c_CurrLottable07,
                     @c_CurrLottable08,
                     @c_CurrLottable09,
                     @c_CurrLottable10,
                     @c_CurrLottable11,
                     @c_CurrLottable12,
                     @dt_CurrLottable13,
                     @dt_CurrLottable14,
                     @dt_CurrLottable15    	  
             END

         FETCH NEXT FROM CUR_SKUXLOC INTO @c_CurrStorer, @c_CurrSKU, @c_CurrLoc, @c_Facility, @n_BalQty, @n_QtyLocationMinimum, @n_QtyLocationLimit, @c_HostWHCode, 
                                          @c_NoMixLottable01, @c_NoMixLottable02, @c_NoMixLottable03, @c_NoMixLottable04, @c_NoMixLottable05, @c_NoMixLottable06, @c_NoMixLottable07,
                                          @c_NoMixLottable08, @c_NoMixLottable09, @c_NoMixLottable10, @c_NoMixLottable11, @c_NoMixLottable12, @c_NoMixLottable13, @c_NoMixLottable14, @c_NoMixLottable15,
                                          @n_OverAllocateQty         	                   	
      END
      CLOSE CUR_SKUXLOC
      DEALLOCATE CUR_SKUXLOC        	      	 
                
   QUIT_SP:
   
   SELECT * 
   FROM #BELOWMINSTOCK
   ORDER BY Sku, loc
END   

GO