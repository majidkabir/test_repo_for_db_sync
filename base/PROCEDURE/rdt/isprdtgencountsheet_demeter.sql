SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispRDTGenCountSheet_Demeter                        */
/* Creation Date:                                                       */
/* Copyright: Maersk                                                    */
/*                                                                      */
/* Purpose: Generate StockTake Count Sheet			                     */
/*                                                                      */
/* Called By: 		                                                      */
/*                                                                      */
/* PVCS Version: 1.14		                                             */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 2024-06-12   Dennis     FCR-235                                      */
/************************************************************************/

CREATE   PROC [RDT].[ispRDTGenCountSheet_Demeter] (
   @nFunc           INT
   ,@c_StorerKey     NVARCHAR( 15)
   ,@c_StockTakeKey NVARCHAR(10)
   ,@c_Loc NVARCHAR(10)
   ,@c_SKU NVARCHAR(20) = ''
   ,@c_TaskDetailKey NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   
   /***********************************************************************************************

                                    Stardard Generate CCDetail

   ***********************************************************************************************/
DECLARE @c_Facility	   NVARCHAR(5),
	@c_AisleParm	      NVARCHAR(60),
	@c_LevelParm	      NVARCHAR(60),
	@c_ZoneParm	         NVARCHAR(60),
	@c_HostWHCodeParm    NVARCHAR(60),
	@c_ClearHistory	   NVARCHAR(1),
	@c_WithQuantity      NVARCHAR(1),
	@c_EmptyLocation     NVARCHAR(1),
	@n_LinesPerPage      int,
	@c_SKUParm           NVARCHAR(125),
	-- Added by SHONG 01 OCT 2002
	@c_AgencyParm        NVARCHAR(150),
	@c_ABCParm           NVARCHAR(60),
	@c_SkuGroupParm      NVARCHAR(125),
	@c_ExcludeQtyPicked  NVARCHAR(1),
   @c_CCSheetNoKeyName NVARCHAR(30) -- NJOW03

-- declare a select condition variable for parameters
-- SOS42806 Changed NVARCHAR(250) and NVARCHAR(255) to NVARCHAR(800)
DECLARE @c_AisleSQL	   NVARCHAR(800),
	@c_LevelSQL	         NVARCHAR(800),
	@c_ZoneSQL	         NVARCHAR(800),
	@c_HostWHCodeSQL     NVARCHAR(800),
	@c_AisleSQL2	      NVARCHAR(800),
	@c_LevelSQL2	      NVARCHAR(800),
	@c_ZoneSQL2	         NVARCHAR(800),
	@c_HostWHCodeSQL2    NVARCHAR(800),
	@c_SKUSQL            NVARCHAR(800),
	@c_SKUSQL2           NVARCHAR(800),
	@b_success           int,
	@c_AgencySQL         NVARCHAR(800),
	@c_AgencySQL2        NVARCHAR(800),
	@c_ABCSQL            NVARCHAR(800),
	@c_ABCSQL2           NVARCHAR(800), 
	@c_SkuGroupSQL       NVARCHAR(800),
	@c_SkuGroupSQL2      NVARCHAR(800)

-- Add by June 12.Mar.02 FBR063
-- SOS42806
DECLARE   @c_StorerSQL  NVARCHAR(800)
, @c_StorerSQL2 NVARCHAR(800)
, @c_StorerParm NVARCHAR(60)
, @c_GroupLottable05 NVARCHAR(10)

SELECT @c_Facility = Facility,
	-- @c_StorerKey = StorerKey,     --Remark by June 12.Mar.02 FBR063
	@c_StorerParm = StorerKey,
	@c_AisleParm = AisleParm,
	@c_LevelParm = LevelParm,
	@c_ZoneParm = ZoneParm,
	@c_HostWHCodeParm = HostWHCodeParm,
	@c_WithQuantity = WithQuantity,
	@c_ClearHistory = ClearHistory,
	@c_EmptyLocation = EmptyLocation,
	@n_LinesPerPage = LinesPerPage,
	@c_SKUParm      = SKUParm,
	@c_GroupLottable05 = GroupLottable05,
	@c_AgencyParm = AgencyParm,
	@c_ABCParm = ABCParm,
	@c_SkuGroupParm = SkuGroupParm,
   @c_ExcludeQtyPicked = ExcludeQtyPicked    
FROM StockTakeSheetParameters (NOLOCK)
WHERE StockTakeKey = @c_StockTakeKey
SET NOCOUNT ON

/*
-- Remark by June 12.Mar.02 FBR063
IF @c_StorerKey IS NULL
BEGIN
RETURN
END
*/

IF @n_LinesPerPage = 0 OR @n_LinesPerPage IS NULL
SELECT @n_LinesPerPage = 999
 

UPDATE StockTakeSheetParameters
   SET FinalizeStage = 0,
       PopulateStage = 0,
       EditDate = GetDate(),  --tlting01
       EditWho  = SUser_SName()
WHERE StockTakeKey = @c_StockTakeKey

IF dbo.fnc_RTrim(@c_WithQuantity) = '' OR @c_WithQuantity IS NULL
SELECT @c_WithQuantity = 'N'

-- Create Temp Result Table
SELECT LOTxLOCxID.lot,
	LOTxLOCxID.loc,
	LOTxLOCxID.id,
	LOTxLOCxID.StorerKey,
	LOTxLOCxID.sku,
	LOTATTRIBUTE.Lottable01,
	LOTATTRIBUTE.Lottable02,
	LOTATTRIBUTE.Lottable03,
	LOTATTRIBUTE.Lottable04,
	LOTATTRIBUTE.Lottable05,
   LOTATTRIBUTE.Lottable06,
   LOTATTRIBUTE.Lottable07,
   LOTATTRIBUTE.Lottable08,
   LOTATTRIBUTE.Lottable09,
   LOTATTRIBUTE.Lottable10,
   LOTATTRIBUTE.Lottable11,
   LOTATTRIBUTE.Lottable12,
   LOTATTRIBUTE.Lottable13,
   LOTATTRIBUTE.Lottable14,
   LOTATTRIBUTE.Lottable15,
	Qty = 0,
	LOC.PutawayZone,
	LOC.LocLevel,
	Aisle = LOC.locAisle,
	LOC.Facility,
	LOC.CCLogicalLoc
INTO #RESULT
FROM	LOTxLOCxID (NOLOCK),
	SKU (NOLOCK),
	LOTATTRIBUTE (NOLOCK),
	LOC (NOLOCK)
WHERE	1=2

DECLARE @c_SQL NVARCHAR(max)

-- Start : SOS66279
DECLARE @c_sqlOther NVARCHAR(4000),
		  @c_sqlWhere NVARCHAR(4000),
		  @c_sqlGroup NVARCHAR(4000) 

SELECT  @c_sqlOther = ''
-- End : SOS66279

BEGIN
	-- Start : SOS66279
	IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) WHERE Stocktakekey = @c_StockTakeKey)
	BEGIN
	-- End : SOS66279
		SELECT @c_SQL =  'INSERT INTO #RESULT '
		+ 'SELECT LOTxLOCxID.lot,LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey,'
		+ 'LOTxLOCxID.sku,LOTATTRIBUTE.Lottable01,LOTATTRIBUTE.Lottable02,'
		+ 'LOTATTRIBUTE.Lottable03,LOTATTRIBUTE.Lottable04,LOTATTRIBUTE.Lottable05,
         LOTATTRIBUTE.Lottable06,LOTATTRIBUTE.Lottable07,LOTATTRIBUTE.Lottable08,LOTATTRIBUTE.Lottable09,
         LOTATTRIBUTE.Lottable10,LOTATTRIBUTE.Lottable11,LOTATTRIBUTE.Lottable12,LOTATTRIBUTE.Lottable13,
         LOTATTRIBUTE.Lottable14,LOTATTRIBUTE.Lottable15,'
	   + CASE WHEN @c_ExcludeQtyPicked = 'Y' THEN 'Qty = SUM(LOTxLOCxID.qty-LOTxLOCxID.qtypicked),' ELSE 'Qty = SUM(LOTxLOCxID.qty),' END
		+ 'LOC.PutawayZone,LOC.LocLevel,Aisle = LOC.locAisle,LOC.Facility, LOC.CCLogicalLoc '
		+ 'FROM	LOTxLOCxID (NOLOCK), SKU (NOLOCK), LOTATTRIBUTE (NOLOCK), LOC (NOLOCK) '
		+ 'WHERE LOTxLOCxID.StorerKey = SKU.StorerKey '
		+ 'AND   LOTxLOCxID.sku = SKU.sku '
		+ 'AND   LOTxLOCxID.lot = LOTATTRIBUTE.lot '
		+ 'AND   LOTxLOCxID.loc = LOC.loc '
		+ 'AND   LOC.LOC = "' + @c_Loc + '" '
	   
	   IF ISNULL(RTRIM(@c_SKU),'') <> ''
		BEGIN
		   SET @c_SQL = @c_SQL + ' AND   LOTxLOCxID.SKU = "' + ISNULL(RTRIM(@c_SKU),'') + '" '
		END
		
	   SELECT @c_SQL =  @c_SQL +  CASE WHEN @c_ExcludeQtyPicked = 'Y' THEN 'AND   LOTxLOCxID.Qty-LOTxLOCxID.QtyPicked > 0 ' ELSE 'AND   LOTxLOCxID.Qty > 0 ' END
		+ ' AND   LOC.Facility = "' + ISNULL(dbo.fnc_RTrim(@c_Facility), '') + '" '
		+ ISNULL(dbo.fnc_RTrim(@c_StorerSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_StorerSQL2), '') + ' '
		+ ISNULL(dbo.fnc_RTrim(@c_ZoneSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ZoneSQL2), '') + ' '
		+ ISNULL(dbo.fnc_RTrim(@c_AisleSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AisleSQL2), '') + ' '
		+ ISNULL(dbo.fnc_RTrim(@c_LevelSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_LevelSQL2), '') + ' '
		+ ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL2), '') + ' '
		+ ISNULL(dbo.fnc_RTrim(@c_SKUSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_SKUSQL2), '') + ' '
		+ ISNULL(dbo.fnc_RTrim(@c_AgencySQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AgencySQL2), '') + ' '
		+ ISNULL(dbo.fnc_RTrim(@c_ABCSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ABCSQL2), '') + ' '
		+ ISNULL(dbo.fnc_RTrim(@c_SkuGroupSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_SkuGroupSQL2), '') + ' '
		+ 'GROUP BY LOTxLOCxID.lot, LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey,'
		+ 'LOTxLOCxID.sku,LOTATTRIBUTE.Lottable01,LOTATTRIBUTE.Lottable02,LOTATTRIBUTE.Lottable03,'
		+ 'LOTATTRIBUTE.Lottable04,LOTATTRIBUTE.Lottable05,LOTATTRIBUTE.Lottable06,LOTATTRIBUTE.Lottable07,LOTATTRIBUTE.Lottable08,LOTATTRIBUTE.Lottable09,
         LOTATTRIBUTE.Lottable10,LOTATTRIBUTE.Lottable11,LOTATTRIBUTE.Lottable12,LOTATTRIBUTE.Lottable13,
         LOTATTRIBUTE.Lottable14,LOTATTRIBUTE.Lottable15,LOC.PutawayZone,LOC.LocLevel,LOC.locAisle, LOC.Facility, LOC.CCLogicalLoc'
	-- Start : SOS66279
	END 

END
--PRINT @c_sql
EXEC (@c_sql)

	DECLARE @c_lot	 NVARCHAR(10),
		--@c_loc		   NVARCHAR(10),
		@c_id		      NVARCHAR(18),
		--@c_sku		   NVARCHAR(20),
		@c_Lottable01 NVARCHAR(18),
		@c_Lottable02 NVARCHAR(18),
		@c_Lottable03 NVARCHAR(18),
		@d_Lottable04	datetime,
		@d_Lottable05	datetime,
      @c_Lottable06     NVARCHAR( 30),           
      @c_Lottable07     NVARCHAR( 30),           
      @c_Lottable08     NVARCHAR( 30),           
      @c_Lottable09     NVARCHAR( 30),           
      @c_Lottable10     NVARCHAR( 30),           
      @c_Lottable11     NVARCHAR( 30),           
      @c_Lottable12     NVARCHAR( 30),           
      @d_Lottable13     DATETIME,           
      @d_Lottable14     DATETIME,           
      @d_Lottable15     DATETIME,
		@n_qty		   int,
		@c_Aisle	      NVARCHAR(10),
		@n_LocLevel	   int,
		@c_prev_Facility   NVARCHAR(5),
		@c_prev_Aisle	    NVARCHAR(10),
		@n_prev_LocLevel   int,
		@c_ccdetailkey	    NVARCHAR(10),
		@c_ccsheetno	    NVARCHAR(10),
		@n_err		       int,
		@c_errmsg	       NVARCHAR(250),
		@n_LineCount       int,
		@c_PreLogLocation  NVARCHAR(18),
		@c_CCLogicalLoc    NVARCHAR(18),
      @n_SystemQty       int,
      @c_PrevZone        NVARCHAR(10),
      @c_PutawayZone     NVARCHAR(10)
SELECT @c_prev_Facility = " ", @c_prev_Aisle = "XX", @n_prev_LocLevel = 999, @c_PreLogLocation = '000'


DECLARE @c_bypassPAZone NVARCHAR(1)
-- SELECT @c_storerkey = SUBSTRING(@c_StorerSQL, CHARINDEX('"', @c_StorerSQL, 1),
--							 LEN(@c_StorerSQL) - CHARINDEX('"', @c_StorerSQL, 1))
SELECT TOP 1 
   @c_storerkey = TRIM( REPLACE( Value, '"', ''))
FROM STRING_SPLIT( @c_StorerParm, ',')

SELECT @b_success = 0
SELECT @c_storerkey '@c_storerkey'
Execute nspGetRight @c_Facility,	-- facility
   @c_storerkey, 	-- Storerkey
   null,				-- Sku
   'CCSHEETBYPASSPA',	-- Configkey
   @b_success		output,
   @c_bypassPAZone output,
   @n_err			output,
   @c_errmsg		output

IF @b_success <> 1 OR @c_bypassPAZone = '0'
	SELECT @c_bypassPAZone = 'N'	
ELSE
	SELECT @c_bypassPAZone = 'Y'	

IF @c_bypassPAZone = 'N'
BEGIN
	EXEC ('DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
			FOR  SELECT lot, loc, id, StorerKey, sku, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
         Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
         Lottable11, Lottable12, Lottable13, Lottable14, Lottable15,
	            CASE WHEN "' + @c_WithQuantity + '" = "Y" THEN qty ELSE 0 END,
	            Facility, Aisle, LocLevel, CCLogicalLoc, qty, PutawayZone 
	      FROM #RESULT
	      ORDER BY Facility, PutawayZone, Aisle, LocLevel, CCLogicalLoc, Loc, SKU')
END
ELSE
BEGIN
	EXEC ('DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
			FOR  SELECT lot, loc, id, StorerKey, sku, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
         Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
         Lottable11, Lottable12, Lottable13, Lottable14, Lottable15,
	            CASE WHEN "' + @c_WithQuantity + '" = "Y" THEN qty ELSE 0 END,
	            Facility, Aisle, LocLevel, CCLogicalLoc, qty, "" as PutawayZone 
	      FROM #RESULT
	      ORDER BY Facility, Aisle, LocLevel, CCLogicalLoc, Loc, SKU')
END
SELECT @n_err = @@ERROR  
IF @n_err <> 0
BEGIN    
  CLOSE cur_1    
  DEALLOCATE cur_1    
END    
ELSE
BEGIN  
  OPEN cur_1 
-- End - SOS23776

	SELECT @n_LineCount = 0
  SELECT @c_CCSheetNoKeyName = 'CSHEET'+LTRIM(RTRIM(@c_StockTakeKey)) --NJOW03
	
	FETCH NEXT FROM cur_1 INTO @c_lot, @c_loc, @c_id, @c_StorerKey, @c_sku, @c_Lottable01, @c_Lottable02, @c_Lottable03,
	@d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08,
	@c_Lottable09, @c_Lottable10,@c_Lottable11, @c_Lottable12, @d_Lottable13,
	@d_Lottable14, @d_Lottable15,@n_qty, @c_Facility, @c_Aisle, @n_LocLevel, @c_CCLogicalLoc, @n_SystemQty, @c_PutawayZone 
	
	WHILE @@FETCH_STATUS <> -1
	BEGIN
      
      SET @c_CCSheetNo = @c_TaskDetailKey
	
	   EXECUTE nspg_getkey
	   'CCDetailKey'
	   , 10
	   , @c_CCDetailKey OUTPUT
	   , @b_success OUTPUT
	   , @n_err OUTPUT
	   , @c_errmsg OUTPUT
	   IF dbo.fnc_RTrim(@c_lot) <> '' AND dbo.fnc_RTrim(@c_lot) IS NOT NULL 
	   BEGIN	
	      INSERT CCDETAIL (cckey, ccdetailkey, StorerKey, sku, lot, loc, id, qty, ccsheetno, Lottable01,
	      Lottable02, Lottable03, Lottable04, Lottable05,Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
         Lottable11, Lottable12, Lottable13, Lottable14, Lottable15, SystemQty)
	      VALUES (@c_StockTakeKey, @c_CCDetailKey, @c_StorerKey, @c_sku, @c_lot, @c_loc, @c_id, 0, @c_CCSheetNo,
	      @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,@c_Lottable06, @c_Lottable07, @c_Lottable08,
         @c_Lottable09, @c_Lottable10,@c_Lottable11, @c_Lottable12, @d_Lottable13,@d_Lottable14, @d_Lottable15, @n_SystemQty)
	   END
	   ELSE
	   BEGIN
         
	      INSERT CCDETAIL (cckey, ccdetailkey, StorerKey, sku, lot, loc, id, qty, ccsheetno, Lottable01,
	      Lottable02, Lottable03, Lottable04, Lottable05, Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
         Lottable11, Lottable12, Lottable13, Lottable14, Lottable15, SystemQty, Status)
	      VALUES (@c_StockTakeKey, @c_CCDetailKey, @c_StorerKey, @c_sku, @c_lot, @c_loc, @c_id, 0, @c_CCSheetNo,
	      @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08,
         @c_Lottable09, @c_Lottable10,@c_Lottable11, @c_Lottable12, @d_Lottable13,@d_Lottable14, @d_Lottable15, @n_SystemQty, 
         CASE WHEN @n_SystemQty = 0 THEN '4' ELSE '0' END)
	   END
	
	   SELECT @n_LineCount = @n_LineCount + 1
	   SELECT @c_prev_Aisle = @c_Aisle,
	         @n_prev_LocLevel = @n_LocLevel,
	         @c_PreLogLocation = @c_CCLogicalLoc,
	         @c_PrevZone = @c_PutawayZone 
	
	   FETCH NEXT FROM cur_1 INTO @c_lot, @c_loc, @c_id, @c_StorerKey, @c_sku, @c_Lottable01, @c_Lottable02,
				@c_Lottable03, @d_Lottable04, @d_Lottable05,@c_Lottable06, @c_Lottable07, @c_Lottable08,
            @c_Lottable09, @c_Lottable10,@c_Lottable11, @c_Lottable12, @d_Lottable13,@d_Lottable14, @d_Lottable15,
            @n_qty, @c_Facility, @c_Aisle, @n_LocLevel, @c_CCLogicalLoc,
	         @n_SystemQty, @c_PutawayZone 
	END -- WHILE
	CLOSE cur_1
	DEALLOCATE cur_1

   -- Blank LOC
   IF @n_LineCount = 0
   BEGIN
	   EXECUTE nspg_getkey
	   'CCDetailKey'
	   , 10
	   , @c_CCDetailKey OUTPUT
	   , @b_success OUTPUT
	   , @n_err OUTPUT
	   , @c_errmsg OUTPUT
      
      INSERT CCDETAIL (cckey, ccdetailkey, StorerKey, sku, lot, loc, id, qty, SystemQty, ccsheetno, 
         Lottable01, Lottable02, Lottable03, Lottable04, Lottable05)
      VALUES (@c_StockTakeKey, @c_CCDetailKey, @c_StorerKey, @c_sku, '', @c_loc, '', 0, 0, @c_TaskDetailKey,
         '', '', '', NULL, NULL)
   END
END -- SOS23776

DROP TABLE #RESULT
-- return results
 
   Quit:
END


GO