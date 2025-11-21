SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/****************************************************************************/
/* Stored Procedure: ispGenBlankSheet                                       */
/* Creation Date:                                                           */
/* Copyright: IDS                                                           */
/* Written by:                                                              */
/*                                                                          */
/* Purpose: Generate blank Count Sheet in StockTake module                  */
/*                                                                          */
/* Called By: PB object nep_n_cst_stocktake_parm_new                        */
/*                                                                          */
/* PVCS Version: 1.8                                                        */
/*                                                                          */
/* Version: 5.4                                                             */
/*                                                                          */
/* Data Modifications:                                                      */
/*                                                                          */
/* Updates:                                                                 */
/* Date         Author     Ver.  Purposes                                   */
/* 13-Jul-2004  Admtor           Include Drop Object before Create          */
/* 15-Oct-2004  Mohit            Change Cursor Type                         */
/* 10-Nov-2005  MaryVong         SOS42806 Increase length of returned fields*/
/*                               from ispParseParameters to NVARCHAR(800)   */
/* 18-Jan-2008  June             SOS66279 : Include STOCKTAKEPARM2 checking */
/* 02-FEB-2009  NJOW01     1.1   SOS126943 Blank count sheet generate blank */
/*                               line without location                      */
/* 14-09-2009   TLTING     1.1   ID field length   (tlting01)               */
/* 25-Jul-2011  NJOW02     1.2   216737-New count sheet seq# for every stock*/
/*                               take.                                      */
/* 18-Oct-2012  James      1.3   254690-Add CountType (james01)             */
/* 21-May-2014  TKLIM      1.4   Added Lottables 06-15                      */
/* 31-MAR-2016  Wan01      1.5   SOS#366947: SG-Stocktake LocationRoom Parm */
/* 29-JUN-2016  Wan02      1.6   SOS#370874 - TW Add Cycle Count Strategy   */
/* 08-AUG-2016  Wan03      1.7   SOS#373839 - [TW] CountSheet Generation Logic*/
/* 11-OCT-2016  Wan04      1.8   WMS-453:Number of Lines in Blank Count Sheet*/
/* 24-NOV-2016  Wan05      1.8   WMS-648 - GW StockTake Parameter2          */
/*                               Enhancement                                */
/* 21-Jan-2021  WLChooi    1.9   WMS-15985 - Generate No. Of Loc by Count   */
/*                               Sheet (WL01)                               */
/****************************************************************************/

CREATE PROC [dbo].[ispGenBlankSheet] (
@c_StockTakeKey NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE  @c_facility             NVARCHAR(5),
            @c_StorerKey            NVARCHAR(18),
            @c_AisleParm            NVARCHAR(60),
            @c_LevelParm            NVARCHAR(60),
            @c_ZoneParm             NVARCHAR(60),
            @c_HostWHCodeParm       NVARCHAR(60),
            @c_ClearHistory         NVARCHAR(1),
            @c_WithQuantity         NVARCHAR(1),
            @c_EmptyLocation        NVARCHAR(1),
            @n_LinesPerPage         int,
            @n_noofblankcountsheet  int,  --NJOW01
            @c_hideloc              NVARCHAR(1),  --NJOW01
            @c_CCSheetNoKeyName     NVARCHAR(30) -- NJOW02
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
          , @c_StrategySQL             NVARCHAR(4000)       --(Wan02) 
          , @c_StrategySkuSQL          NVARCHAR(4000)       --(Wan02)   
          , @c_StrategyLocSQL          NVARCHAR(4000)       --(Wan02)
         --(Wan03) - START   
         , @c_CountSheetGroupBy        NVARCHAR(1000)
         , @c_CountSheetSortBy         NVARCHAR(1000)
         , @c_PartitionBy              NVARCHAR(1000)
         , @c_SortBy                   NVARCHAR(1000)
         , @c_ColumnName               NVARCHAR(50)
         , @c_SheetLineColumn          NVARCHAR(1000)
         , @n_SheetLineNo              INT
         , @c_RowRefColumn             NVARCHAR(1000)
         , @n_RowRef                   BIGINT
         , @c_SQL2                     NVARCHAR(4000)
         --(Wan03) - END   
         , @n_LOCPerPage               INT                  --WL01
         , @c_IsLOCPerPage             NVARCHAR(10) = 'Y'   --WL01

   -- declare a select condition variable for parameters
   -- SOS42806 Changed NVARCHAR(120) and NVARCHAR(255) to NVARCHAR(800)
   DECLARE  @c_AisleSQL             NVARCHAR(800),
            @c_LevelSQL             NVARCHAR(800),
            @c_ZoneSQL              NVARCHAR(800),
            @c_HostWHCodeSQL        NVARCHAR(800),
            @c_AisleSQL2            NVARCHAR(800),
            @c_LevelSQL2            NVARCHAR(800),
            @c_ZoneSQL2             NVARCHAR(800),
            @c_HostWHCodeSQL2       NVARCHAR(800),
            @b_success              int,
            @c_lot                  NVARCHAR(10),
            @c_loc                  NVARCHAR(10),
            @c_id                   NVARCHAR(18),      -- tlting01
            @c_sku                  NVARCHAR(20),
            @c_Lottable01           NVARCHAR(18),
            @c_Lottable02           NVARCHAR(18),
            @c_Lottable03           NVARCHAR(18),
            @d_Lottable04           DATETIME,
            @d_Lottable05           DATETIME,
            @c_Lottable06           NVARCHAR(30),
            @c_Lottable07           NVARCHAR(30),
            @c_Lottable08           NVARCHAR(30),
            @c_Lottable09           NVARCHAR(30),
            @c_Lottable10           NVARCHAR(30),
            @c_Lottable11           NVARCHAR(30),
            @c_Lottable12           NVARCHAR(30),
            @d_Lottable13           DATETIME,
            @d_Lottable14           DATETIME,
            @d_Lottable15           DATETIME,
            @n_qty                  int,
            @c_Aisle                NVARCHAR(10),
            @n_loclevel             int,
            @c_prev_facility        NVARCHAR(5),
            @c_prev_Aisle           NVARCHAR(10),
            @n_prev_loclevel        int,
            @c_ccdetailkey          NVARCHAR(10),
            @c_ccsheetno            NVARCHAR(10),
            @n_err                  int,
            @c_errmsg               NVARCHAR(250),
            @n_LineCount            int
         --(Wan01) - START
         ,  @c_Extendedparm1SQL  NVARCHAR(800)
         ,  @c_Extendedparm1SQL2 NVARCHAR(800)
         ,  @c_Extendedparm2SQL  NVARCHAR(800)
         ,  @c_Extendedparm2SQL2 NVARCHAR(800)
         ,  @c_Extendedparm3SQL  NVARCHAR(800)
         ,  @c_Extendedparm3SQL2 NVARCHAR(800)
         --(Wan01) - END

   -- Start : SOS66279
   DECLARE  @c_SQL                  NVARCHAR(4000),
            @c_SQLOther             NVARCHAR(4000),
            @c_SQLWhere             NVARCHAR(4000)
   -- End : SOS66279

   --(Wan04) - START
   DECLARE @n_NoOfLinePerLoc        INT
         , @n_InsertedLinePerLoc    INT 

         , @c_LocLineByMaxPallet    NVARCHAR(1)
         , @c_NoOfLocLineSQL        NVARCHAR(4000)

         , @c_CCDStatus             NVARCHAR(10)          
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

  --(Wan03) - START   
   SET @c_CountSheetGroupBy   = ''
   SET @c_CountSheetSortBy    = ''
   SET @c_PartitionBy         = ''
   SET @c_SortBy              = ''
   SET @c_ColumnName          = ''
   SET @c_SheetLineColumn     = ''
   SET @n_SheetLineNo         = 0
   SET @c_RowRefColumn        = ''
   SET @n_RowRef              = 0
   SET @c_SQL2                = ''                          
   --(Wan03) - END
   SET @c_LocLineByMaxPallet  = ''        --(Wan04)

   SELECT   @c_Facility             = Facility,
            @c_StorerKey            = StorerKey,
            @c_AisleParm            = AisleParm,
            @c_LevelParm            = LevelParm,
            @c_ZoneParm             = ZoneParm,
            @c_HostWHCodeParm       = HostWHCodeParm,
            @c_WithQuantity         = WithQuantity,
            @c_ClearHistory         = ClearHistory,
            @c_EmptyLocation        = EmptyLocation,
            @n_LinesPerPage         = LinesPerPage,
            @n_noofblankcountsheet  = BlankCSheetNoOfPage,  --NJOW01
            @c_hideloc              = BlankCSheetHideLoc    --NJOW01
         ,  @c_LocLineByMaxPallet   = BlankCSheetLineByMaxPLT  --(Wan04)
            --(Wan01) - START
          , @c_ExtendedParm1Field = ExtendedParm1Field
          , @c_ExtendedParm1      = ExtendedParm1 
          , @c_ExtendedParm2Field = ExtendedParm2Field
          , @c_ExtendedParm2      = ExtendedParm2 
          , @c_ExtendedParm3Field = ExtendedParm3Field 
          , @c_ExtendedParm3      = ExtendedParm3
            --(Wan01) - END
         --(Wan03) - START
         , @c_CountSheetGroupBy   = CountSheetGroupBy01          
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
         --(Wan03) - END 
         , @n_LOCPerPage          = LocPerPage   --WL01   
   FROM  StockTakeSheetParameters (NOLOCK)
   WHERE StockTakeKey = @c_StockTakeKey
   IF @c_StorerKey IS NULL 
   BEGIN
      RETURN
   END

   -- (james01)
   UPDATE StockTakeSheetParameters WITH (ROWLOCK) 
   SET CountType = 'BLK'
   WHERE StockTakeKey = @c_StockTakeKey

   IF @n_LinesPerPage = 0 OR @n_LinesPerPage IS NULL
   BEGIN
      SELECT @n_LinesPerPage = 999
   END

   --WL01 S
   IF @n_LOCPerPage = 0 OR @n_LOCPerPage IS NULL OR @n_LOCPerPage = 999
   BEGIN
   	SET @c_IsLOCPerPage = 'N'
      SET @n_LOCPerPage = 999
   END
   --WL01 E
   
   SELECT @c_CCSheetNoKeyName = 'CSHEET'+LTRIM(RTRIM(@c_StockTakeKey)) --NJOW02

   IF @c_hideloc = 'Y'   --NJOW01
   BEGIN
      IF @n_noofblankcountsheet = 0 OR @n_noofblankcountsheet IS NULL
         SELECT @n_noofblankcountsheet = 1
       
      IF @n_LinesPerPage = 0 OR @n_LinesPerPage IS NULL OR @n_LinesPerPage = 999
         SELECT @n_LinesPerPage = 10   --NJOW01
           
      WHILE @n_noofblankcountsheet > 0
      BEGIN
         EXECUTE nspg_getkey
               --'CCSheetNo'
                @c_CCSheetNoKeyName --NJOW02
                , 10
                , @c_CCSheetNo OUTPUT
                , @b_success OUTPUT
                , @n_err OUTPUT
                , @c_errmsg OUTPUT
     
         SELECT @n_linecount = 1
         WHILE @n_linecount <= @n_LinesPerPage
         BEGIN          
            EXECUTE nspg_getkey
                    'CCDetailKey'
                    , 10
                    , @c_CCDetailKey OUTPUT
                    , @b_success OUTPUT
                    , @n_err OUTPUT
                    , @c_errmsg OUTPUT
   
            INSERT CCDETAIL (cckey, ccdetailkey, storerkey, sku, lot, loc, id, qty, ccsheetno, 
                  Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
                  Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
                  Lottable11, Lottable12, Lottable13, Lottable14, Lottable15, status)
            VALUES (@c_StockTakeKey, @c_CCDetailKey, @c_Storerkey, '', '', '', '', 0, @c_CCSheetNo,
                  '', '', '', NULL, NULL,
                  '', '', '', '', '',
                  '', '', NULL, NULL, NULL ,'4')
          
            SELECT @n_linecount = @n_linecount + 1
         END
         SELECT @n_noofblankcountsheet = @n_noofblankcountsheet - 1
      END
   END
   ELSE  -- No hideloc
   BEGIN

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
         RAISERROR('Error Executing ispCCStrategy', 16, 1)
         RETURN 
      END
      --(Wan02) - END

      --(Wan05) - START
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
         ,  @c_EmptyLocation   = 'Y'
         ,  @c_SkuConditionSQL = ''
         ,  @c_LocConditionSQL = @c_LocConditionSQL
         ,  @c_ExtendedConditionSQL1 = @c_ExtendedConditionSQL1
         ,  @c_ExtendedConditionSQL2 = @c_ExtendedConditionSQL2
         ,  @c_ExtendedConditionSQL3 = @c_ExtendedConditionSQL3
         ,  @c_StocktakeParm2SQL = @c_StocktakeParm2SQL OUTPUT
         ,  @c_StocktakeParm2OtherSQL = @c_StocktakeParm2OtherSQL OUTPUT
      --(Wan05) - END

      --(Wan04) - START
      SET @c_CCDStatus = '0'
      SET @c_NoOfLocLineSQL = ',NoOfLinePerLoc = 1 '

      IF @c_LocLineByMaxPallet = 'Y'
      BEGIN 
         SET @c_CCDStatus = '4'
         SET @c_NoOfLocLineSQL = ',NoOfLinePerLoc = ISNULL(LOC.MaxPallet,0) ' 
      END
      --(Wan04) - END

      -- Purge All the historical records for this stocktakekey if clear history flag = 'Y'
      IF @c_ClearHistory = 'Y'
      BEGIN
         DELETE CCDETAIL
         WHERE  CCKEY = @c_StockTakeKey
      END
   
      IF dbo.fnc_RTrim(@c_WithQuantity) = '' OR @c_WithQuantity IS NULL
      BEGIN
         SELECT @c_WithQuantity = 'N'
      END
   
      -- Create Temp Result Table
   
      SELECT LOTxLOCxID.lot,
            LOTxLOCxID.loc,
            LOTxLOCxID.id,
            LOTxLOCxID.storerkey,
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
            LOC.putawayzone,
            LOC.loclevel,
            Aisle = LOC.locAisle,
            LOC.facility
            ,NoOfLinePerLoc = 1                    --(Wan04)
      INTO #RESULT
      FROM  LOTxLOCxID (NOLOCK),
            SKU (NOLOCK),
            LOTATTRIBUTE (NOLOCK),
            LOC (NOLOCK)
      WHERE   1=2
   
      -- Start : SOS66279
      IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) WHERE Stocktakekey = @c_StockTakeKey)
      BEGIN
      -- End : SOS66279
         SELECT @c_SQL = 'INSERT INTO #RESULT '
             + 'SELECT lot = SPACE(10),loc,id = SPACE(20),storerkey = N''' + @c_StorerKey + '''' + ',sku = SPACE(20),'
             + 'Lottable01 = SPACE(18), Lottable02 = SPACE(18), Lottable03 = SPACE(18), Lottable04 = NULL, Lottable05 = NULL,'
             + 'Lottable06 = SPACE(30), Lottable07 = SPACE(30), Lottable08 = SPACE(30), Lottable09 = SPACE(30), Lottable10 = SPACE(30),'
             + 'Lottable11 = SPACE(30), Lottable12 = SPACE(30), Lottable13 = NULL, Lottable14 = NULL, Lottable15 = NULL,'
             + 'Qty = 0,putawayzone,loclevel,Aisle = locAisle,facility '
             + @c_NoOfLocLineSQL                   --(Wan04)
             + 'FROM LOC (NOLOCK) '
             + 'WHERE   LOC.facility = N''' + ISNULL(dbo.fnc_RTrim(@c_facility), '') + ''' '
             + ISNULL(dbo.fnc_RTrim(@c_ZoneSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ZoneSQL2), '') + ' '
             + ISNULL(dbo.fnc_RTrim(@c_AisleSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AisleSQL2), '') + ' '
             + ISNULL(dbo.fnc_RTrim(@c_LevelSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_LevelSQL2), '') + ' '
             + ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL2), '') + ' '
   
         --(Wan01) - START
         IF ISNULL(RTRIM(@c_ExtendedParm1Field),'') <> '' AND 
            SUBSTRING(@c_ExtendedParm1Field, 1, CHARINDEX('.', @c_ExtendedParm1Field) - 1) = 'loc' 
         BEGIN
            SET @c_SQL = @c_SQL + ' ' 
                        + ISNULL(RTrim(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm1SQL2), '') 
                        + ' '
         END

         IF ISNULL(RTRIM(@c_ExtendedParm2Field),'') <> '' AND 
            SUBSTRING(@c_ExtendedParm2Field, 1, CHARINDEX('.', @c_ExtendedParm2Field) - 1) = 'loc' 
         BEGIN
            SET @c_SQL = @c_SQL + ' ' 
                        + ISNULL(RTrim(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm2SQL2), '')
                        + ' ' 
         END

         IF ISNULL(RTRIM(@c_ExtendedParm3Field),'') <> '' AND 
            SUBSTRING(@c_ExtendedParm3Field, 1, CHARINDEX('.', @c_ExtendedParm3Field) - 1) = 'loc' 
         BEGIN
            SET @c_SQL = @c_SQL + ' ' 
                        + ISNULL(RTrim(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTrim(@c_ExtendedParm3SQL2), '') 
                        + ' ' 
         END
         --(Wan01) - END 
         SET @c_SQL = @c_SQL + ' ' + RTRIM(@c_StrategyLocSQL) + ' '                                   --(Wan03)

         EXEC ( @c_SQL )   
      -- Start : SOS66279
      END 
      ELSE
      BEGIN
         SELECT @c_SQLOther = ''
   
         SELECT @c_SQL = N'INSERT INTO #RESULT '
             + 'SELECT lot = SPACE(10),loc,id = SPACE(20),storerkey = N''' + @c_StorerKey + '''' + ',sku = SPACE(20),'
             + 'Lottable01 = SPACE(18), Lottable02 = SPACE(18), Lottable03 = SPACE(18), Lottable04 = NULL, Lottable05 = NULL,'
             + 'Lottable06 = SPACE(30), Lottable07 = SPACE(30), Lottable08 = SPACE(30), Lottable09 = SPACE(30), Lottable10 = SPACE(30),'
             + 'Lottable11 = SPACE(30), Lottable12 = SPACE(30), Lottable13 = NULL, Lottable14 = NULL, Lottable15 = NULL,'
             + 'Qty = 0,putawayzone,loclevel,Aisle = locAisle,facility '
             + @c_NoOfLocLineSQL                   --(Wan04)
             + 'FROM LOC (NOLOCK) '
   
         --(Wan05) - START
         SET @c_sql = @c_sql + @c_StocktakeParm2SQL
         SET @c_sqlOther = @c_sqlOther + @c_StocktakeParm2OtherSQL

         /*
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
                                  + ' ON  dbo.fnc_RTrim(dbo.fnc_LTrim(PARM2_LOC.Value)) = LOC.LOC '
                                  + 'AND  UPPER(PARM2_LOC.Tablename) = ''LOC'' '
                                  + 'AND  PARM2_LOC.Stocktakekey = ''' + ISNULL(dbo.fnc_RTrim(@c_StockTakeKey), '') + ''''
         END
         */
         --(Wan05) - END
         SELECT @c_SQLWhere = ' ' + 'WHERE   LOC.facility = N''' + ISNULL(dbo.fnc_RTrim(@c_facility), '') + ''' '
                            + ' ' + RTRIM(@c_StrategyLocSQL) + ' '                                 --(Wan03)

         SELECT @c_SQL = @c_SQL + ' ' + @c_SQLWhere + ' ' + @c_SQLOther 
   
         EXEC ( @c_SQL )
      END
      -- End : SOS66279

      --(Wan04) - START
      SET @c_Loc = ''
      SET @n_NoOfLinePerLoc = 0 
      SET @n_InsertedLinePerLoc = 1

      DECLARE CUR_LOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Loc
            ,NoOfLinePerLoc
      FROM   #RESULT
      WHERE NoOfLinePerLoc > 1
      ORDER BY Loc

      OPEN CUR_LOC
   
      FETCH NEXT FROM CUR_LOC INTO @c_Loc
                                  ,@n_NoOfLinePerLoc
      WHILE @@FETCH_STATUS <> -1
      BEGIN

         SET @n_InsertedLinePerLoc = 1

         WHILE @n_InsertedLinePerLoc < @n_NoOfLinePerLoc
         BEGIN
            INSERT INTO #RESULT
            SELECT TOP 1 
                    lot, loc, id, storerkey, sku              
                  , Lottable01, Lottable02, Lottable03, Lottable04, Lottable05       
                  , Lottable06, Lottable07, Lottable08, Lottable09, Lottable10       
                  , Lottable11, Lottable12, Lottable13, Lottable14, Lottable15       
                  , Qty, putawayzone, loclevel, Aisle, facility, NoOfLinePerLoc         
            FROM #RESULT
            WHERE Loc = @c_Loc

            SET @n_InsertedLinePerLoc = @n_InsertedLinePerLoc + 1
         END
         FETCH NEXT FROM CUR_LOC INTO @c_Loc
                                    , @n_NoOfLinePerLoc
      END 
      CLOSE CUR_LOC
      DEALLOCATE CUR_LOC
      --(Wan04) - END

      SELECT @c_prev_facility = "", @c_prev_Aisle = "", @n_prev_loclevel = 0
    
      --(Wan03) - START
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

      SET @c_SQL2 = N'DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY'
                  + ' FOR SELECT R.lot, R.loc, R.id, R.storerkey, R.sku,' 
                  + ' R.Lottable01, R.Lottable02, R.Lottable03, R.Lottable04, R.Lottable05,' 
                  + ' R.Lottable06, R.Lottable07, R.Lottable08, R.Lottable09, R.Lottable10,' 
                  + ' R.Lottable11, R.Lottable12, R.Lottable13, R.Lottable14, R.Lottable15,' 
                  + CASE WHEN @c_WithQuantity = 'Y' THEN 'R.qty' ELSE '0' END
                  + ',R.facility, R.Aisle, R.loclevel'
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
      --FOR  SELECT lot, loc, id, storerkey, sku, 
      --            Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
      --            Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
      --            Lottable11, Lottable12, Lottable13, Lottable14, Lottable15, 
      --      CASE WHEN @c_WithQuantity = 'Y' THEN qty ELSE 0 END,
      --      facility, Aisle, loclevel
      --FROM #RESULT 
      --ORDER BY facility, Aisle, loclevel
      SET @n_err = @@ERROR  
      IF @n_err <> 0
      BEGIN    
        CLOSE cur_1    
        DEALLOCATE cur_1    
      END    
      ELSE
      BEGIN 
      --(Wan03) -- END
         OPEN cur_1
   
         FETCH NEXT FROM cur_1 INTO @c_lot, @c_loc, @c_id, @c_storerkey, @c_sku, 
                                    @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                                    @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, 
                                    @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
                                    @n_qty, @c_facility, @c_Aisle, @n_loclevel
                                  , @n_SheetLineNo, @n_RowRef              ---(Wan03)    
         SELECT @n_LineCount = 0
   
         WHILE @@FETCH_STATUS = 0
         BEGIN
            --IF @n_LineCount > @n_LinesPerPage OR @c_Aisle <> @c_prev_Aisle OR @n_loclevel <> @n_prev_loclevel 
            --OR @n_LineCount = 0 -- SOS66279
         IF (@n_LineCount > @n_LinesPerPage OR @n_SheetLineNo = 1) AND @c_IsLOCPerPage = 'N'   --WL01  
            BEGIN
               EXECUTE nspg_getkey
                     --'CCSheetNo'
                     @c_CCSheetNoKeyName --NJOW02
                     , 10
                     , @c_CCSheetNo OUTPUT
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT
                     
               --(Wan03) - START
               --SELECT @c_prev_facility = @c_facility, 
               --       @c_prev_Aisle = @c_Aisle, 
               --       @n_prev_loclevel = @n_loclevel
               --(Wan03) - END
               SELECT @n_LineCount = 1
            END
            
            --WL01 S
            IF (@n_LineCount > @n_LocPerPage OR @n_SheetLineNo = 1) AND @c_IsLOCPerPage = 'Y'
            BEGIN
               EXECUTE nspg_getkey
                     --'CCSheetNo'
                     @c_CCSheetNoKeyName
                     , 10
                     , @c_CCSheetNo OUTPUT
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT

               SELECT @n_LineCount = 1
            END
            --WL01 E
   
            EXECUTE nspg_getkey
                     'CCDetailKey'
                     , 10
                     , @c_CCDetailKey OUTPUT
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT
   
            IF @c_lot <> ""   
            BEGIN   
               INSERT CCDETAIL (cckey, ccdetailkey, storerkey, sku, lot, loc, id, qty, ccsheetno, 
                        Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
                        Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
                        Lottable11, Lottable12, Lottable13, Lottable14, Lottable15
                       ,Status                                                      --(Wan04)                         
                       )
               VALUES (@c_StockTakeKey, @c_CCDetailKey, @c_storerkey, @c_sku, @c_lot, @c_loc, @c_id, @n_qty, @c_CCSheetNo,
                        @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                        @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, 
                        @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
                       ,@c_CCDStatus                                                --(Wan04)                        
                       )
            END
            ELSE
            BEGIN
               INSERT CCDETAIL (cckey, ccdetailkey, storerkey, sku, lot, loc, id, qty, ccsheetno,  
                        Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
                        Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
                        Lottable11, Lottable12, Lottable13, Lottable14, Lottable15
                       ,Status                                                      --(Wan04) 
                       )
               VALUES (@c_StockTakeKey, @c_CCDetailKey, @c_storerkey, @c_sku, @c_lot, @c_loc, @c_id, @n_qty, @c_CCSheetNo,
                        @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                        @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, 
                        @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
                       ,@c_CCDStatus                                                --(Wan04)
                       )
            END
         
            SELECT @n_LineCount = @n_LineCount + 1
            
            FETCH NEXT FROM cur_1 INTO @c_lot, @c_loc, @c_id, @c_storerkey, @c_sku, 
                                       @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                                       @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, 
                                       @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
                                       @n_qty, @c_facility, @c_Aisle, @n_loclevel
                                     , @n_SheetLineNo, @n_RowRef              ---(Wan03)
         END -- WHILE
   
         CLOSE cur_1
         DEALLOCATE cur_1
      END
      DROP TABLE #RESULT
   END -- END hideloc
END -- END SP

GO