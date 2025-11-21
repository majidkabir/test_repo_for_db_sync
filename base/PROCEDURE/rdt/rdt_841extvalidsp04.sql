SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_841ExtValidSP04                                 */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2020-05-21 1.0  YeeKung    WMS-13131. Created                        */
/* 2021-04-01 1.1  YeeKung    WMS-16718 Add serialno and serialqty      */
/*                            Params (yeekung02)                        */   
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_841ExtValidSP04] (  
   @nMobile     INT,  
   @nFunc       INT,   
   @cLangCode   NVARCHAR(3),   
   @nStep       INT,   
   @cStorerKey  NVARCHAR(15),   
   @cDropID     NVARCHAR(20),  
   @cSKU        NVARCHAR(20), 
   @cPickSlipNo NVARCHAR(10),
   @cSerialNo   NVARCHAR( 30), 
   @nSerialQTY  INT,   
   @nErrNo      INT       OUTPUT,   
   @cErrMsg     CHAR( 20) OUTPUT
)  
AS  

SET NOCOUNT ON       
SET QUOTED_IDENTIFIER OFF       
SET ANSI_NULLS OFF      
SET CONCAT_NULL_YIELDS_NULL OFF   

   DECLARE @nInputKey      INT
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @cCartonType NVARCHAR (20)
   
   SELECT @nInputKey = InputKey, 
          @cLoadKey = I_Field03,
          @cCartonType=V_string47
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nStep = 1
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF @cLoadKey <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)
                       JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)
                       WHERE PD.Storerkey = @cStorerKey
                       AND   O.LoadKey = @cLoadKey
                       AND   O.status IN ('CANC'))
            BEGIN            
               SET @nErrNo = 152951            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong ord type            
               GOTO QUIT              
            END
         END
      END
   END
   IF @nStep = 7
   BEGIN
      IF ISNULL(@cCartonType,'')=''
      BEGIN            
         SET @nErrNo = 152952            
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong ord type            
         GOTO QUIT              
      END
   END
  
QUIT:  

 

GO