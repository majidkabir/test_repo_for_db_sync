SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/************************************************************************/  
/* Store procedure: rdt_839DecodeIDSP01                                 */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Date       Rev Author      Purposes                                  */  
/* 20-08-2020 1.0 YeeKung     WMS-14630 Created                         */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_839DecodeIDSP01] (  

   @nMobile      INT,            
   @nFunc        INT,            
   @cLangCode    NVARCHAR( 3),   
   @nStep        INT,            
   @nInputKey    INT,            
   @cFacility    NVARCHAR( 5),   
   @cStorerKey   NVARCHAR( 15),  
   @cPickSlipNo  NVARCHAR( 20),  
   @cPickZone    NVARCHAR( 15), 
   @cDefaultQTY  NVARCHAR(  1)  OUTPUT,  
   @cCartonID    NVARCHAR( 20)  OUTPUT,
   @cSuggSKU     NVARCHAR( 20)  OUTPUT,
   @cSKUDescr    NVARCHAR( 60)  OUTPUT,
   @nSuggQTY     INT            OUTPUT,
   @cDefaultSKU  NVARCHAR(  1)  OUTPUT,
   @cSuggID      NVARCHAR( 20)  OUTPUT,
   @cSuggLoc     NVARCHAR(20)   OUTPUT,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cPrefix NVARCHAR(1)
   DECLARE @cOrderKey   NVARCHAR( 10)    
   DECLARE @cLoadKey    NVARCHAR( 10)    
   DECLARE @cZone       NVARCHAR( 18)        
   DECLARE @cCurrLogicalLOC    NVARCHAR( 18)    
   DECLARE @cCurrLOC           NVARCHAR( 10)    
   DECLARE @cPickConfirmStatus NVARCHAR( 1)    

   SET @cDefaultQTY = rdt.rdtGetConfig( @nFunc, 'DefaultQTY', @cStorerKey)

   IF (SUBSTRING(@cCartonID, 1, 1)='F')
   BEGIN
      SET @cPrefix =SUBSTRING(@cCartonID, 1, 1)
      SET @cCartonID=SUBSTRING(@cCartonID, 2, len(@cCartonID)-1)
      SET @cDefaultSKU='1'
   END

   IF (@cCartonID='99')
   BEGIN
      UPDATE RDT.RDTMOBREC WITH (ROWLOCK)
      SET O_Field12='ID      : ' + @cSuggID
      where mobile=@nMobile
   END

   IF ISNULL(@cDefaultQTY,'')=0 
   BEGIN
      IF @cPrefix='F'
         SET @cDefaultQTY='1'
   END

   IF EXISTS (SELECT 1 from LOTxLOCxID (NOLOCK)
               where sku=@cSuggSKU
                  AND id=@cSuggID
                  and loc=@cSuggLoc
                  and qty<>@nSuggQTY
                  and qty<>0) and @cPrefix='F'
   BEGIN
      SET @nErrNo = 157601
      SET @cErrMsg =rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
      GOTO QUIT
   END

Quit:  
  
END  

GO