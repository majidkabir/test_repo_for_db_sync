SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/      
/* Store procedure: rdt_TN_GetMbol_LEVIS                                */      
/* Copyright      : IDS                                                 */      
/*                                                                      */      
/* Called from: rdtfnc_TrackNo_SortToPallet                             */      
/*                                                                      */      
/* Purpose: Get MBOLKey                                                 */      
/*                                                                      */      
/* Modifications log:                                                   */      
/* Date        Rev  Author   Purposes                                   */      
/* 2024-06-14  1.0  Dennis   FCR-396    Created                         */    
/************************************************************************/      
      
CREATE   PROC [RDT].[rdt_TN_GetMbol_LEVIS] (      
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

   /***********************************************************************************************    
                                              Standard get mbolkey for LEVIS   
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
                  AND   [Status] > '5')  
      BEGIN  
         SET @nErrNo = 189828  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lane Closed  
         GOTO Quit  
      END

      SET @cPalletKey = '' 
      SELECT TOP 1 @cPalletKey = PD.PalletKey 
      FROM dbo.PalletDetail PD WITH (NOLOCK)  
      JOIN dbo.PALLET P WITH (NOLOCK) ON ( PD.PalletKey = P.PalletKey)  
      WHERE P.StorerKey = @cStorerKey  
      AND   P.Status = 0
      AND   PD.UserDefine01 = @cOrderKey
      ORDER BY PD.EditDate desc

      SET @cLane = ''
      SELECT @cLane = M.ExternMbolKey  
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