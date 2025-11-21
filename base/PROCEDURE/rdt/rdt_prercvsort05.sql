SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
/* Store procedure: rdt_PreRcvSort05                                                   */
/* Copyright      : LFLogistics                                                        */
/*                                                                                     */
/* Date        Rev  Author     Purposes                                                */
/* 2018-07-16  1.0  Ung        WMS-5728 Created                                        */
/***************************************************************************************/

CREATE PROC [RDT].[rdt_PreRcvSort05] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3),
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cParam1          NVARCHAR( 20),
   @cParam2          NVARCHAR( 20),
   @cParam3          NVARCHAR( 20),
   @cParam4          NVARCHAR( 20),
   @cParam5          NVARCHAR( 20),
   @cUCCNo           NVARCHAR( 20),  
   @cPosition01      NVARCHAR( 20)  OUTPUT,   
   @cPosition02      NVARCHAR( 20)  OUTPUT,   
   @cPosition03      NVARCHAR( 20)  OUTPUT,   
   @cPosition04      NVARCHAR( 20)  OUTPUT,   
   @cPosition05      NVARCHAR( 20)  OUTPUT,   
   @cPosition06      NVARCHAR( 20)  OUTPUT,   
   @cPosition07      NVARCHAR( 20)  OUTPUT,   
   @cPosition08      NVARCHAR( 20)  OUTPUT,   
   @cPosition09      NVARCHAR( 20)  OUTPUT,   
   @cPosition10      NVARCHAR( 20)  OUTPUT,   
   @nErrNo           INT            OUTPUT, 
   @cErrMsg          NVARCHAR( 20)  OUTPUT 
)
AS
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cReceiptKey NVARCHAR(10)
   DECLARE @cRDLineNo NVARCHAR(5)
   DECLARE @cSKU NVARCHAR(20)
   DECLARE @cUDF05 NVARCHAR(30)
   DECLARE @cToID NVARCHAR(18)

   SET @cReceiptKey = @cParam1
   SET @cSKU = @cUCCNo

   -- Get line with balance
   SET @cRDLineNo = ''
   SET @cUDF05 = ''
   SELECT 
      @cRDLineNo = ReceiptLineNumber, 
      @cUDF05 = UserDefine05, -- Carton No
      @cToID = TOID           -- Carton ID
   FROM ReceiptDetail WITH (NOLOCK)
   WHERE Receiptkey = @cReceiptKey
      AND StorerKey = @cStorerKey
      AND SKU = @cSKU
      AND QTYExpected > BeforeReceivedQTY
   ORDER BY ReceiptLineNumber   
   
   IF @cRDLineNo <> ''
   BEGIN
      -- Show carton no
      SET @cPosition01 = 'CARTON NO: '  
      SET @cPosition02 = LEFT( @cUDF05, 5)
      
      DECLARE @cConfirmPosition NVARCHAR(1)
      SET @cConfirmPosition = rdt.RDTGetConfig( @nFunc, 'ConfirmPosition', @cStorerKey)      
      IF @cConfirmPosition <> '0'
      BEGIN
         -- Get carton ID of the carton
         IF @cToID = ''
            SELECT TOP 1 
               @cToID = TOID
            FROM ReceiptDetail WITH (NOLOCK)
            WHERE Receiptkey = @cReceiptKey
               AND StorerKey = @cStorerKey
               AND UserDefine05 = @cUDF05 -- Carton No
               AND @cToID <> ''           -- Carton ID
         
         SET @cPosition09 = @cToID
      END
   END

GO