SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_534DecodeSP01                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2018-03-07 1.0  ChewKP     WMS-4190. Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_534DecodeSP01] (
   @nMobile      INT                   
  ,@nFunc        INT                     
  ,@nStep        INT                     
  ,@nInputKey    INT                     
  ,@cLangCode    NVARCHAR( 3)            
  ,@cStorerKey   NVARCHAR( 15)           
  ,@cFacility    NVARCHAR( 5)            
  ,@cFromLoc     NVARCHAR( 10)           
  ,@cToID        NVARCHAR( 18)           
  ,@cBarcode     NVARCHAR( 20)           
  ,@cUPC         NVARCHAR( 20) OUTPUT    
  ,@nQTY         INT           OUTPUT    
  ,@nErrNo       INT           OUTPUT    
  ,@cErrMsg      NVARCHAR( 20) OUTPUT    
)
AS
BEGIN      
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_success     INT

   IF @nFunc = 534
   BEGIN
      IF @nStep = 3
      BEGIN
         IF @nInputKey = 1 
         BEGIN
            
            

            IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK) 
                        WHERE StorerKey = @cStorerKey
                        AND UCCNo = @cBarcode
                        AND Status = '1' )
            BEGIN
               

               SELECT   @cUPC = SKU
                       ,@nQTY = SUM(Qty)
               FROM dbo.UCC WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND UCCNo = @cBarcode
               AND Status = '1'
               Group By SKU 

               
               
            END
            ELSE
            BEGIN
               SET @cUPC = @cBarcode
               SET @nQTY = 1 
            END
            
            IF EXISTS ( SELECT 1 FROM rdt.rdtMoveToIDLog WITH (NOLOCK) 
                        WHERE StorerKey = @cStorerKey
                        AND ToID = @cToID ) 
            BEGIN
                
                
                EXEC [RDT].[rdt_GETSKU]
                   @cStorerKey  = @cStorerKey
                  ,@cSKU        = @cUPC          OUTPUT
                  ,@bSuccess    = @b_Success     OUTPUT
                  ,@nErr        = @nErrNo        OUTPUT
                  ,@cErrMsg     = @cErrMsg       OUTPUT
               
               IF @nErrNo <> 0
               BEGIN
                  SET @nErrNo = 121351
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidSKU
                  GOTO Quit
               END   
               
               IF NOT EXISTS ( SELECT 1 FROM rdt.rdtMoveToIDLog WITH (NOLOCK) 
                               WHERE StorerKey = @cStorerKey
                               AND ToID = @cToID
                               AND SKU = @cUPC  )
               BEGIN
                  SET @nErrNo = 121352
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMixSKUInPallet
                  GOTO QUIT
               END
               
               
            END
            
            
         END
      END
      
      
   END
     
   GOTO Quit

Quit:         

END
      

GO