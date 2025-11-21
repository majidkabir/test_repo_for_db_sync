SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_513ExtVal10                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2021-04-09 1.0  James      WMS-16776. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_513ExtVal10] (
   @nMobile         INT,          
   @nFunc           INT,          
   @cLangCode       NVARCHAR( 3), 
   @nStep           INT,          
   @nInputKey       INT,          
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR(  5),
   @cFromLOC        NVARCHAR( 10),
   @cFromID         NVARCHAR( 18),
   @cSKU            NVARCHAR( 20),
   @nQTY            INT,          
   @cToID           NVARCHAR( 18),
   @cToLOC          NVARCHAR( 10),
   @nErrNo          INT           OUTPUT,   
   @cErrMsg         NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @cPickSlipNo NVARCHAR(10)
DECLARE @cSOStatus   NVARCHAR(10)
DECLARE @cShipperKey NVARCHAR(15)
DECLARE @nRowCount   INT
DECLARE @cFromLottable02   NVARCHAR( 18) = ''
DECLARE @cToLottable02     NVARCHAR( 18) = ''

   IF @nStep = 6 -- LOC
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN                  
         IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                     JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot)
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)       
                     WHERE LLI.StorerKey = @cStorerKey
                     AND   LLI.Loc = @cFromLOC
                     AND   (( @cFromID = '') OR ( LLI.Id = @cFromID))
                     AND   LLI.Sku = @cSKU
                     AND   LLI.Qty > 0
                     AND   LA.Lottable08 = 'AP1BCH'
                     AND   LOC.Facility = @cFacility)
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK) 
                        WHERE Loc = @cToLOC 
                        AND   Facility = @cFacility
                        AND   PickZone NOT IN ( 'LOGIBFG', 'LOGIBCV'))
            BEGIN
               SET @nErrNo = 165901
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid ToLOC
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK) 
                        WHERE Loc = @cToLOC 
                        AND   Facility = @cFacility
                        AND   PickZone IN ( 'LOGIBFG', 'LOGIBCV'))
            BEGIN
               SET @nErrNo = 165902
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid ToLOC
               GOTO Quit
            END
         END

         IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                     JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot)
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)       
                     WHERE LLI.StorerKey = @cStorerKey
                     AND   LLI.Loc = @cFromLOC
                     AND   (( @cFromID = '') OR ( LLI.Id = @cFromID))
                     AND   LLI.Sku = @cSKU
                     AND   LLI.Qty > 0
                     AND   LA.Lottable09 = 'AP1BCV'
                     AND   LOC.Facility = @cFacility)
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK) 
                        WHERE Loc = @cToLOC 
                        AND   Facility = @cFacility
                        AND   PickZone <> 'LOGIBCV')
            BEGIN
               SET @nErrNo = 165903
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid ToLOC
               GOTO Quit
            END
         END

         IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                     JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot)
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)       
                     WHERE LLI.StorerKey = @cStorerKey
                     AND   LLI.Loc = @cFromLOC
                     AND   (( @cFromID = '') OR ( LLI.Id = @cFromID))
                     AND   LLI.Sku = @cSKU
                     AND   LLI.Qty > 0
                     AND   LA.Lottable09 IN ( 'AP1BFG', 'AP1BCP', 'AP1BRP')
                     AND   LOC.Facility = @cFacility)
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK) 
                        WHERE Loc = @cToLOC 
                        AND   Facility = @cFacility
                        AND   PickZone <> 'LOGIBFG')
            BEGIN
               SET @nErrNo = 165904
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid ToLOC
               GOTO Quit
            END
         END
         /*
         IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                     JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot)
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)       
                     WHERE LLI.StorerKey = @cStorerKey
                     AND   LLI.Loc = @cFromLOC
                     AND   (( @cFromID = '') OR ( LLI.Id = @cFromID))
                     AND   LLI.Sku = @cSKU
                     AND   LLI.Qty > 0
                     AND   LA.Lottable08 = 'AP1BCH'
                     AND   LOC.Facility = @cFacility
                     GROUP BY LA.Lottable08
                     HAVING COUNT( DISTINCT LA.Lottable02) > 1)
         BEGIN
            */
         SELECT @cFromLottable02 = LA.Lottable02 
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)       
         WHERE LLI.StorerKey = @cStorerKey
         AND   LLI.Loc = @cFromLOC
         AND   LLI.Sku = @cSKU
         AND   LLI.Qty > 0
         AND   LA.Lottable08 = 'AP1BCH'
         AND   LOC.Facility = @cFacility

         SELECT @cToLottable02 = LA.Lottable02 
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)       
         WHERE LLI.StorerKey = @cStorerKey
         AND   LLI.Loc = @cToLOC
         AND   LLI.Sku = @cSKU
         AND   LLI.Qty > 0
         AND   LA.Lottable08 = 'AP1BCH'
         AND   LOC.Facility = @cFacility
         
         IF @cFromLottable02 <> @cToLottable02 AND
            ISNULL( @cFromLottable02, '') <> '' AND 
            ISNULL( @cToLottable02, '') <> ''
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK) 
                        WHERE Loc = @cToLOC 
                        AND   Facility = @cFacility
                        AND   PickZone IN ( 'LOGIBFG', 'LOGIBCV'))
            BEGIN
               SET @nErrNo = 165905
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Mix Lot02
               GOTO Quit
            END
         END
      END
   END


Quit:


GO