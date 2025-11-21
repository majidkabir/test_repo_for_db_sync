SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispLot6PutAwayByBond                                */
/* Copyright: IDS                                                       */
/* Purpose: Putaway Strategy for Lottable06 Bonded and Unbounded Putaway*/
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2015-05-12   James     1.0   SOS336667 Created                       */
/* 2015-11-26   Chris     1.1   Update fixed text UNBONDED to NONBONDED */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispLot6PutAwayByBond]
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

   DECLARE @c_Bonded          NVARCHAR( 1),
           @c_NONBONDED        NVARCHAR( 1),  
           @c_Short           NVARCHAR( 10),  
           @c_Facility        NVARCHAR( 5),
           @c_SuggestedLOC    NVARCHAR( 10),
           @c_Lottable06	   NVARCHAR( 60), 
           @c_PAZone          NVARCHAR( 10), 
           @nFunc             INT  

   SET @b_debug = 0

   IF ISNULL( @c_LOT, '') = '' OR ISNULL( @c_SKU, '') = ''
      GOTO Quit

   SET @c_SuggestedLOC = ''

   -- Get rdt function id
   SELECT @nFunc = Func, @c_Facility = Facility 
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE UserName = sUSER_sName()

   -- Get Lottables
   SELECT @c_Lottable06 = Lottable06 
   FROM dbo.LotAttribute WITH (NOLOCK) 
   WHERE LOT = @c_LOT

   SELECT TOP 1 @c_Short = Short
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'BONDFAC'
      AND StorerKey = @c_StorerKey
      AND Code = @c_Lottable06

   IF @c_Short = 'NONBONDED'
   BEGIN
      SELECT @c_PAZone = PutawayZone  
      FROM dbo.SKU WITH (NOLOCK)  
      WHERE StorerKey = @c_StorerKey
      AND   SKU = @c_SKU

      SELECT TOP 1 @c_SuggestedLOC = LOC.LOC 
      FROM dbo.LOC LOC WITH (NOLOCK) 
      LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE LOC.Facility = @c_Facility
      --AND   LOC.Locationflag <> 'HOLD'
      --AND   LOC.Locationflag <> 'DAMAGE'
      --AND   LOC.Status <> 'HOLD'
      AND   LOC.PutAwayZone = @c_PAZone
      GROUP BY LOC.LOC 
      -- Empty LOC
      HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) = 0 
      ORDER BY 1 
   END
   ELSE  -- Non Bonded
   BEGIN
      /*
      SELECT TOP 1 @c_SuggestedLOC = LOC.LOC 
      FROM dbo.LOC LOC WITH (NOLOCK) 
      LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE LOC.Facility = @c_Facility
      AND   LOC.Locationflag <> 'HOLD'
      AND   LOC.Locationflag <> 'DAMAGE'
      AND   LOC.Status <> 'HOLD'
      and   LOC.LocationRoom = @c_StorerKey 
      GROUP BY LOC.LOC 
      -- Empty LOC
      HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) = 0 
      ORDER BY 1 
      */
      SET @c_SuggestedLOC = 'ASRS IN'
    END


   Quit:
   BEGIN
      SET @c_SQL = CASE WHEN ISNULL( @c_SuggestedLOC, '') = '' THEN ' AND 1 = 2' ELSE ' AND LOC.LOC = ''' + @c_SuggestedLOC + '''' END 

      RETURN
   END
END



GO