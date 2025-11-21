SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_841GetOrders02                                  */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: Get orderkey which allocated from pickface only             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2019-04-02  1.0  James    WMS8484. Created                           */  
/* 2019-06-14  1.1  James    WMS9457. Skip if user key in tote (james01)*/  
/* 2019-06-17  1.2  James    Perf tune (james02)                        */  
/* 2020-04-27  1.3  James    WMS-13041. Filter JITX orders (james02)    */  
/* 2021-04-16  1.4  James    WMS-16024 Standarized use of TrackingNo    */
/*                           (james03)                                  */
/************************************************************************/  

CREATE PROC [RDT].[rdt_841GetOrders02] (  
   @nMobile       INT,  
   @nFunc         INT,  
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,
   @nInputKey     INT,
   @cUserName     NVARCHAR( 15),  
   @cFacility     NVARCHAR( 5),  
   @cStorerKey    NVARCHAR( 15),  
   @cToteno       NVARCHAR( 20),  
   @cWaveKey      NVARCHAR( 10),
   @cLoadKey      NVARCHAR( 10),  
   @cSKU          NVARCHAR( 20),  
   @cPickslipNo   NVARCHAR( 10),  
   @cTrackNo      NVARCHAR( 20),  
   @cDropIDType   NVARCHAR( 10),  
   @cOrderkey     NVARCHAR( 10) OUTPUT,  
   @nErrNo        INT           OUTPUT,  
   @cErrMsg       NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cNoToteFlag    NVARCHAR(1)

   SET @nErrNo   = 0  
   SET @cErrMsg  = ''  
   
   SELECT @cNoToteFlag = V_String16
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   IF @nStep = 2  
   BEGIN
      IF @nInputKey = 1
      BEGIN
         -- If key in tote no then no need do custom get orders process (james01)
         IF @cNoToteFlag = ''
            GOTO Quit

         IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
                         JOIN Orders O WITH (NOLOCK) ON PD.OrderKey = O.orderKey
                         WHERE O.LoadKey = @cLoadKey
                         AND   PD.SKU = @cSKU
                         AND   PD.StorerKey = @cStorerKey   -- (james02)
                         AND   PD.Status <= '3'             -- (james02)
                         AND   PD.Qty > 0)
         BEGIN  
            SET @nErrNo = 137251  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU notin load  
            GOTO Quit
         END 

         SET @cOrderkey = '' 

         SELECT TOP 1 @cOrderKey = PK.Orderkey
         FROM dbo.PICKDETAIL PK WITH (NOLOCK)    
         JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = PK.Orderkey AND O.LoadKey = ISNULL(RTRIM(@cLoadKey),'')  
         JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON ( PK.Loc = SL.Loc AND PK.Sku = SL.Sku )
         WHERE PK.SKU = @cSKU    
            AND PK.Status = '0' AND PK.ShipFlag = '0' 
            AND PK.CaseID = ''    
            AND PK.StorerKey = @cStorerKey    
            AND O.Type IN ('DTC', 'TMALL', 'NORMAL', 'COD' , 'SS', 'EX', 'TMALLCN')
            AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD' , 'PENDCANC' )   
            AND PK.Qty > 0
            --AND ISNULL(O.UserDefine04,'')  <> ''   
            AND ISNULL(O.TrackingNo,'')  <> ''  -- (james03)
            AND NOT EXISTS ( SELECT 1 FROM rdt.rdtECOMMLog RE WITH (NOLOCK)     
                              WHERE RE.OrderKey = O.OrderKey     
                              AND Status < '9'  )  
            AND NOT EXISTS ( SELECT 1 FROM ORDERS O2 WITH (NOLOCK)
                             WHERE O.OrderKey = O2.OrderKey
                             AND   O2.[Type] = 'VIP'
                             AND   O2.DocType = 'E')
            AND   SL.LocationType = 'PICK'

         IF ISNULL( @cOrderKey, '') = ''
         BEGIN  
            SET @nErrNo = 137252  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Ord 2 Pack
            GOTO Quit
         END 

         INSERT INTO rdt.rdtECOMMLog
         ( Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate) 
         SELECT TOP 1 @nMobile, @cToteNo, PK.Orderkey, PK.SKU, @cDropIDType, SUM(PK.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE()    
         FROM dbo.PICKDETAIL PK WITH (NOLOCK)    
         JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = PK.Orderkey AND O.LoadKey = ISNULL(RTRIM(@cLoadKey),'')  
         WHERE PK.SKU = @cSKU    
            AND PK.Status = '0' AND PK.ShipFlag = '0' 
            AND PK.CaseID = ''    
            AND PK.StorerKey = @cStorerKey    
            AND O.Type IN ('DTC', 'TMALL', 'NORMAL', 'COD' , 'SS', 'EX', 'TMALLCN')
            AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD' , 'PENDCANC' )
            AND PK.Qty > 0
            --AND ISNULL(O.UserDefine04,'')  <> ''   
            AND ISNULL(O.TrackingNo,'')  <> ''  -- (james03)
            AND NOT EXISTS ( SELECT 1 FROM rdt.rdtECOMMLog RE WITH (NOLOCK)     
                              WHERE RE.OrderKey = O.OrderKey     
                              AND Status < '9'  )   
            AND O.OrderKey = @cOrderKey
         GROUP BY PK.OrderKey, PK.SKU   

         IF @@ERROR <> 0 OR @@ROWCOUNT = 0
         BEGIN  
            SET @nErrNo = 137253  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins Ecomm Fail  
            GOTO Quit  
         END 
      END
   END

   Quit:        
END  

GO