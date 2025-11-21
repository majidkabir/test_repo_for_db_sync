SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_841GetOrders06                                  */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: Get orderkey to pack. Only allow orders.doctype = 'E'       */  
/*          and orders.ecom_single_flag = 's'                           */
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2019-10-23  1.0  James    WMS-13459. Created                         */  
/************************************************************************/  

CREATE PROC [RDT].[rdt_841GetOrders06] (  
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
   SAVE TRAN rdt_841GetOrders06

   IF @nStep = 2  
   BEGIN
      IF @nInputKey = 1
      BEGIN
         INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate)  
         SELECT TOP 1 @nMobile, @cToteNo, PK.Orderkey, PK.SKU, @cDropIDType, SUM(PK.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE()    
         FROM dbo.PICKDETAIL PK WITH (NOLOCK)    
         JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = PK.Orderkey AND O.LoadKey = ISNULL(RTRIM(@cLoadKey),'')  
         WHERE PK.SKU = @cSKU
            AND PK.Status = '0' AND PK.ShipFlag = '0'
            AND PK.CaseID = ''
            AND PK.StorerKey = @cStorerKey
            AND O.DocType = 'E'
            AND O.ECOM_SINGLE_Flag = 'S'
            AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' )
            AND PK.Qty > 0
            AND NOT EXISTS ( SELECT 1 FROM rdt.rdtECOMMLog RE WITH (NOLOCK)     
                              WHERE RE.OrderKey = O.OrderKey
                              AND Status < '9'  )
         GROUP BY PK.OrderKey, PK.SKU
         
         SET @nRowCount = @@ROWCOUNT
         
         SET @nRowRef = SCOPE_IDENTITY()
         
         IF @@ERROR <> 0 
         BEGIN  
            SET @nErrNo = 153151  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins Ecomm Fail  
            GOTO RollBackTran  
         END 

         IF @nRowCount = 0
         BEGIN
            SET @nErrNo = 153152  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoRecToProcess  
            GOTO RollBackTran  
         END
      END
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_841GetOrders06

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_841GetOrders06

   Fail:        
END  

GO