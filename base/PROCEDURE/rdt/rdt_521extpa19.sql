SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_521ExtPA19                                      */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Customized PA logic for Puma                                */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 04-Sept-2024 1.0  LJQ006   FCR-747 Created                           */
/* 11-Oct-2024  1.1.0  LJQ006   Use LocLevel and CubicCapacity          */
/*                              instead of LocationGroup                */
/* 30-Oct-2024  1.1.1  LJQ006   run strategy key in codelkup instead    */
/************************************************************************/

CREATE   PROC [RDT].[rdt_521ExtPA19] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 18),
   @cStorerKey       NVARCHAR( 15),
   @cFacility        NVARCHAR( 5),
   @cLOC             NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cLOT             NVARCHAR( 10),
   @cUCC             NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQty             INT,
   @cSuggestedLOC    NVARCHAR( 10) OUTPUT,
   @cPickAndDropLoc  NVARCHAR( 10) OUTPUT,
   @nPABookingKey    INT           OUTPUT,
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @nTranCount     INT,
            @bDebugFlag     BIT = 0,
            @cStyle         NVARCHAR(20),
            @cColor         NVARCHAR(10),
            @nRowCount      INT,
            @nSkuCube       FLOAT

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

   SET @cSuggestedLOC = ''
   SET @cPickAndDropLoc = ''

   IF ISNULL(@cSuggestedLOC,'') = ''
   BEGIN
      -- Declare table variables for the range data of the location contains sku
      DECLARE @tmpCom TABLE (
         cTempAisle NVARCHAR(10),
         cTempBay NVARCHAR(10),
         cTempLocationLevel NVARCHAR(30),
         cTempPutawayZone NVARCHAR(10)
      )

      DECLARE @tmpLoc TABLE(
         cTempLoc NVARCHAR(10)
      )

      -- get sku by UCC
      SELECT TOP 1
         @cSKU = ucc.SKU
      FROM dbo.UCC ucc WITH(NOLOCK)
      INNER JOIN dbo.SKU sku ON sku.SKU = ucc.SKU
      WHERE ucc.UCCNo = @cUCC
       AND sku.StorerKey = @cStorerKey
       AND ucc.StorerKey = @cStorerKey

      -- Get the style, color and cube of the sku
      SELECT TOP 1
         @cStyle = sku.Style,
         @cColor = sku.Color,
         @nSkuCube = sku.Cube
      FROM dbo.SKU sku WITH(NOLOCK)
      WHERE sku.SKU = @cSKU
         AND StorerKey = @cStorerKey;

      -- get the location contains same sku and still have space
      WITH LocSummary AS
      (
         SELECT 
            loc.Loc, 
            SUM((lli.Qty - lli.QtyPicked + lli.PendingMoveIN) * sku.Cube) AS OccupiedCube,
            -- SUM((lli.Qty - lli.QtyPicked) * sku.Cube) AS OccupiedCube,
            MAX(loc.CubicCapacity) AS Cube,
            MAX(loc.LocLevel) AS LocLevel,
            MAX(loc.LocBay) AS LocBay,
            MAX(loc.LocAisle) AS LocAisle
         FROM dbo.Loc loc 
         INNER JOIN dbo.LOTxLOCxID lli WITH(NOLOCK) ON loc.Loc = lli.Loc 
         INNER JOIN dbo.Sku sku WITH(NOLOCK) ON sku.Sku = lli.Sku
            WHERE loc.Facility = @cFacility
            AND lli.StorerKey = @cStorerKey
            AND sku.Style = @cStyle
            AND sku.Color = @cColor
            AND sku.StorerKey = @cStorerKey
            AND loc.LocationRoom like 'MEZZ%'
            AND loc.LocationFlag <> 'INACTIVE'
            AND loc.CommingleSku = 1
         GROUP BY loc.Loc
      )
      SELECT TOP 1
         ls.loc
      FROM LocSummary ls
         WHERE ls.OccupiedCube + @nQty * @nSkuCube < ls.Cube
         AND ls.OccupiedCube > 0
         AND ls.Loc IN (
            SELECT Loc FROM dbo.LOTxLOCxID WITH (NOLOCK) WHERE StorerKey = @cStorerKey
               AND sku = @cSKU
               AND Qty-QtyPicked > 0
               -- OR lli.PendingMoveIN > 0
            )
         ORDER BY ls.LocAisle, ls.LocBay, ls.LocLevel, ls.Loc
      
      IF @cSuggestedLOC = ''
      BEGIN
         INSERT INTO @tmpLoc SELECT 
            loc.Loc
            FROM dbo.LOC loc WITH (NOLOCK)
               INNER JOIN dbo.LOTxLOCxID lli WITH (NOLOCK)
               ON lli.Loc = loc.Loc
            WHERE loc.LocationRoom like 'MEZZ%'
               AND loc.Facility = @cFacility
               AND (lli.Qty - lli.QtyPicked > 0 OR lli.PendingMoveIN > 0)
               AND lli.Sku = @cSKU

         INSERT INTO @tmpCom SELECT DISTINCT
            loc.LocAisle,
            loc.LocBay,
            loc.LocLevel,
            loc.PutawayZone
            FROM dbo.LOC loc WITH(NOLOCK)
            WHERE EXISTS (SELECT 1 FROM @tmpLoc tl WHERE tl.cTempLoc = loc.Loc)
            AND loc.LocAisle <> ''
            AND loc.LocBay <> ''
            AND loc.LocLevel <> ''
            AND loc.PutawayZone <> ''         

         SET  @nRowCount = @@ROWCOUNT

         -- Get empty location near the full location already has the same sku
         IF @nRowCount > 0
         BEGIN
            SELECT TOP 1
               @cSuggestedLOC = loc.Loc
            FROM dbo.LOC loc WITH(NOLOCK)
               LEFT JOIN dbo.LOTxLOCxID lli WITH(NOLOCK)
               ON lli.Loc = loc.Loc
            WHERE loc.Facility = @cFacility
               AND (lli.StorerKey = @cStorerKey OR ISNULL(lli.StorerKey, '') = '')
               AND (lli.loc IS NULL OR ( lli.Qty - lli.QtyPicked = 0 AND lli.PendingMoveIN = 0))
               -- AND (lli.loc IS NULL OR ( lli.Qty - lli.QtyPicked = 0 ))
               AND NOT EXISTS (SELECT 1 FROM @tmpLoc tl WHERE tl.cTempLoc = loc.Loc)
               AND loc.CubicCapacity > (@nSkuCube * @nQty)
               AND loc.LocationFlag <> 'INACTIVE'
               AND loc.LocationRoom like 'MEZZ%'
               AND NOT EXISTS (SELECT 1 FROM dbo.LOTxLOCxID lli2 WITH(NOLOCK)
                  WHERE lli2.Loc = loc.Loc
                  AND lli2.StorerKey = @cStorerKey
                  AND (lli2.Qty - lli2.QtyPicked <> 0 OR lli2.PendingMoveIN <> 0))
               AND EXISTS (
                  SELECT 1 FROM @tmpCom tmp
                     WHERE tmp.cTempAisle = loc.LocAisle
                        AND tmp.cTempBay = loc.LocBay 
                        AND tmp.cTempLocationLevel = loc.LocLevel 
                        AND tmp.cTempPutawayZone = loc.PutawayZone   
               )
              ORDER BY loc.LocAisle, loc.LocBay,loc.LocLevel, loc.Loc
         END
      END

      IF @cSuggestedLOC = ''
      BEGIN
         -- get the location contains different sku but same color and style and still have space
         WITH LocSummary AS 
         (
            SELECT 
               loc.Loc, 
               SUM((lli.Qty - lli.QtyPicked + lli.PendingMoveIN) * sku.Cube) AS OccupiedCube,
               -- SUM((lli.Qty - lli.QtyPicked) * sku.Cube) AS OccupiedCube,
               MAX(loc.CubicCapacity) AS Cube,
               MAX(loc.LocLevel) AS LocLevel,
               MAX(loc.LocBay) AS LocBay,
               MAX(loc.LocAisle) AS LocAisle
            FROM dbo.Loc loc 
            INNER JOIN dbo.LOTxLOCxID lli ON loc.Loc = lli.Loc 
            INNER JOIN dbo.Sku sku ON sku.Sku = lli.Sku
               WHERE loc.Facility = @cFacility
               AND lli.StorerKey = @cStorerKey
               AND sku.Style = @cStyle
               AND sku.Color = @cColor
               AND sku.StorerKey = @cStorerKey
               AND loc.LocationRoom like 'MEZZ%'
               AND loc.LocationFlag <> 'INACTIVE'
               AND loc.CommingleSku = 1
            GROUP BY loc.Loc
         )  
         SELECT TOP 1
            ls.loc
         FROM LocSummary ls
            WHERE ls.OccupiedCube + @nQty * @nSkuCube < ls.Cube
            AND ls.OccupiedCube > 0
            AND ls.Loc IN (
               SELECT Loc FROM dbo.LOTxLOCxID WITH (NOLOCK) WHERE StorerKey = @cStorerKey
                  AND sku = @cSKU
                  AND Qty-QtyPicked > 0
                  -- OR lli.PendingMoveIN > 0
               )
         ORDER BY ls.LocAisle, ls.LocBay, ls.LocLevel, ls.Loc
      END

      IF @cSuggestedLOC = ''
      BEGIN
         DELETE FROM @tmpCom
         DELETE FROM @tmpLoc

         -- get the location contains different sku from current
         INSERT INTO @tmpLoc SELECT 
            loc.Loc
            FROM dbo.LOC loc WITH (NOLOCK)
               INNER JOIN dbo.LOTxLOCxID lli WITH (NOLOCK)
               ON lli.Loc = loc.Loc
               INNER JOIN dbo.Sku sku WITH (NOLOCK)
               ON sku.Sku = lli.Sku
            WHERE loc.LocationRoom like 'MEZZ%'
               AND loc.Facility = @cFacility
               AND (lli.Qty - lli.QtyPicked > 0 OR lli.PendingMoveIN > 0)
               AND lli.Sku <> @cSKU
               AND sku.Style = @cStyle
               AND sku.Color = @cColor
               AND sku.StorerKey = @cStorerKey

         INSERT INTO @tmpCom SELECT DISTINCT
            loc.LocAisle,
            loc.LocBay,
            loc.LocLevel,
            loc.PutawayZone
            FROM dbo.LOC loc WITH(NOLOCK)
            WHERE EXISTS (SELECT 1 FROM @tmpLoc tl WHERE tl.cTempLoc = loc.Loc)
            AND loc.LocAisle <> ''
            AND loc.LocBay <> ''
            AND loc.LocLevel <> ''
            AND loc.PutawayZone <> ''        

         SET  @nRowCount = @@ROWCOUNT
         -- get an empty locations near the location contains different sku in same location group
         IF @nRowCount > 0
         BEGIN
            SELECT TOP 1
               @cSuggestedLOC = loc.Loc
            FROM dbo.LOC loc WITH(NOLOCK)
               LEFT JOIN dbo.LOTxLOCxID lli WITH(NOLOCK)
               ON lli.Loc = loc.Loc
            WHERE loc.Facility = @cFacility
               AND (lli.StorerKey = @cStorerKey OR ISNULL(lli.StorerKey, '') = '')
               AND (lli.loc IS NULL OR ( lli.Qty - lli.QtyPicked = 0 AND lli.PendingMoveIN = 0))
               -- AND (lli.loc IS NULL OR ( lli.Qty - lli.QtyPicked = 0 ))
               AND NOT EXISTS (SELECT 1 FROM @tmpLoc tl WHERE tl.cTempLoc = loc.Loc)
               AND loc.CubicCapacity > (@nSkuCube * @nQty)
               AND loc.LocationFlag <> 'INACTIVE'
               AND loc.LocationRoom like 'MEZZ%'
               AND NOT EXISTS (SELECT 1 FROM dbo.LOTxLOCxID lli2 WITH(NOLOCK)
                  WHERE lli2.Loc = loc.Loc
                  AND lli2.StorerKey = @cStorerKey
                  AND (lli2.Qty - lli2.QtyPicked <> 0 OR lli2.PendingMoveIN <> 0))                
               AND EXISTS (
                  SELECT 1 FROM @tmpCom tmp
                     WHERE tmp.cTempAisle = loc.LocAisle
                        AND tmp.cTempBay = loc.LocBay
                        AND tmp.cTempLocationLevel = loc.LocLevel
                        AND tmp.cTempPutawayZone = loc.PutawayZone   
               )
              ORDER BY loc.LocAisle, loc.LocBay,loc.LocLevel, loc.Loc
         END
      END

      IF @cSuggestedLOC = ''
      BEGIN
         -- Suggest LOC
         EXEC @nErrNo = [dbo].[nspRDTPASTD]    
              @c_userid        = 'RDT'          -- NVARCHAR(10)    
            , @c_storerkey     = @cStorerkey    -- NVARCHAR(15)    
            , @c_lot           = ''             -- NVARCHAR(10)    
            , @c_sku           = @cSKU          -- NVARCHAR(20)    
            , @c_id            = @cID           -- NVARCHAR(18)    
            , @c_fromloc       = @cLOC          -- NVARCHAR(10)    
            , @n_qty           = @nQty          -- int    
            , @c_uom           = ''             -- NVARCHAR(10)    
            , @c_packkey       = ''             -- NVARCHAR(10) -- optional    
            , @n_putawaycapacity = 0    
            , @c_final_toloc     = @cSuggestedLOC     OUTPUT    
            , @c_PickAndDropLoc  = @cPickAndDropLoc   OUTPUT
            , @c_Param1          = @cParam1
            , @c_Param2          = @cParam2
            , @c_Param3          = @cParam3
            , @c_Param4          = @cParam4
            , @c_Param5          = @cParam5
            , @c_PAStrategyKey   = @cPAStrategyKey
      END

      IF @cSuggestedLOC = ''
      BEGIN
         SET @nErrNo = -1
         GOTO Quit
      END
      
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      
      -- Lock suggested location
      IF @cSuggestedLOC <> '' 
      BEGIN
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdt_521ExtPA19 -- For rollback or commit only our own transaction
         
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
            ,@cLOC
            ,@cID
            ,@cSuggestedLOC
            ,@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@cSKU          = @cSKU
            ,@nPutawayQTY   = @nQTY
            ,@cFromLOT      = @cLOT
            ,@cUCCNo        = @cUCC
            ,@nPABookingKey = @nPABookingKey OUTPUT
         
         IF @nErrNo <> 0
            GOTO RollBackTran

         COMMIT TRAN rdt_521ExtPA19 -- Only commit change made here
      END
   END -- END suggestLoc=''
   
   GOTO CommitTran

   RollBackTran:
      ROLLBACK TRAN rdt_521ExtPA19 -- Only rollback change made here

   CommitTran:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

         -- No loc found finally
      IF ISNULL(@cSuggestedLOC,'') = '' 
         SET @nErrNo = -1 -- No suggested LOC, and allow continue.

END --END SP
Quit:

GO