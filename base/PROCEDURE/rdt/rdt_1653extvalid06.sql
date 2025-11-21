SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1653ExtValid06                                  */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Called from: rdtfnc_TrackNo_SortToPallet                             */    
/*                                                                      */    
/* Purpose: Validate if pallet cannot mix shipperkey (using HM          */    
/*          shipperkey method)                                          */
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2022-06-22  1.0  James    WMS-19868. Created                         */    
/* 2022-09-15  1.1  James    WMS-20667 Add Lane (james01)               */
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_1653ExtValid06] (    
   @nMobile        INT,    
   @nFunc          INT,    
   @cLangCode      NVARCHAR( 3),    
   @nStep          INT,    
   @nInputKey      INT,    
   @cFacility      NVARCHAR( 5),    
   @cStorerKey     NVARCHAR( 15),    
   @cTrackNo       NVARCHAR( 40),    
   @cOrderKey      NVARCHAR( 20),    
   @cPalletKey     NVARCHAR( 20),    
   @cMBOLKey       NVARCHAR( 10),    
   @cLane          NVARCHAR( 20),
   @tExtValidVar   VariableTable READONLY,    
   @nErrNo         INT           OUTPUT,    
   @cErrMsg        NVARCHAR( 20) OUTPUT    
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @cNew_ShipperKey   NVARCHAR( 15)
   DECLARE @cCur_ShipperKey   NVARCHAR( 15)
   DECLARE @cCur_OrderKey     NVARCHAR( 10)
   
   IF @nStep = 2    
   BEGIN    
      IF @nInputKey = 1    
      BEGIN    
         -- Get shipperkey from newly scanned orderkey (tracking no)
         SELECT @cNew_ShipperKey = SUBSTRING( C.Short, 1, 3) 
         FROM dbo.ORDERS O WITH (NOLOCK) 
         JOIN dbo.Codelkup C WITH (NOLOCK) ON ( C.Code = O.ShipperKey)
         WHERE O.OrderKey = @cOrderKey 
         AND   C.Listname = 'HMCourier'

         -- Get orderkey from existing pallet
         SELECT TOP 1 @cCur_OrderKey = UserDefine01
         FROM dbo.PALLETDETAIL WITH (NOLOCK)
         WHERE PalletKey = @cPalletKey
         AND   StorerKey = @cStorerKey
         AND   [Status] = '0'
         ORDER BY 1
         
         IF @@ROWCOUNT = 1
         BEGIN
            -- Get shipperkey from orders on existing pallet
            SELECT @cCur_ShipperKey = SUBSTRING( C.Short, 1, 3) 
            FROM dbo.ORDERS O WITH (NOLOCK) 
            JOIN dbo.Codelkup C WITH (NOLOCK) ON ( C.Code = O.ShipperKey)
            WHERE O.OrderKey = @cCur_OrderKey 
            AND   C.Listname = 'HMCourier'
         
            -- Validate if same shipperkey
            IF @cCur_ShipperKey <> @cNew_ShipperKey
            BEGIN
               SET @nErrNo = 187651  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PltDiffShipper  
               GOTO Quit  
            END
         END
      END
   END    
   
    
Quit:    
END

GO