SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_PltConsoSSCC_GetNextSKU                         */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get next SKU                                                */
/*                                                                      */
/* Called from: rdtfnc_PalletConsolidate_SSCC                           */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author      Purposes                               */
/* 18-Mar-2016  1.0  James       SOS357366 - Created                    */
/************************************************************************/

CREATE PROC [RDT].[rdt_PltConsoSSCC_GetNextSKU] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cFromID          NVARCHAR( 20),
   @cOption          NVARCHAR( 10),
   @nQty             INT,
   @cToID            NVARCHAR( 20),
   @nMultiStorer     INT,
   @cSKU_StorerKey   NVARCHAR( 15)  OUTPUT,
   @cSKU             NVARCHAR( 20)  OUTPUT,
   @cDescr           NVARCHAR( 60)  OUTPUT,
   @cPUOM_Desc       NVARCHAR( 10)  OUTPUT, 
   @cMUOM_Desc       NVARCHAR( 10)  OUTPUT, 
   @nSKU_CNT         INT            OUTPUT,
   @nPQTY            INT            OUTPUT,
   @nMQTY            INT            OUTPUT,
   @nTtl_Scanned     INT            OUTPUT,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSuggestedSKU     NVARCHAR( 20),
           @cID               NVARCHAR( 18), 
           @cUserName         NVARCHAR( 18), 
           @nPUOM_Div         INT,
           @nIDQTY            INT

   SELECT @cUserName = UserName
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nInputKey = 1
   BEGIN
      IF @nStep IN (3, 4)
      BEGIN
         SELECT @cID = CASE WHEN @nStep = 3 AND @cToID <> '' THEN @cToID 
                            WHEN @nStep = 3 AND @cToID = '' THEN @cFromID 
                            WHEN @nStep = 4 THEN @cToID 
                            WHEN @nStep = 4 AND @cToID = '' THEN @cFromID 
                       ELSE CASE WHEN @cOption = 'CURRENT' THEN @cToID ELSE @cFromID END END

         IF @cOption = 'NEXT' AND @cToID = '' AND @nStep = 4
            SET @cID = @cFromID

         IF @cOption = 'NEXT'
         BEGIN
            SELECT TOP 1 @cSuggestedSKU = SKU, 
                         @cSKU_StorerKey = StorerKey 
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
            WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN StorerKey ELSE @cStorerKey END
            AND   LLI.ID = @cID 
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

            IF ISNULL( @cSuggestedSKU, '') = ''
            BEGIN
               SET @cSKU = ''
               GOTO Quit
            END
            ELSE
               SET @cSKU = @cSuggestedSKU
         END

         SELECT @nSKU_CNT = COUNT( DISTINCT SKU)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
         WHERE LLI.StorerKey = @cStorerKey 
         AND   LLI.ID = @cID 
         AND   LOC.Facility = @cFacility
         AND   Qty > 0

         -- Get SKU QTY
         SELECT @nIDQTY = ISNULL( SUM( QTY), 0)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
         WHERE LLI.StorerKey = @cStorerKey 
         AND   LLI.ID = @cID 
         AND   LOC.Facility = @cFacility
         AND   SKU = @cSKU

         IF @nIDQTY = 0
            GOTO Quit

         SELECT 
            @cMUOM_Desc = Pack.PackUOM3, 
            @cPUOM_Desc = Pack.PackUOM1, -- Case
            @nPUOM_Div = CAST( Pack.CaseCNT AS INT) 
         FROM dbo.SKU S (NOLOCK) 
         JOIN dbo.Pack Pack (nolock) ON (S.PackKey = Pack.PackKey)
         WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

         -- Convert to prefer UOM QTY
         IF @nPUOM_Div = 0 -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY = 0
            SET @nMQTY = @nIDQTY 
         END
         ELSE
         BEGIN
            SET @nPQTY = @nIDQTY/ @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMQTY = @nIDQTY % @nPUOM_Div -- Calc the remaining in master unit
         END

         SELECT @nTtl_Scanned = ISNULL( SUM( Qty), 0)/@nPUOM_Div
         FROM dbo.PalletDetail PLTD WITH (NOLOCK)
         WHERE PLTD.Storerkey = @cStorerkey
         AND   PLTD.UserDefine01 = @cID
         AND   PLTD.Status < '9'
         AND   PLTD.SKU = @cSKU
         AND   EXISTS (
               SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
               WHERE PLTD.Storerkey = PD.Storerkey
               AND   PLTD.UserDefine01 = PD.ID
               AND   PLTD.UserDefine02 = PD.PickDetailKey
               AND   PLTD.Sku = PD.Sku
               AND   PD.Status < '9')
      END

      IF @nStep = 5
      BEGIN
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
      END
   END



   
Quit:
END

GO