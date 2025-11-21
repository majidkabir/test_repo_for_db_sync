SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[ispGenTagNo] (
@c_StockTakeKey NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
DECLARE @c_Facility	   NVARCHAR(5),
        @c_StorerKey	   NVARCHAR(18),
        @c_AisleParm	   NVARCHAR(60),
        @c_LevelParm	   NVARCHAR(60),
        @c_ZoneParm	   NVARCHAR(60),
        @c_HostWHCodeParm  NVARCHAR(60),
        @c_ClearHistory	   NVARCHAR(1),
        @c_WithQuantity    NVARCHAR(1),
        @c_EmptyLocation   NVARCHAR(1),
        @n_LinesPerPage    int,
        @c_SKUParm         NVARCHAR(125)

DECLARE @c_AreaKey    NVARCHAR(10),
	@c_loc		       NVARCHAR(10),
	@c_LocAisle	       NVARCHAR(10),
	@n_loclevel	       int,
	@c_prev_Facility   NVARCHAR(5),
	@c_prev_Aisle	    NVARCHAR(10),
	@n_prev_loclevel   int,
	@c_ccdetailkey	    NVARCHAR(10),
	@c_CountSheetNo	 NVARCHAR(10),
	@n_err		       int,
	@c_errmsg	       NVARCHAR(250),
	@n_LineCount       int,
	@c_PreLogLocation  NVARCHAR(18),
	@c_LogicalLocation NVARCHAR(18),
   @n_TagNo           int

SELECT @c_prev_Facility = " ", @c_prev_Aisle = " ", @n_prev_loclevel = 0, @c_PreLogLocation = ''

DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY FOR  
   SELECT CCDETAILKEY,  LOC.LOC,      CCSheetNo,
          LOC.Facility, LOC.LOCAisle, LOC.LocLevel, 
          LOC.CCLogicalLoc,           ISNULL(AreaDetail.AreaKey, ' ') As AreaKey  
   FROM CCDETAIL (NOLOCK)
   JOIN LOC (NOLOCK) ON (CCDETAIL.LOC = LOC.LOC)
   LEFT OUTER JOIN AreaDetail (NOLOCK) ON (AreaDetail.PutAwayZone = LOC.PutawayZone)
   WHERE CCKey = @c_StockTakeKey 
   ORDER BY CCSheetNo, CCDETAILKEY 

OPEN cur_1

SELECT @n_TagNo = 0 

FETCH NEXT FROM CUR_1 INTO @c_ccDetailKey,    @c_loc,       @c_CountSheetNo, 
                           @c_Facility,       @c_LocAisle,  @n_LocLevel,
                           @c_LogicalLocation,   @c_AreaKey

WHILE @@FETCH_STATUS <> -1
BEGIN
   SELECT @n_TagNo = @n_TagNo + 1

   UPDATE CCDETAIL 
      SET TagNo = RIGHT( Replicate('0',9) + dbo.fnc_RTrim(CAST(@n_TagNo AS NVARCHAR(10))), 10)
   WHERE CCDETAILKEY = @c_ccDetailKey


   FETCH NEXT FROM CUR_1 INTO @c_ccDetailKey,    @c_loc,       @c_CountSheetNo, 
                           @c_Facility,       @c_LocAisle,     @n_LocLevel,
                           @c_LogicalLocation,   @c_AreaKey
END -- WHILE

CLOSE cur_1
DEALLOCATE cur_1


END


GO