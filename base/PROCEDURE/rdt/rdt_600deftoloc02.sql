SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_600DefToLoc02                                       */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2023-05-25  YeeKung    1.0  WMS-22596 Created                              */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_600DefToLoc02] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cFacility       NVARCHAR( 5),
   @cStorerKey      NVARCHAR( 15),
   @cReceiptKey     NVARCHAR( 10),
   @cPOKey          NVARCHAR( 10),
   @cDefaultToLOC   NVARCHAR( 10)  OUTPUT,
   @nErrNo          INT            OUTPUT,
   @cErrMsg         NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cRECTYPE NVARCHAR(20)

   IF @nFunc = 600 -- Normal receiving
   BEGIN
      IF @nInputKey = '1'
      BEGIN
         SELECT  @cRECTYPE =  RECTYPE
         FROM RECEIPT (NOLOCK)
         WHERE Receiptkey = @cReceiptKey
            AND Storerkey = @cStorerKey

         SELECT @cDefaultToLOC = Udf03
         FROM CODELKUP (NOLOCK)
         WHERE Listname = 'RECTYPE'
            AND Storerkey = @cStorerKey
            AND CODE = @cRECTYPE
      END
   END

Quit:

END

GO