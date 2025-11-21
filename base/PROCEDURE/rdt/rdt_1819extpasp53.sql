SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP53                                   */
/* Created by : Maersk                                                  */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev      Author   Purposes                               */
/* 2024-9-4    1.0.0    LJQ006   FCR-747 Created                        */
/* 2024-10-30  1.0.1    LJQ006   run strategy key in codelkup instead   */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1819ExtPASP53] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 18),
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cFromLOC         NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cSuggLOC         NVARCHAR( 10)  OUTPUT,
   @cPickAndDropLOC  NVARCHAR( 10)  OUTPUT,
   @cFitCasesInAisle NVARCHAR( 1)   OUTPUT,
   @nPABookingKey    INT            OUTPUT, 
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nTranCount       INT

   DECLARE 
      @cSKU             NVARCHAR(20),
      @cStyle           NVARCHAR(20),
      @cColor           NVARCHAR(10),
      @nRowCount        INT
   
   DECLARE @cPAStrategyKey    NVARCHAR(10)  
   DECLARE @cParam1           NVARCHAR( 20)
   DECLARE @cParam2           NVARCHAR( 20)
   DECLARE @cParam3           NVARCHAR( 20)
   DECLARE @cParam4           NVARCHAR( 20)
   DECLARE @cParam5           NVARCHAR( 20)
      
   -- Get putaway strategy  
   SET @cPAStrategyKey = ''  
   SELECT @cPAStrategyKey = Short   
   FROM dbo.CodeLKUP WITH (NOLOCK)  
   WHERE ListName = 'RDTExtPA'  
      AND StorerKey = @cStorerKey  
      AND Code2 = @cFacility  
      AND Code = @nFunc
   
   SET @cSuggLOC = ''
   SET @cPickAndDropLOC = ''
   
   -- Lock suggested location
   IF @cSuggLOC = '' 
   BEGIN    
      -- Find the SKU from PalletID and FromLoc
      SELECT TOP 1
         @cSKU = lli.SKU,
         @cStyle = sku.Style,
         @cColor = sku.Color
      FROM dbo.LOTxLOCxID lli WITH(NOLOCK)
      INNER JOIN dbo.SKU sku WITH(NOLOCK)
         ON lli.SKU = sku.SKU
      WHERE ID = @cID 
         AND LOC = @cFromLOC
         AND lli.StorerKey = @cStorerKey

      DECLARE @tmpCom TABLE(
         cTempAisle NVARCHAR(10),
         cTempBay NVARCHAR(10),
         cTempPutawayZone NVARCHAR(10)
      )  
      DECLARE @tmpLoc TABLE(
         cTempLoc NVARCHAR(10)
      ) 

      IF @cSKU <>  ''
      BEGIN
         INSERT INTO @tmpLoc SELECT 
            loc.Loc
            FROM dbo.LOC loc WITH (NOLOCK)
               INNER JOIN dbo.LOTxLOCxID lli WITH (NOLOCK)
               ON lli.Loc = loc.Loc
            WHERE 
               lli.Sku = @cSKU
               AND loc.Facility = @cFacility
               AND lli.StorerKey = @cStorerKey
               AND (lli.Qty - lli.QtyPicked > 0 OR lli.PendingMoveIN > 0)
               AND loc.LocationRoom like 'RACK%'
         INSERT INTO @tmpCom SELECT DISTINCT
            loc.LocAisle,
            loc.LocBay,
            loc.PutawayZone
            FROM dbo.LOC loc WITH(NOLOCK)
            WHERE EXISTS (SELECT 1 FROM @tmpLoc tl WHERE tl.cTempLoc = loc.Loc)
            AND loc.Facility = @cFacility
            AND loc.LocAisle <> ''
            AND loc.LocBay <> ''
            AND loc.PutawayZone <> ''
         
         SET @nRowCount = @@ROWCOUNT
         IF @nRowCount > 0
         BEGIN
            SELECT TOP 1
               @cSuggLOC = loc.Loc
            FROM dbo.LOC loc WITH(NOLOCK)
               LEFT JOIN dbo.LOTxLOCxID lli WITH(NOLOCK)
               ON lli.Loc = loc.Loc
               INNER JOIN @tmpCom tmp
               ON tmp.cTempAisle = loc.LocAisle
                  AND tmp.cTempBay = loc.LocBay
                  AND tmp.cTempPutawayZone = loc.PutawayZone
            WHERE loc.Facility = @cFacility
               AND (lli.loc IS NULL OR ( lli.Qty - lli.QtyPicked = 0 AND lli.PendingMoveIN = 0))
               -- AND (lli.loc IS NULL OR ( lli.Qty - lli.QtyPicked = 0 ))
               AND (lli.StorerKey = @cStorerKey OR ISNULL(lli.StorerKey, '') = '')
               AND loc.LocationFlag = 'NONE'
               AND loc.LocationRoom like 'RACK%'
               AND NOT EXISTS (SELECT 1 FROM @tmpLoc tl WHERE tl.cTempLoc = loc.Loc)
               AND NOT EXISTS (SELECT 1 FROM dbo.LOTxLOCxID lli2 WITH(NOLOCK)
               WHERE lli2.Loc = loc.Loc
               AND (lli2.Qty - lli2.QtyPicked <> 0 OR lli2.PendingMoveIN <> 0))
               -- AND (lli2.Qty - lli2.QtyPicked <> 0))
               ORDER BY loc.LocAisle, loc.LocBay, loc.LocLevel, loc.Loc

         END
      END

      DELETE FROM @tmpLoc
      DELETE FROM @tmpCom

      IF @cSuggLOC = ''
      BEGIN

         -- Get all locations contains different SKU but same color and style
         INSERT INTO @tmpLoc SELECT 
         loc.Loc
         FROM dbo.LOC loc WITH (NOLOCK)
            INNER JOIN dbo.LOTxLOCxID lli WITH (NOLOCK)
            ON lli.Loc = loc.Loc
            INNER JOIN dbo.SKU sku WITH (NOLOCK)
            ON lli.SKU = sku.SKU
         WHERE lli.Sku <> @cSKU
            AND sku.Style = @cStyle
            AND sku.Color = @cColor
            AND loc.Facility = @cFacility
            AND lli.StorerKey = @cStorerKey
            AND (lli.Qty - lli.QtyPicked > 0 OR lli.PendingMoveIN > 0)
            AND loc.LocationRoom like 'RACK%'
      
         INSERT INTO @tmpCom SELECT DISTINCT
            loc.LocAisle,
            loc.LocBay,
            loc.PutawayZone
            FROM dbo.LOC loc WITH(NOLOCK)
            WHERE EXISTS (SELECT 1 FROM @tmpLoc tl WHERE tl.cTempLoc = loc.Loc)
            AND loc.Facility = @cFacility
            AND loc.LocAisle <> ''
            AND loc.LocBay <> ''
            AND loc.PutawayZone <> ''
            
         -- get an empty location near the location contains similar SKU
         SET @nRowCount = @@ROWCOUNT
         IF @nRowCount > 0
         BEGIN
            SELECT TOP 1
               @cSuggLOC = loc.Loc
            FROM dbo.LOC loc WITH(NOLOCK)
               LEFT JOIN dbo.LOTxLOCxID lli WITH(NOLOCK)
               ON lli.Loc = loc.Loc
               INNER JOIN @tmpCom tmp
               ON tmp.cTempAisle = loc.LocAisle
                  AND tmp.cTempBay = loc.LocBay
                  AND tmp.cTempPutawayZone = loc.PutawayZone
            WHERE loc.Facility = @cFacility
               AND (lli.loc IS NULL OR ( lli.Qty - lli.QtyPicked = 0 AND lli.PendingMoveIN = 0))
               -- AND (lli.loc IS NULL OR ( lli.Qty - lli.QtyPicked = 0 ))
               AND (lli.StorerKey = @cStorerKey OR ISNULL(lli.StorerKey, '') = '')
               AND loc.LocationFlag = 'NONE'
               AND loc.LocationRoom like 'RACK%'
               AND NOT EXISTS (SELECT 1 FROM @tmpLoc tl WHERE tl.cTempLoc = loc.Loc)
               AND NOT EXISTS (SELECT 1 FROM dbo.LOTxLOCxID lli2 WITH(NOLOCK)
                  WHERE lli2.Loc = loc.Loc
                  AND (lli2.Qty - lli2.QtyPicked <> 0 OR lli2.PendingMoveIN <> 0))
                  -- AND (lli2.Qty - lli2.QtyPicked <> 0))
               ORDER BY loc.LocAisle, loc.LocBay, loc.LocLevel, loc.Loc
         END

      END

      -- Exec patype 19
      IF @cSuggLOC = ''
      BEGIN
         -- Suggest LOC
         EXEC @nErrNo = [dbo].[nspRDTPASTD]
             @c_userid          = 'RDT'
            ,@c_storerkey       = @cStorerKey
            ,@c_lot             = ''
            ,@c_sku             = ''
            ,@c_id              = @cID
            ,@c_fromloc         = @cFromLOC
            ,@n_qty             = 0
            ,@c_uom             = '' -- not used
            ,@c_packkey         = '' -- optional, if pass-in SKU
            ,@n_putawaycapacity = 0
            ,@c_final_toloc     = @cSuggLOC          OUTPUT
            ,@c_PickAndDropLoc  = @cPickAndDropLOC   OUTPUT
            ,@c_FitCasesInAisle = @cFitCasesInAisle  OUTPUT
            , @c_Param1          = @cParam1
            , @c_Param2          = @cParam2
            , @c_Param3          = @cParam3
            , @c_Param4          = @cParam4
            , @c_Param5          = @cParam5
            , @c_PAStrategyKey   = @cPAStrategyKey  
      END

         -- Check suggest loc
      IF @cSuggLOC = ''
      BEGIN
         SET @nErrNo = -1
         GOTO Quit
      END

      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_1819ExtPASP53 -- For rollback or commit only our own transaction

      SET @nPABookingKey = 0
      IF @cFitCasesInAisle <> 'Y'
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
            ,@cFromLOC
            ,@cID
            ,@cSuggLOC
            ,@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@nPABookingKey = @nPABookingKey OUTPUT

         IF @nErrNo <> 0
            GOTO RollBackTran
      END

      COMMIT TRAN rdt_1819ExtPASP53 -- Only commit change made here
   END

   GOTO CommitTran

RollBackTran:
   ROLLBACK TRAN rdt_1819ExtPASP53 -- Only rollback change made here

CommitTran:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
   
   GOTO Quit
END
Quit:

GO