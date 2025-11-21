SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1653ExtValid08                                  */    
/* Copyright      : LF Logistics                                        */    
/*                                                                      */    
/* Date        Rev  Author   Purposes                                   */    
/* 2023-04-28  1.0  James    WMS-22349 Created                          */  
/************************************************************************/    
    
CREATE   PROC [RDT].[rdt_1653ExtValid08] (    
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
   
   DECLARE @cNew_State     NVARCHAR( 45)
   DECLARE @cCur_State     NVARCHAR( 45)
   DECLARE @cCur_OrderKey  NVARCHAR( 10)
   DECLARE @cShort         NVARCHAR( 10)
   DECLARE @cShipperKey    NVARCHAR( 15)
   
   IF @nFunc = 1653 -- Track no sort to pallet
   BEGIN
      IF @nStep IN ( 2, 5) -- PalletKey
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get shipperkey from newly scanned orderkey (tracking no)
            SELECT 
               @cNew_State = C_State,
               @cShipperKey = ShipperKey
            FROM dbo.ORDERS WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey

         	SELECT @cShort = Short
            FROM dbo.CODELKUP WITH (NOLOCK)
            WHERE LISTNAME = 'LANECONFIG'
            AND   Code = 'MIXSTATE'
            AND   Storerkey = @cStorerKey
            AND   code2 = @cShipperKey
            
            IF @cShort <> '1'
               GOTO Quit

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
               SELECT @cCur_State = C_State
               FROM dbo.ORDERS WITH (NOLOCK)
               WHERE OrderKey = @cCur_OrderKey

               -- Validate if same shipperkey
               IF @cCur_State <> @cNew_State
               BEGIN
                  SET @nErrNo = 200451
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Plt Diff State
                  GOTO Quit
               END
            END
         END
      END
   END
   
Quit:

END    

GO