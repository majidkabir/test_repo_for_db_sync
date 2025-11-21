SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispHnMPA01                                          */
/* Copyright: IDS                                                       */
/* Purpose: HnM putaway strategy. This storer has different PA strategy */
/*          for different putaway method for the same sku.              */
/*          so we need to use putcode to diffentiate                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2013-03-14   James     1.0   SOS301647 Created                       */
/* 2014-11-02   James     1.1   Performance tuning (james01)            */
/* 2016-05-20   NJOW01    1.2   369889-cater for non-RDT. Lottable03=STD*/                              
/************************************************************************/

CREATE PROCEDURE [dbo].[ispHnMPA01]
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
      @nFunc            INT,
      @n_IsRDT          INT --NJOW01

   SET @b_debug = 0
   
   -- Get rdt function id
   SELECT @nFunc = Func, @c_Facility = Facility FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE UserName = sUSER_sName()

   -- Get Facility
   SELECT @c_Facility = Facility 
   FROM dbo.LOC WITH (NOLOCK) 
   WHERE LOC = @c_FromLoc

   SET @c_SuggestedLOC = ''
   SET @c_PAZone = ''


   -- Putaway by sku
   --IF @nFunc = 523

   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT  --NJOW01
   IF @nFunc = 523 OR @n_IsRDT <> 1 --NJOW01
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
      AND   LA.Lottable03 = 'STD' --NJOW01
      GROUP BY LOC.LOC 
      -- Not Empty LOC
      HAVING ISNULL(SUM((LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + LLI.PendingMoveIn), 0) > 0 
      ORDER BY SUM((LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + LLI.PendingMoveIn), -- loc which has min qty
      --HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) > 0 
      --ORDER BY SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), -- loc which has min qty
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
         AND   LA.Lottable03 = 'STD' --NJOW01
         GROUP BY LOC.LOC 
         -- Not Empty LOC
         HAVING ISNULL(SUM((LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + LLI.PendingMoveIn), 0) > 0 
         ORDER BY SUM((LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + LLI.PendingMoveIn), -- loc which has min qty
         --HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) > 0 
         --ORDER BY SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), -- loc which has min qty
                  1
      -- If cannot find loc in same sku putawayzone, then look for putawayzone setup in PUTAWAYSTRATEGYDETAIL
      
      --NJOW01 remove
      /*
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
         HAVING ISNULL(SUM((LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + LLI.PendingMoveIn), 0) = 0 
         --HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) = 0 
         ORDER BY 1 
      END
      */      

      IF ISNULL(@c_SuggestedLOC, '') = '' 
      BEGIN
         GOTO Quit
      END 
   END
   ELSE IF @nFunc = 521
   BEGIN
      /*
      Suggest an empty loc(Loc.Category = 'Other'), but can be over written;
      If same SKU has stock in WMS, empty location with same putawayzone will be commended at first;
      If above location can't be found, find empty loc from other putawayzone.
      */

      SELECT TOP 1 @c_PAZone = LOC.PutAwayZone  -- Stock can exists in more than 1 zone, get TOP 1
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE LOC.Facility = @c_Facility
      AND   LOC.LocationCategory = 'OTHER'
      AND   LOC.Locationflag <> 'HOLD'
      AND   LOC.Locationflag <> 'DAMAGE'
      AND   LOC.Status <> 'HOLD'
      AND   LLI.SKU = @c_SKU
      GROUP BY LOC.PutAwayZone 
      -- Not Empty LOC
      HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) > 0 
      ORDER BY 1 

      GOTO Quit
   END
   ELSE
      GOTO Quit
   
   Quit:
   BEGIN
      IF @nFunc = 521
         -- If sku has stock in same pa zone then use same pa zone else no need filter pa zone (look for other/any pa zone)
         SET @c_SQL = CASE WHEN ISNULL( @c_PAZone, '') = '' THEN ' AND LOC.PutAwayZone = LOC.PutAwayZone' ELSE ' AND LOC.PutAwayZone = ''' + @c_PAZone + '''' END 
      ELSE
         SET @c_SQL = CASE WHEN ISNULL( @c_SuggestedLOC, '') = '' THEN ' AND 1 = 2' ELSE ' AND LOC.LOC = ''' + @c_SuggestedLOC + '''' END 

      RETURN
   END
END

GO