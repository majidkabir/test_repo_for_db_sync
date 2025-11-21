SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_839ExtValidSP10                                 */  
/* Purpose: Validate option                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2021-12-20 1.0  James      WMS-18004. Created                        */
/* 2023-04-17 1.1  James      Add PackData1~3 param (james01)           */
/************************************************************************/  
CREATE   PROC [RDT].[rdt_839ExtValidSP07] (  
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5) , 
   @cStorerKey   NVARCHAR( 15), 
   @cType        NVARCHAR( 10), 
   @cPickSlipNo  NVARCHAR( 10), 
   @cPickZone    NVARCHAR( 10),  
   @cDropID      NVARCHAR( 20), 
   @cLOC         NVARCHAR( 10), 
   @cSKU         NVARCHAR( 20), 
   @nQTY         INT, 
   @cPackData1   NVARCHAR( 30),
   @cPackData2   NVARCHAR( 30),
   @cPackData3   NVARCHAR( 30),                 
   @nErrNo       INT           OUTPUT, 
   @cErrMsg      NVARCHAR(250) OUTPUT  
)  
AS  

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF
  
IF @nFunc = 839  
BEGIN  
   DECLARE @cOption           NVARCHAR( 1)
          
   SET @nErrNo          = 0
   SET @cErrMSG         = ''

   IF @nStep = 5 
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SELECT @cOption = I_Field01 
         FROM rdt.RDTMOBREC WITH (NOLOCK)
         WHERE Mobile = @nMobile 
         
         IF @cOption = '1'   
         BEGIN  
            SET @nErrNo = 180201
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Cannot ShtPick'
            GOTO QUIT  
         END  

         IF @cOption = '4'   
         BEGIN  
            SET @nErrNo = 180202
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Cannot SkipLoc'
            GOTO QUIT  
         END  
      END
   END
END  
  
QUIT:  


GO