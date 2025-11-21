SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_600ExtVal20                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: Disallow mix sku on one pallet                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2024-07-17 1.0  Dennis     FCR-232   Created                         */
/************************************************************************/

CREATE   PROC rdt.rdt_600ExtVal20(
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5), 
   @cStorerKey   NVARCHAR( 15), 
   @cReceiptKey  NVARCHAR( 10), 
   @cPOKey       NVARCHAR( 10), 
   @cLOC         NVARCHAR( 10), 
   @cID          NVARCHAR( 18), 
   @cSKU         NVARCHAR( 20), 
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
   @nQTY         INT,           
   @cReasonCode  NVARCHAR( 10), 
   @cSuggToLOC   NVARCHAR( 10), 
   @cFinalLOC    NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 10), 
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 50)  OUTPUT
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
   @nRowCount            INT,
   @cexternReceiptKey    NVARCHAR( 30), 
   @cexternLineNo        NVARCHAR( 30),    
   @nLotNum              INT,
   @cListName            NVARCHAR( 30),
   @cLotValue            NVARCHAR( 30),     
   @cStorerConfig        NVARCHAR( 50),  
   @cSQLHead             NVARCHAR( MAX),
   @cSQLBody             NVARCHAR( MAX),
   @cSQLFoot             NVARCHAR( MAX),
   @cSQL                 NVARCHAR( MAX),
   @cSQLParam            NVARCHAR( MAX),
   @cUserDefine08        NVARCHAR( 30),  
   @nSQLResult           INT,
   @nCheckDigit          INT,
   @cActLoc              NVARCHAR( 20),
   @cPalletTypeInUse     NVARCHAR( 5),
   @cPalletTypeSave      NVARCHAR( 10),
   @cLott10              NVARCHAR( 30),
   @dLotDate             DATETIME,
   @cColumn              NVARCHAR( 30),
   @cLastSku             NVARCHAR( 20)='',
   @cLastLot             NVARCHAR( 20)

   SET @cStorerConfig = ISNULL(rdt.RDTGetConfig( @nFunc, 'DisAllowMixPallet', @cStorerKey),'')
   SET @cSQLHead='SELECT TOP 1 @cLastLot = ISNULL(RD.'
   SET @cSQLBody = ','''')
               FROM dbo.Receipt R WITH (NOLOCK)
                  INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey  = RD.ReceiptKey
               WHERE R.Facility = @cFacility AND R.StorerKey = @cStorerKey
                  AND R.ReceiptKey = @cReceiptKey AND (@cPOKey=''NOPO'' or RD.POKey = @cPOKey)
                  AND RD.ToId = @cID AND RD.Sku = @cSKU 
               ORDER BY RD.ReceiptLineNumber
               IF @cLastLot <> ISNULL('
   SET @cSQLFoot = '
               ,'''')
               BEGIN
                  SET @nErrNo = 204703
                  SET @cErrMsg = rdt.rdtgetmessageLong( @nErrNo, ''ENG'', ''DSP'') 
               END
               '
   SET @cSQLParam =
               '@cFacility    NVARCHAR( 5),  ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cReceiptKey  NVARCHAR( 10), ' +
               '@cPOKey       NVARCHAR( 10), ' +
               '@cID          NVARCHAR( 18), ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@cLottable01  NVARCHAR( 18), ' +
               '@cLottable02  NVARCHAR( 18), ' +
               '@cLottable03  NVARCHAR( 18), ' +
               '@dLottable04  DATETIME,      ' +
               '@dLottable05  DATETIME,      ' +
               '@cLottable06  NVARCHAR( 30), ' +
               '@cLottable07  NVARCHAR( 30), ' +
               '@cLottable08  NVARCHAR( 30), ' +
               '@cLottable09  NVARCHAR( 30), ' +
               '@cLottable10  NVARCHAR( 30), ' +
               '@cLottable11  NVARCHAR( 30), ' +
               '@cLottable12  NVARCHAR( 30), ' +
               '@dLottable13  DATETIME,      ' +
               '@dLottable14  DATETIME,      ' +
               '@dLottable15  DATETIME,      ' +
               '@cLastLot     NVARCHAR( 20) OUTPUT,'+
               '@nErrNo       INT         OUTPUT, 
                @cErrMsg      NVARCHAR(20)  OUTPUT'

   IF @nFunc = 600 -- Normal receiving
   BEGIN
      IF @nStep = 4
      BEGIN
      	IF @nInputKey = 1
      	BEGIN
               IF @cStorerConfig != ''
               BEGIN
                  DECLARE LIST CURSOR FOR 
                  SELECT Code2 FROM codelkup (NOLOCK) WHERE Listname = @cStorerConfig 
                  AND Storerkey = @cStorerKey AND Code = '600'
                  OPEN LIST
                  FETCH NEXT FROM LIST INTO @cColumn
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     IF @cColumn = 'SKU'
                     BEGIN
                        SELECT TOP 1 @cLastSku = ISNULL(RD.Sku,'')
                        FROM dbo.Receipt R WITH (NOLOCK)
                           INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey  = RD.ReceiptKey
                        WHERE R.Facility = @cFacility AND R.StorerKey = @cStorerKey
                           AND R.ReceiptKey = @cReceiptKey AND (@cPOKey='NOPO' or RD.POKey = @cPOKey)
                           AND RD.ToId = @cID
                        ORDER BY RD.ReceiptLineNumber
                        
                        IF @cLastSku <> '' AND @cLastSku <> @cSKU
                        BEGIN
                           SET @nErrNo = 204702
                           SET @cErrMsg = rdt.rdtgetmessageLong( @nErrNo, @cLangCode, 'DSP') --Mix SKU Not Allowed
                           GOTO CLOSELIST
                        END
                        GOTO CLOSELIST
                     END
                     FETCH NEXT FROM LIST INTO @cColumn
                  END
                  GOTO CLOSELIST
               END
      	END
      END
   END         
   GOTO Quit
   CLOSELIST:
      CLOSE LIST
      DEALLOCATE LIST
      GOTO Quit

   Quit:


GO