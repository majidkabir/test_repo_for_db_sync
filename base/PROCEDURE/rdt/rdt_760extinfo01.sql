SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_760ExtInfo01                                    */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2016-08-09  1.0  ChewKP   SOS#372470 Created                         */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_760ExtInfo01] (  
   @nMobile        INT,                
   @nFunc          INT,                
   @cLangCode      NVARCHAR(3),        
   @nStep          INT,                
   @cUserName      NVARCHAR( 18),       
   @cFacility      NVARCHAR( 5),        
   @cStorerKey     NVARCHAR( 15),       
   @cDropID        NVARCHAR( 20),       
   @cSKU           NVARCHAR( 20),       
   @nQty           INT,                 
   @cLabelNo       NVARCHAR( 20),       
   @cPTSLogKey     NVARCHAR( 20),       
   @cShort         NVARCHAR(1),
   @coFieled01     NVARCHAR(20) OUTPUT,     
   @coFieled02     NVARCHAR(20) OUTPUT,   
   @nErrNo         INT OUTPUT,   
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   
   DECLARE @cPTSPosition NVARCHAR(20)   
          

   SET @nErrNo                = 0  
   SET @cErrMsg               = '' 
   SET @coFieled01            = ''
   SET @coFieled02            = ''
   
 
   
   IF @nFunc = 760
   BEGIN
      
      IF @nStep = 3 
      BEGIN
         
         SELECT @cPTSPosition = PTSPosition 
         FROM rdt.rdtPTSLog  WITH (NOLOCK) 
         WHERE PTSLogKey = @cPTSLogKey
         
         SET @coFieled01 = 'POSITION:'
         SET @coFieled02 = @cPTSPosition
         
         
      END
  END


END  




GO