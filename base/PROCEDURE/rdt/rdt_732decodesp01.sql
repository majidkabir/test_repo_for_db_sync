SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_732DecodeSP01                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: UA decode lottable11 and retrieve sku                             */
/*          1 ucc same sku but different lot                                  */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 27-06-2018  James     1.0   WMS5140 Created                                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_732DecodeSP01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cStorerKey     NVARCHAR( 15), 
   @cCCKey         NVARCHAR( 10), 
   @cCCSheetNo     NVARCHAR( 10), 
   @cCountNo       NVARCHAR( 1), 
   @cBarcode       NVARCHAR( 60),
   @cLOC           NVARCHAR( 10)  OUTPUT, 
   @cUPC           NVARCHAR( 20)  OUTPUT, 
   @nQTY           INT            OUTPUT, 
   @cLottable01    NVARCHAR( 18)  OUTPUT, 
   @cLottable02    NVARCHAR( 18)  OUTPUT, 
   @cLottable03    NVARCHAR( 18)  OUTPUT, 
   @dLottable04    DATETIME       OUTPUT, 
   @dLottable05    DATETIME       OUTPUT, 
   @cLottable06    NVARCHAR( 30)  OUTPUT, 
   @cLottable07    NVARCHAR( 30)  OUTPUT, 
   @cLottable08    NVARCHAR( 30)  OUTPUT, 
   @cLottable09    NVARCHAR( 30)  OUTPUT, 
   @cLottable10    NVARCHAR( 30)  OUTPUT, 
   @cLottable11    NVARCHAR( 30)  OUTPUT, 
   @cLottable12    NVARCHAR( 30)  OUTPUT, 
   @dLottable13    DATETIME       OUTPUT, 
   @dLottable14    DATETIME       OUTPUT, 
   @dLottable15    DATETIME       OUTPUT, 
   @cUserDefine01  NVARCHAR( 60)  OUTPUT, 
   @cUserDefine02  NVARCHAR( 60)  OUTPUT, 
   @cUserDefine03  NVARCHAR( 60)  OUTPUT, 
   @cUserDefine04  NVARCHAR( 60)  OUTPUT, 
   @cUserDefine05  NVARCHAR( 60)  OUTPUT, 
   @nErrNo         INT            OUTPUT, 
   @cErrMsg        NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cTempSKU    NVARCHAR( 20), 
           @cQty        NVARCHAR( 5), 
           @bSuccess    INT,
           @nTempQTY    INT,
           @cDisableQTYField    NVARCHAR( 1),
           @cDefaultQty         NVARCHAR(10)
   
   IF @nFunc = 732 -- Simple CC
   BEGIN
      IF @nStep = 4 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cBarcode <> ''
            BEGIN
               SET @cUPC = ''
               SET @cTempSKU = ''
               SET @nTempQTY = 0

               SELECT TOP 1 @cTempSKU = SKU, @nTempQTY = SystemQty
               FROM dbo.CCDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   LOC = @cLOC
               AND   CCKey = @cCCKey
               AND   (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))
               AND   Lottable11 = @cBarcode
               AND   1 = CASE
                     WHEN @cCountNo = '1' AND FinalizeFlag <> 'Y' THEN 1
                     WHEN @cCountNo = '2' AND FinalizeFlag_Cnt2 <> 'Y' THEN 1
                     WHEN @cCountNo = '3' AND FinalizeFlag_Cnt3 <> 'Y' THEN 1
                     ELSE 0 END
               ORDER BY CCDetailKey

               -- If cannot find in lottable11 then maybe user scan a upc/sku
               IF ISNULL( @cTempSKU, '') = ''
               BEGIN
               	SELECT @bsuccess = 1
                  -- Validate SKU/UPC
                  EXEC dbo.nspg_GETSKU
                     @c_StorerKey= @cStorerKey  OUTPUT
                    ,@c_Sku      = @cBarcode    OUTPUT
                    ,@b_Success  = @bSuccess    OUTPUT
                    ,@n_Err      = @nErrNo      OUTPUT
                    ,@c_ErrMsg   = @cErrMsg     OUTPUT

                  -- User key in valid SKU/UPC, no need decode anymore
   	            IF @bSuccess = 1
   	            BEGIN
                     SET @cLottable11 = ''
                     SET @cUPC = @cBarcode

                     SET @cQty = rdt.RDTGetConfig( @nFunc, 'SimpleCCDefaultQTY', @cStorerkey)
                     IF @cQty IN ('', '0')
                        SET @nQty = 0
                     ELSE
                        SET @nQty = CAST( @cQty AS INT)

                     GOTO Quit
                  END
               END
               ELSE  -- Scan value is a valid ucc
               BEGIN
                  -- Check if this ucc scanned b4
                  IF NOT EXISTS ( SELECT 1 
                     FROM dbo.CCDetail WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   LOC = @cLOC
                     AND   CCKey = @cCCKey
                     AND   (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))
                     AND   Lottable11 = @cBarcode
                     AND   1 = CASE
                           WHEN @cCountNo = '1' AND Counted_Cnt1 = '0' THEN 1
                           WHEN @cCountNo = '2' AND Counted_Cnt2 = '0' THEN 1
                           WHEN @cCountNo = '3' AND Counted_Cnt3 = '0' THEN 1
                           ELSE 0 END)
                  BEGIN
                     SET @nErrNo = 126651   
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Scanned B4 
                     GOTO Quit
                  END 

                  -- If system qty is blank qty then take default qty (1st) or screen qty (2nd)
                  IF @nTempQTY = 0
                  BEGIN
                     SET @cDisableQTYField = rdt.RDTGetConfig( @nFunc, 'DisableQTYField', @cStorerkey)
                     IF @cDisableQTYField IN ('', '0')
                        SET @cDisableQTYField = '0'

                     -- (james01)
                     SET @cDefaultQty = ''
                     SET @cDefaultQty = rdt.RDTGetConfig( @nFunc, 'SimpleCCDefaultQTY', @cStorerkey)

                     IF @cDisableQTYField = '1'
                        SET @nTempQTY = CASE WHEN ISNULL(@cDefaultQty, '') = '' OR @cDefaultQty = '0' THEN '1' ELSE @cDefaultQty END
                     ELSE
                        SELECT @nTempQTY = I_Field08
                        FROM RDT.RDTMOBREC WITH (NOLOCK)
                        WHERE Mobile = @nMobile
                  END

                  SET @cLottable11 = @cBarcode
                  SET @cUPC = @cTempSKU
                  SET @nQTY = @nTempQTY
               END
            END   -- @cBarcode
         END   -- ENTER
      END   -- @nStep = 4
   END

Quit:

END

GO