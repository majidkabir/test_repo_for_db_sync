SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_598ToLOCLKUP01                                  */
/* Purpose: Validate carton type                                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-03-19 1.0  James      WMS-12559 Created                         */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_598ToLOCLKUP01] (  
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5),
   @cStorerKey   NVARCHAR( 15),
   @cRefNo       NVARCHAR( 20),
   @cColumnName  NVARCHAR( 20),
   @cLOC         NVARCHAR( 10),
   @cID          NVARCHAR( 18),
   @cSKU         NVARCHAR( 20),
   @nQTY         INT,          
   @cReceiptKey  NVARCHAR( 10),
   @cReceiptLineNumber NVARCHAR( 10),
   @tDefaultToLOC      VARIABLETABLE READONLY,
   @cDefaultToLOC      NVARCHAR( 10)  OUTPUT, 
   @nErrNo             INT            OUTPUT, 
   @cErrMsg            NVARCHAR( 20)  OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT @cDefaultToLOC = CLK.UDF03 
   FROM dbo.CODELKUP CLK WITH (NOLOCK) 
   WHERE CLK.LISTNAME = 'PLATFORM'
   AND   CLK.Storerkey = @cStorerKey
   AND   EXISTS ( SELECT 1 FROM dbo.RECEIPT R WITH (NOLOCK) 
                  JOIN rdt.rdtConReceiveLog C WITH (NOLOCK) 
                     ON ( R.ReceiptKey = C.ReceiptKey)
                  WHERE CLK.Storerkey = R.StorerKey 
                  AND   CLK.Code = R.ReceiptGroup
                  AND   C.Mobile = @nMobile)

GO