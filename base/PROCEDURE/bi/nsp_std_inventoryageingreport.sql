SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*******************************************************************************************
	TITLE - STANDARD INVENTORY AGEING REPORT
	DATE		AUTHOR			VER			PURPOSE
	9/28/22		JAM				1.0			NEW STANDARD REPORT
	10/3/23		JAM				1.1			ADD INVENTORY HOLD STATUS
*******************************************************************************************/
-- Test EXEC [BI].[nsp_STD_InventoryAgeingReport] 'GCI', 'SEV','','','','','40M150'
CREATE     PROC [BI].[nsp_STD_InventoryAgeingReport] 
	@param_storerkey		nvarchar(20)	-- REQUIRED
	,@param_facility		nvarchar(20)	-- REQUIRED
	-- OPTIONAL parameters					-- 
	,@param_locationtype	nvarchar(20)	-- IF BLANK, SKIP THIS CONDITION
	,@param_locationgroup	nvarchar(20)	-- IF BLANK, SKIP THIS CONDITION
	,@param_locationflag	nvarchar(10)	-- IF BLANK, SKIP THIS CONDITION
	,@param_locaisle		nvarchar(20)	-- IF BLANK, SKIP THIS CONDITION
	,@param_sku				nvarchar(20)	-- IF BLANK, SKIP THIS CONDITION

AS
BEGIN
 SET NOCOUNT ON       ;   SET ANSI_DEFAULTS OFF  ;   SET QUOTED_IDENTIFIER OFF;   SET CONCAT_NULL_YIELDS_NULL OFF;
   SET ANSI_NULLS ON    ;   SET ANSI_WARNINGS ON   ;

DECLARE @Debug		BIT = 0
	   , @LogId		INT
       , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
       , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'') --NAME OF SP
       , @cParamOut NVARCHAR(4000)= ''
       , @cParamIn  NVARCHAR(4000)= '{ "PARAM_GENERIC_StorerKey":"'		+@param_storerkey+'",'
                                     + '"PARAM_GENERIC_Facility":"'		+@param_facility+'",'
                                     + '"param_locationtype":"'			+@param_locationtype+'",'
                                     + '"param_locationgroup":"'		+@param_locationgroup+'",'
                                     + '"param_locationflag":"'			+@param_locationflag+'",'
                                     + '"param_locaisle":"'				+@param_locaisle+'",'
                                     + '"param_sku":"'					+@param_sku+'"'
                                     + ' }'
declare	@stmt nvarchar(max) = ''

	SET @param_storerkey = TRIM(@param_storerkey)
	SET @param_facility = TRIM(@param_facility)

EXEC BI.dspExecInit @ClientId = @param_storerkey
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   , @Schema = @Schema;

set @stmt = '
select top 500000
	lli.storerkey
	,loc.facility
	,lli.sku
	,s.descr
	,lli.qty
	,lli.qtyallocated
	,lli.qtypicked
	,(LLI.Qty) -(LLI.QtyAllocated + LLI.QtyPicked) [qtyavailable]
	,lli.qty/nullif(p.casecnt,0)			[qty-cs]
	,lli.qtyallocated/nullif(p.casecnt,0)	[qtyallocated-cs]
	,lli.qtypicked/nullif(p.casecnt,0)		[qtypicked-cs]
	,((LLI.Qty) -(LLI.QtyAllocated + LLI.QtyPicked))/nullif(p.casecnt,0) [qtyavailable-cs]
	,lli.qty/nullif(p.pallet,0)			[qty-pl]
	,lli.qtyallocated/nullif(p.pallet,0)	[qtyallocated-pl]
	,lli.qtypicked/nullif(p.pallet,0)		[qtypicked-pl]
	,((LLI.Qty) -(LLI.QtyAllocated + LLI.QtyPicked))/nullif(p.pallet,0) [qtyavailable-pl]
	,lli.lot
	,lli.loc
	,lli.id
	,p.packkey
	,p.casecnt
	,p.pallet
	,loc.HOSTWHCODE
	,loc.LocAisle
	,loc.LocationCategory
	,loc.LocationFlag
	,loc.LocationGroup
	,loc.LocationType
	,loc.CCLogicalLoc
	,loc.LogicalLocation
	,loc.PutawayZone
	,loc.SectionKey
	,loc.PALogicalLoc
	,la.lottable01
	,la.lottable02
	,la.lottable03
	,la.lottable04
	,la.lottable05
	,la.lottable06
	,la.lottable07
	,la.lottable08
	,la.lottable09
	,la.lottable10
	,la.lottable11
	,la.lottable12
	,la.lottable13
	,la.lottable14
	,la.lottable15
	,s.lottable01label
	,s.lottable02label
	,s.lottable03label
	,s.lottable04label
	,s.lottable05label
	,s.lottable06label
	,s.lottable07label
	,s.lottable08label
	,s.lottable09label
	,s.lottable10label
	,s.lottable11label
	,s.lottable12label
	,s.lottable13label
	,s.lottable14label
	,s.lottable15label
	,s.susr1
	,s.susr2
	,s.susr3
	,s.susr4
	,s.susr5
	,s.active
	,s.skugroup
	,S.CLASS
	,S.ITEMCLASS
	,S.MANUFACTURERSKU
	,S.RETAILSKU
	,S.ALTSKU
	,S.IVAS
	,S.LOTTABLECODE
	,s.price
	,s.cost
	,s.shelflife '
set @stmt = @stmt +
'	,case	when s.lottable01label IN (''BATCHNO'',''BBT_BATCH'',''BATCHNUM'') then la.lottable01
			when s.lottable02label IN (''BATCHNO'',''BBT_BATCH'',''BATCHNUM'') then la.lottable02
			when s.lottable03label IN (''BATCHNO'',''BBT_BATCH'',''BATCHNUM'') then la.lottable03
			when s.lottable06label IN (''BATCHNO'',''BBT_BATCH'',''BATCHNUM'') then la.Lottable06
			when s.lottable07label IN (''BATCHNO'',''BBT_BATCH'',''BATCHNUM'') then la.Lottable07
			when s.lottable08label IN (''BATCHNO'',''BBT_BATCH'',''BATCHNUM'') then la.Lottable08
			when s.lottable09label IN (''BATCHNO'',''BBT_BATCH'',''BATCHNUM'') then la.Lottable09
			when s.lottable10label IN (''BATCHNO'',''BBT_BATCH'',''BATCHNUM'') then la.lottable10
			when s.lottable11label IN (''BATCHNO'',''BBT_BATCH'',''BATCHNUM'') then la.lottable11
			when s.lottable12label IN (''BATCHNO'',''BBT_BATCH'',''BATCHNUM'') then la.lottable12
			else NULL
	end [BATCHNO]
	,case	when s.lottable04label IN (''RCP_DATE'') then la.lottable04
			when s.lottable05label IN (''RCP_DATE'') then la.lottable05
			when s.lottable13label IN (''RCP_DATE'') then la.lottable13
			when s.lottable14label IN (''RCP_DATE'') then la.lottable14
			when s.lottable15label IN (''RCP_DATE'') then la.lottable15
			else NULL
	end [RECEIPTDATE]
	,case	when s.lottable04label IN (''MANF-DATE'',''PRODN_DATE'',''PRD_DATE'',''PRODDATE'') then la.lottable04
			when s.lottable05label IN (''MANF-DATE'',''PRODN_DATE'',''PRD_DATE'',''PRODDATE'') then la.lottable05
			when s.lottable13label IN (''MANF-DATE'',''PRODN_DATE'',''PRD_DATE'',''PRODDATE'') then la.lottable13
			when s.lottable14label IN (''MANF-DATE'',''PRODN_DATE'',''PRD_DATE'',''PRODDATE'') then la.lottable14
			when s.lottable15label IN (''MANF-DATE'',''PRODN_DATE'',''PRD_DATE'',''PRODDATE'') then la.lottable15
			else NULL
	end [PRODDATE]
	,case	when s.lottable04label IN (''BBT_EXPDATE'',''EXP_DATE'',''CBD'',''EXPDATE'',''EXP-DATE'',''EXPIRY DATE'',''Expiry Date/CBD'') then la.lottable04
			when s.lottable05label IN (''BBT_EXPDATE'',''EXP_DATE'',''CBD'',''EXPDATE'',''EXP-DATE'',''EXPIRY DATE'',''Expiry Date/CBD'') then la.lottable05
			when s.lottable13label IN (''BBT_EXPDATE'',''EXP_DATE'',''CBD'',''EXPDATE'',''EXP-DATE'',''EXPIRY DATE'',''Expiry Date/CBD'') then la.lottable13
			when s.lottable14label IN (''BBT_EXPDATE'',''EXP_DATE'',''CBD'',''EXPDATE'',''EXP-DATE'',''EXPIRY DATE'',''Expiry Date/CBD'') then la.lottable14
			when s.lottable15label IN (''BBT_EXPDATE'',''EXP_DATE'',''CBD'',''EXPDATE'',''EXP-DATE'',''EXPIRY DATE'',''Expiry Date/CBD'') then la.lottable15
			else NULL
	end [EXPIRYDATE]
	,s.abc
	,CASE WHEN (ID.Status = ''HOLD'' AND LOT.Status = ''HOLD'' AND LOC.Status = ''HOLD'') THEN ''HOLD (ID, LOT, LOC)'' 
		WHEN (ID.Status = ''HOLD'' AND LOT.Status = ''HOLD'') THEN ''HOLD (ID, LOT)'' 
		WHEN (ID.Status = ''HOLD'' AND LOC.Status = ''HOLD'') THEN ''HOLD (ID, LOC)'' 
		WHEN (LOT.Status = ''HOLD'' AND LOC.Status = ''HOLD'') THEN ''HOLD (LOT, LOC)'' 
		WHEN (ID.Status = ''HOLD'') THEN ''HOLD (ID)'' 
		WHEN (LOC.LocationFlag = ''HOLD'' OR LOC.LocationFlag = ''DAMAGE'') THEN ''HOLD (LOC)'' 
		WHEN (LOC.Status = ''HOLD'') THEN ''HOLD (LOC)'' 
		WHEN (LOT.Status = ''HOLD'') THEN ''HOLD (LOT)'' 
		ELSE ''OK'' END [HoldStatus]
from
	BI.v_lotxlocxid lli (nolock)
	inner join BI.v_loc loc (nolock) on loc.facility='''+@param_facility+''' and lli.loc=loc.loc
	inner join BI.v_sku s (nolock) on lli.storerkey=s.storerkey and lli.sku=s.sku
	inner join BI.v_lotattribute la (nolock) on la.lot=lli.lot and la.sku=lli.sku and la.storerkey=lli.storerkey
	inner join BI.v_pack p (nolock) on s.packkey=p.packkey
	INNER JOIN BI.V_ID ID WITH (NOLOCK) ON lli.Id = ID.Id 
	INNER JOIN BI.V_LOT LOT WITH (NOLOCK) ON LLI.Lot = LOT.Lot
where
	lli.storerkey		= '''+@param_storerkey+'''
	and loc.facility	= '''+@param_facility+''''
-- OPTIONAL PARAMETERS. IF BLANK, EXCLUDE TO @STMT
	if ISNULL(@param_locationtype,'')<>''
	Begin
		set @stmt = @stmt + ' and loc.locationtype = ''' + @param_locationtype + ''''
	End
	if ISNULL(@param_locationgroup,'')<>''
	Begin
		set @stmt = @stmt + ' and loc.locationgroup = ''' + @param_locationgroup + ''''
	End
	if ISNULL(@param_locationflag,'')<>''
	Begin
		set @stmt = @stmt + ' and loc.locationflag = ''' + @param_locationflag + ''''
	End
	if ISNULL(@param_locaisle,'')<>''
	Begin
		set @stmt = @stmt + ' and loc.locaisle = ''' + @param_locaisle + ''''
	End
	if ISNULL(@param_sku,'')<>''
	Begin
		set @stmt = @stmt + ' and lli.sku = ''' + @param_sku + ''''
	End

set @stmt = @stmt +
'	and lli.qty>0
order by 1,2,3,13,14
'

PRINT @Stmt
EXEC BI.dspExecStmt @Stmt = @stmt
   , @LogId = @LogId
   , @Debug = @Debug;

END

GO