SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispRDTGenCountSheetByUCC                           */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Generate Count Sheet by UCC in Stock Take module			   */
/*                                                                      */
/* Called By: PB object nep_n_cst_stocktake_parm_new		               */
/*                                                                      */
/* PVCS Version: 1.7		                                                */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 11-Aug-2004  Shong	   Fixes                                        */
/* 12-Aug-2004  Wally      Include DYNAMICPK location type              */
/* 15-Oct-2004  Mohit		Changed cursor type					            */
/* 21-Oct-2004  June       SOS28639 Changed id to NVARCHAR(18)              */
/* 19-Jul-2005  MaryVong   SOS35241 Changed StockTake LotxLocxID.Qty    */
/*                         to (Qty-QtyAllocated-QtyPicked)              */
/* 10-Nov-2005  MaryVong   SOS42806 Increase length of returned fields  */
/*                         from ispParseParameters to NVARCHAR(800)         */
/* 19-Jan-2006  Vicky      SOS#44960 - Add in Locationtype 'OTHER' to   */
/*                         extraction of System Qty                     */
/* 19-Apr-2006  June       SOS48814 - Bug fixed SOS44960                */
/* 18-Jan-2008  June			 SOS66279 : Include STOCKTAKEPARM2 checking	*/
/* 05-Aug-2010  NJOW01     182454 - Add skugroup parameter              */
/* 25-Jul-2011  NJOW02     216737-New count sheet seq# for every stock  */
/*                         take.                                        */
/* 01-Mar-2012  James      Additional LOC filter (james01)              */
/* 01-Aug-2014  CSCHONG    Added 10 Lottables                           */
/************************************************************************/

CREATE PROC [dbo].[ispRDTGenCountSheetByUCC] (
@c_StockTakeKey NVARCHAR(10)
,@c_Loc NVARCHAR(10)
,@c_SKU NVARCHAR(20) = ''
,@c_TaskDetailKey NVARCHAR(10)

)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   	
	DECLARE @c_Facility NVARCHAR(5),
		@c_StorerKey	   NVARCHAR(18),
		@c_AisleParm	   NVARCHAR(60),
		@c_LevelParm	   NVARCHAR(60),
		@c_ZoneParm	      NVARCHAR(60),
		@c_HostWHCodeParm NVARCHAR(60),
		@c_ClearHistory   NVARCHAR(1),
		@c_WithQuantity   NVARCHAR(1),
		@c_EmptyLocation  NVARCHAR(1),
		@n_LinesPerPage   int,
		@c_SKUParm        NVARCHAR(125),
		-- Added by SHONG 01-Oct-2002
		@c_AgencyParm     NVARCHAR(150),
		@c_ABCParm        NVARCHAR(60),
		@c_SkuGroupParm   NVARCHAR(125),
      @c_CCSheetNoKeyName NVARCHAR(30) -- NJOW02
	
	-- declare a select condition variable for parameters
	-- SOS42806 Changed NVARCHAR(250) and NVARCHAR(255) to NVARCHAR(800)
	DECLARE @c_AisleSQL  NVARCHAR(800),
		@c_LevelSQL	      NVARCHAR(800),
		@c_ZoneSQL        NVARCHAR(800),
		@c_HostWHCodeSQL  NVARCHAR(800),
		@c_AisleSQL2	   NVARCHAR(800),
		@c_LevelSQL2	   NVARCHAR(800),
		@c_ZoneSQL2	      NVARCHAR(800),
		@c_HostWHCodeSQL2 NVARCHAR(800),
		@c_SKUSQL         NVARCHAR(800),
		@c_SKUSQL2        NVARCHAR(800),
		@b_success        int,
		@c_AgencySQL      NVARCHAR(800),
		@c_AgencySQL2     NVARCHAR(800),
		@c_ABCSQL         NVARCHAR(800),
		@c_ABCSQL2        NVARCHAR(800), 
		@c_SkuGroupSQL    NVARCHAR(800),
		@c_SkuGroupSQL2   NVARCHAR(800)
		--@c_Loc            NVARCHAR(10)
	
	-- Add by June 12.Mar.02 FBR063
	DECLARE   @c_StorerSQL  NVARCHAR(800)
			  , @c_StorerSQL2      NVARCHAR(800)
			  , @c_StorerParm      NVARCHAR(60)
			  , @c_GroupLottable05 NVARCHAR(10)
  
	-- Start : SOS66279
	DECLARE @c_sqlOther NVARCHAR(4000),
			  @c_sqlWhere NVARCHAR(4000),
			  @c_sqlGroup NVARCHAR(4000) 
	
	SELECT  @c_sqlOther = ''
	-- End : SOS66279

	SELECT @c_Facility = Facility,
			-- @c_StorerKey = StorerKey,     Remark by June 12.Mar.02 FBR063
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
			@c_SkuGroupParm = SkuGroupParm     
	FROM StockTakeSheetParameters (NOLOCK)
	WHERE StockTakeKey = @c_StockTakeKey
	SET NOCOUNT ON

	IF @n_LinesPerPage = 0 OR @n_LinesPerPage IS NULL
	SELECT @n_LinesPerPage = 999
	
--	EXEC ispParseParameters
--		@c_StorerParm,
--		'string',
--		'LOTXLOCXID.StorerKey',
--		@c_StorerSQL OUTPUT,
--		@c_StorerSQL2 OUTPUT,
--		@b_success OUTPUT
--
--	IF @c_StorerSQL IS NULL And @c_StorerSQL2 IS NULL
--	BEGIN
--		RETURN
--	END
--	
--	EXEC ispParseParameters
--		@c_AisleParm,
--		'string',
--		'LOC.LOCAISLE',
--		@c_AisleSQL OUTPUT,
--		@c_AisleSQL2 OUTPUT,
--		@b_success OUTPUT
--
--	EXEC ispParseParameters
--		@c_LevelParm,
--		'number',
--		'LOC.LocLevel',
--		@c_LevelSQL OUTPUT,
--		@c_LevelSQL2 OUTPUT,
--		@b_success OUTPUT
--
--	EXEC ispParseParameters
--		@c_ZoneParm,
--		'string',
--		'LOC.PutawayZone',
--		@c_ZoneSQL OUTPUT,
--		@c_ZoneSQL2 OUTPUT,
--		@b_success OUTPUT
--
--	EXEC ispParseParameters
--		@c_HostWHCodeParm,
--		'string',
--		'LOC.HostWHCode',
--		@c_HostWHCodeSQL OUTPUT,
--		@c_HostWHCodeSQL2 OUTPUT,
--		@b_success OUTPUT
--
--	EXEC ispParseParameters
--		@c_SKUParm,
--		'string',
--		'LOTxLOCxID.SKU',
--		@c_SKUSQL OUTPUT,
--		@c_SKUSQL2 OUTPUT,
--		@b_success OUTPUT
--
--	-- Purge All the historical records for this stocktakekey if clear history flag = 'Y'
--	IF @c_ClearHistory = 'Y'
--	BEGIN
--	   DELETE CCDETAIL
--	   WHERE  CCKEY = @c_StockTakeKey
--	END
--	
--	-- Added By SHONG 01 Oct 2002
--	EXEC ispParseParameters 
--	     @c_AgencyParm,
--	     'string',
--	     'SKU.SUSR3',
--	     @c_AgencySQL OUTPUT,
--	     @c_AgencySQL2 OUTPUT,
--	     @b_success OUTPUT
--	
--	EXEC ispParseParameters 
--	     @c_ABCParm,
--	     'string',
--	     'SKU.ABC',
--	     @c_ABCSQL OUTPUT,
--	     @c_ABCSQL2 OUTPUT,
--	     @b_success OUTPUT
--	-- End
--	
--	EXEC ispParseParameters 
--	     @c_SkuGroupParm,
--	     'string',
--	     'SKU.SKUGROUP',
--	     @c_SkuGroupSQL OUTPUT,
--	     @c_SkuGroupSQL2 OUTPUT,
--	     @b_success OUTPUT
	
	UPDATE StockTakeSheetParameters
	SET FinalizeStage = 0,
		 PopulateStage = 0
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
		LOTATTRIBUTE.Lottable06,		--(CS01)
		LOTATTRIBUTE.Lottable07,		--(CS01)
		LOTATTRIBUTE.Lottable08,		--(CS01)
		LOTATTRIBUTE.Lottable09,		--(CS01)
		LOTATTRIBUTE.Lottable10,		--(CS01)
		LOTATTRIBUTE.Lottable11,		--(CS01)
		LOTATTRIBUTE.Lottable12,		--(CS01)
		LOTATTRIBUTE.Lottable13,		--(CS01)
		LOTATTRIBUTE.Lottable14,		--(CS01)
		LOTATTRIBUTE.Lottable15,		--(CS01)
		Qty = 0,
		LOC.PutawayZone,
		LOC.LocLevel,
		Aisle = LOC.locAisle,
		LOC.Facility,
		LOC.CCLogicalLoc,
		SPACE(20) as UccNo
	INTO #RESULT
	FROM	LOTxLOCxID (NOLOCK),
			SKU (NOLOCK),
			LOTATTRIBUTE (NOLOCK),
			LOC (NOLOCK)
	WHERE	1=2

	DECLARE @c_SQL NVARCHAR(max), @c_UccNo NVARCHAR(20)

--	IF dbo.fnc_RTrim(@c_GroupLottable05) = 'MIN'
--	BEGIN
--		IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) WHERE Stocktakekey = @c_StockTakeKey)
--		BEGIN
--			SELECT @c_SQL =  'INSERT INTO #RESULT '
--				+ 'SELECT SPACE(10) as LOT,LOTxLOCxID.LOC,LOTxLOCxID.ID,LOTxLOCxID.StorerKey, '
--				+ 'LOTxLOCxID.SKU,LOTATTRIBUTE.Lottable01,LOTATTRIBUTE.Lottable02, '
--				+ 'LOTATTRIBUTE.Lottable03,LOTATTRIBUTE.Lottable04, MIN(LOTATTRIBUTE.Lottable05) as Lottable05, '
--				+ 'Qty = CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked)  '            
--			   + '           WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked) '  -- (james01)
--				+ 'WHEN LOC.LocationType NOT IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") AND MIN(UCC.Qty) IS NULL THEN SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked) ' 
--				+ 'ELSE MIN(UCC.Qty) END, ' 
--				+ 'LOC.PutawayZone,LOC.LocLevel,Aisle = LOC.locAisle,LOC.Facility, '
--				+ 'LOC.CCLogicalLoc, '
--				+ 'CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" ELSE ISNULL(UCC.UccNo,"") END as UCCNo ' 
--				+ 'FROM LOTxLOCxID (NOLOCK) ' 
--				+ 'JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Loc = SKUxLOC.Loc '
--				+ 'AND LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND LOTxLOCxID.SKU = SKUxLOC.SKU '
--				+ 'JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc  '
--				+ 'LEFT OUTER JOIN UCC (NOLOCK) ON LOTxLOCxID.StorerKey = UCC.StorerKey '
--				+ 'AND LOTxLOCxID.Sku = UCC.Sku '
--				+ 'AND LOTxLOCxID.Lot = UCC.Lot '
--				+ 'AND LOTxLOCxID.Loc = UCC.Loc '
--				+ 'AND LOTxLOCxID.Id = UCC.Id '
--				--+ 'AND UCC.Status BETWEEN "1" AND "2" '-- (james01)
--				+ 'AND UCC.Status < "4" '
--				+ 'AND 1 = CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN 2 ELSE 1 END ' 
--				+ 'JOIN SKU (NOLOCK) ON LOTxLOCxID.StorerKey = SKU.StorerKey '
--				+ 'AND LOTxLOCxID.Sku = SKU.Sku '
--				+ 'JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.Lot = LOTATTRIBUTE.Lot '
--				+ 'WHERE LOTxLOCxID.Qty > 0 '
--				+ 'AND   LOC.Facility = "' + ISNULL(dbo.fnc_RTrim(@c_Facility), '') + '" '
--				+ ISNULL(dbo.fnc_RTrim(@c_StorerSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_StorerSQL2), '') + ' '
--				+ ISNULL(dbo.fnc_RTrim(@c_ZoneSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ZoneSQL2), '') + ' '
--				+ ISNULL(dbo.fnc_RTrim(@c_AisleSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AisleSQL2), '') + ' '
--				+ ISNULL(dbo.fnc_RTrim(@c_LevelSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_LevelSQL2), '') + ' '
--				+ ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL2), '') + ' '
--				+ ISNULL(dbo.fnc_RTrim(@c_SKUSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_SKUSQL2), '') + ' '
--				+ ISNULL(dbo.fnc_RTrim(@c_AgencySQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AgencySQL2), '') + ' '
--				+ ISNULL(dbo.fnc_RTrim(@c_ABCSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ABCSQL2), '') + ' '
--				+ ISNULL(dbo.fnc_RTrim(@c_SkuGroupSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_SkuGroupSQL2), '') + ' '
--				+ 'GROUP BY LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, '
--				+ 'LOTxLOCxID.sku,LOTATTRIBUTE.Lottable01,LOTATTRIBUTE.Lottable02,LOTATTRIBUTE.Lottable03,'
--				+ 'LOTATTRIBUTE.Lottable04,LOC.PutawayZone,LOC.LocLevel,LOC.locAisle, LOC.Facility, LOC.CCLogicalLoc, UCC.UccNo, '
--				+ 'LOC.LocationType, LOC.LocationCategory, CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" ELSE ISNULL(UCC.UccNo,"") END '
--				+ 'Order By LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, LOTxLOCxID.sku '
--		END 
--		ELSE
--		BEGIN	
--			SELECT @c_SQL = N'INSERT INTO #RESULT '
--				+ 'SELECT SPACE(10) as LOT,LOTxLOCxID.LOC,LOTxLOCxID.ID,LOTxLOCxID.StorerKey, '
--				+ 'LOTxLOCxID.SKU,LOTATTRIBUTE.Lottable01,LOTATTRIBUTE.Lottable02, '
--				+ 'LOTATTRIBUTE.Lottable03,LOTATTRIBUTE.Lottable04, MIN(LOTATTRIBUTE.Lottable05) as Lottable05, '
--				+ 'Qty = CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked)  '            
--			   + '           WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked) '  -- (james01)
--				+ '           WHEN LOC.LocationType NOT IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") AND MIN(UCC.Qty) IS NULL THEN SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked) ' 
--				+ '           ELSE MIN(UCC.Qty) END, ' 
--				+ 'LOC.PutawayZone,LOC.LocLevel,Aisle = LOC.locAisle,LOC.Facility, '
--				+ 'LOC.CCLogicalLoc, '
--				+ 'CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" ELSE ISNULL(UCC.UccNo,"") END as UCCNo ' 
--				+ 'FROM LOTxLOCxID (NOLOCK) ' 
--				+ 'JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Loc = SKUxLOC.Loc '
--				+ 'AND LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND LOTxLOCxID.SKU = SKUxLOC.SKU '
--				+ 'JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc  '
--				+ 'LEFT OUTER JOIN UCC (NOLOCK) ON LOTxLOCxID.StorerKey = UCC.StorerKey '
--				+ '			AND LOTxLOCxID.Sku = UCC.Sku '
--				+ '			AND LOTxLOCxID.Lot = UCC.Lot '
--				+ '			AND LOTxLOCxID.Loc = UCC.Loc '
--				+ '			AND LOTxLOCxID.Id = UCC.Id '
--				--+ '			AND UCC.Status BETWEEN "1" AND "2" '-- (james01)
--				+ '         AND UCC.Status < "4" '
--				+ '			AND 1 = CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN 2 ELSE 1 END ' 
--				+ 'JOIN SKU (NOLOCK) ON LOTxLOCxID.StorerKey = SKU.StorerKey AND LOTxLOCxID.Sku = SKU.Sku '
--				+ 'JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.Lot = LOTATTRIBUTE.Lot '
--	
--			IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) 
--						  		WHERE Stocktakekey = @c_StockTakeKey
--						  		AND   UPPER(Tablename) = 'SKU')
--			BEGIN
--				SELECT @c_SQLOther = @c_SQLOther + ' ' 
--										+ ISNULL(dbo.fnc_RTrim(@c_SKUSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_SKUSQL2), '') + ' '
--										+ ISNULL(dbo.fnc_RTrim(@c_AgencySQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AgencySQL2), '') + ' '
--										+ ISNULL(dbo.fnc_RTrim(@c_ABCSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ABCSQL2), '') + ' '
--										+ ISNULL(dbo.fnc_RTrim(@c_SkuGroupSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_SkuGroupSQL2), '') + ' '
--			END
--			ELSE
--			BEGIN
--				SELECT @c_SQL = @c_SQL + ' ' 
--									+ 'JOIN STOCKTAKEPARM2 PARM2_SKU WITH (NOLOCK) '
--									+ ' ON PARM2_SKU.Storerkey = LOTxLOCxID.Storerkey '
--									+ 'AND dbo.fnc_RTrim(dbo.fnc_LTrim(PARM2_SKU.Value)) = LOTxLOCxID.SKU '
--									+ 'AND UPPER(PARM2_SKU.Tablename) = ''SKU'' '
--									+ 'AND PARM2_SKU.Stocktakekey = ''' + ISNULL(dbo.fnc_RTrim(@c_StockTakeKey), '') + ''''
--			END
--	
--			IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) 
--						  		WHERE Stocktakekey = @c_StockTakeKey
--						  		AND   UPPER(Tablename) = 'LOC')
--			BEGIN
--				SELECT @c_SQLOther = @c_SQLOther + ' '  		 
--										+ ISNULL(dbo.fnc_RTrim(@c_ZoneSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ZoneSQL2), '') + ' '
--										+ ISNULL(dbo.fnc_RTrim(@c_AisleSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AisleSQL2), '') + ' '
--										+ ISNULL(dbo.fnc_RTrim(@c_LevelSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_LevelSQL2), '') + ' '
--										+ ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL2), '') 
--			END
--			ELSE
--			BEGIN
--				SELECT @c_SQL = @c_SQL + ' ' 
--									+ 'JOIN STOCKTAKEPARM2 PARM2_LOC WITH (NOLOCK) '
--									+ ' ON dbo.fnc_RTrim(dbo.fnc_LTrim(PARM2_LOC.Value)) = LOTxLOCxID.LOC '
--									+ 'AND UPPER(PARM2_LOC.Tablename) = ''LOC'' '
--									+ 'AND PARM2_LOC.Stocktakekey = ''' + ISNULL(dbo.fnc_RTrim(@c_StockTakeKey), '') + ''''
--			END
--	
--			SELECT @c_SQLWhere = ' '
--										+ 'WHERE LOTxLOCxID.Qty > 0 '
--										+ 'AND   LOC.Facility = "' + ISNULL(dbo.fnc_RTrim(@c_Facility), '') + '" '
--										+ ISNULL(dbo.fnc_RTrim(@c_StorerSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_StorerSQL2), '') + ' '
--
--			SELECT @c_SQLGroup = ' '
--										+ 'GROUP BY LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, '
--										+ 'LOTxLOCxID.sku,LOTATTRIBUTE.Lottable01,LOTATTRIBUTE.Lottable02,LOTATTRIBUTE.Lottable03,'
--										+ 'LOTATTRIBUTE.Lottable04,LOC.PutawayZone,LOC.LocLevel,LOC.locAisle, LOC.Facility, LOC.CCLogicalLoc, UCC.UccNo, '
--										+ 'LOC.LocationType, LOC.LocationCategory, CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" ELSE ISNULL(UCC.UccNo,"") END '
--										+ 'Order BY LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, LOTxLOCxID.sku '
--
--			SELECT @c_sql = @c_sql + ' ' + @c_sqlWhere + ' ' + @c_sqlOther + ' ' + @c_sqlGroup
--		END
--	END
--	ELSE IF dbo.fnc_RTrim(@c_GroupLottable05) = 'MAX'
--	BEGIN
--		IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) WHERE Stocktakekey = @c_StockTakeKey)
--		BEGIN
--			SELECT @c_SQL = 'INSERT INTO #RESULT '
--				+ 'SELECT SPACE(10) as LOT,LOTxLOCxID.LOC,LOTxLOCxID.ID,LOTxLOCxID.StorerKey, '
--				+ 'LOTxLOCxID.SKU,LOTATTRIBUTE.Lottable01,LOTATTRIBUTE.Lottable02, '
--				+ 'LOTATTRIBUTE.Lottable03,LOTATTRIBUTE.Lottable04, MAX(LOTATTRIBUTE.Lottable05) as Lottable05, '
--				+ 'Qty = CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked)  '            
--			   + '           WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked) '  -- (james01)
--				+ 'WHEN LOC.LocationType NOT IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") AND MIN(UCC.Qty) IS NULL THEN SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked) '  
--				+ 'ELSE MIN(UCC.Qty) END, ' 
--				+ 'LOC.PutawayZone,LOC.LocLevel,Aisle = LOC.locAisle,LOC.Facility, '
--				+ 'LOC.CCLogicalLoc, '
--				+ 'CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" ELSE ISNULL(UCC.UccNo,"") END as UCCNo ' 
--				+ 'FROM LOTxLOCxID (NOLOCK) '
--				+ 'JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Loc = SKUxLOC.Loc '
--				+ 'AND LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND LOTxLOCxID.SKU = SKUxLOC.SKU '
--				+ 'JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc  '
--				+ 'LEFT OUTER JOIN UCC (NOLOCK) ON LOTxLOCxID.StorerKey = UCC.StorerKey '
--				+ 'AND LOTxLOCxID.Sku = UCC.Sku '
--				+ 'AND LOTxLOCxID.Lot = UCC.Lot '
--				+ 'AND LOTxLOCxID.Loc = UCC.Loc '
--				+ 'AND LOTxLOCxID.Id = UCC.Id '
--				--+ 'AND UCC.Status BETWEEN "1" AND "2" '-- (james01)
--				+ 'AND UCC.Status < "4" '
--				+ 'AND 1 = CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN 2 ELSE 1 END ' 
--				+ 'JOIN SKU (NOLOCK) ON LOTxLOCxID.StorerKey = SKU.StorerKey '
--				+ 'AND LOTxLOCxID.Sku = SKU.Sku '
--				+ 'JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.Lot = LOTATTRIBUTE.Lot '
--				+ 'WHERE LOTxLOCxID.Qty > 0 '
--				+ 'AND   LOC.Facility = "' + ISNULL(dbo.fnc_RTrim(@c_Facility), '') + '" '
--				+ ISNULL(dbo.fnc_RTrim(@c_StorerSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_StorerSQL2), '') + ' '
--				+ ISNULL(dbo.fnc_RTrim(@c_ZoneSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ZoneSQL2), '') + ' '
--				+ ISNULL(dbo.fnc_RTrim(@c_AisleSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AisleSQL2), '') + ' '
--				+ ISNULL(dbo.fnc_RTrim(@c_LevelSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_LevelSQL2), '') + ' '
--				+ ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL2), '') + ' '
--				+ ISNULL(dbo.fnc_RTrim(@c_SKUSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_SKUSQL2), '') + ' '
--				+ ISNULL(dbo.fnc_RTrim(@c_AgencySQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AgencySQL2), '') + ' '
--				+ ISNULL(dbo.fnc_RTrim(@c_ABCSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ABCSQL2), '') + ' '
--				+ ISNULL(dbo.fnc_RTrim(@c_SkuGroupSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_SkuGroupSQL2), '') + ' '
--				+ 'GROUP BY LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, '
--				+ 'LOTxLOCxID.sku,LOTATTRIBUTE.Lottable01,LOTATTRIBUTE.Lottable02,LOTATTRIBUTE.Lottable03,'
--				+ 'LOTATTRIBUTE.Lottable04,LOC.PutawayZone,LOC.LocLevel,LOC.locAisle, LOC.Facility, LOC.CCLogicalLoc, UCC.UccNo, '
--				+ 'LOC.LocationType, LOC.LocationCategory, CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" ELSE ISNULL(UCC.UccNo,"") END '
--				+ 'Order By LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, LOTxLOCxID.sku '	
--		-- Start : SOS66279
--		END 
--		ELSE
--		BEGIN	
--			SELECT @c_SQL = N'INSERT INTO #RESULT '
--				+ 'SELECT SPACE(10) as LOT,LOTxLOCxID.LOC,LOTxLOCxID.ID,LOTxLOCxID.StorerKey, '
--				+ 'LOTxLOCxID.SKU,LOTATTRIBUTE.Lottable01,LOTATTRIBUTE.Lottable02, '
--				+ 'LOTATTRIBUTE.Lottable03,LOTATTRIBUTE.Lottable04, MAX(LOTATTRIBUTE.Lottable05) as Lottable05, '
--				+ 'Qty = CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked)  '            
--			   + '           WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked) '  -- (james01)
--				+ '			  WHEN LOC.LocationType NOT IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") AND MIN(UCC.Qty) IS NULL THEN SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked) '  
--				+ '			  ELSE MIN(UCC.Qty) END, ' 
--				+ 'LOC.PutawayZone,LOC.LocLevel,Aisle = LOC.locAisle,LOC.Facility, '
--				+ 'LOC.CCLogicalLoc, '
--				+ 'CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" ELSE ISNULL(UCC.UccNo,"") END as UCCNo ' 
--				+ 'FROM LOTxLOCxID (NOLOCK) '
--				+ 'JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Loc = SKUxLOC.Loc AND LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND LOTxLOCxID.SKU = SKUxLOC.SKU '
--				+ 'JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc  '
--				+ 'LEFT OUTER JOIN UCC (NOLOCK) ON LOTxLOCxID.StorerKey = UCC.StorerKey '
--				+ '				AND LOTxLOCxID.Sku = UCC.Sku '
--				+ '				AND LOTxLOCxID.Lot = UCC.Lot '
--				+ '				AND LOTxLOCxID.Loc = UCC.Loc '
--				+ '				AND LOTxLOCxID.Id = UCC.Id '
--				--+ '				AND UCC.Status BETWEEN "1" AND "2" '-- (james01)
--				+ '            AND UCC.Status < "4" '
--				+ '				AND 1 = CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN 2 ELSE 1 END ' 
--				+ 'JOIN SKU (NOLOCK) ON LOTxLOCxID.StorerKey = SKU.StorerKey AND LOTxLOCxID.Sku = SKU.Sku '
--				+ 'JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.Lot = LOTATTRIBUTE.Lot '
--
--			IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) 
--						  		WHERE Stocktakekey = @c_StockTakeKey
--						  		AND   UPPER(Tablename) = 'SKU')
--			BEGIN
--				SELECT @c_SQLOther = @c_SQLOther + ' ' 
--										+ ISNULL(dbo.fnc_RTrim(@c_SKUSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_SKUSQL2), '') + ' '
--										+ ISNULL(dbo.fnc_RTrim(@c_AgencySQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AgencySQL2), '') + ' '
--										+ ISNULL(dbo.fnc_RTrim(@c_ABCSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ABCSQL2), '') + ' '
--										+ ISNULL(dbo.fnc_RTrim(@c_SkuGroupSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_SkuGroupSQL2), '') + ' '
--			END
--			ELSE
--			BEGIN
--				SELECT @c_SQL = @c_SQL + ' '
--										+ 'JOIN STOCKTAKEPARM2 PARM2_SKU WITH (NOLOCK) '
--										+ ' ON PARM2_SKU.Storerkey = LOTxLOCxID.Storerkey '
--										+ 'AND dbo.fnc_RTrim(dbo.fnc_LTrim(PARM2_SKU.Value)) = LOTxLOCxID.SKU '
--										+ 'AND UPPER(PARM2_SKU.Tablename) = ''SKU'' '
--										+ 'AND PARM2_SKU.Stocktakekey = ''' + ISNULL(dbo.fnc_RTrim(@c_StockTakeKey), '') + ''''
--			END
--
--			IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) 
--						  		WHERE Stocktakekey = @c_StockTakeKey
--						  		AND   UPPER(Tablename) = 'LOC')
--			BEGIN
--				SELECT @c_SQLOther = @c_SQLOther + ' '  		 
--										+ ISNULL(dbo.fnc_RTrim(@c_ZoneSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ZoneSQL2), '') + ' '
--										+ ISNULL(dbo.fnc_RTrim(@c_AisleSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AisleSQL2), '') + ' '
--										+ ISNULL(dbo.fnc_RTrim(@c_LevelSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_LevelSQL2), '') + ' '
--										+ ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL2), '') 
--			END
--			ELSE
--			BEGIN
--				SELECT @c_SQL = @c_SQL + ' '
--										+ 'JOIN STOCKTAKEPARM2 PARM2_LOC WITH (NOLOCK) '
--										+ ' ON dbo.fnc_RTrim(dbo.fnc_LTrim(PARM2_LOC.Value)) = LOTxLOCxID.LOC '
--										+ 'AND UPPER(PARM2_LOC.Tablename) = ''LOC'' '
--										+ 'AND PARM2_LOC.Stocktakekey = ''' + ISNULL(dbo.fnc_RTrim(@c_StockTakeKey), '') + ''''
--			END
--
--			SELECT @c_SQLWhere = ' '	
--										+ 'WHERE LOTxLOCxID.Qty > 0 '
--										+ 'AND   LOC.Facility = "' + ISNULL(dbo.fnc_RTrim(@c_Facility), '') + '" '
--										+ ISNULL(dbo.fnc_RTrim(@c_StorerSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_StorerSQL2), '') + ' '					
--
--			SELECT @c_SQLGroup = ' '
--										+ 'GROUP BY LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, '
--										+ 'LOTxLOCxID.sku,LOTATTRIBUTE.Lottable01,LOTATTRIBUTE.Lottable02,LOTATTRIBUTE.Lottable03,'
--										+ 'LOTATTRIBUTE.Lottable04,LOC.PutawayZone,LOC.LocLevel,LOC.locAisle, LOC.Facility, LOC.CCLogicalLoc, UCC.UccNo, '
--										+ 'LOC.LocationType, LOC.LocationCategory, CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" ELSE ISNULL(UCC.UccNo,"") END '
--										+ 'Order By LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, LOTxLOCxID.sku '	
--
--			SELECT @c_sql = @c_sql + ' ' + @c_sqlWhere + ' ' + @c_sqlOther + ' ' + @c_sqlGroup
--		END
--   END
--	ELSE
	BEGIN
		IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) WHERE Stocktakekey = @c_StockTakeKey)
		BEGIN
			SELECT @c_SQL =  'INSERT INTO #RESULT '
				+ 'SELECT LOTxLOCxID.LOT,LOTxLOCxID.LOC,LOTxLOCxID.ID,LOTxLOCxID.StorerKey, '
				+ 'LOTxLOCxID.SKU,LOTATTRIBUTE.Lottable01,LOTATTRIBUTE.Lottable02, '
				+ 'LOTATTRIBUTE.Lottable03,LOTATTRIBUTE.Lottable04, MIN(LOTATTRIBUTE.Lottable05) as Lottable05, '
				+ 'LOTATTRIBUTE.Lottable06,LOTATTRIBUTE.Lottable07,LOTATTRIBUTE.Lottable08,LOTATTRIBUTE.Lottable09,'          --(CS01)
				+ 'LOTATTRIBUTE.Lottable10,LOTATTRIBUTE.Lottable11,LOTATTRIBUTE.Lottable12,LOTATTRIBUTE.Lottable13,'          --(CS01)
				+ 'LOTATTRIBUTE.Lottable14,LOTATTRIBUTE.Lottable15,'                                                          --(CS01)
				+ 'Qty = CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked)  '            
			   + '           WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked) '  -- (james01)
				+ '           WHEN LOC.LocationType NOT IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") AND MIN(UCC.Qty) IS NULL THEN SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked) '  
				+ 'ELSE MIN(UCC.Qty) END, ' 
				+ 'LOC.PutawayZone,LOC.LocLevel,Aisle = LOC.locAisle,LOC.Facility, '
				+ 'LOC.CCLogicalLoc, '
				+ 'CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" ELSE ISNULL(UCC.UccNo,"") END as UCCNo ' 
				+ 'FROM LOTxLOCxID (NOLOCK) '
				+ 'JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Loc = SKUxLOC.Loc '
				+ 'AND LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND LOTxLOCxID.SKU = SKUxLOC.SKU '
				+ 'JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc  '
				+ 'LEFT OUTER JOIN UCC (NOLOCK) ON LOTxLOCxID.StorerKey = UCC.StorerKey '
				+ 'AND LOTxLOCxID.Sku = UCC.Sku '
				+ 'AND LOTxLOCxID.Lot = UCC.Lot '
				+ 'AND LOTxLOCxID.Loc = UCC.Loc '
				+ 'AND LOTxLOCxID.Id = UCC.Id '
				--+ 'AND UCC.Status BETWEEN "1" AND "2" '-- (james01)
				+ 'AND UCC.Status < "4" '
				+ 'AND 1 = CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN 2 ELSE 1 END ' 
				+ 'JOIN SKU (NOLOCK) ON LOTxLOCxID.StorerKey = SKU.StorerKey '
				+ 'AND LOTxLOCxID.Sku = SKU.Sku '
				+ 'JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.Lot = LOTATTRIBUTE.Lot '
				+ 'WHERE LOTxLOCxID.Qty > 0 '
				+ 'AND   LOC.Facility = "' + ISNULL(dbo.fnc_RTrim(@c_Facility), '') + '" '
				+ 'AND   LOC.LOC = "' + @c_Loc + '" '
				
				IF ISNULL(RTRIM(@c_SKU),'') <> ''
				BEGIN
				   SET @c_SQL = @c_SQL + 'AND   LOTxLOCxID.SKU = "' + ISNULL(RTRIM(@c_SKU),'') + '" '
				END
				
				--+ ISNULL(dbo.fnc_RTrim(@c_StorerSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_StorerSQL2), '') + ' '
				--+ ISNULL(dbo.fnc_RTrim(@c_ZoneSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ZoneSQL2), '') + ' '
				--+ ISNULL(dbo.fnc_RTrim(@c_AisleSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AisleSQL2), '') + ' '
				--+ ISNULL(dbo.fnc_RTrim(@c_LevelSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_LevelSQL2), '') + ' '
				--+ ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL2), '') + ' '
				--+ ISNULL(dbo.fnc_RTrim(@c_SKUSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_SKUSQL2), '') + ' '
				--+ ISNULL(dbo.fnc_RTrim(@c_AgencySQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AgencySQL2), '') + ' '
				--+ ISNULL(dbo.fnc_RTrim(@c_ABCSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ABCSQL2), '') + ' '
				--+ ISNULL(dbo.fnc_RTrim(@c_SkuGroupSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_SkuGroupSQL2), '') + ' '
				SELECT @c_SQL =  @c_SQL +  'GROUP BY LOTxLOCxID.LOT, LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, '
				+ 'LOTxLOCxID.sku,LOTATTRIBUTE.Lottable01,LOTATTRIBUTE.Lottable02,LOTATTRIBUTE.Lottable03,'
				+ 'LOTATTRIBUTE.Lottable04,LOTATTRIBUTE.Lottable06,LOTATTRIBUTE.Lottable07,LOTATTRIBUTE.Lottable08,'           --(CS01)
				+ 'LOTATTRIBUTE.Lottable09,LOTATTRIBUTE.Lottable10,LOTATTRIBUTE.Lottable11,LOTATTRIBUTE.Lottable12,'           --(CS01)
				+ 'LOTATTRIBUTE.Lottable13,LOTATTRIBUTE.Lottable14,LOTATTRIBUTE.Lottable15,'                                   --(CS01)
				+ 'LOC.PutawayZone,LOC.LocLevel,LOC.locAisle, LOC.Facility, LOC.CCLogicalLoc, UCC.UccNo, '
				+ 'LOC.LocationType, LOC.LocationCategory, CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" ELSE ISNULL(UCC.UccNo,"") END ' 
				+ 'Order By LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, LOTxLOCxID.sku '
		END 
--		ELSE
--		BEGIN	
--			SELECT @c_SQL = N'INSERT INTO #RESULT '
--				+ 'SELECT LOTxLOCxID.LOT,LOTxLOCxID.LOC,LOTxLOCxID.ID,LOTxLOCxID.StorerKey, '
--				+ 'LOTxLOCxID.SKU,LOTATTRIBUTE.Lottable01,LOTATTRIBUTE.Lottable02, '
--				+ 'LOTATTRIBUTE.Lottable03,LOTATTRIBUTE.Lottable04, MIN(LOTATTRIBUTE.Lottable05) as Lottable05, '
--				+ 'Qty = CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked)  '            
--			   + '           WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked) '  -- (james01)
--				+ '			  WHEN LOC.LocationType NOT IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") AND MIN(UCC.Qty) IS NULL THEN SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked) '  
--				+ '			  ELSE MIN(UCC.Qty) END, ' 
--				+ 'LOC.PutawayZone,LOC.LocLevel,Aisle = LOC.locAisle,LOC.Facility, '
--				+ 'LOC.CCLogicalLoc, '
--				+ 'CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" ELSE ISNULL(UCC.UccNo,"") END as UCCNo ' 
--				+ 'FROM LOTxLOCxID (NOLOCK) '
--				+ 'JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Loc = SKUxLOC.Loc AND LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND LOTxLOCxID.SKU = SKUxLOC.SKU '
--				+ 'JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc  '
--				+ 'LEFT OUTER JOIN UCC (NOLOCK) ON LOTxLOCxID.StorerKey = UCC.StorerKey '
--				+ '				AND LOTxLOCxID.Sku = UCC.Sku '
--				+ '				AND LOTxLOCxID.Lot = UCC.Lot '
--				+ '				AND LOTxLOCxID.Loc = UCC.Loc '
--				+ '				AND LOTxLOCxID.Id = UCC.Id '
--				--+ '				AND UCC.Status BETWEEN "1" AND "2" '-- (james01)
--				+ '            AND UCC.Status < "4" '
--				+ '				AND 1 = CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN 2 ELSE 1 END ' 
--				+ 'JOIN SKU (NOLOCK) ON LOTxLOCxID.StorerKey = SKU.StorerKey AND  LOTxLOCxID.Sku = SKU.Sku '
--				+ 'JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.Lot = LOTATTRIBUTE.Lot '
--
--			IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) 
--						  		WHERE Stocktakekey = @c_StockTakeKey
--						  		AND   UPPER(Tablename) = 'SKU')
--			BEGIN
--				SELECT @c_SQLOther = @c_SQLOther + ' ' 
--										+ ISNULL(dbo.fnc_RTrim(@c_SKUSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_SKUSQL2), '') + ' '
--										+ ISNULL(dbo.fnc_RTrim(@c_AgencySQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AgencySQL2), '') + ' '
--										+ ISNULL(dbo.fnc_RTrim(@c_ABCSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ABCSQL2), '') + ' '
--										+ ISNULL(dbo.fnc_RTrim(@c_SkuGroupSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_SkuGroupSQL2), '') + ' '
--			END
--			ELSE
--			BEGIN
--				SELECT @c_SQL = @c_SQL + ' ' 
--										+ 'JOIN STOCKTAKEPARM2 PARM2_SKU WITH (NOLOCK) '
--										+ ' ON PARM2_SKU.Storerkey = LOTxLOCxID.Storerkey '
--										+ 'AND dbo.fnc_RTrim(dbo.fnc_LTrim(PARM2_SKU.Value)) = LOTxLOCxID.SKU '
--										+ 'AND UPPER(PARM2_SKU.Tablename) = ''SKU'' '
--										+ 'AND PARM2_SKU.Stocktakekey = ''' + ISNULL(dbo.fnc_RTrim(@c_StockTakeKey), '') + ''''
--			END
--
--			IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) 
--						  		WHERE Stocktakekey = @c_StockTakeKey
--						  		AND   UPPER(Tablename) = 'LOC')
--			BEGIN
--				SELECT @c_SQLOther = @c_SQLOther + ' '  		 
--										+ ISNULL(dbo.fnc_RTrim(@c_ZoneSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ZoneSQL2), '') + ' '
--										+ ISNULL(dbo.fnc_RTrim(@c_AisleSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AisleSQL2), '') + ' '
--										+ ISNULL(dbo.fnc_RTrim(@c_LevelSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_LevelSQL2), '') + ' '
--										+ ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL2), '') 
--			END
--			ELSE
--			BEGIN
--				SELECT @c_SQL = @c_SQL + ' ' 
--										+ 'JOIN STOCKTAKEPARM2 PARM2_LOC WITH (NOLOCK) '
--										+ ' ON dbo.fnc_RTrim(dbo.fnc_LTrim(PARM2_LOC.Value)) = LOTxLOCxID.LOC '
--										+ 'AND UPPER(PARM2_LOC.Tablename) = ''LOC'' '
--										+ 'AND PARM2_LOC.Stocktakekey = ''' + ISNULL(dbo.fnc_RTrim(@c_StockTakeKey), '') + ''''
--			END
--
--			SELECT @c_SQLWhere = ' '	
--										+ 'WHERE LOTxLOCxID.Qty > 0 '
--										+ 'AND   LOC.Facility = "' + ISNULL(dbo.fnc_RTrim(@c_Facility), '') + '" '
--										+ ISNULL(dbo.fnc_RTrim(@c_StorerSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_StorerSQL2), '') + ' '
--
--			SELECT @c_SQLGroup = ' '
--										+ 'GROUP BY LOTxLOCxID.LOT, LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, '
--										+ 'LOTxLOCxID.sku,LOTATTRIBUTE.Lottable01,LOTATTRIBUTE.Lottable02,LOTATTRIBUTE.Lottable03,'
--										+ 'LOTATTRIBUTE.Lottable04,LOC.PutawayZone,LOC.LocLevel,LOC.locAisle, LOC.Facility, LOC.CCLogicalLoc, UCC.UccNo, '
--										+ 'LOC.LocationType, LOC.LocationCategory, CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" ELSE ISNULL(UCC.UccNo,"") END ' 
--										+ 'Order By LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, LOTxLOCxID.sku '			
--							
--			SELECT @c_sql = @c_sql + ' ' + @c_sqlWhere + ' ' + @c_sqlOther + ' ' + @c_sqlGroup
--		END
--		-- End : SOS66279
	END

	--PRINT @C_SQL
	
	EXEC (@c_sql)
	
	--SELECT * FROM #RESULT
	
--	IF @c_EmptyLocation = 'Y'
--	BEGIN
--		-- Start : SOS66279
--		IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) WHERE Stocktakekey = @c_StockTakeKey)
--		BEGIN
--		-- End : SOS66279	
--			SELECT @c_SQL =  'INSERT INTO #RESULT '
--			+ 'SELECT lot = space(10),loc,id = space(20),StorerKey = space(10),sku = space(20),'
--			+ 'Lottable01 = space(18),Lottable02 = space(18),Lottable03 = space(18),Lottable04 = NULL,'
--			+ 'Lottable05 = NULL,Qty = 0,PutawayZone,LocLevel,Aisle = locAisle,Facility,CCLogicalLoc, UccNo = space(20) '
--			+ 'FROM LOC (NOLOCK) '
--			+ 'WHERE   LOC.Facility = "' + ISNULL(dbo.fnc_RTrim(@c_Facility), '') + '" '
--			--+ ISNULL(dbo.fnc_RTrim(@c_ZoneSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ZoneSQL2), '') + ' '
--			--+ ISNULL(dbo.fnc_RTrim(@c_AisleSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AisleSQL2), '') + ' '
--			--+ ISNULL(dbo.fnc_RTrim(@c_LevelSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_LevelSQL2), '') + ' '
--			--+ ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL2), '') + ' '
--			+ 'AND LOC NOT IN (SELECT DISTINCT LOC FROM #RESULT) ' 
--
--			EXEC ( @c_SQL )
--		-- Start : SOS66279
--		END 
--		ELSE
--		BEGIN
--			SELECT @c_sqlOther = ''
--
--			SELECT @c_SQL = N'INSERT INTO #RESULT '
--			+ 'SELECT lot = space(10),loc,id = space(20),StorerKey = space(10),sku = space(20),'
--			+ 'Lottable01 = space(18),Lottable02 = space(18),Lottable03 = space(18),Lottable04 = NULL,'
--			+ 'Lottable05 = NULL,Qty = 0,PutawayZone,LocLevel,Aisle = locAisle,Facility,CCLogicalLoc, UccNo = space(20) '
--			+ 'FROM LOC (NOLOCK) '
--	
--			IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) 
--						  		WHERE Stocktakekey = @c_StockTakeKey
--						  		AND   UPPER(Tablename) = 'LOC')
--			BEGIN
--				SELECT @c_SQLOther = @c_SQLOther + ' '  		 
--										+ ISNULL(dbo.fnc_RTrim(@c_ZoneSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ZoneSQL2), '') + ' '
--										+ ISNULL(dbo.fnc_RTrim(@c_AisleSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AisleSQL2), '') + ' '
--										+ ISNULL(dbo.fnc_RTrim(@c_LevelSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_LevelSQL2), '') + ' '
--										+ ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL2), '') 
--			END
--			ELSE
--			BEGIN
--				SELECT @c_SQL = @c_SQL + ' ' 
--										+ 'JOIN STOCKTAKEPARM2 PARM2_LOC WITH (NOLOCK) '
--										+ ' ON dbo.fnc_RTrim(dbo.fnc_LTrim(PARM2_LOC.Value)) = LOC.LOC '
--										+ 'AND UPPER(PARM2_LOC.Tablename) = ''LOC'' '
--										+ 'AND PARM2_LOC.Stocktakekey = ''' + ISNULL(dbo.fnc_RTrim(@c_StockTakeKey), '') + ''''
--			END
--	
--			SELECT @c_SQLWhere = ' ' 
--										+ 'WHERE   LOC.Facility = "' + ISNULL(dbo.fnc_RTrim(@c_Facility), '') + '" '
--										+ 'AND LOC NOT IN (SELECT DISTINCT LOC FROM #RESULT) ' 
--	
--			SELECT @c_sql = @c_sql + ' ' + @c_sqlWhere + ' ' + @c_sqlOther 
--
--			EXEC ( @c_SQL )
--		END
		-- End : SOS66279
--	END
		
	DECLARE @c_lot	 NVARCHAR(10),
		--@c_loc	 NVARCHAR(10),
		@c_id	 NVARCHAR(18),
		--@c_sku	 NVARCHAR(20),
		@c_Lottable01 NVARCHAR(18),
		@c_Lottable02 NVARCHAR(18),
		@c_Lottable03 NVARCHAR(18),
		@d_Lottable04	datetime,
		@d_Lottable05	datetime,
		@c_Lottable06 NVARCHAR(30),		--(CS01)
		@c_Lottable07 NVARCHAR(30),		--(CS01)
		@c_Lottable08 NVARCHAR(30),      --(CS01)
		@c_Lottable09 NVARCHAR(30),		--(CS01)
		@c_Lottable10 NVARCHAR(30),		--(CS01)
		@c_Lottable11 NVARCHAR(30),      --(CS01)
		@c_Lottable12 NVARCHAR(30),      --(CS01)
		@d_Lottable13	datetime,			--(CS01)
		@d_Lottable14	datetime,			--(CS01)
		@d_Lottable15	datetime,			--(CS01)
		@n_qty		int,
		@c_Aisle	 NVARCHAR(10),
		@n_LocLevel	 int,
		@c_prev_Facility NVARCHAR(5),
		@c_prev_Aisle	 NVARCHAR(10),
		@n_prev_LocLevel int,
		@c_ccdetailkey	 NVARCHAR(10),
		@c_ccsheetno	 NVARCHAR(10),
		@n_err		       int,
		@c_errmsg	       NVARCHAR(250),
		@n_LineCount       int,
		@c_PreLogLocation  NVARCHAR(18),
		@c_CCLogicalLoc NVARCHAR(18),
      @n_SystemQty       int,
      @c_PrevZone        NVARCHAR(10),
      @c_PutawayZone     NVARCHAR(10)

	SELECT @c_prev_Facility = " ", @c_prev_Aisle = "XX", @n_prev_LocLevel = 999, @c_PreLogLocation = '000'
	DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY 
	FOR SELECT lot, loc, id, StorerKey, sku, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
	           Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,                                      --(CS01)
				  Lottable11, Lottable12, Lottable13, Lottable14, Lottable15,													--(CS01)
	            CASE WHEN @c_WithQuantity = 'Y' THEN qty ELSE 0 END,
	            Facility, Aisle, LocLevel, CCLogicalLoc, qty, PutawayZone, UccNo
   FROM #RESULT
   ORDER BY Facility, PutawayZone, Aisle, LocLevel, CCLogicalLoc, Loc, SKU 
	
	OPEN cur_1
	SELECT @n_LineCount = 0
   SELECT @c_CCSheetNoKeyName = 'CSHEET'+LTRIM(RTRIM(@c_StockTakeKey)) --NJOW02

	FETCH NEXT FROM cur_1 INTO @c_lot, @c_loc, @c_id, @c_StorerKey, @c_sku, @c_Lottable01, @c_Lottable02, @c_Lottable03,
	@d_Lottable04, @d_Lottable05,@c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09, @c_Lottable10, @c_Lottable11, --(CS01)
	@c_Lottable12,@d_Lottable13, @d_Lottable14, @d_Lottable15,                                                            --(CS01)
	@n_qty, @c_Facility, @c_Aisle, @n_LocLevel, @c_CCLogicalLoc, @n_SystemQty, 
	@c_PutawayZone, @c_UccNo
	
	WHILE @@FETCH_STATUS <> -1
	BEGIN
	 -- select @c_Aisle '@c_Aisle', @c_prev_Aisle '@c_prev_Aisle', @n_LocLevel '@n_LocLevel', @n_prev_LocLevel '@n_prev_LocLevel'
--	   IF @n_LineCount > @n_LinesPerPage 
--	   OR dbo.fnc_RTrim(@c_PutawayZone) <> dbo.fnc_RTrim(@c_PrevZone) 
--	   OR dbo.fnc_RTrim(@c_Aisle) <> dbo.fnc_RTrim(@c_prev_Aisle)
--	   OR dbo.fnc_RTrim(@n_LocLevel) <> dbo.fnc_RTrim(@n_prev_LocLevel)
--	   BEGIN
--	      EXECUTE nspg_getkey
--	      --'CCSheetNo'
--        @c_CCSheetNoKeyName  --NJOW02
--	      , 10
--	      , @c_CCSheetNo OUTPUT
--	      , @b_success OUTPUT
--	      , @n_err OUTPUT
--	      , @c_errmsg OUTPUT
--	      SELECT @n_LineCount = 1
--	   END

      SET @c_CCSheetNo = @c_TaskDetailKey
	
	   EXECUTE nspg_getkey
		   'CCDetailKey'
		   , 10
		   , @c_CCDetailKey OUTPUT
		   , @b_success OUTPUT
		   , @n_err OUTPUT
		   , @c_errmsg OUTPUT

	   IF @c_lot <> ""	
	   BEGIN	
	      INSERT CCDETAIL (cckey, ccdetailkey, StorerKey, sku, lot, loc, id, qty, ccsheetno, Lottable01,
		      Lottable02, Lottable03, Lottable04, Lottable05,Lottable06, Lottable07, Lottable08, Lottable09,  --(CS01)
				Lottable10, Lottable11, Lottable12, Lottable13,Lottable14, Lottable15,SystemQty, RefNo)         --(CS01)
	      VALUES (@c_StockTakeKey, @c_CCDetailKey, @c_StorerKey, @c_sku, @c_lot, @c_loc, @c_id, 0, @c_CCSheetNo,
	      	     @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
					  @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09, @c_Lottable10, @c_Lottable11,       --(CS01)
					  @c_Lottable12,@d_Lottable13,@d_Lottable14, @d_Lottable15,@n_SystemQty, @c_UccNo)               --(CS01)
	   END
	   ELSE
	   BEGIN
	      INSERT CCDETAIL (cckey, ccdetailkey, StorerKey, sku, lot, loc, id, qty, ccsheetno, Lottable01,
	      	Lottable02, Lottable03, Lottable04, Lottable05,Lottable06, Lottable07, Lottable08, Lottable09,  --(CS01)
				Lottable10, Lottable11, Lottable12, Lottable13,Lottable14, Lottable15,SystemQty, RefNo)         --(CS01)
	      VALUES (@c_StockTakeKey, @c_CCDetailKey, @c_StorerKey, @c_sku, @c_lot, @c_loc, @c_id, 0, @c_CCSheetNo,
	      	@c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,  
				@c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09, @c_Lottable10, @c_Lottable11,       --(CS01)
				@c_Lottable12,@d_Lottable13,@d_Lottable14, @d_Lottable15,@n_SystemQty, @c_UccNo)               --(CS01)
	   END
	
	   SELECT @n_LineCount = @n_LineCount + 1
	   SELECT @c_prev_Aisle = @c_Aisle,
	         @n_prev_LocLevel = @n_LocLevel,
	         @c_PreLogLocation = @c_CCLogicalLoc,
	         @c_PrevZone = @c_PutawayZone 
	
	   FETCH NEXT FROM cur_1 INTO @c_lot, @c_loc, @c_id, @c_StorerKey, @c_sku, @c_Lottable01, @c_Lottable02,
				@c_Lottable03, @d_Lottable04, @d_Lottable05,@c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09,        --(CS01) 
				@c_Lottable10, @c_Lottable11, @c_Lottable12,@d_Lottable13, @d_Lottable14, @d_Lottable15,                       --(CS01) 
				@n_qty, @c_Facility, @c_Aisle, @n_LocLevel, @c_CCLogicalLoc,
	         @n_SystemQty, @c_PutawayZone, @c_UccNo
	END -- WHILE
	CLOSE cur_1
	DEALLOCATE cur_1
	DROP TABLE #RESULT
END

GO