SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispPutAwayInDPQC                                    */
/* Copyright: IDS                                                       */
/* Purpose: Putaway Strategy for liquor accounts (Beam/Remy/Edrington)  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2015-05-12   James     1.0   SOS337104 Created                       */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPutAwayInDPQC]
    @n_PTraceHeadKey             NVARCHAR(10)
   ,@n_PTraceDetailKey           NVARCHAR(10)
   ,@c_PutawayStrategyKey        NVARCHAR(10)
   ,@c_PutawayStrategyLineNumber NVARCHAR(5)
   ,@c_StorerKey                 NVARCHAR(15)
   ,@c_SKU                       NVARCHAR(20)
   ,@c_LOT                       NVARCHAR(10)
   ,@c_FromLoc                   NVARCHAR(10)
   ,@c_ID                        NVARCHAR(18)
   ,@n_Qty                       INT     
   ,@c_ToLoc                     NVARCHAR(10)
   ,@c_Param1                    NVARCHAR(20)
   ,@c_Param2                    NVARCHAR(20)
   ,@c_Param3                    NVARCHAR(20)
   ,@c_Param4                    NVARCHAR(20)
   ,@c_Param5                    NVARCHAR(20)
   ,@b_debug                     INT
   ,@c_SQL                       VARCHAR( 1000) OUTPUT
   ,@b_RestrictionsPassed        INT   OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_Bonded             NVARCHAR( 1),
           @c_Facility           NVARCHAR( 5),
           @c_SuggestedLOC       NVARCHAR( 10),
           @c_PAZone             NVARCHAR( 10), 
           @c_TemperatureFlag    NVARCHAR( 30), 
           @c_PutawayZone        NVARCHAR( 10), 
           @c_Lottable01         NVARCHAR( 18), 
           @c_Lottable06         NVARCHAR( 30), 
           @c_SUSR3              NVARCHAR( 20), 
           @c_Brand              NVARCHAR( 20), 
           @d_Lottable04         DATETIME, 
           @c_PalletTotStdCube   NVARCHAR( 10), 
           @nFunc                INT

   DECLARE  @cExecStatements  NVARCHAR( 4000),  
            @cExecArguments   NVARCHAR( 4000)

   IF ISNULL( @c_LOT, '') = '' OR ISNULL( @c_SKU, '') = ''
      GOTO Quit

   SELECT @c_Lottable01 = Lottable01, 
          @d_Lottable04 = Lottable04, 
          @c_Lottable06 = Lottable06  
   FROM dbo.LotAttribute WITH (NOLOCK) 
   WHERE LOT = @c_Lot

   SET @c_SuggestedLOC = ''

   -- Get rdt function id
   SELECT @nFunc = Func, @c_Facility = Facility 
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE UserName = sUSER_sName()

  --IF @b_debug = 1
  --SET @c_Facility = 'BULIM'

   -- From loc must from DPQC
   IF NOT EXISTS ( SELECT 1 
                   FROM dbo.LOC WITH (NOLOCK) 
                   WHERE LOC = @c_FromLoc 
                   AND   LocationCategory = 'DPStage' )
      GOTO Quit

   SELECT @c_SUSR3 = SUSR3 
   FROM dbo.Storer WITH (NOLOCK) 
   WHERE StorerKey = @c_StorerKey 
   AND   [Type] = '1'

   IF ISNULL( @c_SUSR3, '') = ''
      GOTO Quit

   SELECT @c_TemperatureFlag = TemperatureFlag
   FROM dbo.SKU WITH (NOLOCK) 
   WHERE StorerKey = @c_StorerKey
   AND   SKU = @c_SKU

   SET @cExecStatements = ''
   SET @cExecStatements = 'SELECT TOP 1 @c_Brand = ' + RTRIM( @c_SUSR3) + ', ' + 
                          '@c_PutawayZone = PutawayZone ' +
                          'FROM dbo.SKU WITH (NOLOCK) ' + 
                          'WHERE StorerKey = ''' + RTRIM(@c_StorerKey)  + ''' ' +
                          'AND   SKU = ''' + RTRIM(@c_SKU)  + ''' ' 
   SET @cExecArguments = N'@c_Brand          NVARCHAR( 20) OUTPUT, ' +
                          '@c_PutawayZone    NVARCHAR( 10) OUTPUT, ' + 
                          '@c_StorerKey      NVARCHAR( 15), ' +
                          '@c_SKU            NVARCHAR( 20)  '
   EXEC sp_ExecuteSql @cExecStatements
                     , @cExecArguments
                     , @c_Brand        OUTPUT
                     , @c_PutawayZone  OUTPUT
                     , @c_StorerKey
                     , @c_SKU

   SELECT @c_PalletTotStdCube = (SKU.STDCUBE * LLI.Qty) 
   FROM SKU SKU WITH (NOLOCK)  
   JOIN LOTxLOCxID lli WITH (NOLOCK) ON ( SKU.StorerKey = LLI.StorerKey AND SKU.Sku = LLI.SKU)
   WHERE LLI.Loc = @c_FromLoc AND  
         LLI.Id  = @c_ID AND  
         LLI.StorerKey = @c_StorerKey AND  
         LLI.SKU = @c_SKU AND  
         LLI.Qty > 0  

   SET @cExecStatements = ''
   SET @cExecStatements = ' SELECT TOP 1 @c_SuggestedLOC = LLI.LOC ' + 
                          ' FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) ' +
                          ' JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC) ' +------xxxxxxxxxx
                          ' JOIN dbo.LotAttribute LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT) ' +
                          ' JOIN dbo.SKU SKU WITH (NOLOCK) ON ( LLI.SKU = SKU.SKU AND LLI.StorerKey = SKU.StorerKey) ' +
                          ' WHERE LLI.StorerKey = ''' + RTRIM(@c_StorerKey) + ''' ' +-----xxxxxx
                          ' AND   LLI.SKU = ''' + RTRIM(@c_SKU) + ''' ' +--------xxxxxx
                          ' AND   ( LLI.Qty - LLI.QtyAllocated) > 0 OR LLI.PendingMoveIn > 0 ' +
                          ' AND   LA.Lottable01 = ''' + RTRIM(@c_Lottable01) + ''' ' +
                          ' AND   ISNULL( LA.Lottable04, 0) = ' + ISNULL( @d_Lottable04, 0) + 
                          ' AND   LA.Lottable06 = ''' + RTRIM(@c_Lottable06)  + ''' ' +                             
                          ' AND   LOC.LocationRoom = ''' + RTRIM(@c_StorerKey)  + ''' ' +
                          ' AND   LOC.Facility = ''' + RTRIM(@c_Facility)  + ''' ' +---------xxxxxxxxx
                          ' AND   SKU.PutawayZone = ''' + RTRIM(@c_PutawayZone)  + ''' ' +
                          ' AND   SKU.' + RTRIM( @c_SUSR3) + ' = ''' + RTRIM(@c_Brand)  + ''' ' + 
                          ' GROUP BY LLI.LOC ' + 
                          ' HAVING MAX(LOC.CubicCapacity) - ' + 
                          '        SUM((ISNULL(LLI.Qty, 0) - ISNULL(LLI.QtyPicked,0) + ISNULL(LLI.PendingMoveIn,0))* ISNULL(SKU.STDCUBE,1)) >= ' + @c_PalletTotStdCube --------xxxxxxxx

   SET @cExecArguments = N'@c_SuggestedLOC      NVARCHAR( 10) OUTPUT, ' +
                          '@c_StorerKey         NVARCHAR( 30), '  +
                          '@c_SKU               NVARCHAR( 20), '  +                          
                          '@c_Lottable01        NVARCHAR( 18), '  +                          
                          '@d_Lottable04        DATETIME, '       +                          
                          '@c_Lottable06        NVARCHAR( 30), '  +                          
                          '@c_Facility          NVARCHAR( 5),  '  +                                                                                                        
                          '@c_TemperatureFlag   NVARCHAR( 30), '  +
                          '@c_PutawayZone       NVARCHAR( 10), '  + 
                          '@c_SUSR3             NVARCHAR( 5),  '  +                                                                                                        
                          '@c_Brand             NVARCHAR( 30), '  +
                          '@c_PalletTotStdCube  NVARCHAR( 10) '                  

   EXEC sp_ExecuteSql  @cExecStatements
                     , @cExecArguments
                     , @c_SuggestedLOC       OUTPUT
                     , @c_StorerKey 
                     , @c_SKU   
                     , @c_Lottable01 
                     , @d_Lottable04 
                     , @c_Lottable06 
                     , @c_Facility 
                     , @c_TemperatureFlag 
                     , @c_PutawayZone 
                     , @c_SUSR3 
                     , @c_Brand 
                     , @c_PalletTotStdCube

   IF @b_debug = 1
      PRINT @cExecStatements

   -- If find a friend success, goto quit
   IF ISNULL( @c_SuggestedLOC, '') <> ''
      GOTO Quit
   ELSE
   BEGIN
      -- Look for empty loc
      SELECT TOP 1 @c_SuggestedLOC = LOC.LOC 
      FROM dbo.LOC LOC WITH (NOLOCK) 
      LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)      
      WHERE LOC.LocationRoom = RTRIM(@c_StorerKey)
      AND   LOC.Facility = RTRIM(@c_Facility)
      AND   LOC.PutawayZone = RTRIM(@c_PutawayZone)
      AND   LOC.Locationflag <> 'HOLD'
      AND   LOC.Locationflag <> 'DAMAGE'
      AND   LOC.Status <> 'HOLD'
      GROUP BY LOC.LOC 
      -- Empty LOC
      HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) = 0 
      ORDER BY 1 
   END

      --IF @b_debug = 1
      --INSERT INTO TRACEINFO (TRACENAME, TIMEIN, COL1, COL2, COL3, COL4) values ('dpqc', getdate(), @c_Lot, @n_PalletTotStdCube, @c_SuggestedLOC, @c_PutawayZone)
   Quit:
   BEGIN
      SET @c_SQL = CASE WHEN ISNULL( @c_SuggestedLOC, '') = '' THEN ' AND 1 = 2' ELSE ' AND LOC.LOC = ''' + @c_SuggestedLOC + '''' END 

      RETURN
   END
END

GO