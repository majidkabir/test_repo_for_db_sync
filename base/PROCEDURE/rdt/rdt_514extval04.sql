SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_514ExtVal04                                     */  
/* Purpose: Validate UCC                                                */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2018-01-29 1.0  Ung        WMS-3897 Created                          */  
/* 2019-03-26 1.1  James      WMS-8352 Add From ID (james01)            */  
/* 2023-01-20 1.2  Ung        WMS-21577 Add unlimited UCC to move       */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_514ExtVal04] (  
   @nMobile        INT, 
   @nFunc          INT, 
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT, 
   @nInputKey      INT, 
   @cStorerKey     NVARCHAR( 15), 
   @cToID          NVARCHAR( 18), 
   @cToLoc         NVARCHAR( 10), 
   @cFromLoc       NVARCHAR( 10), 
   @cFromID        NVARCHAR( 18), 
   @cUCC           NVARCHAR( 20), 
   @cUCC1          NVARCHAR( 20), 
   @cUCC2          NVARCHAR( 20), 
   @cUCC3          NVARCHAR( 20), 
   @cUCC4          NVARCHAR( 20), 
   @cUCC5          NVARCHAR( 20), 
   @cUCC6          NVARCHAR( 20), 
   @cUCC7          NVARCHAR( 20), 
   @cUCC8          NVARCHAR( 20), 
   @cUCC9          NVARCHAR( 20), 
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT
)  
AS  
BEGIN
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
  
   IF @nFunc = 514 -- Move by UCC
   BEGIN  
      IF @nStep = 2 -- ToLOC
      BEGIN
         -- VNA location
         IF EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC AND LocationCategory = 'VNA')
         BEGIN
            -- Check not empty 
            IF EXISTS( SELECT TOP 1 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE LOC = @cToLOC AND QTY > 0)
            BEGIN
               -- Get LOC info
               DECLARE @nMaxPallet INT
               SELECT @nMaxPallet = MaxPallet FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC
               
               -- MaxPallet is cartons
               DECLARE @nCartons INT
               IF @nMaxPallet > 0
               BEGIN
                  -- Calc cartons in TOLOC (by case count)
                  SELECT @nCartons  = SUM( Cartons)
                  FROM
                  (
                     SELECT CEILING( SUM( LLI.QTY-LLI.QTYPicked) / CASE WHEN Pack.CaseCnt > 0 THEN Pack.CaseCnt ELSE 1 END) AS Cartons
                     FROM LOTxLOCxID LLI WITH (NOLOCK) 
                        JOIN SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
                        JOIN PACK WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
                     WHERE LLI.LOC = @cToLOC 
                        AND LLI.QTY-LLI.QTYPicked > 0 
                     GROUP BY SKU.StorerKey, SKU.SKU, Pack.CaseCnt
                  ) AS A
                  
                  -- Get UCC
                  DECLARE @nUCC INT
                  SELECT @nUCC = COUNT(1)
                  FROM rdt.rdtMoveUCCLog WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND AddWho = SUSER_SNAME()

                  -- Check able to fit
                  IF (@nCartons + @nUCC) > @nMaxPallet
                  BEGIN
                     SET @nErrNo = 119051
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC cannot fit
                     GOTO Quit
                  END
               END
            END
            
            -- Check pending move in
            IF EXISTS( SELECT TOP 1 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE LOC = @cToLOC AND PendingMoveIn > 0)
            BEGIN
               SET @nErrNo = 119052
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC booked
               GOTO Quit
            END
         END
      END
   END  
  
Quit:  

END

GO