SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_GetTransitLoc05                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get transit LOC by 3 hierarchy levels                       */
/*          1. P&D                                                      */
/*          2. PutawayZone                                              */
/*          3. StorerConfig InTransitLOC                                */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 10-10-2018  1.0  ChewKP    WMS-5223 - Allow Same PutawayZone Transit */
/*                            (ChewKP01)                                */
/************************************************************************/

CREATE PROC [RDT].[rdt_GetTransitLoc05] (
   @cUserName   NVARCHAR( 10),
   @cStorerKey  NVARCHAR( 15),
   @cSKU        NVARCHAR( 20),
   @nQTY        INT,
   @cFromLOC    NVARCHAR(10),
   @cFromID     NVARCHAR(18),
   @cToLOC      NVARCHAR(10),
   @nLockLOC    INT = 0,    -- Lock PND transit LOC. 1=Yes, 0=No
   @cTransitLOC NVARCHAR(10)  OUTPUT,
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR(20)  OUTPUT,
   @nFunc       INT = 0
) AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_success       INT
   DECLARE @cGITLOC         NVARCHAR( 10)
   DECLARE @cFacility       NVARCHAR( 5)

   DECLARE @cFromLOCAisle   NVARCHAR( 10)
   DECLARE @cFromLOCCat     NVARCHAR( 10)
   DECLARE @cFromLOCInVNA   INT
   DECLARE @cFromPAZone     NVARCHAR( 10)
   DECLARE @cFromPAOutLOC   NVARCHAR( 10)
   DECLARE @cFromTransitLOC NVARCHAR( 10)

   DECLARE @cToLOCAisle     NVARCHAR( 10)
   DECLARE @cToLOCCat       NVARCHAR( 10)
   DECLARE @cToLOCInVNA     INT
   DECLARE @cToPAZone       NVARCHAR( 10)
   DECLARE @cToPAInLOC      NVARCHAR( 10)
   DECLARE @cToTransitLOC   NVARCHAR( 10)

   -- Init var
   SET @nErrNo = 0
   SET @cErrMsg = ''
   SET @cFromTransitLOC = ''
   SET @cToTransitLOC = ''
   SET @cTransitLOC = ''

   -- Get FromLOC info
   SELECT
      @cFacility = Facility,
      @cFromPAZone = PutawayZone,
      @cFromLOCAisle  = LocAisle,
      @cFromLOCCat = LocationCategory
   FROM LOC WITH (NOLOCK)
   WHERE LOC = @cFromLOC

   -- Check if FromLOC in VNA (i.e. the aisle had PND location setup)
   IF EXISTS(  SELECT 1 FROM LOC WITH (NOLOCK)
               WHERE Facility = @cFacility
               -- AND PutawayZone = @cFromPAZone
               AND LOCAisle = @cFromLOCAisle
               AND LocationCategory IN ('PND', 'PND_IN', 'PND_OUT') )
         AND @cFromLOCAisle <> '' -- and LocAisle is setup
         AND @cFromLOCCat NOT IN ('PND', 'PND_IN', 'PND_OUT') -- and itself is not PND
      SET @cFromLOCInVNA = 1 --Yes
   ELSE
      SET @cFromLOCInVNA = 0 --No

   -- Get ToLOC info
   SELECT
      @cToPAZone = PutawayZone,
      @cToLOCAisle  = LocAisle,
      @cToLOCCat = LocationCategory
   FROM LOC WITH (NOLOCK)
   WHERE LOC = @cToLOC

   -- Check if ToLOC in VNA (i.e. the aisle had PND setup)
   IF EXISTS(  SELECT 1 FROM LOC WITH (NOLOCK)
               WHERE Facility = @cFacility
               -- AND PutawayZone = @cToPAZone
               AND LOCAisle = @cToLOCAisle
               AND LocationCategory IN ('PND', 'PND_IN', 'PND_OUT') )
         AND @cToLOCAisle <> '' -- and LocAisle is setup
         AND @cToLOCCat NOT IN ('PND', 'PND_IN', 'PND_OUT') -- and itself is not PND
      SET @cToLOCInVNA = 1 --Yes
   ELSE
      SET @cToLOCInVNA = 0 --No

   -- Get FromPAZone info
   SELECT @cFromPAOutLOC = OutLOC FROM PutawayZone WITH (NOLOCK) WHERE PutawayZone = @cFromPAZone

   -- Get ToPAZone info
   SELECT @cToPAInLOC = InLOC FROM PutawayZone WITH (NOLOCK) WHERE PutawayZone = @cToPAZone

   -- Get GIT LOC
   SET @cGITLOC = rdt.RDTGetConfig( 0, 'InTransitLOC', @cStorerKey)

   IF @cGITLOC = '0'
      SET @cGITLOC = ''

   -- In same zone
   IF @cFromPAZone = @cToPAZone
   BEGIN
      -- From To is VNA, in same aisle, no transit required
      IF @cFromLOCInVNA = 1 AND @cToLOCInVNA = 1 AND
         @cFromLOCAisle = @cToLOCAisle
      BEGIN
         SET @cTransitLOC = @cToLOC
         GOTO Quit
      END

      -- From To is non-VNA, no transit required
      IF @cFromLOCInVNA = 0 AND @cToLOCInVNA = 0
      BEGIN
         -- (ChewKP01) 
         IF @cFromLocAisle = @cToLocAisle 
         BEGIN
            SET @cTransitLOC = @cToLOC
            GOTO Quit
         END
      END
   END

   /*-------------------------------------------------------------------------------

                                       FromLOC section

   -------------------------------------------------------------------------------*/
   -- Check if FromLOC already a PND LOC / zone out LOC / GITLOC
   IF @cFromLOCCat = 'PND' OR
      @cFromLOC = @cFromPAOutLOC OR
      @cFromLOC = @cGITLOC
      GOTO ToLOC

   -- 1. VNA level
   IF @cFromLOCinVNA = 1 --Yes
   BEGIN
      -- Find an empty PND location for execute task
      IF @nLockLOC = 1 --Yes
      BEGIN
         -- Get an empty PND LOC
--         SELECT TOP 1
--             @cFromTransitLOC = LOC.LOC
--         FROM LOC WITH (NOLOCK)
--            LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC AND (LLI.QTY > 0 OR LLI.PendingMoveIN > 0))
--         WHERE Facility = @cFacility
--            -- AND PutawayZone = @cFromPAZone
--            AND LOCAisle = @cFromLOCAisle
--            AND LocationCategory IN ('PND', 'PND_OUT')
--         GROUP BY LOC.LogicalLocation, LOC.LOC, LOC.MaxPallet
--         HAVING COUNT( DISTINCT LLI.ID) < LOC.MaxPallet
--         ORDER BY LOC.LogicalLocation, LOC.LOC

         SELECT TOP 1
             @cFromTransitLOC = LOC.LOC
         FROM LOC WITH (NOLOCK)
         WHERE Facility = @cFacility
            AND LOCAisle = @cFromLOCAisle
            AND LocationCategory IN ('PND', 'PND_OUT')
            AND  NOT EXISTS( SELECT 1
                             FROM LOC L2 WITH (NOLOCK)
                             JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = L2.LOC
                                    AND (LLI.LOC = L2.LOC AND (LLI.QTY > 0 OR LLI.PendingMoveIN > 0)))
                             WHERE LOC.LOC = L2.LOC
                             AND   L2.Facility = @cFacility
                             AND   L2.LOCAisle = @cFromLOCAisle
                             AND LocationCategory IN ('PND', 'PND_OUT')
                             GROUP BY L2.LOC, L2.MaxPallet
                             HAVING COUNT(DISTINCT LLI.ID) >= L2.MaxPallet )
         ORDER BY LOC.LogicalLocation, LOC.LOC


         IF @cFromTransitLOC = ''
         BEGIN
            SET @nErrNo = 74201
            SET @cErrMsg = '74201 No PDN LOC'
            GOTO Fail
         END
      END

      -- Find any PND location. Don't need to be empty
      IF @nLockLOC <> 1 --No
      BEGIN
         -- Get a PND LOC
         SELECT TOP 1
             @cFromTransitLOC = LOC.LOC
         FROM LOC WITH (NOLOCK)
            LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE Facility = @cFacility
            -- AND PutawayZone = @cFromPAZone
            AND LOCAisle = @cFromLOCAisle
            AND LocationCategory IN ('PND', 'PND_OUT')
         GROUP BY LOC.LogicalLocation, LOC.LOC
         ORDER BY LOC.LogicalLocation, LOC.LOC

         IF @cFromTransitLOC = ''
         BEGIN
            SET @nErrNo = 74202
            SET @cErrMsg = '74202 No PDN LOC'
            GOTO Fail
         END
      END
      --GOTO ToLOC
      GOTO Quit
   END

   -- 2. PutawayZone level
   IF @cFromTransitLOC = '' AND @cFromPAOutLOC <> ''
      SET @cFromTransitLOC = @cFromPAOutLOC

   -- 3. Storer config level
   IF @cFromTransitLOC = '' AND @cGITLOC <> ''
      SET @cFromTransitLOC = @cGITLOC

   -- If found, exit
   IF @cFromTransitLOC <> ''
      GOTO Quit

   /*-------------------------------------------------------------------------------

                                       ToLOC section

   -------------------------------------------------------------------------------*/
   ToLOC:
   -- Check if ToLOC already a PND LOC / zone in LOC / GITLOC
   IF @cToLOCCat = 'PND' OR
      @cToLOC = @cToPAInLOC OR
      @cToLOC = @cGITLOC
      GOTO Quit

   -- 1. VNA level
   IF @cToLOCInVNA = 1 --Yes
   BEGIN
      -- FromLOC is ToLOC's in transit LOC
      IF @cFromLOCCat = 'PND' AND
         @cFromLOCAisle = @cToLOCAisle
         GOTO Quit

      -- Find an empty PND location for execute task
      IF @nLockLOC = 1 --Yes
      BEGIN
         -- Get an empty PND LOC
--         SELECT TOP 1
--             @cToTransitLOC = LOC.LOC
--         FROM LOC WITH (NOLOCK)
--            LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC AND (LLI.QTY > 0 OR LLI.PendingMoveIN > 0))
--         WHERE Facility = @cFacility
--            -- AND PutawayZone = @cToPAZone
--            AND LOCAisle = @cToLOCAisle
--            AND LocationCategory IN ('PND', 'PND_IN')
--         GROUP BY LOC.LogicalLocation, LOC.LOC, LOC.MaxPallet
--         HAVING COUNT( DISTINCT LLI.ID) < LOC.MaxPallet
--         ORDER BY LOC.LogicalLocation, LOC.LOC

         SELECT TOP 1
             @cToTransitLOC = LOC.LOC
         FROM LOC WITH (NOLOCK)
         WHERE Facility = @cFacility
            AND LOCAisle = @cToLOCAisle
            AND LocationCategory IN ('PND', 'PND_IN')
            AND  NOT EXISTS( SELECT 1
                             FROM LOC L2 WITH (NOLOCK)
                             JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = L2.LOC
                                 AND (LLI.LOC = L2.LOC AND (LLI.QTY > 0 OR LLI.PendingMoveIN > 0)))
                             WHERE LOC.LOC = L2.LOC
                             AND   L2.Facility = @cFacility
                             AND   L2.LOCAisle = @cToLOCAisle
                             AND LocationCategory IN ('PND', 'PND_IN')
                             GROUP BY L2.LOC, L2.MaxPallet
                             HAVING COUNT(DISTINCT LLI.ID) >= L2.MaxPallet )
         ORDER BY LOC.LogicalLocation, LOC.LOC


         IF @cToTransitLOC = ''
         BEGIN
            SET @nErrNo = 74203
            SET @cErrMsg = '74203 No PDN LOC'
            GOTO Fail
         END
      END

      -- Find any PND location. Don't need to be empty
      IF @nLockLOC <> 1 --No
      BEGIN
         -- Get a PND LOC
         SELECT TOP 1
             @cToTransitLOC = LOC.LOC
         FROM LOC WITH (NOLOCK)
            LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE Facility = @cFacility
            -- AND PutawayZone = @cToPAZone
            AND LOCAisle = @cToLOCAisle
            AND LocationCategory IN ('PND', 'PND_IN')
         GROUP BY LOC.LogicalLocation, LOC.LOC
         ORDER BY LOC.LogicalLocation, LOC.LOC

         IF @cToTransitLOC = ''
         BEGIN
            SET @nErrNo = 74204
            SET @cErrMsg = '74204 No PDN LOC'
            GOTO Fail
         END
      END

      GOTO Quit
   END

   -- FromLOC is ToLOC's in transit LOC
   IF @cFromLOC IN (@cToPAInLOC, @cGITLOC)
      GOTO Quit

   -- 2. PutawayZone level
   IF @cToTransitLOC = '' AND @cToPAInLOC <> ''
      SET @cToTransitLOC = @cToPAInLOC

   -- 3. Storer config level
   IF @cToTransitLOC = '' AND @cGITLOC <> ''
      SET @cToTransitLOC = @cGITLOC

   Quit:
   -- Decide transit LOC
   IF @cFromTransitLOC <> ''
      SET @cTransitLOC = ISNULL(RTRIM(@cFromTransitLOC),'') -- SOS# 316284
   ELSE
      IF @cToTransitLOC <> ''
         SET @cTransitLOC = ISNULL(RTRIM(@cToTransitLOC),'') -- SOS# 316284
      ELSE
         SET @cTransitLOC = ISNULL(RTRIM(@cToLOC),'') -- SOS# 316284

   -- Lock PND LOC
   IF @nLockLOC = 1 AND (SELECT LocationCategory FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cTransitLOC) IN ('PND', 'PND_IN', 'PND_OUT')
   BEGIN
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
         ,@cFromLOC
         ,@cFromID
         ,@cTransitLOC
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cSKU        = @cSKU
         ,@nPutawayQTY = @nQTY
         ,@nFunc       = @nFunc

      IF @nErrNo <> 0
         GOTO Fail
/*
      SET @b_success = 1
      EXEC dbo.nspPendingMoveInUpdate
          @c_storerkey = @cStorerKey
         ,@c_sku       = ''
         ,@c_lot       = ''
         ,@c_Loc       = @cToTransitLOC
         ,@c_ID        = ''
         ,@c_FromLOC   = @cFromLOC
         ,@c_fromid    = @cFromID
         ,@n_qty       = 0
         ,@c_action    = ''
         ,@b_Success   = @b_success OUTPUT
         ,@n_Err       = @nErrNo    OUTPUT
         ,@c_ErrMsg    = @cErrMsg   OUTPUT
         ,@c_tasktype  = 'RP'
      IF @b_success = 0
         GOTO Fail
*/
   END

-- select @cFromTransitLOC '@cFromTransitLOC', @cToTransitLOC '@cToTransitLOC', @cToLOC '@cToLOC'

Fail:

END

GO