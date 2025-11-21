SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  rdt_CheckEmptyPallet                               */  
/*                                                                      */
/* Purpose: Check whether pallet is empty                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2015-04-14   1.0  James      SOS314929 - Created                     */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_CheckEmptyPallet] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR (3),
   @cFacility        NVARCHAR (5),
   @cStorerKey       NVARCHAR( 15),
   @cFromID          NVARCHAR( 20),    
   @cToID            NVARCHAR( 20),    
   @cFromLOC         NVARCHAR( 10), 
   @cSKU             NVARCHAR( 20), 
   @nQty             INT, 
   @nErrNo           INT            OUTPUT, 
   @cErrMsg          NVARCHAR( 20)  OUTPUT  -- screen limitation, 20 char max
)
AS
BEGIN
   
   DECLARE  @cLOCCategory        NVARCHAR( 10), 
            @cCurrentL06         NVARCHAR( 10),
            @cOtherL06           NVARCHAR( 10),
            @cCurrentZone        NVARCHAR( 10),
            @cOtherZone          NVARCHAR( 10), 
            @cCurrentStorer      NVARCHAR( 15), 
            @cLottable06         NVARCHAR( 30) 

   -- Check ID on hold
   IF EXISTS( SELECT 1 FROM dbo.InventoryHold WITH (NOLOCK) WHERE ID = @cToID AND Hold = '1')
   BEGIN
      SET @nErrNo = 53451
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID on hold
      GOTO Quit
   END

   -- Pallet ID has inventory
   IF EXISTS (SELECT 1 
              FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
              JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
              WHERE LOC.Facility = @cFacility
              AND   LLI.ID = @cToID 
              AND   LLI.Qty > 0 ) 
   BEGIN
      -- If loc is on the excluded location category (eg. staging) then more checking to perform
      IF EXISTS ( SELECT 1 
                  FROM dbo.CODELKUP CL WITH (NOLOCK) 
                  JOIN dbo.LOC LOC WITH (NOLOCK) ON CL.Code = LOC.LocationCategory
                  WHERE ListName = 'EXCLOCCAT'
                  AND   Code = @cLOCCategory
                  AND   StorerKey = @cStorerKey
                  AND   LOC = @cFromLOC)
      BEGIN
         -- Get from id storer
         SELECT TOP 1 @cCurrentStorer = LLI.StorerKey
         FROM dbo.LotxLocXID LLI WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
         WHERE LLI.ID = @cFromID 
         AND   LLI.Qty > 0
         AND   LOC.Facility = @cFacility

         -- Check if mix storer for to id
         IF NOT EXISTS ( SELECT 1 
                         FROM dbo.LotxLocXID LLI WITH (NOLOCK) 
                         JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
                         WHERE LLI.StorerKey = @cCurrentStorer
                         AND   LLI.ID = @cToID 
                         AND   LLI.Qty > 0
                         AND   LOC.Facility = @cFacility)
         BEGIN
            SET @nErrNo = 53452
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PalletMixStore
            GOTO Quit
         END      

         SELECT TOP 1 @cLottable06 = LA.Lottable06
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON LLI.LOT = LA.LOT
         JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC 
         WHERE LLI.ID = @cToID
         AND   LLI.Qty > 0
         AND   LOC.Facility = @cFacility

         IF @cLottable06 <> '' 
         BEGIN
            -- Get current L06 is bond / non-bond
            SET @cCurrentL06 = ''
            SELECT @cCurrentL06 = ISNULL( Short, '')
            FROM CodeLKUP WITH (NOLOCK) 
            WHERE ListName = 'BONDFAC' 
               AND StorerKey = @cStorerKey
               AND Code = @cLottable06
                  
            IF @cCurrentL06 <> '' AND (@cCurrentL06 = 'BONDED' OR @cCurrentL06 = 'UNBONDED')
            BEGIN
               IF @cCurrentL06 = 'BONDED'
                  SET @cOtherL06  = 'UNBONDED'
               ELSE
                  SET @cOtherL06  = 'BONDED'
                     
               -- Check mix L06 (bond / non-bond)
               IF EXISTS( SELECT 1 
                  FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                  JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON LLI.LOT = LA.LOT
                  JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
                  WHERE LOC.Facility = @cFacility
                     AND LLI.ID = @cToID
                     AND LA.Lottable06 <> ''
                     AND EXISTS(
                        SELECT 1
                        FROM CodeLKUP WITH (NOLOCK) 
                        WHERE ListName = 'BONDFAC' 
                           AND StorerKey = @cStorerKey
                           AND Code = LA.Lottable06
                           AND Short = @cOtherL06))
               BEGIN
                  SET @nErrNo = 53453
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MixBond/Unbond
                  GOTO Quit
               END
            END
         END

         -- Get SKU info
         SELECT TOP 1 @cCurrentZone = SKU.PutawayZone 
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON LLI.SKU = SKU.SKU AND LLI.StorerKey = SKU.StorerKey
         JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
         WHERE SKU.StorerKey = @cStorerKey 
         AND   LLI.ID = @cToID
         AND   LOC.Facility = @cFacility
               
         -- Check mix zone (AIRCOND or AMBIENT) on same ID
         IF @cCurrentZone = 'AIRCOND' OR @cCurrentZone = 'AMBIENT'
         BEGIN
            IF @cCurrentZone = 'AIRCOND'
               SET @cOtherZone = 'AMBIENT'
            ELSE
               SET @cOtherZone = 'AIRCOND'

            IF EXISTS ( SELECT 1 
                        FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                        JOIN dbo.SKU SKU WITH (NOLOCK) ON LLI.SKU = SKU.SKU AND LLI.StorerKey = SKU.StorerKey
                        JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
                        WHERE SKU.StorerKey = @cStorerKey 
                        AND   SKU.PutawayZone = @cOtherZone
                        AND   LLI.ID = @cToID
                        AND   LOC.Facility = @cFacility)
           BEGIN
               SET @nErrNo = 53454
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mix AC/Ambient
               GOTO Quit
            END
         END
      END
      ELSE
      BEGIN
         SET @nErrNo = 53455
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Pallet Not Empty
         GOTO Quit
      END
   END      

Quit:

END

GO