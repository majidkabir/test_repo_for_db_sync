SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispCheckUCCbal                                     */  
/* Creation Date: 07-Dec-2004                                           */  
/* Copyright: IDS                                                       */  
/* Written by: June                                                     */  
/*                                                                      */  
/* Purpose: To validate UCC balance against lotxlocxid balance - not    */  
/*          allow proceed to UCC gen stocktake if variance exists       */  
/*                                                                      */  
/* Called By: PB object nep_n_cst_stocktake_parm_new                    */  
/*                                                                      */  
/* PVCS Version: 1.3                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author     Purposes                                     */  
/* 07-Feb-2005  YokeBeen   Change from ALTER PROC to CREATE PROC        */  
/* 10-Nov-2005  MaryVong   SOS42806 Increase length of returned fields  */  
/*                         from ispParseParameters to NVARCHAR(800)     */  
/*                         -- Add RTRIM                                 */  
/* 19-Jan-2006  Vicky  SOS#44960 - include QtyAllocated - QtyPicked     */  
/*                         in Qty extraction                            */  
/* 18-Jan-2008  June   SOS66279 : Include STOCKTAKEPARM2 checking       */  
/* 05-Aug-2010  NJOW01     182454 - Add skugroup parameter              */  
/* 22-Oct-2012  James      254690-If loc.loseucc=0, then UCC should     */  
/*                         populate to the ccdetail.refno (james01)     */  
/* 08-Nov-2012  James      Add StockTakeErrorReport (james02)           */
/* 29-MAR-2016  Wan01    1.1  SOS#366947: SG-Stocktake LocationRoom Parm*/
/* 29-JUN-2016  Wan03    1.3  SOS#370874 - TW Add Cycle Count Strategy  */
/* 24-NOV-2016  Wan04    1.6  WMS-648 - GW StockTake Parameter2         */
/*                            Enhancement                               */
/* 13-APR-2021  NJOW02   17   Fix join UCC condition                    */
/************************************************************************/  
  
CREATE PROC [dbo].[ispCheckUCCbal] (  
@c_StockTakeKey NVARCHAR(10)  
)  
AS  
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
        @c_AgencyParm      NVARCHAR(150),  
        @c_ABCParm         NVARCHAR(60),  
        @c_SQL             nvarchar(4000),  
        @c_uccno           NVARCHAR(20),  
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
 DECLARE @c_sqlOther    NVARCHAR(4000),  
     @c_sqlWhere        NVARCHAR(4000),  
     @c_sqlGroup        NVARCHAR(4000), 
     @c_ExecStatements  NVARCHAR(4000),    -- (james02)
     @c_ErrText         NVARCHAR(100),     -- (james02)
     @c_StorerKey       NVARCHAR(15),      -- (james02)
     @c_SKU             NVARCHAR(20),      -- (james02)
     @c_LOT             NVARCHAR(10),      -- (james02)
     @c_LOC             NVARCHAR(10),      -- (james02)
     @c_ID              NVARCHAR(18)       -- (james02)
   
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
  SELECT @c_SQL = N'SELECT LOTXLOCXID.Storerkey, LOTXLOCXID.Sku, LOTXLOCXID.Lot, LOTXLOCXID.Loc, LOTXLOCXID.id '     
      + 'FROM LOC (NOLOCK) '   
                -- SOS#44960 - include QtyAllocated - QtyPicked in Qty extraction  
      + 'INNER JOIN (SELECT Storerkey, sku, lot, loc, id, sum(Qty-QtyAllocated-QtyPicked) as qty ' -- SOS#44960 (End)  
      + '    FROM LOTXLOCXID (NOLOCK) WHERE 1=1 '   
      + ISNULL(dbo.fnc_RTrim(@c_StorerSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_StorerSQL2), '')   
      + '    GROUP BY Storerkey, sku, lot, loc, id) AS LOTXLOCXID ON LOC.LOC = LOTXLOCXID.LOC '  
      + 'INNER JOIN SKU (NOLOCK) ON LOTXLOCXID.StorerKey = SKU.StorerKey AND LOTXLOCXID.SKU = SKU.SKU '   
      + 'INNER JOIN UCC (NOLOCK) ON LOTXLOCXID.StorerKey = UCC.StorerKey AND LOTXLOCXID.Sku = UCC.Sku AND LOTXLOCXID.Lot = UCC.Lot '
      + 'AND LOTXLOCXID.Loc = UCC.Loc '   
      + 'AND LOTXLOCXID.Id = UCC.Id '   
      + 'AND UCC.Status BETWEEN "1" AND "2" '   
--      + 'AND 1 = CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "OTHER") THEN 2 ELSE 1 END '  -- SOS#44960  
                  + 'AND 1 = CASE WHEN LOC.LOSEUCC = "0" THEN 1 ELSE 2 END '   -- (james02)  
      + 'INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOTATTRIBUTE.Lot = LOTXLOCXID.Lot '                   --(Wan01)          
      + 'WHERE 1 = 1  ' +  
      -- SOS42806 Add in RTRIM  
      + ISNULL(dbo.fnc_RTrim(@c_StorerSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_StorerSQL2), '') + ' '  
      + 'AND LOC.facility = "' + @c_facility + '" '  
      + ISNULL(dbo.fnc_RTrim(@c_ZoneSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ZoneSQL2), '') + ' '  
      + ISNULL(dbo.fnc_RTrim(@c_AisleSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AisleSQL2), '') + ' '  
      + ISNULL(dbo.fnc_RTrim(@c_LevelSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_LevelSQL2), '') + ' '  
      + ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL2), '') + ' '  
      + ISNULL(dbo.fnc_RTrim(@c_SKUSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_SKUSQL2), '')   
      + ISNULL(dbo.fnc_RTrim(@c_AgencySQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AgencySQL2), '')   
      + ISNULL(dbo.fnc_RTrim(@c_ABCSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ABCSQL2), '') + ' '  
      + ISNULL(dbo.fnc_RTrim(@c_SkuGroupSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_SkuGroupSQL2), '') + ' '
      + ISNULL(RTRIM(@c_ExtendedParm1SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm1SQL2), '') + ' '  --(Wan01)
      + ISNULL(RTRIM(@c_ExtendedParm2SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm2SQL2), '') + ' '  --(Wan01)
      + ISNULL(RTRIM(@c_ExtendedParm3SQL), '') + ' ' + ISNULL(RTRIM(@c_ExtendedParm3SQL2), '') + ' '  --(Wan01)
      + RTRIM(@c_StrategySQL) + ' '                                                                   --(Wan03)
      + 'GROUP BY LOTXLOCXID.Storerkey, LOTXLOCXID.Sku, LOTXLOCXID.Lot, LOTXLOCXID.Loc, LOTXLOCXID.id '  
      + 'HAVING MAX(LOTXLOCXID.QTY) <> SUM(UCC.QTY) '   
 -- Start : SOS66279  
 END   
 ELSE  
 BEGIN  
  SELECT @c_SQL = N'SELECT LOTXLOCXID.Storerkey, LOTXLOCXID.Sku, LOTXLOCXID.Lot, LOTXLOCXID.Loc, LOTXLOCXID.id '     
      + 'FROM LOC (NOLOCK) '   
                -- SOS#44960 - include QtyAllocated - QtyPicked in Qty extraction  
      + 'INNER JOIN (SELECT Storerkey, sku, lot, loc, id, sum(Qty-QtyAllocated-QtyPicked) as qty ' -- SOS#44960 (End)  
      + '    FROM LOTXLOCXID (NOLOCK) WHERE 1=1 '   
      + ISNULL(dbo.fnc_RTrim(@c_StorerSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_StorerSQL2), '')   
      + '    GROUP BY Storerkey, sku, lot, loc, id) AS LOTXLOCXID ON LOC.LOC = LOTXLOCXID.LOC '  
      + 'INNER JOIN SKU (NOLOCK) ON LOTXLOCXID.StorerKey = SKU.StorerKey AND LOTXLOCXID.SKU = SKU.SKU '   
      + 'INNER JOIN UCC (NOLOCK) ON LOTXLOCXID.StorerKey = UCC.StorerKey AND LOTXLOCXID.Sku = UCC.Sku AND LOTXLOCXID.Lot = UCC.Lot '
      + 'AND LOTXLOCXID.Loc = UCC.Loc '   
      + 'AND LOTXLOCXID.Id = UCC.Id '   
      + 'AND UCC.Status BETWEEN "1" AND "2" '   
--      + 'AND 1 = CASE WHEN LOC.LocationType IN ("DYNAMICPK", "PICK", "CASE", "OTHER") THEN 2 ELSE 1 END '  -- SOS#44960  
                  + 'AND 1 = CASE WHEN LOC.LOSEUCC = "0" THEN 1 ELSE 2 END '   -- (james02)  
      + 'INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOTATTRIBUTE.Lot = LOTXLOCXID.Lot '                   --(Wan01)        
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
          + 'ON  dbo.fnc_RTrim(dbo.fnc_LTrim(PARM2_LOC.Value)) = LOTxLOCxID.LOC '  
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
   --(Wan04) - END
 
  SELECT @c_SQLWhere = ' '   
          + 'WHERE 1 = 1  ' +  
          + ISNULL(dbo.fnc_RTrim(@c_StorerSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_StorerSQL2), '') + ' '  
          + 'AND LOC.facility = "' + ISNULL(dbo.fnc_RTrim(@c_facility), '') + '" '
          + RTRIM(@c_StrategySQL) + ' '                                    --(Wan03)  
      
  SELECT @c_SQLGroup = ' '   
          + 'GROUP BY LOTXLOCXID.Storerkey, LOTXLOCXID.Sku, LOTXLOCXID.Lot, LOTXLOCXID.Loc, LOTXLOCXID.id '  
          + 'HAVING MAX(LOTXLOCXID.QTY) <> SUM(UCC.QTY) '   
  
  SELECT @c_sql = @c_sql + ' ' + @c_sqlWhere + ' ' + @c_sqlOther + ' ' + @c_sqlGroup  
 END  
 -- End : SOS66279  

 EXEC sp_executesql @c_SQL --, N'@c_uccno NVARCHAR(20) OUTPUT ', @c_uccno OUTPUT  

 -- (james02)
 IF @@ROWCOUNT > 0
 BEGIN
   DELETE FROM STOCKTAKEERRORREPORT WHERE STOCKTAKEKEY = @c_StockTakeKey
   
   INSERT INTO STOCKTAKEERRORREPORT (STOCKTAKEKEY, ErrorNo, Type, LineText) VALUES (@c_StockTakeKey, 0, 'ERROR', 
                                     '-----------------------------------------------------')                 
   INSERT INTO STOCKTAKEERRORREPORT (STOCKTAKEKEY, ErrorNo, Type, LineText) VALUES (@c_StockTakeKey, 0, 'ERRORMSG', 
                                     'UCC QTY NOT TALLY WITH LOTXLOCXID')        
   INSERT INTO STOCKTAKEERRORREPORT (STOCKTAKEKEY, ErrorNo, Type, LineText) VALUES (@c_StockTakeKey, 0, 'ERROR',          
                                     '-----------------------------------------------------')        
   INSERT INTO STOCKTAKEERRORREPORT (STOCKTAKEKEY, ErrorNo, Type, LineText) VALUES (@c_StockTakeKey, 0, 'ERROR',        
                                CONVERT(NVARCHAR(15), 'STORERKEY')  + ' '       
                              + CONVERT(NVARCHAR(20), 'SKU')        + ' ' 
                              + CONVERT(NVARCHAR(10), 'LOT')        + ' ' 
                              + CONVERT(NVARCHAR(10), 'LOC')        + ' ' 
                              + CONVERT(NVARCHAR(18), 'ID')         + ' ' )      
   INSERT INTO STOCKTAKEERRORREPORT (STOCKTAKEKEY, ErrorNo, Type, LineText) VALUES (@c_StockTakeKey, 0, 'ERROR',       
                                CONVERT(NVARCHAR(15), REPLICATE('-', 10)) + ' '       
                              + CONVERT(NVARCHAR(20), REPLICATE('-', 20)) + ' ' 
                              + CONVERT(NVARCHAR(10), REPLICATE('-', 10)) + ' ' 
                              + CONVERT(NVARCHAR(10), REPLICATE('-', 10)) + ' ' 
                              + CONVERT(NVARCHAR(18), REPLICATE('-', 18)) + ' ' )        
                                 
   SET @c_ExecStatements = ''
   SET @c_ExecStatements = 'DECLARE CUR_LOOP CURSOR READ_ONLY FAST_FORWARD FOR '
   EXEC (@c_ExecStatements + @c_SQL)
   OPEN CUR_LOOP
   FETCH NEXT FROM CUR_LOOP INTO @c_StorerKey, @c_SKU, @c_LOT, @c_LOC, @c_ID 
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_ErrText = @c_StorerKey + ' '
      SET @c_ErrText = @c_ErrText + @c_SKU + ' '
      SET @c_ErrText = @c_ErrText + @c_LOT + ' '
      SET @c_ErrText = @c_ErrText + @c_LOC + ' '
      SET @c_ErrText = @c_ErrText + @c_ID 

      INSERT INTO STOCKTAKEERRORREPORT (STOCKTAKEKEY, ErrorNo, Type, LineText) VALUES 
                  (@c_StockTakeKey,  0, 'ERROR', @c_ErrText)     
                  
      FETCH NEXT FROM CUR_LOOP INTO @c_StorerKey, @c_SKU, @c_LOT, @c_LOC, @c_ID 
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP
 END
 
 IF @b_debug = 1  
 BEGIN  
  SELECT @c_SQL   
 END  
END       

GO