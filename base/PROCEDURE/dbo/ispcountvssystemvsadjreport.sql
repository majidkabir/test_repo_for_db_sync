SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispCountVsSystemVsAdjReport                         */
/* Creation Date  : 2005-05-19                                          */
/* Copyright      : IDS                                                 */
/* Written by     : Shong                                               */
/*                                                                      */
/* Purpose: normal receipt                                              */
/*                                                                      */
/* Called from: 1 (Stock Take )                                         */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 19-May-2005  Shong         Created                                   */
/* 29-Jun-2005  June          SOS35681 - change Storerkey to Uppercase  */
/*                            Inconsistent U/L case cause wrong AdjQty  */
/* 10-Nov-2005  MaryVong      SOS42806 Increase length of returned fields*/
/*                            from ispParseParameters to NVARCHAR(800)  */
/* 18-Jan-2008  June          SOS66279 : Include STOCKTAKEPARM2 checking*/
/* 05-Aug-2010  NJOW01        182454 - Add skugroup parameter           */
/* 28-MAR-2016  Wan01         SOS#366947: SG-Stocktake LocationRoom Parm*/
/* 29-JUN-2016  Wan03    1.3  SOS#370874 - TW Add Cycle Count Strategy  */
/* 24-NOV-2016  Wan04    1.4  WMS-648 - GW StockTake Parameter2         */
/*                            Enhancement                               */
/************************************************************************/

CREATE PROC [dbo].[ispCountVsSystemVsAdjReport] (
@c_StockTakeKey NVARCHAR(10),
@c_CountNo      NVARCHAR(1)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
      
DECLARE @c_facility     NVARCHAR(5),
        @c_StorerParm   NVARCHAR(60),
        @c_AisleParm    NVARCHAR(60),
        @c_LevelParm    NVARCHAR(60),
        @c_ZoneParm     NVARCHAR(60),
        @c_SKUParm      NVARCHAR(125),
        @c_HostWHCodeParm  NVARCHAR(60),
        @c_ClearHistory    NVARCHAR(1),
        @c_WithQuantity    NVARCHAR(1),
        @c_EmptyLocation   NVARCHAR(1),
        @n_LinesPerPage    int,
-- Added by SHONG 01 OCT 2002
        @c_AgencyParm      NVARCHAR(150),
        @c_ABCParm         NVARCHAR(60), 
        @b_success         int ,
        @c_SkuGroupParm    NVARCHAR(125)
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

-- declare a select condition variable for parameters
-- SOS42806 Changed NVARCHAR(250) and NVARCHAR(255) to NVARCHAR(800)
DECLARE @c_AisleSQL      NVARCHAR(800),
        @c_LevelSQL      NVARCHAR(800),
        @c_ZoneSQL       NVARCHAR(800),
        @c_HostWHCodeSQL   NVARCHAR(800),
        @c_AisleSQL2     NVARCHAR(800),
        @c_LevelSQL2     NVARCHAR(800),
        @c_ZoneSQL2      NVARCHAR(800),
        @c_HostWHCodeSQL2  NVARCHAR(800),
        @c_SKUSQL          NVARCHAR(800),
        @c_SKUSQL2         NVARCHAR(800),
        @c_StorerSQL       NVARCHAR(800),
        @c_StorerSQL2    NVARCHAR(800),
        @n_continue        int,
        @b_debug           int, 
        @c_sourcekey       NVARCHAR(20),
        @c_password        NVARCHAR(10),
        @c_protect         NVARCHAR(1),
        @c_AgencySQL       NVARCHAR(800),
        @c_AgencySQL2      NVARCHAR(800),
        @c_ABCSQL          NVARCHAR(800),
        @c_ABCSQL2         NVARCHAR(800),
        @c_AdjReasonCode   NVARCHAR(10),
        @c_AdjType         NVARCHAR(3),  
        @c_SkuGroupSQL     NVARCHAR(800),
        @c_SkuGroupSQL2    NVARCHAR(800)
      --(Wan01) - START
      , @c_Extendedparm1SQL  NVARCHAR(800)
      , @c_Extendedparm1SQL2 NVARCHAR(800)
      , @c_Extendedparm2SQL  NVARCHAR(800)
      , @c_Extendedparm2SQL2 NVARCHAR(800)
      , @c_Extendedparm3SQL  NVARCHAR(800)
      , @c_Extendedparm3SQL2 NVARCHAR(800)
      --(Wan01) - END

--(Wan03) - START
DECLARE  @n_err            INT 
      ,  @c_errmsg         NVARCHAR(255)
      ,  @c_StrategySQL    NVARCHAR(4000) 
      ,  @c_StrategySkuSQL NVARCHAR(4000) 
      ,  @c_StrategyLocSQL NVARCHAR(4000)        
--(Wan03) - END 

--(Wan04) - START
DECLARE @c_SkuConditionSQL          NVARCHAR(MAX)
      , @c_LocConditionSQL          NVARCHAR(MAX)
      , @c_ExtendedConditionSQL1    NVARCHAR(MAX)   
      , @c_ExtendedConditionSQL2    NVARCHAR(MAX)
      , @c_ExtendedConditionSQL3    NVARCHAR(MAX)
      , @c_StocktakeParm2SQL        NVARCHAR(MAX)
      , @c_StocktakeParm2OtherSQL   NVARCHAR(MAX)
--(Wan04) - END

-- Start : SOS66279
DECLARE @c_sql      NVARCHAR(max),
        @c_sqlOther NVARCHAR(4000),
        @c_sqlWhere NVARCHAR(4000),
        @c_sqlGroup NVARCHAR(4000) 

SELECT  @c_sqlOther = ''
-- End : SOS66279

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

SET NOCOUNT ON

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
       @c_AdjReasonCode = AdjReasonCode, 
       @c_AdjType    = AdjType,
       @c_SkuGroupParm = SkuGroupParm 
      --(Wan01) - START
      , @c_ExtendedParm1Field = ExtendedParm1Field
      , @c_ExtendedParm1      = ExtendedParm1 
      , @c_ExtendedParm2Field = ExtendedParm2Field
      , @c_ExtendedParm2      = ExtendedParm2 
      , @c_ExtendedParm3Field = ExtendedParm3Field 
      , @c_ExtendedParm3      = ExtendedParm3
      --(Wan01) - END
FROM StockTakeSheetParameters (NOLOCK)
WHERE StockTakeKey = @c_StockTakeKey
IF @c_StorerParm IS NULL 
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
  
select @n_continue = 1, @b_debug = 0
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

-- Generate WithDraw Stock from Lotxlocxid table
IF @b_debug = 1 
BEGIN
   select  dbo.fnc_RTrim(@c_facility) + '" '
       + dbo.fnc_RTrim(@c_ZoneSQL) + ' ' + dbo.fnc_RTrim(@c_ZoneSQL2) + ' '
       + dbo.fnc_RTrim(@c_AisleSQL) + ' ' + dbo.fnc_RTrim(@c_AisleSQL2) + ' '
       + dbo.fnc_RTrim(@c_LevelSQL) + ' ' + dbo.fnc_RTrim(@c_LevelSQL2) + ' '
       + dbo.fnc_RTrim(@c_HostWHCodeSQL) + ' ' + dbo.fnc_RTrim(@c_HostWHCodeSQL2) + ' ' 
       + dbo.fnc_RTrim(@c_SKUSQL) + ' ' + dbo.fnc_RTrim(@c_SKUSQL2) + ' '
       + dbo.fnc_RTrim(@c_StorerSQL) + ' ' + dbo.fnc_RTrim(@c_StorerSQL2)
END 

CREATE TABLE #System  (
      StorerKey char (15)  NULL ,
      SKU char (20)  NOT NULL ,
      Qty int NOT NULL,
      Lottable01 char (18)  NULL ,
      Lottable02 char (18)  NULL ,
      Lottable03 char (18)  NULL ,
      Lottable04 datetime NULL ,
      Lottable05 datetime NULL 
)
CREATE TABLE #CCount (
      StorerKey char (15)  NULL ,
      SKU char (20)  NOT NULL ,
      Qty int NOT NULL,
      Lottable01 char (18)  NULL ,
      Lottable02 char (18)  NULL ,
      Lottable03 char (18)  NULL ,
      Lottable04 datetime NULL ,
      Lottable05 datetime NULL 
)
CREATE TABLE #Adjustment (
      StorerKey char (15)  NULL ,
      SKU char (20)  NOT NULL ,
      Qty int NOT NULL,
      Lottable01 char (18)  NULL ,
      Lottable02 char (18)  NULL ,
      Lottable03 char (18)  NULL ,
      Lottable04 datetime NULL ,
      Lottable05 datetime NULL 
)


IF @n_continue = 1 OR @n_continue = 2 
BEGIN 
   --(Wan03) - START
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
   --(Wan03) - END

 --(Wan04) - START
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
   --(Wan04) - END
   -- Start : SOS66279
   IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) WHERE Stocktakekey = @c_StockTakeKey)
   BEGIN
   -- End : SOS66279
      SELECT @c_SQL = N'SELECT LOTxLOCxID.StorerKey, LOTxLOCxID.SKU, '
          + 'SUM(LOTxLOCxID.qty), '
          + 'ISNULL(LotAttribute.lottable01, ''''), ISNULL(LotAttribute.lottable02, ''''), '
          + 'ISNULL(LotAttribute.lottable03, ''''), LotAttribute.lottable04, '
          + 'LotAttribute.lottable05 '
          + 'FROM LOC (NOLOCK), LOTxLOCxID (NOLOCK), LotAttribute (NOLOCK), SKU (NOLOCK) '
          + 'WHERE LOC.LOC = LOTxLOCxID.LOC '
          + 'AND LOTxLOCxID.LOT = LotAttribute.LOT '
          + 'AND LOTxLOCxID.StorerKey = SKU.StorerKey '
          + 'AND LOTxLOCxID.SKU = SKU.SKU '
          + 'AND LOTxLOCxID.Qty > 0 ' 
          + 'AND LOC.facility = N''' + ISNULL(dbo.fnc_RTrim(@c_facility), '') + ''' '
          + ISNULL(dbo.fnc_RTrim(@c_ZoneSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ZoneSQL2), '') + ' '
          + ISNULL(dbo.fnc_RTrim(@c_AisleSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AisleSQL2), '') + ' '
          + ISNULL(dbo.fnc_RTrim(@c_LevelSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_LevelSQL2), '') + ' '
          + ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL2), '') + ' '
          + ISNULL(dbo.fnc_RTrim(@c_StorerSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_StorerSQL2), '') + ' '
          + ISNULL(dbo.fnc_RTrim(@c_SKUSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_SKUSQL2), '') + ' '
          + ISNULL(dbo.fnc_RTrim(@c_AgencySQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AgencySQL2), '') + ' '
          + ISNULL(dbo.fnc_RTrim(@c_ABCSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ABCSQL2), '') + ' '
          + ISNULL(dbo.fnc_RTrim(@c_SkuGroupSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_SkuGroupSQL2), '') + ' '
          + ISNULL(RTRIM(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm1SQL2), '') + ' '  --(Wan01)
          + ISNULL(RTRIM(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm2SQL2), '') + ' '  --(Wan01)
          + ISNULL(RTRIM(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm3SQL2), '') + ' '  --(Wan01)
          + RTRIM(@c_StrategySQL) + ' '                                                                   --(Wan03)
          + 'GROUP BY LOTxLOCxID.StorerKey, LOTxLOCxID.SKU, '
          + 'ISNULL(LotAttribute.lottable01, ''''), ISNULL(LotAttribute.lottable02, ''''), '
          + 'ISNULL(LotAttribute.lottable03, ''''), LotAttribute.lottable04, '
          + 'LotAttribute.lottable05 '
   -- Start : SOS66279
   END 
   ELSE
   BEGIN
      SELECT @c_SQL = N'SELECT LOTxLOCxID.StorerKey, LOTxLOCxID.SKU, '
          + 'SUM(LOTxLOCxID.qty), '
          + 'ISNULL(LotAttribute.lottable01, ''''), ISNULL(LotAttribute.lottable02, ''''), '
          + 'ISNULL(LotAttribute.lottable03, ''''), LotAttribute.lottable04, '
          + 'LotAttribute.lottable05 '
          + 'FROM LOC WITH (NOLOCK) '
          + 'JOIN LOTxLOCxID WITH (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC '
          + 'JOIN LotAttribute WITH (NOLOCK) ON LotAttribute.LOT = LOTxLOCxID.LOT '
          + 'JOIN SKU WITH (NOLOCK) ON SKU.Storerkey = LOTxLOCxID.Storerkey AND SKU.SKU = LOTxLOCxID.SKU '
      --(Wan04) - START
      SET @c_sql = @c_sql + @c_StocktakeParm2SQL
      SET @c_sqlOther = @c_sqlOther + @c_StocktakeParm2OtherSQL
      /*
      IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) 
                     WHERE Stocktakekey = @c_StockTakeKey
                     AND   UPPER(Tablename) = 'SKU')
      BEGIN
         SELECT @c_SQLOther = @c_SQLOther + ' ' 
                              + ISNULL(dbo.fnc_RTrim(@c_SKUSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_SKUSQL2), '') + ' '
                              + ISNULL(dbo.fnc_RTrim(@c_AgencySQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AgencySQL2), '') + ' ' 
                              + ISNULL(dbo.fnc_RTrim(@c_ABCSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ABCSQL2), '') + ' '
                              + ISNULL(dbo.fnc_RTrim(@c_SkuGroupSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_SkuGroupSQL2), '') + ' '
         
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
                               + 'ON  PARM2_SKU.Storerkey = LOTxLOCxID.Storerkey '
                               + 'AND dbo.fnc_RTrim(dbo.fnc_LTrim(PARM2_SKU.Value)) = LOTxLOCxID.SKU '
                               + 'AND UPPER(PARM2_SKU.Tablename) = ''SKU'' '
                               + 'AND PARM2_SKU.Stocktakekey = N''' + ISNULL(dbo.fnc_RTrim(@c_StockTakeKey), '') + ''''
      END

      IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) 
                     WHERE Stocktakekey = @c_StockTakeKey
                     AND   UPPER(Tablename) = 'LOC')
      BEGIN
         SELECT @c_SQLOther = @c_SQLOther + ' '        
                              + ISNULL(dbo.fnc_RTrim(@c_ZoneSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ZoneSQL2), '') + ' '
                              + ISNULL(dbo.fnc_RTrim(@c_AisleSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AisleSQL2), '') + ' '
                              + ISNULL(dbo.fnc_RTrim(@c_LevelSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_LevelSQL2), '') + ' '
                              + ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL2), '') + ' ' 

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
                               + 'ON  dbo.fnc_RTrim(dbo.fnc_LTrim(PARM2_LOC.Value)) = LOTxLOCxID.LOC '
                               + 'AND UPPER(PARM2_LOC.Tablename) = ''LOC'' '
                               + 'AND PARM2_LOC.Stocktakekey = N''' + ISNULL(dbo.fnc_RTrim(@c_StockTakeKey), '') + ''''
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
      --(Wan04) - END
      SELECT @c_SQLWhere = ' '                               
                           + 'WHERE LOTxLOCxID.Qty > 0 ' 
                           + 'AND LOC.facility = N''' + ISNULL(dbo.fnc_RTrim(@c_facility), '') + ''' '
                           + ISNULL(dbo.fnc_RTrim(@c_StorerSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_StorerSQL2), '') + ' '
                           + RTRIM(@c_StrategySQL) + ' '                                  --(Wan03)
      SELECT @c_SQLGroup = ' '                               
                           + 'GROUP BY LOTxLOCxID.StorerKey, LOTxLOCxID.SKU, '
                           + 'ISNULL(LotAttribute.lottable01, ''''), ISNULL(LotAttribute.lottable02, ''''), '
                           + 'ISNULL(LotAttribute.lottable03, ''''), LotAttribute.lottable04, '
                           + 'LotAttribute.lottable05 '

      SELECT @c_sql = @c_sql + ' ' + @c_sqlWhere + ' ' + @c_sqlOther + ' ' + @c_sqlGroup
   END

   INSERT INTO #System (StorerKey, SKU, Qty, LOTTABLE01, LOTTABLE02, LOTTABLE03, LOTTABLE04, LOTTABLE05)
   EXEC ( @c_SQL )
   -- End : SOS66279 
END

-- Generate Deposit Transaction From CCDETAIL Table
IF @n_continue = 1 OR @n_continue = 2 
BEGIN
   DECLARE @c_Checking NVARCHAR(255)

   SELECT @c_Checking = ''

   IF @c_CountNo = '1'
   BEGIN
      SELECT @c_Checking = 'AND CCDETAIL.QTY > 0 ' 
   END 
   IF @c_CountNo = '2'
   BEGIN
      SELECT @c_Checking = 'AND CCDETAIL.QTY_Cnt2 > 0 ' 
   END 
   IF @c_CountNo = '3'
   BEGIN
      SELECT @c_Checking = 'AND CCDETAIL.QTY_Cnt3 > 0 ' 
   END 


   INSERT INTO #CCount (StorerKey, SKU, Qty, LOTTABLE01, LOTTABLE02, LOTTABLE03, LOTTABLE04, LOTTABLE05)
   EXEC ( 'SELECT CCDETAIL.StorerKey, CCDETAIL.SKU, ' 
        +  'SUM(CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.qty '
        +  '     WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.qty_Cnt2 '
        +  '     WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.qty_Cnt3 '
        +  'END) As Qty, '
        +  'CASE WHEN ' + @c_CountNo + ' = 1 THEN ISNULL(CCDETAIL.lottable01,'''') '
        +  '     WHEN ' + @c_CountNo + ' = 2 THEN ISNULL(CCDETAIL.lottable01_Cnt2,'''') '
        +  '     WHEN ' + @c_CountNo + ' = 3 THEN ISNULL(CCDETAIL.lottable01_Cnt3,'''') '
        +  'END As Lottable01, '
        +  'CASE WHEN ' + @c_CountNo + ' = 1 THEN ISNULL(CCDETAIL.lottable02,'''') '
        +  '     WHEN ' + @c_CountNo + ' = 2 THEN ISNULL(CCDETAIL.lottable02_Cnt2,'''') '
        +  '     WHEN ' + @c_CountNo + ' = 3 THEN ISNULL(CCDETAIL.lottable02_Cnt3,'''') '
        +  'END As Lottable02, '
        +  'CASE WHEN ' + @c_CountNo + ' = 1 THEN ISNULL(CCDETAIL.lottable03,'''') '
        +  '     WHEN ' + @c_CountNo + ' = 2 THEN ISNULL(CCDETAIL.lottable03_Cnt2,'''') '
        +  '     WHEN ' + @c_CountNo + ' = 3 THEN ISNULL(CCDETAIL.lottable03_Cnt3,'''') '
        +  'END As Lottable03, '
        +  'CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.lottable04 '
        +  '     WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.lottable04_Cnt2 '
        +  '     WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.lottable04_Cnt3 '
        +  'END As Lottable04, '
        +  'CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.lottable05 '
        +  '     WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.lottable05_Cnt2 '
        +  '     WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.lottable05_Cnt3 '
        +  'END As Lottable05 '
        +  'FROM CCDETAIL (NOLOCK), SKU (NOLOCK) '
        +  'WHERE CCDETAIL.CCKEY = N''' + @c_StockTakeKey + ''' '
        +  'AND CCDETAIL.StorerKey = SKU.StorerKey '
        +  'AND CCDETAIL.SKU = SKU.SKU '
        +  @c_Checking 
        +  'GROUP BY CCDETAIL.StorerKey, CCDETAIL.SKU, ' 
        +  'CASE WHEN ' + @c_CountNo + ' = 1 THEN ISNULL(CCDETAIL.lottable01,'''') '
        +  '     WHEN ' + @c_CountNo + ' = 2 THEN ISNULL(CCDETAIL.lottable01_Cnt2,'''') '
        +  '     WHEN ' + @c_CountNo + ' = 3 THEN ISNULL(CCDETAIL.lottable01_Cnt3,'''') '
        +  'END, '
        +  'CASE WHEN ' + @c_CountNo + ' = 1 THEN ISNULL(CCDETAIL.lottable02,'''') '
        +  '     WHEN ' + @c_CountNo + ' = 2 THEN ISNULL(CCDETAIL.lottable02_Cnt2,'''') '
        +  '     WHEN ' + @c_CountNo + ' = 3 THEN ISNULL(CCDETAIL.lottable02_Cnt3,'''') '
        +  'END, '
        +  'CASE WHEN ' + @c_CountNo + ' = 1 THEN ISNULL(CCDETAIL.lottable03,'''') '
        +  '     WHEN ' + @c_CountNo + ' = 2 THEN ISNULL(CCDETAIL.lottable03_Cnt2,'''') '
        +  '     WHEN ' + @c_CountNo + ' = 3 THEN ISNULL(CCDETAIL.lottable03_Cnt3,'''') '
        +  'END, '
        +  'CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.lottable04 '
        +  '     WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.lottable04_Cnt2 '
        +  '     WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.lottable04_Cnt3 '
        +  'END, '
        +  'CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.lottable05 '
        +  '     WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.lottable05_Cnt2 '
        +  '     WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.lottable05_Cnt3 '
        +  'END ') 

   IF @@ERROR <> 0
   BEGIN
      SELECT @n_continue = 3
      RETURN
   END
END

IF @n_continue = 1 OR @n_continue = 2 
BEGIN 
   INSERT INTO #Adjustment (StorerKey, SKU, Qty, LOTTABLE01, LOTTABLE02, LOTTABLE03, LOTTABLE04, LOTTABLE05)
   EXEC ('SELECT AD.StorerKey, AD.SKU, '
       + 'SUM(AD.qty), '
       + 'ISNULL(LotAttribute.lottable01, ''''), ISNULL(LotAttribute.lottable02, ''''), '
       + 'ISNULL(LotAttribute.lottable03, ''''), LotAttribute.lottable04, '
       + 'LotAttribute.lottable05 '
       + 'FROM AdjustmentDetail  AD (NOLOCK), LotAttribute (NOLOCK), Adjustment AH (NOLOCK) '
       + 'WHERE AD.LOT = LotAttribute.LOT '
       + 'AND AD.AdjustmentKey = AH.AdjustmentKey ' 
       + 'AND AH.CustomerRefNo = N''' + @c_StockTakeKey + ''' ' 
       + 'GROUP BY AD.StorerKey, AD.SKU, '
       + 'ISNULL(LotAttribute.lottable01, ''''), ISNULL(LotAttribute.lottable02, ''''), '
       + 'ISNULL(LotAttribute.lottable03, ''''), LotAttribute.lottable04, '
       + 'LotAttribute.lottable05 ' )


END
-- Added By Vicky 23 Oct 2001
-- Update status = 3 in CCDETAIL table when generate posting is done
IF @n_continue = 1 OR @n_continue = 2 
BEGIN
   SELECT Storerkey = UPPER(CCount.StorerKey), CCount.SKU, CCount.Lottable01, CCount.Lottable02, CCount.Lottable03, CCount.Lottable04, CCount.Lottable05,
         ISNULL(Sys.Qty,0) as SysQty, CCount.Qty as CountQty, 0 as AdjQty 
    INTO #REPORT 
    FROM #CCount as CCount 
    LEFT OUTER JOIN #System as Sys ON CCount.StorerKey = Sys.StorerKey AND 
                           CCount.SKU = Sys.SKU AND 
                           CCount.Lottable01 = Sys.Lottable01 AND
                           CCount.Lottable02 = Sys.Lottable02 AND
                           CCount.Lottable03 = Sys.Lottable03 AND
                           ISNULL(CCount.Lottable04, '') = ISNULL(Sys.Lottable04, '') AND
                           ISNULL(CCount.Lottable05, '') = ISNULL(Sys.Lottable05, '')




  INSERT INTO #REPORT 
  SELECT Storerkey = UPPER(Sys.StorerKey), Sys.SKU, Sys.Lottable01, Sys.Lottable02, Sys.Lottable03, Sys.Lottable04, Sys.Lottable05,
         ISNULL(Sys.Qty,0) as SysQty, 0 as CountQty, 0 as AdjQty 
  FROM   #System Sys 
  LEFT OUTER JOIN #REPORT R ON R.StorerKey = Sys.StorerKey AND 
                           R.SKU = Sys.SKU AND
                           R.Lottable01 = Sys.Lottable01 AND
                           R.Lottable02 = Sys.Lottable02 AND
                           R.Lottable03 = Sys.Lottable03 AND
                           ISNULL(R.Lottable04, '') = ISNULL(Sys.Lottable04, '') AND
                           ISNULL(R.Lottable05, '') = ISNULL(Sys.Lottable05, '')
   WHERE R.Storerkey IS NULL 


   UPDATE #REPORT
      SET AdjQty = Adj.Qty
   FROM #REPORT R
   JOIN #Adjustment Adj ON Adj.StorerKey = R.StorerKey AND 
                           Adj.SKU = R.SKU AND
                           Adj.Lottable01 = R.Lottable01 AND
                           Adj.Lottable02 = R.Lottable02 AND
                           Adj.Lottable03 = R.Lottable03 AND
                           ISNULL(Adj.Lottable04, '') = ISNULL(R.Lottable04, '') AND
                           ISNULL(Adj.Lottable05, '') = ISNULL(R.Lottable05, '')

  INSERT INTO #REPORT 
  SELECT Storerkey = UPPER(Adj.StorerKey), Adj.SKU, Adj.Lottable01, Adj.Lottable02, Adj.Lottable03, Adj.Lottable04, Adj.Lottable05,
         0 as SysQty, 0 as CountQty, Adj.Qty 
  FROM   #Adjustment Adj 
  LEFT OUTER JOIN #REPORT R ON Adj.StorerKey = R.StorerKey AND 
          Adj.SKU = R.SKU AND
                           Adj.Lottable01 = R.Lottable01 AND
                           Adj.Lottable02 = R.Lottable02 AND
                           Adj.Lottable03 = R.Lottable03 AND
                           ISNULL(Adj.Lottable04, '') = ISNULL(R.Lottable04, '') AND
                           ISNULL(Adj.Lottable05, '') = ISNULL(R.Lottable05, '')
   WHERE R.Storerkey IS NULL 

   SELECT @c_Facility, 
          R.StorerKey, 
          R.SKU, SKU.DESCR, 
          R.Lottable01, 
          R.Lottable02, 
          R.Lottable03, 
          R.Lottable04, 
          R.Lottable05,
          R.SysQty, R.CountQty, R.AdjQty, 
          Storer.Company, 
          @c_StockTakeKey,
          @c_CountNo,
          PACK.PackUOM3            
   FROM #REPORT R 
   JOIN Storer (NOLOCK) ON Storer.StorerKey = R.StorerKey 
   JOIN SKU (NOLOCK) ON SKU.SKU = R.SKU AND SKU.StorerKey = R.StorerKey
   JOIN PACK (NOLOCK) ON SKU.PackKey = PACK.PACKKey 
   order by 1,2,3,4, 5, 6  

END

EXIT_SP:

END

GO