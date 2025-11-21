SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispHnMJPPA01                                        */
/* Copyright: IDS                                                       */
/* Purpose: HnM JP putaway strategy.                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2015-10-05   James     1.0   SOS301647 Created                       */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispHnMJPPA01]
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
      @c_PAZone         NVARCHAR( 10), 
      @c_SuggestedLOC   NVARCHAR( 10), 
      @c_Facility       NVARCHAR( 5), 
      @c_Lottable01     NVARCHAR( 18), 
      @c_Lottable02     NVARCHAR( 18), 
      @c_Lottable03     NVARCHAR( 18), 
      @d_Lottable04     DATETIME, 
      @d_Lottable05     DATETIME, 
      @nFunc            INT  

   DECLARE 
      @c_IsHazmat       NVARCHAR( 1), 
      @c_HazmatClass    NVARCHAR( 30) 

   SET @b_debug = 0
   
   -- Get rdt function id
   SELECT @nFunc = Func, @c_Facility = Facility FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE UserName = sUSER_sName()

   -- Get Facility
   SELECT @c_Facility = Facility 
   FROM dbo.LOC WITH (NOLOCK) 
   WHERE LOC = @c_FromLoc

   SET @c_SuggestedLOC = ''
   SET @c_PAZone = ''
   SET @c_IsHazmat = '0'

   SELECT @c_IsHazmat = CASE WHEN HazardousFlag = '1' THEN '1' ELSE 0 END
   FROM dbo.SKU WITH (NOLOCK) 
   WHERE StorerKey = @c_StorerKey
   AND   SKU = @c_SKU

   -- Putaway by sku
   IF @nFunc = 523
   BEGIN
      /* Rules
         There are 4 input parameters to search the suggest Loc.
         1#---Loc.Category=other
         2#---SKU.SKU 
         3#--- Lotattribute.Lottable01 
         4#--- Lotattribute.Lottable02 
         5#--- Lotattribute.Lottable03    -- ignore lot03-05 (update by michael 16/04/2014)
         6#--- Lotattribute.Lottable04 
         7#--- Lotattribute.Lottable05 
         If return > = 1 records, select the Loc as suggest Loc which has minimum qty. Output results will be as following:
            1#---Suggested location
            2#---On hand Qty of suggested location

         If no return record, search loc within the same sku
         if still no return record, search empty location using the zone specified 
         if still no return record, prompt no suitable loc
      */

      IF ISNULL( @c_LOT, '') = '' OR ISNULL( @c_SKU, '') = '' OR ISNULL( @c_FromLoc, '') = ''
         GOTO Quit

      -- Get Lottables
      SELECT @c_Lottable01 = Lottable01, 
             @c_Lottable02 = Lottable02  
      FROM dbo.LotAttribute WITH (NOLOCK) 
      WHERE LOT = @c_LOT

      IF @c_IsHazmat = '0'
      BEGIN
         SELECT TOP 1 @c_SuggestedLOC = LOC.LOC 
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
         WHERE LOC.Facility = @c_Facility
         AND   LOC.LocationCategory = 'OTHER'
         AND   LOC.Locationflag <> 'HOLD'
         AND   LOC.Locationflag <> 'DAMAGE'
         AND   LOC.Status <> 'HOLD'
         AND   LLI.SKU = @c_SKU
         AND   LA.Lottable01 = @c_Lottable01
         AND   LA.Lottable02 = @c_Lottable02
         GROUP BY LOC.LOC 
         -- Not Empty LOC
         HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) > 0 
         ORDER BY SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), -- loc which has min qty
                  1 
         --insert into traceinfo (tracename, timein, col1, col2, col3, col4, col5, step1) values ('hnm', getdate(), @c_Facility, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_SuggestedLOC)

         IF ISNULL( @c_SuggestedLOC, '') = ''
            SELECT TOP 1 @c_SuggestedLOC = LOC.LOC 
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
            WHERE LOC.Facility = @c_Facility
            AND   LOC.LocationCategory = 'OTHER'
            AND   LOC.Locationflag <> 'HOLD'
            AND   LOC.Locationflag <> 'DAMAGE'
            AND   LOC.Status <> 'HOLD'
            AND   LLI.SKU = @c_SKU
            GROUP BY LOC.LOC 
            -- Not Empty LOC
            HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) > 0 
            ORDER BY SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), -- loc which has min qty
                     1
         -- If cannot find loc in same sku putawayzone, then look for putawayzone setup in PUTAWAYSTRATEGYDETAIL
         IF ISNULL( @c_SuggestedLOC, '') = ''
         BEGIN
            SELECT @c_PAZone = Zone  
            FROM dbo.PutAwayStrategyDetail WITH (NOLOCK)  
            WHERE PutAwayStrategyKey = @c_PutawayStrategyKey   
            AND   PutAwayStrategyLineNumber = @c_PutawayStrategyLineNumber  

            SELECT TOP 1 @c_SuggestedLOC = LOC.LOC 
            FROM dbo.LOC LOC WITH (NOLOCK) 
            LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LOC.Facility = @c_Facility
            AND   LOC.Locationflag <> 'HOLD'
            AND   LOC.Locationflag <> 'DAMAGE'
            AND   LOC.Status <> 'HOLD'
            AND   LOC.PutAwayZone = @c_PAZone
            GROUP BY LOC.LOC 
            -- Empty LOC
            HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) = 0 
            ORDER BY 1 
         END
      END
      ELSE  -- Hazmat item putaway
      BEGIN
         -- Same lot02, same hazmat class
         SELECT TOP 1 @c_SuggestedLOC = LOC.LOC 
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
         JOIN SKUInfo SIF WITH (NOLOCK) ON ( LLI.SKU = SIF.SKU AND LLI.StorerKey = SIF.StorerKey)
         WHERE LOC.Facility = @c_Facility
         AND   LOC.Locationflag <> 'HOLD'
         AND   LOC.Locationflag <> 'DAMAGE'
         AND   LOC.Status <> 'HOLD'
         AND   LLI.SKU = @c_SKU
         AND   LA.Lottable02 = @c_Lottable02
         AND   LOC.LocationCategory = SIF.ExtendedField01 
         GROUP BY LOC.LOC 
         -- Not Empty LOC
         HAVING ISNULL( SUM( LLI.Qty - LLI.QtyPicked), 0) > 0 OR ISNULL( SUM( LLI.PendingMoveIn), 0) > 0 
         ORDER BY SUM(LLI.Qty - LLI.QtyPicked), 1 -- order by loc which has min qty then by loc

         IF ISNULL( @c_SuggestedLOC, '') = ''
            -- Same lot01, same hazmat class
            SELECT TOP 1 @c_SuggestedLOC = LOC.LOC 
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
            JOIN SKUInfo SIF WITH (NOLOCK) ON ( LLI.SKU = SIF.SKU AND LLI.StorerKey = SIF.StorerKey)
            WHERE LOC.Facility = @c_Facility
            AND   LOC.Locationflag <> 'HOLD'
            AND   LOC.Locationflag <> 'DAMAGE'
            AND   LOC.Status <> 'HOLD'
            AND   LLI.SKU = @c_SKU
            AND   LA.Lottable01 = @c_Lottable01
            AND   LOC.LocationCategory = SIF.ExtendedField01 
            GROUP BY LOC.LOC 
            -- Not Empty LOC
            HAVING ISNULL( SUM( LLI.Qty - LLI.QtyPicked), 0) > 0 OR ISNULL( SUM( LLI.PendingMoveIn), 0) > 0 
            ORDER BY SUM(LLI.Qty - LLI.QtyPicked), 1 -- order by loc which has min qty then by loc

         IF ISNULL( @c_SuggestedLOC, '') = ''
            -- Same sku, same hasmat class
            SELECT TOP 1 @c_SuggestedLOC = LOC.LOC 
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
            JOIN SKUInfo SIF WITH (NOLOCK) ON ( LLI.SKU = SIF.SKU AND LLI.StorerKey = SIF.StorerKey)
            WHERE LOC.Facility = @c_Facility
            AND   LOC.Locationflag <> 'HOLD'
            AND   LOC.Locationflag <> 'DAMAGE'
            AND   LOC.Status <> 'HOLD'
            AND   LLI.SKU = @c_SKU
            AND   LOC.LocationCategory = SIF.ExtendedField01 
            GROUP BY LOC.LOC 
            -- Not Empty LOC
            HAVING ISNULL( SUM( LLI.Qty - LLI.QtyPicked), 0) > 0 OR ISNULL( SUM( LLI.PendingMoveIn), 0) > 0 
            ORDER BY SUM(LLI.Qty - LLI.QtyPicked), 1 -- order by loc which has min qty then by loc

         IF ISNULL( @c_SuggestedLOC, '') = ''
            -- Same hazmat class
            SELECT TOP 1 @c_SuggestedLOC = LOC.LOC 
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
            JOIN SKUInfo SIF WITH (NOLOCK) ON ( LLI.SKU = SIF.SKU AND LLI.StorerKey = SIF.StorerKey)
            WHERE LOC.Facility = @c_Facility
            AND   LOC.Locationflag <> 'HOLD'
            AND   LOC.Locationflag <> 'DAMAGE'
            AND   LOC.Status <> 'HOLD'
            AND   LOC.LocationCategory = SIF.ExtendedField01 
            GROUP BY LOC.LOC 
            -- Not Empty LOC
            HAVING ISNULL( SUM( LLI.Qty - LLI.QtyPicked), 0) > 0 OR ISNULL( SUM( LLI.PendingMoveIn), 0) > 0 
            ORDER BY SUM(LLI.Qty - LLI.QtyPicked), 1 -- order by loc which has min qty then by loc
      END

      IF ISNULL(@c_SuggestedLOC, '') = '' 
      BEGIN
         GOTO Quit
      END 
   END
   ELSE IF @nFunc = 521
   BEGIN
      SELECT @c_HazmatClass = SIF.ExtendedField01
      FROM dbo.SKU WITH (NOLOCK)
      JOIN SKUInfo SIF WITH (NOLOCK) ON ( SKU.SKU = SIF.SKU AND SKU.StorerKey = SIF.StorerKey)
      WHERE SKU.StorerKey = @c_StorerKey
      AND   SKU.SKU = @c_SKU

      -- Find an empty loc 
      -- If sku is hazmat then look for empty loc with same hazmat class
      -- Else look for empty loc in location category OTHER
      SELECT TOP 1 @c_SuggestedLOC = LOC.LOC
      FROM LOC LOC WITH (NOLOCK) 
      LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC) 
      WHERE LOC.Facility = @c_Facility
      AND   LOC.LocationCategory = CASE WHEN @c_IsHazmat = '0' THEN 'OTHER' ELSE @c_HazmatClass END
      AND   LOC.Locationflag <> 'HOLD'
      AND   LOC.Locationflag <> 'DAMAGE'
      AND   LOC.Status <> 'HOLD'
      GROUP BY LOC.LogicalLocation, LOC.LOC 
      HAVING ISNULL( SUM(LLI.Qty - LLI.QtyPicked), 0) = 0 
      AND   ISNULL( SUM(LLI.PendingMoveIn), 0) = 0
      ORDER BY LOC.LogicalLocation, LOC.LOC 

      -- Generic ucc putaway not allow to have blank suggested loc
      -- For H&M JP, they can key in they desired loc to proceed
      -- So suggest a dummy LOC and let the screen pass
      IF ISNULL( @c_SuggestedLOC, '') = ''
         SET @c_SuggestedLOC = 'DUMMYLOC'
   END
   ELSE
      GOTO Quit
   
   Quit:
   BEGIN
      SET @c_SQL = CASE WHEN ISNULL( @c_SuggestedLOC, '') = '' THEN ' AND 1 = 2' ELSE ' AND LOC.LOC = ''' + @c_SuggestedLOC + '''' END 

      RETURN
   END
END

GO