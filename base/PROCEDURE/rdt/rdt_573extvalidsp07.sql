SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_573ExtValidSP07                                 */
/* Purpose: Validate  UCC                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-06-19 1.0  YeeKung    WMS-22768  Created                        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_573ExtValidSP07] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR(3),
   @nStep       INT,
   @cStorerKey  NVARCHAR(15),
   @cFacility   NVARCHAR(5),
   @cReceiptKey1 NVARCHAR(20),
   @cReceiptKey2 NVARCHAR(20),
   @cReceiptKey3 NVARCHAR(20),
   @cReceiptKey4 NVARCHAR(20),
   @cReceiptKey5 NVARCHAR(20),
   @cLoc        NVARCHAR(20),
   @cID         NVARCHAR(18),
   @cUCC        NVARCHAR(20),
   @nErrNo      INT  OUTPUT,
   @cErrMsg     NVARCHAR(1024) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nInputKey  INT
   DECLARE @cPO        NVARCHAR( 18) = ''
   DECLARE @cUCC_PO    NVARCHAR( 18) = ''

   SET @nErrNo = 0

   SELECT @nInputKey = InputKey
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nStep = 1
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF  EXISTS ( SELECT 1 FROM RECEIPT R WITH (NOLOCK)
                         JOIN rdt.rdtConReceiveLog CRL WITH (NOLOCK) ON ( R.ReceiptKey = CRL.ReceiptKey)
                         WHERE R.RECType = 'UARESERVED'
                         AND   CRL.Mobile = @nMobile)
         BEGIN
            DECLARE  @cLine01 NVARCHAR(20),
                     @cLine02 NVARCHAR(20),
                     @cLine03 NVARCHAR(20)

            SELECT TOP 1 @cReceiptKey1 =R.receiptkey  
            FROM RECEIPT R WITH (NOLOCK)
            JOIN rdt.rdtConReceiveLog CRL WITH (NOLOCK) ON ( R.ReceiptKey = CRL.ReceiptKey)
            WHERE R.RECType = 'UARESERVED'
            AND   CRL.Mobile = @nMobile

            SET @cLine01 = 'ASN' +@cReceiptKey1
            SET @cLine02 = 'IS PTO'
            SET @cLine03 = 'Please double check'

            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,      
            @cLine01, @cLine02, @cLine03,'',     
            '', '', '', '', '',      
            '', '', '','',''      
            SET @nErrNo = 0   
         END
      END
   END

QUIT:

GO