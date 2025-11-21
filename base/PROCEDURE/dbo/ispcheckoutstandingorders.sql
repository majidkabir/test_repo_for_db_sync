SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispCheckOutstandingOrders                          */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Check Outstanding Order in StockTake module                 */
/*                                                                      */
/* Called By: PB object nep_n_cst_stocktake_parm_new                    */
/*                                                                      */
/* PVCS Version: 1.5                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 11-Jul-2002  Shong      Bug fixed                                    */
/* 11-Sep-2002  Ricky      Merge Code from SOS, FBR and Performance     */
/*                         Tuning changes from July 13th till Aug23th   */
/* 01-Oct-2002  Shong      Added new parameters Agency code and ABC     */
/* 24-Nov-2003  Ricky      Extend the fields to NVARCHAR(250)           */
/* 03-Dec-2003  Shong      Bug fixed                                    */
/* 10-Nov-2005  MaryVong   SOS42806 Increase length of returned fields  */
/*                         from ispParseParameters to NVARCHAR(800)     */
/*                                                                      */
/* 18-Jan-2008  June       SOS66279 : Include STOCKTAKEPARM2 checking   */
/* 05-Aug-2010  NJOW01     182454 - Add skugroup parameter              */
/* 09-May-2011  NJOW02     201680 - Add exclude qty picked checking when*/
/*                                  calculate system qty                */
/* 10-Sep-2012  James      SOS255810 - Remove LTRIM & RTRIM function    */
/* 26-Mar-2015  NJOW03     315484-CC Post adj by pallet current loc     */
/* 30-MAR-2016  Wan01    1.2  SOS#366947: SG-Stocktake LocationRoom Parm*/
/* 16-JUN-2016  Wan02    1.3  SOS#366947: SOS#371185 - CN Carter's SH   */
/*                            WMS Cycle Count module                    */
/* 18-JUL-2016  Wan03    1.4  IN00099878: HK Fixed                      */
/* 29-JUN-2016  Wan04    1.5  SOS#370874 - TW Add Cycle Count Strategy  */
/* 24-NOV-2016  Wan05    1.6  WMS-648 - GW StockTake Parameter2         */
/*                            Enhancement                               */
/* 15-OCT-2024  SKB01    1.7  UWP-20468 joining PickDetail table to get */
/*                            Qty picked                                */
/************************************************************************/

CREATE    PROC ispCheckOutstandingOrders (
    @c_StockTakeKey NVARCHAR(10),
    @c_CountNo      NVARCHAR(1),
    @c_ByPalletLevel NVARCHAR(10) = 'N' -- NJOW03
)
AS
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @c_facility        NVARCHAR(5),
@c_StorerKey       NVARCHAR(18),
@c_StorerParm      NVARCHAR(60),
@c_AisleParm       NVARCHAR(60),
@c_LevelParm       NVARCHAR(60),
@c_ZoneParm        NVARCHAR(60),
@c_SKUParm         NVARCHAR(125),
@c_HostWHCodeParm  NVARCHAR(60),
@c_ClearHistory    NVARCHAR(1),
@c_WithQuantity    NVARCHAR(1),
@c_EmptyLocation   NVARCHAR(1),
@n_LinesPerPage    int,
-- Added by SHONG 01-Oct-2002
@c_AgencyParm      NVARCHAR(150),
@c_ABCParm         NVARCHAR(60),
@c_SkuGroupParm    NVARCHAR(125),
@c_ExcludeQtyPicked NVARCHAR(1)  --NJOW02
, @c_GenCCdetailbyExcludePKDStatus3 NVARCHAR(1)
, @c_PickDetailJoinQuery NVARCHAR(255) = ''        --(SKB01)
, @c_PickDetailQtyAddQuery NVARCHAR(255) = ''
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

, @c_ExcludeQtyAllocated     NVARCHAR(1)  --Wan02

--(Wan04) - START
DECLARE  @n_err            INT
,  @c_errmsg         NVARCHAR(255)
,  @c_StrategySQL    NVARCHAR(4000)
,  @c_StrategySkuSQL NVARCHAR(4000)
,  @c_StrategyLocSQL NVARCHAR(4000)
    --(Wan04) - END

--(Wan05) - START
DECLARE @c_SkuConditionSQL          NVARCHAR(MAX)
, @c_LocConditionSQL          NVARCHAR(MAX)
, @c_ExtendedConditionSQL1    NVARCHAR(MAX)
, @c_ExtendedConditionSQL2    NVARCHAR(MAX)
, @c_ExtendedConditionSQL3    NVARCHAR(MAX)
, @c_StocktakeParm2SQL        NVARCHAR(MAX)
, @c_StocktakeParm2OtherSQL   NVARCHAR(MAX)
    --(Wan05) - END

-- declare a SELECT condition variable for parameters
-- SOS42806 Changed NVARCHAR(250) and NVARCHAR(255) to NVARCHAR(800)
DECLARE @c_AisleSQL        NVARCHAR(800),
@c_LevelSQL        NVARCHAR(800),
@c_ZoneSQL         NVARCHAR(800),
@c_HostWHCodeSQL   NVARCHAR(800),
@c_AisleSQL2       NVARCHAR(800),
@c_LevelSQL2       NVARCHAR(800),
@c_ZoneSQL2        NVARCHAR(800),
@c_HostWHCodeSQL2  NVARCHAR(800),
@c_SKUSQL          NVARCHAR(800),
@c_SKUSQL2         NVARCHAR(800),
@c_StorerSQL       NVARCHAR(800),
@c_StorerSQL2      NVARCHAR(800),
@b_success         int,
@n_continue        int,
@b_debug           int,
@c_sourcekey       NVARCHAR(20),
@c_password        NVARCHAR(10),
@c_protect         NVARCHAR(1),
@c_AgencySQL       NVARCHAR(800),
@c_AgencySQL2      NVARCHAR(800),
@c_ABCSQL          NVARCHAR(800),
@c_ABCSQL2         NVARCHAR(800),
@c_SkuGroupSQL     NVARCHAR(800),
@c_SkuGroupSQL2    NVARCHAR(800),
@c_ExcludePickedSQL NVARCHAR(800)  --NJOW02
, @c_ExcludeQtyAllocatedSQL   NVARCHAR(1)  --Wan02
--(Wan01) - START
, @c_Extendedparm1SQL  NVARCHAR(800)
, @c_Extendedparm1SQL2 NVARCHAR(800)
, @c_Extendedparm2SQL  NVARCHAR(800)
, @c_Extendedparm2SQL2 NVARCHAR(800)
, @c_Extendedparm3SQL  NVARCHAR(800)
, @c_Extendedparm3SQL2 NVARCHAR(800)

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
    SET @c_ExcludeQtyAllocated  = ''   --Wan02

SELECT @c_Facility = Facility,
       @c_StorerParm = StorerKey,
       @c_AisleParm = AisleParm,
       @c_LevelParm = LevelParm,
       @c_ZoneParm = ZoneParm,
       @c_HostWHCodeParm = HostWHCodeParm,
       @c_SKUParm = SKUParm,
       @c_WithQuantity = WithQuantity,
       @c_ClearHistory = ClearHistory,
       @c_EmptyLocation = EmptyLocation,
       @n_LinesPerPage = LinesPerPage,
       @c_password = password,
       @c_protect = protect,
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
        , @c_ExcludeQtyAllocated= ExcludeQtyAllocated   --Wan02
FROM StockTakeSheetParameters (NOLOCK)
WHERE StockTakeKey = @c_StockTakeKey

    IF ISNULL(RTRIM(@c_StorerParm),'') = ''
        BEGIN
            SELECT @n_continue = 3
            RAISERROR ('Bad StorerKey', 16, 1)
            RETURN
        END

    IF @c_CountNo NOT IN ('1','2','3')
        BEGIN
            SELECT @n_continue = 3
            RAISERROR ('Bad Count Number.', 16, 1)
            RETURN
        END

SELECT @n_continue = 1, @b_debug = 0

    SET @c_GenCCdetailbyExcludePKDStatus3 = ''
    EXEC nspGetRight
         @c_Facility   = @c_Facility ,
         @c_StorerKey  = @c_StorerParm,
         @c_sku        = '',
         @c_ConfigKey  = 'GenCCdetailbyExcludePKDStatus3',
         @b_Success    = @b_Success OUTPUT,
         @c_authority  = @c_GenCCdetailbyExcludePKDStatus3  OUTPUT,
         @n_err        = @n_err   OUTPUT,
         @c_errmsg     = @c_errmsg  OUTPUT
    IF @b_Success<>1
        BEGIN
            RAISERROR('Error Executing nspGetRight', 16, 1)
            RETURN
        END
    IF @c_GenCCdetailbyExcludePKDStatus3 = '1'
        BEGIN
            SET @c_GenCCdetailbyExcludePKDStatus3 = 'Y'
            SET @c_PickDetailJoinQuery = 'LEFT JOIN PICKDETAIL WITH (NOLOCK) ON PICKDETAIL.Lot = LOTxLOCxID.Lot and PICKDETAIL.Loc = LOTxLOCxID.Loc and PICKDETAIL.ID = LOTxLOCxID.Id ' --(SKB01)
            SET @c_PickDetailQtyAddQuery = ' + CASE WHEN PICKDETAIL.Status=''3'' THEN PICKDETAIL.Qty ELSE 0 END '
        END
    ELSE
        SET @c_GenCCdetailbyExcludePKDStatus3 = 'N'

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
         'LOC.LOCLEVEL',
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

    EXEC ispParseParameters
         @c_StorerParm,
         'string',
         'LOTxLOCxID.StorerKey',
         @c_StorerSQL OUTPUT,
         @c_StorerSQL2 OUTPUT,
         @b_success OUTPUT

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

    IF @n_continue = 1 OR @n_continue = 2
        BEGIN
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
                    SET @n_Continue = 3
                    RAISERROR('Error Executing ispCCStrategy', 16, 1)
                    RETURN
                END
            --(Wan04) - END

            --(Wan05) - START
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
                ,  @c_ByPalletLevel   = @c_ByPalletLevel
                ,  @c_SkuConditionSQL = @c_SkuConditionSQL
                ,  @c_LocConditionSQL = @c_LocConditionSQL
                ,  @c_ExtendedConditionSQL1 = @c_ExtendedConditionSQL1
                ,  @c_ExtendedConditionSQL2 = @c_ExtendedConditionSQL2
                ,  @c_ExtendedConditionSQL3 = @c_ExtendedConditionSQL3
                ,  @c_StocktakeParm2SQL = @c_StocktakeParm2SQL OUTPUT
                ,  @c_StocktakeParm2OtherSQL = @c_StocktakeParm2OtherSQL OUTPUT
            --(Wan05) - END
            -- Start : SOS66279
            IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) WHERE Stocktakekey = @c_StockTakeKey)
                BEGIN

                    -- End : SOS66279
                    --(Wan02) - START
                    --SELECT @c_ExcludePickedSQL = CASE WHEN @c_ExcludeQtyPicked = 'Y' THEN 'AND LOTxLOCxID.QtyAllocated > 0 ' ELSE 'AND LOTxLOCxID.QtyAllocated + QtyPicked > 0 ' END  --NJOW02

                    SET @c_ExcludePickedSQL = CASE WHEN @c_ExcludeQtyAllocated = 'N' AND @c_ExcludeQtyPicked = 'N' THEN 'AND LOTxLOCxID.Qtyallocated + LOTxLOCxID.Qtypicked ' + @c_PickDetailQtyAddQuery + ' > 0 '
                                                   WHEN @c_ExcludeQtyAllocated = 'N' AND @c_ExcludeQtyPicked = 'Y' THEN 'AND LOTxLOCxID.Qtyallocated > 0 '
                                                   WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'N' THEN 'AND LOTxLOCxID.QtyPicked ' + @c_PickDetailQtyAddQuery + ' > 0 '
                                                   WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'AND 1 = 2 '                    -- (Wan03) - 18-JUL-2016 Fixed
                        END
                    --(Wan02) - END
                    IF @c_ByPalletLevel = 'Y'
                        BEGIN
                            --NJOW03
                            EXEC ( 'SELECT Count(*) '
                                + 'FROM LOC WITH (NOLOCK) '
                                + 'JOIN LOTxLOCxID WITH (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC '
                                + 'JOIN SKU WITH (NOLOCK) ON SKU.Storerkey = LOTxLOCxID.Storerkey AND SKU.SKU = LOTxLOCxID.SKU '
                                + 'JOIN LOTATTRIBUTE WITH (NOLOCK) ON LOTATTRIBUTE.Lot = LOTxLOCxID.Lot '             --(Wan01)
                                +  @c_PickDetailJoinQuery                                                             --(SKB01)
                                + 'WHERE 1=1 '                                                                        --(SKB01)
                                +  @c_StorerSQL + ' ' + @c_StorerSQL2 + ' '
                                --+ 'AND LOTxLOCxID.QtyAllocated + QtyPicked > 0 '
                                + @c_ExcludePickedSQL + ' '
                                + 'AND LOC.facility = "' + @c_facility + '" '
                                + 'AND EXISTS (SELECT 1 FROM CCDETAIL CC (NOLOCK) WHERE CC.Storerkey = LOTXLOCXID.Storerkey AND CC.Id = LOTXLOCXID.ID '
                                + '            AND ISNULL(CC.ID,'''') <> '''' AND CC.CCKey = ''' + @c_StockTakeKey + ''') '
                                + @c_SKUSQL + ' ' + @c_SKUSQL2 + ' '
                                + @c_AgencySQL + ' ' + @c_AgencySQL2 + ' '
                                + @c_ABCSQL + ' ' + @c_ABCSQL2 + ' '
                                + @c_SkuGroupSQL + ' ' + @c_SkuGroupSQL2 + ' '
                                + @c_ExtendedParm1SQL + ' ' + @c_ExtendedParm1SQL2 + ' '  --(Wan01)
                                + @c_ExtendedParm2SQL + ' ' + @c_ExtendedParm2SQL2 + ' '  --(Wan01)
                                + @c_ExtendedParm3SQL + ' ' + @c_ExtendedParm3SQL2 + ' '  --(Wan01)
                                + @c_StrategySQL + ' '                                    --(Wan04)
                                )                                                       --(Wan01)

                        END
                    ELSE
                        BEGIN
                            EXEC ( 'SELECT Count(*) '
                                + 'FROM LOC WITH (NOLOCK) '
                                + 'JOIN LOTxLOCxID WITH (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC '
                                + 'JOIN SKU WITH (NOLOCK) ON SKU.Storerkey = LOTxLOCxID.Storerkey AND SKU.SKU = LOTxLOCxID.SKU '
                                + 'JOIN LOTATTRIBUTE WITH (NOLOCK) ON LOTATTRIBUTE.Lot = LOTxLOCxID.Lot '             --(Wan01)
                                +  @c_PickDetailJoinQuery                                                             --(SKB01)
                                + 'WHERE 1=1 '                                                                        --(SKB01)
                                +  @c_StorerSQL + ' ' + @c_StorerSQL2 + ' '
                                --+ 'AND LOTxLOCxID.QtyAllocated + QtyPicked > 0 '
                                + @c_ExcludePickedSQL + ' '
                                + 'AND LOC.facility = "' + @c_facility + '" '
                                + @c_ZoneSQL + ' ' + @c_ZoneSQL2 + ' '
                                + @c_AisleSQL + ' ' + @c_AisleSQL2 + ' '
                                + @c_LevelSQL + ' ' + @c_LevelSQL2 + ' '
                                + @c_HostWHCodeSQL + ' ' + @c_HostWHCodeSQL2 + ' '
                                + @c_SKUSQL + ' ' + @c_SKUSQL2 + ' '
                                + @c_AgencySQL + ' ' + @c_AgencySQL2 + ' '
                                + @c_ABCSQL + ' ' + @c_ABCSQL2 + ' '
                                + @c_SkuGroupSQL + ' ' + @c_SkuGroupSQL2  + ' '
                                + @c_ExtendedParm1SQL + ' ' + @c_ExtendedParm1SQL2 + ' '  --(Wan01)
                                + @c_ExtendedParm2SQL + ' ' + @c_ExtendedParm2SQL2 + ' '  --(Wan01)
                                + @c_ExtendedParm3SQL + ' ' + @c_ExtendedParm3SQL2 + ' '  --(Wan01)
                                + @c_StrategySQL + ' '                                    --(Wan04)
                                )                                                       --(Wan01)
                        END

                    -- Start : SOS66279
                END
            ELSE
                BEGIN
                    DECLARE @c_SQL   NVARCHAR(max),
                        @c_SQLOther        NVARCHAR(4000),
                        @c_SQLWhere        NVARCHAR(4000)

                    SELECT @c_SQLOther = ''

                    SELECT @c_SQL = N'SELECT Count(*) '
                        + 'FROM LOC WITH (NOLOCK) '
                        + 'JOIN LOTxLOCxID WITH (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC '
                        + 'JOIN SKU WITH (NOLOCK) ON SKU.Storerkey = LOTxLOCxID.Storerkey AND SKU.SKU = LOTxLOCxID.SKU '
                        + 'JOIN LOTATTRIBUTE WITH (NOLOCK) ON LOTATTRIBUTE.Lot = LOTxLOCxID.Lot '             --(Wan01)
                        +  @c_PickDetailJoinQuery                                                             --(SKB01)

                    --(Wan05) - START
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
                       SELECT @c_SQL = @c_SQL + ' '
                                          + 'JOIN STOCKTAKEPARM2 PARM2_SKU WITH (NOLOCK) '
                                          + '  ON PARM2_SKU.Storerkey = LOTxLOCxID.Storerkey '
                                          + ' AND RTRIM(LTRIM(PARM2_SKU.Value)) = LOTxLOCxID.SKU '
                                          + ' AND UPPER(PARM2_SKU.Tablename) = ''SKU'' '
                                          + ' AND PARM2_SKU.Stocktakekey = ''' + ISNULL(RTRIM(@c_StockTakeKey), '') + ''''
                    END

                    IF @c_ByPalletLevel <> 'Y' --NJOW03
                    BEGIN
                       IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK)
                                      WHERE Stocktakekey = @c_StockTakeKey
                                      AND   UPPER(Tablename) = 'LOC')
                       BEGIN
                          SELECT @c_SQLOther = @c_SQLOther + ' '
                                               + ISNULL(RTRIM(@c_ZoneSQL), '') + ' ' + ISNULL(RTRIM(@c_ZoneSQL2), '') + ' '
                                               + ISNULL(RTRIM(@c_AisleSQL), '') + ' ' + ISNULL(RTRIM(@c_AisleSQL2), '') + ' '
                                               + ISNULL(RTRIM(@c_LevelSQL), '') + ' ' + ISNULL(RTRIM(@c_LevelSQL2), '') + ' '
                                               + ISNULL(RTRIM(@c_HostWHCodeSQL), '') + ' ' + ISNULL(RTRIM(@c_HostWHCodeSQL2), '') + ' '
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
                                                + '  ON RTRIM(LTRIM(PARM2_LOC.Value)) = LOTxLOCxID.LOC '
                                                + ' AND UPPER(PARM2_LOC.Tablename) = ''LOC'' '
                                                + ' AND PARM2_LOC.Stocktakekey = ''' + ISNULL(RTRIM(@c_StockTakeKey), '') + ''''
                       END
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
                    --(Wan05) - END

                    --SELECT @c_ExcludePickedSQL = CASE WHEN @c_ExcludeQtyPicked = 'Y' THEN 'AND LOTxLOCxID.QtyAllocated > 0 ' ELSE 'AND LOTxLOCxID.QtyAllocated + QtyPicked > 0 ' END  --NJOW02
                    --(Wan02) - START
                    SET @c_ExcludePickedSQL = CASE WHEN @c_ExcludeQtyAllocated = 'N' AND @c_ExcludeQtyPicked = 'N' THEN 'AND LOTxLOCxID.Qtyallocated + LOTxLOCxID.Qtypicked ' + @c_PickDetailQtyAddQuery + ' > 0 '
                                                   WHEN @c_ExcludeQtyAllocated = 'N' AND @c_ExcludeQtyPicked = 'Y' THEN 'AND LOTxLOCxID.Qtyallocated > 0 '
                                                   WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'N' THEN 'AND LOTxLOCxID.QtyPicked ' + @c_PickDetailQtyAddQuery + ' > 0 '
                                                   WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'AND 1 = 2 '                    -- (Wan03) - 18-JUL-2016 Fixed
                        END
                    --(Wan02) - END
                    SELECT @c_SQLWhere = 'WHERE 1 = 1 '
                        + ISNULL(RTRIM(@c_StorerSQL), '') + ' ' + ISNULL(RTRIM(@c_StorerSQL2), '') + ' '
                         + 'AND LOC.facility = "' + ISNULL(RTRIM(@c_facility), '') + '" '
                        + @c_ExcludePickedSQL + ' '
                        --+ 'AND LOTxLOCxID.QtyAllocated + QtyPicked > 0 '
                        + ' ' + @c_StrategySQL + ' '             --(Wan04)

                    IF @c_ByPalletLevel = 'Y' --NJOW03
                        BEGIN
                            SELECT @c_SQLWhere = @c_SQLWhere
                                + ' AND EXISTS (SELECT 1 FROM CCDETAIL CC (NOLOCK) WHERE CC.Storerkey = LOTXLOCXID.Storerkey AND CC.Id = LOTXLOCXID.ID '
                                + '            AND ISNULL(CC.ID,'''') <> '''' AND CC.CCKey = ''' + RTRIM(ISNULL(@c_StockTakeKey,'')) + ''') '
                        END

                    SELECT @c_SQL = @c_SQL + ' ' + @c_SQLWhere + ' ' + @c_SQLOther

                    EXEC ( @c_SQL )

                END
            -- End : SOS66279

        END

GO