SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtVal02                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Validate pallet id before putaway                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2017-02-17   James     1.0   WMS1079. Created                        */
/* 2017-09-11   James     1.1   WMS1892. Add mix Lot01 valid (james01)  */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1819ExtVal02]
   @nMobile         INT,          
   @nFunc           INT,          
   @cLangCode       NVARCHAR( 3), 
   @nStep           INT,          
   @nInputKey       INT,           
   @cFromID         NVARCHAR( 18),
   @cSuggLOC        NVARCHAR( 10),
   @cPickAndDropLOC NVARCHAR( 10),
   @cToLOC          NVARCHAR( 10),
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cStorerKey NVARCHAR( 15),
           @cSKU       NVARCHAR( 20),
           @cUCC       NVARCHAR( 20),
           @cFacility  NVARCHAR( 10)

   SELECT @cStorerKey = StorerKey, @cFacility = Facility
   FROM rdt.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   IF @nInputKey = 1 
   BEGIN
      IF @nStep = 1 
      BEGIN
         DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT DISTINCT UCCNo, SKU 
         FROM dbo.UCC WITH (NOLOCK) 
         WHERE Storerkey = @cStorerKey
         AND   ID = @cFromID
         AND   [Status] = '1'
         OPEN CUR_LOOP
         FETCH NEXT FROM CUR_LOOP INTO @cUCC, @cSKU
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                        AND   UCCNo = @cUCC 
                        AND   [Status] = '1'
                        GROUP BY UCCNo 
                        HAVING COUNT( DISTINCT SKU) > 1)
            BEGIN
               SET @nErrNo = 106301
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mix ucc sku
               CLOSE CUR_LOOP
               DEALLOCATE CUR_LOOP
               GOTO Quit
            END

            IF NOT EXISTS ( 
               SELECT 1 FROM dbo.SKU WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   SKU = @cSKU 
               AND   ISNULL( STDCUBE, 0) > 0)
            BEGIN
               SET @nErrNo = 106302
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Stdcube = 0
               CLOSE CUR_LOOP
               DEALLOCATE CUR_LOOP
               GOTO Quit
            END

            FETCH NEXT FROM CUR_LOOP INTO @cUCC, @cSKU
         END
         CLOSE CUR_LOOP
         DEALLOCATE CUR_LOOP

         -- 1 SKU cannot have > 1 sku grade (lottable01) on the pallet
         IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
                     JOIN dbo.LotAttribute LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)
                     WHERE LLI.StorerKey = @cStorerKey
                     AND   LLI.ID = @cFromID
                     AND   LLI.Qty > 0
                     AND   LOC.Facility = @cFacility
                     GROUP BY LA.SKU
                     HAVING COUNT( DISTINCT LA.Lottable01) > 1)
         BEGIN
            SET @nErrNo = 106303
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mix sku grade
            GOTO Quit
         END
      END
   END

Quit:

END

GO