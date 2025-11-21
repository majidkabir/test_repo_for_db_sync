SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_605Extinfo01                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2020-07-29  1.0  YeeKung     WMS-14414 Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_605Extinfo01] (
   @nMobile      INT,          
   @nFunc        INT,          
   @cLangCode    NVARCHAR( 3), 
   @nStep        INT,          
   @nInputKey    INT,          
   @cFacility    NVARCHAR( 5), 
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cRefNo       NVARCHAR( 20),
   @cID          NVARCHAR( 18),
   @nCurrentScanned INT,       
   @cExtendedInfo NVARCHAR(20) OUTPUT 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTotalID INT


   select @nCurrentScanned=COUNT(Distinct toID)
   FROM receiptdetail (Nolock)
   where ExternReceiptkey=@cRefNo
   and beforereceivedqty<>0

   SELECT @nTotalID=COUNT(Distinct toID)
   FROM receiptdetail (Nolock)
   where ExternReceiptkey=@cRefNo

   SET @cExtendedInfo='No ID:'+ CAST(@nCurrentScanned AS NVARCHAR(5))+'/'+CAST(@nTotalID AS NVARCHAR(5))

END
Quit:    

GO