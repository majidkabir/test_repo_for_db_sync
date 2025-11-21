SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_639ExtVal04                                           */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2023-03-09   Ung       1.0   WMS-21506 Created                             */
/* 2023-04-11   Ung       1.1   WMS-22105 Allow SKU to process once Printed   */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_639ExtVal04] (
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

   IF @nFunc = 639 -- Move to UCC V7
   BEGIN
      IF @nStep = 3 -- From LOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- For staging LOC
            IF NOT EXISTS( SELECT 1
               FROM dbo.LOC WITH (NOLOCK)
               WHERE LOC = @cFromLOC
                  AND LocationHandling = '9' 
                  AND LocationCategory = 'STAGING')
            BEGIN
               SET @nErrNo = 197701
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- STAGE LOC ONLY
               GOTO Quit
            END
         END
      END

      IF @nStep = 5 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- For SKU with putaway
            IF NOT EXISTS( SELECT 1
               FROM dbo.RFPutaway RF WITH (NOLOCK)
                  JOIN dbo.LOC WITH (NOLOCK) ON (RF.SuggestedLOC = LOC.LOC)
               WHERE RF.FromLOC = @cFromLOC
                  AND RF.FromID = @cFromID
                  AND RF.StorerKey = @cStorerKey
                  AND RF.SKU = @cSKU
                  AND RF.QTYPrinted > 0
                  AND LOC.LocationCategory IN ('FP','HP','FC'))
            BEGIN
               SET @nErrNo = 197702
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PutawaySKUOnly
               GOTO Quit
            END
         END
      END
      
      IF @nStep = 7 -- UCC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check other user with same SKU trying to post
            IF EXISTS( SELECT 1 
               FROM rdt.rdtMobRec WITH (NOLOCK)
               WHERE Func = 639
                  AND Step = 7
                  AND I_Field01 <> '' -- Already scanned UCC
                  AND V_LOC = @cFromLOC
                  AND StorerKey = @cStorerKey
                  AND V_SKU = @cSKU
                  AND UserName <> SUSER_SNAME())
            BEGIN
               DECLARE @cMsg1 NVARCHAR( 20) 
               DECLARE @cMsg2 NVARCHAR( 20) 
               DECLARE @cMsg3 NVARCHAR( 20) 

               SET @cMsg1 = rdt.rdtgetmessage( 197703, @cLangCode, 'DSP') -- LOCKED BY: 
               SET @cMsg2 = SUSER_SNAME()
               SET @cMsg3 = rdt.rdtgetmessage( 197704, @cLangCode, 'DSP') -- PLEASE RETRY LATER

               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @cMsg1,  @cMsg2, '', @cMsg3
               SET @nErrNo = -1
               GOTO Quit
            END
         END
      END
   END

Quit:


GO