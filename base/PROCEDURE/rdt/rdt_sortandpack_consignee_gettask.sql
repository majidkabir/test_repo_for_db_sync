SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_SortAndPack_Consignee_GetTask                   */  
/* Copyright: IDS                                                       */  
/* Purpose: Get statistic                                               */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Ver  Author   Purposes                                    */  
/* 2020-11-05 1.0  Chermaine  WMS-15185 Created                         */   
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_SortAndPack_Consignee_GetTask]  
    @nMobile         INT  
   ,@nFunc           INT  
   ,@cLangCode       NVARCHAR(3)   
   ,@cUserName       NVARCHAR(18)  
   ,@cWaveKey        NVARCHAR(10)  
   ,@cBatchKeyIn     NVARCHAR(10)  
   ,@cStorerKey      NVARCHAR(15)  
   ,@cSKUIn          NVARCHAR(20)  
   ,@cUCCNo          NVARCHAR(20)  
   ,@cBatchKey       NVARCHAR(10) OUTPUT  
   ,@cLoadKey        NVARCHAR(10) OUTPUT  
   ,@cSKU            NVARCHAR(20) OUTPUT  
   ,@cConsigneeKey   NVARCHAR(15) OUTPUT  
   ,@cOrderKey       NVARCHAR(10) OUTPUT  
   ,@cPosition       NVARCHAR(10) OUTPUT  
   ,@cPalletID       NVARCHAR(20) OUTPUT  
   ,@cPackData       NVARCHAR( 1) OUTPUT  
   ,@nLoadQTY        INT          OUTPUT  
   ,@nErrNo          INT          OUTPUT   
   ,@cErrMsg         NVARCHAR( 20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @nFromWave INT  
  
   SET @nErrNo = 0  
   SET @cErrMsg = ''  
     
   SELECT @nFromWave = V_Integer3 FROM rdt.RDTMOBREC WITH (NOLOCK) WHERE mobile = @nMobile  
     
   IF @cUCCNo <> ''  
   BEGIN  
      IF NOT EXISTS (SELECT 1 FROM UCC WITH (NOLOCK) WHERE Storerkey = @cStorerKey AND UCCNo = @cUCCNo)  
      BEGIN  
         SET @nErrNo = 161103      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UCC      
         GOTO Quit  
      END  
      
      IF (SELECT COUNT(UCC_RowRef) FROM UCC WITH (NOLOCK) WHERE Storerkey = @cStorerKey AND UCCNo = @cUCCNo) >1  
      BEGIN  
         SET @nErrNo = 161104      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC >1 SKU       
         GOTO Quit  
      END  
      
      SELECT @cSKUIn = SKU FROM UCC WITH (NOLOCK) WHERE Storerkey = @cStorerKey AND UCCNo = @cUCCNo  
      
   END  
  
   IF @cSKUIn <> ''  
   BEGIN   
      IF @nFromWave = 1  
      BEGIN  
         SELECT TOP 1     
            @cBatchKey =LP.userdefine09,   
            @cLoadKey = LP.loadKey,   
            @cPosition = LP.userdefine10,   
            @cPalletID =  '' ,  
            @csku = PD.SKU,  
            @cConsigneeKey = '',  
            @cOrderKey = '',  
            @cPackData = W.Userdefine01  
         FROM ORDERS O WITH (NOLOCK)   
         JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (O.orderKey = LPD.OrderKey)  
         JOIN LoadPlan LP WITH (NOLOCK) ON (LPD.LoadKey = LP.LoadKey)  
         JOIN pickDetail PD WITH (NOLOCK) ON (o.orderKey = PD.OrderKey AND PD.Storerkey = O.StorerKey)  
         JOIN Wave W (NOLOCK) ON (W.waveKey = O.USERDEFINE09)  
         --LEFT JOIN (SELECT CARTONTYPE, SUM(QTY) QTY FROM rdt.rdtSortAndPackLog(NOLOCK)  WHERE  waveKey =@cWaveKey AND Status <> 9  GROUP BY CARTONTYPE ) AS SP ON SP.CARTONTYPE=RIGHT(PD.DropID,10)  
         LEFT JOIN (SELECT SKU,LOADKEY, SUM(QTY) QTY FROM rdt.rdtSortAndPackLog(NOLOCK)  WHERE  waveKey =@cWaveKey AND Status <> 9  GROUP BY LOADKEY,SKU ) AS SP ON SP.LOADKEY=O.LOADKEY AND PD.SKU=SP.SKU  
               WHERE O.storerKey = @cStorerKey   
               AND (O.UserDefine09 = @cWaveKey)  
               AND LP.UserDefine09 <> ''  
               AND  O.UserDefine09 <> ''  
               AND PD.SKU = @cSKUIn  
         AND LP.status < 9  
         AND PD.status < 5  
         AND PD.UOM=2  
         GROUP BY LP.userdefine09, LP.loadKey, LP.userdefine10, PD.SKU, W.Userdefine01,SP.QTY  
         HAVING  ISNULL(SP.QTY,0)<SUM(ISNULL(PD.QTY,0))  
         ORDER BY LP.UserDefine09,LP.Loadkey   
  
         IF @@ROWCOUNT = 0  
         BEGIN  
            SET @nErrNo = 161101      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU  
            GOTO Quit  
         END  
        
         SELECT 
            @nLoadQTY = SUM(PD.QTY)   
         FROM LOADPLAN LP WITH (NOLOCK)           
         LEFT JOIN ORDERS O WITH (NOLOCK) ON (LP.LOADKEY=O.LOADKEY)          
         LEFT JOIN PICKDETAIL PD WITH (NOLOCK) ON (O.ORDERKEY=PD.ORDERKEY)          
         WHERE O.UserDefine09 = @cWaveKey  
            AND PD.SKU = @cSKU  
            AND PD.UOM=2  
      END  
      ELSE  
      BEGIN  
       SELECT TOP 1   
            @cBatchKey =LP.userdefine09,   
            @cLoadKey = LP.loadKey,   
            @cPosition = LP.userdefine10,   
            @cPalletID = PD.DropID,  
            @csku = PD.SKU,  
            @cConsigneeKey = O.ConsigneeKey,  
            @cOrderKey = O.OrderKey,  
            @cPackData = W.Userdefine01  
         FROM ORDERS O WITH (NOLOCK)   
         JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (O.orderKey = LPD.OrderKey)  
         JOIN LoadPlan LP WITH (NOLOCK) ON (LPD.LoadKey = LP.LoadKey)  
         JOIN pickDetail PD WITH (NOLOCK) ON (o.orderKey = PD.OrderKey AND PD.Storerkey = O.StorerKey)  
         JOIN Wave W (NOLOCK) ON (W.waveKey = PD.WaveKey)  
         FULL OUTER JOIN rdt.rdtSortAndPackLog SNP WITH (NOLOCK) ON (LP.loadKey = SNP.loadKey AND O.StorerKey = SNP.StorerKey AND PD.SKU = SNP.SKU AND SNP.waveKey = '' AND SNP.status <> 9)  
         WHERE O.storerKey = @cStorerKey   
         AND (LP.UserDefine09 = @cBatchKeyIn)  
         AND LP.UserDefine09 <> ''  
         AND  O.UserDefine09 <> ''  
         AND PD.SKU = @cSKUIn  
         AND LP.status < 9  
         AND PD.Status < 5  
         AND PD.UOM=2  
         --AND LP.LoadKey NOT IN (SELECT loadkey FROM rdt.rdtSortAndPackLog WITH (NOLOCK) WHERE AddWho = @cUserName AND storerKey = @cStorerKey AND LoadKey = LP.Loadkey AND STATUS =9)  
         GROUP BY LP.userdefine09, LP.loadKey, LP.userdefine10, PD.DropID, PD.SKU, O.ConsigneeKey, O.OrderKey, W.Userdefine01,PD.QTY,SNP.QTY  
         HAVING (ISNULL(SNP.QTY,0) < ISNULL(SUM(PD.QTY),0))  
         ORDER BY LP.userdefine09,LP.Loadkey  
        
         IF @@ROWCOUNT = 0  
         BEGIN  
            SET @nErrNo = 161102      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU  
            GOTO Quit  
         END  
           
         SELECT @nLoadQTY = SUM(PD.QTY)   
         FROM LOADPLAN LP WITH (NOLOCK)     
         LEFT JOIN ORDERS O WITH (NOLOCK) ON (LP.LOADKEY=O.LOADKEY)    
         LEFT JOIN PICKDETAIL PD WITH (NOLOCK) ON (O.ORDERKEY=PD.ORDERKEY)    
         WHERE LP.UserDefine09 = @cBatchKeyIn   
         AND LP.loadKey = @cLoadKey  
         AND PD.SKU = @cSKU  
         AND PD.UOM=2  
      END          
   END    
Quit:  
  
END

GO