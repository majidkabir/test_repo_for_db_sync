SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_839ExtValidSP06                                 */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2021-06-21 1.0  Chermaine  WMS-17261. Created                        */
/* 2022-04-20 1.1  YeeKung    WMS-19311 Add Data capture (yeekung01)    */
/************************************************************************/  
CREATE   PROC [RDT].[rdt_839ExtValidSP06] (  
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5) , 
   @cStorerKey   NVARCHAR( 15), 
   @cType        NVARCHAR( 10), 
   @cPickSlipNo  NVARCHAR( 10), 
   @cPickZone    NVARCHAR( 1),  
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
   DECLARE @cUserName      NVARCHAR( 18)
  
   SET @nErrNo          = 0
   SET @cErrMSG         = ''
   
   IF @nStep = 2 --DropID
   BEGIN
      IF @nInputKey = 1 --ENTER
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                     WHERE DropID = @cDropID
                     AND   storerKey = @cStorerKey)
         BEGIN
            SET @nErrNo = 169451
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Dup DropID
            GOTO QUIT
         END
      END
   END
END
  
QUIT:  


GO