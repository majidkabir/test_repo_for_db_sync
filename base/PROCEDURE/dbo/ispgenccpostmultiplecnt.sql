SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/****************************************************************************/
/* Stored Procedure: ispGenCCPostMultipleCnt                                */
/* Creation Date:                                                           */
/* Copyright: IDS                                                           */
/* Written by:                                                              */
/*                                                                          */
/* Purpose: Post Cycle Count (multiple count) in StockTake module           */
/*                                                                          */
/* Called By: PB object nep_n_cst_stocktake_parm_new                        */
/*                                                                          */
/* PVCS Version: 2.0                                                        */
/*                                                                          */
/* Version: 5.4                                                             */
/*                                                                          */
/* Data Modifications:                                                      */
/*                                                                          */
/* Updates:                                                                 */
/* Date         Author     Ver.  Purposes                                   */
/* 01-Oct-2002  Shong            Added new parameters Agency code and ABC   */
/* 11-Jul-2002  Shong            Bug fixed                                  */
/* 10-Nov-2005  MaryVong         SOS42806 Increase length of returned fields*/
/*                               from ispParseParameters to NVARCHAR(800)   */
/* 18-Jan-2008  June             SOS66279 : Include STOCKTAKEPARM2 checking */
/* 03-Feb-2009  NJOW01     1.1   SOS126943 Generate Posting By stock take   */
/*                               no, not to generate withdrawal if          */
/*                               blankcsheethideloc = 'Y'                   */
/* 05-Aug-2010  NJOW01     1.2   182454 - Add skugroup parameter            */
/* 24-Jan-2011  NJOW02     1.3   201680 - Add exclude qty picked checking   */
/*                               when calculate system qty                  */
/* 04-Nov-2011  YTWan      1.4   SOS#229737- Fix to update all pending      */
/*                               status to '3'. (Wan01)                     */
/* 30-Oct-2013  Shong      1.5   SOS254691 StocktakeSheetParameters.CountType*/
/*                               Block normal countsheet if detected UCC data*/
/* 21-May-2014  TKLIM      1.6   Added Lottables 06-15                      */
/* 30-MAR-2016  Wan02      1.7   SOS#366947: SG-Stocktake LocationRoom Parm */
/* 16-JUN-2016  Wan03      1.8   SOS#366947: SOS#371185 - CN Carter's SH    */
/*                               WMS Cycle Count module                     */
/* 29-JUN-2016  Wan04      1.9   SOS#370874 - TW Add Cycle Count Strategy   */
/* 24-NOV-2016  Wan05      2.0   WMS-648 - GW StockTake Parameter2          */
/*                               Enhancement                                */
/* 10-FEB-2017  Wan06      2.1   WMS-453 - Number of Lines in Blank Count   */
/*                               Sheet                                      */
/****************************************************************************/

CREATE PROC [dbo].[ispGenCCPostMultipleCnt] (
@c_StockTakeKey NVARCHAR(10),
@c_CountNo      NVARCHAR(1) 
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
      
   DECLARE @c_facility        NVARCHAR(5),
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
   -- Added by SHONG 01 OCT 2002
           @c_AgencyParm      NVARCHAR(150),
           @c_ABCParm         NVARCHAR(60),
           @c_SkuGroupParm    NVARCHAR(125),
   -- SOS126943 NJOW 16FEB09
           @c_blankcsheethideloc NVARCHAR(1),        
           @c_ExcludeQtyPicked  NVARCHAR(1) 
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
         , @c_ExcludeQtyAllocated      NVARCHAR(1)          --(Wan03)     

   -- declare a select condition variable for parameters
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
           @c_SkuGroupSQL2    NVARCHAR(800) 
         --(Wan02) - START
         ,  @c_Extendedparm1SQL  NVARCHAR(800)
         ,  @c_Extendedparm1SQL2 NVARCHAR(800)
         ,  @c_Extendedparm2SQL  NVARCHAR(800)
         ,  @c_Extendedparm2SQL2 NVARCHAR(800)
         ,  @c_Extendedparm3SQL  NVARCHAR(800)
         ,  @c_Extendedparm3SQL2 NVARCHAR(800)
         --(Wan02) - END

   -- Start : SOS66279
   DECLARE @c_SQL             NVARCHAR(max),
           @c_sqlOther        NVARCHAR(4000),
           @c_sqlWhere        NVARCHAR(4000)
   
   SELECT  @c_sqlOther = ''
   -- End : SOS66279

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
         , @c_BlankCSheetDPTrnOnly     NVARCHAR(1)       --(Wan06)

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

   DECLARE @c_CountType   NVARCHAR(10)
   SET @c_CountType = ''
           
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
          @c_blankcsheethideloc = blankcsheethideloc, -- SOS126943 NJOW 16FEB09         
          @c_SkuGroupParm = SkuGroupParm,
          @c_ExcludeQtyPicked = ExcludeQtyPicked, 
          @c_CountType = CountType 
         --(Wan02) - START
         , @c_ExtendedParm1Field = ExtendedParm1Field
         , @c_ExtendedParm1      = ExtendedParm1 
         , @c_ExtendedParm2Field = ExtendedParm2Field
         , @c_ExtendedParm2      = ExtendedParm2 
         , @c_ExtendedParm3Field = ExtendedParm3Field 
         , @c_ExtendedParm3      = ExtendedParm3
         --(Wan02) - END  
         , @c_ExcludeQtyAllocated= ExcludeQtyAllocated         --(Wan03)    
         , @c_BlankCSheetDPTrnOnly = BlankCSheetDPTrnOnly      -- (Wan06)           
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
   -- Added By SHONG 01-Oct-2002
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
   -- Purge All the historical records for this stocktakekey if clear history flag = 'Y'
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

   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN
       IF @c_CountType = 'UCC'
       BEGIN
          SELECT @n_continue = 3
          RAISERROR ('Incorrect posting option, only applicable for non-UCC CountType. (ispGenCCPostMultipleCnt)', 16, 1)  
          RETURN       
       END
   END

   --NJOW01 
   IF @n_continue = 1 OR @n_continue = 2   
   BEGIN
      BEGIN TRAN
      DELETE CCDETAIL WHERE cckey = @c_stocktakekey
      AND (ISNULL(sku,'')='' OR ISNULL(loc,'')='')
   
      IF @@ERROR <> 0
      BEGIN
      SELECT @n_continue = 3
      RAISERROR ('Error Found Deleting CCDetail', 16, 1)
         ROLLBACK TRAN
         RETURN
      END
      ELSE
         COMMIT TRAN
   END
   --END NJOW01

      
   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN
      BEGIN TRAN
      --DELETE WithdrawStock
      DELETE WithdrawStock WHERE sourcetype = "CC Withdrawal (" +  @c_stocktakekey + ")"   --NJOW01
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
      --DELETE TempStock
      DELETE TempStock WHERE sourcetype = "CC Deposit (" + @c_stocktakekey + ")"    --NJOW01
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
   set @b_debug = 0
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

   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN 
      BEGIN TRAN

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
         ROLLBACK TRAN
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
         SELECT @c_SQL =  'INSERT INTO WITHDRAWSTOCK (StorerKey, SKU, LOT, ID, LOC, Qty, '
                        + 'LOTTABLE01, LOTTABLE02, LOTTABLE03, LOTTABLE04, LOTTABLE05, '
                        + 'LOTTABLE06, LOTTABLE07, LOTTABLE08, LOTTABLE09, LOTTABLE10, '
                        + 'LOTTABLE11, LOTTABLE12, LOTTABLE13, LOTTABLE14, LOTTABLE15, '
                        + 'Sourcekey, Sourcetype) '
                        + 'SELECT LOTxLOCxID.StorerKey, LOTxLOCxID.SKU, LOTxLOCxID.LOT, '
                        + 'LOTxLOCxID.id, LOTxLOCxID.loc, '
                        --(Wan03) - START
                        --+ CASE WHEN @c_ExcludeQtyPicked = 'Y' THEN 'LOTxLOCxID.qty-LOTxLOCxID.qtypicked, ' ELSE 'LOTxLOCxID.qty, ' END
                        +  CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated-LOTxLOCxID.Qtypicked, '
                                WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated, ' 
                                WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.Qtypicked, '
                                ELSE 'LOTxLOCxID.Qty, ' END
                        --(Wan03) - END  
                        + 'LotAttribute.lottable01, LotAttribute.lottable02, LotAttribute.lottable03, LotAttribute.lottable04, LotAttribute.lottable05, '
                        + 'LotAttribute.lottable06, LotAttribute.lottable07, LotAttribute.lottable08, LotAttribute.lottable09, LotAttribute.lottable10, '
                        + 'LotAttribute.lottable11, LotAttribute.lottable12, LotAttribute.lottable13, LotAttribute.lottable14, LotAttribute.lottable15, '
                        + '" ",'
                        + '"CC Withdrawal (' +  @c_stocktakekey + ')" '
                        + 'FROM LOC (NOLOCK), LOTxLOCxID (NOLOCK), LotAttribute (NOLOCK), SKU (NOLOCK) '
                        + 'WHERE LOC.LOC = LOTxLOCxID.LOC '
                        + 'AND LOTxLOCxID.LOT = LotAttribute.LOT '
                        + 'AND LOTxLOCxID.StorerKey = SKU.StorerKey '
                        + 'AND LOTxLOCxID.SKU = SKU.SKU '
                        --(Wan03) - START
                        --+ CASE WHEN @c_ExcludeQtyPicked = 'Y' THEN 'AND LOTxLOCxID.Qty-LOTxLOCxID.QtyPicked > 0 ' ELSE 'AND LOTxLOCxID.Qty > 0 ' END
                        +  CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'AND LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated-LOTxLOCxID.Qtypicked > 0 '
                                WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'AND LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated > 0 ' 
                                WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'AND LOTxLOCxID.Qty-LOTxLOCxID.Qtypicked > 0 '
                                ELSE 'AND LOTxLOCxID.Qty > 0 ' END
                        --(Wan03) - END 
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
                        + ISNULL(RTRIM(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm1SQL2), '') + ' '  --(Wan02)
                        + ISNULL(RTRIM(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm2SQL2), '') + ' '  --(Wan02)
                        + ISNULL(RTRIM(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm3SQL2), '') + ' '  --(Wan02)
                        + RTRIM(@c_StrategySQL) + ' '                                                                   --(Wan04)
      -- Start : SOS66279
      END 
      ELSE
      BEGIN
         SELECT @c_SQL = N'INSERT INTO WITHDRAWSTOCK (StorerKey, SKU, LOT, ID, LOC, Qty, '
                        + 'LOTTABLE01, LOTTABLE02, LOTTABLE03, LOTTABLE04, LOTTABLE05, '
                        + 'LOTTABLE06, LOTTABLE07, LOTTABLE08, LOTTABLE09, LOTTABLE10, '
                        + 'LOTTABLE11, LOTTABLE12, LOTTABLE13, LOTTABLE14, LOTTABLE15, '
                        + 'Sourcekey, Sourcetype) '
                        + 'SELECT LOTxLOCxID.StorerKey, LOTxLOCxID.SKU, LOTxLOCxID.LOT, '
                        + 'LOTxLOCxID.id, LOTxLOCxID.loc, '
                        --(Wan03) - START  
                        --+ CASE WHEN @c_ExcludeQtyPicked = 'Y' THEN 'LOTxLOCxID.qty-LOTxLOCxID.qtypicked, ' ELSE 'LOTxLOCxID.qty, ' END
                        +  CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated-LOTxLOCxID.Qtypicked, '
                                WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated, ' 
                                WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'LOTxLOCxID.Qty-LOTxLOCxID.Qtypicked, '
                                ELSE 'LOTxLOCxID.Qty, ' END
                        --(Wan03) - END  
                        + 'LotAttribute.lottable01, LotAttribute.lottable02, LotAttribute.lottable03, LotAttribute.lottable04, LotAttribute.lottable05, '
                        + 'LotAttribute.lottable06, LotAttribute.lottable07, LotAttribute.lottable08, LotAttribute.lottable09, LotAttribute.lottable10, '
                        + 'LotAttribute.lottable11, LotAttribute.lottable12, LotAttribute.lottable13, LotAttribute.lottable14, LotAttribute.lottable15, '
                        + '" ",'
                        + '"CC Withdrawal (' +  @c_stocktakekey + ')" '
                        + 'FROM LOC WITH (NOLOCK) '
                        + 'JOIN LOTxLOCxID WITH (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC '
                        + 'JOIN LotAttribute WITH (NOLOCK) ON LotAttribute.LOT = LOTxLOCxID.LOT ' 
                        + 'JOIN SKU WITH (NOLOCK) ON SKU.Storerkey = LOTxLOCxID.Storerkey AND SKU.SKU = LOTxLOCxID.SKU '

    
         --(Wan05) - START
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
                                     + ' ON dbo.fnc_RTrim(dbo.fnc_LTrim(PARM2_LOC.Value)) = LOTxLOCxID.LOC '
                                     + 'AND UPPER(PARM2_LOC.Tablename) = ''LOC'' '
                                     + 'AND PARM2_LOC.Stocktakekey = ''' + ISNULL(dbo.fnc_RTrim(@c_StockTakeKey), '') + ''''
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
         --(Wan05) - END
         SELECT @c_SQLWhere = ' '
                            --(Wan03) - START
                              --+ CASE WHEN @c_ExcludeQtyPicked = 'Y' THEN 'WHERE LOTxLOCxID.Qty-LOTxLOCxID.QtyPicked > 0 ' ELSE 'WHERE LOTxLOCxID.Qty > 0 ' END
                            +  CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN 'WHERE LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated-LOTxLOCxID.Qtypicked > 0 '
                                    WHEN @c_ExcludeQtyAllocated = 'Y' THEN 'WHERE LOTxLOCxID.Qty-LOTxLOCxID.Qtyallocated > 0 ' 
                                    WHEN @c_ExcludeQtyPicked    = 'Y' THEN 'WHERE LOTxLOCxID.Qty-LOTxLOCxID.Qtypicked > 0 '
                                    ELSE 'WHERE LOTxLOCxID.Qty > 0 ' END
                            --(Wan03) - END 
                              + 'AND LOC.facility = N''' + ISNULL(dbo.fnc_RTrim(@c_facility), '') + ''' '
                              + ISNULL(dbo.fnc_RTrim(@c_StorerSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_StorerSQL2), '') + ' '
                              + RTRIM(@c_StrategySQL) + ' '                                           --(Wan04)
         SELECT @c_sql = @c_sql + ' ' + @c_sqlWhere + ' ' + @c_sqlOther 
      END

   IF (@c_blankcsheethideloc <> 'Y'  -- SOS126943 NJOW 16FEB09         
   AND @c_BlankCSheetDPTrnOnly IS NULL)     --(Wan06)    
   OR  @c_BlankCSheetDPTrnOnly = 'N'        --(Wan06)
   BEGIN
      EXEC ( @c_SQL )
      -- End : SOS66279
  
      -- Added By Vicky 23-Oct-2001  
      UPDATE Withdrawstock
      SET   sourcekey = CCDetail.CCdetailkey
      FROM  CCDetail
      WHERE CCDetail.Lot = Withdrawstock.Lot
      AND   CCDetail.Loc = Withdrawstock.Loc
      AND   CCDetail.ID  = Withdrawstock.ID   
      AND   CCDetail.Storerkey = Withdrawstock.Storerkey
      AND   CCDetail.SKu = Withdrawstock.SKu
      AND   CCDetail.CCKey = @c_StockTakeKey 
      AND   Withdrawstock.Sourcetype = "CC Withdrawal (" +  @c_stocktakekey + ")"
   END  

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

      BEGIN TRAN
      EXEC ( 'INSERT INTO TempStock (StorerKey, SKU, ID, LOC, Qty, '
            + 'LOTTABLE01, LOTTABLE02, LOTTABLE03, LOTTABLE04, LOTTABLE05, '
            + 'LOTTABLE06, LOTTABLE07, LOTTABLE08, LOTTABLE09, LOTTABLE10, '
            + 'LOTTABLE11, LOTTABLE12, LOTTABLE13, LOTTABLE14, LOTTABLE15, '
            + 'Sourcekey, Sourcetype) '
            + 'SELECT CCDETAIL.StorerKey, CCDETAIL.SKU, '
            + 'CCDETAIL.id, CCDETAIL.loc, ' 
            + 'CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.qty '
            + '     WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.qty_Cnt2 '
            + '     WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.qty_Cnt3 '
            + 'END As Qty, '
            + 'CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.lottable01 '
            + '     WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.lottable01_Cnt2 '
            + '     WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.lottable01_Cnt3 '
            + 'END As Lottable01, '
            + 'CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.lottable02 '
            + '     WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.lottable02_Cnt2 '
            + '     WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.lottable02_Cnt3 '
            + 'END As Lottable02, '
            + 'CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.lottable03 '
            + '     WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.lottable03_Cnt2 '
            + '     WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.lottable03_Cnt3 '
            + 'END As Lottable03, '
            + 'CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.lottable04 '
            + '     WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.lottable04_Cnt2 '
            + '     WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.lottable04_Cnt3 '
            + 'END As Lottable04, '
            + 'CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.lottable05 '
            + '     WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.lottable05_Cnt2 '
            + '     WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.lottable05_Cnt3 '
            + 'END As Lottable05, '
            + 'CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.Lottable06 '
            + '     WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.Lottable06_Cnt2 '
            + '     WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.Lottable06_Cnt3 '
            + 'END As Lottable06, '
            + 'CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.Lottable07 '
            + '     WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.Lottable07_Cnt2 '
            + '     WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.Lottable07_Cnt3 '
            + 'END As Lottable07, '
            + 'CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.Lottable08 '
            + '     WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.Lottable08_Cnt2 '
            + '     WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.Lottable08_Cnt3 '
            + 'END As Lottable08, '
            + 'CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.lottable09 '
            + '     WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.lottable09_Cnt2 '
            + '     WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.lottable09_Cnt3 '
            + 'END As Lottable09, '
            + 'CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.lottable10 '
            + '     WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.lottable10_Cnt2 '
            + '     WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.lottable10_Cnt3 '
            + 'END As Lottable10, '
            + 'CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.lottable11 '
            + '     WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.lottable11_Cnt2 '
            + '     WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.lottable11_Cnt3 '
            + 'END As Lottable11, '
            + 'CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.lottable12 '
            + '     WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.lottable12_Cnt2 '
            + '     WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.lottable12_Cnt3 '
            + 'END As Lottable12, '
            + 'CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.lottable13 '
            + '     WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.lottable13_Cnt2 '
            + '     WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.lottable13_Cnt3 '
            + 'END As Lottable13, '
            + 'CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.lottable14 '
            + '     WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.lottable14_Cnt2 '
            + '     WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.lottable14_Cnt3 '
            + 'END As Lottable14, '
            + 'CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.lottable15 '
            + '     WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.lottable15_Cnt2 '
            + '     WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.lottable15_Cnt3 '
            + 'END As Lottable15, '
            + 'CCDETAIL.CCDetailKey,' 
            + '"CC Deposit (' + @c_stocktakekey + ')"'
            + 'FROM CCDETAIL (NOLOCK), SKU (NOLOCK) '
            + 'WHERE CCDETAIL.CCKEY = N''' + @c_StockTakeKey + ''' '
            + 'AND CCDETAIL.STORERKEY = SKU.STORERKEY '
            + 'AND CCDETAIL.SKU = SKU.SKU '
            + @c_Checking ) 
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
      AND TEMPSTOCK.sourcetype = "CC Deposit (" + @c_stocktakekey + ")" --NJOW01
 
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_continue = 3
         RAISERROR ('Error Updating CCDETAIL', 16, 1)
         ROLLBACK TRAN
         RETURN
      END
      ELSE 
         COMMIT TRAN 


      /*--Wan01 (START)--*/
      SET @c_Checking = ''
      IF @c_CountNo = '1'
      BEGIN
         SET @c_Checking = 'AND CCDETAIL.QTY = 0 ' 
      END 
      IF @c_CountNo = '2'
      BEGIN
         SET @c_Checking = 'AND CCDETAIL.QTY_Cnt2 = 0 ' 
      END 
      IF @c_CountNo = '3'
      BEGIN
         SET @c_Checking = 'AND CCDETAIL.QTY_Cnt3 = 0 ' 
      END 

      SET @c_SQL = 'UPDATE CCDETAIL WITH (ROWLOCK) '
                 + 'SET Status = ''3'' '          
                 + 'FROM CCDETAIL '
                 + 'WHERE CCDETAIL.CCKEY = ''' + @c_StockTakeKey + ''' '
                 + 'AND CCDETAIL.Status <> ''3'' '
                 + 'AND CCDETAIL.Status < ''9'' '
                 +  @c_Checking
      BEGIN TRAN

      EXEC (@c_SQL) 
   
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_continue = 3
         RAISERROR ('Error Updating CCDETAIL', 16, 1)
         ROLLBACK TRAN
         RETURN
      END
      ELSE 
         COMMIT TRAN 
      /*-- Wan01 (END)--*/
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
   --         RAISERROR ('Error setting password', 16, 1)
   --           ROLLBACK TRAN
   --           RETURN
   --       END
   --       ELSE 
   --     COMMIT TRAN 
   --  END
END

GO