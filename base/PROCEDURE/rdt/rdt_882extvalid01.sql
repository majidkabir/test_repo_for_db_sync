SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_882ExtValid01                                   */
/*                                                                      */
/* Purpose: Get UCC stat                                                */
/*                                                                      */
/* Called from: rdtfnc_ModifyUCCData                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2020-05-04  1.0  James      WMS13409. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_882ExtValid01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15), 
   @cPalletID      NVARCHAR( 20), 
   @cUCC           NVARCHAR( 20), 
   @cLOT           NVARCHAR( 10), 
   @cLOC           NVARCHAR( 10), 
   @cID            NVARCHAR( 18), 
   @cSKU           NVARCHAR( 20), 
   @nQty           INT,           
   @cStatus        NVARCHAR( 1),                 
   @tExtValidVar   VariableTable READONLY,  
   @nErrNo         INT           OUTPUT,   
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nStep = 1
   BEGIN
      IF @nInputKey = 1
      BEGIN      
         SELECT @cID = ID
         FROM RDT.rdtPreReceiveSort WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   UCCNo = @cUCC
         AND   [Status] = '1'
                         
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 151651
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Not Sorted
            GOTO Quit
         END

         IF ISNULL( @cPalletID, '') <> '' AND @cPalletID <> @cID
         BEGIN
            SET @nErrNo = 151652
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCC Not On ID'
            GOTO Quit  
         END
      END
   END
   
   Quit:

GO