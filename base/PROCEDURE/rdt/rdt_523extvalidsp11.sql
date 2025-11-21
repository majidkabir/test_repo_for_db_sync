SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_523ExtValidSP11                                 */
/*                                                                      */
/* Purpose: Validate Qty PWY cannot exceed home loc qty.                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author    Purposes                                   */
/* 2023-02-27 1.0  yeekung     WMS-21630. Created                       */
/************************************************************************/

CREATE   PROC [RDT].[rdt_523ExtValidSP11] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR( 5),
   @cFromLOC        NVARCHAR( 10),
   @cFromID         NVARCHAR( 18),
   @cSKU            NVARCHAR( 20),
   @nQty            INT,
   @cSuggestedLOC   NVARCHAR( 10),
   @cFinalLOC       NVARCHAR( 10),
   @cOption         NVARCHAR( 1),
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPutawayZone NVARCHAR(20)
   DECLARE @nMaxQTY      INT
   
   DECLARE  @cHazmat             NVARCHAR( 1),
            @cLocCategory        NVARCHAR( 10)

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 4
      BEGIN
         IF ISNULL( @cFinalLOC, '') = ''
         BEGIN
            SET @nErrNo = 197101
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid LOC'
            GOTO Quit
         END

            IF ISNULL( @cSKU, '') = ''
            BEGIN
               SET @nErrNo = 197102
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
               GOTO Quit
            END

            IF EXISTS ( SELECT 1 FROM dbo.SKU WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                        AND   SKU = @cSKU
                        AND   HazardousFlag = '1')
               SET @cHazmat = '1'
            ELSE
               SET @cHazmat = '0'

            SELECT @cLocCategory = LocationCategory
            FROM LOC WITH (NOLOCK)
            WHERE LOC = @cFinalLOC
            AND   Facility = @cFacility

            IF @cHazmat = '1' AND
               NOT EXISTS ( SELECT 1 FROM SKU SKU WITH (NOLOCK)
                              JOIN SKUInfo SIF WITH (NOLOCK) ON
                                 ( SKU.StorerKey = SIF.StorerKey AND SKU.SKU = SIF.SKU)
                              WHERE SKU.StorerKey = @cStorerKey
                              AND   SKU.SKU = @cSKU
                              AND   SIF.ExtendedField01 = @cLocCategory)
            BEGIN
               SET @nErrNo = 197103
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Cat'
               GOTO Quit
            END

            IF @cHazmat = '0' AND @cLocCategory <> 'OTHER'
            BEGIN
               SET @nErrNo = 197104
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Cat'
               GOTO Quit
            END

         SELECT @cPutawayZone=putawayzone,
                @nMaxQTY = MaxQTY
         FROM LOC (NOLOCK)
         WHERE loc =@cFinalLOC
         AND facility=@cFacility

         IF ISNULL(@nMaxQTY,'')  NOT IN ('0','')
         BEGIN
            IF EXISTS (SELECT 1 FROM CODELKUP (NOLOCK)
                        WHERE storerkey=@cStorerKey
                           AND listname='PAwayMaxQ'
                           AND code = @cPutawayZone)
            BEGIN

               IF EXISTS (SELECT 1
                           FROM LOTXLOCXID (NOLOCK)
                           WHERE loc=@cFinalLOC
                           HAVING SUM (Qty-Qtyallocated)+@nQty>@nMaxQTY)
               BEGIN
                  SET @nErrNo = 197105
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ExceedAcceptQty'
                  GOTO QUIT
               END

            END
         END
      END
   END

   QUIT:


GO