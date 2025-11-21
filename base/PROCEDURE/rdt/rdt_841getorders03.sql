SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_841GetOrders03                                  */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Get orderkey to pack. If sostatus = pendcanc, prompt error  */    
/*          If orders need FragileCHK, prompt screen to alert           */  
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2019-10-23  1.0  James    WMS-10896. Created                         */
/* 2022-01-24  1.1. YeeKung  WMS-18823  Add status in ('3') (yeekung01) */    
/************************************************************************/    
  
CREATE   PROC [RDT].[rdt_841GetOrders03] (    
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
    
   DECLARE @nTranCount        INT = 0  
   DECLARE @nRowCount         INT = 0  
   DECLARE @nRowRef           INT = 0  
   DECLARE @cSOStatus         NVARCHAR( 10) = ''  
   DECLARE @cErrMsg01         NVARCHAR( 20) = ''  
  
  
   SET @nErrNo   = 0    
   SET @cErrMsg  = ''    
  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_841GetOrders03  
  
   IF @nStep = 2    
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
         INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate)    
         SELECT TOP 1 @nMobile, @cToteNo, PK.Orderkey, PK.SKU, @cDropIDType, SUM(PK.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE()      
         FROM dbo.PICKDETAIL PK WITH (NOLOCK)      
         JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = PK.Orderkey AND O.LoadKey = ISNULL(RTRIM(@cLoadKey),'')    
         WHERE PK.SKU = @cSKU  
            AND PK.Status IN('0','3') AND PK.ShipFlag = '0'  --yeekung01
            AND PK.CaseID = ''  
            AND PK.StorerKey = @cStorerKey  
            --AND O.Type IN ( 'DTC', 'TMALL', 'NORMAL', 'COD' , 'SS', 'EX', 'TMALLCN', 'NORMAL1', 'VIP')  
            AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD')  
            AND PK.Qty > 0  
            AND NOT EXISTS ( SELECT 1 FROM rdt.rdtECOMMLog RE WITH (NOLOCK)       
                              WHERE RE.OrderKey = O.OrderKey  
                              AND Status < '9'  )  
         GROUP BY PK.OrderKey, PK.SKU  
           
         SET @nRowCount = @@ROWCOUNT  
           
         SET @nRowRef = SCOPE_IDENTITY()  
           
         IF @@ERROR <> 0   
         BEGIN    
            SET @nErrNo = 145751    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins Ecomm Fail    
            GOTO RollBackTran    
         END   
  
         IF @nRowCount = 0  
         BEGIN  
            SET @nErrNo = 145752    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoRecToProcess    
            GOTO RollBackTran    
         END  
           
         SELECT @cOrderkey = re.OrderKey  
         FROM RDT.rdtECOMMLog AS re WITH (NOLOCK)  
         WHERE re.RowRef = @nRowRef  
           
         SELECT @cSOStatus = o.SOStatus   
         FROM dbo.ORDERS AS o WITH (NOLOCK)  
         WHERE o.OrderKey = @cOrderkey  
  
        IF @cSOStatus = 'PENDCANC'  
         BEGIN  
          UPDATE dbo.ORDERDETAIL WITH (ROWLOCK) SET  
             [Status] = '3',  
               EditWho = sUser_sName(),  
               EditDate = GetDate(),  
               TrafficCop = NULL  
          WHERE OrderKey = @cOrderKey  
            AND  [Status] < '3'  
            
          IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 145753  
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --Assign Loc Err  
               GOTO RollBackTran    
            END  
  
            UPDATE dbo.ORDERS WITH (ROWLOCK) SET   
               STATUS = '3',  
               EditWho = sUser_sName(),  
               EditDate = GetDate(),  
               TrafficCop = NULL  
            WHERE OrderKey = @cOrderKey  
            AND  [Status] < '3'  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 145754  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd OdHdr Fail'  
               GOTO RollBackTran  
            END  
              
            DELETE FROM rdt.rdtECOMMLog WHERE RowRef = @nRowRef  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 145755  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Canc Ecomm Fail'  
               GOTO RollBackTran  
            END  
  
            SET @cErrMsg01 = ''  
            SET @cErrMsg01 = rdt.rdtgetmessage( 145756, @cLangCode, 'DSP')  
  
            SET @nErrNo = 0  
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg01  
            SET @nErrNo = 145756  
            SET @cOrderkey = ''  
         END  
      END  
   END  
  
   GOTO Quit  
  
   RollBackTran:  
      ROLLBACK TRAN rdt_841GetOrders03  
  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN rdt_841GetOrders03  
  
   Fail:          
END    

SET QUOTED_IDENTIFIER OFF

GO