SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/********************************************************************************/
/* Stored Procedure: ispGenCountSheet                                           */
/* Creation Date:                                                               */
/* Copyright: IDS                                                               */
/* Written by:                                                                  */
/*                                                                              */
/* Purpose: Generate StockTake Count Sheet                                      */
/*                                                                              */
/* Called By:                                                                   */
/*                                                                              */
/* PVCS Version: 1.14                                                           */
/*                                                                              */
/* Version: 5.4                                                                 */
/*                                                                              */
/* Data Modifications:                                                          */
/*                                                                              */
/* Updates:                                                                     */
/* Date         Author     Purposes                                             */
/* 31-Oct-2001  Shong      Fixed Skipped Count Sheet No                         */
/* 15-Jun-2002  Shong      If default PreXXX to BLANK, no count sheet #         */
/*                         will generate, because prexxx = xxx cause            */
/*                         xxx not setup, equal to BLANK                        */
/* 26-Jul-2002  Shong      Group by Lottables doesn't works                     */
/* 16-Aug-2002  Shong      Include System Qty                                   */
/* 26-Aug-2002  Shong      Include sorting for CCLogicalLoc and Loc             */
/* 01-Oct-2002  Shong      Added new parameters Agency code and ABC             */
/* 25-Oct-2002  Shong      -- Page break by PutawayZone                         */
/*                         -- Sorting by SKU in same location                   */
/* 16-Jun-2003  Wally      SOS11783 Increase agency code parameter              */
/*                         length to 255                                        */
/* 24-Jul-2003  Shong      When Rtrim Blank Parameter will cause the            */
/*                         SQL Statement become NULL -- Cause dbo.fnc_RTrim('') */
/*                         is equal to NULL in 6.5 Compatible Mode              */
/* 02-Jun-2004  June       SOS23776 Add in Configflag 'CCSHEETBYPASSPA'.        */
/*                         If enabled, CCSheet will not sort by PA Zone.        */
/*                         Raised by IDSTH                                      */
/* 09-Nov-2005  MaryVong   SOS42806 Increase length of returned fields          */
/*                         from ispParseParameters to NVARCHAR(800)             */
/* 19-Nov-2007  James      SOS69723 - Include field Status when                 */
/*                         insert CCDetail.                                     */
/* 18-Jan-2008  June       SOS66279 : Include STOCKTAKEPARM2 checking           */
/* 05-Aug-2010  NJOW01     182454 - Add skugroup parameter                      */
/* 24-Jan-2011  NJOW02     201680 - Add exclude qty picked checking when        */
/*                         calculate system qty                                 */
/* 25-Jul-2011  NJOW03     216737-New count sheet seq# for every stock          */
/*                         take.                                                */
/* 19-Oct-2012  Ung        SOS254691 Block if detected UCC data (ung01)         */
/* 22-Oct-2012  James      254690-Add CountType (james01)                       */
/* 03-Dec-2012  Leong      SOS# 263478 - Bug fix.                               */
/* 21-May-2014  TKLIM      Added Lottables 06-15                                */
/* 06-Nov-2014  NJOW04     324950-Generate count sheet no include id by config  */
/* 22-Jan-2015  James      Generate CCDetail with storerkey for empty loc if    */
/*                         configkey EmptyLOCWithStorerKey turned on (james02)  */
/* 17-Mar-2015  NJOW05     335849-Turn Off Cycle Count Sheet UCC Checking       */
/* 30-Mar-2015  NJOW06     316549-Group to oldest lot per sku,loc,id            */
/*                         no split ccsheet per loc and id.                     */
/* 28-MAR-2016  Wan01      SOS#366947: SG-Stocktake LocationRoom Parameter      */
/* 25-APR-2016  Wan02      SOS#368812 - DGE_CountSheetGenerationLogic_CR        */
/* 16-JUN-2016  Wan03      SOS#366947: SOS#371185 - CN Carter's SH WMS Cycle    */
/*                         Count module                                         */
/* 29-JUN-2016  Wan04      SOS#370874 - TW Add Cycle Count Strategy             */
/* 08-AUG-2016  Wan05      SOS#373839 - [TW] CountSheet Generation Logic        */
/* 23-NOV-2016  Wan06      WMS-648 - GW StockTake Parameter2 Enhancement        */
/* 21-Jan-2021  WLChooi    WMS-15985 - Generate No. Of Loc by Count Sheet (WL01)*/
/* 03-Mar-2021  WLChooi    WMS-15985 - Fix LocPerPage Logic (WL02)              */
/* 12-Nov-2021  Wan07      DevOps Combine Script.                               */
/* 12-Nov-2021  Wan07      WMS-18332 - [TW]LOR_CycleCount_CR                    */
/* 04-Jan-2023  LZG        JSM-120963 - Default StorerKey for empty location    */
/*                         if EmptyLOCWithStorerKey is turned on (ZG01)         */
/* 15-OCT-2024  SKB01      UWP-20468 joining PickDetail table to get Qty picked */
/********************************************************************************/
    
CREATE    PROC [dbo].[ispGenCountSheet] (
    @c_StockTakeKey NVARCHAR(10)
)
AS
BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE @c_Facility     NVARCHAR(5),
        @c_StorerKey         NVARCHAR(18),
        @c_AisleParm         NVARCHAR(60),
        @c_LevelParm         NVARCHAR(60),
        @c_ZoneParm          NVARCHAR(60),
        @c_HostWHCodeParm    NVARCHAR(60),
        @c_ClearHistory      NVARCHAR(1),
        @c_WithQuantity      NVARCHAR(1),
        @c_EmptyLocation     NVARCHAR(1),
        @n_LinesPerPage      int,
        @c_SKUParm           NVARCHAR(125),
        -- Added by SHONG 01 OCT 2002
        @c_AgencyParm        NVARCHAR(150),
        @c_ABCParm           NVARCHAR(60),
        @c_SkuGroupParm      NVARCHAR(125),
        @c_ExcludeQtyPicked  NVARCHAR(1),
        @c_GenCCdetailbyExcludePKDStatus3 NVARCHAR(1),
        @c_PickDetailJoinQuery NVARCHAR(255) = '',              --(SKB01)
        @c_PickDetailQtySubtractQuery NVARCHAR(255) = '',
        @c_authority NVARCHAR(1),
        @c_CCSheetNoKeyName  NVARCHAR(30), -- NJOW03
        @c_CCSheetIncludeID  NVARCHAR(10), --NJOW04
        @c_prev_ID           NVARCHAR(18), --NJOW04
        @c_prev_LOC         NVARCHAR(10), --NJOW06
        @c_TempStorerKey     NVARCHAR( 15),
        @n_Err               INT,           -- (james02)
        @c_ErrMsg            NVARCHAR (250),
        @c_GenEmptyLOCWithStorerKey NVARCHAR( 1)
--(Wan01) - START
        , @c_Extendedparm1Field      NVARCHAR(50)
        , @c_ExtendedParm1DataType   NVARCHAR(20)
        , @c_Extendedparm1           NVARCHAR(125)
        , @c_Extendedparm2Field      NVARCHAR(50)
        , @c_ExtendedParm2DataType   NVARCHAR(20)
        , @c_Extendedparm2           NVARCHAR(125)
        , @c_Extendedparm3Field      NVARCHAR(50)
        , @c_ExtendedParm3DataType   NVARCHAR(20)
        , @c_Extendedparm3           NVARCHAR(125)
--(Wan01) - END
        , @c_ExcludeQtyAllocated     NVARCHAR(1)       --(Wan03)
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

    -- declare a select condition variable for parameters
    -- SOS42806 Changed NVARCHAR(250) and NVARCHAR(255) to NVARCHAR(800)
    DECLARE @c_AisleSQL     NVARCHAR(800),
        @c_LevelSQL          NVARCHAR(800),
        @c_ZoneSQL           NVARCHAR(800),
        @c_HostWHCodeSQL     NVARCHAR(800),
        @c_AisleSQL2         NVARCHAR(800),
        @c_LevelSQL2         NVARCHAR(800),
        @c_ZoneSQL2          NVARCHAR(800),
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
--(Wan01) - START
        ,  @c_Extendedparm1SQL  NVARCHAR(800)
        ,  @c_Extendedparm1SQL2 NVARCHAR(800)
        ,  @c_Extendedparm2SQL  NVARCHAR(800)
        ,  @c_Extendedparm2SQL2 NVARCHAR(800)
        ,  @c_Extendedparm3SQL  NVARCHAR(800)
        ,  @c_Extendedparm3SQL2 NVARCHAR(800)
--(Wan01) - END
        ,  @c_StrategySQL       NVARCHAR(4000)       --(Wan03)
        ,  @c_StrategySkuSQL    NVARCHAR(4000)       --(Wan03)
        ,  @c_StrategyLocSQL    NVARCHAR(4000)       --(Wan03)

    -- Add by June 12.Mar.02 FBR063
    -- SOS42806
    DECLARE   @c_StorerSQL  NVARCHAR(800)
        , @c_StorerSQL2 NVARCHAR(800)
        , @c_StorerParm NVARCHAR(60)
        , @c_GroupLottable05 NVARCHAR(10)

    --(Wan01) - START
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
    --(Wan01) - END

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
            , @c_ExcludeQtyAllocated= ExcludeQtyAllocated        --(Wan03)
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
            , @n_LOCPerPage         = LocPerPage   --WL01
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
            SET @c_PickDetailJoinQuery = 'LEFT JOIN PICKDETAIL WITH (NOLOCK) ON PICKDETAIL.Lot = LOTxLOCxID.Lot and PICKDETAIL.Loc = LOTxLOCxID.Loc and PICKDETAIL.ID = LOTxLOCxID.Id '     --(SKB01)
            SET @c_PickDetailQtySubtractQuery = ' - CASE WHEN PICKDETAIL.Status=''3'' THEN PICKDETAIL.Qty ELSE 0 END '
        END
    ELSE
        SET @c_GenCCdetailbyExcludePKDStatus3 = 'N'
    /*
-- Remark by June 12.Mar.02 FBR063
IF @c_StorerKey IS NULL
BEGIN
RETURN
END
*/

    IF @n_LinesPerPage = 0 OR @n_LinesPerPage IS NULL
        SELECT @n_LinesPerPage = 999

    --WL01 S
    IF @n_LOCPerPage = 0 OR @n_LOCPerPage IS NULL OR @n_LOCPerPage = 999
        BEGIN
            SET @c_IsLOCPerPage = 'N'
            SET @n_LOCPerPage = 999
        END
    --WL01 E

    -- Start - Add by June 12.Mar.02 FBR063
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
    -- End - Add by June 12.Mar.02  FBR063
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

UPDATE StockTakeSheetParameters
SET FinalizeStage = 0,
    PopulateStage = 0,
    CountType = 'SKU'      -- (james01)
WHERE StockTakeKey = @c_StockTakeKey

    --(Wan01) - START
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
    --(Wan01) - END

    IF RTrim(@c_WithQuantity) = '' OR @c_WithQuantity IS NULL
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
FROM  LOTxLOCxID (NOLOCK),
      SKU (NOLOCK),
      LOTATTRIBUTE (NOLOCK),
      LOC (NOLOCK)
WHERE 1=2

DECLARE @c_SQL NVARCHAR(4000),
@c_SQL2 NVARCHAR(4000) --NJOW04

-- Start : SOS66279
DECLARE @c_sqlOther NVARCHAR(4000),
@c_sqlWhere NVARCHAR(4000),
@c_sqlGroup NVARCHAR(4000)

SELECT  @c_sqlOther = ''
    -- End : SOS66279


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

    IF RTrim(@c_GroupLottable05) = 'MIN'
        BEGIN
            -- Start : SOS66279
            IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) WHERE Stocktakekey = @c_StockTakeKey)
                BEGIN
                    -- End : SOS66279
                    SELECT @c_SQL =  'INSERT INTO #RESULT '
                        + 'SELECT SPACE(10),LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey,LOTxLOCxID.sku,'
                        + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, MIN(LOTATTRIBUTE.Lottable05),'
                        + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                        + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                        --(Wan03) - START
                        --+ CASE WHEN @c_ExcludeQtyPicked = 'Y' THEN 'Qty = SUM(LOTxLOCxID.qty-LOTxLOCxID.qtypicked),' ELSE 'Qty = SUM(LOTxLOCxID.qty),' END
                        +  CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated-LOTxLOCxID.Qtypicked'+ @c_PickDetailQtySubtractQuery + '), '
                                WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated), '
                                WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.Qtypicked'+ @c_PickDetailQtySubtractQuery + '), '
                                ELSE 'SUM(LOTxLOCxID.Qty), ' END
                        --(Wan03) - END
                        + 'LOC.PutawayZone,LOC.LocLevel,Aisle = LOC.locAisle,LOC.Facility, LOC.CCLogicalLoc '
                        + 'FROM  LOC WITH (NOLOCK) '
                        + 'JOIN LOTxLOCxID WITH (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC '
                        + 'JOIN SKU WITH (NOLOCK) ON SKU.Storerkey = LOTxLOCxID.Storerkey AND SKU.SKU = LOTxLOCxID.SKU '
                        + 'JOIN LOTATTRIBUTE WITH (NOLOCK) ON LOTATTRIBUTE.Lot = LOTxLOCxID.Lot '             --(Wan01)
                        + @c_PickDetailJoinQuery                                                              --(SKB01)
                        + 'WHERE 1 = 1 '                                                                      --(SKB01)
                        --(Wan03)
                        --+ CASE WHEN @c_ExcludeQtyPicked = 'Y' THEN 'AND   LOTxLOCxID.Qty-LOTxLOCxID.QtyPicked > 0 ' ELSE 'AND   LOTxLOCxID.Qty > 0 ' END
                        +  CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'AND LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated-LOTxLOCxID.Qtypicked'+ @c_PickDetailQtySubtractQuery +' > 0 '
                                WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'AND LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated > 0 '
                                WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'AND LOTxLOCxID.Qty-LOTxLOCxID.Qtypicked '+  @c_PickDetailQtySubtractQuery +'> 0 '
                                ELSE 'AND LOTxLOCxID.Qty > 0 ' END
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
                        + ISNULL(RTRIM(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm1SQL2), '') + ' '  --(Wan01)
                        + ISNULL(RTRIM(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm2SQL2), '') + ' '  --(Wan01)
                        + ISNULL(RTRIM(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm3SQL2), '') + ' '  --(Wan01)
                        + RTRIM(@c_StrategySQL) + ' '                                                                   --(Wan04)

                        + 'GROUP BY LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey,LOTxLOCxID.sku,' -- By SHONG 26th Jul 2002, Remove the LOT from this line
                        + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04,'
                        + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                        + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                        + 'LOC.PutawayZone,LOC.LocLevel,LOC.locAisle, LOC.Facility, LOC.CCLogicalLoc'
                    -- Start : SOS66279
                END
            ELSE
                BEGIN
                    SELECT @c_sql = N'INSERT INTO #RESULT '
                        + 'SELECT SPACE(10),LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey,LOTxLOCxID.sku,'
                        + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, MIN(LOTATTRIBUTE.Lottable05),'
                        + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                        + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                        --(Wan03) - START
                        --+ CASE WHEN @c_ExcludeQtyPicked = 'Y' THEN 'Qty = SUM(LOTxLOCxID.qty-LOTxLOCxID.qtypicked),' ELSE 'Qty = SUM(LOTxLOCxID.qty),' END
                        +  CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated-LOTxLOCxID.Qtypicked'+ @c_PickDetailQtySubtractQuery + '), '
                                WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated), '
                                WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.Qtypicked'+ @c_PickDetailQtySubtractQuery + '), '
                                ELSE 'SUM(LOTxLOCxID.Qty), ' END
                        --(Wan03) - END
                        + 'LOC.PutawayZone,LOC.LocLevel,Aisle = LOC.locAisle,LOC.Facility, LOC.CCLogicalLoc '
                        + 'FROM  LOTxLOCxID WITH (NOLOCK) '
                        + 'JOIN  SKU WITH (NOLOCK) ON SKU.Storerkey = LOTxLOCxID.Storerkey AND SKU.SKU = LOTxLOCxID.SKU '
                        + 'JOIN  LOTATTRIBUTE WITH (NOLOCK) ON LOTATTRIBUTE.LOT = LOTxLOCxID.LOT '
                        + 'JOIN  LOC WITH (NOLOCK) ON LOC.LOC = LOTxLOCxID.LOC '
                        + @c_PickDetailJoinQuery                        --(SKB01)


                    --(Wan06) - START
                    SET @c_sql = @c_sql + @c_StocktakeParm2SQL
                    SET @c_sqlOther = @c_sqlOther + @c_StocktakeParm2OtherSQL

                    /*
                    IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK)
                                   WHERE Stocktakekey = @c_StockTakeKey
                                   AND   UPPER(Tablename) = 'SKU')
                    BEGIN
                       SELECT @c_sqlOther = @c_sqlOther + ' '
                                         + ISNULL(RTrim(@c_SKUSQL), '') + ' ' + ISNULL(RTrim(@c_SKUSQL2), '') + ' '
                                         + ISNULL(RTrim(@c_AgencySQL), '') + ' ' + ISNULL(RTrim(@c_AgencySQL2), '') + ' '
                                         + ISNULL(RTrim(@c_ABCSQL), '') + ' ' + ISNULL(RTrim(@c_ABCSQL2), '') + ' '
                                         + ISNULL(RTrim(@c_SkuGroupSQL), '') + ' ' + ISNULL(RTrim(@c_SkuGroupSQL2), '') + ' '

                       --(Wan01) - START
                       IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                          SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'sku'
                       BEGIN
                          SET @c_sqlOther = @c_sqlOther + ' '
                                          + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
                                          + ' '
                       END

                       IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                          SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'sku'
                       BEGIN
                          SET @c_sqlOther = @c_sqlOther + ' '
                                          + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                                          + ' '
                       END

                       IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                          SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'sku'
                       BEGIN
                          SET @c_sqlOther = @c_sqlOther + ' '
                                          + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')
                                          + ' '
                       END
                       --(Wan01) - END
                    END
                    ELSE
                    BEGIN
                       SELECT @c_sql = @c_sql + ' '
                                         + 'JOIN STOCKTAKEPARM2 PARM2_SKU WITH (NOLOCK) '
                                         + '  ON PARM2_SKU.Storerkey = LOTxLOCxID.Storerkey '
                                         + ' AND RTrim(LTrim(PARM2_SKU.Value)) = LOTxLOCxID.SKU '
                                         + ' AND UPPER(PARM2_SKU.Tablename) = ''SKU'' '
                                         + ' AND PARM2_SKU.Stocktakekey = N''' + ISNULL(RTrim(@c_StockTakeKey), '') + ''''
                    END

                 IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK)
                                   WHERE Stocktakekey = @c_StockTakeKey
                                   AND   UPPER(Tablename) = 'LOC')
                    BEGIN
                       SELECT @c_sqlOther = @c_sqlOther + ' '
                                         + ISNULL(RTrim(@c_ZoneSQL), '') + ' ' + ISNULL(RTrim(@c_ZoneSQL2), '') + ' '
                                         + ISNULL(RTrim(@c_AisleSQL), '') + ' ' + ISNULL(RTrim(@c_AisleSQL2), '') + ' '
                                         + ISNULL(RTrim(@c_LevelSQL), '') + ' ' + ISNULL(RTrim(@c_LevelSQL2), '') + ' '
                                         + ISNULL(RTrim(@c_HostWHCodeSQL), '') + ' ' + ISNULL(RTrim(@c_HostWHCodeSQL2), '') + ' '

                       --(Wan01) - START
                       IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                          SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'loc'
                       BEGIN
                       SET @c_sqlOther = @c_sqlOther + ' '
                                       + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
                                       + ' '
                       END

                       IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                          SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'loc'
                       BEGIN
                       SET @c_sqlOther = @c_sqlOther + ' '
                                       + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                                       + ' '
                       END

                       IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                          SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'loc'
                       BEGIN
                       SET @c_sqlOther = @c_sqlOther + ' '
                                       + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')
                                       + ' '
                       END
                       --(Wan01) - END
                    END
                    ELSE
                    BEGIN
                       SELECT @c_sql = @c_sql + ' '
                                         + 'JOIN STOCKTAKEPARM2 PARM2_LOC WITH (NOLOCK) '
                                         + '  ON RTrim(LTrim(PARM2_LOC.Value)) = LOTxLOCxID.LOC '
                                         + ' AND UPPER(PARM2_LOC.Tablename) = ''LOC'' '
                                         + ' AND PARM2_LOC.Stocktakekey = N''' + ISNULL(RTrim(@c_StockTakeKey), '') + ''''
                    END

                    --(Wan01) - START
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
                    --(Wan01) - END
                    */

                    SELECT @c_sqlWhere = ' '
                        --(Wan03) - START
                        --+ CASE WHEN @c_ExcludeQtyPicked = 'Y' THEN 'WHERE LOTxLOCxID.Qty-LOTxLOCxID.QtyPicked > 0 ' ELSE 'WHERE LOTxLOCxID.Qty > 0 ' END
                        +  CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'WHERE LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated-LOTxLOCxID.Qtypicked'+ @c_PickDetailQtySubtractQuery + ' > 0 '
                                WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'WHERE LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated > 0 '
                                WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'WHERE LOTxLOCxID.Qty-LOTxLOCxID.Qtypicked '+ @c_PickDetailQtySubtractQuery +' > 0 '
                                ELSE 'WHERE LOTxLOCxID.Qty > 0 ' END
                        --(Wan03) - END
                        + 'AND   LOC.Facility = N''' + ISNULL(RTrim(@c_Facility), '') + ''' '
                        + ISNULL(RTrim(@c_StorerSQL), '') + ' ' + ISNULL(RTrim(@c_StorerSQL2), '') + ' '
                        + RTRIM(@c_StrategySQL) + ' '                                              --(Wan04)
                    SELECT @c_sqlGroup = ' '
                        + 'GROUP BY LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey,LOTxLOCxID.sku,' -- By SHONG 26th Jul 2002, Remove the LOT from this line
                        + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04,'
                        + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                        + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                        + 'LOC.PutawayZone,LOC.LocLevel,LOC.locAisle, LOC.Facility, LOC.CCLogicalLoc'

                    SELECT @c_sql = @c_sql + ' ' + @c_sqlWhere + ' ' + @c_sqlOther + ' ' + @c_sqlGroup
                END
            -- End : SOS66279
        END
    ELSE IF RTrim(@c_GroupLottable05) = 'MAX'
        BEGIN
            -- Start : SOS66279
            IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) WHERE Stocktakekey = @c_StockTakeKey)
                BEGIN
                    -- End : SOS66279
                    SELECT @c_SQL =  'INSERT INTO #RESULT '
                        + 'SELECT SPACE(10),LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey,LOTxLOCxID.sku,'
                        + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, MAX(LOTATTRIBUTE.Lottable05),'
                        + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                        + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                        --(Wan03) - START
                        --+ CASE WHEN @c_ExcludeQtyPicked = 'Y' THEN 'Qty = SUM(LOTxLOCxID.qty-LOTxLOCxID.qtypicked),' ELSE 'Qty = SUM(LOTxLOCxID.qty),' END
                        +  CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated-LOTxLOCxID.Qtypicked'+ @c_PickDetailQtySubtractQuery + '), '
                                WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated), '
                                WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.Qtypicked'+ @c_PickDetailQtySubtractQuery + '), '
                                ELSE 'SUM(LOTxLOCxID.Qty), ' END
                        --(Wan03) - END
                        + 'LOC.PutawayZone,LOC.LocLevel,Aisle = LOC.locAisle,LOC.Facility, LOC.CCLogicalLoc '
                        + 'FROM  LOC WITH (NOLOCK) '
                        + 'JOIN LOTxLOCxID WITH (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC '
                        + 'JOIN SKU WITH (NOLOCK) ON SKU.Storerkey = LOTxLOCxID.Storerkey AND SKU.SKU = LOTxLOCxID.SKU '
                        + 'JOIN LOTATTRIBUTE WITH (NOLOCK) ON LOTATTRIBUTE.Lot = LOTxLOCxID.Lot '             --(Wan01)
                        + @c_PickDetailJoinQuery                                                              --(SKB01)
                        + 'WHERE 1 = 1 '                                                                      --(SKB01)
                        --(Wan03) - START
                        --+ CASE WHEN @c_ExcludeQtyPicked = 'Y' THEN 'AND   LOTxLOCxID.Qty-LOTxLOCxID.QtyPicked > 0 ' ELSE 'AND   LOTxLOCxID.Qty > 0 ' END
                        +  CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'AND LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated-LOTxLOCxID.Qtypicked '+ @c_PickDetailQtySubtractQuery + ' > 0 '
                                WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'AND LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated > 0 '
                                WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'AND LOTxLOCxID.Qty-LOTxLOCxID.Qtypicked '+ @c_PickDetailQtySubtractQuery + ' > 0 '
                                ELSE 'AND LOTxLOCxID.Qty > 0 ' END
                        --(Wan03) - END
                        + 'AND   LOC.Facility = N''' + ISNULL(RTrim(@c_Facility), '') + ''' '
                        + ISNULL(RTrim(@c_StorerSQL), '') + ' ' + ISNULL(RTrim(@c_StorerSQL2), '') + ' '
                        + ISNULL(RTrim(@c_ZoneSQL), '') + ' ' + ISNULL(RTrim(@c_ZoneSQL2), '') + ' '
                        + ISNULL(RTrim(@c_AisleSQL), '') + ' ' + ISNULL(RTrim(@c_AisleSQL2), '') + ' '
                        + ISNULL(RTrim(@c_LevelSQL), '') + ' ' + ISNULL(RTrim(@c_LevelSQL2), '') + ' '
                        + ISNULL(RTrim(@c_HostWHCodeSQL), '') + ' ' + ISNULL(RTrim(@c_HostWHCodeSQL2), '') + ' '
                        + ISNULL(RTrim(@c_SKUSQL), '') + ' ' + ISNULL(RTrim(@c_SKUSQL2), '') + ' '
                        + ISNULL(RTrim(@c_AgencySQL), '') + ' ' + ISNULL(RTrim(@c_AgencySQL2), '') + ' '
                        + ISNULL(RTrim(@c_ABCSQL), '') + ' ' + ISNULL(RTrim(@c_ABCSQL2), '') + ' '
                        + ISNULL(RTrim(@c_SkuGroupSQL), '') + ' ' + ISNULL(RTrim(@c_SkuGroupSQL2), '') + ' '
                        + ISNULL(RTRIM(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm1SQL2), '') + ' '  --(Wan01)
                        + ISNULL(RTRIM(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm2SQL2), '') + ' '  --(Wan01)
                        + ISNULL(RTRIM(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm3SQL2), '') + ' '  --(Wan01)
                        + RTRIM(@c_StrategySQL) + ' '                                                                   --(Wan04)

                        + 'GROUP BY LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey,LOTxLOCxID.sku,' -- By SHONG 26th Jul 2002, Remove the LOT from this line
                        + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04,'
                        + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                        + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                        + 'LOC.PutawayZone,LOC.LocLevel,LOC.locAisle, LOC.Facility, LOC.CCLogicalLoc'
                    -- Start : SOS66279
                END
            ELSE
                BEGIN
                    SELECT @c_sql = N'INSERT INTO #RESULT '
                        + 'SELECT SPACE(10),LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey,LOTxLOCxID.sku,'
                        + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, MAX(LOTATTRIBUTE.Lottable05),'
                        + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                        + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                        --(Wan03) - START
                        --+ CASE WHEN @c_ExcludeQtyPicked = 'Y' THEN 'Qty = SUM(LOTxLOCxID.qty-LOTxLOCxID.qtypicked),' ELSE 'Qty = SUM(LOTxLOCxID.qty),' END
                        +  CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated-LOTxLOCxID.Qtypicked'+ @c_PickDetailQtySubtractQuery + '), '
                                WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated), '
                                WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.Qtypicked'+ @c_PickDetailQtySubtractQuery + '), '
                                ELSE 'SUM(LOTxLOCxID.Qty), ' END
                        --(Wan03) - END
                        + 'LOC.PutawayZone,LOC.LocLevel,Aisle = LOC.locAisle,LOC.Facility, LOC.CCLogicalLoc '
                        + 'FROM  LOTxLOCxID WITH (NOLOCK) '
                        + 'JOIN  SKU WITH (NOLOCK) ON SKU.Storerkey = LOTxLOCxID.Storerkey AND SKU.SKU = LOTxLOCxID.SKU '
                        + 'JOIN  LOTATTRIBUTE WITH (NOLOCK) ON LOTATTRIBUTE.LOT = LOTxLOCxID.LOT '
                        + 'JOIN  LOC WITH (NOLOCK) ON LOC.LOC = LOTxLOCxID.LOC '
                        + @c_PickDetailJoinQuery                          --(SKB01)

                    --(Wan06) - START
                    SET @c_sql = @c_sql + @c_StocktakeParm2SQL
                    SET @c_sqlOther = @c_sqlOther + @c_StocktakeParm2OtherSQL
                    /*
              IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK)
                             WHERE Stocktakekey = @c_StockTakeKey
                             AND   UPPER(Tablename) = 'SKU')
              BEGIN
                 SELECT @c_sqlOther = @c_sqlOther + ' '
                                   + ISNULL(RTrim(@c_SKUSQL), '') + ' ' + ISNULL(RTrim(@c_SKUSQL2), '') + ' '
                                   + ISNULL(RTrim(@c_AgencySQL), '') + ' ' + ISNULL(RTrim(@c_AgencySQL2), '') + ' '
                                   + ISNULL(RTrim(@c_ABCSQL), '') + ' ' + ISNULL(RTrim(@c_ABCSQL2), '') + ' '
                                   + ISNULL(RTrim(@c_SkuGroupSQL), '') + ' ' + ISNULL(RTrim(@c_SkuGroupSQL2), '') + ' '
                 --(Wan01) - START
                 IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                    SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'sku'
                 BEGIN
                    SET @c_sqlOther = @c_sqlOther + ' '
                                    + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
                                    + ' '
                 END

                 IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                    SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'sku'
                 BEGIN
                    SET @c_sqlOther = @c_sqlOther + ' '
                                    + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                                    + ' '
                 END

                 IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                    SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'sku'
                 BEGIN
                    SET @c_sqlOther = @c_sqlOther + ' '
                                    + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')
                                    + ' '
                 END
                 --(Wan01) - END
              END
              ELSE
              BEGIN
                 SELECT @c_sql = @c_sql + ' '
                                   + 'JOIN STOCKTAKEPARM2 PARM2_SKU WITH (NOLOCK) '
                                   + ' ON  PARM2_SKU.Storerkey = LOTxLOCxID.Storerkey '
                                   + ' AND RTrim(LTrim(PARM2_SKU.Value)) = LOTxLOCxID.SKU '
                                   + ' AND UPPER(PARM2_SKU.Tablename) = ''SKU'' '
                                   + ' AND PARM2_SKU.Stocktakekey = N''' + ISNULL(RTrim(@c_StockTakeKey), '') + ''''
              END

              IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK)
                             WHERE Stocktakekey = @c_StockTakeKey
                             AND   UPPER(Tablename) = 'LOC')
              BEGIN
                 SELECT @c_sqlOther = @c_sqlOther + ' '
                                   + ISNULL(RTrim(@c_ZoneSQL), '') + ' ' + ISNULL(RTrim(@c_ZoneSQL2), '') + ' '
                                   + ISNULL(RTrim(@c_AisleSQL), '') + ' ' + ISNULL(RTrim(@c_AisleSQL2), '') + ' '
                                   + ISNULL(RTrim(@c_LevelSQL), '') + ' ' + ISNULL(RTrim(@c_LevelSQL2), '') + ' '
                                   + ISNULL(RTrim(@c_HostWHCodeSQL), '') + ' ' + ISNULL(RTrim(@c_HostWHCodeSQL2), '') + ' '
                 --(Wan01) - START
                 IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                    SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'loc'
                 BEGIN
                 SET @c_sqlOther = @c_sqlOther + ' '
                                 + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
                                 + ' '
                 END

                 IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                    SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'loc'
                 BEGIN
                 SET @c_sqlOther = @c_sqlOther + ' '
                                 + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                                 + ' '
                 END

                 IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                    SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'loc'
                 BEGIN
                 SET @c_sqlOther = @c_sqlOther + ' '
                                 + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')
                                 + ' '
                 END
                 --(Wan01) - END
              END
              ELSE
              BEGIN
                 SELECT @c_sql = @c_sql + ' '
                                   + 'JOIN STOCKTAKEPARM2 PARM2_LOC WITH (NOLOCK) '
                                   + ' ON  RTrim(LTrim(PARM2_LOC.Value)) = LOTxLOCxID.LOC '
                                   + ' AND UPPER(PARM2_LOC.Tablename) = ''LOC'' '
                                   + ' AND PARM2_LOC.Stocktakekey = N''' + ISNULL(RTrim(@c_StockTakeKey), '') + ''''
              END

              --(Wan01) - START
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
              --(Wan01) - END
              */
                    --(Wan06) - END
                    SELECT @c_sqlWhere = ' '
                        --(Wan03) - START
                        --+ CASE WHEN @c_ExcludeQtyPicked = 'Y' THEN 'WHERE LOTxLOCxID.Qty-LOTxLOCxID.QtyPicked > 0 ' ELSE 'WHERE LOTxLOCxID.Qty > 0 ' END
                        +  CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'WHERE LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated-LOTxLOCxID.Qtypicked '+ @c_PickDetailQtySubtractQuery + '> 0 '
                                WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'WHERE LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated > 0 '
                                WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'WHERE LOTxLOCxID.Qty-LOTxLOCxID.Qtypicked '+ @c_PickDetailQtySubtractQuery + '> 0 '
                                ELSE 'WHERE LOTxLOCxID.Qty > 0 ' END
                        --(Wan03) - END
                        + 'AND   LOC.Facility = N''' + ISNULL(RTrim(@c_Facility), '') + ''' '
                        + ISNULL(RTrim(@c_StorerSQL), '') + ' ' + ISNULL(RTrim(@c_StorerSQL2), '') + ' '
                        + RTRIM(@c_StrategySQL) + ' '                                              --(Wan04)

                    SELECT @c_sqlGroup = ' '
                        + 'GROUP BY LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey,LOTxLOCxID.sku,' -- By SHONG 26th Jul 2002, Remove the LOT from this line
                        + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04,'
                        + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                        + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                        + 'LOC.PutawayZone,LOC.LocLevel,LOC.locAisle, LOC.Facility, LOC.CCLogicalLoc'

                    SELECT @c_sql = @c_sql + ' ' + @c_sqlWhere + ' ' + @c_sqlOther + ' ' + @c_sqlGroup
                END
            -- End : SOS66279
        END
    ELSE
        BEGIN
            -- Start : SOS66279
            IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) WHERE Stocktakekey = @c_StockTakeKey)
                BEGIN
                    -- End : SOS66279
                    SELECT @c_SQL =  'INSERT INTO #RESULT '
                        + 'SELECT LOTxLOCxID.lot,LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey,LOTxLOCxID.sku,'
                        + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05,'
                        + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                        + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                        --(Wan03) - START
                        --+ CASE WHEN @c_ExcludeQtyPicked = 'Y' THEN 'Qty = SUM(LOTxLOCxID.qty-LOTxLOCxID.qtypicked),' ELSE 'Qty = SUM(LOTxLOCxID.qty),' END
                        +  CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated-LOTxLOCxID.Qtypicked'+ @c_PickDetailQtySubtractQuery + '), '
                                WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated), '
                                WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.Qtypicked'+ @c_PickDetailQtySubtractQuery + '), '
                                ELSE 'SUM(LOTxLOCxID.Qty), ' END
                        --(Wan03) - END
                        + 'LOC.PutawayZone,LOC.LocLevel,Aisle = LOC.locAisle,LOC.Facility, LOC.CCLogicalLoc '
                        + 'FROM LOC WITH (NOLOCK) '
                        + 'JOIN LOTxLOCxID WITH (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC '
                        + 'JOIN SKU WITH (NOLOCK) ON SKU.Storerkey = LOTxLOCxID.Storerkey AND SKU.SKU = LOTxLOCxID.SKU '
                        + 'JOIN LOTATTRIBUTE WITH (NOLOCK) ON LOTATTRIBUTE.Lot = LOTxLOCxID.Lot '             --(Wan01)
                        + @c_PickDetailJoinQuery                                                              --(SKB01)
                        + 'WHERE 1 = 1 '                                                                      --(SKB01)
                        --(Wan03) - START
                        --+ CASE WHEN @c_ExcludeQtyPicked = 'Y' THEN 'AND   LOTxLOCxID.Qty-LOTxLOCxID.QtyPicked > 0 ' ELSE 'AND   LOTxLOCxID.Qty > 0 ' END
                        +  CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'AND LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated-LOTxLOCxID.Qtypicked '+ @c_PickDetailQtySubtractQuery + '> 0 '
                                WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'AND LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated > 0 '
                                WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'AND LOTxLOCxID.Qty-LOTxLOCxID.Qtypicked '+ @c_PickDetailQtySubtractQuery + '> 0 '
                                ELSE 'AND LOTxLOCxID.Qty > 0 ' END
                        --(Wan03) - END
                        + 'AND   LOC.Facility = N''' + ISNULL(RTrim(@c_Facility), '') + ''' '
                        + ISNULL(RTrim(@c_StorerSQL), '') + ' ' + ISNULL(RTrim(@c_StorerSQL2), '') + ' '
                        + ISNULL(RTrim(@c_ZoneSQL), '') + ' ' + ISNULL(RTrim(@c_ZoneSQL2), '') + ' '
                        + ISNULL(RTrim(@c_AisleSQL), '') + ' ' + ISNULL(RTrim(@c_AisleSQL2), '') + ' '
                        + ISNULL(RTrim(@c_LevelSQL), '') + ' ' + ISNULL(RTrim(@c_LevelSQL2), '') + ' '
                        + ISNULL(RTrim(@c_HostWHCodeSQL), '') + ' ' + ISNULL(RTrim(@c_HostWHCodeSQL2), '') + ' '
                        + ISNULL(RTrim(@c_SKUSQL), '') + ' ' + ISNULL(RTrim(@c_SKUSQL2), '') + ' '
                        + ISNULL(RTrim(@c_AgencySQL), '') + ' ' + ISNULL(RTrim(@c_AgencySQL2), '') + ' '
                        + ISNULL(RTrim(@c_ABCSQL), '') + ' ' + ISNULL(RTrim(@c_ABCSQL2), '') + ' '
                        + ISNULL(RTrim(@c_SkuGroupSQL), '') + ' ' + ISNULL(RTrim(@c_SkuGroupSQL2), '') + ' '
                        + ISNULL(RTRIM(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm1SQL2), '') + ' '  --(Wan01)
                        + ISNULL(RTRIM(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm2SQL2), '') + ' '  --(Wan01)
                        + ISNULL(RTRIM(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm3SQL2), '') + ' '  --(Wan01)
                        + RTRIM(@c_StrategySQL) + ' '                                                                   --(Wan04)

                        + 'GROUP BY LOTxLOCxID.lot, LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey,LOTxLOCxID.sku,'
                        + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04,'
                        + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                        + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                        + 'LOTATTRIBUTE.Lottable05,LOC.PutawayZone,LOC.LocLevel,LOC.locAisle, LOC.Facility, LOC.CCLogicalLoc'
                    -- Start : SOS66279
                END
            ELSE
                BEGIN
                    SELECT @c_sql = N'INSERT INTO #RESULT '
                        + 'SELECT LOTxLOCxID.lot,LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey,LOTxLOCxID.sku,'
                        + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05,'
                        + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                        + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                        --(Wan03) - START
                        --+ CASE WHEN @c_ExcludeQtyPicked = 'Y' THEN 'Qty = SUM(LOTxLOCxID.qty-LOTxLOCxID.qtypicked),' ELSE 'Qty = SUM(LOTxLOCxID.qty),' END
                        +  CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated-LOTxLOCxID.Qtypicked'+ @c_PickDetailQtySubtractQuery + '), '
                                WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated), '
                                WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'SUM(LOTxLOCxID.Qty-LOTxLOCxID.Qtypicked'+ @c_PickDetailQtySubtractQuery + '), '
                                ELSE 'SUM(LOTxLOCxID.Qty), ' END
                        --(Wan03) - END
                        + 'LOC.PutawayZone,LOC.LocLevel,Aisle = LOC.locAisle,LOC.Facility, LOC.CCLogicalLoc '
                        + 'FROM  LOTxLOCxID WITH (NOLOCK) '
                        + 'JOIN  SKU WITH (NOLOCK) ON SKU.Storerkey = LOTxLOCxID.Storerkey AND SKU.SKU = LOTxLOCxID.SKU '
                        + 'JOIN  LOTATTRIBUTE WITH (NOLOCK) ON LOTATTRIBUTE.LOT = LOTxLOCxID.LOT '
                        + 'JOIN  LOC WITH (NOLOCK) ON LOC.LOC = LOTxLOCxID.LOC '
                        + @c_PickDetailJoinQuery                            --(SKB01)

                    --(Wan06) - START
                    SET @c_sql = @c_sql + @c_StocktakeParm2SQL
                    SET @c_sqlOther = @c_sqlOther + @c_StocktakeParm2OtherSQL

                    /*
                    IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK)
                                   WHERE Stocktakekey = @c_StockTakeKey
                                   AND   UPPER(Tablename) = 'SKU')
                    BEGIN
                       SELECT @c_sqlOther = @c_sqlOther + ' '
                                         + ISNULL(RTrim(@c_SKUSQL), '') + ' ' + ISNULL(RTrim(@c_SKUSQL2), '') + ' '
                                         + ISNULL(RTrim(@c_AgencySQL), '') + ' ' + ISNULL(RTrim(@c_AgencySQL2), '') + ' '
                                         + ISNULL(RTrim(@c_ABCSQL), '') + ' ' + ISNULL(RTrim(@c_ABCSQL2), '') + ' '
                                         + ISNULL(RTrim(@c_SkuGroupSQL), '') + ' ' + ISNULL(RTrim(@c_SkuGroupSQL2), '') + ' '

                       --(Wan01) - START
                       IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                          SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'sku'
                       BEGIN
                          SET @c_sqlOther = @c_sqlOther + ' '
                                          + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
                                          + ' '
                       END

                       IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                          SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'sku'
                       BEGIN
                          SET @c_sqlOther = @c_sqlOther + ' '
                                          + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                                          + ' '
                       END

                       IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                          SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'sku'
                       BEGIN
                          SET @c_sqlOther = @c_sqlOther + ' '
                                          + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')
                                          + ' '
                       END
                       --(Wan01) - END
                    END
                    ELSE
                    BEGIN
                       SELECT @c_sql = @c_sql + ' '
                                         + 'JOIN STOCKTAKEPARM2 PARM2_SKU WITH (NOLOCK) '
                                         + ' ON  PARM2_SKU.Storerkey = LOTxLOCxID.Storerkey '
                                         + ' AND RTrim(LTrim(PARM2_SKU.Value)) = LOTxLOCxID.SKU '
                                         + ' AND UPPER(PARM2_SKU.Tablename) = ''SKU'' '
                                         + ' AND PARM2_SKU.Stocktakekey = N''' + ISNULL(RTrim(@c_StockTakeKey), '') + ''''
                    END

                    IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK)
                                   WHERE Stocktakekey = @c_StockTakeKey
                                   AND   UPPER(Tablename) = 'LOC')
                    BEGIN
                       SELECT @c_sqlOther = @c_sqlOther + ' '
                                         + ISNULL(RTrim(@c_ZoneSQL), '') + ' ' + ISNULL(RTrim(@c_ZoneSQL2), '') + ' '
                                         + ISNULL(RTrim(@c_AisleSQL), '') + ' ' + ISNULL(RTrim(@c_AisleSQL2), '') + ' '
                                         + ISNULL(RTrim(@c_LevelSQL), '') + ' ' + ISNULL(RTrim(@c_LevelSQL2), '') + ' '
                                         + ISNULL(RTrim(@c_HostWHCodeSQL), '') + ' ' + ISNULL(RTrim(@c_HostWHCodeSQL2), '') + ' '
                       --(Wan01) - START
                       IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                          SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'loc'
                       BEGIN
                          SET @c_sqlOther = @c_sqlOther + ' '
                                          + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
                                          + ' '
                       END

                       IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                          SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'loc'
                       BEGIN
                          SET @c_sqlOther = @c_sqlOther + ' '
                                          + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                                          + ' '
                       END

                       IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                          SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'loc'
                       BEGIN
                          SET @c_sqlOther = @c_sqlOther + ' '
                                          + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')
                                          + ' '
                       END
                       --(Wan01) - END
                    END
                    ELSE
                    BEGIN
                       SELECT @c_sql = @c_sql + ' '
                                         + 'JOIN STOCKTAKEPARM2 PARM2_LOC WITH (NOLOCK) '
                                         + ' ON  RTrim(LTrim(PARM2_LOC.Value)) = LOTxLOCxID.LOC '
                                         + ' AND UPPER(PARM2_LOC.Tablename) = ''LOC'' '
                                         + ' AND PARM2_LOC.Stocktakekey = N''' + ISNULL(RTrim(@c_StockTakeKey), '') + ''''
                    END

                    --(Wan01) - START
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
                    --(Wan01) - END
                    */
                    --(Wan06) - END
                    SELECT @c_sqlWhere = ' '
                        --(Wan03) - START
                        --+ CASE WHEN @c_ExcludeQtyPicked = 'Y' THEN 'WHERE LOTxLOCxID.Qty-LOTxLOCxID.QtyPicked > 0 ' ELSE 'WHERE LOTxLOCxID.Qty > 0 ' END
                        +  CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'WHERE LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated-LOTxLOCxID.Qtypicked '+ @c_PickDetailQtySubtractQuery + '> 0 '
                                WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'WHERE LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated > 0 '
                                WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'WHERE LOTxLOCxID.Qty-LOTxLOCxID.Qtypicked '+ @c_PickDetailQtySubtractQuery + '> 0 '
                                ELSE 'WHERE LOTxLOCxID.Qty > 0 ' END
                        --(Wan03) - END
                        + 'AND   LOC.Facility = N''' + ISNULL(RTrim(@c_Facility), '') + ''' '
                        + ISNULL(RTrim(@c_StorerSQL), '') + ' ' + ISNULL(RTrim(@c_StorerSQL2), '') + ' '
                        + RTRIM(@c_StrategySQL) + ' '                                              --(Wan04)

                    SELECT @c_sqlGroup = ' '
                        + 'GROUP BY LOTxLOCxID.lot, LOTxLOCxID.loc,LOTxLOCxID.id,LOTxLOCxID.StorerKey,LOTxLOCxID.sku,'
                        + 'LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05,'
                        + 'LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,'
                        + 'LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,'
                        + 'LOC.PutawayZone,LOC.LocLevel,LOC.locAisle, LOC.Facility, LOC.CCLogicalLoc'

                    SELECT @c_sql = @c_sql + ' ' + @c_sqlWhere + ' ' + @c_sqlOther + ' ' + @c_sqlGroup

                END
            -- End : SOS66279
        END

    EXEC (@c_sql)
    --print @c_sql
--NJOW06 Start

    IF dbo.fnc_RTrim(@c_GroupLottable05) IN('MINLOT','MAXLOT')
        BEGIN
            SELECT Storerkey, Sku, Loc, ID, SPACE(18) AS MinMaxLot, Qty, SPACE(10) AS Lot
            INTO #RESULT2
            FROM #RESULT
            WHERE 1=2

            IF dbo.fnc_RTrim(@c_GroupLottable05) = 'MINLOT'
                BEGIN
                    INSERT INTO #RESULT2
                    SELECT Storerkey, Sku, Loc, ID, MIN(CONVERT(NVARCHAR(8),Lottable05,112) + Lot) AS MinMaxLot, SUM(Qty) AS Qty, ''
                    FROM #RESULT
                    GROUP BY Storerkey, Sku, Loc, ID
                END
            ELSE
                BEGIN
                    INSERT INTO #RESULT2
                    SELECT Storerkey, Sku, Loc, ID, MAX(CONVERT(NVARCHAR(8),Lottable05,112) + Lot) AS MinMaxLot, SUM(Qty) AS Qty, ''
                    FROM #RESULT
                    GROUP BY Storerkey, Sku, Loc, ID
                END

            UPDATE #RESULT2
            SET Lot = CASE WHEN LEN(MinMaxLot) > 10 THEN SUBSTRING(MinMaxLot,9,10) ELSE MinMaxLot END
            FROM #RESULT2

            DELETE FROM #RESULT

            INSERT INTO #RESULT
            SELECT #RESULT2.Lot, #RESULT2.loc, #RESULT2.id, #RESULT2.StorerKey,
                   #RESULT2.sku, LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02,
                   LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05,
                   LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08,
                   LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10, LOTATTRIBUTE.Lottable11,
                   LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,
                   #RESULT2.Qty, LOC.PutawayZone, LOC.LocLevel, LOC.locAisle, LOC.Facility, LOC.CCLogicalLoc
            FROM #RESULT2
                     JOIN LOTATTRIBUTE WITH (NOLOCK) ON #RESULT2.Lot = LOTATTRIBUTE.Lot
                     JOIN LOC WITH (NOLOCK) ON LOC.LOC = #RESULT2.LOC
        END

--NJOW06 End

    IF @c_EmptyLocation = 'Y'
        BEGIN
            -- (james02)
            -- If LOC empty then storerkey = blank
            -- Some RDT CC module cannot handle storerkey = blank
            -- If configkey setup, turned on and only 1 storerkey specified in stocktakeparameters.storerkey
            -- then populate empty loc with storerkey
            SELECT @c_TempStorerKey = StorerKey
            FROM StockTakeSheetParameters (NOLOCK)
            WHERE StockTakeKey = @c_StockTakeKey

            SET @c_GenEmptyLOCWithStorerKey = ''
            EXECUTE nspGetRight
                    @c_Facility,    -- facility
                    @c_TempStorerKey,             -- Storerkey
                    NULL,                         -- Sku
                    'EmptyLOCWithStorerKey',    -- Configkey
                    @b_Success                  OUTPUT,
                    @c_GenEmptyLOCWithStorerKey OUTPUT,
                    @n_Err                      OUTPUT,
                    @c_ErrMsg                   OUTPUT

            IF @b_Success <> 1 OR @c_GenEmptyLOCWithStorerKey <> '1'
                SET @c_TempStorerKey = ''

            -- Start : SOS66279
            IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) WHERE Stocktakekey = @c_StockTakeKey)
                BEGIN
                    -- End : SOS66279
                    SELECT @c_SQL = N'INSERT INTO #RESULT '
                        -- Change by June 12.Mar.02  FBR063
                        --     + 'SELECT lot = space(10),loc,id = space(20),StorerKey = "' + @c_StorerKey + '"' + ',sku = space(20),'
                        --+ 'SELECT lot = SPACE(10),loc,id = SPACE(20),StorerKey = SPACE(10),sku = SPACE(20),'                                             -- ZG01
                        + 'SELECT lot = SPACE(10),loc,id = SPACE(20),StorerKey = N''' + ISNULL(RTRIM(@c_TempStorerKey), '') + ''' ' + ',sku = SPACE(20),'  -- ZG01
                        + 'Lottable01 = SPACE(18), Lottable02 = SPACE(18), Lottable03 = SPACE(18), Lottable04 = NULL, Lottable05 = NULL,'
                        + 'Lottable06 = SPACE(30), Lottable07 = SPACE(30), Lottable08 = SPACE(30), Lottable09 = SPACE(30), Lottable10 = SPACE(30),'
                        + 'Lottable11 = SPACE(30), Lottable12 = SPACE(30), Lottable13 = NULL, Lottable14 = NULL, Lottable15 = NULL,'
                        + 'Qty = 0,PutawayZone,LocLevel,Aisle = locAisle,Facility,CCLogicalLoc '
                        + 'FROM LOC (NOLOCK) '
                        + 'WHERE   LOC.Facility = N''' + ISNULL(RTrim(@c_Facility), '') + ''' '
                        + ISNULL(RTrim(@c_ZoneSQL), '') + ' ' + ISNULL(RTrim(@c_ZoneSQL2), '') + ' '
                        + ISNULL(RTrim(@c_AisleSQL), '') + ' ' + ISNULL(RTrim(@c_AisleSQL2), '') + ' '
                        + ISNULL(RTrim(@c_LevelSQL), '') + ' ' + ISNULL(RTrim(@c_LevelSQL2), '') + ' '
                        + ISNULL(RTrim(@c_HostWHCodeSQL), '') + ' ' + ISNULL(RTrim(@c_HostWHCodeSQL2), '') + ' '
                        --+ ISNULL(RTRIM(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm1SQL2), '') + ' '  --(Wan01)
                        --+ ISNULL(RTRIM(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm2SQL2), '') + ' '  --(Wan01)
                        --+ ISNULL(RTRIM(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm3SQL2), '') + ' '  --(Wan01)
                        --(Wan01) - START
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
                        + RTRIM(@c_StrategyLocSQL) + ' '                                                                --(Wan04)
                        --(Wan01) - END
                        -- Patches from IDSMY 31 Dec 2002
                        -- Remark by June 30.Oct.02 -- To prevent Syntax error, doesn't select from LOTXLOCXID table
                        --+ @c_SKUSQL + ' ' + @c_SKUSQL2 + ' '
                        -- Remark by SHONG 27th Mar 2003
                        -- Agency is not in LOC table
                        --+ @c_AgencySQL + ' ' + @c_AgencySQL2 + ' '
                        --+ @c_ABCSQL + ' ' + @c_ABCSQL2 + ' '
                        + 'AND LOC NOT IN (SELECT DISTINCT LOC FROM #RESULT) '

                    EXEC ( @c_SQL )
                    -- Start : SOS66279
                END
            ELSE
                BEGIN
                    SET @c_SQLOther = ''    -- (Wan01)
                    SELECT @c_SQL = N'INSERT INTO #RESULT '
                        --+ 'SELECT lot = SPACE(10),loc,id = SPACE(20),StorerKey = SPACE(10),sku = SPACE(20),'                                             -- ZG01
                        + 'SELECT lot = SPACE(10),loc,id = SPACE(20),StorerKey = N''' + ISNULL(RTRIM(@c_TempStorerKey), '') + ''' ' + ',sku = SPACE(20),'  -- ZG01
                        + 'Lottable01 = SPACE(18),Lottable02 = SPACE(18),Lottable03 = SPACE(18),Lottable04 = NULL,Lottable05 = NULL,'
                        + 'Lottable06 = SPACE(30), Lottable07 = SPACE(30), Lottable08 = SPACE(30), Lottable09 = SPACE(30), Lottable10 = SPACE(30),'
                        + 'Lottable11 = SPACE(30), Lottable12 = SPACE(30), Lottable13 = NULL, Lottable14 = NULL, Lottable15 = NULL,'
                        + 'Qty = 0,PutawayZone,LocLevel,Aisle = locAisle,Facility,CCLogicalLoc '
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
                                         + ISNULL(RTrim(@c_ZoneSQL), '') + ' ' + ISNULL(RTrim(@c_ZoneSQL2), '') + ' '
                                         + ISNULL(RTrim(@c_AisleSQL), '') + ' ' + ISNULL(RTrim(@c_AisleSQL2), '') + ' '
                                         + ISNULL(RTrim(@c_LevelSQL), '') + ' ' + ISNULL(RTrim(@c_LevelSQL2), '') + ' '
                                         + ISNULL(RTrim(@c_HostWHCodeSQL), '') + ' ' + ISNULL(RTrim(@c_HostWHCodeSQL2), '') + ' '

                       --(Wan01) - START
                       IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND
                          SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'loc'
                       BEGIN
                          SET @c_sqlOther = @c_sqlOther + ' '
                                          + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '')
                                          + ' '
                       END

                       IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND
                          SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'loc'
                       BEGIN
                          SET @c_sqlOther = @c_sqlOther + ' '
                                          + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                                          + ' '
                       END

                       IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND
                          SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'loc'
                       BEGIN
                          SET @c_sqlOther = @c_sqlOther + ' '
                                          + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '')
                                          + ' '
                       END
                       --(Wan01) - END
                    END
                    ELSE
                    BEGIN
                       SELECT @c_SQL = @c_SQL + ' '
                                         + 'JOIN STOCKTAKEPARM2 PARM2_LOC WITH (NOLOCK) '
                                         + ' ON  RTrim(LTrim(PARM2_LOC.Value)) = LOC.LOC '
                                         + ' AND UPPER(PARM2_LOC.Tablename) = ''LOC'' '
                                         + ' AND PARM2_LOC.Stocktakekey = N''' + ISNULL(RTrim(@c_StockTakeKey), '') + ''''
                    END
                    */
                    --(Wan06) - END
                    SELECT @c_sqlWhere = ' '
                        + 'WHERE LOC.Facility = N''' + ISNULL(RTrim(@c_Facility), '') + ''' '
                        + 'AND LOC NOT IN (SELECT DISTINCT LOC FROM #RESULT) '
                        + RTRIM(@c_StrategyLocSQL) + ' '                                                --(Wan04)
                    SELECT @c_SQL = @c_SQL + ' ' + @c_sqlWhere + ' ' + @c_SQLOther

                    EXEC ( @c_SQL )
                END
            -- End : SOS66279

        END


-- Check if UCC data exist (ung01)

    IF EXISTS( SELECT TOP 1 1
               FROM #RESULT R
                        JOIN UCC (NOLOCK) ON R.StorerKey = UCC.StorerKey
                   AND R.Sku = UCC.Sku
                   -- AND R.Lot = UCC.Lot -- if group by L05, lot is blank
                   AND R.Loc = UCC.Loc
                   AND R.Id = UCC.Id
                   AND UCC.Status BETWEEN '1' AND '2'
                        LEFT JOIN STORERCONFIG SC (NOLOCK) ON R.Storerkey = SC.Storerkey
                   AND SC.Configkey = 'TurnOffCCSheetUccCheck'
                   AND SC.Svalue = '1'  --NJOW05
               WHERE ISNULL(SC.Svalue,'')='')
        BEGIN
            RETURN
        END

DECLARE @c_lot  NVARCHAR(10),
@c_loc         NVARCHAR(10),
@c_id          NVARCHAR(18),
@c_sku         NVARCHAR(20),
@c_Lottable01 NVARCHAR(18),
@c_Lottable02 NVARCHAR(18),
@c_Lottable03 NVARCHAR(18),
@d_Lottable04  datetime,
@d_Lottable05  datetime,
@c_Lottable06        NVARCHAR(30),
@c_Lottable07        NVARCHAR(30),
@c_Lottable08        NVARCHAR(30),
@c_Lottable09        NVARCHAR(30),
@c_Lottable10        NVARCHAR(30),
@c_Lottable11        NVARCHAR(30),
@c_Lottable12        NVARCHAR(30),
@d_Lottable13        DATETIME,
@d_Lottable14        DATETIME,
@d_Lottable15        DATETIME,
@n_qty         int,
@c_Aisle       NVARCHAR(10),
@n_LocLevel    int,
@c_prev_Facility   NVARCHAR(5),
@c_prev_Aisle      NVARCHAR(10),
@n_prev_LocLevel   int,
@c_ccdetailkey     NVARCHAR(10),
@c_ccsheetno       NVARCHAR(10),
--    @n_err             int,
--    @c_errmsg          NVARCHAR(250),
@n_LineCount       int,
@c_PreLogLocation  NVARCHAR(18),
@c_CCLogicalLoc    NVARCHAR(18),
@n_SystemQty       int,
@c_PrevZone        NVARCHAR(10),
@c_PutawayZone     NVARCHAR(10)
, @c_PrevStorerkey   NVARCHAR(15)         --(Wan02)
, @c_PrevSku         NVARCHAR(20)         --(Wan02)
-- Change by SHONG
-- If default the PreXXX to BLANK, no count sheet # will generate, because prexxx = xxx cause xxx not
-- setup, equal to BLANK
SELECT @c_prev_Facility = " ", @c_prev_Aisle = "XX", @n_prev_LocLevel = 999, @c_PreLogLocation = '000',
       @c_prev_ID = 'XX', --NJOW04
       @c_prev_LOC = '000' --NJOW06

    SET @c_PrevStorerkey = ''                    --(Wan02)
    SET @c_PrevSku       = ''                    --(Wan02)
-- Start - SOS23776

/*
DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
FOR  SELECT lot, loc, id, StorerKey, sku, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
            CASE WHEN @c_WithQuantity = 'Y' THEN qty ELSE 0 END,
            Facility, Aisle, LocLevel, CCLogicalLoc, qty, PutawayZone
      FROM #RESULT
      ORDER BY Facility, PutawayZone, Aisle, LocLevel, CCLogicalLoc, Loc, SKU
OPEN cur_1
*/
DECLARE @c_bypassPAZone NVARCHAR(1)
, @c_CCSheetBySku NVARCHAR(1)             --(Wan02)
-- SOS# 263478 (Start)
-- SELECT @c_storerkey = SUBSTRING(@c_StorerSQL, CHARINDEX('"', @c_StorerSQL, 1),
--                       LEN(@c_StorerSQL) - CHARINDEX('"', @c_StorerSQL, 1))
-- SELECT @c_storerkey = RTrim(LTrim(REPLACE(@c_storerkey, '"', '')))

SELECT @c_storerkey = SUBSTRING(@c_StorerSQL, CHARINDEX('''', @c_StorerSQL, 1),
                                LEN(@c_StorerSQL) - CHARINDEX('''', @c_StorerSQL, 1))
SELECT @c_storerkey = RTrim(LTrim(REPLACE(@c_storerkey, '''', '')))
-- SOS# 263478 (End)

SELECT @b_success = 0

    Execute nspGetRight @c_Facility, -- facility
            @c_storerkey,  -- Storerkey
            null,          -- Sku
            'CCSHEETBYPASSPA',   -- Configkey
            @b_success     output,
            @c_bypassPAZone output,
            @n_err         output,
            @c_errmsg      output

    IF @c_bypassPAZone = '1'
        SELECT @c_bypassPAZone = 'Y'
    ELSE
        SELECT @c_bypassPAZone = 'N'

    /*
    IF @b_success <> 1 OR @c_bypassPAZone = '0'
       SELECT @c_bypassPAZone = 'N'
    ELSE
       SELECT @c_bypassPAZone = 'Y'
    */

--(Wan02) - START
    Execute nspGetRight
            @c_Facility          -- facility
        ,  @c_storerkey         -- Storerkey
        ,  null                 -- Sku
        ,  'CCSHEETBYSKU'       -- Configkey
        ,  @b_success           OUTPUT
        ,  @c_CCSheetBySku      OUTPUT
        ,  @n_err               OUTPUT
        ,  @c_errmsg            OUTPUT

    IF @c_CCSheetBySku = '1'
        BEGIN
            SET @c_CCSheetBySku = 'Y'
        END
    ELSE
        BEGIN
            SET @c_CCSheetBySku = 'N'
        END
    --(Wan02) - END

--NJOW04 Start
    Execute nspGetRight @c_Facility, -- facility
            @c_storerkey,  -- Storerkey
            null,          -- Sku
            'CCSHEETINCLUDEID',  -- Configkey
            @b_success     output,
            @c_CCSheetIncludeID output,
            @n_err         output,
            @c_errmsg      output

    IF @c_CCSheetIncludeID = '1'
        SELECT @c_CCSheetIncludeID = 'Y'
    ELSE
        SELECT @c_CCSheetIncludeID = 'N'

--(Wan05) - START
    SET @c_PartitionBy = ''
    SET @c_SortBy = ''
    IF  @c_CCSheetIncludeID = 'Y' OR  @c_bypassPAZone = 'Y' OR @c_CCSheetBySku = 'Y'
        BEGIN
            SET @c_PartitionBy = 'LOC.PutawayZone,LOC.LocAisle,LOC.LocLevel'
            SET @c_SortBy = 'LOC.CCLogicalLoc,LOC.Loc,LOTxLOCxID.ID,LOTxLOCxID.SKU'

            IF @c_CCSheetIncludeID = 'Y'
                BEGIN
                    SET @c_PartitionBy = 'LOC.PutawayZone,LOC.LocAisle,LOC.LocLevel,LOC.CCLogicalLoc,LOC.Loc,LOTxLOCxID.SKU,LOTxLOCxID.ID'
                    SET @c_SortBy = 'LOTxLOCxID.Lot'
                END

            IF @c_bypassPAZone = 'Y'
                BEGIN
                    SET @c_PartitionBy = REPLACE(@c_PartitionBy,'LOC.PutawayZone,', '')
                    SET @c_PartitionBy = REPLACE(@c_PartitionBy,'LOC.PutawayZone', '')
                END

            IF @c_CCSheetBySku = 'Y'
                BEGIN
                    SET @c_PartitionBy = 'LOTxLOCxID.Storerkey,LOTxLOCxID.SKU,LOC.LocAisle'
                    SET @c_SortBy = 'LOTxLOCxID.ID'
                END

            IF RTRIM(@c_PartitionBy) <> ''
                BEGIN
                    SET  @c_SortBy = @c_PartitionBy + ',' + @c_SortBy
                END
        END
    ELSE
        BEGIN
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
        END

    SET @c_SheetLineColumn = ', SheetLineNo = ROW_NUMBER() OVER (ORDER BY LOC.Facility,LOTxLOCxID.Storerkey)'
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


    SET @c_SQL2 = 'DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
               FOR  SELECT R.lot, R.loc, R.id, R.StorerKey, R.sku,
               R.Lottable01, R.Lottable02, R.Lottable03, R.Lottable04, R.Lottable05,
               R.Lottable06, R.Lottable07, R.Lottable08, R.Lottable09, R.Lottable10,
               R.Lottable11, R.Lottable12, R.Lottable13, R.Lottable14, R.Lottable15,
               CASE WHEN N''' + @c_WithQuantity + ''' = ''Y'' THEN R.qty ELSE 0 END,
               R.Facility, R.Aisle, '
        +  CASE WHEN @c_CCSheetBySku = 'N' THEN 'R.LocLevel' ELSE ''''' AS LocLevel' END                                       --(Wan02)
        + ', R.CCLogicalLoc, R.qty, '
        +  CASE WHEN @c_bypassPAZone = 'N' AND @c_CCSheetBySku = 'N' THEN 'R.PutawayZone ' ELSE ''''' AS PutawayZone ' END     --(Wan02)
        + @c_SheetLineColumn
        + @c_RowRefColumn
        + ' FROM #RESULT R'
        + ' JOIN LOC WITH (NOLOCK) ON (R.Loc = LOC.Loc)'
        + ' LEFT JOIN LOTxLOCxID WITH (NOLOCK) ON  (R.Lot = LOTxLOCxID.Lot)'
        +  ' AND (R.Loc = LOTxLOCxID.Loc)'
        +  ' AND (R.ID  = LOTxLOCxID.ID)'
        + ' ORDER BY RowRef'

/*
SELECT @c_SQL2 = 'DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
                   FOR  SELECT lot, loc, id, StorerKey, sku, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
                  Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
                  Lottable11, Lottable12, Lottable13, Lottable14, Lottable15,
                   CASE WHEN N''' + @c_WithQuantity + ''' = ''Y'' THEN qty ELSE 0 END,
                   Facility, Aisle, '
               +  CASE WHEN @c_CCSheetBySku = 'N' THEN 'LocLevel' ELSE ''''' AS LocLevel' END                                       --(Wan02)
               + ', CCLogicalLoc, qty, '
               +  CASE WHEN @c_bypassPAZone = 'N' AND @c_CCSheetBySku = 'N' THEN 'PutawayZone ' ELSE ''''' AS PutawayZone ' END     --(Wan02)


               + ' FROM #RESULT ' +
                   CASE WHEN @c_CCSheetBySku = 'Y' THEN ' ORDER BY StorerKey, Sku, Aisle, ID'                                       --(Wan02)
                        WHEN @c_bypassPAZone = 'N' AND @c_CCSheetIncludeID = 'N'  THEN ' ORDER BY Facility, PutawayZone, Aisle, LocLevel, CCLogicalLoc, Loc, ID, SKU ' --NJOW06
                        WHEN @c_bypassPAZone = 'N' AND @c_CCSheetIncludeID = 'Y'  THEN ' ORDER BY Facility, PutawayZone, Aisle, LocLevel, CCLogicalLoc, Loc, SKU, ID, Lot '
                        WHEN @c_bypassPAZone = 'Y' AND @c_CCSheetIncludeID = 'N'  THEN ' ORDER BY Facility, Aisle, LocLevel, CCLogicalLoc, Loc, ID, SKU '  --NJOW06
                        WHEN @c_bypassPAZone = 'Y' AND @c_CCSheetIncludeID = 'Y'  THEN ' ORDER BY Facility, Aisle, LocLevel, CCLogicalLoc, Loc, SKU, ID, Lot '
                   END
                */
--(Wan05) - END

    EXEC (@c_SQL2)
    --NJOW04 End

/*
IF @c_bypassPAZone = 'N'
BEGIN
   EXEC ('DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
         FOR  SELECT lot, loc, id, StorerKey, sku, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
               CASE WHEN N''' + @c_WithQuantity + ''' = ''Y'' THEN qty ELSE 0 END,
               Facility, Aisle, LocLevel, CCLogicalLoc, qty, PutawayZone
         FROM #RESULT
         ORDER BY Facility, PutawayZone, Aisle, LocLevel, CCLogicalLoc, Loc, SKU')
END
ELSE
BEGIN
   EXEC ('DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
         FOR  SELECT lot, loc, id, StorerKey, sku, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
               CASE WHEN N''' + @c_WithQuantity + ''' = ''Y'' THEN qty ELSE 0 END,
               Facility, Aisle, LocLevel, CCLogicalLoc, qty, "" as PutawayZone
         FROM #RESULT
         ORDER BY Facility, Aisle, LocLevel, CCLogicalLoc, Loc, SKU')
END
*/

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

            FETCH NEXT FROM cur_1 INTO @c_lot, @c_loc, @c_id, @c_StorerKey, @c_sku,
                @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
                @n_qty, @c_Facility, @c_Aisle, @n_LocLevel, @c_CCLogicalLoc, @n_SystemQty, @c_PutawayZone
                , @n_SheetLineNo, @n_RowRef              ---(Wan05)

            WHILE @@FETCH_STATUS <> -1
                BEGIN
                    -- select @c_Aisle '@c_Aisle', @c_prev_Aisle '@c_prev_Aisle', @n_LocLevel '@n_LocLevel', @n_prev_LocLevel '@n_prev_LocLevel'
                    IF ((@n_LineCount > @n_LinesPerPage
                        AND (ISNULL(@c_Loc,'') <> ISNULL(@c_prev_LOC,'')
                            OR ISNULL(@c_ID,'') <> ISNULL(@c_prev_ID,'') )
                            ) --NJOW06
                    --(Wan05) - START
                        OR @n_SheetLineNo = 1) AND @c_IsLOCPerPage = 'N'   --WL01

                    --OR RTrim(@c_PutawayZone) <> RTrim(@c_PrevZone)
                    --OR RTrim(@c_Aisle) <> RTrim(@c_prev_Aisle)
                    --OR RTrim(@n_LocLevel) <> RTrim(@n_prev_LocLevel)
                    --OR (ISNULL(@c_ID,'') <> ISNULL(@c_prev_ID,'') AND @c_CCSheetIncludeID = 'Y')   --NJOW04
                    --OR (    (ISNULL(@c_StorerKey,'') <> ISNULL(@c_PrevStorerkey,'')                  --(Wan02)
                    --    OR   ISNULL(@c_Sku,'') <> ISNULL(@c_PrevSku,'')) AND @c_CCSheetBySku = 'Y' ) --(Wan02)
                    --(Wan05) - END

                        BEGIN
                            EXECUTE nspg_getkey
                                --'CCSheetNo'
                                    @c_CCSheetNoKeyName --NJOW03
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

                    EXECUTE nspg_getkey
                            'CCDetailKey'
                        , 10
                        , @c_CCDetailKey OUTPUT
                        , @b_success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT
                    IF RTrim(@c_lot) <> '' AND RTrim(@c_lot) IS NOT NULL
                        BEGIN
                            INSERT CCDETAIL (cckey, ccdetailkey, StorerKey, sku, lot, loc, id, qty, ccsheetno,
                                             Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
                                             Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
                                             Lottable11, Lottable12, Lottable13, Lottable14, Lottable15, SystemQty)
                            VALUES (@c_StockTakeKey, @c_CCDetailKey, @c_StorerKey, @c_sku, @c_lot, @c_loc, @c_id, @n_qty, @c_CCSheetNo,
                                    @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                                    @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                    @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15, @n_SystemQty)
                        END
                    ELSE
                        BEGIN

                            INSERT CCDETAIL (cckey, ccdetailkey, StorerKey, sku, lot, loc, id, qty, ccsheetno,
                                             Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
                                             Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
                                             Lottable11, Lottable12, Lottable13, Lottable14, Lottable15, SystemQty, Status)
                            VALUES (@c_StockTakeKey, @c_CCDetailKey, @c_StorerKey, @c_sku, @c_lot, @c_loc, @c_id, @n_qty, @c_CCSheetNo,
                                    @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                                    @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                    @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,  @n_SystemQty,
                                    CASE WHEN @n_SystemQty = 0 THEN '4' ELSE '0' END)

                        END

                    SELECT @n_LineCount = @n_LineCount + 1

                    --(Wan05) - START
                    SET   @c_prev_ID = @c_ID   --NJOW04
                    SET   @c_prev_LOC = @c_Loc --NJOW06
                    /*
                    SELECT @c_prev_Aisle = @c_Aisle,
                          @n_prev_LocLevel = @n_LocLevel,
                          @c_PreLogLocation = @c_CCLogicalLoc,
                          @c_PrevZone = @c_PutawayZone,
                          @c_prev_ID = @c_ID, --NJOW04
                          @c_prev_LOC = @c_Loc --NJOW06

                    SET @c_PrevStorerkey = @c_Storerkey --(Wan02)
                    SEt @c_PrevSku       = @c_Sku       --(Wan02)
                    */

                    --(Wan05) - END
                    FETCH NEXT FROM cur_1 INTO @c_lot, @c_loc, @c_id, @c_StorerKey, @c_sku,
                        @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                        @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                        @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
                        @n_qty, @c_Facility, @c_Aisle, @n_LocLevel, @c_CCLogicalLoc, @n_SystemQty, @c_PutawayZone
                        , @n_SheetLineNo, @n_RowRef              ---(Wan05)
                END -- WHILE
            CLOSE cur_1
            DEALLOCATE cur_1
        END -- SOS23776

    DROP TABLE #RESULT

--(Wan07) - START

    EXEC ispPostGenCountSheet_Wrapper
         @c_StockTakeKey= @c_StockTakeKey
        ,  @c_StorerKey   = @c_StorerKey
--(Wan07) - END
-- return results

-- SELECT CCDETAIL.ccsheetno,
-- CCDETAIL.lot,
-- CCDETAIL.loc,
-- CCDETAIL.id,
-- CCDETAIL.StorerKey,
-- CCDETAIL.sku,
-- SKU.descr,
-- CCDETAIL.Lottable01,
-- CCDETAIL.Lottable02,
-- CCDETAIL.Lottable03,
-- CCDETAIL.Lottable04,
-- CCDETAIL.Lottable05,
-- CCDETAIL.qty,
-- PACK.packuom3,
-- LOC.PutawayZone,
-- LOC.LocLevel,
-- LOC.locAisle,
-- LOC.Facility
-- FROM CCDETAIL (NOLOCK),
-- SKU (NOLOCK),
-- PACK (NOLOCK),
-- LOC (NOLOCK)
-- WHERE CCDETAIL.CCKEY = @c_StockTakeKey
-- AND   CCDETAIL.LOC = LOC.LOC
-- AND   CCDETAIL.StorerKey = SKU.StorerKey
-- AND   CCDETAIL.SKU = SKU.SKU
-- AND   SKU.PackKey = PACK.PackKey
-- UNION
-- SELECT CCDETAIL.ccsheetno,
-- CCDETAIL.lot,
-- CCDETAIL.loc,
-- CCDETAIL.id,
-- CCDETAIL.StorerKey,
-- CCDETAIL.sku,
-- '',
-- CCDETAIL.Lottable01,
-- CCDETAIL.Lottable02,
-- CCDETAIL.Lottable03,
-- CCDETAIL.Lottable04,
-- CCDETAIL.Lottable05,
-- CCDETAIL.qty,
-- '',
-- LOC.PutawayZone,
-- LOC.LocLevel,
-- LOC.locAisle,
-- LOC.Facility
-- FROM CCDETAIL (NOLOCK),  LOC (NOLOCK)
-- WHERE CCDETAIL.CCKEY = @c_StockTakeKey
-- AND   CCDETAIL.LOC = LOC.LOC
-- ORDER BY LOC.Facility, LOC.locAisle, LOC.LocLevel

END


GO