SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispAJCHK01                                         */
/* Creation Date: 13-Nov-2014                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#320679 TH - Adjustment freeze during stock take         */
/*                                                                      */
/* Called By: Finalize Adjustment                                       */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 28-MAR-2016  Wan01    1.1  SOS#366947: SG-Stocktake LocationRoom Parm*/
/* 29-JUN-2016  Wan02    1.2  SOS#370874 - TW Add Cycle Count Strategy  */
/* 23-NOV-2016  Wan03    1.3  WMS-648 - GW StockTake Parameter2         */
/*                            Enhancement                               */
/* 01-Feb-2017  TLTING   1.3  Performance Tune                          */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispAJCHK01]
   @c_AdjustmentKey    NVARCHAR(10),
   @b_Success          INT = 1  OUTPUT,
   @n_ErrNo            INT = 0  OUTPUT,
   @c_ErrorMsg         NVARCHAR(250) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @c_StockTakekey    NVARCHAR(10),
           @c_Storerkey       NVARCHAR(15),
           @c_facility        NVARCHAR(5),
           @c_StorerParm      NVARCHAR(60),
           @c_AisleParm       NVARCHAR(60),
           @c_LevelParm       NVARCHAR(60),
           @c_ZoneParm        NVARCHAR(60),
           @c_SKUParm         NVARCHAR(125),
           @c_HostWHCodeParm  NVARCHAR(60),
           @c_AgencyParm      NVARCHAR(150),
           @c_ABCParm         NVARCHAR(60),
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
   
   DECLARE @c_AisleSQL        NVARCHAR(800),
           @c_AisleSQL2       NVARCHAR(800),
           @c_LevelSQL        NVARCHAR(800),
           @c_LevelSQL2       NVARCHAR(800),
           @c_ZoneSQL         NVARCHAR(800),
           @c_ZoneSQL2        NVARCHAR(800),
           @c_HostWHCodeSQL   NVARCHAR(800),
           @c_HostWHCodeSQL2  NVARCHAR(800),
           @c_SKUSQL          NVARCHAR(800),
           @c_SKUSQL2         NVARCHAR(800),
           @c_StorerSQL       NVARCHAR(800),
           @c_StorerSQL2      NVARCHAR(800),
           @c_AgencySQL       NVARCHAR(800),
           @c_AgencySQL2      NVARCHAR(800),
           @c_ABCSQL          NVARCHAR(800),
           @c_ABCSQL2         NVARCHAR(800),
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

   DECLARE @b_debug           INT,
           @n_RecFound        INT,
           @n_Continue        INT,
           @c_SQL             NVARCHAR(Max),
           @c_SQLOther        NVARCHAR(Max),
           @c_SQLWhere        NVARCHAR(Max)
           
   --(Wan02) - START
   DECLARE  @c_StrategySQL    NVARCHAR(4000) 
         ,  @c_StrategySkuSQL NVARCHAR(4000) 
         ,  @c_StrategyLocSQL NVARCHAR(4000) 
   --(Wan02) - END 

   --(Wan03) - START
   DECLARE @c_SkuConditionSQL          NVARCHAR(MAX)
         , @c_LocConditionSQL          NVARCHAR(MAX)
         , @c_ExtendedConditionSQL1    NVARCHAR(MAX)   
         , @c_ExtendedConditionSQL2    NVARCHAR(MAX)
         , @c_ExtendedConditionSQL3    NVARCHAR(MAX)
         , @c_StocktakeParm2SQL        NVARCHAR(MAX)
         , @c_StocktakeParm2OtherSQL   NVARCHAR(MAX)
   --(Wan03) - END

   CREATE TABLE #SKUXLOC (
      Storerkey NVARCHAR(15) NULL,
      Sku NVARCHAR(20) NULL,
      Loc NVARCHAR(10) NULL)                             

   SELECT @n_continue = 1, @b_debug = 0, @n_ErrNo = 0, @b_Success  = 1, @c_ErrorMsg  = ''
   
   SELECT @c_Storerkey = RTRIM(Storerkey)
   FROM ADJUSTMENT (NOLOCK) 
   WHERE Adjustmentkey = @c_AdjustmentKey
   
   INSERT INTO #SKUXLOC
   SELECT DISTINCT AD.Storerkey, AD.Sku, AD.Loc
   FROM ADJUSTMENT A (NOLOCK)
   JOIN ADJUSTMENTDETAIL AD (NOLOCK) ON A.Adjustmentkey = AD.Adjustmentkey
   WHERE A.Adjustmentkey = @c_AdjustmentKey
   
   IF @b_debug = 1 
   BEGIN
   	  SELECT * FROM #SKUXLOC
   END
        

   DECLARE CUR_STOCKTAKE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
      SELECT STP.StockTakeKey
      FROM StockTakeSheetParameters STP (NOLOCK)
      JOIN CCDetail CCD (NOLOCK) ON STP.StockTakeKey = CCD.CCKey 
      LEFT JOIN CCDetail CCD2 (NOLOCK) ON STP.StockTakeKey = CCD2.CCKey AND CCD2.status = '9'
      LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'ADJTYPE' AND STP.AdjType = CL.Code
      WHERE CCD.Status < '9'
      AND CHARINDEX(@c_Storerkey, STP.Storerkey, 1) > 0
      AND DATEDIFF(DAY,CCD.AddDate, GETDATE()) < 7
      AND ISNULL(CL.UDF01,'') = 'CCFREEZE'
      GROUP BY STP.StockTakeKey
      HAVING COUNT(DISTINCT CCD2.CCDetailKey) = 0        
   
   OPEN CUR_STOCKTAKE 
    
   FETCH NEXT FROM CUR_STOCKTAKE INTO @c_StockTakeKey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
   	  SELECT @c_AisleSQL = '', @c_AisleSQL2 = '', @c_LevelSQL = '', @c_LevelSQL2 = '', @c_ZoneSQL = '', @c_ZoneSQL2 = ''
      SELECT @c_HostWHCodeSQL = '', @c_HostWHCodeSQL2 = '', @c_SKUSQL = '', @c_SKUSQL2 = '', @c_StorerSQL = '', @c_StorerSQL2 = ''
      SELECT @c_AgencySQL = '', @c_AgencySQL2 = '', @c_ABCSQL = '', @c_ABCSQL2 = '', @c_SkuGroupSQL = '', @c_SkuGroupSQL2 = ''
      SELECT @n_RecFound = 0, @c_SQL = '', @c_SQLOther = '', @c_SQLWhere = ''

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

      IF @b_debug = 1 
      BEGIN
         SELECT  @c_Stocktakekey AS Stocktakekey,
                 Facility,
                 StorerKey,
                 AisleParm,
                 LevelParm,
                 ZoneParm,
                 HostWHCodeParm,
                 SKUParm,
                 AgencyParm,
                 ABCParm,
                 SkuGroupParm
          , ExtendedParm1Field
          ,  ExtendedParm1 
          , ExtendedParm2Field
          ,  ExtendedParm2 
          ,  ExtendedParm3Field 
          ,  ExtendedParm3
         FROM StockTakeSheetParameters (NOLOCK)
         WHERE StockTakeKey = @c_StockTakeKey
      END         

      SELECT @c_Facility = Facility,
             @c_StorerParm = StorerKey,
             @c_AisleParm = AisleParm,
             @c_LevelParm = LevelParm,
             @c_ZoneParm = ZoneParm,
             @c_HostWHCodeParm = HostWHCodeParm,
             @c_SKUParm = SKUParm,
             @c_AgencyParm = AgencyParm,
             @c_ABCParm = ABCParm,
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
           '#SKUXLOC.SKU',
           @c_SKUSQL OUTPUT,
           @c_SKUSQL2 OUTPUT,
           @b_success OUTPUT
      
      EXEC ispParseParameters
           @c_StorerParm,
           'string',
           '#SKUXLOC.StorerKey',
           @c_StorerSQL OUTPUT,
           @c_StorerSQL2 OUTPUT,
           @b_success OUTPUT
      
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

      --(Wan02) - START
      EXEC ispCCStrategy 
         @c_StockTakeKey   = @c_StockTakeKey
      ,  @c_StrategySQL    = @c_StrategySQL     OUTPUT
      ,  @c_StrategySkuSQL = @c_StrategySkuSQL  OUTPUT
      ,  @c_StrategyLocSQL = @c_StrategyLocSQL  OUTPUT
      ,  @b_Success        = @b_Success         OUTPUT      
      ,  @n_err            = @n_errno           OUTPUT        
      ,  @c_errmsg         = @c_errormsg        OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_Continue = 3
         SET @n_errno = 75853
         SET @c_errormsg = 'NSQL' + CONVERT(CHAR(5), @n_errno) + ': Error Executing ispCCStrategy.(ispAJCHK01)' 
         SET @b_Success = 0
         GOTO EXIT_SP 
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
      IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) WHERE Stocktakekey = @c_StockTakeKey)
      BEGIN
      	  SELECT @c_SQL = 'SELECT @n_RecFound = Count(*) '
                        + 'FROM #SKUXLOC '
                        + 'JOIN LOC (NOLOCK) ON #SKUXLOC.Loc = LOC.Loc '
                        + 'JOIN SKU (NOLOCK) ON #SKUXLOC.Storerkey = SKU.Storerkey AND #SKUXLOC.Sku = SKU.Sku '
                        --(Wan01)
                        + 'JOIN LOTxLOCxID (NOLOCK) ON #SKUXLOC.Storerkey = LOTxLOCxID.Storerkey AND #SKUXLOC.Sku = LOTxLOCxID.Sku '
                        +                           'AND #SKUXLOC.Loc = LOTxLOCxID.Loc '
                        + 'JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.Lot = LOTATTRIBUTE.Lot '
                        --(Wan01)
                        + 'WHERE 1 = 1 '
                        + @c_StorerSQL + ' ' + @c_StorerSQL2 + ' '
                        + 'AND LOC.facility = "' + @c_facility + '" '
                        + @c_ZoneSQL + ' ' + @c_ZoneSQL2 + ' '
                        + @c_AisleSQL + ' ' + @c_AisleSQL2 + ' '
                        + @c_LevelSQL + ' ' + @c_LevelSQL2 + ' '
                        + @c_HostWHCodeSQL + ' ' + @c_HostWHCodeSQL2 + ' '
                        + @c_SKUSQL + ' ' + @c_SKUSQL2 + ' '
                        + @c_AgencySQL + ' ' + @c_AgencySQL2 + ' '
                        + @c_ABCSQL + ' ' + @c_ABCSQL2 + ' '
                        + @c_SkuGroupSQL + ' ' + @c_SkuGroupSQL2 + ' '
                        + ISNULL(RTRIM(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm1SQL2), '') + ' '  --(Wan01)
                        + ISNULL(RTRIM(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm2SQL2), '') + ' '  --(Wan01)
                        + ISNULL(RTRIM(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm3SQL2), '') + ' '  --(Wan01)
                        + RTRIM(@c_StrategySQL) + ' '                                                                   --(Wan02)
          IF @b_debug = 1
             PRINT @c_SQL                        
          
          EXEC sp_executesql @c_SQL, N'@n_RecFound int OUTPUT', @n_RecFound OUTPUT

 
          IF @n_RecFound > 0  
          BEGIN
      	     SELECT @n_continue = 3
             SELECT @n_errno = 75851
             SELECT @c_errormsg = 'There is a stock take '''+ RTRIM(ISNULL(@c_StockTakeKey,''))  +''' in progress. Finalize adjustment is not allowed.(ispAJCHK01)' 
             SELECT @b_Success = 0
             GOTO EXIT_SP
          END
      END
      ELSE
      BEGIN            
         SELECT @c_SQL = N'SELECT @n_RecFound = Count(*) '
          + 'FROM LOC WITH (NOLOCK) '
          + 'JOIN #SKUXLOC WITH (NOLOCK) ON #SKUXLOC.LOC = LOC.LOC '
          + 'JOIN SKU WITH (NOLOCK) ON SKU.Storerkey = #SKUXLOC.Storerkey AND SKU.SKU = #SKUXLOC.SKU '
          --(Wan01)
          + 'JOIN LOTxLOCxID (NOLOCK) ON #SKUXLOC.Storerkey = LOTxLOCxID.Storerkey AND #SKUXLOC.Sku = LOTxLOCxID.Sku '
          +                           'AND #SKUXLOC.Loc = LOTxLOCxID.Loc '
          + 'JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.Lot = LOTATTRIBUTE.Lot '
          --(Wan01)
         
         --(Wan03) - START
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
                               + '  ON PARM2_SKU.Storerkey = #SKUXLOC.Storerkey '
                               + ' AND RTRIM(LTRIM(PARM2_SKU.Value)) = #SKUXLOC.SKU '
                               + ' AND UPPER(PARM2_SKU.Tablename) = ''SKU'' '
                               + ' AND PARM2_SKU.Stocktakekey = ''' + ISNULL(RTRIM(@c_StockTakeKey), '') + ''''
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
                                  + '  ON RTRIM(LTRIM(PARM2_LOC.Value)) = #SKUXLOC.LOC '
                                  + ' AND UPPER(PARM2_LOC.Tablename) = ''LOC'' '
                                  + ' AND PARM2_LOC.Stocktakekey = ''' + ISNULL(RTRIM(@c_StockTakeKey), '') + ''''
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
         SELECT @c_SQLWhere = 'WHERE 1 = 1 '
                            + ISNULL(RTRIM(@c_StorerSQL), '') + ' ' + ISNULL(RTRIM(@c_StorerSQL2), '') + ' '
                            + 'AND LOC.facility = "' + ISNULL(RTRIM(@c_facility), '') + '" '
                            + RTRIM(@c_StrategySQL) + ' '                                             --(Wan02)

         SELECT @c_SQL = @c_SQL + ' ' + @c_SQLWhere + ' ' + @c_SQLOther

         IF @b_debug = 1
            PRINT @c_SQL                        
      
         EXEC sp_executesql @c_SQL, N'@n_RecFound int OUTPUT', @n_RecFound OUTPUT

         IF @n_RecFound > 0  
         BEGIN
      	    SELECT @n_continue = 3
            SELECT @n_errno = 75852
            SELECT @c_errormsg = 'There is a stock take '''+ RTRIM(ISNULL(@c_StockTakeKey,''))  +''' in progress. Finalize adjustment is not allowed.(ispAJCHK01)' 
            SELECT @b_Success = 0
            GOTO EXIT_SP
         END
      END   	
        
      FETCH NEXT FROM CUR_STOCKTAKE INTO @c_StockTakeKey
   END

   EXIT_SP:  

   CLOSE CUR_STOCKTAKE
   DEALLOCATE CUR_STOCKTAKE      
END

GO