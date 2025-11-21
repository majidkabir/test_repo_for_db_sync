SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispNikeSDCPA01                                      */
/* Copyright: IDS                                                       */
/* Purpose: NIKE SDC putaway strategy.                                  */
/*          Pallet 1 SKU use pallet putaway strategy                    */
/*          Pallet > 1 SKU use case putaway stragegy                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2017-02-17   James     1.0   WMS1075. Created                        */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispNikeSDCPA01]
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

   DECLARE 
      @c_PAZone01             NVARCHAR( 10), 
      @c_PAZone02             NVARCHAR( 10), 
      @c_PAZone03             NVARCHAR( 10), 
      @c_PAZone04             NVARCHAR( 10), 
      @c_PAZone05             NVARCHAR( 10), 
      @c_SearchZone           NVARCHAR(10),  
      @c_SuggestedLOC         NVARCHAR( 10), 
      @c_Facility             NVARCHAR( 5), 
      @c_MultiPutawayZone     NVARCHAR( 100), 
      @c_ExecStatements       NVARCHAR( 4000), 
      @c_ExecArguments        NVARCHAR( 4000),
      @n_Func                 INT,
      @nPutawayZoneCount      INT,
      @n_PalletTotStdCube     DECIMAL(15,5)


   SET @b_debug = 0
   
   -- Get rdt function id
   SELECT @n_Func = Func, 
          @c_Facility = Facility,
          @c_StorerKey = StorerKey
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE UserName = sUSER_sName()

   -- Get Facility
   SELECT @c_Facility = Facility 
   FROM dbo.LOC WITH (NOLOCK) 
   WHERE LOC = @c_FromLoc

   IF @n_Func = 1819
   BEGIN
      IF ISNULL( @c_ID, '') = '' OR ISNULL( @c_FromLoc, '') = ''
         GOTO Quit

      SELECT @c_PAZone01 = PutAwayZone01,
             @c_PAZone02 = PutAwayZone02,
             @c_PAZone03 = PutAwayZone03,
             @c_PAZone04 = PutAwayZone04,
             @c_PAZone05 = PutAwayZone05,
             @c_SearchZone = Zone
      FROM dbo.PutAwayStrategyDetail WITH (NOLOCK)  
      WHERE PutAwayStrategyKey = @c_PutawayStrategyKey   
      AND   PutAwayStrategyLineNumber = @c_PutawayStrategyLineNumber  

      SET @nPutawayZoneCount = 0   
      SET @c_MultiPutawayZone = ''  
  
      WHILE @nPutawayZoneCount < 5   
      BEGIN  
           
  
         IF @nPutawayZoneCount = 0  
         BEGIN  
            IF ISNULL(RTRIM(@c_PAZone01),'' )  <> ''   
            BEGIN  
                 
               SET @c_MultiPutawayZone = ',' + '''' + @c_PAZone01 + ''''  
            END  
            ELSE  
            BEGIN  
               SET @c_MultiPutawayZone = ''  
            END  
         END  
         ELSE IF @nPutawayZoneCount = 1  
         BEGIN  
            IF ISNULL(RTRIM(@c_MultiPutawayZone),'' )  <> ''   
            BEGIN  
                  SET @c_MultiPutawayZone = @c_MultiPutawayZone + CASE WHEN @c_PAZone02 <> '' THEN ' , ' + '''' + @c_PAZone02 + '''' ELSE '' END  
            END  
            ELSE  
            BEGIN  
               SET @c_MultiPutawayZone = @c_PAZone02   
            END  
         END IF @nPutawayZoneCount = 2  
         BEGIN  
            IF ISNULL(RTRIM(@c_MultiPutawayZone),'' )  <> ''   
            BEGIN  
                  SET @c_MultiPutawayZone = @c_MultiPutawayZone + CASE WHEN @c_PAZone03 <> '' THEN ' , ' + '''' + @c_PAZone03 + '''' ELSE '' END  
            END  
            ELSE  
            BEGIN  
               SET @c_MultiPutawayZone = @c_PAZone03   
            END  
         END IF @nPutawayZoneCount = 3  
         BEGIN  
            IF ISNULL(RTRIM(@c_MultiPutawayZone),'' )  <> ''   
            BEGIN  
                  SET @c_MultiPutawayZone = @c_MultiPutawayZone + CASE WHEN @c_PAZone04 <> '' THEN ' , ' + '''' + @c_PAZone04 + '''' ELSE '' END  
            END  
            ELSE  
            BEGIN  
               SET @c_MultiPutawayZone = @c_PAZone04   
            END  
         END IF @nPutawayZoneCount = 4  
         BEGIN  
            IF ISNULL(RTRIM(@c_MultiPutawayZone),'' )  <> ''   
            BEGIN  
                  SET @c_MultiPutawayZone = @c_MultiPutawayZone + CASE WHEN @c_PAZone05 <> '' THEN ' , ' + '''' + @c_PAZone05 + '''' ELSE '' END  
            END  
            ELSE  
            BEGIN  
               SET @c_MultiPutawayZone = @c_PAZone05   
            END  
         END  
           
         SET @nPutawayZoneCount = @nPutawayZoneCount + 1  
      END  

      -- Check if pallet has mix sku
      IF NOT EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID WITH (NOLOCK)
                      WHERE StorerKey = @c_StorerKey
                      AND   LOC = @c_FromLoc 
                      AND   ID = @c_ID
                      GROUP BY ID 
                      HAVING COUNT( DISTINCT SKU) > 1)
      BEGIN -- no mix sku, use pallet putaway strategy

         SELECT @n_PalletTotStdCube = (SKU.STDCUBE * LLI.Qty)
         FROM SKU SKU WITH (NOLOCK)  
         JOIN LOTxLOCxID LLI WITH (NOLOCK) ON ( SKU.StorerKey = LLI.StorerKey AND SKU.Sku = LLI.SKU)
         WHERE LLI.LOC = @c_FromLoc 
         AND   LLI.ID  = @c_ID 
         AND   LLI.Qty > 0  

         SELECT @c_ExecStatements =   
         ' SELECT TOP 1 @c_SuggestedLOC = LOC.LOC ' + 
         ' FROM dbo.LOC LOC WITH (NOLOCK) ' + 
         ' LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC) ' + 
         ' LEFT OUTER JOIN SKU WITH (NOLOCK) ON ( SKU.StorerKey = LLI.StorerKey AND SKU.SKU = LLI.SKU) ' + 
         ' WHERE LOC.Facility = N''' + @c_Facility + '''' + 
         ' AND   LOC.Locationflag <> ''HOLD'' ' + 
         ' AND   LOC.Locationflag <> ''DAMAGE'' ' + 
         ' AND   LOC.Status <> ''HOLD'' ' + 
         ' AND   LOC.PutAwayZone IN ( N''' + RTRIM(@c_SearchZone) + ''' ' + @c_MultiPutawayZone + ')' + 
         ' AND   LOC.LOC <> N''' + @c_FromLoc + '''' + 
         ' GROUP BY LOC.CubicCapacity, LOC.LOC ' + 
         -- Find a friend
         ' HAVING ISNULL(SUM((LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + LLI.PendingMoveIn), 0) > 0 ' + 
         -- fit by cube 
         ' AND    MAX( LOC.CubicCapacity) - ' + 
         '        SUM( ( ISNULL(LLI.Qty, 0) - ISNULL( LLI.QtyPicked,0) + ISNULL( LLI.PendingMoveIn,0)) * ISNULL( SKU.STDCUBE,1)) >= ' + 
                  CAST( @n_PalletTotStdCube AS NVARCHAR( 20)) 

         -- smaller loc come first
         SELECT @c_ExecStatements =  @c_ExecStatements + 
         ' ORDER BY LOC.CubicCapacity, LOC.LOC ' 

         SET @c_ExecArguments = N'@c_SuggestedLOC            NVARCHAR( 10)      OUTPUT ' 

         EXEC sp_ExecuteSql @c_ExecStatements
                           , @c_ExecArguments
                           , @c_SuggestedLOC          OUTPUT

         --IF ISNULL( @c_SuggestedLOC, '') = ''
         --BEGIN
         --   SET @c_ExecStatements = ''

         --   SELECT @c_ExecStatements =   
         --   ' SELECT TOP 1 @c_SuggestedLOC = LOC.LOC ' + 
         --   ' FROM dbo.LOC LOC WITH (NOLOCK) ' + 
         --   ' LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC) ' + 
         --   ' LEFT OUTER JOIN SKU WITH (NOLOCK) ON ( SKU.StorerKey = LLI.StorerKey AND SKU.SKU = LLI.SKU) ' + 
         --   ' WHERE LOC.Facility = N''' + @c_Facility + '''' + 
         --   ' AND   LOC.Locationflag <> ''HOLD'' ' + 
         --   ' AND   LOC.Locationflag <> ''DAMAGE'' ' + 
         --   ' AND   LOC.Status <> ''HOLD'' ' + 
         --   ' AND   LOC.PutAwayZone IN ( N''' + RTRIM(@c_SearchZone) + ''' ' + @c_MultiPutawayZone + ')' + 
         --   ' AND   LOC.LOC <> N''' + @c_FromLoc + '''' + 
         --   ' GROUP BY LOC.CubicCapacity, LOC.LOC ' + 
         --   -- Empty LOC
         --   ' HAVING ISNULL(SUM((LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + LLI.PendingMoveIn), 0) = 0 ' -- +
         --   -- fit by cube 
         --   --' AND    MAX( LOC.CubicCapacity) - ' + 
         --   --'        SUM( ( ISNULL(LLI.Qty, 0) - ISNULL( LLI.QtyPicked,0) + ISNULL( LLI.PendingMoveIn,0)) * ISNULL( SKU.STDCUBE,1)) >= ' + 
         --   --         CAST( @n_PalletTotStdCube AS NVARCHAR( 20)) 

         --   -- smaller loc come first
         --   SELECT @c_ExecStatements =  @c_ExecStatements + 
         --   ' ORDER BY LOC.CubicCapacity, LOC.LOC ' 

         --   SET @c_ExecArguments = N'@c_SuggestedLOC            NVARCHAR( 10)      OUTPUT ' 

         --   EXEC sp_ExecuteSql @c_ExecStatements
         --                     , @c_ExecArguments
         --                     , @c_SuggestedLOC          OUTPUT
         --END

         SET @c_SQL = CASE WHEN ISNULL( @c_SuggestedLOC, '') <> '' THEN ' AND LOC.LOC = ''' + @c_SuggestedLOC + '''' ELSE '' END 

      END/*
      ELSE
      BEGIN -- mix sku, use case putaway strategy
         /*
            Find a friend
            Find an empty loc
         */

         SELECT TOP 1 @cSKU = SKU
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   LOC = @cFromLoc 
         AND   ID = @cID
         AND   ( QTY - QTYAllocated - QTYPicked) > 0

         -- Find a friend
         SELECT TOP 1 @cSuggestedLOC = LOC.LOC 
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC) 
         WHERE LOC.Facility = @cFacility 
         AND   LOC.LocationCategory = 'OTHER' 
         AND   LOC.Locationflag <> 'HOLD' 
         AND   LOC.Locationflag <> 'DAMAGE' 
         AND   LOC.Status <> 'HOLD' 
         AND   LOC.LOC <> @cFromLoc
         AND   LLI.SKU = @cSKU 
         GROUP BY LOC.LOC 
         -- Not Empty LOC
         HAVING ISNULL(SUM((LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + LLI.PendingMoveIn), 0) > 0 
         ORDER BY SUM((LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + LLI.PendingMoveIn) -- loc which has min qty

         -- Find an empty loc
         IF ISNULL( @cSuggestedLOC, '') = ''
         BEGIN
            SELECT TOP 1 @cSuggestedLOC = LOC.LOC 
            FROM dbo.LOC LOC WITH (NOLOCK) 
            LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC) 
            WHERE LOC.Facility = @cFacility 
            AND   LOC.Locationflag <> 'HOLD' 
            AND   LOC.Locationflag <> 'DAMAGE' 
            AND   LOC.Status <> 'HOLD' 
            AND   LOC.LOC <> @cFromLoc 
            GROUP BY LOC.LOC  
            -- Empty LOC
            HAVING ISNULL(SUM((LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + LLI.PendingMoveIn), 0) = 0  
            ORDER BY LOC.LOC 
         END

         IF ISNULL( @cSuggestedLOC, '') = ''
            SET @cSuggLOC = ''
         ELSE
         BEGIN
            SET @cSuggLOC = @cSuggestedLOC

            EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
               ,@cFromLOC
               ,@cID
               ,@cSuggLOC
               ,@cStorerKey
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
               ,@nPABookingKey = @nPABookingKey OUTPUT
         END
      END*/
   END
END

   Quit:
      RETURN


GO