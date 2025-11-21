SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispGenCountSheetByUCC                              */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Generate Count Sheet by UCC in Stock Take module            */
/*                                                                      */
/* Called By: PB object nep_n_cst_stocktake_parm_new                    */
/*                                                                      */
/* PVCS Version: 1.8                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 11-Aug-2004  Shong      Fixes                                        */
/* 12-Aug-2004  Wally      Include DYNAMICPK location type              */
/* 15-Oct-2004  Mohit      Changed cursor type                          */
/* 21-Oct-2004  June       SOS28639 Changed id to NVARCHAR(18)          */
/* 19-Jul-2005  MaryVong   SOS35241 Changed StockTake LotxLocxID.Qty    */
/*                         to (Qty-QtyAllocated-QtyPicked)              */
/* 10-Nov-2005  MaryVong   SOS42806 Increase length of returned fields  */
/*                         from ispParseParameters to NVARCHAR(800)     */
/* 19-Jan-2006  Vicky      SOS#44960 - Add in Locationtype 'OTHER' to   */
/*                         extraction of System Qty                     */
/* 19-Apr-2006  June       SOS48814 - Bug fixed SOS44960                */
/* 18-Jan-2008  June        SOS66279 : Include STOCKTAKEPARM2 checking  */
/* 05-Aug-2010  NJOW01     182454 - Add skugroup parameter              */
/* 25-Jul-2011  NJOW02     216737-New count sheet seq# for every stock  */
/*                         take.                                        */
/* 01-Mar-2012  James      Additional LOC filter (james01)              */
/* 19-Oct-2012  Ung        SOS254691 Revert back UCC.Status = 1, 2      */
/*                         Not generate UCC for SHELVING, DECK location */
/* 22-Oct-2012  James      254690-Add CountType (james02)               */
/*                         If loc.loseucc=0, then UCC should populate to*/
/*                         the ccdetail.refno field                     */
/* 18-Mar-2013  James      Take qty from UCC when LOC is not loseucc    */
/*                         (james03)                                    */
/* 05-Sep-2013  NJOW3      288779-Default status by storerconfig        */
/*                         GenUCCCountSheetStatus2                      */
/* 29-Oct-2013  YTWan      Fixed to Group By Loc.LoseUCC,               */
/*                         ISNULL(MIN(UCC.Qty),0) to set 0              */
/*                         if min(ucc.qty) is Null        (Wan01)       */
/* 21-May-2014  TKLIM      Added Lottables 06-15                        */
/* 28-MAR-2016  Wan02      SOS#366947: SG-Stocktake LocationRoom Parm   */
/* 16-JUN-2016  Wan03      SOS#366947: SOS#371185 - CN Carter's SH      */
/*                         WMS Cycle Count module                       */
/* 29-JUN-2016  Wan04      SOS#370874 - TW Add Cycle Count Strategy     */
/* 08-AUG-2016  Wan05      SOS#373839 - [TW] CountSheet Generation Logic*/
/* 23-NOV-2016  Wan06      WMS-648 - GW StockTake Parameter2 Enhancement*/
/* 21-Jan-2021  WLChooi    WMS-15985 - Generate No. Of Loc by Count     */
/*                         Sheet (WL01)                                 */
/* 03-Mar-2021  WLChooi    WMS-15985 - Fix LocPerPage Logic (WL02)      */
/************************************************************************/

CREATE PROC ispGenCountSheetByUCC (
    @c_StockTakeKey NVARCHAR(10)
)
AS
BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE @c_Facility                 NVARCHAR(5)
        , @c_StorerKey                NVARCHAR(18)
        , @c_AisleParm                NVARCHAR(60)
        , @c_LevelParm                NVARCHAR(60)
        , @c_ZoneParm                 NVARCHAR(60)
        , @c_HostWHCodeParm           NVARCHAR(60)
        , @c_ClearHistory             NVARCHAR(1)
        , @c_WithQuantity             NVARCHAR(1)
        , @c_EmptyLocation            NVARCHAR(1)
        , @n_LinesPerPage             int
        , @c_SKUParm                  NVARCHAR(125)
        -- Added by SHONG 01-Oct-2002
        , @c_AgencyParm               NVARCHAR(150)
        , @c_ABCParm                  NVARCHAR(60)
        , @c_SkuGroupParm             NVARCHAR(125)
        , @c_CCSheetNoKeyName         NVARCHAR(30)   -- NJOW02
        , @b_Debug                    int            -- (james01)
        , @c_ExcludeQtyPicked         NVARCHAR(1)    -- (james01)
        , @c_GenCCdetailbyExcludePKDStatus3 NVARCHAR(1)
        , @c_PickDetailJoinQuery NVARCHAR(255) = ''
        , @c_PickDetailQtySubtractQuery NVARCHAR(255) = ''
        , @c_authority NVARCHAR(1)
        , @c_GenUCCCountSheetStatus2  NVARCHAR(10)   --NJOW03
        , @c_Status                   NVARCHAR(10)   --NJOW03
    --(Wan02) - START
        , @c_Extendedparm1Field       NVARCHAR(50)
        , @c_ExtendedParm1DataType    NVARCHAR(20)
        , @c_Extendedparm1            NVARCHAR(125)
        , @c_Extendedparm2Field       NVARCHAR(50)
        , @c_ExtendedParm2DataType    NVARCHAR(20)
        , @c_Extendedparm2            NVARCHAR(125)
        , @c_Extendedparm3Field       NVARCHAR(50)
        , @c_ExtendedParm3DataType    NVARCHAR(20)
        , @c_Extendedparm3            NVARCHAR(125)
        --(Wan02) - END
        , @c_ExcludeQtyAllocated      NVARCHAR(1)    --(Wan03)
    --(Wan05) - START
        , @c_CountSheetGroupBy       NVARCHAR(1000)
        , @c_CountSheetSortBy        NVARCHAR(1000)
        , @c_PartitionBy             NVARCHAR(1000)
        , @c_SortBy                  NVARCHAR(1000)
        , @c_ColumnName              NVARCHAR(50)
        , @c_SheetLineColumn         NVARCHAR(1000)
        , @n_SheetLineNo             INT
        , @c_RowRefColumn            NVARCHAR(1000)
        , @n_RowRef                  BIGINT
        --(Wan05) - END
        , @n_LOCPerPage              INT                  --WL01
        , @c_IsLOCPerPage            NVARCHAR(10) = 'Y'   --WL01
        , @n_LOCLineCount            INT = 0              --WL02

    SET @b_Debug = 0

    -- declare a select condition variable for parameters
    -- SOS42806 Changed NVARCHAR(250) and NVARCHAR(255) to NVARCHAR(800)
    DECLARE @c_AisleSQL           NVARCHAR(800)
        , @c_LevelSQL           NVARCHAR(800)
        , @c_ZoneSQL            NVARCHAR(800)
        , @c_HostWHCodeSQL      NVARCHAR(800)
        , @c_AisleSQL2          NVARCHAR(800)
        , @c_LevelSQL2          NVARCHAR(800)
        , @c_ZoneSQL2           NVARCHAR(800)
        , @c_HostWHCodeSQL2     NVARCHAR(800)
        , @c_SKUSQL             NVARCHAR(800)
        , @c_SKUSQL2            NVARCHAR(800)
        , @b_success            int
        , @c_AgencySQL          NVARCHAR(800)
        , @c_AgencySQL2         NVARCHAR(800)
        , @c_ABCSQL             NVARCHAR(800)
        , @c_ABCSQL2            NVARCHAR(800)
        , @c_SkuGroupSQL        NVARCHAR(800)
        , @c_SkuGroupSQL2       NVARCHAR(800)
        --(Wan02) - START
        ,  @c_Extendedparm1SQL  NVARCHAR(800)
        ,  @c_Extendedparm1SQL2 NVARCHAR(800)
        ,  @c_Extendedparm2SQL  NVARCHAR(800)
        ,  @c_Extendedparm2SQL2 NVARCHAR(800)
        ,  @c_Extendedparm3SQL  NVARCHAR(800)
        ,  @c_Extendedparm3SQL2 NVARCHAR(800)
    --(Wan02) - END

    -- Add by June 12.Mar.02 FBR063
    DECLARE @c_StorerSQL          NVARCHAR(800)
        , @c_StorerSQL2         NVARCHAR(800)
        , @c_StorerParm         NVARCHAR(60)
        , @c_GroupLottable05    NVARCHAR(10)

    -- Start : SOS66279
    DECLARE @c_sqlOther           NVARCHAR(4000)
        , @c_sqlWhere           NVARCHAR(4000)
        , @c_sqlGroup           NVARCHAR(4000)

    SELECT  @c_sqlOther = ''
    -- End : SOS66279

    --(Wan04) - START
    DECLARE  @n_err            INT
        ,  @c_errmsg         NVARCHAR(255)
        ,  @c_StrategySQL    NVARCHAR(4000)
        ,  @c_StrategySkuSQL NVARCHAR(4000)
        ,  @c_StrategyLocSQL NVARCHAR(4000)
    --(Wan04) - END

    --(Wan02) - START
    SET @c_Extendedparm1Field   = ''
    SET @c_ExtendedParm1DataType= ''
    SET @c_Extendedparm1        = ''
    SET @c_Extendedparm2Field   = ''
    SET @c_ExtendedParm2DataType= ''
    SET @c_Extendedparm2        = ''
    SET @c_Extendedparm3Field   = ''
    SET @c_ExtendedParm3DataType= ''
    SET @c_Extendedparm3        = ''
    SET @c_Extendedparm1SQL     = ''
    SET @c_Extendedparm1SQL2    = ''
    SET @c_Extendedparm2SQL     = ''
    SET @c_Extendedparm2SQL2    = ''
    SET @c_Extendedparm3SQL     = ''
    SET @c_Extendedparm3SQL2    = ''
    --(Wan02) - END

    --(Wan05) - START
    SET @c_CountSheetGroupBy   = ''
    SET @c_CountSheetSortBy    = ''
    SET @c_PartitionBy         = ''
    SET @c_SortBy              = ''
    SET @c_ColumnName          = ''
    SET @c_SheetLineColumn     = ''
    SET @n_SheetLineNo         = 0
    SET @c_RowRefColumn        = ''
    SET @n_RowRef              = 0
    --(Wan05) - END

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
           @c_SkuGroupParm = SkuGroupParm,
           @c_ExcludeQtyPicked = ExcludeQtyPicked
           --(Wan01) - START
            , @c_ExtendedParm1Field = ExtendedParm1Field
            , @c_ExtendedParm1      = ExtendedParm1
            , @c_ExtendedParm2Field = ExtendedParm2Field
            , @c_ExtendedParm2      = ExtendedParm2
            , @c_ExtendedParm3Field = ExtendedParm3Field
            , @c_ExtendedParm3      = ExtendedParm3
           --(Wan01) - END
            , @c_ExcludeQtyAllocated= ExcludeQtyAllocated         --(Wan03)
           --(Wan05) - START
            , @c_CountSheetGroupBy  = CountSheetGroupBy01
        + ',' + CountSheetGroupBy02
        + ',' + CountSheetGroupBy03
        + ',' + CountSheetGroupBy04
        + ',' + CountSheetGroupBy05
            , @c_CountSheetSortBy = CountSheetSortBy01
        + ',' + CountSheetSortBy02
        + ',' + CountSheetSortBy03
        + ',' + CountSheetSortBy04
        + ',' + CountSheetSortBy05
        + ',' + CountSheetSortBy06
        + ',' + CountSheetSortBy07
        + ',' + CountSheetSortBy08
           --(Wan05) - END
            , @n_LOCPerPage       = LocPerPage   --WL01
    FROM StockTakeSheetParameters (NOLOCK)
    WHERE StockTakeKey = @c_StockTakeKey
    SET NOCOUNT ON

    SET @c_GenCCdetailbyExcludePKDStatus3 = ''
    EXEC nspGetRight
         @c_Facility   = @c_Facility ,
         @c_StorerKey  = @c_StorerParm,
         @c_sku        = '',
         @c_ConfigKey  = 'GenCCdetailbyExcludePKDStatus3',
         @b_Success    = @b_Success OUTPUT,
         @c_authority  = @c_GenCCdetailbyExcludePKDStatus3  OUTPUT,
         @n_err        = @n_err   OUTPUT,
         @c_errmsg     = @c_ErrMsg  OUTPUT
    IF @b_Success<>1
        BEGIN
            RAISERROR('Error Executing nspGetRight', 16, 1)
            RETURN
        END
    IF @c_GenCCdetailbyExcludePKDStatus3 = '1'
        BEGIN
            SET @c_GenCCdetailbyExcludePKDStatus3 = 'Y'
            SET  @c_PickDetailJoinQuery = 'LEFT JOIN PICKDETAIL WITH (NOLOCK) ON PICKDETAIL.Lot = LOTxLOCxID.Lot and PICKDETAIL.Loc = LOTxLOCxID.Loc and PICKDETAIL.ID = LOTxLOCxID.Id '
            SET @c_PickDetailQtySubtractQuery = ' - CASE WHEN PICKDETAIL.Status=''3'' THEN PICKDETAIL.Qty ELSE 0 END '
        END
    ELSE
        SET @c_GenCCdetailbyExcludePKDStatus3 = 'N'

    IF @n_LinesPerPage = 0 OR @n_LinesPerPage IS NULL
        SELECT @n_LinesPerPage = 999

    --WL01 S
    IF @n_LOCPerPage = 0 OR @n_LOCPerPage IS NULL OR @n_LOCPerPage = 999
        BEGIN
            SET @c_IsLOCPerPage = 'N'
            SET @n_LOCPerPage = 999
        END
    --WL01 E

    EXEC ispParseParameters
         @c_StorerParm,
         'string',
         'LOTXLOCXID.StorerKey',
         @c_StorerSQL OUTPUT,
         @c_StorerSQL2 OUTPUT,
         @b_success OUTPUT

    IF @c_StorerSQL IS NULL And @c_StorerSQL2 IS NULL
        BEGIN
            RETURN
        END

    EXEC ispParseParameters
         @c_AisleParm,
         'string',
         'LOC.LOCAISLE',
         @c_AisleSQL OUTPUT,
         @c_AisleSQL2 OUTPUT,
         @b_success OUTPUT

    EXEC ispParseParameters
         @c_LevelParm,
         'number',
         'LOC.LocLevel',
         @c_LevelSQL OUTPUT,
         @c_LevelSQL2 OUTPUT,
         @b_success OUTPUT

    EXEC ispParseParameters
         @c_ZoneParm,
         'string',
         'LOC.PutawayZone',
         @c_ZoneSQL OUTPUT,
         @c_ZoneSQL2 OUTPUT,
         @b_success OUTPUT

    EXEC ispParseParameters
         @c_HostWHCodeParm,
         'string',
         'LOC.HostWHCode',
         @c_HostWHCodeSQL OUTPUT,
         @c_HostWHCodeSQL2 OUTPUT,
         @b_success OUTPUT

    EXEC ispParseParameters
         @c_SKUParm,
         'string',
         'LOTxLOCxID.SKU',
         @c_SKUSQL OUTPUT,
         @c_SKUSQL2 OUTPUT,
         @b_success OUTPUT

    -- Purge All the historical records for this stocktakekey if clear history flag = 'Y'
    IF @c_ClearHistory = 'Y'
        BEGIN
            DELETE CCDETAIL
            WHERE  CCKEY = @c_StockTakeKey
        END

    -- Added By SHONG 01 Oct 2002
    EXEC ispParseParameters
         @c_AgencyParm,
         'string',
         'SKU.SUSR3',
         @c_AgencySQL OUTPUT,
         @c_AgencySQL2 OUTPUT,
         @b_success OUTPUT

    EXEC ispParseParameters
         @c_ABCParm,
         'string',
         'SKU.ABC',
         @c_ABCSQL OUTPUT,
         @c_ABCSQL2 OUTPUT,
         @b_success OUTPUT
    -- End

    EXEC ispParseParameters
         @c_SkuGroupParm,
         'string',
         'SKU.SKUGROUP',
         @c_SkuGroupSQL OUTPUT,
         @c_SkuGroupSQL2 OUTPUT,
         @b_success OUTPUT

    --(Wan02) - START
    EXEC isp_GetDataType
         @c_TableName   = ''
        , @c_FieldName   = @c_ExtendedParm1Field
        , @c_DB_DataType = ''
        , @c_PB_DataType = @c_ExtendedParm1DataType OUTPUT


    IF @c_ExtendedParm1DataType <> ''
        BEGIN
            EXEC ispParseParameters
                 @c_ExtendedParm1
                ,@c_ExtendedParm1DataType
                ,@c_ExtendedParm1Field
                ,@c_ExtendedParm1SQL    OUTPUT
                ,@c_ExtendedParm1SQL2   OUTPUT
                ,@b_success             OUTPUT
        END

    EXEC isp_GetDataType
         @c_TableName   = ''
        , @c_FieldName   = @c_ExtendedParm2Field
        , @c_DB_DataType = ''
        , @c_PB_DataType = @c_ExtendedParm2DataType OUTPUT

    IF @c_ExtendedParm2DataType <> ''
        BEGIN
            EXEC ispParseParameters
                 @c_ExtendedParm2
                ,@c_ExtendedParm2DataType
                ,@c_ExtendedParm2Field
                ,@c_ExtendedParm2SQL    OUTPUT
                ,@c_ExtendedParm2SQL2   OUTPUT
                ,@b_success             OUTPUT
        END

    EXEC isp_GetDataType
         @c_TableName   = ''
        , @c_FieldName   = @c_ExtendedParm3Field
        , @c_DB_DataType = ''
        , @c_PB_DataType = @c_ExtendedParm3DataType OUTPUT

    IF @c_ExtendedParm3DataType <> ''
        BEGIN
            EXEC ispParseParameters
                 @c_ExtendedParm3
                ,@c_ExtendedParm3DataType
                ,@c_ExtendedParm3Field
                ,@c_ExtendedParm3SQL    OUTPUT
                ,@c_ExtendedParm3SQL2   OUTPUT
                ,@b_success             OUTPUT
        END
    --(Wan02) - END

    --(Wan04) - START
    EXEC ispCCStrategy
         @c_StockTakeKey   = @c_StockTakeKey
        ,  @c_StrategySQL    = @c_StrategySQL     OUTPUT
        ,  @c_StrategySkuSQL = @c_StrategySkuSQL  OUTPUT
        ,  @c_StrategyLocSQL = @c_StrategyLocSQL  OUTPUT
        ,  @b_Success        = @b_Success         OUTPUT
        ,  @n_err            = @n_err             OUTPUT
        ,  @c_errmsg         = @c_errmsg          OUTPUT

    IF @b_Success <> 1
        BEGIN
            RAISERROR('Error Executing ispCCStrategy', 16, 1)
            RETURN
        END
    --(Wan04) - END

    --(Wan06) - START
    DECLARE @c_SkuConditionSQL          NVARCHAR(MAX)
        , @c_LocConditionSQL          NVARCHAR(MAX)
        , @c_ExtendedConditionSQL1    NVARCHAR(MAX)
        , @c_ExtendedConditionSQL2    NVARCHAR(MAX)
        , @c_ExtendedConditionSQL3    NVARCHAR(MAX)
        , @c_StocktakeParm2SQL        NVARCHAR(MAX)
        , @c_StocktakeParm2OtherSQL   NVARCHAR(MAX)

    SET @c_SkuConditionSQL = ISNULL(RTrim(@c_SKUSQL), '')      + ' ' + ISNULL(RTrim(@c_SKUSQL2), '') + ' '
        + ISNULL(RTrim(@c_AgencySQL), '')   + ' ' + ISNULL(RTrim(@c_AgencySQL2), '') + ' '
        + ISNULL(RTrim(@c_ABCSQL), '')      + ' ' + ISNULL(RTrim(@c_ABCSQL2), '') + ' '
        + ISNULL(RTrim(@c_SkuGroupSQL), '') + ' ' + ISNULL(RTrim(@c_SkuGroupSQL2), '') + ' '

    SET @c_LocConditionSQL =
            + ISNULL(RTrim(@c_ZoneSQL), '')       + ' ' + ISNULL(RTrim(@c_ZoneSQL2), '') + ' '
                + ISNULL(RTrim(@c_AisleSQL), '')      + ' ' + ISNULL(RTrim(@c_AisleSQL2), '') + ' '
                + ISNULL(RTrim(@c_LevelSQL), '')      + ' ' + ISNULL(RTrim(@c_LevelSQL2), '') + ' '
                + ISNULL(RTrim(@c_HostWHCodeSQL), '') + ' ' + ISNULL(RTrim(@c_HostWHCodeSQL2), '') + ' '

    SET @c_ExtendedConditionSQL1 = ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
    SET @c_ExtendedConditionSQL2 = ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
    SET @c_ExtendedConditionSQL3 = ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')

    EXEC ispGetStocktakeParm2
         @c_StockTakeKey    = @c_StockTakeKey
        ,  @c_SkuConditionSQL = @c_SkuConditionSQL
        ,  @c_LocConditionSQL = @c_LocConditionSQL
        ,  @c_ExtendedConditionSQL1 = @c_ExtendedConditionSQL1
        ,  @c_ExtendedConditionSQL2 = @c_ExtendedConditionSQL2
        ,  @c_ExtendedConditionSQL3 = @c_ExtendedConditionSQL3
        ,  @c_StocktakeParm2SQL = @c_StocktakeParm2SQL OUTPUT
        ,  @c_StocktakeParm2OtherSQL = @c_StocktakeParm2OtherSQL OUTPUT
    --(Wan06) - END


    UPDATE StockTakeSheetParameters
    SET FinalizeStage = 0,
        PopulateStage = 0,
        CountType = 'UCC'       -- (james02)
    WHERE StockTakeKey = @c_StockTakeKey

    IF RTRIM(@c_WithQuantity) = '' OR @c_WithQuantity IS NULL
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
        LOC.CCLogicalLoc,
        SPACE(20) as UccNo
    INTO #RESULT
    FROM  LOTxLOCxID (NOLOCK),
          SKU (NOLOCK),
          LOTATTRIBUTE (NOLOCK),
          LOC (NOLOCK)
    WHERE 1=2

    DECLARE @c_SQL NVARCHAR(max), @c_UccNo NVARCHAR(20)

    IF @c_ExcludeQtyPicked = 'Y' OR @c_ExcludeQtyAllocated = 'Y'
        BEGIN
            IF RTRIM(@c_GroupLottable05) = 'MIN'
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) WHERE Stocktakekey = @c_StockTakeKey)
                        BEGIN
                            SELECT @c_SQL =  'INSERT INTO #RESULT '
                                + 'SELECT SPACE(10) as LOT,LOTxLOCxID.LOC,LOTxLOCxID.ID,LOTxLOCxID.StorerKey,LOTxLOCxID.SKU, '
                                + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, MIN(LOTATTRIBUTE.Lottable05),'
                                + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                                + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                                --(Wan03) - START
                                --+ 'Qty = CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(MIN(UCC.Qty),0) ELSE SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated) END, '
                                + 'Qty = CASE WHEN LOC.LOSEUCC = ''0'' THEN ISNULL(MIN(UCC.Qty),0) ELSE '
                                + CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked'+ @c_PickDetailQtySubtractQuery + ' ) '
                                       WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated) '
                                       WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyPicked'+ @c_PickDetailQtySubtractQuery + ' ) '
                                                 END
                                + ' END, '
                                --(Wan03) - END
                                + 'LOC.PutawayZone,LOC.LocLevel,Aisle = LOC.locAisle,LOC.Facility, '
                                + 'LOC.CCLogicalLoc, '
                                --          + 'CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" '
                                --          + '     WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN "" ELSE ISNULL(UCC.UccNo,"") END as UCCNo '
                                + 'CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(UCC.UccNo,"") ELSE "" END as UCCNo '  -- (james02)
                                + 'FROM LOTxLOCxID (NOLOCK) '
                                + 'JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Loc = SKUxLOC.Loc '
                                + 'AND LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND LOTxLOCxID.SKU = SKUxLOC.SKU '
                                + 'JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc  '
                                + @c_PickDetailJoinQuery
                                + 'LEFT OUTER JOIN UCC (NOLOCK) ON LOTxLOCxID.StorerKey = UCC.StorerKey '
                                + 'AND LOTxLOCxID.Sku = UCC.Sku '
                                + 'AND LOTxLOCxID.Lot = UCC.Lot '
                                + 'AND LOTxLOCxID.Loc = UCC.Loc '
                                + 'AND LOTxLOCxID.Id = UCC.Id '
                                + 'AND UCC.Status BETWEEN "1" AND "2" '-- (james01)
                                --+ 'AND UCC.Status < "4" '
                                --          + 'AND 1 = CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN 2 '
                                --          + '             WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN 2 ELSE 1 END '
                                + 'AND 1 = CASE WHEN LOC.LOSEUCC = "0" THEN 1 ELSE 2 END '   -- (james02)
                                + 'JOIN SKU (NOLOCK) ON LOTxLOCxID.StorerKey = SKU.StorerKey '
                                + 'AND LOTxLOCxID.Sku = SKU.Sku '
                                + 'JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.Lot = LOTATTRIBUTE.Lot '
                                --(Wan03) - START
                                --+ 'WHERE LOTxLOCxID.Qty > 0 '
                                + 'WHERE CASE WHEN LOC.LOSEUCC = ''0'' THEN LOTxLOCxID.Qty ELSE '
                                + CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked '+ @c_PickDetailQtySubtractQuery
                                       WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated '
                                       WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.QtyPicked '+ @c_PickDetailQtySubtractQuery 
                                    END
                                + ' END > 0 '
                                --(Wan03) - END
                                + 'AND   LOC.Facility = N''' + ISNULL(RTRIM(@c_Facility), '') + ''' '
                                + ISNULL(RTRIM(@c_StorerSQL), '') + ' ' + ISNULL(RTRIM(@c_StorerSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_ZoneSQL), '') + ' ' + ISNULL(RTRIM(@c_ZoneSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_AisleSQL), '') + ' ' + ISNULL(RTRIM(@c_AisleSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_LevelSQL), '') + ' ' + ISNULL(RTRIM(@c_LevelSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_HostWHCodeSQL), '') + ' ' + ISNULL(RTRIM(@c_HostWHCodeSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_SKUSQL), '') + ' ' + ISNULL(RTRIM(@c_SKUSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_AgencySQL), '') + ' ' + ISNULL(RTRIM(@c_AgencySQL2), '') + ' '
                                + ISNULL(RTRIM(@c_ABCSQL), '') + ' ' + ISNULL(RTRIM(@c_ABCSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_SkuGroupSQL), '') + ' ' + ISNULL(RTRIM(@c_SkuGroupSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm1SQL2), '') + ' '  --(Wan02)
                                + ISNULL(RTRIM(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm2SQL2), '') + ' '  --(Wan02)
                                + ISNULL(RTRIM(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm3SQL2), '') + ' '  --(Wan02)
                                + RTRIM(@c_StrategySQL) + ' '                                                                   --(Wan04)
                                + 'GROUP BY LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, LOTxLOCxID.SKU,'
                                + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04,'
                                + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                                + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                                + 'LOC.PutawayZone,LOC.LocLevel,LOC.locAisle, LOC.Facility, LOC.CCLogicalLoc, UCC.UccNo, '
                                + 'LOC.LOSEUCC, '  --(Wan01)
                                --          + 'LOC.LocationType, LOC.LocationCategory, CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" ELSE ISNULL(UCC.UccNo,"") END '
                                + 'LOC.LocationType, LOC.LocationCategory, CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(UCC.UccNo,"") ELSE "" END ' -- (james02)
                                + 'Order By LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, LOTxLOCxID.sku '
                        END
                    ELSE
                        BEGIN
                            SELECT @c_SQL = N'INSERT INTO #RESULT '
                                + 'SELECT SPACE(10) as LOT,LOTxLOCxID.LOC,LOTxLOCxID.ID,LOTxLOCxID.StorerKey,LOTxLOCxID.SKU, '
                                + 'LOTATTRIBUTE.Lottable01,LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03,LOTATTRIBUTE.Lottable04, MIN(LOTATTRIBUTE.Lottable05) as Lottable05,'
                                + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                                + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                                --(Wan03) - START
                                --+ 'Qty = CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(MIN(UCC.Qty),0) ELSE SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated) END, '
                                + 'Qty = CASE WHEN LOC.LOSEUCC = ''0'' THEN ISNULL(MIN(UCC.Qty),0) ELSE '
                                + CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked'+ @c_PickDetailQtySubtractQuery + ' ) '
                                       WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated) '
                                       WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyPicked'+ @c_PickDetailQtySubtractQuery + ' ) '
                                                END
                                + ' END, '
                                --(Wan03) - END
                                + 'LOC.PutawayZone,LOC.LocLevel,Aisle = LOC.locAisle,LOC.Facility, '
                                + 'LOC.CCLogicalLoc, '
                                --          + 'CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" '
                                --          + '     WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN "" ELSE ISNULL(UCC.UccNo,"") END as UCCNo '
                                + 'CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(UCC.UccNo,"") ELSE "" END as UCCNo '     -- (james02)
                                + 'FROM LOTxLOCxID (NOLOCK) '
                                + 'JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Loc = SKUxLOC.Loc '
                                + 'AND LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND LOTxLOCxID.SKU = SKUxLOC.SKU '
                                + 'JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc  '
                                + @c_PickDetailJoinQuery
                                + 'LEFT OUTER JOIN UCC (NOLOCK) ON LOTxLOCxID.StorerKey = UCC.StorerKey '
                                + '         AND LOTxLOCxID.Sku = UCC.Sku '
                                + '         AND LOTxLOCxID.Lot = UCC.Lot '
                                + '         AND LOTxLOCxID.Loc = UCC.Loc '
                                + '         AND LOTxLOCxID.Id = UCC.Id '
                                + '         AND UCC.Status BETWEEN "1" AND "2" '-- (james01)
                                --+ '         AND UCC.Status < "4" '
                                --          + '         AND 1 = CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN 2 '
                                --          + '                      WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN 2 ELSE 1 END '
                                + 'AND 1 = CASE WHEN LOC.LOSEUCC = "0" THEN 1 ELSE 2 END '  -- (james02)
                                + 'JOIN SKU (NOLOCK) ON LOTxLOCxID.StorerKey = SKU.StorerKey AND LOTxLOCxID.Sku = SKU.Sku '
                                + 'JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.Lot = LOTATTRIBUTE.Lot '

                            --(Wan06) - START
                            SET @c_sql = @c_sql + @c_StocktakeParm2SQL
                            SET @c_sqlOther = @c_sqlOther + @c_StocktakeParm2OtherSQL
                            /*
                            IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK)
                                           WHERE Stocktakekey = @c_StockTakeKey
                                           AND   UPPER(Tablename) = 'SKU')
                            BEGIN
                               SELECT @c_SQLOther = @c_SQLOther + ' '
                                              + ISNULL(RTRIM(@c_SKUSQL), '') + ' ' + ISNULL(RTRIM(@c_SKUSQL2), '') + ' '
                                              + ISNULL(RTRIM(@c_AgencySQL), '') + ' ' + ISNULL(RTRIM(@c_AgencySQL2), '') + ' '
                                              + ISNULL(RTRIM(@c_ABCSQL), '') + ' ' + ISNULL(RTRIM(@c_ABCSQL2), '') + ' '
                                              + ISNULL(RTRIM(@c_SkuGroupSQL), '') + ' ' + ISNULL(RTRIM(@c_SkuGroupSQL2), '') + ' '
                               --(Wan02) - START
                               IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'sku'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
                                                  + ' '
                               END

                               IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'sku'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                                                  + ' '
                               END

                               IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'sku'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')
                                                  + ' '
                               END
                               --(Wan02) - END
                            END
                            ELSE
                            BEGIN
                               SELECT @c_SQL = @c_SQL + ' '
                                              + 'JOIN STOCKTAKEPARM2 PARM2_SKU WITH (NOLOCK) '
                                              + ' ON PARM2_SKU.Storerkey = LOTxLOCxID.Storerkey '
                                              + 'AND RTRIM(dbo.fnc_LTrim(PARM2_SKU.Value)) = LOTxLOCxID.SKU '
                                              + 'AND UPPER(PARM2_SKU.Tablename) = ''SKU'' '
                                              + 'AND PARM2_SKU.Stocktakekey = N''' + ISNULL(RTRIM(@c_StockTakeKey), '') + ''''
                            END

                            IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK)
                                           WHERE Stocktakekey = @c_StockTakeKey
                                           AND   UPPER(Tablename) = 'LOC')
                            BEGIN
                               SELECT @c_SQLOther = @c_SQLOther + ' '
                                              + ISNULL(RTRIM(@c_ZoneSQL), '') + ' ' + ISNULL(RTRIM(@c_ZoneSQL2), '') + ' '
                                              + ISNULL(RTRIM(@c_AisleSQL), '') + ' ' + ISNULL(RTRIM(@c_AisleSQL2), '') + ' '
                                              + ISNULL(RTRIM(@c_LevelSQL), '') + ' ' + ISNULL(RTRIM(@c_LevelSQL2), '') + ' '
                                              + ISNULL(RTRIM(@c_HostWHCodeSQL), '') + ' ' + ISNULL(RTRIM(@c_HostWHCodeSQL2), '') + ' '

                               --(Wan02) - START
                               IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'loc'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
                                                  + ' '
                               END

                               IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'loc'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                                                  + ' '
                               END

                               IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'loc'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')
                                                  + ' '
                               END
                               --(Wan02) - END
                            END
                            ELSE
                            BEGIN
                               SELECT @c_SQL = @c_SQL + ' '
                                              + 'JOIN STOCKTAKEPARM2 PARM2_LOC WITH (NOLOCK) '
                                              + ' ON RTRIM(dbo.fnc_LTrim(PARM2_LOC.Value)) = LOTxLOCxID.LOC '
                                              + 'AND UPPER(PARM2_LOC.Tablename) = ''LOC'' '
                                              + 'AND PARM2_LOC.Stocktakekey = N''' + ISNULL(RTRIM(@c_StockTakeKey), '') + ''''
                            END

                            --(Wan02) - START
                            IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                               SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'lotattribute'
                            BEGIN
                               SET @c_sqlOther = @c_sqlOther + ' '
                                                 + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
                                                 + ' '
                            END

                            IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                               SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'lotattribute'
                            BEGIN
                               SET @c_sqlOther = @c_sqlOther + ' '
                                                 + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                                                 + ' '
                            END

                            IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                               SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'lotattribute'
                            BEGIN
                               SET @c_sqlOther = @c_sqlOther + ' '
                                                 + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')
                                                 + ' '
                            END
                            --(Wan02) - END
                            */
                            --(Wan06) - END
                            SELECT @c_SQLWhere = ' '
                                --(Wan03) - START
                                --+ 'WHERE LOTxLOCxID.Qty > 0 '
                                + 'WHERE CASE WHEN LOC.LOSEUCC = ''0'' THEN LOTxLOCxID.Qty ELSE '
                                + CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked '+ @c_PickDetailQtySubtractQuery
                                       WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated '
                                       WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.QtyPicked '+ @c_PickDetailQtySubtractQuery
                                                     END
                                + ' END > 0 '
                                --(Wan03) - END
                                + 'AND   LOC.Facility = N''' + ISNULL(RTRIM(@c_Facility), '') + ''' '
                                + ISNULL(RTRIM(@c_StorerSQL), '') + ' ' + ISNULL(RTRIM(@c_StorerSQL2), '') + ' '
                                + RTRIM(@c_StrategySQL) + ' '                                           --(Wan04)
                            SELECT @c_SQLGroup = ' '
                                + 'GROUP BY LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, LOTxLOCxID.sku,'
                                + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04,'
                                + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                                + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                                + 'LOC.PutawayZone,LOC.LocLevel,LOC.locAisle, LOC.Facility, LOC.CCLogicalLoc, UCC.UccNo, '
                                + 'LOC.LOSEUCC, '  --(Wan01)
                                --                         + 'LOC.LocationType, LOC.LocationCategory, CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" ELSE ISNULL(UCC.UccNo,"") END '
                                + 'LOC.LocationType, LOC.LocationCategory, CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(UCC.UccNo,"") ELSE "" END '    -- (james02)
                                + 'Order BY LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, LOTxLOCxID.sku '

                            SELECT @c_sql = @c_sql + ' ' + @c_sqlWhere + ' ' + @c_sqlOther + ' ' + @c_sqlGroup
                        END
                END
            ELSE IF RTRIM(@c_GroupLottable05) = 'MAX'
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) WHERE Stocktakekey = @c_StockTakeKey)
                        BEGIN
                            SELECT @c_SQL = 'INSERT INTO #RESULT '
                                + 'SELECT SPACE(10) as LOT,LOTxLOCxID.LOC,LOTxLOCxID.ID,LOTxLOCxID.StorerKey, LOTxLOCxID.SKU,'
                                + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, MAX(LOTATTRIBUTE.Lottable05) as Lottable05, '
                                + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                                + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                                --(Wan03) - START
                                --+ 'Qty = CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(MIN(UCC.Qty),0) ELSE SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated) END, '
                                + 'Qty = CASE WHEN LOC.LOSEUCC = ''0'' THEN ISNULL(MIN(UCC.Qty),0) ELSE '
                                + CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked'+ @c_PickDetailQtySubtractQuery + ' ) '
                                       WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated) '
                                       WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyPicked'+ @c_PickDetailQtySubtractQuery + ' ) '
                                    END
                                + ' END, '
                                --(Wan03) - END
                                + 'LOC.PutawayZone,LOC.LocLevel,Aisle = LOC.locAisle,LOC.Facility, '
                                + 'LOC.CCLogicalLoc, '
                                --          + 'CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" '
                                --          + '     WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN "" ELSE ISNULL(UCC.UccNo,"") END as UCCNo '
                                + 'CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(UCC.UccNo,"") ELSE "" END as UCCNo '  -- (james02)
                                + 'FROM LOTxLOCxID (NOLOCK) '
                                + 'JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Loc = SKUxLOC.Loc '
                                + 'AND LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND LOTxLOCxID.SKU = SKUxLOC.SKU '
                                + 'JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc  '
                                + @c_PickDetailJoinQuery
                                + 'LEFT OUTER JOIN UCC (NOLOCK) ON LOTxLOCxID.StorerKey = UCC.StorerKey '
                                + 'AND LOTxLOCxID.Sku = UCC.Sku '
                                + 'AND LOTxLOCxID.Lot = UCC.Lot '
                                + 'AND LOTxLOCxID.Loc = UCC.Loc '
                                + 'AND LOTxLOCxID.Id = UCC.Id '
                                + 'AND UCC.Status BETWEEN "1" AND "2" '-- (james01)
                                --+ 'AND UCC.Status < "4" '
                                --          + 'AND 1 = CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN 2 '
                                --          + '             WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN 2 ELSE 1 END '
                                + 'AND 1 = CASE WHEN LOC.LOSEUCC = "0" THEN 1 ELSE 2 END '  -- (james02)
                                + 'JOIN SKU (NOLOCK) ON LOTxLOCxID.StorerKey = SKU.StorerKey '
                                + 'AND LOTxLOCxID.Sku = SKU.Sku '
                                + 'JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.Lot = LOTATTRIBUTE.Lot '
                                --(Wan03) - START
                                --+ 'WHERE LOTxLOCxID.Qty > 0 '
                                + 'WHERE CASE WHEN LOC.LOSEUCC = ''0'' THEN LOTxLOCxID.Qty ELSE '
                                + CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked '+ @c_PickDetailQtySubtractQuery
                                       WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated '
                                       WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.QtyPicked '+ @c_PickDetailQtySubtractQuery
                                                END
                                + ' END > 0 '
                                --(Wan03) - END
                                + 'AND   LOC.Facility = N''' + ISNULL(RTRIM(@c_Facility), '') + ''' '
                                + ISNULL(RTRIM(@c_StorerSQL), '') + ' ' + ISNULL(RTRIM(@c_StorerSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_ZoneSQL), '') + ' ' + ISNULL(RTRIM(@c_ZoneSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_AisleSQL), '') + ' ' + ISNULL(RTRIM(@c_AisleSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_LevelSQL), '') + ' ' + ISNULL(RTRIM(@c_LevelSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_HostWHCodeSQL), '') + ' ' + ISNULL(RTRIM(@c_HostWHCodeSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_SKUSQL), '') + ' ' + ISNULL(RTRIM(@c_SKUSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_AgencySQL), '') + ' ' + ISNULL(RTRIM(@c_AgencySQL2), '') + ' '
                                + ISNULL(RTRIM(@c_ABCSQL), '') + ' ' + ISNULL(RTRIM(@c_ABCSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_SkuGroupSQL), '') + ' ' + ISNULL(RTRIM(@c_SkuGroupSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm1SQL2), '') + ' '  --(Wan02)
                                + ISNULL(RTRIM(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm2SQL2), '') + ' '  --(Wan02)
                                + ISNULL(RTRIM(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm3SQL2), '') + ' '  --(Wan02)
                                + RTRIM(@c_StrategySQL) + ' '                                                                   --(Wan04)
                                + 'GROUP BY LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, LOTxLOCxID.sku,'
                                + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04,'
                                + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                                + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                                + 'LOC.PutawayZone,LOC.LocLevel,LOC.locAisle, LOC.Facility, LOC.CCLogicalLoc, UCC.UccNo, '
                                + 'LOC.LOSEUCC, '  --(Wan01)
                                --          + 'LOC.LocationType, LOC.LocationCategory, CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" ELSE ISNULL(UCC.UccNo,"") END '
                                + 'LOC.LocationType, LOC.LocationCategory, CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(UCC.UccNo,"") ELSE "" END '    -- (james02)
                                + 'Order By LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, LOTxLOCxID.sku '
                            -- Start : SOS66279
                        END
                    ELSE
                        BEGIN
                            SELECT @c_SQL = N'INSERT INTO #RESULT '
                                + 'SELECT SPACE(10) as LOT,LOTxLOCxID.LOC,LOTxLOCxID.ID,LOTxLOCxID.StorerKey, LOTxLOCxID.SKU,'
                                + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, MAX(LOTATTRIBUTE.Lottable05) as Lottable05, '
                                + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                                + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                                --(Wan03) - START
                                --+ 'Qty = CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(MIN(UCC.Qty),0) ELSE SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated) END, '
                                + 'Qty = CASE WHEN LOC.LOSEUCC = ''0'' THEN ISNULL(MIN(UCC.Qty),0) ELSE '
                                + CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked'+ @c_PickDetailQtySubtractQuery + ' ) '
                                       WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated) '
                                       WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyPicked'+ @c_PickDetailQtySubtractQuery +
                                        ' ) '
                                                END
                                + ' END, '
                                --(Wan03) - END
                                + 'LOC.PutawayZone,LOC.LocLevel,Aisle = LOC.locAisle,LOC.Facility, '
                                + 'LOC.CCLogicalLoc, '
                                --          + 'CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" '
                                --          + '     WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN "" ELSE ISNULL(UCC.UccNo,"") END as UCCNo '
                                + 'CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(UCC.UccNo,"") ELSE "" END as UCCNo '  -- (james02)
                                + 'FROM LOTxLOCxID (NOLOCK) '
                                + 'JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Loc = SKUxLOC.Loc AND LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND LOTxLOCxID.SKU = SKUxLOC.SKU '
                                + 'JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc  '
                                + @c_PickDetailJoinQuery
                                + 'LEFT OUTER JOIN UCC (NOLOCK) ON LOTxLOCxID.StorerKey = UCC.StorerKey '
                                + '            AND LOTxLOCxID.Sku = UCC.Sku '
                                + '            AND LOTxLOCxID.Lot = UCC.Lot '
                                + '            AND LOTxLOCxID.Loc = UCC.Loc '
                                + '            AND LOTxLOCxID.Id = UCC.Id '
                                + '            AND UCC.Status BETWEEN "1" AND "2" '-- (james01)
                                --+ '            AND UCC.Status < "4" '
                                --          + '            AND 1 = CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN 2 '
                                --          + '                         WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN 2 ELSE 1 END '
                                + 'AND 1 = CASE WHEN LOC.LOSEUCC = "0" THEN 1 ELSE 2 END '  -- (james02)
                                + 'JOIN SKU (NOLOCK) ON LOTxLOCxID.StorerKey = SKU.StorerKey AND LOTxLOCxID.Sku = SKU.Sku '
                                + 'JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.Lot = LOTATTRIBUTE.Lot '

                            --(Wan06) - START
                            SET @c_sql = @c_sql + @c_StocktakeParm2SQL
                            SET @c_sqlOther = @c_sqlOther + @c_StocktakeParm2OtherSQL
                            /*
                            IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK)
                                           WHERE Stocktakekey = @c_StockTakeKey
                                           AND   UPPER(Tablename) = 'SKU')
                            BEGIN
                               SELECT @c_SQLOther = @c_SQLOther + ' '
                                                 + ISNULL(RTRIM(@c_SKUSQL), '') + ' ' + ISNULL(RTRIM(@c_SKUSQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_AgencySQL), '') + ' ' + ISNULL(RTRIM(@c_AgencySQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_ABCSQL), '') + ' ' + ISNULL(RTRIM(@c_ABCSQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_SkuGroupSQL), '') + ' ' + ISNULL(RTRIM(@c_SkuGroupSQL2), '') + ' '
                               --(Wan02) - START
                               IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'sku'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
                                                  + ' '
                               END

                               IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'sku'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                                                  + ' '
                               END

                               IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'sku'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')
                                                  + ' '
                               END
                               --(Wan02) - END
                            END
                            ELSE
                            BEGIN
                               SELECT @c_SQL = @c_SQL + ' '
                                                 + 'JOIN STOCKTAKEPARM2 PARM2_SKU WITH (NOLOCK) '
                                                 + ' ON PARM2_SKU.Storerkey = LOTxLOCxID.Storerkey '
                                                 + 'AND RTRIM(dbo.fnc_LTrim(PARM2_SKU.Value)) = LOTxLOCxID.SKU '
                                                 + 'AND UPPER(PARM2_SKU.Tablename) = ''SKU'' '
                                                 + 'AND PARM2_SKU.Stocktakekey = N''' + ISNULL(RTRIM(@c_StockTakeKey), '') + ''''
                            END

                            IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK)
                                           WHERE Stocktakekey = @c_StockTakeKey
                                           AND   UPPER(Tablename) = 'LOC')
                            BEGIN
                               SELECT @c_SQLOther = @c_SQLOther + ' '
                                                 + ISNULL(RTRIM(@c_ZoneSQL), '') + ' ' + ISNULL(RTRIM(@c_ZoneSQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_AisleSQL), '') + ' ' + ISNULL(RTRIM(@c_AisleSQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_LevelSQL), '') + ' ' + ISNULL(RTRIM(@c_LevelSQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_HostWHCodeSQL), '') + ' ' + ISNULL(RTRIM(@c_HostWHCodeSQL2), '') + ' '

                               --(Wan02) - START
                               IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'loc'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
                                                  + ' '
                               END

                               IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'loc'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                                                  + ' '
                               END

                               IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'loc'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')
                                                  + ' '
                               END
                               --(Wan02) - END
                            END
                            ELSE
                            BEGIN
                               SELECT @c_SQL = @c_SQL + ' '
                                                 + 'JOIN STOCKTAKEPARM2 PARM2_LOC WITH (NOLOCK) '
                                                 + ' ON RTRIM(dbo.fnc_LTrim(PARM2_LOC.Value)) = LOTxLOCxID.LOC '
                                                 + 'AND UPPER(PARM2_LOC.Tablename) = ''LOC'' '
                                                 + 'AND PARM2_LOC.Stocktakekey = N''' + ISNULL(RTRIM(@c_StockTakeKey), '') + ''''
                            END

                             --(Wan02) - START
                            IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                               SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'lotattribute'
                            BEGIN
                               SET @c_sqlOther = @c_sqlOther + ' '
                                                 + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
                                                 + ' '
                            END

                            IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                               SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'lotattribute'
                            BEGIN
                               SET @c_sqlOther = @c_sqlOther + ' '
                                                 + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                                                 + ' '
                            END

                            IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                               SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'lotattribute'
                            BEGIN
                               SET @c_sqlOther = @c_sqlOther + ' '
                                                 + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')
                                                 + ' '
                            END
                            --(Wan02) - END
                            */
                            --(Wan06) - END
                            SELECT @c_SQLWhere = ' '
                                --(Wan03) - START
                                --+ 'WHERE LOTxLOCxID.Qty > 0 '
                                + 'WHERE CASE WHEN LOC.LOSEUCC = ''0'' THEN LOTxLOCxID.Qty ELSE '
                                + CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked '+ @c_PickDetailQtySubtractQuery
                                       WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated '
                                       WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.QtyPicked '+ @c_PickDetailQtySubtractQuery
                                                     END
                                + ' END > 0 '
                                --(Wan03) - END
                                + 'AND   LOC.Facility = N''' + ISNULL(RTRIM(@c_Facility), '') + ''' '
                                + ISNULL(RTRIM(@c_StorerSQL), '') + ' ' + ISNULL(RTRIM(@c_StorerSQL2), '') + ' '
                                + RTRIM(@c_StrategySQL) + ' '                                        --(Wan04)
                            SELECT @c_SQLGroup = ' '
                                + 'GROUP BY LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, LOTxLOCxID.sku,'
                                + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04,'
                                + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                                + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                                + 'LOC.PutawayZone,LOC.LocLevel,LOC.locAisle, LOC.Facility, LOC.CCLogicalLoc, UCC.UccNo, '
                                + 'LOC.LOSEUCC, '  --(Wan01)
                                --                            + 'LOC.LocationType, LOC.LocationCategory, CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" ELSE ISNULL(UCC.UccNo,"") END '
                                + 'LOC.LocationType, LOC.LocationCategory, CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(UCC.UccNo,"") ELSE "" END '    -- (james02)
                                + 'Order By LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, LOTxLOCxID.sku '

                            SELECT @c_sql = @c_sql + ' ' + @c_sqlWhere + ' ' + @c_sqlOther + ' ' + @c_sqlGroup
                        END
                END
            ELSE
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) WHERE Stocktakekey = @c_StockTakeKey)
                        BEGIN
                            SELECT @c_SQL =  'INSERT INTO #RESULT '
                                + 'SELECT LOTxLOCxID.LOT,LOTxLOCxID.LOC,LOTxLOCxID.ID,LOTxLOCxID.StorerKey,LOTxLOCxID.SKU, '
                                + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, '
                                + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                                + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                                --(Wan03) - START
                                --+ 'Qty = CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(UCC.Qty,0) ELSE LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated END, '
                                + 'Qty = CASE WHEN LOC.LOSEUCC = ''0'' THEN ISNULL(UCC.Qty,0) ELSE '
                                + CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked '+ @c_PickDetailQtySubtractQuery
                                       WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated '
                                       WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.QtyPicked '+ @c_PickDetailQtySubtractQuery
                                                 END
                                + ' END, '
                                --(Wan03) - END
                                + 'LOC.PutawayZone,LOC.LocLevel,Aisle = LOC.locAisle,LOC.Facility, '
                                + 'LOC.CCLogicalLoc, '
                                --          + 'CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" '
                                --          + '     WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN "" ELSE ISNULL(UCC.UccNo,"") END as UCCNo '
                                + 'CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(UCC.UccNo,"") ELSE "" END as UCCNo '  -- (james02)
                                + 'FROM LOTxLOCxID (NOLOCK) '
                                + 'JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Loc = SKUxLOC.Loc '
                                + 'AND LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND LOTxLOCxID.SKU = SKUxLOC.SKU '
                                + 'JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc  '
                                + @c_PickDetailJoinQuery
                                + 'LEFT OUTER JOIN UCC (NOLOCK) ON LOTxLOCxID.StorerKey = UCC.StorerKey '
                                + 'AND LOTxLOCxID.Sku = UCC.Sku '
                                + 'AND LOTxLOCxID.Lot = UCC.Lot '
                                + 'AND LOTxLOCxID.Loc = UCC.Loc '
                                + 'AND LOTxLOCxID.Id = UCC.Id '
                                + 'AND UCC.Status BETWEEN "1" AND "2" '-- (james01)
                                --+ 'AND UCC.Status < "4" '
                                --          + 'AND 1 = CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN 2 '
                                --          + '             WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN 2 ELSE 1 END '
                                + 'AND 1 = CASE WHEN LOC.LOSEUCC = "0" THEN 1 ELSE 2 END '  -- (james02)
                                + 'JOIN SKU (NOLOCK) ON LOTxLOCxID.StorerKey = SKU.StorerKey '
                                + 'AND LOTxLOCxID.Sku = SKU.Sku '
                                + 'JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.Lot = LOTATTRIBUTE.Lot '
                                --(Wan03) - START
                                --+ 'WHERE LOTxLOCxID.Qty > 0 '
                                + 'WHERE CASE WHEN LOC.LOSEUCC = ''0'' THEN LOTxLOCxID.Qty ELSE '
                                + CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked '+ @c_PickDetailQtySubtractQuery
                                       WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated '
                                       WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.QtyPicked '+ @c_PickDetailQtySubtractQuery
                                                 END
                                + ' END > 0 '
                                --(Wan03) - END
                                + 'AND   LOC.Facility = N''' + ISNULL(RTRIM(@c_Facility), '') + ''' '
                                + ISNULL(RTRIM(@c_StorerSQL), '') + ' ' + ISNULL(RTRIM(@c_StorerSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_ZoneSQL), '') + ' ' + ISNULL(RTRIM(@c_ZoneSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_AisleSQL), '') + ' ' + ISNULL(RTRIM(@c_AisleSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_LevelSQL), '') + ' ' + ISNULL(RTRIM(@c_LevelSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_HostWHCodeSQL), '') + ' ' + ISNULL(RTRIM(@c_HostWHCodeSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_SKUSQL), '') + ' ' + ISNULL(RTRIM(@c_SKUSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_AgencySQL), '') + ' ' + ISNULL(RTRIM(@c_AgencySQL2), '') + ' '
                                + ISNULL(RTRIM(@c_ABCSQL), '') + ' ' + ISNULL(RTRIM(@c_ABCSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_SkuGroupSQL), '') + ' ' + ISNULL(RTRIM(@c_SkuGroupSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm1SQL2), '') + ' '  --(Wan02)
                                + ISNULL(RTRIM(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm2SQL2), '') + ' '  --(Wan02)
                                + ISNULL(RTRIM(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm3SQL2), '') + ' '  --(Wan02)
                                + RTRIM(@c_StrategySQL) + ' '                                                                   --(Wan04)
                                + 'Order By LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, LOTxLOCxID.sku '
                        END
                    ELSE
                        BEGIN
                            SELECT @c_SQL = N'INSERT INTO #RESULT '
                                + 'SELECT LOTxLOCxID.LOT,LOTxLOCxID.LOC,LOTxLOCxID.ID,LOTxLOCxID.StorerKey, LOTxLOCxID.SKU,'
                                + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, '
                                + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                                + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                                --(Wan03) - START
                                --+ 'Qty = CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(UCC.Qty,0) ELSE LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated END, '
                                + 'Qty = CASE WHEN LOC.LOSEUCC = ''0'' THEN ISNULL(UCC.Qty,0) ELSE '
                                + CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked '+ @c_PickDetailQtySubtractQuery
                                       WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated '
                                       WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.QtyPicked '+ @c_PickDetailQtySubtractQuery
                                                END
                                + ' END, '
                                --(Wan03) - END
                                + 'LOC.PutawayZone,LOC.LocLevel,Aisle = LOC.locAisle,LOC.Facility, '
                                + 'LOC.CCLogicalLoc, '
                                --          + 'CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" '
                                --          + '     WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN "" ELSE ISNULL(UCC.UccNo,"") END as UCCNo '
                                + 'CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(UCC.UccNo,"") ELSE "" END as UCCNo '  -- (james02)
                                + 'FROM LOTxLOCxID (NOLOCK) '
                                + 'JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Loc = SKUxLOC.Loc AND LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND LOTxLOCxID.SKU = SKUxLOC.SKU '
                                + 'JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc  '
                                + @c_PickDetailJoinQuery
                                + 'LEFT OUTER JOIN UCC (NOLOCK) ON LOTxLOCxID.StorerKey = UCC.StorerKey '
                                + '            AND LOTxLOCxID.Sku = UCC.Sku '
                                + '            AND LOTxLOCxID.Lot = UCC.Lot '
                                + '            AND LOTxLOCxID.Loc = UCC.Loc '
                                + '            AND LOTxLOCxID.Id = UCC.Id '
                                + '            AND UCC.Status BETWEEN "1" AND "2" '-- (james01)
                                --+ '            AND UCC.Status < "4" '
                                --          + '            AND 1 = CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN 2 '
                                --          + '                         WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN 2 ELSE 1 END '
                                + 'AND 1 = CASE WHEN LOC.LOSEUCC = "0" THEN 1 ELSE 2 END '  -- (james02)
                                + 'JOIN SKU (NOLOCK) ON LOTxLOCxID.StorerKey = SKU.StorerKey AND  LOTxLOCxID.Sku = SKU.Sku '
                                + 'JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.Lot = LOTATTRIBUTE.Lot '

                            --(Wan06) - START
                            SET @c_sql = @c_sql + @c_StocktakeParm2SQL
                            SET @c_sqlOther = @c_sqlOther + @c_StocktakeParm2OtherSQL
                            /*
                            IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK)
                                           WHERE Stocktakekey = @c_StockTakeKey
                                           AND   UPPER(Tablename) = 'SKU')
                            BEGIN
                               SELECT @c_SQLOther = @c_SQLOther + ' '
                                                 + ISNULL(RTRIM(@c_SKUSQL), '') + ' ' + ISNULL(RTRIM(@c_SKUSQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_AgencySQL), '') + ' ' + ISNULL(RTRIM(@c_AgencySQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_ABCSQL), '') + ' ' + ISNULL(RTRIM(@c_ABCSQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_SkuGroupSQL), '') + ' ' + ISNULL(RTRIM(@c_SkuGroupSQL2), '') + ' '
                               --(Wan02) - START
                               IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'sku'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
                                                  + ' '
                               END

                               IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'sku'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                                                  + ' '
                               END

                               IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'sku'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')
                                                  + ' '
                               END
                               --(Wan02) - END
                            END
                            ELSE
                            BEGIN
                               SELECT @c_SQL = @c_SQL + ' '
                                                 + 'JOIN STOCKTAKEPARM2 PARM2_SKU WITH (NOLOCK) '
                                                 + ' ON PARM2_SKU.Storerkey = LOTxLOCxID.Storerkey '
                                                 + 'AND RTRIM(dbo.fnc_LTrim(PARM2_SKU.Value)) = LOTxLOCxID.SKU '
                                                 + 'AND UPPER(PARM2_SKU.Tablename) = ''SKU'' '
                                                 + 'AND PARM2_SKU.Stocktakekey = ''' + ISNULL(RTRIM(@c_StockTakeKey), '') + ''''
                            END

                            IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK)
                                           WHERE Stocktakekey = @c_StockTakeKey
                                           AND   UPPER(Tablename) = 'LOC')
                            BEGIN
                               SELECT @c_SQLOther = @c_SQLOther + ' '
                                                 + ISNULL(RTRIM(@c_ZoneSQL), '') + ' ' + ISNULL(RTRIM(@c_ZoneSQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_AisleSQL), '') + ' ' + ISNULL(RTRIM(@c_AisleSQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_LevelSQL), '') + ' ' + ISNULL(RTRIM(@c_LevelSQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_HostWHCodeSQL), '') + ' ' + ISNULL(RTRIM(@c_HostWHCodeSQL2), '') + ' '
                               --(Wan02) - START
                               IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'loc'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
                                                  + ' '
                               END

                               IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'loc'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                                                  + ' '
                               END

                               IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'loc'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')
                                                  + ' '
                               END
                               --(Wan02) - END
                            END
                            ELSE
                            BEGIN
                               SELECT @c_SQL = @c_SQL + ' '
                                                 + 'JOIN STOCKTAKEPARM2 PARM2_LOC WITH (NOLOCK) '
                                                 + ' ON RTRIM(dbo.fnc_LTrim(PARM2_LOC.Value)) = LOTxLOCxID.LOC '
                                                 + 'AND UPPER(PARM2_LOC.Tablename) = ''LOC'' '
                                                 + 'AND PARM2_LOC.Stocktakekey = ''' + ISNULL(RTRIM(@c_StockTakeKey), '') + ''''
                            END

                            --(Wan02) - START
                            IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                               SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'lotattribute'
                            BEGIN
                               SET @c_sqlOther = @c_sqlOther + ' '
                                                 + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
                                                 + ' '
                            END

                            IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                               SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'lotattribute'
                            BEGIN
                               SET @c_sqlOther = @c_sqlOther + ' '
                                                 + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                                                 + ' '
                            END

                            IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                               SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'lotattribute'
                            BEGIN
                               SET @c_sqlOther = @c_sqlOther + ' '
                                                 + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')
                                                 + ' '
                            END
                            --(Wan02) - END
                            */
                            --(Wan06) - END
                            SELECT @c_SQLWhere = ' '
                                --(Wan03) - START
                                --+ 'WHERE LOTxLOCxID.Qty > 0 '
                                + 'WHERE CASE WHEN LOC.LOSEUCC = ''0'' THEN LOTxLOCxID.Qty ELSE '
                                + CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked '+ @c_PickDetailQtySubtractQuery
                                       WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated '
                                       WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.QtyPicked '+ @c_PickDetailQtySubtractQuery
                                                     END
                                + ' END > 0 '
                                --(Wan03) - END
                                + 'AND   LOC.Facility = N''' + ISNULL(RTRIM(@c_Facility), '') + ''' '
                                + ISNULL(RTRIM(@c_StorerSQL), '') + ' ' + ISNULL(RTRIM(@c_StorerSQL2), '') + ' '
                                + RTRIM(@c_StrategySQL) + ' '                                          --(Wan04)

                            SELECT @c_SQLGroup = ' '
                                + 'Order By LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, LOTxLOCxID.sku '

                            SELECT @c_sql = @c_sql + ' ' + @c_sqlWhere + ' ' + @c_sqlOther + ' ' + @c_sqlGroup
                        END
                    -- End : SOS66279
                END

        END   -- end for @c_ExcludeQtyPicked OR c_ExcludeQtyAllocated
    ELSE
        BEGIN
            IF RTRIM(@c_GroupLottable05) = 'MIN'
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) WHERE Stocktakekey = @c_StockTakeKey)
                        BEGIN

                            SELECT @c_SQL =  'INSERT INTO #RESULT '
                                + 'SELECT SPACE(10) as LOT,LOTxLOCxID.LOC,LOTxLOCxID.ID,LOTxLOCxID.StorerKey, LOTxLOCxID.SKU,'
                                + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, MIN(LOTATTRIBUTE.Lottable05) as Lottable05, '
                                + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                                + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                                + 'Qty = CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(MIN(UCC.Qty),0) ELSE SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked) END, '
                                + 'LOC.PutawayZone,LOC.LocLevel,Aisle = LOC.locAisle,LOC.Facility, '
                                + 'LOC.CCLogicalLoc, '
                                --          + 'CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" '
                                --          + '     WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN "" ELSE ISNULL(UCC.UccNo,"") END as UCCNo '
                                + 'CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(UCC.UccNo,"") ELSE "" END as UCCNo '  -- (james02)
                                + 'FROM LOTxLOCxID (NOLOCK) '
                                + 'JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Loc = SKUxLOC.Loc '
                                + 'AND LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND LOTxLOCxID.SKU = SKUxLOC.SKU '
                                + 'JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc  '
                                + 'LEFT OUTER JOIN UCC (NOLOCK) ON LOTxLOCxID.StorerKey = UCC.StorerKey '
                                + 'AND LOTxLOCxID.Sku = UCC.Sku '
                                + 'AND LOTxLOCxID.Lot = UCC.Lot '
                                + 'AND LOTxLOCxID.Loc = UCC.Loc '
                                + 'AND LOTxLOCxID.Id = UCC.Id '
                                + 'AND UCC.Status BETWEEN "1" AND "2" '-- (james01)
                                --+ 'AND UCC.Status < "4" '
                                --          + 'AND 1 = CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN 2 '
                                --          + '             WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN 2 ELSE 1 END '
                                + 'AND 1 = CASE WHEN LOC.LOSEUCC = "0" THEN 1 ELSE 2 END '   -- (james02)
                                + 'JOIN SKU (NOLOCK) ON LOTxLOCxID.StorerKey = SKU.StorerKey '
                                + 'AND LOTxLOCxID.Sku = SKU.Sku '
                                + 'JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.Lot = LOTATTRIBUTE.Lot '
                                + 'WHERE LOTxLOCxID.Qty > 0 '
                                + 'AND   LOC.Facility = N''' + ISNULL(RTRIM(@c_Facility), '') + ''' '
                                + ISNULL(RTRIM(@c_StorerSQL), '') + ' ' + ISNULL(RTRIM(@c_StorerSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_ZoneSQL), '') + ' ' + ISNULL(RTRIM(@c_ZoneSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_AisleSQL), '') + ' ' + ISNULL(RTRIM(@c_AisleSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_LevelSQL), '') + ' ' + ISNULL(RTRIM(@c_LevelSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_HostWHCodeSQL), '') + ' ' + ISNULL(RTRIM(@c_HostWHCodeSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_SKUSQL), '') + ' ' + ISNULL(RTRIM(@c_SKUSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_AgencySQL), '') + ' ' + ISNULL(RTRIM(@c_AgencySQL2), '') + ' '
                                + ISNULL(RTRIM(@c_ABCSQL), '') + ' ' + ISNULL(RTRIM(@c_ABCSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_SkuGroupSQL), '') + ' ' + ISNULL(RTRIM(@c_SkuGroupSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm1SQL2), '') + ' '  --(Wan02)
                                + ISNULL(RTRIM(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm2SQL2), '') + ' '  --(Wan02)
                                + ISNULL(RTRIM(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm3SQL2), '') + ' '  --(Wan02)
                                + RTRIM(@c_StrategySQL) + ' '                                                                   --(Wan04)
                                + 'GROUP BY LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, LOTxLOCxID.sku,'
                                + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04,'
                                + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                                + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                                + 'LOC.PutawayZone,LOC.LocLevel,LOC.locAisle, LOC.Facility, LOC.CCLogicalLoc, UCC.UccNo, '
                                + 'LOC.LOSEUCC, '  --(Wan01)
                                --          + 'LOC.LocationType, LOC.LocationCategory, CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" ELSE ISNULL(UCC.UccNo,"") END '
                                + 'LOC.LocationType, LOC.LocationCategory, CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(UCC.UccNo,"") ELSE "" END ' -- (james02)
                                + 'Order By LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, LOTxLOCxID.sku '
                        END
                    ELSE
                        BEGIN
                            SELECT @c_SQL = N'INSERT INTO #RESULT '
                                + 'SELECT SPACE(10) as LOT,LOTxLOCxID.LOC,LOTxLOCxID.ID,LOTxLOCxID.StorerKey, LOTxLOCxID.SKU,'
                                + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, MIN(LOTATTRIBUTE.Lottable05) as Lottable05, '
                                + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                                + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                                + 'Qty = CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(MIN(UCC.Qty),0) ELSE SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked) END, '
                                + 'LOC.PutawayZone,LOC.LocLevel,Aisle = LOC.locAisle,LOC.Facility, '
                                + 'LOC.CCLogicalLoc, '
                                --          + 'CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" '
                                --          + '     WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN "" ELSE ISNULL(UCC.UccNo,"") END as UCCNo '
                                + 'CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(UCC.UccNo,"") ELSE "" END as UCCNo '     -- (james02)
                                + 'FROM LOTxLOCxID (NOLOCK) '
                                + 'JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Loc = SKUxLOC.Loc '
                                + 'AND LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND LOTxLOCxID.SKU = SKUxLOC.SKU '
                                + 'JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc  '
                                + 'LEFT OUTER JOIN UCC (NOLOCK) ON LOTxLOCxID.StorerKey = UCC.StorerKey '
                                + '         AND LOTxLOCxID.Sku = UCC.Sku '
                                + '         AND LOTxLOCxID.Lot = UCC.Lot '
                                + '         AND LOTxLOCxID.Loc = UCC.Loc '
                                + '         AND LOTxLOCxID.Id = UCC.Id '
                                + '         AND UCC.Status BETWEEN "1" AND "2" '-- (james01)
                                --+ '         AND UCC.Status < "4" '
                                --          + '         AND 1 = CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN 2 '
                                --          + '                      WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN 2 ELSE 1 END '
                                + 'AND 1 = CASE WHEN LOC.LOSEUCC = "0" THEN 1 ELSE 2 END '  -- (james02)
                                + 'JOIN SKU (NOLOCK) ON LOTxLOCxID.StorerKey = SKU.StorerKey AND LOTxLOCxID.Sku = SKU.Sku '
                                + 'JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.Lot = LOTATTRIBUTE.Lot '

                            --(Wan06) - START
                            SET @c_sql = @c_sql + @c_StocktakeParm2SQL
                            SET @c_sqlOther = @c_sqlOther + @c_StocktakeParm2OtherSQL
                            /*
                            IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK)
                                           WHERE Stocktakekey = @c_StockTakeKey
                                           AND   UPPER(Tablename) = 'SKU')
                            BEGIN
                               SELECT @c_SQLOther = @c_SQLOther + ' '
                                                 + ISNULL(RTRIM(@c_SKUSQL), '') + ' ' + ISNULL(RTRIM(@c_SKUSQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_AgencySQL), '') + ' ' + ISNULL(RTRIM(@c_AgencySQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_ABCSQL), '') + ' ' + ISNULL(RTRIM(@c_ABCSQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_SkuGroupSQL), '') + ' ' + ISNULL(RTRIM(@c_SkuGroupSQL2), '') + ' '
                               --(Wan02) - START
                               IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'sku'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
                                                  + ' '
                               END

                               IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'sku'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                                                  + ' '
                               END

                               IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'sku'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')
                                                  + ' '
                               END
                               --(Wan02) - END
                            END
                            ELSE
                            BEGIN
                               SELECT @c_SQL = @c_SQL + ' '
                                              + 'JOIN STOCKTAKEPARM2 PARM2_SKU WITH (NOLOCK) '
                                              + ' ON PARM2_SKU.Storerkey = LOTxLOCxID.Storerkey '
                                              + 'AND RTRIM(dbo.fnc_LTrim(PARM2_SKU.Value)) = LOTxLOCxID.SKU '
                                              + 'AND UPPER(PARM2_SKU.Tablename) = ''SKU'' '
                                              + 'AND PARM2_SKU.Stocktakekey = ''' + ISNULL(RTRIM(@c_StockTakeKey), '') + ''''
                            END

                            IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK)
                                           WHERE Stocktakekey = @c_StockTakeKey
                                           AND   UPPER(Tablename) = 'LOC')
                            BEGIN
                               SELECT @c_SQLOther = @c_SQLOther + ' '
                                                 + ISNULL(RTRIM(@c_ZoneSQL), '') + ' ' + ISNULL(RTRIM(@c_ZoneSQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_AisleSQL), '') + ' ' + ISNULL(RTRIM(@c_AisleSQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_LevelSQL), '') + ' ' + ISNULL(RTRIM(@c_LevelSQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_HostWHCodeSQL), '') + ' ' + ISNULL(RTRIM(@c_HostWHCodeSQL2), '') + ' '

                               --(Wan02) - START
                               IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'loc'
                               BEGIN
                               SET @c_SQLOther = @c_SQLOther + ' '
                                               + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
                                               + ' '
                               END

                               IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'loc'
                               BEGIN
                               SET @c_SQLOther = @c_SQLOther + ' '
                                               + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                                               + ' '
                               END

                               IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'loc'
                               BEGIN
                               SET @c_SQLOther = @c_SQLOther + ' '
                                               + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')
                                               + ' '
                               END
                               --(Wan02) - END
                            END
                            ELSE
                            BEGIN
                               SELECT @c_SQL = @c_SQL + ' '
                                              + 'JOIN STOCKTAKEPARM2 PARM2_LOC WITH (NOLOCK) '
                                              + ' ON RTRIM(dbo.fnc_LTrim(PARM2_LOC.Value)) = LOTxLOCxID.LOC '
                                              + 'AND UPPER(PARM2_LOC.Tablename) = ''LOC'' '
                                              + 'AND PARM2_LOC.Stocktakekey = ''' + ISNULL(RTRIM(@c_StockTakeKey), '') + ''''
                            END

                            --(Wan02) - START
                            IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                               SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'lotattribute'
                            BEGIN
                               SET @c_sqlOther = @c_sqlOther + ' '
                                                 + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
                                                 + ' '
                            END

                            IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                               SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'lotattribute'
                            BEGIN
                               SET @c_sqlOther = @c_sqlOther + ' '
                                                 + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                                                 + ' '
                            END

                            IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                               SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'lotattribute'
                            BEGIN
                               SET @c_sqlOther = @c_sqlOther + ' '
                                                 + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')
                                                 + ' '
                            END
                            --(Wan02) - END
                            */
                            --(Wan06) - END
                            SELECT @c_SQLWhere = ' '
                                + 'WHERE LOTxLOCxID.Qty > 0 '
                                + 'AND   LOC.Facility = N''' + ISNULL(RTRIM(@c_Facility), '') + ''' '
                                + ISNULL(RTRIM(@c_StorerSQL), '') + ' ' + ISNULL(RTRIM(@c_StorerSQL2), '') + ' '
                                + RTRIM(@c_StrategySQL) + ' '                                        --(Wan04)
                            SELECT @c_SQLGroup = ' '
                                + 'GROUP BY LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey,LOTxLOCxID.sku, '
                                + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04,'
                                + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                                + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                                + 'LOC.PutawayZone,LOC.LocLevel,LOC.locAisle, LOC.Facility, LOC.CCLogicalLoc, UCC.UccNo, '
                                + 'LOC.LOSEUCC, '  --(Wan01)
                                --                            + 'LOC.LocationType, LOC.LocationCategory, CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" ELSE ISNULL(UCC.UccNo,"") END '
                                + 'LOC.LocationType, LOC.LocationCategory, CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(UCC.UccNo,"") ELSE "" END '    -- (james02)
                                + 'Order BY LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, LOTxLOCxID.sku '

                            SELECT @c_sql = @c_sql + ' ' + @c_sqlWhere + ' ' + @c_sqlOther + ' ' + @c_sqlGroup
                        END
                END
            ELSE IF RTRIM(@c_GroupLottable05) = 'MAX'
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) WHERE Stocktakekey = @c_StockTakeKey)
                        BEGIN
                            SELECT @c_SQL = 'INSERT INTO #RESULT '
                                + 'SELECT SPACE(10) as LOT,LOTxLOCxID.LOC,LOTxLOCxID.ID,LOTxLOCxID.StorerKey,LOTxLOCxID.SKU, '
                                + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, MAX(LOTATTRIBUTE.Lottable05) as Lottable05, '
                                + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                                + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                                + 'Qty = CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(MIN(UCC.Qty),0) ELSE SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked) END, '
                                + 'LOC.PutawayZone,LOC.LocLevel,Aisle = LOC.locAisle,LOC.Facility, '
                                + 'LOC.CCLogicalLoc, '
                                --          + 'CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" '
                                --          + '     WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN "" ELSE ISNULL(UCC.UccNo,"") END as UCCNo '
                                + 'CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(UCC.UccNo,"") ELSE "" END as UCCNo '  -- (james02)
                                + 'FROM LOTxLOCxID (NOLOCK) '
                                + 'JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Loc = SKUxLOC.Loc '
                                + 'AND LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND LOTxLOCxID.SKU = SKUxLOC.SKU '
                                + 'JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc  '
                                + 'LEFT OUTER JOIN UCC (NOLOCK) ON LOTxLOCxID.StorerKey = UCC.StorerKey '
                                + 'AND LOTxLOCxID.Sku = UCC.Sku '
                                + 'AND LOTxLOCxID.Lot = UCC.Lot '
                                + 'AND LOTxLOCxID.Loc = UCC.Loc '
                                + 'AND LOTxLOCxID.Id = UCC.Id '
                                + 'AND UCC.Status BETWEEN "1" AND "2" '-- (james01)
                                --+ 'AND UCC.Status < "4" '
                                --          + 'AND 1 = CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN 2 '
                                --          + '             WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN 2 ELSE 1 END '
                                + 'AND 1 = CASE WHEN LOC.LOSEUCC = "0" THEN 1 ELSE 2 END '  -- (james02)
                                + 'JOIN SKU (NOLOCK) ON LOTxLOCxID.StorerKey = SKU.StorerKey '
                                + 'AND LOTxLOCxID.Sku = SKU.Sku '
                                + 'JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.Lot = LOTATTRIBUTE.Lot '
                                + 'WHERE LOTxLOCxID.Qty > 0 '
                                + 'AND   LOC.Facility = N''' + ISNULL(RTRIM(@c_Facility), '') + ''' '
                                + ISNULL(RTRIM(@c_StorerSQL), '') + ' ' + ISNULL(RTRIM(@c_StorerSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_ZoneSQL), '') + ' ' + ISNULL(RTRIM(@c_ZoneSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_AisleSQL), '') + ' ' + ISNULL(RTRIM(@c_AisleSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_LevelSQL), '') + ' ' + ISNULL(RTRIM(@c_LevelSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_HostWHCodeSQL), '') + ' ' + ISNULL(RTRIM(@c_HostWHCodeSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_SKUSQL), '') + ' ' + ISNULL(RTRIM(@c_SKUSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_AgencySQL), '') + ' ' + ISNULL(RTRIM(@c_AgencySQL2), '') + ' '
                                + ISNULL(RTRIM(@c_ABCSQL), '') + ' ' + ISNULL(RTRIM(@c_ABCSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_SkuGroupSQL), '') + ' ' + ISNULL(RTRIM(@c_SkuGroupSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm1SQL2), '') + ' '  --(Wan02)
                                + ISNULL(RTRIM(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm2SQL2), '') + ' '  --(Wan02)
                                + ISNULL(RTRIM(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm3SQL2), '') + ' '  --(Wan02)
                                + RTRIM(@c_StrategySQL) + ' '                                                                   --(Wan04)
                                + 'GROUP BY LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey,LOTxLOCxID.sku, '
                                + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04,'
                                + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                                + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                                + 'LOC.PutawayZone,LOC.LocLevel,LOC.locAisle, LOC.Facility, LOC.CCLogicalLoc, UCC.UccNo, '
                                + 'LOC.LOSEUCC, '  --(Wan01)
                                --          + 'LOC.LocationType, LOC.LocationCategory, CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" ELSE ISNULL(UCC.UccNo,"") END '
                                + 'LOC.LocationType, LOC.LocationCategory, CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(UCC.UccNo,"") ELSE "" END '    -- (james02)
                                + 'Order By LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, LOTxLOCxID.sku '
                            -- Start : SOS66279
                        END
                    ELSE
                        BEGIN
                            SELECT @c_SQL = N'INSERT INTO #RESULT '
                                + 'SELECT SPACE(10) as LOT,LOTxLOCxID.LOC,LOTxLOCxID.ID,LOTxLOCxID.StorerKey, LOTxLOCxID.SKU,'
                                + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, MAX(LOTATTRIBUTE.Lottable05) as Lottable05, '
                                + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                                + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                                + 'Qty = CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(MIN(UCC.Qty),0) ELSE SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked) END, '
                                + 'LOC.PutawayZone,LOC.LocLevel,Aisle = LOC.locAisle,LOC.Facility, '
                                + 'LOC.CCLogicalLoc, '
                                --          + 'CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" '
                                --          + '     WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN "" ELSE ISNULL(UCC.UccNo,"") END as UCCNo '
                                + 'CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(UCC.UccNo,"") ELSE "" END as UCCNo '  -- (james02)
                                + 'FROM LOTxLOCxID (NOLOCK) '
                                + 'JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Loc = SKUxLOC.Loc AND LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND LOTxLOCxID.SKU = SKUxLOC.SKU '
                                + 'JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc  '
                                + 'LEFT OUTER JOIN UCC (NOLOCK) ON LOTxLOCxID.StorerKey = UCC.StorerKey '
                                + '            AND LOTxLOCxID.Sku = UCC.Sku '
                                + '            AND LOTxLOCxID.Lot = UCC.Lot '
                                + '            AND LOTxLOCxID.Loc = UCC.Loc '
                                + '            AND LOTxLOCxID.Id = UCC.Id '
                                + '            AND UCC.Status BETWEEN "1" AND "2" '-- (james01)
                                --+ '            AND UCC.Status < "4" '
                                --          + '            AND 1 = CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN 2 '
                                --          + '                         WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN 2 ELSE 1 END '
                                + 'AND 1 = CASE WHEN LOC.LOSEUCC = "0" THEN 1 ELSE 2 END '  -- (james02)
                                + 'JOIN SKU (NOLOCK) ON LOTxLOCxID.StorerKey = SKU.StorerKey AND LOTxLOCxID.Sku = SKU.Sku '
                                + 'JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.Lot = LOTATTRIBUTE.Lot '

                            --(Wan06) - START
                            SET @c_sql = @c_sql + @c_StocktakeParm2SQL
                            SET @c_sqlOther = @c_sqlOther + @c_StocktakeParm2OtherSQL
                            /*
                            IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK)
                                           WHERE Stocktakekey = @c_StockTakeKey
                                           AND   UPPER(Tablename) = 'SKU')
                            BEGIN
                               SELECT @c_SQLOther = @c_SQLOther + ' '
                                                 + ISNULL(RTRIM(@c_SKUSQL), '') + ' ' + ISNULL(RTRIM(@c_SKUSQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_AgencySQL), '') + ' ' + ISNULL(RTRIM(@c_AgencySQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_ABCSQL), '') + ' ' + ISNULL(RTRIM(@c_ABCSQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_SkuGroupSQL), '') + ' ' + ISNULL(RTRIM(@c_SkuGroupSQL2), '') + ' '

                               --(Wan02) - START
                               IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'sku'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
                                                  + ' '
                               END

                               IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'sku'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                                                  + ' '
                               END

                               IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'sku'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')
                                                  + ' '
                               END
                               --(Wan02) - END
                            END
                            ELSE
                            BEGIN
                               SELECT @c_SQL = @c_SQL + ' '
                                                 + 'JOIN STOCKTAKEPARM2 PARM2_SKU WITH (NOLOCK) '
                                                 + ' ON PARM2_SKU.Storerkey = LOTxLOCxID.Storerkey '
                                                 + 'AND RTRIM(dbo.fnc_LTrim(PARM2_SKU.Value)) = LOTxLOCxID.SKU '
                                                 + 'AND UPPER(PARM2_SKU.Tablename) = ''SKU'' '
                                                 + 'AND PARM2_SKU.Stocktakekey = N''' + ISNULL(RTRIM(@c_StockTakeKey), '') + ''''
                            END

                            IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK)
                                           WHERE Stocktakekey = @c_StockTakeKey
                                           AND   UPPER(Tablename) = 'LOC')
                            BEGIN
                               SELECT @c_SQLOther = @c_SQLOther + ' '
                                                 + ISNULL(RTRIM(@c_ZoneSQL), '') + ' ' + ISNULL(RTRIM(@c_ZoneSQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_AisleSQL), '') + ' ' + ISNULL(RTRIM(@c_AisleSQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_LevelSQL), '') + ' ' + ISNULL(RTRIM(@c_LevelSQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_HostWHCodeSQL), '') + ' ' + ISNULL(RTRIM(@c_HostWHCodeSQL2), '') + ' '
                               --(Wan02) - START
                               IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'loc'
                               BEGIN
                               SET @c_SQLOther = @c_SQLOther + ' '
                                               + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
                                               + ' '
                               END

                               IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'loc'
                               BEGIN
                               SET @c_SQLOther = @c_SQLOther + ' '
                                               + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                                               + ' '
                               END

                               IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'loc'
                               BEGIN
                               SET @c_SQLOther = @c_SQLOther + ' '
                                               + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')
                                               + ' '
                               END
                               --(Wan02) - END
                            END
                            ELSE
                            BEGIN
                               SELECT @c_SQL = @c_SQL + ' '
                                                 + 'JOIN STOCKTAKEPARM2 PARM2_LOC WITH (NOLOCK) '
                                                 + ' ON RTRIM(dbo.fnc_LTrim(PARM2_LOC.Value)) = LOTxLOCxID.LOC '
                                                 + 'AND UPPER(PARM2_LOC.Tablename) = ''LOC'' '
                                                 + 'AND PARM2_LOC.Stocktakekey = N''' + ISNULL(RTRIM(@c_StockTakeKey), '') + ''''
                            END

                            --(Wan02) - START
                            IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                               SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'lotattribute'
                            BEGIN
                               SET @c_sqlOther = @c_sqlOther + ' '
                                                 + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
                                                 + ' '
                            END

                            IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                               SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'lotattribute'
                            BEGIN
                               SET @c_sqlOther = @c_sqlOther + ' '
                                                 + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                                                 + ' '
                            END

                            IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                               SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'lotattribute'
                            BEGIN
                               SET @c_sqlOther = @c_sqlOther + ' '
                                                 + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')
                                                 + ' '
                            END
                            --(Wan02) - END
                            */
                            --(Wan06) - END

							 SELECT @c_SQLWhere = ' '
                                + 'WHERE LOTxLOCxID.Qty > 0 '
                                + 'AND   LOC.Facility = N''' + ISNULL(RTRIM(@c_Facility), '') + ''' '
                                + ISNULL(RTRIM(@c_StorerSQL), '') + ' ' + ISNULL(RTRIM(@c_StorerSQL2), '') + ' '
                                + RTRIM(@c_StrategySQL) + ' '                                        --(Wan04)
                            SELECT @c_SQLGroup = ' '
                                + 'GROUP BY LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, LOTxLOCxID.sku,'
                                + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04,'
                                + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                                + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                                + 'LOC.PutawayZone,LOC.LocLevel,LOC.locAisle, LOC.Facility, LOC.CCLogicalLoc, UCC.UccNo, '
                                + 'LOC.LOSEUCC, '  --(Wan01)
                                --                            + 'LOC.LocationType, LOC.LocationCategory, CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" ELSE ISNULL(UCC.UccNo,"") END '
                                + 'LOC.LocationType, LOC.LocationCategory, CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(UCC.UccNo,"") ELSE "" END '    -- (james02)
                                + 'Order By LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, LOTxLOCxID.sku '

                            SELECT @c_sql = @c_sql + ' ' + @c_sqlWhere + ' ' + @c_sqlOther + ' ' + @c_sqlGroup
                        END
                END
            ELSE
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) WHERE Stocktakekey = @c_StockTakeKey)
                        BEGIN
                            SELECT @c_SQL =  'INSERT INTO #RESULT '
                                + 'SELECT LOTxLOCxID.LOT,LOTxLOCxID.LOC,LOTxLOCxID.ID,LOTxLOCxID.StorerKey, LOTxLOCxID.SKU,'
                                + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05,'
                                + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                                + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                                + 'Qty = CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(UCC.Qty,0) ELSE LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked END, '
                                + 'LOC.PutawayZone,LOC.LocLevel,Aisle = LOC.locAisle,LOC.Facility, '
                                + 'LOC.CCLogicalLoc, '
                                --          + 'CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" '
                                --          + '     WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN "" ELSE ISNULL(UCC.UccNo,"") END as UCCNo '
                                + 'CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(UCC.UccNo,"") ELSE "" END as UCCNo '  -- (james02)
                                + 'FROM LOTxLOCxID (NOLOCK) '
                                + 'JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Loc = SKUxLOC.Loc '
                                + 'AND LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND LOTxLOCxID.SKU = SKUxLOC.SKU '
                                + 'JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc  '
                                + 'LEFT OUTER JOIN UCC (NOLOCK) ON LOTxLOCxID.StorerKey = UCC.StorerKey '
                                + 'AND LOTxLOCxID.Sku = UCC.Sku '
                                + 'AND LOTxLOCxID.Lot = UCC.Lot '
                                + 'AND LOTxLOCxID.Loc = UCC.Loc '
                                + 'AND LOTxLOCxID.Id = UCC.Id '
                                + 'AND UCC.Status BETWEEN "1" AND "2" '-- (james01)
                                --+ 'AND UCC.Status < "4" '
                                --          + 'AND 1 = CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN 2 '
                                --          + '             WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN 2 ELSE 1 END '
                                + 'AND 1 = CASE WHEN LOC.LOSEUCC = "0" THEN 1 ELSE 2 END '  -- (james02)
                                + 'JOIN SKU (NOLOCK) ON LOTxLOCxID.StorerKey = SKU.StorerKey '
                                + 'AND LOTxLOCxID.Sku = SKU.Sku '
                                + 'JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.Lot = LOTATTRIBUTE.Lot '
                                + 'WHERE LOTxLOCxID.Qty > 0 '
                                + 'AND   LOC.Facility = N''' + ISNULL(RTRIM(@c_Facility), '') + ''' '
                                + ISNULL(RTRIM(@c_StorerSQL), '') + ' ' + ISNULL(RTRIM(@c_StorerSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_ZoneSQL), '') + ' ' + ISNULL(RTRIM(@c_ZoneSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_AisleSQL), '') + ' ' + ISNULL(RTRIM(@c_AisleSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_LevelSQL), '') + ' ' + ISNULL(RTRIM(@c_LevelSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_HostWHCodeSQL), '') + ' ' + ISNULL(RTRIM(@c_HostWHCodeSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_SKUSQL), '') + ' ' + ISNULL(RTRIM(@c_SKUSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_AgencySQL), '') + ' ' + ISNULL(RTRIM(@c_AgencySQL2), '') + ' '
                                + ISNULL(RTRIM(@c_ABCSQL), '') + ' ' + ISNULL(RTRIM(@c_ABCSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_SkuGroupSQL), '') + ' ' + ISNULL(RTRIM(@c_SkuGroupSQL2), '') + ' '
                                + ISNULL(RTRIM(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm1SQL2), '') + ' '  --(Wan02)
                                + ISNULL(RTRIM(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm2SQL2), '') + ' '  --(Wan02)
                                + ISNULL(RTRIM(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm3SQL2), '') + ' '  --(Wan02)
                                + RTRIM(@c_StrategySQL) + ' '                                                                   --(Wan04)
                                + 'Order By LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, LOTxLOCxID.sku '
                        END
                    ELSE
                        BEGIN
                            SELECT @c_SQL = N'INSERT INTO #RESULT '
                                + 'SELECT LOTxLOCxID.LOT,LOTxLOCxID.LOC,LOTxLOCxID.ID,LOTxLOCxID.StorerKey, LOTxLOCxID.SKU,'
                                + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05,'
                                + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                                + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                                + 'Qty = CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(UCC.Qty,0) ELSE LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked END, '
                                + 'LOC.PutawayZone,LOC.LocLevel,Aisle = LOC.locAisle,LOC.Facility, '
                                + 'LOC.CCLogicalLoc, '
                                --          + 'CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN "" '
                                --          + '     WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN "" ELSE ISNULL(UCC.UccNo,"") END as UCCNo '
                                + 'CASE WHEN LOC.LOSEUCC = "0" THEN ISNULL(UCC.UccNo,"") ELSE "" END as UCCNo '  -- (james02)
                                + 'FROM LOTxLOCxID (NOLOCK) '
                                + 'JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Loc = SKUxLOC.Loc AND LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND LOTxLOCxID.SKU = SKUxLOC.SKU '
                                + 'JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc  '
                                + 'LEFT OUTER JOIN UCC (NOLOCK) ON LOTxLOCxID.StorerKey = UCC.StorerKey '
                                + '            AND LOTxLOCxID.Sku = UCC.Sku '
                                + '            AND LOTxLOCxID.Lot = UCC.Lot '
                                + '            AND LOTxLOCxID.Loc = UCC.Loc '
                                + '            AND LOTxLOCxID.Id = UCC.Id '
                                + '            AND UCC.Status BETWEEN "1" AND "2" '-- (james01)
                                --+ '            AND UCC.Status < "4" '
                                --          + '            AND 1 = CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "DYNPICKP", "DYNPPICK") THEN 2 '
                                --          + '                         WHEN LOC.LocationType = "OTHER" AND LOC.LocationCategory IN ("SHELVING", "DECK") THEN 2 ELSE 1 END '
                                + 'AND 1 = CASE WHEN LOC.LOSEUCC = "0" THEN 1 ELSE 2 END '  -- (james02)
                                + 'JOIN SKU (NOLOCK) ON LOTxLOCxID.StorerKey = SKU.StorerKey AND  LOTxLOCxID.Sku = SKU.Sku '
                                + 'JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.Lot = LOTATTRIBUTE.Lot '

                            --(Wan06) - START
                            SET @c_sql = @c_sql + @c_StocktakeParm2SQL
                            SET @c_sqlOther = @c_sqlOther + @c_StocktakeParm2OtherSQL
                            /*
                            IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK)
                                           WHERE Stocktakekey = @c_StockTakeKey
                                           AND   UPPER(Tablename) = 'SKU')
                            BEGIN
                               SELECT @c_SQLOther = @c_SQLOther + ' '
                                                 + ISNULL(RTRIM(@c_SKUSQL), '') + ' ' + ISNULL(RTRIM(@c_SKUSQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_AgencySQL), '') + ' ' + ISNULL(RTRIM(@c_AgencySQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_ABCSQL), '') + ' ' + ISNULL(RTRIM(@c_ABCSQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_SkuGroupSQL), '') + ' ' + ISNULL(RTRIM(@c_SkuGroupSQL2), '') + ' '

                               --(Wan02) - START
                               IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'sku'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
                                                  + ' '
                               END

                               IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'sku'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                                                  + ' '
                               END

                               IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'sku'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')
                                                  + ' '
                               END
                               --(Wan02) - END
                            END
                            ELSE
                            BEGIN
                               SELECT @c_SQL = @c_SQL + ' '
                                                 + 'JOIN STOCKTAKEPARM2 PARM2_SKU WITH (NOLOCK) '
                                                 + ' ON PARM2_SKU.Storerkey = LOTxLOCxID.Storerkey '
                                                 + 'AND RTRIM(dbo.fnc_LTrim(PARM2_SKU.Value)) = LOTxLOCxID.SKU '
                                                 + 'AND UPPER(PARM2_SKU.Tablename) = ''SKU'' '
                                                 + 'AND PARM2_SKU.Stocktakekey = ''' + ISNULL(RTRIM(@c_StockTakeKey), '') + ''''
                            END

                            IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK)
                                           WHERE Stocktakekey = @c_StockTakeKey
                                           AND   UPPER(Tablename) = 'LOC')
                            BEGIN
                               SELECT @c_SQLOther = @c_SQLOther + ' '
                                                 + ISNULL(RTRIM(@c_ZoneSQL), '') + ' ' + ISNULL(RTRIM(@c_ZoneSQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_AisleSQL), '') + ' ' + ISNULL(RTRIM(@c_AisleSQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_LevelSQL), '') + ' ' + ISNULL(RTRIM(@c_LevelSQL2), '') + ' '
                                                 + ISNULL(RTRIM(@c_HostWHCodeSQL), '') + ' ' + ISNULL(RTRIM(@c_HostWHCodeSQL2), '') + ' '
                               --(Wan02) - START
                               IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'loc'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
                                                  + ' '
                               END

                               IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'loc'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                                                  + ' '
                               END

                               IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                                  SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'loc'
                               BEGIN
                                  SET @c_SQLOther = @c_SQLOther + ' '
                                                  + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')
                                                  + ' '
                               END
                               --(Wan02) - END
                            END
                            ELSE
                            BEGIN
                               SELECT @c_SQL = @c_SQL + ' '
                                                 + 'JOIN STOCKTAKEPARM2 PARM2_LOC WITH (NOLOCK) '
                                                 + ' ON RTRIM(dbo.fnc_LTrim(PARM2_LOC.Value)) = LOTxLOCxID.LOC '
                                                 + 'AND UPPER(PARM2_LOC.Tablename) = ''LOC'' '
                                                 + 'AND PARM2_LOC.Stocktakekey = ''' + ISNULL(RTRIM(@c_StockTakeKey), '') + ''''
                            END

                            --(Wan02) - START
                            IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                               SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'lotattribute'
                            BEGIN
                               SET @c_sqlOther = @c_sqlOther + ' '
                                                 + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
                                                 + ' '
                            END

                            IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                               SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'lotattribute'
                            BEGIN
                               SET @c_sqlOther = @c_sqlOther + ' '
                                                 + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                                                 + ' '
                            END

                            IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                               SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'lotattribute'
                            BEGIN
                               SET @c_sqlOther = @c_sqlOther + ' '
                                                 + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')
                                                 + ' '
                            END
                            --(Wan02) - END
                            */
                            --(Wan06) - END
                            SELECT @c_SQLWhere = ' '
                                + 'WHERE LOTxLOCxID.Qty > 0 '
                                + 'AND   LOC.Facility = N''' + ISNULL(RTRIM(@c_Facility), '') + ''' '
                                + ISNULL(RTRIM(@c_StorerSQL), '') + ' ' + ISNULL(RTRIM(@c_StorerSQL2), '') + ' '
                                + RTRIM(@c_StrategySQL) + ' '                                        --(Wan04)
                            SELECT @c_SQLGroup = ' '
                                + 'Order By LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey, LOTxLOCxID.sku '

                            SELECT @c_sql = @c_sql + ' ' + @c_sqlWhere + ' ' + @c_sqlOther + ' ' + @c_sqlGroup
                        END
                    -- End : SOS66279
                END
        END

    IF @b_Debug = 1
        PRINT @C_SQL

    EXEC (@c_sql)

    IF @c_EmptyLocation = 'Y'
        BEGIN
            -- Start : SOS66279
            IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) WHERE Stocktakekey = @c_StockTakeKey)
                BEGIN
                    -- End : SOS66279
                    SELECT @c_SQL =  'INSERT INTO #RESULT '
                        + 'SELECT lot = SPACE(10),loc,id = SPACE(20),StorerKey = SPACE(10),sku = SPACE(20),'
                        + 'Lottable01 = SPACE(18),Lottable02 = SPACE(18),Lottable03 = SPACE(18),Lottable04 = NULL,Lottable05 = NULL,'
                        + 'Lottable06 = SPACE(30), Lottable07 = SPACE(30), Lottable08 = SPACE(30), Lottable09 = SPACE(30), Lottable10 = SPACE(30),'
                        + 'Lottable11 = SPACE(30), Lottable12 = SPACE(30), Lottable13 = NULL, Lottable14 = NULL, Lottable15 = NULL,'
                        + 'Qty = 0,PutawayZone,LocLevel,Aisle = locAisle,Facility,CCLogicalLoc, UccNo = SPACE(20) '
                        + 'FROM LOC (NOLOCK) '
                        + 'WHERE   LOC.Facility = N''' + ISNULL(RTRIM(@c_Facility), '') + ''' '
                        + ISNULL(RTRIM(@c_ZoneSQL), '') + ' ' + ISNULL(RTRIM(@c_ZoneSQL2), '') + ' '
                        + ISNULL(RTRIM(@c_AisleSQL), '') + ' ' + ISNULL(RTRIM(@c_AisleSQL2), '') + ' '
                        + ISNULL(RTRIM(@c_LevelSQL), '') + ' ' + ISNULL(RTRIM(@c_LevelSQL2), '') + ' '
                        + ISNULL(RTRIM(@c_HostWHCodeSQL), '') + ' ' + ISNULL(RTRIM(@c_HostWHCodeSQL2), '') + ' '
                        --+ ISNULL(RTRIM(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm1SQL2), '') + ' '  --(Wan02)
                        --+ ISNULL(RTRIM(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm2SQL2), '') + ' '  --(Wan02)
                        --+ ISNULL(RTRIM(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm3SQL2), '') + ' '  --(Wan02)
                        --(Wan02) - START
                        + CASE WHEN ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                                    SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'loc'
                                   THEN ISNULL(RTRIM(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm1SQL2), '') + ' '
                               ELSE ''
                                         END
                        + CASE WHEN ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                                    SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'loc'
                                   THEN ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '') + ' '
                               ELSE ''
                                         END
                        + CASE WHEN ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                                    SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'loc'
                                   THEN ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '') + ' '
                               ELSE ''
                                         END
                        --(Wan02) - END
                        + RTRIM(@c_StrategyLocSQL) + ' '                                              --(Wan04)
                        + 'AND LOC NOT IN (SELECT DISTINCT LOC FROM #RESULT) '
                    EXEC ( @c_SQL )
                    -- Start : SOS66279
                END
            ELSE
                BEGIN
                    SELECT @c_sqlOther = ''

                    SELECT @c_SQL = N'INSERT INTO #RESULT '
                        + 'SELECT lot = SPACE(10),loc,id = SPACE(20),StorerKey = SPACE(10),sku = SPACE(20),'
                        + 'Lottable01 = SPACE(18),Lottable02 = SPACE(18),Lottable03 = SPACE(18),Lottable04 = NULL,Lottable05 = NULL,'
                        + 'Lottable06 = SPACE(30), Lottable07 = SPACE(30), Lottable08 = SPACE(30), Lottable09 = SPACE(30), Lottable10 = SPACE(30),'
                        + 'Lottable11 = SPACE(30), Lottable12 = SPACE(30), Lottable13 = NULL, Lottable14 = NULL, Lottable15 = NULL,'
                        + 'Qty = 0,PutawayZone,LocLevel,Aisle = locAisle,Facility,CCLogicalLoc, UccNo = SPACE(20) '
                        + 'FROM LOC (NOLOCK) '

                    --(Wan06) - START
                    EXEC ispGetStocktakeParm2
                         @c_StockTakeKey    = @c_StockTakeKey
                        ,  @c_EmptyLocation   = @c_EmptyLocation
                        ,  @c_SkuConditionSQL = @c_SkuConditionSQL
                        ,  @c_LocConditionSQL = @c_LocConditionSQL
                        ,  @c_ExtendedConditionSQL1 = @c_ExtendedConditionSQL1
                        ,  @c_ExtendedConditionSQL2 = @c_ExtendedConditionSQL2
                        ,  @c_ExtendedConditionSQL3 = @c_ExtendedConditionSQL3
                        ,  @c_StocktakeParm2SQL = @c_StocktakeParm2SQL OUTPUT
                        ,  @c_StocktakeParm2OtherSQL = @c_StocktakeParm2OtherSQL OUTPUT

                    SET @c_SQL = @c_SQL + @c_StocktakeParm2SQL
                    SET @c_SQLOther = @c_SQLOther + @c_StocktakeParm2OtherSQL
                    /*
                    IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK)
                                   WHERE Stocktakekey = @c_StockTakeKey
                                   AND   UPPER(Tablename) = 'LOC')
                    BEGIN
                       SELECT @c_SQLOther = @c_SQLOther + ' '
                                         + ISNULL(RTRIM(@c_ZoneSQL), '') + ' ' + ISNULL(RTRIM(@c_ZoneSQL2), '') + ' '
                                         + ISNULL(RTRIM(@c_AisleSQL), '') + ' ' + ISNULL(RTRIM(@c_AisleSQL2), '') + ' '
                                         + ISNULL(RTRIM(@c_LevelSQL), '') + ' ' + ISNULL(RTRIM(@c_LevelSQL2), '') + ' '
                                         + ISNULL(RTRIM(@c_HostWHCodeSQL), '') + ' ' + ISNULL(RTRIM(@c_HostWHCodeSQL2), '') + ' '

                       --(Wan02) - START
                       IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                          SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'loc'
                       BEGIN
                       SET @c_SQLOther = @c_SQLOther + ' '
                                       + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
                                       + ' '
                       END

                       IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                          SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'loc'
                       BEGIN
                       SET @c_SQLOther = @c_SQLOther + ' '
                                       + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                                       + ' '
                       END

                       IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                          SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'loc'
                       BEGIN
                       SET @c_SQLOther = @c_SQLOther + ' '
                                       + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')
                                       + ' '
                       END
                       --(Wan02) - END
                    END
                    ELSE
                    BEGIN
                       SELECT @c_SQL = @c_SQL + ' '
                                         + 'JOIN STOCKTAKEPARM2 PARM2_LOC WITH (NOLOCK) '
                                         + ' ON RTRIM(dbo.fnc_LTrim(PARM2_LOC.Value)) = LOC.LOC '
                                         + 'AND UPPER(PARM2_LOC.Tablename) = ''LOC'' '
                                         + 'AND PARM2_LOC.Stocktakekey = ''' + ISNULL(RTRIM(@c_StockTakeKey), '') + ''''

                    END
                    */
                    --(Wan06) - END
                    SELECT @c_SQLWhere = ' '
                        + 'WHERE   LOC.Facility = N''' + ISNULL(RTRIM(@c_Facility), '') + ''' '
                        + 'AND LOC NOT IN (SELECT DISTINCT LOC FROM #RESULT) '
                        + RTRIM(@c_StrategyLocSQL) + ' '                                        --(Wan04)
                    SELECT @c_sql = @c_sql + ' ' + @c_sqlWhere + ' ' + @c_sqlOther

                    EXEC ( @c_SQL )
                END
            -- End : SOS66279
        END

    DECLARE @c_lot             NVARCHAR(10)
        , @c_loc             NVARCHAR(10)
        , @c_id              NVARCHAR(18)
        , @c_sku             NVARCHAR(20)
        , @c_Lottable01      NVARCHAR(18)
        , @c_Lottable02      NVARCHAR(18)
        , @c_Lottable03      NVARCHAR(18)
        , @d_Lottable04      DATETIME
        , @d_Lottable05      DATETIME
        , @c_Lottable06      NVARCHAR(30)
        , @c_Lottable07      NVARCHAR(30)
        , @c_Lottable08      NVARCHAR(30)
        , @c_Lottable09      NVARCHAR(30)
        , @c_Lottable10      NVARCHAR(30)
        , @c_Lottable11      NVARCHAR(30)
        , @c_Lottable12      NVARCHAR(30)
        , @d_Lottable13      DATETIME
        , @d_Lottable14      DATETIME
        , @d_Lottable15      DATETIME
        , @n_qty             int
        , @c_Aisle           NVARCHAR(10)
        , @n_LocLevel        int
        , @c_prev_Facility   NVARCHAR(5)
        , @c_prev_Aisle      NVARCHAR(10)
        , @n_prev_LocLevel   int
        , @c_ccdetailkey     NVARCHAR(10)
        , @c_ccsheetno       NVARCHAR(10)
        --, @n_err             int
        --, @c_errmsg          NVARCHAR(250)
        , @n_LineCount       int
        , @c_PreLogLocation  NVARCHAR(18)
        , @c_CCLogicalLoc    NVARCHAR(18)
        , @n_SystemQty       int
        , @c_PrevZone        NVARCHAR(10)
        , @c_PutawayZone     NVARCHAR(10)
        , @c_Prev_Loc        NVARCHAR(10)      -- (Wan05)
        , @c_Prev_ID         NVARCHAR(18)      -- (Wan05)
        , @c_SQL2            NVARCHAR(4000)    -- (Wan05)

    SET @c_Prev_Loc = ''                         -- (Wan05)
    SET @c_Prev_ID  = ''                         -- (Wan05)
    SET @c_SQL2     = ''                         -- (Wan05)
    SELECT @c_prev_Facility = " ", @c_prev_Aisle = "XX", @n_prev_LocLevel = 999, @c_PreLogLocation = '000'

    --(Wan05) - START
    SET @c_PartitionBy = ''
    SET @c_SortBy = ''
    SET @c_ColumnName = ''

    DECLARE CUR_CCSHTBY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
        SELECT ColValue
        FROM   dbo.fnc_DelimSplit(',',@c_CountSheetGroupBy)
        ORDER BY SeqNo

    OPEN CUR_CCSHTBY

    FETCH NEXT FROM CUR_CCSHTBY INTO @c_ColumnName
    WHILE @@FETCH_STATUS <> -1
        BEGIN
            IF @c_ColumnName <> ''
                BEGIN
                    SET @c_PartitionBy = @c_PartitionBy  + @c_ColumnName + ','
                END
            FETCH NEXT FROM CUR_CCSHTBY INTO @c_ColumnName
        END
    CLOSE CUR_CCSHTBY
    DEALLOCATE CUR_CCSHTBY

    DECLARE CUR_CCSHTSORTBY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
        SELECT ColValue
        FROM   dbo.fnc_DelimSplit(',',@c_CountSheetSortBy)
        ORDER BY SeqNo

    OPEN CUR_CCSHTSORTBY

    FETCH NEXT FROM CUR_CCSHTSORTBY INTO @c_ColumnName
    WHILE @@FETCH_STATUS <> -1
        BEGIN
            IF @c_ColumnName <> ''
                BEGIN
                    SET @c_SortBy = @c_SortBy  + @c_ColumnName + ','
                END
            FETCH NEXT FROM CUR_CCSHTSORTBY INTO @c_ColumnName
        END
    CLOSE CUR_CCSHTSORTBY
    DEALLOCATE CUR_CCSHTSORTBY

    IF RTRIM(@c_PartitionBy) <> ''
        BEGIN
            IF RIGHT(RTRIM(@c_PartitionBy),1) = ','
                BEGIN
                    SET @c_PartitionBy = SUBSTRING(@c_PartitionBy,1, LEN(@c_PartitionBy) - 1)
                END

            SET @c_SortBy = @c_PartitionBy + ',' + @c_SortBy
        END

    IF RIGHT(RTRIM(@c_SortBy),1) = ','
        BEGIN
            SET @c_SortBy = SUBSTRING(@c_SortBy,1, LEN(@c_SortBy) - 1)
        END

    SET @c_SheetLineColumn = ', SheetLineNo = ROW_NUMBER() Over (ORDER BY LOC.Facility,LOTxLOCxID.Storerkey)'
    IF  RTRIM(@c_PartitionBy) <> '' OR RTRIM(@c_SortBy) <> ''
        BEGIN
            SET @c_SheetLineColumn = ', SheetLineNo = ROW_NUMBER() Over ('

            IF RTRIM(@c_PartitionBy) <> ''
                BEGIN
                    SET @c_SheetLineColumn = @c_SheetLineColumn + 'Partition By ' + RTRIM(@c_PartitionBy)
                END

            IF RTRIM(@c_SortBy) <> ''
                BEGIN
                    SET @c_SheetLineColumn = @c_SheetLineColumn + ' ORDER BY ' + RTRIM(@c_SortBy)
                END

            SET @c_SheetLineColumn = @c_SheetLineColumn + ')'
        END

    SET @c_RowRefColumn = ', RowRef= ROW_NUMBER() OVER ( ORDER BY ' + RTRIM(@c_SortBy)  + ')'

    SET @c_SQL2 = N'DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
                   FOR SELECT R.lot, R.loc, R.id, R.StorerKey, R.sku,
                           R.Lottable01, R.Lottable02, R.Lottable03, R.Lottable04, R.Lottable05,
                           R.Lottable06, R.Lottable07, R.Lottable08, R.Lottable09, R.Lottable10,
                           R.Lottable11, R.Lottable12, R.Lottable13, R.Lottable14, R.Lottable15,'
        +  CASE WHEN @c_WithQuantity = 'Y' THEN 'R.qty' ELSE '0' END
        + ',R.Facility, R.Aisle, R.LocLevel, R.CCLogicalLoc, R.qty, R.PutawayZone, R.UccNo'
        + @c_SheetLineColumn
        + @c_RowRefColumn
        + ' FROM #RESULT R'
        + ' JOIN LOC WITH (NOLOCK) ON (R.Loc = LOC.Loc)'
        + ' LEFT JOIN LOTxLOCxID WITH (NOLOCK) ON  (R.Lot = LOTxLOCxID.Lot)'
        +   ' AND (R.Loc = LOTxLOCxID.Loc)'
        +   ' AND (R.ID  = LOTxLOCxID.ID)'
        + ' ORDER BY RowRef'
    EXEC (@c_SQL2)
    --DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
    --FOR SELECT lot, loc, id, StorerKey, sku,
    --            Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
    --            Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
    --            Lottable11, Lottable12, Lottable13, Lottable14, Lottable15,
    --            CASE WHEN @c_WithQuantity = 'Y' THEN qty ELSE 0 END,
    --            Facility, Aisle, LocLevel, CCLogicalLoc, qty, PutawayZone, UccNo
    --FROM #RESULT
    --ORDER BY Facility, PutawayZone, Aisle, LocLevel, CCLogicalLoc, Loc, SKU

    SET @n_err = @@ERROR
    IF @n_err <> 0
        BEGIN
            CLOSE cur_1
            DEALLOCATE cur_1
        END
    ELSE
        BEGIN
            --(Wan05) -- END

            OPEN cur_1
            SELECT @n_LineCount = 0
            SELECT @c_CCSheetNoKeyName = 'CSHEET'+LTRIM(RTRIM(@c_StockTakeKey)) --NJOW02

            FETCH NEXT FROM cur_1 INTO @c_lot, @c_loc, @c_id, @c_StorerKey, @c_sku,
                @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
                @n_qty, @c_Facility, @c_Aisle, @n_LocLevel, @c_CCLogicalLoc, @n_SystemQty, @c_PutawayZone, @c_UccNo
                , @n_SheetLineNo, @n_RowRef              ---(Wan05)

            WHILE @@FETCH_STATUS <> -1
                BEGIN
                    -- select @c_Aisle '@c_Aisle', @c_prev_Aisle '@c_prev_Aisle', @n_LocLevel '@n_LocLevel', @n_prev_LocLevel '@n_prev_LocLevel'
                    --(Wan05) - START
                    IF ((@n_LineCount > @n_LinesPerPage
                        AND (ISNULL(@c_Loc,'') <> ISNULL(@c_prev_LOC,'')
                            OR ISNULL(@c_ID,'') <> ISNULL(@c_prev_ID,'') )
                            )
                        --OR RTRIM(@c_PutawayZone) <> RTRIM(@c_PrevZone)
                        --OR RTRIM(@c_Aisle) <> RTRIM(@c_prev_Aisle)
                        --OR RTRIM(@n_LocLevel) <> RTRIM(@n_prev_LocLevel)
                        OR @n_SheetLineNo = 1) AND @c_IsLOCPerPage = 'N'   --WL01
                    --(Wan05) - END
                        BEGIN
                            EXECUTE nspg_getkey
                                --'CCSheetNo'
                                    @c_CCSheetNoKeyName  --NJOW02
                                , 10
                                , @c_CCSheetNo OUTPUT
                                , @b_success OUTPUT
                                , @n_err OUTPUT
                                , @c_errmsg OUTPUT
                            SELECT @n_LineCount = 1
                        END

                    --WL01 S
                    --WL02 S
                    IF ((ISNULL(@c_Loc,'') <> ISNULL(@c_prev_LOC,'') OR ISNULL(@c_ID,'') <> ISNULL(@c_prev_ID,'') ) OR @n_SheetLineNo = 1) AND @c_IsLOCPerPage = 'Y'
                        SET @n_LOCLineCount = @n_LOCLineCount + 1

                    IF (@n_LOCLineCount > @n_LOCPerPage
                        OR @n_SheetLineNo = 1) AND @c_IsLOCPerPage = 'Y'   --WL02 E
                        BEGIN
                            EXECUTE nspg_getkey
                                --'CCSheetNo'
                                    @c_CCSheetNoKeyName
                                , 10
                                , @c_CCSheetNo OUTPUT
                                , @b_success OUTPUT
                                , @n_err OUTPUT
                                , @c_errmsg OUTPUT

                            SELECT @n_LOCLineCount = 1   --WL02
                        END
                    --WL01 E

                    --NJOW03 Start
                    SET @c_GenUCCCountSheetStatus2 = ''
                    EXECUTE nspGetRight
                            @c_Facility,                  -- facility
                            @c_StorerKey,                 -- Storerkey
                            NULL,                         -- Sku
                            'GenUCCCountSheetStatus2',    -- Configkey
                            @b_Success                 OUTPUT,
                            @c_GenUCCCountSheetStatus2 OUTPUT,
                            @n_err                     OUTPUT,
                            @c_ErrMsg                  OUTPUT

                    IF @c_GenUCCCountSheetStatus2 = '1'
                        SET @c_Status = '2'
                    ELSE
                        SET @c_Status = '0'
                    --NJOW03 End

                    EXECUTE nspg_getkey
                            'CCDetailKey'
                        , 10
                        , @c_CCDetailKey OUTPUT
                        , @b_success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT

                    IF @c_lot <> ""
                        BEGIN
                            INSERT CCDETAIL (cckey, ccdetailkey, StorerKey, sku, lot, loc, id, qty, ccsheetno,
                                             Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
                                             Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
                                             Lottable11, Lottable12, Lottable13, Lottable14, Lottable15, SystemQty, RefNo, Status)
                            VALUES (@c_StockTakeKey, @c_CCDetailKey, @c_StorerKey, @c_sku, @c_lot, @c_loc, @c_id, @n_qty, @c_CCSheetNo,
                                    @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                                    @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                    @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15, @n_SystemQty, @c_UccNo, @c_Status)
                        END
                    ELSE
                        BEGIN
                            INSERT CCDETAIL (cckey, ccdetailkey, StorerKey, sku, lot, loc, id, qty, ccsheetno,
                                             Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
                                             Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
                                             Lottable11, Lottable12, Lottable13, Lottable14, Lottable15, SystemQty, RefNo, Status)
                            VALUES (@c_StockTakeKey, @c_CCDetailKey, @c_StorerKey, @c_sku, @c_lot, @c_loc, @c_id, @n_qty, @c_CCSheetNo,
                                    @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                                    @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                    @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,  @n_SystemQty, @c_UccNo, @c_Status)
                        END

                    SELECT @n_LineCount = @n_LineCount + 1
                    --(Wan05) - START
                    --SELECT @c_prev_Aisle = @c_Aisle,
                    --      @n_prev_LocLevel = @n_LocLevel,
                    --      @c_PreLogLocation = @c_CCLogicalLoc,
                    --      @c_PrevZone = @c_PutawayZone
                    SET @c_prev_Loc = @c_loc
                    SET @c_prev_ID  = @c_id
                    --(Wan05) - END
                    FETCH NEXT FROM cur_1 INTO @c_lot, @c_loc, @c_id, @c_StorerKey, @c_sku,
                        @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                        @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                        @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
                        @n_qty, @c_Facility, @c_Aisle, @n_LocLevel, @c_CCLogicalLoc, @n_SystemQty, @c_PutawayZone, @c_UccNo
                        , @n_SheetLineNo, @n_RowRef              ---(Wan05)
                END -- WHILE
            CLOSE cur_1
            DEALLOCATE cur_1
        END
    DROP TABLE #RESULT
END

GO