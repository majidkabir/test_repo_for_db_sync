SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtVFNMVFGetSuggLOC                                       */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev   Author   Purposes                                        */
/* 07-05-2014  1.0   Ung      SOS309834. Created                              */
/* 08-10-2014  1.1   Ung      Fix search stop when 1st aisle of all zones full*/
/******************************************************************************/

CREATE PROC [RDT].[rdtVFNMVFGetSuggLOC] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 18), 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cTaskDetailKey   NVARCHAR( 10), 
   @cFromLOC         NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cSuggestedLOC    NVARCHAR( 10) OUTPUT,
   @cPickAndDropLOC  NVARCHAR( 10) OUTPUT,
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT, 
   @nDebug           INT = 0
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nTranCount    INT
   DECLARE @nRowCount     INT

   DECLARE @cType         NVARCHAR( 10)
   DECLARE @cSuggToLOC    NVARCHAR( 10)
   DECLARE @cLastPndAisle NVARCHAR( 10)
   DECLARE @cLastPnDZone  NVARCHAR( 10)
   DECLARE @cNextPnDLOC   NVARCHAR( 10)
   DECLARE @cNextPnDAisle NVARCHAR( 10)
   DECLARE @cNextPnDZone  NVARCHAR( 10)
   DECLARE @tAisle TABLE 
   (
      LOCAisle    NVARCHAR(10),
      PutawayZone NVARCHAR(10), 
      Closed      NVARCHAR(1)
   )
   
   SET @cType         = ''
   SET @cSuggToLOC    = ''
   SET @cLastPndAisle = ''
   SET @cLastPnDZone  = ''
   SET @cNextPnDLOC   = ''
   SET @cNextPnDAisle = ''
   SET @cNextPnDZone  = ''
   
   -- Get DropID info
   SELECT @cType = DropIDType FROM DropID WITH (NOLOCK) WHERE DropID = @cID   
   
   -- Get candidate LOC aisle
   INSERT INTO @tAisle
   SELECT DISTINCT LOC.LOCAisle, LOC.PutawayZone, 'N'
   FROM CodeLKUP WITH (NOLOCK) 
      JOIN LOC WITH (NOLOCK) ON (LOC.PutawayZone = CodeLkup.Code)
   WHERE ListName = 'NMVPAZones' 
      AND StorerKey = @cStorerKey
      -- AND ISNULL( Short, '') = @cType -- For not mixing normal and XD pallet in same Zone

   IF @nDebug = 1
      SELECT * FROM @tAisle ORDER BY LOCAisle

   -- Get last PND aisle used from TaskDetail
   SELECT TOP 1
       @cLastPndAisle = LOC.LOCAisle
      ,@cLastPnDZone = LOC.PutawayZone
   FROM TaskDetail TD WITH (NOLOCK)
      JOIN LOC LOC WITH (NOLOCK) ON (LOC.LOC = TD.ToLOC AND LOC.LocationCategory IN ('PnD_In', 'PnD'))
      JOIN @tAisle T ON (T.LOCAisle = LOC.LOCAisle AND T.Closed = 'N')
   WHERE LOC.Facility = @cFacility
      AND TD.TaskType = 'NMF'
      AND TD.Status = '9'
   ORDER BY TD.EditDate DESC

   IF @nDebug = 1
      SELECT 'After search last PND', @cLastPndAisle '@cLastPndAisle', @cLastPnDZone '@cLastPnDZone'

   -- Set search after last aisle
   IF @cLastPndAisle <> ''
   BEGIN
      SET @cNextPnDAisle = @cLastPndAisle
      SET @cNextPnDZone = @cLastPnDZone
   END

   -- Loop aisle to get PnD
   WHILE (1=1)
   BEGIN
      IF @nDebug = 1
         SELECT 'Before search next PND (in next zone, aisle)', @cNextPnDLOC '@cNextPnDLOC', @cNextPnDAisle '@cNextPnDAisle', @cNextPnDZone '@cNextPnDZone', @nRowCount '@nRowCount'
      
      -- Search next zone, aisle
      SELECT TOP 1
          @cNextPnDLOC = LOC.LOC
         ,@cNextPnDAisle = LOC.LocAisle
         ,@cNextPnDZone = LOC.PutawayZone
      FROM LOC WITH (NOLOCK)  
         JOIN @tAisle T ON (T.LOCAisle = LOC.LOCAisle AND T.Closed = 'N')
      WHERE LOC.LocationCategory IN ('PnD_In', 'PnD')
         AND LOC.Facility = @cFacility
         AND LOC.PutawayZone <> @cNextPnDZone 
         AND LOC.LOCAisle > @cNextPnDAisle
         AND (LOC.MaxPallet = 0
         OR 
         (
            (SELECT COUNT( 1) FROM DropID WITH (NOLOCK) WHERE DropID.DropLOC = LOC.LOC AND DropLOC <> '' AND DropID.Status < '9') + 
            (SELECT COUNT( 1) FROM RFPutawayNMV NMV WITH (NOLOCK) WHERE NMV.SuggestedLOC = LOC.LOC) 
         ) < LOC.MaxPallet)
      ORDER BY
          LOC.LOCAisle
         ,LOC.LogicalLocation
         ,LOC.LOC

      SET @nRowCount = @@ROWCOUNT
      IF @nDebug = 1
         SELECT 'After search next PND (in next zone, aisle)', @cNextPnDLOC '@cNextPnDLOC', @cNextPnDAisle '@cNextPnDAisle', @cNextPnDZone '@cNextPnDZone', @nRowCount '@nRowCount'
            
      -- If not found, find all aisle
      IF @nRowCount = 0
      BEGIN
         -- Searc all aisle
         SELECT TOP 1
             @cNextPnDLOC = LOC.LOC
            ,@cNextPnDAisle = LOC.LocAisle
            ,@cNextPnDZone = LOC.PutawayZone
         FROM LOC WITH (NOLOCK)  
            JOIN @tAisle T ON (T.LOCAisle = LOC.LOCAisle AND T.Closed = 'N')
         WHERE LOC.LocationCategory IN ('PnD_In', 'PnD')
            AND LOC.Facility = @cFacility
            AND (LOC.MaxPallet = 0
            OR 
            (
               (SELECT COUNT( 1) FROM DropID WITH (NOLOCK) WHERE DropID.DropLOC = LOC.LOC AND DropLOC <> '' AND DropID.Status < '9') + 
               (SELECT COUNT( 1) FROM RFPutawayNMV NMV WITH (NOLOCK) WHERE NMV.SuggestedLOC = LOC.LOC) 
            ) < LOC.MaxPallet)
         ORDER BY
             LOC.LOCAisle
            ,LOC.LogicalLocation
            ,LOC.LOC
            
         SET @nRowCount = @@ROWCOUNT
         IF @nDebug = 1
            SELECT 'After search all PND (in all zone, aisle)', @cNextPnDLOC '@cNextPnDLOC', @cNextPnDAisle '@cNextPnDAisle', @cNextPnDZone '@cNextPnDZone', @nRowCount '@nRowCount'

         IF @nRowCount = 0
            BREAK
      END

      -- Find empty LOC
      IF @cSuggToLOC = ''
      BEGIN
         SELECT TOP 1
            @cSuggToLOC = LOC.LOC
         FROM dbo.LOC WITH (NOLOCK)
            LEFT OUTER JOIN dbo.DropID WITH (NOLOCK) ON (DropID.DropLOC = LOC.LOC AND DropLOC <> '' AND DropID.Status < '9')
            LEFT OUTER JOIN RFPutawayNMV NMV WITH (NOLOCK) ON (NMV.SuggestedLOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
            AND LOC.LocationCategory = 'PACK&HOLD'
            AND LOC.LOCAisle = @cNextPnDAisle
            AND DropID.DropLOC IS NULL
            AND NMV.SuggestedLOC IS NULL
         ORDER BY LOC.LogicalLocation, LOC.LOC
         
         IF @nDebug = 1
            SELECT 'After search final loc (empty loc)', @cNextPnDAisle '@cNextPnDAisle', @cSuggToLOC '@cSuggToLOC', @nRowCount '@nRowCount'
      END

      -- Find LOC not yet reach MaxPallet
      IF @cSuggToLOC = ''
      BEGIN
         SELECT TOP 1 
            @cSuggToLOC = LOC.LOC
         FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC.Facility = @cFacility
            AND LOC.LocationCategory = 'PACK&HOLD'
            AND LOC.LOCAisle = @cNextPnDAisle
            AND (LOC.MaxPallet = 0
            OR 
            (
               (SELECT COUNT( 1) FROM DropID WITH (NOLOCK) WHERE DropID.DropLOC = LOC.LOC AND DropLOC <> '' AND DropID.Status < '9') + 
               (SELECT COUNT( 1) FROM RFPutawayNMV NMV WITH (NOLOCK) WHERE NMV.SuggestedLOC = LOC.LOC) 
            ) < LOC.MaxPallet)
         ORDER BY LOC.LogicalLocation, LOC.LOC

         IF @nDebug = 1
            SELECT 'After search final loc (not reach maxpallet)', @cNextPnDAisle '@cNextPnDAisle', @cSuggToLOC '@cSuggToLOC', @nRowCount '@nRowCount'
      END

      -- Found final LOC
      IF @cSuggToLOC <> ''
         BREAK
         
      -- Close off aisle
      UPDATE @tAisle SET
         Closed = 'Y'
      WHERE LOCAisle = @cNextPnDAisle
      
      -- Check any aisle still open
      IF NOT EXISTS( SELECT TOP 1 1 FROM @tAisle WHERE Closed = 'N')
         BREAK
   END

   -- Check suggest loc
   IF @cSuggToLOC = ''
   BEGIN
      SET @nErrNo = 80201
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoSuitableLOC
      GOTO Quit
   END

   -- Lock suggested location
   IF @cSuggToLOC <> '' 
   BEGIN
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtVFNMVFGetSuggLOC -- For rollback or commit only our own transaction
               
      EXEC rdt.rdt_NMV_PendingMoveIn @nMobile, @nFunc, @cLangCode, @cUserName, 'LOCK'
         ,@cTaskDetailKey
         ,@cFromLOC
         ,@cID
         ,@cSuggToLOC
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran

      -- Lock PND location
      IF @cNextPnDLOC <> ''
      BEGIN
         EXEC rdt.rdt_NMV_PendingMoveIn @nMobile, @nFunc, @cLangCode, @cUserName, 'LOCK'
            ,@cTaskDetailKey
            ,@cFromLOC
            ,@cID
            ,@cNextPnDLOC
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran

      END

      -- Output result
      IF @cSuggToLOC <> ''
         SET @cSuggestedLOC = @cSuggToLOC
      IF @cNextPnDLOC <> '' 
         SET @cPickAndDropLOC = @cNextPnDLOC

      COMMIT TRAN rdtVFNMVFGetSuggLOC -- Only commit change made here
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdtVFNMVFGetSuggLOC -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

END

GO