SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_598AutoGenID01                                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Auto generate ID                                            */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 2017-06-14  1.0  Ung       WMS-2231 Created                          */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_598AutoGenID01]
   @nMobile     INT, 
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3), 
   @nStep       INT, 
   @nInputKey   INT, 
   @cFacility   NVARCHAR(5),
   @cStorerKey  NVARCHAR(15),
   @cAutoGenID  NVARCHAR(20),
   @cRefNo      NVARCHAR(20), 
   @cColumnName NVARCHAR(20), 
   @cLOC        NVARCHAR(10),
   @cID         NVARCHAR(18), 
   @cAutoID     NVARCHAR(18)  OUTPUT,   
   @nErrNo      INT           OUTPUT, 
   @cErrMsg     NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @cAutoID = ''

   DECLARE @b_success INT
   SET @b_success = 0
   EXECUTE dbo.nspg_GetKey
      'ID',
      10 ,
      @cAutoID    OUTPUT,
      @b_success  OUTPUT,
      @nErrNo     OUTPUT,
      @cErrMsg    OUTPUT
   IF @b_success <> 1
   BEGIN
      SET @nErrNo = 107401
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetAutoID Fail
      GOTO Fail
   END

   -- Get SKU info
   DECLARE @cBUSR10 NVARCHAR(30)
   SELECT TOP 1 
      @cBUSR10 = SKU.BUSR10
   FROM dbo.ReceiptDetail RD WITH (NOLOCK)
      JOIN rdt.rdtConReceiveLog CRL WITH (NOLOCK) ON (RD.ReceiptKey = CRL.ReceiptKey)
      JOIN SKU WITH (NOLOCK) ON (RD.StorerKey = SKU.StorerKey AND RD.SKU = SKU.SKU)
   WHERE Mobile = @nMobile

   SET @cAutoID = LEFT( @cBUSR10, 1) + @cAutoID

Fail:
END


GO