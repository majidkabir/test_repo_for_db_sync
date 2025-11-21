SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_641ExtValid01                                   */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: Check validity of tracking id                               */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 2020-03-12  1.0  James       WMS-12360. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_641ExtValid01]
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cParentTrackID NVARCHAR( 20),
   @cChildTrackID  NVARCHAR( 1000),
   @cSKU           NVARCHAR( 10),
   @nQty           INT,
   @cOption        NVARCHAR( 1),
   @tExtValidate   VariableTable READONLY,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPallet_SKU    NVARCHAR( 20)
   DECLARE @nCaseCnt       INT = 0
   DECLARE @nPallet        INT = 0
   DECLARE @nScanned       INT = 0

   IF @nStep = 2 -- Child Tracking ID
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- 1 Pallet 1 SKU
         SELECT TOP 1 @cPallet_SKU = SKU
         FROM dbo.TrackingID WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ParentTrackingID = @cParentTrackID
         AND   [Status] = '0'
         ORDER BY 1
         
         IF ISNULL( @cPallet_SKU, '') <> ''
         BEGIN
            IF @cSKU <> @cPallet_SKU
            BEGIN
               SET @nErrNo = 149451
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Cannot Mix SKU
               GOTO Quit
            END
         END

         -- Check over scan
         SELECT @nCaseCnt = PACK.CaseCnt,
                @nPallet = PACK.Pallet
         FROM dbo.SKU SKU WITH (NOLOCK)
         JOIN dbo.PACK PACK WITH (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey)
         WHERE SKU.StorerKey = @cStorerKey
         AND   SKU.Sku = @cSKU
         
         SELECT @nScanned = ISNULL( SUM( Qty), 0)
         FROM dbo.TrackingID WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ParentTrackingID = @cParentTrackID
         AND   [Status] = '0'
         
         IF @nCaseCnt + @nScanned > @nPallet
         BEGIN
            SET @nErrNo = 149452
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Scanned
            GOTO Quit
         END
      END
   END

Quit:
END

GO