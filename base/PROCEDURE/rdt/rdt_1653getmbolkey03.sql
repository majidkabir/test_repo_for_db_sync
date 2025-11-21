SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/    
/* Store procedure: rdt_1653GetMbolKey03                                */    
/* Copyright      : MAERSK                                              */    
/*                                                                      */    
/* Called from: rdt_TrackNo_SortToPallet_GetMbolKey                     */    
/*                                                                      */    
/* Purpose: Get MBOLKey                                                 */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2022-09-15  1.0  James    WMS-20667. Created                         */    
/* 2023-08-30  1.1  James    WMS-23471 Allow palletkey blank (james01)  */
/* 202405-17   1.2  James    WMS-23948 Add plt not mix mbol (james02)   */
/************************************************************************/    
    
CREATE   PROC [RDT].[rdt_1653GetMbolKey03] (    
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
    
   DECLARE @cCur_ShipperKey   NVARCHAR( 15) = ''    
   DECLARE @cNew_ShipperKey   NVARCHAR( 15) = ''    
   DECLARE @cCur_OrderKey     NVARCHAR( 10) = ''    
   DECLARE @cPalletNotAllowMixShipperKey  NVARCHAR( 1)    
   DECLARE @cBillToKey        NVARCHAR( 15) = ''
   DECLARE @cBuyerPO          NVARCHAR( 20) = ''

   IF ISNULL( @cOrderKey, '') = ''    
      SELECT @cOrderKey = OrderKey,    
             @cNew_ShipperKey = ShipperKey    
      FROM dbo.ORDERS WITH (NOLOCK)    
      WHERE StorerKey = @cStorerKey    
      AND   TrackingNo = @cTrackNo    
   ELSE    
      SELECT @cNew_ShipperKey = ShipperKey    
      FROM dbo.ORDERS WITH (NOLOCK)    
      WHERE OrderKey = @cOrderKey    
    
   SET @cMBOLKey = ''    
   SELECT @cMBOLKey = MbolKey    
   FROM dbo.MBOLDETAIL WITH (NOLOCK)    
   WHERE OrderKey = @cOrderKey    
    
   SET @cLane = ''    
   SELECT @cLane = ExternMbolKey    
   FROM dbo.MBOL WITH (NOLOCK)    
   WHERE MbolKey = @cMBOLKey    
       
   IF @cMBOLKey <> '' AND @cLane <> ''    
   BEGIN    
      IF EXISTS ( SELECT 1 FROM MBOL WITH (NOLOCK)    
                  WHERE MbolKey = @cMBOLKey    
                  AND   [Status] = '9')    
      BEGIN    
         SET @nErrNo = 191451    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL Shipped    
         GOTO Quit    
      END    
    
      SET @cPalletKey = ''    
      SELECT TOP 1     
         @cPalletKey = PalletKey    
      FROM dbo.PALLETDETAIL WITH (NOLOCK)    
      WHERE StorerKey = @cStorerKey    
      AND   UserDefine01 = @cOrderKey    
      ORDER BY EditDate DESC    
          
      SET @cPalletNotAllowMixShipperKey = rdt.RDTGetConfig( @nFunc, 'PalletNotAllowMixShipperKey', @cStorerkey)    
      IF @cPalletNotAllowMixShipperKey = '0'    
         SET @cPalletNotAllowMixShipperKey = ''    
    
      -- 1 pallet 1 shipperkey    
      IF @cPalletNotAllowMixShipperKey = '1' AND @cPalletKey <> ''   
      BEGIN    
         -- Get orderkey from existing pallet    
         SELECT TOP 1 @cCur_OrderKey = UserDefine01    
         FROM dbo.PALLETDETAIL WITH (NOLOCK)    
         WHERE PalletKey = @cPalletKey    
         AND   StorerKey = @cStorerKey    
         AND   [Status] = '0'     -- CHANGES   
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
            SET @cLane = ''    
         END    
      END  

      -- Cater for storer who create mbol before scan to pallet
      IF @cPalletKey = ''
         SET @cMBOLKey = ''
   END    

   IF ISNULL( @cMBOLKey, '') = ''
   BEGIN
      SELECT 
         @cBuyerPO = BuyerPO,
         @cBillToKey = BillToKey
      FROM dbo.ORDERS WITH (NOLOCK)      
      WHERE OrderKey = @cOrderKey

      IF EXISTS (SELECT 1 
                 FROM dbo.CODELKUP WITH (NOLOCK) 
                 WHERE ListName = 'NOMIXPLSHP'
                 AND   Code = @cBillToKey
                 AND   StorerKey = @cStorerkey 
                 AND   UDF02 = 'AUTOSORTPO')
      BEGIN
         SET @cMBOLKey = ''
         SELECT TOP 1 @cMBOLKey = MbolKey
         FROM dbo.ORDERS WITH (NOLOCK)      
         WHERE StorerKey = @cStorerKey
         AND   BuyerPO = @cBuyerPO
         AND   BillToKey = @cBillToKey
         AND   [Status] NOT IN ( '9', 'CANC') 
         AND   ISNULL( MBOLKey, '') <> ''
         ORDER BY 1
         
         IF ISNULL( @cMBOLKey, '') <> ''
         BEGIN
         	SET @cLane = ''      
            SELECT @cLane = ExternMbolKey      
            FROM dbo.MBOL WITH (NOLOCK)      
            WHERE MbolKey = @cMBOLKey
            
            SET @cPalletKey = ''
            SELECT TOP 1 @cPalletKey = PalletKey 
            FROM dbo.PALLETDETAIL PD WITH (NOLOCK) 
            JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PD.UserDefine01 = O.OrderKey AND PD.StorerKey = O.StorerKey)
            WHERE O.MBOLKey = @cMbolKey 
            AND   PD.StorerKey = @cStorerKey 
            AND   PD.Status = '0'
            ORDER BY 1
         END
      END
   END
Quit:    
END 

GO