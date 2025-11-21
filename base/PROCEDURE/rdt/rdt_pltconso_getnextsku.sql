SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_PltConso_GetNextSKU                             */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get next SKU                                                */
/*                                                                      */
/* Called from: rdtfnc_PalletConsolidate                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 16-02-2015  1.0  James       SOS315975 Created                       */
/* 17-12-2015  1.1  James       Allow pallet mix storer (james01)       */
/************************************************************************/

CREATE PROC [RDT].[rdt_PltConso_GetNextSKU] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cFromID          NVARCHAR( 20),
   @cOption          NVARCHAR,
   @nQty             INT,
   @cToID            NVARCHAR( 20),
   @nMultiStorer     INT,
   @cSKU_StorerKey   NVARCHAR( 15)  OUTPUT,
   @cSKU             NVARCHAR( 20)  OUTPUT,
   @cDescr           NVARCHAR( 60)  OUTPUT,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSuggestedSKU     NVARCHAR( 20)

   SELECT TOP 1 @cSuggestedSKU = SKU, 
                @cSKU_StorerKey = StorerKey 
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
   WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN StorerKey ELSE @cStorerKey END
   AND   LLI.ID = @cFromID 
   AND   LOC.Facility = @cFacility
   AND   LLI.Qty > 0
   AND   LLI.SKU > @cSKU
   ORDER BY 1

   IF ISNULL( @cSuggestedSKU, '') <> ''
   BEGIN
      SELECT @cDescr = DESCR 
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cSKU_StorerKey
      AND   SKU = @cSuggestedSKU
   END
   ELSE
   BEGIN
      SET @cSuggestedSKU = ''
   END

   SET @cSKU = @cSuggestedSKU

   
Quit:
END

GO