SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_600ExtVal19                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: Reject B2C type ASN           									   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2024-05-07 1.0  Dennis     UWP-19017 Created                         */
/************************************************************************/

CREATE   PROC rdt.rdt_600ExtVal19 (
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
   @cErrMsg      NVARCHAR( 20)  OUTPUT
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
   @SQL                  NVARCHAR( MAX),
   @cUserDefine08        NVARCHAR( 30),  
   @nSQLResult           INT,
   @nCheckDigit          INT,
   @cActLoc              NVARCHAR( 20),
   @cPalletTypeInUse     NVARCHAR( 5),
   @cPalletTypeSave      NVARCHAR( 10),
   @cLott10              NVARCHAR( 30),
   @dLotDate             DATETIME
   
   IF @nFunc = 600 -- Normal receiving
   BEGIN
      IF @nStep = 5
      BEGIN
      	IF @nInputKey = 1
      	BEGIN
      		   SET @cStorerConfig = ISNULL(rdt.RDTGetConfig( @nFunc, 'NoFutureDateLottable', @cStorerKey),'')
               IF @cStorerConfig != ''
               BEGIN
                  DECLARE LIST CURSOR FOR 
                  SELECT TRY_CAST(value AS INT) FROM STRING_SPLIT(@cStorerConfig, ',')
                  OPEN LIST
                  FETCH NEXT FROM LIST INTO @nLotNum
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     IF @nLotNum NOT IN (4,5,13,14,15)
                     BEGIN
                        GOTO CLOSELIST
                     END
                     SET @dLotDate = CASE
                                 WHEN @nLotNum = 4  THEN @dLottable04  WHEN @nLotNum = 5 THEN @dLottable05
                                 WHEN @nLotNum = 13 THEN @dLottable13 WHEN @nLotNum = 14 THEN @dLottable14
                                 WHEN @nLotNum = 15 THEN @dLottable15
                                 END 
                     SET @cLotValue = rdt.rdtFormatDate( @dLotDate)
                     IF ISNULL(@cLotValue,'') = '' OR (@cLotValue <> '' AND rdt.rdtIsValidDate( @cLotValue) = 0)
                     BEGIN
                        GOTO CLOSELIST
                     END
                     IF @dLotDate >= DATEADD(DAY, 0, DATEDIFF(DAY, -1, GETDATE()))
                     BEGIN
                        SET @nErrNo = 212607
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --212607DateRequiredToBeBeforeThanToday
                        GOTO CLOSELIST
                     END   
                     FETCH NEXT FROM LIST INTO @nLotNum
                  END
                  GOTO CLOSELIST
                  CLOSELIST:
                     CLOSE LIST
                     DEALLOCATE LIST
                     GOTO Quit
               END
      	END
      END
   END         



   Quit:


GO