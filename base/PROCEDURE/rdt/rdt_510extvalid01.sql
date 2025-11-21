SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_510ExtValid01                                   */  
/* Purpose: Validate ToLoc (if user toloc <> suggested toloc)           */  
/*                                                                      */
/* Called from: rdtfnc_Replenish                                        */
/*                                                                      */
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2020-10-27 1.0  James      WMS-15537. Created                        */ 
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_510ExtValid01] (  
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nAfterStep      INT, 
   @nInputKey       INT,
   @cFacility       NVARCHAR( 5), 
   @cStorerKey      NVARCHAR( 15),
   @cReplenBySKUQTY NVARCHAR( 1),
   @cMoveQTYAlloc   NVARCHAR( 1),
   @cReplenKey      NVARCHAR( 10),
   @cFromLOC        NVARCHAR( 10),
   @cFromID         NVARCHAR( 18),
   @cSKU            NVARCHAR( 20),
   @nQTY            INT,
   @cToLOC          NVARCHAR( 10),
   @cToID           NVARCHAR( 18),
   @cLottable01     NVARCHAR( 18),
   @cLottable02     NVARCHAR( 18),
   @cLottable03     NVARCHAR( 18),
   @dLottable04     DATETIME,    
   @cActToLOC       NVARCHAR( 10),
   @cOption         NVARCHAR( 1),
   @tExtValidVar    VariableTable READONLY,
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
)  
AS  
  
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF   
   
   DECLARE @cTempSKU       NVARCHAR( 20)
   DECLARE @cLocationType  NVARCHAR( 10)
   DECLARE @cLocationFlag  NVARCHAR( 10)
   DECLARE @cCommingleSku  NVARCHAR( 1)
   
   IF @nStep = 5
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF @cOption = '1'
         BEGIN
            SELECT 
               @cLocationType = LocationType,
               @cLocationFlag = LocationFlag,
               @cCommingleSku = CommingleSku
            FROM dbo.LOC WITH (NOLOCK)
            WHERE LOC = @cActToLOC
            AND   Facility = @cFacility
                        
            IF @cLocationType = 'CASE' AND @cLocationFlag = 'NONE'
            BEGIN
               -- If Loc not allow mix sku
               IF @cCommingleSku = '0'
               BEGIN
                  -- Check only if loc is not empty
                  SELECT TOP 1 @cTempSKU = LLI.Sku
                  FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                  JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
                  WHERE LOC.Loc = @cActToLOC
                  AND   LOC.Facility = @cFacility
                  AND   LLI.QTY-LLI.QTYPicked > 0
                  ORDER BY 1
                  
                  IF @@ROWCOUNT > 0
                  BEGIN
                     IF @cSKU <> @cTempSKU
                     BEGIN  
                        SET @nErrNo = 160201  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Cannot Mix Sku
                        GOTO Quit    
                     END
                  END
               END
            END
            ELSE
            BEGIN  
               SET @nErrNo = 160202  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid To Loc  
               GOTO Quit    
            END
         END
      END
   END
   Quit:
    

GO