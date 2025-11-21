SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Stored Procedure: rdt_600ExtScrVLT                                         */
/*                                                                            */
/* Updates:                                                                   */
/* Date         Author  Ver.    Purposes                                      */
/* 07/06/2024   PPA374  1.0     Check receipt location                        */
/* 18/10/2024   PPA374  1.1     Adding shelf locations AND trolleyQC to check */
/* 18/10/2024   PPA374  1.2     Adding checks for lottable                    */
/* 31/10/2024   PPA374  1.3.0   UWP-26437 Removing typo from previous version */
/******************************************************************************/
CREATE   PROC [RDT].[rdt_600ExtScrVLT]
   @nMobile             INT,
   @nFunc               INT,
   @cLangCode           NVARCHAR( 3),
   @nStep               INT,
   @nScn                INT,
   @nInputKey           INT,
   @cFacility           NVARCHAR( 5),
   @cStorerKey          NVARCHAR( 15),
   @cSuggLOC            NVARCHAR( 10) OUTPUT,
   @cLOC                NVARCHAR( 20) OUTPUT,
   @cID                 NVARCHAR( 20) OUTPUT,
   @cSKU                NVARCHAR( 20) OUTPUT,
   @cReceiptKey         NVARCHAR( 10),
   @cPOKey              NVARCHAR( 10),
   @cReasonCode         NVARCHAR( 10),
   @cReceiptLineNumber  NVARCHAR( 5),
   @cPalletType         NVARCHAR( 10),
   @cInField01          NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,  @cLottable01 NVARCHAR( 18) OUTPUT,
   @cInField02          NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,  @cLottable02 NVARCHAR( 18) OUTPUT,
   @cInField03          NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,  @cLottable03 NVARCHAR( 18) OUTPUT,
   @cInField04          NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,  @dLottable04 DATETIME      OUTPUT,
   @cInField05          NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,  @dLottable05 DATETIME      OUTPUT,
   @cInField06          NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,  @cLottable06 NVARCHAR( 30) OUTPUT,
   @cInField07          NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,  @cLottable07 NVARCHAR( 30) OUTPUT,
   @cInField08          NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,  @cLottable08 NVARCHAR( 30) OUTPUT,
   @cInField09          NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,  @cLottable09 NVARCHAR( 30) OUTPUT,
   @cInField10          NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,  @cLottable10 NVARCHAR( 30) OUTPUT,
   @cInField11          NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT,  @cLottable11 NVARCHAR( 30) OUTPUT,
   @cInField12          NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT,  @cLottable12 NVARCHAR( 30) OUTPUT,
   @cInField13          NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT,  @dLottable13 DATETIME      OUTPUT,
   @cInField14          NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT,  @dLottable14 DATETIME      OUTPUT,
   @cInField15          NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT,  @dLottable15 DATETIME      OUTPUT,
   @nAction             INT,
   @nAfterScn           INT OUTPUT, 
   @nAfterStep          INT OUTPUT, 
   @nErrNo              INT            OUTPUT, 
   @cErrMsg             NVARCHAR( 20)  OUTPUT
AS    
BEGIN   
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    

   IF @nFunc = 600
   BEGIN
      IF @nStep = 2
      BEGIN
         -- Load RDT.RDTMobRec
         SELECT @cLOC = I_Field03
         FROM RDT.RDTMOBREC WITH (NOLOCK)
         WHERE Mobile = @nMobile

         --Checking that location type that user is trying to receive to is added to the receiving codelkup
         IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH(NOLOCK) WHERE loc = @cLOC AND EXISTS (SELECT 1 FROM dbo.CODELKUP (NOLOCK) WHERE LocationType = Code
            AND LISTNAME = 'HUSQINBLOC' AND Storerkey = @cStorerKey) AND FACILITY = @cFacility)
         BEGIN
            SET @nErrNo = 217909
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotReceivingLocation
            GOTO Quit  
         END

            UPDATE dbo.SKU WITH(ROWLOCK)
               SET LottableCode = 'HUSQBATTERY'
            WHERE Style = 'B' AND StorerKey = @cStorerKey AND LottableCode <> 'HUSQBATTERY'
         
            UPDATE dbo.SKU WITH(ROWLOCK)
               SET LottableCode = 'HUSQSHELF'
            WHERE Style = 'SHLV' AND StorerKey = @cStorerKey AND LottableCode <> 'HUSQSHELF'    
      END

      IF @nStep = 5
      BEGIN
         --Checklottables
         IF CAST(@dLottable05 AS DATE) > GETDATE()
         BEGIN
            SET @nErrNo = 218030
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Date can''t be future'
            GOTO Quit
         END
         
         IF CAST(@dLottable05 AS DATE) <= '2024-01-01'
         BEGIN
            SET @nErrNo = 218031
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Please check DATE
            GOTO Quit
         END

         IF (ISNUMERIC(@cLottable11) <> 1 or CHARINDEX('.', @cLottable11) > 0) AND @cLottable11 <> ''
         --Checklottables
         BEGIN
            SET @nErrNo = 218032
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Enter whole numeric value'
            GOTO Quit
         END

         IF (SELECT TOP 1 style FROM dbo.sku WITH(NOLOCK) WHERE sku = @cSKU) <> 'B' AND @cLottable12 <> ''
         BEGIN
            SET @nErrNo = 218033
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No batch no required'
            GOTO quit
         END

         IF (SELECT TOP 1 style FROM dbo.sku WITH(NOLOCK) WHERE sku = @cSKU) = 'B' 
            AND (@cLottable12 = '' OR ISNUMERIC(@cLottable12) <> 1 OR LEN(@cLottable12) <> 4)
         BEGIN
            SET @nErrNo = 218034
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Incorrect batch no'
            GOTO Quit
         END
      END
   END
Quit:
END

GO