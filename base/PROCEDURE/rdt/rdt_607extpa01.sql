SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_607ExtPA01                                            */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 14-Sep-2015  Ung       1.0   SOS350418 Created                             */
/* 16-Nov-2016  Ung       1.1   WMS-586 Add Excess stock                      */
/* 13-Aug-2018  Ung       1.2   WMS-5956 Add CPD brand                        */
/* 19-Feb-2019  James     1.3   WMS-7929 Remove CPD brand                     */
/* 03-Aug-2020  James     1.4   WMS-14494 - ToLoc Suggestion change (james01) */
/* 03-Feb-2022  Ung       1.5   WMS-18844 Add suggest LOC by RecType + L06    */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_607ExtPA01]
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cStorerKey   NVARCHAR( 15), 
   @cReceiptKey  NVARCHAR( 10), 
   @cPOKey       NVARCHAR( 10), 
   @cRefNo       NVARCHAR( 20), 
   @cSKU         NVARCHAR( 20), 
   @nQTY         INT,           
   @cLottable01  NVARCHAR( 18), 
   @cLottable02  NVARCHAR( 18), 
   @cLottable03  NVARCHAR( 18), 
   @dLottable04  DATETIME,      
   @dLottable05  DATETIME,      
   @cLottable06  NVARCHAR( 30), 
   @cLottable07  NVARCHAR( 30), 
   @cLottable08  NVARCHAR( 30), 
   @cLottable09  NVARCHAR( 30), 
   @cLottable10  NVARCHAR( 30), 
   @cLottable11  NVARCHAR( 30), 
   @cLottable12  NVARCHAR( 30), 
   @dLottable13  DATETIME,      
   @dLottable14  DATETIME,      
   @dLottable15  DATETIME, 
   @cReasonCode  NVARCHAR( 10), 
   @cID          NVARCHAR( 18), 
   @cLOC         NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 10), 
   @cSuggID      NVARCHAR( 18)  OUTPUT, 
   @cSuggLOC     NVARCHAR( 10)  OUTPUT, 
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 607 -- Return v7
   BEGIN
      DECLARE @nActQTY INT
      DECLARE @nExcessQTY INT
      DECLARE @nQTYExpected INT
      DECLARE @nBeforeReceivedQTY INT
      DECLARE @cSignatory NVARCHAR( 18)
      DECLARE @cBrand NVARCHAR( 250)
      DECLARE @cRECType NVARCHAR( 10)
      DECLARE @cItemClass NVARCHAR( 10)
      
      -- Get receipt info
      SELECT @cSignatory = ISNULL( Signatory, ''), 
             @cRECType = RECType
      FROM Receipt WITH (NOLOCK) 
      WHERE ReceiptKey = @cReceiptKey

      -- Get SKU info
      SET @cBrand = ''
      SELECT @cBrand = ISNULL( Long, '')
      FROM CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'ITEMCLASS' 
         AND StorerKey = @cStorerKey 
         AND Code = @cSignatory
/*
      IF @cBrand = 'CPD'
      BEGIN
         SET @cSuggLOC = @cLottable09

         SELECT @cSuggID = ID
         FROM LOTxLOCxID WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey 
            AND SKU = @cSKU 
            AND LOC = @cSuggLOC
            
         GOTO Quit
      END
*/
      -- Get ReceiptDetail info
      SELECT 
         @nQTYExpected = ISNULL( SUM( QTYExpected), 0), 
         @nBeforeReceivedQTY = ISNULL( SUM( BeforeReceivedQTY), 0) 
      FROM ReceiptDetail WITH (NOLOCK) 
      WHERE ReceiptKey = @cReceiptKey 
         AND SKU = @cSKU
      
      -- Calc excess stock
      IF @nQTYExpected < (@nBeforeReceivedQTY + @nQTY)
      BEGIN
         IF @nQTYExpected > @nBeforeReceivedQTY
            SET @nActQTY = @nQTYExpected - @nBeforeReceivedQTY
         ELSE
            SET @nActQTY = 0
         
         SET @nExcessQTY = @nQTY - @nActQTY
      END
      ELSE
      BEGIN 
         SET @nActQTY = @nQTY
         SET @nExcessQTY = 0
      END

      IF @cSuggID = ''
      BEGIN
         -- Excess stock
         IF @nExcessQTY > 0
         BEGIN
            -- Get the excess PO
            DECLARE @cExcessPOKey NVARCHAR(10)
            SET @cExcessPOKey = ''
            SELECT TOP 1 @cExcessPOKey = POKey FROM PO WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND POGroup = @cReceiptKey
            
            -- Create the excess PO
            IF @cExcessPOKey = ''
            BEGIN
               -- Get new TaskDetailKeys    
               DECLARE @bSuccess INT
            	SET @bSuccess = 1
            	EXECUTE dbo.nspg_getkey
            		'PO'
            		, 10
            		, @cExcessPOKey OUTPUT
            		, @bSuccess     OUTPUT
            		, @nErrNo       OUTPUT
            		, @cErrMsg      OUTPUT
               IF @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 105404
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
                  GOTO Quit
               END
               
               -- Insert excess PO
               INSERT INTO PO (POKey, ExternPOKey, StorerKey, PODate, OtherReference, Status, POType, SellerName, POGroup, Userdefine01, SellerCompany, SellerAddress1)
               SELECT @cExcessPOKey, ExternReceiptKey, @cStorerKey, ReceiptDate, WarehouseReference, '0', 'P', Carrierkey, Receiptkey, Signatory, CarrierName, CarrierAddress1
               FROM Receipt WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 105405
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PO Fail
                  GOTO Quit
               END
            END

            /*
               ToID format:
                  V + L06 + ReceiptKey + Case# 
                  V = excess stock
                  
               L06 is 1 CHAR:
                  Q = not yet process
                  U = processed
                  B = damage
            */
            
            DECLARE @cExcessSuggID NVARCHAR(18)
            DECLARE @cExcessSuggLOC NVARCHAR(10)

            -- Get last ToID of that L06
            SET @cExcessSuggID = ''
            SELECT TOP 1 
               @cExcessSuggID = ToID 
            FROM PODetail WITH (NOLOCK) 
            WHERE POKey = @cExcessPOKey 
               AND Lottable06 = @cLottable06
               AND ToID <> ''
            ORDER BY RIGHT( '0' + SUBSTRING( ToID, 1 + LEN( @cLottable06) + LEN( @cReceiptKey) + 1 , 2), 2) DESC
            
            IF @cExcessSuggID = ''
               SET @cExcessSuggID = 'V' + @cLottable06 + @cReceiptKey + '1'

            SET @cExcessSuggLOC = 'A1QCV'
            
            -- Prompt excess stock
            DECLARE @cMsg1 NVARCHAR(20)
            DECLARE @cMsg2 NVARCHAR(20)
            DECLARE @cMsg3 NVARCHAR(20)
            
            SET @cMsg1 = rdt.rdtgetmessage( 105401, @cLangCode, 'DSP') --EXCESS STOCK:
            SET @cMsg1 = RTRIM( @cMsg1) + CAST( @nExcessQTY AS NVARCHAR(5))
            SET @cMsg2 = rdt.rdtgetmessage( 105402, @cLangCode, 'DSP') --TO ID:
            SET @cMsg3 = rdt.rdtgetmessage( 105403, @cLangCode, 'DSP') --TO LOC:
            
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
               @cMsg1, 
               '', 
               @cMsg2, 
               @cExcessSuggID, 
               '', 
               @cMsg3, 
               @cExcessSuggLOC
         END

         /*
            ToID format:
               L06 + ReceiptKey + Case# 
               
            L06 is 1 CHAR:
               U = Good stock
               Q = Second grade
               B = Bad stock
               EP = need to repackage, re-label
               L = need to take out label
         */
         
         -- Get last ToID of that L06
         SELECT TOP 1 
            @cSuggID = ToID 
         FROM ReceiptDetail WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptKey 
            AND Lottable06 = @cLottable06
            AND ToID <> ''
         ORDER BY RIGHT( '0' + SUBSTRING( ToID, LEN( @cLottable06) + LEN( @cReceiptKey) + 1 , 2), 2) DESC
         
         IF @cSuggID = ''
            SET @cSuggID = @cLottable06 + @cReceiptKey + '1'
      END
      
      IF @cSuggLOC = ''
      BEGIN
         /*
         -- Get SKU putaway before
         IF EXISTS( SELECT 1 FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND RECType = 'GRNB')
            SET @cSuggLOC = 'A1QC2'
         
         ELSE IF @cLottable06 = 'L'
            SET @cSuggLOC = 'A1QC4'
            
         ELSE 
         BEGIN
            -- Get item class
            DECLARE @cItemClass NVARCHAR( 10) 
            SELECT @cItemClass = ItemClass FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
            
            IF EXISTS( SELECT 1 FROM CodeLKUP WHERE ListName = 'ITEMCLASS' AND Code = @cItemClass AND StorerKey = @cStorerKey AND Long = 'LPD')
               SET @cSuggLOC = 'A1QC3'
            ELSE
               SET @cSuggLOC = 'A1QC1'
         END
         */

         -- (james01)
         SELECT @cItemClass = ItemClass 
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
         AND   SKU = @cSKU

         SELECT @cSuggLOC = Short 
         FROM dbo.CODELKUP WITH (NOLOCK) 
         WHERE ListName = 'LORRTN' 
         AND   Code = @cRECType
         AND   Storerkey = @cStorerKey
         AND   Code2 = @cLottable06
         
         IF ISNULL( @cSuggLOC, '') = ''
            SELECT @cSuggLOC = Short 
            FROM dbo.CODELKUP WITH (NOLOCK) 
            WHERE ListName = 'LORRTN' 
            AND   Code = @cLottable06
            AND   Storerkey = @cStorerKey

         IF ISNULL( @cSuggLOC, '') = ''
         BEGIN
            IF EXISTS ( SELECT 1
            FROM dbo.CODELKUP WITH (NOLOCK) 
            WHERE ListName = 'ITEMCLASS' 
            AND   Code = @cItemClass
            AND   Long = 'LPD'
            AND   Storerkey = @cStorerKey)
            BEGIN
               SELECT @cSuggLOC = Short 
               FROM dbo.CODELKUP WITH (NOLOCK) 
               WHERE ListName = 'LORRTN' 
               AND   Code = 'LPD'
               AND   Storerkey = @cStorerKey
            END
         END
         
         IF ISNULL( @cSuggLOC, '') = ''
            SELECT @cSuggLOC = Short 
            FROM dbo.CODELKUP WITH (NOLOCK) 
            WHERE ListName = 'LORRTN' 
            AND   Code = 'RTN'
            AND   Storerkey = @cStorerKey
      END
   END
   
Quit:

END

SET QUOTED_IDENTIFIER OFF


GO