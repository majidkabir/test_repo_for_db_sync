SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_841GetOrders13                                  */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2023-06-21  1.0  yeekung  WMS-22755. Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_841GetOrders13] (
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

   DECLARE @cOrderWithTrackNo NVARCHAR(1)
   DECLARE @cUseUdf04AsTrackNo NVARCHAR(1)
   SET @cOrderWithTrackNo = rdt.RDTGetConfig( @nFunc, 'OrderWithTrackNo', @cStorerkey)  
   SET @cUseUdf04AsTrackNo = rdt.RDTGetConfig( @nFunc, 'UseUdf04AsTrackNo', @cStorerKey)       

   IF @nStep = 2
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF @cOrderWithTrackNo = '1' -- (ChewKP10)     
         BEGIN    
            INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate)    
            SELECT TOP 1 @nMobile, @cToteNo, PK.Orderkey, PK.SKU, @cDropIDType, SUM(PK.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE()      
            FROM dbo.PICKDETAIL PK WITH (NOLOCK)      
            JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = PK.Orderkey AND O.LoadKey = ISNULL(RTRIM(@cLoadKey),'')    
            WHERE PK.SKU = @cSKU      
               AND PK.Status IN ('0','3') AND PK.ShipFlag = '0' --(ChewKP09)    
               AND PK.CaseID = ''      
               AND PK.StorerKey = @cStorerKey      
               AND (O.Type IN ('DTC', 'TMALL', 'NORMAL', 'COD', 'SS',   
                              'EX', 'TMALLCN', 'NORMAL1', 'VIP', 'B2C','0')  
               OR O.Type IN (SELECT code FROM CODELKUP (NOLOCK) where listname='DOCTYPE' AND storerkey = @cStorerKey))
               AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD' , 'PENDCANC' ) -- (ChewKP05)     
               AND PK.Qty > 0 -- SOS# 329265      
               AND (( @cUseUdf04AsTrackNo = '1' AND ISNULL( O.UserDefine04, '') <> '') OR ( ISNULL(O.TrackingNo ,'') <> ''))   -- (james14)  
               AND NOT EXISTS ( SELECT 1 FROM rdt.rdtECOMMLog RE WITH (NOLOCK)       
                                 WHERE RE.OrderKey = O.OrderKey       
                                 AND Status < '9'  )       
            GROUP BY PK.OrderKey, PK.SKU      
         END    
         ELSE    
         BEGIN    
            INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate)    
            SELECT TOP 1 @nMobile, @cToteNo, PK.Orderkey, PK.SKU, @cDropIDType, SUM(PK.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE()      
            FROM dbo.PICKDETAIL PK WITH (NOLOCK)      
            JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = PK.Orderkey AND O.LoadKey = ISNULL(RTRIM(@cLoadKey),'')    
            WHERE PK.SKU = @cSKU      
               AND PK.Status IN ('0','3') AND PK.ShipFlag = '0' --(ChewKP09)    
               AND PK.CaseID = ''      
               AND PK.StorerKey = @cStorerKey      
               AND (O.Type IN ('DTC', 'TMALL', 'NORMAL', 'COD', 'SS',   
                              'EX', 'TMALLCN', 'NORMAL1', 'VIP', 'B2C','0')  
               OR O.Type IN (SELECT code FROM CODELKUP (NOLOCK) where listname='DOCTYPE' AND storerkey = @cStorerKey))
               AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD' , 'PENDCANC' ) 
               AND PK.Qty > 0 -- SOS# 329265      
               AND NOT EXISTS ( SELECT 1 FROM rdt.rdtECOMMLog RE WITH (NOLOCK)       
                                 WHERE RE.OrderKey = O.OrderKey       
                                 AND Status < '9'  )       
            GROUP BY PK.OrderKey, PK.SKU      
         END    

         IF @@ROWCOUNT = 0 -- No data inserted
         BEGIN
            SET @nErrNo = 202451
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoRecToProcess'
            GOTO QUIT
         END
      END
   END

   GOTO Quit

   Quit:

END

GO