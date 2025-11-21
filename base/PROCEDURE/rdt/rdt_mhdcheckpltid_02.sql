SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_MHDCheckPltID_02                                */
/* Purpose: Update DropID                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* To check if over receive by ASN + pallet id + SKU.                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-04-07 1.0  James      SOS305458.                                */
/* 2016-06-07 1.1  SPChin     IN00066678 - Revise Parameters            */
/************************************************************************/

CREATE PROC [RDT].[rdt_MHDCheckPltID_02] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,
   @nInputKey    INT,				--IN00066678	
   @cStorerKey   NVARCHAR( 15), 
   @cReceiptKey  NVARCHAR( 10), 
   @cPOKey       NVARCHAR( 10), 
   @cLOC         NVARCHAR( 10), 
   @cID          NVARCHAR( 18), 
   @cSKU         NVARCHAR( 20), 
   @nQty         INT,           
   @cLottable01  NVARCHAR(18),	--IN00066678
   @cLottable02  NVARCHAR(18),	--IN00066678
   @cLottable03  NVARCHAR(18),	--IN00066678
   @dLottable04  DATETIME,			--IN00066678
   --@nValid       INT            OUTPUT,	--IN00066678   
   @nErrNo       INT            OUTPUT,  
   @cErrMsg      NVARCHAR( 20)  OUTPUT
)
AS

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nQty_Received     INT, 
           @nQty_Expected     INT 

   -- Initialise var
   --SET @nValid = 1	--IN00066678
   
   IF @nStep = 5
   BEGIN
      -- If no pallet ID just ignore
      IF ISNULL( @cID, '') = '' 
         GOTO Quit

      SELECT @nQty_Received = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM dbo.ReceiptDetail WITH (NOLOCK) 
      WHERE ReceiptKey = @cReceiptKey
      AND   ToID = @cID
      AND   SKU = @cSKU
      AND   StorerKey = @cStorerKey
      AND   FinalizeFlag = 'N'

      SELECT @nQty_Expected = ISNULL( SUM( QtyExpected), 0)
      FROM dbo.ReceiptDetail WITH (NOLOCK) 
      WHERE ReceiptKey = @cReceiptKey
      AND   ToID = @cID
      AND   SKU = @cSKU
      AND   StorerKey = @cStorerKey
      AND   FinalizeFlag = 'N'

      IF @nQty_Received + @nQty > @nQty_Expected
      BEGIN
         SET @cErrMsg = 'OVER RECEIVED'
         --SET @nValid = 0	--IN00066678
         SET @nErrNo = 1	--IN00066678
         GOTO Quit
      END
      
   END
Quit:


GO