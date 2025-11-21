SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1653ExtValid04                                  */    
/* Copyright      : LF Logistics                                        */    
/*                                                                      */    
/* Date        Rev  Author   Purposes                                   */    
/* 2022-04-12  1.0  James    WMS-19218 Created                          */  
/* 2022-09-15  1.1  James    WMS-20667 Add Lane (james01)               */
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_1653ExtValid04] (    
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
   
   DECLARE @cNew_WaveKey   NVARCHAR( 10)
   DECLARE @cCur_WaveKey   NVARCHAR( 10)
   DECLARE @cCur_OrderKey  NVARCHAR( 10)
   
   IF @nFunc = 1653 -- Track no sort to pallet
   BEGIN
      IF @nStep IN ( 2, 5) -- PalletKey
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get shipperkey from newly scanned orderkey (tracking no)
            SELECT @cNew_WaveKey = UserDefine09
            FROM dbo.ORDERS WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey

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
               SELECT @cCur_WaveKey = UserDefine09
               FROM dbo.ORDERS WITH (NOLOCK)
               WHERE OrderKey = @cCur_OrderKey

               -- Validate if same shipperkey
               IF @cCur_WaveKey <> @cNew_WaveKey
               BEGIN
                  SET @nErrNo = 185701
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Plt Diff Wave
                  GOTO Quit
               END
            END
         END
      END
   END
   
Quit:

END    

GO