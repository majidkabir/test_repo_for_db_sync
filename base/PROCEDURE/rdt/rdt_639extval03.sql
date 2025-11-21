SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_639ExtVal03                                           */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2022-07-18   Ung       1.0   WMS-20238 migrate from rdt_1804ExtValidSP04   */
/******************************************************************************/

CREATE PROC [RDT].[rdt_639ExtVal03] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR(3),
   @nStep           INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR(15),
   @cFacility       NVARCHAR(5),
   @cToLOC          NVARCHAR(10),
   @cToID           NVARCHAR(18),
   @cFromLOC        NVARCHAR(10),
   @cFromID         NVARCHAR(18),
   @cSKU            NVARCHAR(20),
   @nQTY            INT,
   @cUCC            NVARCHAR(20),
   @cLottable01     NVARCHAR(18),
   @cLottable02     NVARCHAR(18),
   @cLottable03     NVARCHAR(18),
   @dLottable04     DATETIME,
   @dLottable05     DATETIME,
   @cLottable06     NVARCHAR(18),
   @cLottable07     NVARCHAR(18),
   @cLottable08     NVARCHAR(18),
   @cLottable09     NVARCHAR(18),
   @cLottable10     NVARCHAR(18),
   @cLottable11     NVARCHAR(18),
   @cLottable12     NVARCHAR(18),
   @dLottable13     DATETIME,
   @dLottable14     DATETIME,
   @dLottable15     DATETIME,
   @tExtValidVar    VARIABLETABLE READONLY,
   @nErrNo          INT OUTPUT,
   @cErrMsg         NVARCHAR(20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nCaseCnt       INT
   DECLARE @cUCCLabel      NVARCHAR( 20)
   DECLARE @cLabelPrinter  NVARCHAR( 10)
   DECLARE @cInField02     NVARCHAR( 60)

   IF @nFunc = 639
   BEGIN
      IF @nStep = 5 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check SKU LottableCode
            IF EXISTS( SELECT 1
               FROM dbo.SKU WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND SKU = @cSKU
                  AND ISNULL( LottableCode, '') = '')
            BEGIN
               SET @nErrNo = 188401
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SetLottableCod
               GOTO Quit
            END
         END
      END

      IF @nStep = 6 -- QTY
      BEGIN
         SELECT @cInField02 = I_Field02 FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE MOBILE = @nMobile

         IF @nQTY > 0         -- Screen can enter sku only and leave qty blank/0
         AND @cInField02 = '' -- If user enter blank sku and qty > 0 then go to step 7
         BEGIN
            SELECT @nCaseCnt = PACK.CaseCnt
            FROM dbo.SKU SKU WITH (NOLOCK)
            JOIN dbo.PACK PACK WITH (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey)
            WHERE SKU.Sku = @cSKU
            AND   SKU.StorerKey = @cStorerKey

            IF @nQTY <> @nCaseCnt
            BEGIN
               SET @nErrNo = 188402
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- QTY <> CASECNT
               GOTO Quit
            END
         END
      END

      IF @nStep = 7 -- To UCC
      BEGIN
         SET @cUCCLabel = rdt.rdtGetConfig( @nFunc, 'UCCLabel', @cStorerKey)
         IF @cUCCLabel = '0'
            SET @cUCCLabel = ''

         IF @cUCCLabel <> ''
         BEGIN
            SELECT @cLabelPrinter = Printer
            FROM RDT.RDTMOBREC WITH (NOLOCK)
            WHERE Mobile = @nMobile

            IF ISNULL( @cLabelPrinter, '') = ''
            BEGIN
               SET @nErrNo = 188403
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NOLABELPRINTER
               GOTO Quit
            END
         END
      END
   END

Quit:


GO