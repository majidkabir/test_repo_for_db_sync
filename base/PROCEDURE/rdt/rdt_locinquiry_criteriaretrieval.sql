SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_LOCInquiry_CriteriaRetrieval                    */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purposes:                                                            */
/* 1) To Retrieve candidate Locations with arguments parsed in          */
/* 2) Call From rdtfnc_LOCInquiry                                       */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2007-11-16  1.0  Vicky       Created                                 */
/* 2011-04-19  1.1  James       Add database parameter                  */
/************************************************************************/

CREATE PROC [RDT].[rdt_LOCInquiry_CriteriaRetrieval] (
   @cPutawayZone    NVARCHAR(10),
   @cPickZone       NVARCHAR(10),
   @cAisle          NVARCHAR(10),
   @cLevel          NVARCHAR(4),
   @cStartLoc       NVARCHAR(10),
   @cEmpty          NVARCHAR( 1), -- 1 = YES, 2 = NO
   @cHold           NVARCHAR( 1), -- 1 = YES, 2 = NO
   @cLocType        NVARCHAR( 1), -- 1 = BULK, 2 = PICK
   @cFirstTime      NVARCHAR( 1), -- Y = YES, N = NO
   @cFacility       NVARCHAR( 5),
   @cLOC1           NVARCHAR(10)    OUTPUT,
   @cIDCnt1         NVARCHAR(3)     OUTPUT,
   @cMaxPallet1     NVARCHAR(2)     OUTPUT,
   @cLOC2           NVARCHAR(10)    OUTPUT,
   @cIDCnt2         NVARCHAR(3)     OUTPUT,
   @cMaxPallet2     NVARCHAR(2)     OUTPUT,
   @cLOC3           NVARCHAR(10)    OUTPUT,
   @cIDCnt3         NVARCHAR(3)     OUTPUT,
   @cMaxPallet3     NVARCHAR(2)     OUTPUT,
   @cLOC4           NVARCHAR(10)    OUTPUT,
   @cIDCnt4         NVARCHAR(3)     OUTPUT,
   @cMaxPallet4     NVARCHAR(2)     OUTPUT,
   @cLOC5           NVARCHAR(10)    OUTPUT,
   @cIDCnt5         NVARCHAR(3)     OUTPUT,
   @cMaxPallet5     NVARCHAR(2)     OUTPUT,
   @cLOC6           NVARCHAR(10)    OUTPUT,
   @cIDCnt6         NVARCHAR(3)     OUTPUT,
   @cMaxPallet6     NVARCHAR(2)     OUTPUT,
   @cLOC7           NVARCHAR(10)    OUTPUT,
   @cIDCnt7         NVARCHAR(3)     OUTPUT,
   @cMaxPallet7     NVARCHAR(2)     OUTPUT,
   @cLOC8           NVARCHAR(10)    OUTPUT,
   @cIDCnt8         NVARCHAR(3)     OUTPUT,
   @cMaxPallet8     NVARCHAR(2)     OUTPUT,
   @cLOC9           NVARCHAR(10)    OUTPUT,
   @cIDCnt9         NVARCHAR(3)     OUTPUT,
   @cMaxPallet9     NVARCHAR(2)     OUTPUT,
   @cLOC10          NVARCHAR(10)    OUTPUT,
   @cIDCnt10        NVARCHAR(3)     OUTPUT,
   @cMaxPallet10    NVARCHAR(2)     OUTPUT,
   @cMoreRec        NVARCHAR(1)     OUTPUT
) AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cSQL             NVARCHAR(4000),
           @cSQL1            NVARCHAR(4000),
           @cExecStatements  NVARCHAR(4000),
           @cExecArguments   NVARCHAR(4000),
           @n_debug          INT

   DECLARE @nLevel           INT,
           @nIDCnt           INT,
           @nMaxPallet       INT,
           @cLOC             NVARCHAR(10),
           @cIDCnt           NVARCHAR(3),
           @cMaxPallet       NVARCHAR(2)

   DECLARE @nRecCnt          INT

   SET @n_debug = 1
   SET @cSQL = ''
   SET @cSQL1 = ''
   SET @nRecCnt = 0
   SET @cMoreRec = 'Y'

   SET @cLOC1 = ''
	SET @cIDCnt1 = ''
	SET @cMaxPallet1 = ''
   SET @cLOC2 = ''
	SET @cIDCnt2 = ''
	SET @cMaxPallet2 = ''
   SET @cLOC3 = ''
	SET @cIDCnt3 = ''
	SET @cMaxPallet3 = ''
   SET @cLOC4 = ''
	SET @cIDCnt4 = ''
	SET @cMaxPallet4 = ''
   SET @cLOC5 = ''
	SET @cIDCnt5 = ''
	SET @cMaxPallet5 = ''
   SET @cLOC6 = ''
	SET @cIDCnt6 = ''
	SET @cMaxPallet6 = ''
   SET @cLOC7 = ''
	SET @cIDCnt7 = ''
	SET @cMaxPallet7 = ''
   SET @cLOC8 = ''
	SET @cIDCnt8 = ''
	SET @cMaxPallet8 = ''
   SET @cLOC9 = ''
	SET @cIDCnt9 = ''
	SET @cMaxPallet9 = ''
   SET @cLOC10 = ''
	SET @cIDCnt10 = ''
	SET @cMaxPallet10 = ''

   IF @cLocType = '1'
   BEGIN
      SELECT @cSQL = RTRIM(@cSQL) + 'WHERE LOC.LocationType NOT IN ( ''PICK'', ''CASE'') '
   END
   ELSE IF @cLocType = '2'
   BEGIN
      SELECT @cSQL = RTRIM(@cSQL) + 'WHERE LOC.LocationType IN (''PICK'', ''CASE'') '
   END

   IF @cPutawayZone <> '' AND @cPutawayZone IS NOT NULL
   BEGIN
      SELECT @cSQL = RTRIM(@cSQL) + ' AND LOC.Putawayzone = N''' + RTRIM(@cPutawayZone) + ''' '
   END

   IF @cPickZone <> '' AND @cPickZone IS NOT NULL
   BEGIN
      SELECT @cSQL = RTRIM(@cSQL) + ' AND LOC.PickZone = N''' + RTRIM(@cPickZone) + ''' '
   END

   IF @cPickZone <> '' AND @cPickZone IS NOT NULL
   BEGIN
      SELECT @cSQL = RTRIM(@cSQL) + ' AND LOC.PickZone = N''' + RTRIM(@cPickZone) + ''' '
   END

   IF @cAisle <> '' AND @cAisle IS NOT NULL
   BEGIN
      SELECT @cSQL = RTRIM(@cSQL) + ' AND LOC.LocAisle = N''' + RTRIM(@cAisle) + ''' '
   END

   IF @cLevel <> '' AND @cLevel IS NOT NULL
   BEGIN
      SELECT @cSQL = RTRIM(@cSQL) + ' AND LOC.LocLevel = N''' + RTRIM(@cLevel) + ''' '
   END

   IF @cStartLoc <> '' AND @cStartLoc IS NOT NULL
   BEGIN
     IF @cFirstTime = 'Y'
     BEGIN
      SELECT @cSQL = RTRIM(@cSQL) + ' AND LOC.LOC >= N''' + RTRIM(@cStartLoc) + ''' '
     END
     ELSE
     BEGIN
      SELECT @cSQL = RTRIM(@cSQL) + ' AND LOC.LOC > N''' + RTRIM(@cStartLoc) + ''' '
     END
   END
   IF @cHold = '1'
   BEGIN
      SELECT @cSQL = RTRIM(@cSQL) + ' AND (LOC.Status = ''HOLD'' OR LOC.LocationFlag = ''DAMAGE'' ' +
                                  + ' OR LOC.LocationFlag = ''HOLD'' ) '
   END
   ELSE IF @cHold = '2'
   BEGIN
      SELECT @cSQL = RTRIM(@cSQL) + ' AND (LOC.Status = ''OK'' AND LOC.LocationFlag <> ''DAMAGE'' ' +
                                    ' AND LOC.LocationFlag <> ''HOLD'' ) '
   END

   IF @cEmpty = '1'
   BEGIN
      SELECT @cSQL1 = RTRIM(@cSQL1) + ' HAVING ISNULL(SUM(LLI.Qty - LLI.QtyPicked), 0) = 0 '
   END
   ELSE IF @cEmpty = '2'
   BEGIN
      SELECT @cSQL1 = RTRIM(@cSQL1) + ' HAVING ISNULL(SUM(LLI.Qty - LLI.QtyPicked), 0) > 0 '
   END

   SELECT @cSQL = RTRIM(@cSQL)
   SELECT @cSQL1 = RTRIM(@cSQL1)

   IF @n_debug = 1
   BEGIN
     Print @cSQL
     Print @cSQL1
   END

	SET @cExecStatements = ''
	SET @cExecArguments = ''


   SET @cExecStatements = N'DECLARE C_LOC CURSOR FAST_FORWARD READ_ONLY FOR '
                           + 'SELECT TOP 10 LOC.LOC, COUNT(DISTINCT LLI.ID), LOC.MaxPallet '
                           + ' FROM dbo.LOC LOC WITH (NOLOCK)'
                           + ' LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) '
                           + ' ON (LLI.LOC = LOC.LOC AND (LLI.Qty - LLI.QtyPicked ) > 0 ) '
                           + @cSQL
                           + ' AND LOC.Facility = N''' + RTRIM(@cFacility) + ''' '
                           + ' GROUP BY LOC.LOC, LOC.MaxPallet '
                           + @cSQL1
                           + ' ORDER BY LOC.LOC '

   IF @n_debug = 1
   BEGIN
     Print @cExecStatements
   END

   SET @cExecArguments = N'@cLOC       NVARCHAR(10), ' +
                           '@nIDCnt     INT, ' +
                           '@nMaxPallet INT '

	IF @n_debug = 1
	BEGIN
	   PRINT @cExecStatements
	END

   EXEC sp_ExecuteSql @cExecStatements
   , @cExecArguments
                    , @cLOC
                    , @nIDCnt
                    , @nMaxPallet

   OPEN C_LOC
   FETCH NEXT FROM C_LOC INTO @cLOC, @nIDCnt, @nMaxPallet

   WHILE @@FETCH_STATUS <> -1
   BEGIN

     SELECT @nRecCnt = @nRecCnt + 1

	     IF @nRecCnt = 1
	     BEGIN
	        SELECT @cLOC1 = @cLOC
	        SELECT @cIDCnt1 = CONVERT(CHAR(3), @nIDCnt)
	        SELECT @cMaxPallet1 = CONVERT(CHAR(2), @nMaxPallet)
	     END

	     IF @nRecCnt = 2
	     BEGIN
	        SELECT @cLOC2 = @cLOC
	        SELECT @cIDCnt2 = CONVERT(CHAR(3), @nIDCnt)
	        SELECT @cMaxPallet2 = CONVERT(CHAR(2), @nMaxPallet)
	     END

	     IF @nRecCnt = 3
	     BEGIN
	        SELECT @cLOC3 = @cLOC
	        SELECT @cIDCnt3 = CONVERT(CHAR(3), @nIDCnt)
	        SELECT @cMaxPallet3 = CONVERT(CHAR(2), @nMaxPallet)
	     END

	     IF @nRecCnt = 4
	     BEGIN
	        SELECT @cLOC4 = @cLOC
	        SELECT @cIDCnt4 = CONVERT(CHAR(3), @nIDCnt)
	        SELECT @cMaxPallet4 = CONVERT(CHAR(2), @nMaxPallet)
	     END

	     IF @nRecCnt = 5
	     BEGIN
	        SELECT @cLOC5 = @cLOC
	        SELECT @cIDCnt5 = CONVERT(CHAR(3), @nIDCnt)
	        SELECT @cMaxPallet5 = CONVERT(CHAR(2), @nMaxPallet)
	     END

	     IF @nRecCnt = 6
	     BEGIN
	        SELECT @cLOC6 = @cLOC
	        SELECT @cIDCnt6 = CONVERT(CHAR(3), @nIDCnt)
	        SELECT @cMaxPallet6 = CONVERT(CHAR(2), @nMaxPallet)
	     END

	     IF @nRecCnt = 7
	     BEGIN
	        SELECT @cLOC7 = @cLOC
	        SELECT @cIDCnt7 = CONVERT(CHAR(3), @nIDCnt)
	        SELECT @cMaxPallet7 = CONVERT(CHAR(2), @nMaxPallet)
	     END

	     IF @nRecCnt = 8
	     BEGIN
	        SELECT @cLOC8 = @cLOC
	        SELECT @cIDCnt8 = CONVERT(CHAR(3), @nIDCnt)
	        SELECT @cMaxPallet8 = CONVERT(CHAR(2), @nMaxPallet)
	     END

	     IF @nRecCnt = 9
	     BEGIN
	        SELECT @cLOC9 = @cLOC
	        SELECT @cIDCnt9 = CONVERT(CHAR(3), @nIDCnt)
	        SELECT @cMaxPallet9 = CONVERT(CHAR(2), @nMaxPallet)
	     END

	     IF @nRecCnt = 10
	     BEGIN
	        SELECT @cLOC10 = @cLOC
	        SELECT @cIDCnt10 = CONVERT(CHAR(3), @nIDCnt)
	        SELECT @cMaxPallet10 = CONVERT(CHAR(2), @nMaxPallet)
	     END


      FETCH NEXT FROM C_LOC INTO @cLOC, @nIDCnt, @nMaxPallet
   END -- WHILE @@FETCH_STATUS <> -1
   CLOSE C_LOC
   DEALLOCATE C_LOC

   IF @cLOC1 = ''
   BEGIN
     SET @cMoreRec = 'N'
   END
END


GO