SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_573ExtInfo04                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Display total scanned UCC on pallet                         */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2023-08-11 1.0  yeekung     WMS-23108. Created                       */
/************************************************************************/

CREATE   PROC [RDT].[rdt_573ExtInfo04] (
   @nMobile           INT,
   @nFunc             INT,
   @cLangCode         NVARCHAR( 3),
   @nStep             INT,
   @nInputKey         INT,
   @cFacility         NVARCHAR( 5),
   @cStorerKey        NVARCHAR( 15),
   @cLoc              NVARCHAR( 10),
   @cID               NVARCHAR( 18),
   @cUCC              NVARCHAR( 20),
   @tExtInfoVar       VariableTable READONLY,
   @cExtendedInfo     NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nScanUCC    INT
   DECLARE @cUserdefine01  NVARCHAR(20)
   DECLARE @cReceiptkey1 NVARCHAR(20)
   DECLARE @cReceiptkey2 NVARCHAR(20)
   DECLARE @cReceiptkey3 NVARCHAR(20)
   DECLARE @cReceiptkey4 NVARCHAR(20)
   DECLARE @cReceiptkey5 NVARCHAR(20)

   IF @nStep IN ( 3, 4)
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SELECT @nScanUCC = COUNT( DISTINCT IsNull( RTRIM(RD.UserDefine01), ''))
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
         WHERE CR.Mobile = @nMobile
         AND   RD.BeforeReceivedQty > 0 -- Received
         AND   RD.ToId = @cID

         SET @cExtendedInfo = 'UCC Scanned: ' + CAST( @nScanUCC AS NVARCHAR( 5))
      END

   END
   IF @nStep IN (  4)
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SELECT   @cReceiptkey1 = V_String1,
                  @cReceiptkey2 = V_String2,
                  @cReceiptkey3 = V_String3,
                  @cReceiptkey4 = V_String4,
                  @cReceiptkey5 = V_String5
         FROM rdt.rdtmobrec (NOLOCK)
         Where Mobile = @nMobile

         SELECT @cUserdefine01 = R.userdefine01
         FROM Receipt R (nolock) 
         JOIN Receiptdetail RD (Nolock) ON R.Receiptkey= RD.Receiptkey
         Where RD.receiptkey IN (@cReceiptkey1,@cReceiptkey2,@cReceiptkey3,@cReceiptkey4,@cReceiptkey5)
            AND RD.Storerkey = @cStorerkey
            AND RD.userdefine01 = @cUCC

         IF EXISTS(SELECT 1
                     FROM dbo.codelkup (NOLOCK)
                     WHERE listname= '573ADDLGC'
                     AND   long ='VAS'
                     AND   code = @cUserdefine01
                     AND   Storerkey = @cStorerkey)
         BEGIN
            DECLARE @cErrMsg NVARCHAR(20),
                    @cErrMsg1 NVARCHAR(20),
                    @cErrMsg2 NVARCHAR(20)

            SET @cErrMsg1 = 'Please Setup'
            SET @cErrMsg2 = 'VAS'
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, @cErrMsg, @cErrMsg1,@cErrMsg2
         END
      END

   END

Quit:

END

GO