SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispGenCCPosting                                       */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: Post Cycle Count in StockTake module                           */
/*                                                                         */
/* Called By: PB object nep_n_cst_stocktake_parm_new                       */
/*                                                                         */
/* PVCS Version: 1.4                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author     Ver.  Purposes                                  */
/* 01-Oct-2002  Shong            Added new parameters Agency code and ABC  */
/* 10-Nov-2005  MaryVong         SOS42806 Increase length of returned fields*/
/*                               from ispParseParameters to CHAR(800)      */
/* 18-Jan-2008  June             SOS66279 : Include STOCKTAKEPARM2 checking*/
/* 05-Aug-2010  NJOW01           182454 - Add skugroup parameter           */
/* 21-May-2014  TKLIM            Added Lottables 06-15                     */
/* 30-MAR-2016  Wan01            SOS#366947: SG-Stocktake LocationRoom Parm*/
/* 29-JUN-2016  Wan02      1.3   SOS#370874 - TW Add Cycle Count Strategy  */
/* 24-NOV-2016  Wan04      1.4   WMS-648 - GW StockTake Parameter2         */
/*                               Enhancement                               */
/****************************************************************************/

CREATE PROC [dbo].[ispGenCCPosting] (
@c_StockTakeKey NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
      
   DECLARE  @c_facility       NVARCHAR(5),
            @c_StorerParm     NVARCHAR(150),
            @c_AisleParm      NVARCHAR(60),
            @c_LevelParm      NVARCHAR(60),
            @c_ZoneParm       NVARCHAR(60),
            @c_SKUParm        NVARCHAR(125),
            @c_HostWHCodeParm NVARCHAR(60),
            @c_ClearHistory   NVARCHAR(1),
            @c_WithQuantity   NVARCHAR(1),
            @c_EmptyLocation  NVARCHAR(1),
            @n_LinesPerPage   int,
            -- Added by SHONG 01-Oct-2002
            @c_AgencyParm     NVARCHAR(150),
            @c_ABCParm        NVARCHAR(60),
            @c_SkuGroupParm   NVARCHAR(125)  
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
   -- SOS42806 Changed NVARCHAR(120) and NVARCHAR(255) to NVARCHAR(800)
   DECLARE  @c_AisleSQL       NVARCHAR(800),
            @c_LevelSQL       NVARCHAR(800),
            @c_ZoneSQL        NVARCHAR(800),
            @c_HostWHCodeSQL  NVARCHAR(800),
            @c_AisleSQL2      NVARCHAR(800),
            @c_LevelSQL2      NVARCHAR(800),
            @c_ZoneSQL2       NVARCHAR(800),
            @c_HostWHCodeSQL2 NVARCHAR(800),
            @c_SKUSQL         NVARCHAR(800),
            @c_SKUSQL2        NVARCHAR(800),
            @b_success        int,
            @n_continue       int,
            @b_debug          int, 
            @c_sourcekey      NVARCHAR(20),
            @c_password       NVARCHAR(10),
            @c_protect        NVARCHAR(1),
            @c_AgencySQL      NVARCHAR(800),
            @c_AgencySQL2     NVARCHAR(800),
            @c_ABCSQL         NVARCHAR(800),
            @c_ABCSQL2        NVARCHAR(800),       
            @c_StorerSQL      NVARCHAR(800),
            @c_StorerSQL2     NVARCHAR(800), 
            @c_SkuGroupSQL    NVARCHAR(800),
            @c_SkuGroupSQL2   NVARCHAR(800) 
         --(Wan01) - START
         , @c_Extendedparm1SQL  NVARCHAR(800)
         , @c_Extendedparm1SQL2 NVARCHAR(800)
         , @c_Extendedparm2SQL  NVARCHAR(800)
         , @c_Extendedparm2SQL2 NVARCHAR(800)
         , @c_Extendedparm3SQL  NVARCHAR(800)
         , @c_Extendedparm3SQL2 NVARCHAR(800)
         --(Wan01) - END

   -- Start : SOS66279
   DECLARE  @c_SQL            NVARCHAR(max),
            @c_sqlOther       NVARCHAR(4000),
            @c_sqlWhere       NVARCHAR(4000)

   SELECT  @c_sqlOther = ''
   -- End : SOS66279

   --(Wan02) - START
   DECLARE  @n_err            INT 
         ,  @c_errmsg         NVARCHAR(255) 
         ,  @c_StrategySQL    NVARCHAR(4000) 
         ,  @c_StrategySkuSQL NVARCHAR(4000) 
         ,  @c_StrategyLocSQL NVARCHAR(4000) 
   --(Wan02) - END 

   --(Wan03) - START
   DECLARE @c_SkuConditionSQL             NVARCHAR(MAX)
            , @c_LocConditionSQL          NVARCHAR(MAX)
            , @c_ExtendedConditionSQL1    NVARCHAR(MAX)   
            , @c_ExtendedConditionSQL2    NVARCHAR(MAX)
            , @c_ExtendedConditionSQL3    NVARCHAR(MAX)
            , @c_StocktakeParm2SQL        NVARCHAR(MAX)
            , @c_StocktakeParm2OtherSQL   NVARCHAR(MAX)
   --(Wan03) - END

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
   SELECT   @c_Facility       = Facility,
            @c_StorerParm     = StorerKey,
            @c_AisleParm      = AisleParm,
            @c_LevelParm      = LevelParm,
            @c_ZoneParm       = ZoneParm,
            @c_HostWHCodeParm = HostWHCodeParm,
            @c_SKUParm        = SKUParm,
            @c_WithQuantity   = WithQuantity,
            @c_ClearHistory   = ClearHistory,
            @c_EmptyLocation  = EmptyLocation,
            @n_LinesPerPage   = LinesPerPage,
            @c_password       = password, 
            @c_protect        = protect,
            @c_AgencyParm     = AgencyParm,
            @c_ABCParm        = ABCParm,
            @c_SkuGroupParm   = SkuGroupParm  
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

   SELECT @n_continue = 1, @b_debug = 0


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

   -- Purge All the historical records for this stocktakekey if clear history flag = 'Y'
   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN
      BEGIN TRAN
      DELETE WithdrawStock
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_continue = 3
         RAISERROR ('Error Found Deleting WithdrawStock', 16, 1)
         ROLLBACK TRAN
         RETURN
      END
      ELSE
         COMMIT TRAN
   END
   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN
      BEGIN TRAN
      DELETE TempStock
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_continue = 3
         RAISERROR ('Error Found Deleting TempStock', 16, 1)
         ROLLBACK TRAN
         RETURN
      END
      ELSE
         COMMIT TRAN
   END
   -- Generate WithDraw Stock from Lotxlocxid table
   IF @b_debug = 1
   BEGIN
       select  dbo.fnc_RTrim(@c_facility) + '" '
          + dbo.fnc_RTrim(@c_ZoneSQL) + ' ' + dbo.fnc_RTrim(@c_ZoneSQL2) + ' '
          + dbo.fnc_RTrim(@c_AisleSQL) + ' ' + dbo.fnc_RTrim(@c_AisleSQL2) + ' '
          + dbo.fnc_RTrim(@c_LevelSQL) + ' ' + dbo.fnc_RTrim(@c_LevelSQL2) + ' '
          + dbo.fnc_RTrim(@c_HostWHCodeSQL) + ' ' + dbo.fnc_RTrim(@c_HostWHCodeSQL2) + ' '
          + dbo.fnc_RTrim(@c_SKUSQL) + ' ' + dbo.fnc_RTrim(@c_SKUSQL2)
   END
   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN 
      BEGIN TRAN

      --(Wan02) - START
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
         ROLLBACK TRAN
         RETURN 
      END
      --(Wan02) - END

      --(Wan03) - START
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
   
      --(Wan03) - END

      -- Start : SOS66279
      IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) WHERE Stocktakekey = @c_StockTakeKey)
      BEGIN
      -- End : SOS66279
         SELECT @c_SQL = N'INSERT INTO WITHDRAWSTOCK (StorerKey, SKU, LOT, ID, LOC, Qty, '
                        + 'Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, '
                        + 'Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, '
                        + 'Lottable11, Lottable12, Lottable13, Lottable14, Lottable15, '
                        + 'Sourcekey, Sourcetype) '
                        + 'SELECT LOTxLOCxID.StorerKey, LOTxLOCxID.SKU, LOTxLOCxID.LOT, '
                        + 'LOTxLOCxID.id, LOTxLOCxID.loc, LOTxLOCxID.qty, '
                        + 'LotAttribute.Lottable01, LotAttribute.Lottable02, LotAttribute.Lottable03, LotAttribute.Lottable04, LotAttribute.Lottable05, '
                        + 'LotAttribute.Lottable06, LotAttribute.Lottable07, LotAttribute.Lottable08, LotAttribute.Lottable09, LotAttribute.Lottable10, '
                        + 'LotAttribute.Lottable11, LotAttribute.Lottable12, LotAttribute.Lottable13, LotAttribute.Lottable14, LotAttribute.Lottable15, '
                        + '" ",'
                        + '"CC Withdrawal (' +  @c_stocktakekey + ')" '
                        + 'FROM LOC (NOLOCK), LOTxLOCxID (NOLOCK), LotAttribute (NOLOCK), SKU (NOLOCK) '
                        + 'WHERE LOC.LOC = LOTxLOCxID.LOC '
                        + 'AND LOTxLOCxID.StorerKey = SKU.StorerKey '
                        + 'AND LOTxLOCxID.SKU = SKU.SKU '
                        + 'AND LOTxLOCxID.LOT = LotAttribute.LOT '
                        + 'AND LOTxLOCxID.Qty > 0 ' 
                        + 'AND LOC.facility = N''' + ISNULL(dbo.fnc_RTrim(@c_facility), '') + ''' '
                        + ISNULL(dbo.fnc_RTrim(@c_StorerSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_StorerSQL2), '')
                        + ISNULL(dbo.fnc_RTrim(@c_ZoneSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ZoneSQL2), '') + ' '
                        + ISNULL(dbo.fnc_RTrim(@c_AisleSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AisleSQL2), '') + ' '
                        + ISNULL(dbo.fnc_RTrim(@c_LevelSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_LevelSQL2), '') + ' '
                        + ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL2), '') + ' '
                        + ISNULL(dbo.fnc_RTrim(@c_SKUSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_SKUSQL2), '') + ' '
                        + ISNULL(dbo.fnc_RTrim(@c_AgencySQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AgencySQL2), '') + ' '
                        + ISNULL(dbo.fnc_RTrim(@c_ABCSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ABCSQL2), '') + ' '
                        + ISNULL(dbo.fnc_RTrim(@c_SkuGroupSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_SkuGroupSQL2), '')
                        + ISNULL(RTRIM(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm1SQL2), '') + ' '  --(Wan01)
                        + ISNULL(RTRIM(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm2SQL2), '') + ' '  --(Wan01)
                        + ISNULL(RTRIM(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm3SQL2), '') + ' '  --(Wan01)
                        + RTRIM(@c_StrategySQL) + ' '                                                                   --(Wan02)
      -- Start : SOS66279
      END 
      ELSE
      BEGIN
         SELECT @c_SQL = N'INSERT INTO WITHDRAWSTOCK (StorerKey, SKU, LOT, ID, LOC, Qty, '
                        + 'Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, '
                        + 'Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, '
                        + 'Lottable11, Lottable12, Lottable13, Lottable14, Lottable15, '
                        + 'Sourcekey, Sourcetype) '
                        + 'SELECT LOTxLOCxID.StorerKey, LOTxLOCxID.SKU, LOTxLOCxID.LOT, '
                        + 'LOTxLOCxID.id, LOTxLOCxID.loc, LOTxLOCxID.qty, '
                        + 'LotAttribute.Lottable01, LotAttribute.Lottable02, LotAttribute.Lottable03, LotAttribute.Lottable04, LotAttribute.Lottable05, '
                        + 'LotAttribute.Lottable06, LotAttribute.Lottable07, LotAttribute.Lottable08, LotAttribute.Lottable09, LotAttribute.Lottable10, '
                        + 'LotAttribute.Lottable11, LotAttribute.Lottable12, LotAttribute.Lottable13, LotAttribute.Lottable14, LotAttribute.Lottable15, '
                        + '" ",'
                        + '"CC Withdrawal (' +  @c_stocktakekey + ')" '
                        + 'FROM LOC WITH (NOLOCK) ' 
                        + 'JOIN LOTxLOCxID WITH (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC ' 
                        + 'JOIN LotAttribute WITH (NOLOCK) ON LotAttribute.LOT = LOTxLOCxID.LOT '
                        + 'JOIN SKU WITH (NOLOCK) ON SKU.Storerkey = LOTxLOCxID.Storerkey AND SKU.SKU = LOTxLOCxID.SKU '

         --(Wan03) - START
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
                                  + 'AND PARM2_SKU.Stocktakekey = ''' + ISNULL(dbo.fnc_RTrim(@c_StockTakeKey), '') + ''''
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
                                  + ' ON dbo.fnc_RTrim(dbo.fnc_LTrim(PARM2_LOC.Value)) = LOTxLOCxID.LOC '
                                  + 'AND UPPER(PARM2_LOC.Tablename) = ''LOC'' '
                                  + 'AND PARM2_LOC.Stocktakekey = ''' + ISNULL(dbo.fnc_RTrim(@c_StockTakeKey), '') + ''''
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
         --(Wan03) - END        
         SELECT @c_SQLWhere = ' '
                               + 'WHERE LOTxLOCxID.Qty > 0 ' 
                               + 'AND LOC.facility = N''' + ISNULL(dbo.fnc_RTrim(@c_facility), '') + ''' '
                               + ISNULL(dbo.fnc_RTrim(@c_StorerSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_StorerSQL2), '') 
                               + RTRIM(@c_StrategySQL) + ' '                                 --(Wan02)
         SELECT @c_sql = @c_sql + ' ' + @c_sqlWhere + ' ' + @c_sqlOther 
      END

      EXEC ( @c_SQL )
      -- End : SOS66279

      -- Added By Vicky 23 Oct 2001  
      UPDATE Withdrawstock
      SET    sourcekey = CCDetail.CCdetailkey
      FROM    CCDetail
      WHERE CCDetail.Lot = Withdrawstock.Lot
      AND   CCDetail.Loc = Withdrawstock.Loc
      AND   CCDetail.ID  = Withdrawstock.ID   
      AND   CCDetail.Storerkey = Withdrawstock.Storerkey
      AND   CCDetail.SKu = Withdrawstock.SKu
      AND   CCDetail.CCkey = @c_stocktakekey
      if (select count(sourcekey) 
      from withdrawstock (nolock)
      where sourcekey = '' or sourcekey is null) > 0
      update withdrawstock
      set sourcekey = @c_stocktakekey
      where sourcekey = '' or sourcekey is null
      IF @@ERROR <> 0
       BEGIN
          SELECT @n_continue = 3
          RAISERROR ('Error Found during inserting records into WithdrawStock.', 16, 1)
          ROLLBACK TRAN
          RETURN
       END
       ELSE
         COMMIT TRAN
   END
   -- Generate Deposit Transaction From CCDETAIL Table
   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN
      BEGIN TRAN
      EXEC ( 'INSERT INTO TempStock (StorerKey, SKU, ID, LOC, Qty, '
            + 'Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, '
            + 'Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, '
            + 'Lottable11, Lottable12, Lottable13, Lottable14, Lottable15, '
            + 'Sourcekey, Sourcetype) '
            + 'SELECT CCDETAIL.StorerKey, CCDETAIL.SKU, '
            + 'CCDETAIL.id, CCDETAIL.loc, CCDETAIL.qty, '
            + 'CCDETAIL.Lottable01, CCDETAIL.Lottable02, CCDETAIL.Lottable03, CCDETAIL.Lottable04, CCDETAIL.Lottable05, '
            + 'CCDETAIL.Lottable06, CCDETAIL.Lottable07, CCDETAIL.Lottable08, CCDETAIL.Lottable09, CCDETAIL.Lottable10, '
            + 'CCDETAIL.Lottable11, CCDETAIL.Lottable12, CCDETAIL.Lottable13, CCDETAIL.Lottable14, CCDETAIL.Lottable15, '
            + 'CCDETAIL.CCDetailKey,' 
            + '"CC Deposit (' + @c_stocktakekey + ')"'
            + 'FROM CCDETAIL (NOLOCK), SKU (NOLOCK) '
            + 'WHERE CCDETAIL.CCKEY = N''' + @c_StockTakeKey + ''' '
            + 'AND CCDETAIL.STORERKEY = SKU.STORERKEY '
            + 'AND CCDETAIL.SKU = SKU.SKU '
            +  'AND CCDETAIL.QTY > 0 ' )
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_continue = 3
         RAISERROR ('Error Found during inserting records into TempStock.', 16, 1)
         ROLLBACK TRAN
         RETURN
      END
      ELSE
         COMMIT TRAN
   END
   -- Added By Vicky 23 Oct 2001
   -- Update status = 3 in CCDETAIL table when generate posting is done
   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN
      BEGIN TRAN
      UPDATE CCDETAIL
      SET  Status = '3' 
      FROM TempStock
      WHERE CCDETAIL.CCDETAILKEY = TEMPSTOCK.SourceKey
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_continue = 3
         RAISERROR ('Error Updating CCDETAIL', 16, 1)
         ROLLBACK TRAN
         RETURN
      END
      ELSE 
          COMMIT TRAN 
   END
    -- -- Added By Vicky 23 Oct 2001     
    -- -- Set secret password after posting is done 
    -- -- so that no changes can be made for the record after posted successfully
    -- 
    --  IF @n_continue = 1 OR @n_continue = 2 
    --  BEGIN
    --    BEGIN TRAN
    --        UPDATE Stocktakesheetparameters
    --        SET protect = 'Y', 
    --            password = 'pfcteam'
    --        WHERE Stocktakesheetparameters.Storerkey = @c_Storerkey
    --        AND   Stocktakesheetparameters.Stocktakekey = @c_Stocktakekey 
    -- 
    --        IF @@ERROR <> 0
    --        BEGIN
    --         SELECT @n_continue = 3
    --        RAISERROR ('Error setting password', 16, 1)
    --           ROLLBACK TRAN
    --           RETURN
    --       END
    --       ELSE 
    --     COMMIT TRAN 
    --  END
END

GO