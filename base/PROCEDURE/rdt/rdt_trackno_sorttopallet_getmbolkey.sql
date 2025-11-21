SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/      
/* Store procedure: rdt_TrackNo_SortToPallet_GetMbolKey                 */      
/* Copyright      : IDS                                                 */      
/*                                                                      */      
/* Called from: rdtfnc_TrackNo_SortToPallet                             */      
/*                                                                      */      
/* Purpose: Get MBOLKey                                                 */      
/*                                                                      */      
/* Modifications log:                                                   */      
/* Date        Rev  Author   Purposes                                   */      
/* 2020-08-01  1.0  James    WMS-14248. Created                         */    
/* 2021-04-16  1.1  James    WMS-16024 Standarized use of TrackingNo    */  
/*                           (james01)                                  */  
/* 2021-08-24  1.2  James    WMS-17773 Add retrieve palletkey (james02) */  
/*                           Extend TrackNo to 40 chars                 */  
/* 2021-10-21  1.3  James    WMS-18222 Add config to block mix          */  
/*                           shipperkey on 1 pallet (james03)           */  
/* 2022-03-07  1.4  James    WMS-18350 Add filter storerkey when        */  
/*                           suggest palletkey (james04)                */  
/* 2022-09-15  1.5  James    WMS-20667 Add Lane (james05)               */
/************************************************************************/      
      
CREATE PROC [RDT].[rdt_TrackNo_SortToPallet_GetMbolKey] (      
   @nMobile        INT,  
   @nFunc          INT,  
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,  
   @nInputKey      INT,  
   @cFacility      NVARCHAR( 5),  
   @cStorerKey     NVARCHAR( 15),  
   @cTrackNo       NVARCHAR( 40),  
   @cOrderKey      NVARCHAR( 20),  
   @cPalletKey     NVARCHAR( 20) OUTPUT,  
   @cMBOLKey       NVARCHAR( 10) OUTPUT,  
   @cLane          NVARCHAR( 20) OUTPUT,
   @nErrNo         INT           OUTPUT,  
   @cErrMsg        NVARCHAR( 20) OUTPUT  
) AS      
BEGIN      
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
     
   DECLARE @cSQL           NVARCHAR( MAX)  
   DECLARE @cSQLParam      NVARCHAR( MAX)  
   DECLARE @cGetMbolKeySP  NVARCHAR( 20)  
     
   -- Get storer config    
   SET @cGetMbolKeySP = rdt.RDTGetConfig( @nFunc, 'GetMbolKeySP', @cStorerKey)    
   IF @cGetMbolKeySP = '0'    
      SET @cGetMbolKeySP = ''    
    
   /***********************************************************************************************    
                                              Custom get mbolkey    
   ***********************************************************************************************/    
   -- Check confirm SP blank    
   IF @cGetMbolKeySP <> ''    
   BEGIN    
      -- Confirm SP    
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cGetMbolKeySP) +    
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +    
         ' @cTrackNo, @cOrderKey, @cPalletKey OUTPUT, @cMBOLKey OUTPUT, @cLane OUTPUT, ' +     
         ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
      SET @cSQLParam =    
         ' @nMobile        INT,           ' +    
         ' @nFunc          INT,           ' +    
         ' @cLangCode      NVARCHAR( 3),  ' +    
         ' @nStep          INT,           ' +    
         ' @nInputKey      INT,           ' +    
         ' @cFacility      NVARCHAR( 5) , ' +    
         ' @cStorerKey     NVARCHAR( 15), ' +    
         ' @cTrackNo       NVARCHAR( 20), ' +    
         ' @cOrderKey      NVARCHAR( 10), ' +    
         ' @cPalletKey     NVARCHAR( 20) OUTPUT, ' +    
         ' @cMBOLKey       NVARCHAR( 10) OUTPUT, ' +    
         ' @cLane          NVARCHAR( 20) OUTPUT, ' +
         ' @nErrNo         INT           OUTPUT, ' +           
         ' @cErrMsg        NVARCHAR(250) OUTPUT  '    
    
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,     
         @cTrackNo, @cOrderKey, @cPalletKey OUTPUT, @cMBOLKey OUTPUT, @cLane OUTPUT,   
         @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
      GOTO Quit    
   END    
    
   /***********************************************************************************************    
                                              Standard get mbolkey    
   ***********************************************************************************************/    
     
   DECLARE @cCur_ShipperKey   NVARCHAR( 15) = ''  
   DECLARE @cNew_ShipperKey   NVARCHAR( 15) = ''  
   DECLARE @cCur_OrderKey     NVARCHAR( 10) = ''  
   DECLARE @cPalletNotAllowMixShipperKey  NVARCHAR( 1)  
     
   IF ISNULL( @cOrderKey, '') = ''  
      SELECT @cOrderKey = OrderKey,   
             @cNew_ShipperKey = ShipperKey  
      FROM dbo.ORDERS WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
      --AND   @cTrackNo IN ( TrackingNo, UserDefine04)  
      AND   TrackingNo = @cTrackNo  -- (james01)  
   ELSE  
      SELECT @cNew_ShipperKey = ShipperKey  
      FROM dbo.ORDERS WITH (NOLOCK)  
      WHERE OrderKey = @cOrderKey  
  
   SET @cMBOLKey = ''  
   SELECT @cMBOLKey = MbolKey  
   FROM dbo.MBOLDETAIL WITH (NOLOCK)  
   WHERE OrderKey = @cOrderKey  
  
   IF @cMBOLKey <> ''  
   BEGIN  
      IF EXISTS ( SELECT 1 FROM MBOL WITH (NOLOCK)  
                  WHERE MbolKey = @cMBOLKey  
                  AND   [Status] = '9')  
      BEGIN  
         SET @nErrNo = 174151  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Orders Shipped  
         GOTO Quit  
      END  
        
      SET @cPalletKey = ''  
      SELECT @cPalletKey = M.ExternMbolKey  
      FROM dbo.MBOL M WITH (NOLOCK)  
      JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON ( M.MbolKey = MD.MbolKey)  
      JOIN dbo.Orders O WITH (NOLOCK) ON ( MD.OrderKey = O.OrderKey)   
      WHERE M.MbolKey = @cMBOLKey  
      AND   O.StorerKey = @cStorerKey  
        
      SET @cPalletNotAllowMixShipperKey = rdt.RDTGetConfig( @nFunc, 'PalletNotAllowMixShipperKey', @cStorerkey)    
      IF @cPalletNotAllowMixShipperKey = '0'    
         SET @cPalletNotAllowMixShipperKey = ''    
  
      -- 1 pallet 1 shipperkey  
      IF @cPalletNotAllowMixShipperKey = '1'  
      BEGIN  
         -- Get orderkey from existing pallet  
         SELECT TOP 1 @cCur_OrderKey = UserDefine01  
         FROM dbo.PALLETDETAIL WITH (NOLOCK)  
         WHERE PalletKey = @cPalletKey  
         AND   StorerKey = @cStorerKey  
         AND   [Status] = '0'  
         ORDER BY 1  
           
         -- Get shipperkey from orders on existing pallet  
         SELECT @cCur_ShipperKey = ShipperKey  
         FROM dbo.ORDERS WITH (NOLOCK)  
         WHERE OrderKey = @cCur_OrderKey  
   
         -- Validate if same shipperkey  
         IF @cCur_ShipperKey <> @cNew_ShipperKey  
         BEGIN  
            SET @cMBOLKey = ''  
            SET @cPalletKey = ''  
         END  
      END  
   END  
Quit:      
END      

GO