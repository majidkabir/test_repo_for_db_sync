SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_841ExtInfoSP01                                  */    
/* Purpose:                                                             */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author     Purposes                                  */    
/* 2020-05-21 1.0  YeeKung    WMS-13131. Created                        */ 
/* 2021-04-01 1.1  YeeKung    WMS-16718 Add serialno and serialqty       */
/*                            Params (yeekung02)                         */   
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_841ExtInfoSP01] (    
   @nMobile     INT,    
   @nFunc       INT,     
   @cLangCode   NVARCHAR(3),     
   @nStep       INT,     
   @cStorerKey  NVARCHAR(15),     
   @cDropID     NVARCHAR(20),    
   @cSKU        NVARCHAR(20),   
   @cPickSlipNo NVARCHAR(10),  
   @cLoadKey    NVARCHAR(20),  
   @cWavekey    NVARCHAR(20),  
   @nInputKey   INT,
   @cSerialNo   NVARCHAR( 30), 
   @nSerialQTY   INT,  
   @cExtendedinfo  NVARCHAR( 20) OUTPUT,   
   @nErrNo      INT       OUTPUT,     
   @cErrMsg     CHAR( 20) OUTPUT  
)    
AS    
  
SET NOCOUNT ON         
SET QUOTED_IDENTIFIER OFF         
SET ANSI_NULLS OFF        
SET CONCAT_NULL_YIELDS_NULL OFF     
  
   DECLARE @nTotalScannedQty      INT  
  
   IF @nStep = 2  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
  
         select @nTotalScannedQty = Count( pd.pickslipno) from pickdetail pd (nolock)   
         JOIN orders o(NOLOCK) ON (pd.orderkey=o.orderkey)  
         where pd.storerkey =@cStorerKey  
         and o.LoadKey = @cLoadKey   
         and pd.status in ('0','3')  
         AND pd.caseid=''  
  
         SET @cExtendedinfo = 'ScannedQty:'+CAST(@nTotalScannedQty AS NVARCHAR(4))  
      END  
   END  
  
    
QUIT:         
 

GO