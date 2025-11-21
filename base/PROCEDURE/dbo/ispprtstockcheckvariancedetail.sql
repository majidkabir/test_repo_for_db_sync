SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROCEDURE [dbo].[ispPrtStockCheckVarianceDetail](
			@c_StockTakeKey NVARCHAR(10),
			@c_StorerKey_Start NVARCHAR(15),
			@c_StorerKey_End NVARCHAR(15),
			@c_SKU_Start NVARCHAR(20),
			@c_SKU_End NVARCHAR(20),
			@c_LOC_Start NVARCHAR(10),
			@c_LOC_End NVARCHAR(10),
			@c_ItemClass_Start NVARCHAR(10),
			@c_ItemClass_End NVARCHAR(10),
			@c_Zone_Start NVARCHAR(10),
			@c_Zone_End NVARCHAR(10),
			@c_CCSheetNo_Start NVARCHAR(10),
			@c_CCSheetNo_End NVARCHAR(10),
			@c_groupby NVARCHAR(10),
			@c_CountNo  NVARCHAR(2)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @theSQLStmt NVARCHAR(1500)

   SELECT @theSQLStmt = 'SELECT CCDetail.CCKey,CCDetail.CCSheetNo,CCDetail.TagNo,CCDetail.Storerkey,CCDetail.Sku,CCDetail.SystemQty,'   
   SELECT @theSQLStmt = dbo.fnc_RTrim(@theSQLStmt) + 'CASE N'''+dbo.fnc_RTrim(@c_CountNo)+''' WHEN ''3'' THEN CCDETAIL.Qty_Cnt2 ELSE CCDetail.Qty END AS PhyCntQty1,'
   SELECT @theSQLStmt = dbo.fnc_RTrim(@theSQLStmt) + 'CASE N'''+dbo.fnc_RTrim(@c_CountNo)+''' WHEN ''1'' THEN CCDetail.Qty_Cnt2 ELSE CCDETAIL.Qty_Cnt3 END AS PhyCntQty2,'   
   SELECT @theSQLStmt = dbo.fnc_RTrim(@theSQLStmt) + 'CCDetail.Lottable02,CCDetail.Lottable04,PACK.PackUOM3,SKU.DESCR,LOC.Facility,LOC.PutawayZone,'   
   SELECT @theSQLStmt = dbo.fnc_RTrim(@theSQLStmt) + 'LOC.Loc,STORER.Company,N'''+dbo.fnc_RTrim(@c_CountNo)+''' AS CountNo,N'''+dbo.fnc_RTrim(@c_GroupBy)+''' AS GroupBy,' 
   SELECT @theSQLStmt = dbo.fnc_RTrim(@theSQLStmt) + 'SKU.ItemClass,SKU.SkuGroup,SKU.Susr3,SKU.Busr3,SKU.Busr5,SKU.'+dbo.fnc_RTrim(@c_GroupBy)+' AS GroupValue'
   SELECT @theSQLStmt = dbo.fnc_RTrim(@theSQLStmt) + ' FROM CCDetail (NOLOCK)'
   SELECT @theSQLStmt = dbo.fnc_RTrim(@theSQLStmt) + ' LEFT OUTER JOIN SKU (NOLOCK) ON ( CCDetail.Storerkey = SKU.StorerKey and CCDetail.Sku = SKU.Sku )'
   SELECT @theSQLStmt = dbo.fnc_RTrim(@theSQLStmt) + ' LEFT OUTER JOIN PACK (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey )' 
   SELECT @theSQLStmt = dbo.fnc_RTrim(@theSQLStmt) + ' JOIN LOC (NOLOCK) ON ( CCDetail.Loc = LOC.Loc )'
   SELECT @theSQLStmt = dbo.fnc_RTrim(@theSQLStmt) + ' LEFT JOIN STORER (NOLOCK) ON ( STORER.StorerKey = SKU.StorerKey )'
   SELECT @theSQLStmt = dbo.fnc_RTrim(@theSQLStmt) + ' LEFT OUTER JOIN AreaDetail (NOLOCK) ON ( AreaDetail.PutawayZone = LOC.PutawayZone )'
   SELECT @theSQLStmt = dbo.fnc_RTrim(@theSQLStmt) + ' WHERE CCDetail.CCKey = N'''+@c_StockTakeKey+''''
   SELECT @theSQLStmt = dbo.fnc_RTrim(@theSQLStmt) + ' AND CCDetail.StorerKey Between N'''+@c_StorerKey_Start+''' AND N'''+@c_StorerKey_End+''''
   SELECT @theSQLStmt = dbo.fnc_RTrim(@theSQLStmt) + ' AND CCDetail.SKU Between N'''+@c_SKU_Start+''' AND N'''+@c_SKU_End+''''
   SELECT @theSQLStmt = dbo.fnc_RTrim(@theSQLStmt) + ' AND CCDETAIL.CCSheetNo Between N'''+@c_CCSheetNo_Start+''' AND N'''+@c_CCSheetNo_End+''''
   SELECT @theSQLStmt = dbo.fnc_RTrim(@theSQLStmt) + ' AND SKU.ItemClass Between N'''+@c_ItemClass_Start+''' AND N'''+@c_ItemClass_End+''''
   SELECT @theSQLStmt = dbo.fnc_RTrim(@theSQLStmt) + ' AND LOC.LOC Between N'''+@c_LOC_Start+''' AND N'''+@c_LOC_End+''''
   SELECT @theSQLStmt = dbo.fnc_RTrim(@theSQLStmt) + ' AND LOC.PutawayZone Between N'''+@c_Zone_Start+''' AND N'''+@c_Zone_End+''''
   SELECT @theSQLStmt = dbo.fnc_RTrim(@theSQLStmt) + ' ORDER BY SKU.'+@c_groupby+',SKU.sku'

   EXEC(@theSQLStmt)
END -- End Procedure


GO