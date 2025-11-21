SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispValidateStockTakeEntry                          */
/* Creation Date: 21-March-2006                                         */
/* Copyright: IDS                                                       */
/* Written by: Vicky                                                    */
/*                                                                      */
/* Purpose: Validation on Facility and Storerkey when New Record added	*/
/*          to Stock Take Maintenance                                   */
/*                                                                      */
/* Called By: PB object nep_n_cst_ids_stocktake                         */
/*                                                                      */
/* PVCS Version: 1.0		                                                */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* 18-Jan-2008  June			SOS66279 : Include STOCKTAKEPARM2 checking	*/
/*                                                                      */
/************************************************************************/

CREATE PROC [dbo].[ispValidateStockTakeEntry] (
@c_StockTakeKey  NVARCHAR(10),
@c_Storerkey     NVARCHAR(15),
@c_Location      NVARCHAR(10),
@c_ValidateField NVARCHAR(6),
@b_Success       int OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   	
DECLARE @c_Facility	    NVARCHAR(5),
        @c_StorerParm    NVARCHAR(60),
        @c_AisleParm	    NVARCHAR(60),
        @c_LevelParm	    NVARCHAR(60),
        @c_ZoneParm	    NVARCHAR(60),
        @c_SKUParm	    NVARCHAR(125),
        @c_HostWHCodeParm  NVARCHAR(60),
        @c_ClearHistory	   NVARCHAR(1),
        @c_WithQuantity    NVARCHAR(1),
        @c_EmptyLocation   NVARCHAR(1),
        @n_LinesPerPage    int,
        @c_AgencyParm      NVARCHAR(150),
        @c_ABCParm         NVARCHAR(60),
        @c_WhereClause     NVARCHAR(2000),
        @c_WhereClauseRv   NVARCHAR(2000),
        @c_SQL    nvarchar(4000),
        @n_Count           int

-- declare a select condition variable for parameters
DECLARE @c_AisleSQL	    NVARCHAR(800),
        @c_LevelSQL	    NVARCHAR(800),
        @c_ZoneSQL	    NVARCHAR(800),
        @c_HostWHCodeSQL   NVARCHAR(800),
        @c_AisleSQL2	    NVARCHAR(800),
        @c_LevelSQL2	    NVARCHAR(800),
        @c_ZoneSQL2	    NVARCHAR(800),
        @c_HostWHCodeSQL2  NVARCHAR(800),
        @c_SKUSQL          NVARCHAR(800),
        @c_SKUSQL2		   NVARCHAR(800),
        @c_StorerSQL       NVARCHAR(800),
        @c_StorerSQL2	 NVARCHAR(800),
        @n_continue        int,
        @b_debug           int, 
        @c_sourcekey       NVARCHAR(20),
        @c_password        NVARCHAR(10),
        @c_protect         NVARCHAR(1),
        @c_AgencySQL       NVARCHAR(800),
        @c_AgencySQL2      NVARCHAR(800),
        @c_ABCSQL          NVARCHAR(800),
        @c_ABCSQL2         NVARCHAR(800),
        @c_FacilitySQL     NVARCHAR(800),
        @c_FacilitySQL2    NVARCHAR(800)

-- Start : SOS66279
DECLARE @c_sqlOther NVARCHAR(4000),
		  @c_sqlWhere NVARCHAR(4000)

SELECT  @c_sqlOther = ''
-- End : SOS66279

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
       @c_ABCParm = ABCParm         
FROM StockTakeSheetParameters (NOLOCK)
WHERE StockTakeKey = @c_StockTakeKey

IF @c_StorerParm IS NULL 
BEGIN
   SELECT @n_continue = 3
   RAISERROR ('Bad StorerKey', 16, 1)
   RETURN
END
  
SELECT @n_continue = 1, 
       @b_debug = 0,
       @n_Count = 0,
       @c_SQL = ''

EXEC ispParseParameters 
     @c_StorerParm,
     'string',
     'Storerkey',
     @c_StorerSQL OUTPUT,
     @c_StorerSQL2 OUTPUT,
     @b_success OUTPUT 
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


IF @b_debug = 1
BEGIN
     select  dbo.fnc_RTrim(@c_facility) + '" '
	   + dbo.fnc_RTrim(@c_StorerSQL) + ' ' + dbo.fnc_RTrim(@c_StorerSQL2)
	   + dbo.fnc_RTrim(@c_Location) 
      + @c_AisleSQL + ' ' + @c_AisleSQL2 + ' '
      + @c_LevelSQL + ' ' + @c_LevelSQL2 + ' '
      + @c_ZoneSQL + ' ' + @c_ZoneSQL2 + ' '
      + @c_HostWHCodeSQL + ' ' + @c_HostWHCodeSQL2 + ' '
END

IF @n_continue = 1 OR @n_continue = 2 
BEGIN 
 IF @c_ValidateField = 'STORER' 
  BEGIN   
   SELECT @c_SQL = ''
   SELECT @c_SQL = N'SELECT @n_Count = 1 FROM STORER (NOLOCK) '
   SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ' ' + 'WHERE Storerkey = N''' + ISNULL(dbo.fnc_RTrim(@c_Storerkey), '') + '''  '
   SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ' ' + ISNULL(dbo.fnc_RTrim(@c_StorerSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_StorerSQL2), '') + ' '

   IF @b_debug = 1
   BEGIN
      PRINT 'STORER VALIDATION'
      SELECT @c_SQL
   END
  END -- storer validation
  ELSE
  IF @c_ValidateField = 'LOC' 
  BEGIN
	-- Start : SOS66279
	IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) WHERE Stocktakekey = @c_StockTakeKey)
	BEGIN
	-- End : SOS66279
	   SELECT @c_SQL = ''
	   SELECT @c_SQL = N'SELECT @n_Count = 1 FROM LOC LOC (NOLOCK) ' 
	   SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ' ' + 'WHERE LOC.Facility = N''' + ISNULL(dbo.fnc_RTrim(@c_Facility), '') + '''  '
	   SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ' ' + 'AND LOC.Loc = N''' + ISNULL(dbo.fnc_RTrim(@c_Location), '') + '''  '
	   SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ISNULL(dbo.fnc_RTrim(@c_AisleSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AisleSQL2), '') + ' '
	   SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ISNULL(dbo.fnc_RTrim(@c_LevelSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_LevelSQL2), '') + ' '
	   SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ISNULL(dbo.fnc_RTrim(@c_ZoneSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ZoneSQL2), '') + ' '
	   SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL2), '') + ' '
	-- Start : SOS66279
	END 
	ELSE
	BEGIN
		SELECT @c_SQL = N'SELECT @n_Count = 1 FROM LOC LOC (NOLOCK) ' 

	   IF NOT EXISTS (SELECT 1 FROM STOCKTAKEPARM2 WITH (NOLOCK) 
					  		WHERE Stocktakekey = @c_StockTakeKey
					  		AND   UPPER(Tablename) = 'LOC')
		BEGIN
			SELECT @c_SQLOther = @c_SQLOther + ' '  		 
										+ ISNULL(dbo.fnc_RTrim(@c_ZoneSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_ZoneSQL2), '') + ' '
										+ ISNULL(dbo.fnc_RTrim(@c_AisleSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_AisleSQL2), '') + ' '
										+ ISNULL(dbo.fnc_RTrim(@c_LevelSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_LevelSQL2), '') + ' '
										+ ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL), '') + ' ' + ISNULL(dbo.fnc_RTrim(@c_HostWHCodeSQL2), '') 
		END
		ELSE
		BEGIN
			SELECT @c_SQL = @c_SQL + ' '
									 + 'JOIN STOCKTAKEPARM2 PARM2_LOC WITH (NOLOCK) '
									 + ' ON dbo.fnc_RTrim(dbo.fnc_LTrim(PARM2_LOC.Value)) = LOC.LOC '
									 + 'AND UPPER(PARM2_LOC.Tablename) = ''LOC'' ' 
									 + 'AND PARM2_LOC.Stocktakekey = N''' + ISNULL(dbo.fnc_RTrim(@c_StockTakeKey), '') + ''''
		END

		SELECT @c_SQLWhere = ' ' 
								    + 'WHERE LOC.Facility = N''' + ISNULL(dbo.fnc_RTrim(@c_Facility), '') + '''  '
								    + 'AND LOC.Loc = N''' + ISNULL(dbo.fnc_RTrim(@c_Location), '') + '''  '

		SELECT @c_sql = @c_sql + ' ' + @c_sqlWhere + ' ' + @c_sqlOther 
	END
	-- End : SOS66279

   IF @b_debug = 1
   BEGIN
      PRINT 'LOC VALIDATION'
      SELECT @c_SQL
   END
  END -- loc validation
 
   SELECT @n_Count = 0
   EXEC sp_executesql @c_SQL, N'@n_Count int OUTPUT', @n_Count OUTPUT

   IF @n_Count = 1
   BEGIN
      SELECT @b_Success = 1
   END
   ELSE
   BEGIN
     SELECT @b_Success = 0
   END

   IF @b_debug = 1
   BEGIN
      SELECT @b_Success
   END
END -- Continue =1 or 2

END

GO