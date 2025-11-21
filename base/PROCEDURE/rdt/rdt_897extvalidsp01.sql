SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_897ExtValidSP01                                       */
/* Purpose: Validate UCC                                                      */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2017-07-17 1.0  ChewKP   WMS-1992 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_897ExtValidSP01] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15), 
   @cDropID          NVARCHAR( 20), 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON      
SET QUOTED_IDENTIFIER OFF      
SET ANSI_NULLS OFF      
SET CONCAT_NULL_YIELDS_NULL OFF  


IF @nFunc = 897
BEGIN
   
   DECLARE @cReceiptKey NVARCHAR(10) 
          ,@cPOKey      NVARCHAR(10) 
          ,@cExternPOKey NVARCHAR(20)
          


   SET @nErrNo = 0

   IF @nStep = 1 -- From  id
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         
         IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK) 
                         WHERE StorerKey = @cStorerKey
                         AND UCCNo = @cDropID
                         AND Status = '0' ) 
         BEGIN
            SET @nErrNo = 115701
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UCCNotExist
            GOTO Quit  
         END
         
         SELECT TOP 1 @cExternPOKey = SourceKey 
         FROM dbo.UCC WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND UCCNo = @cDropID
         AND Status = '0'

         
         
         IF ISNULL(@cExternPOKey, '' ) = '' 
         BEGIN
            SET @nErrNo = 115703
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- POKeyNotSetup
            GOTO Quit 
         END
         
         
         
         IF NOT EXISTS ( SELECT 1 FROM dbo.Receipt WITH (NOLOCK) 
                         WHERE StorerKey = @cStorerKey
                         AND ExternReceiptKey = @cExternPOKey
                         AND Status < '9'  )
         BEGIN
            SET @nErrNo = 115702
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ANSNotExist
            GOTO Quit               
         END
      END
   END

   
END

Quit:





GO