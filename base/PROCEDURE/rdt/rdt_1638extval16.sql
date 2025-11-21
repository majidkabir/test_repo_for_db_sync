SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1638ExtVal16                                    */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 2022-10-17  1.0  yeekung   WMS-20927. Created                        */  
/************************************************************************/

CREATE   PROC [RDT].[rdt_1638ExtVal16] (
   @nMobile      INT,           
   @nFunc        INT,           
   @nStep        INT,
   @nInputKey    INT,           
   @cLangCode    NVARCHAR( 3),  
   @cFacility    NVARCHAR( 5),  
   @cStorerkey   NVARCHAR( 15), 
   @cPalletKey   NVARCHAR( 30), 
   @cCartonType  NVARCHAR( 10), 
   @cCaseID      NVARCHAR( 20), 
   @cLOC         NVARCHAR( 10), 
   @cSKU         NVARCHAR( 20), 
   @nQTY         INT,            
   @cLength      NVARCHAR(5),    
   @cWidth       NVARCHAR(5),    
   @cHeight      NVARCHAR(5),    
   @cGrossWeight NVARCHAR(5),    
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT 
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cUserName      NVARCHAR(20)
   DECLARE @cBuyerPO  NVARCHAR(20)
   DECLARE @cShipperkey NVARCHAR(20)
   DECLARE @cPrevTrackno NVARCHAR(20)
   DECLARE @cCurrentTrackNo NVARCHAR(20)
   DECLARE @cErrMsg1 NVARCHAR(20)
   DECLARE @cErrMsg2 NVARCHAR(20)
   DECLARE @cErrMsg3 NVARCHAR(20)
   DECLARE @cErrMsg4 NVARCHAR(20)
   DECLARE @cErrMsg5 NVARCHAR(20)

   IF @nFunc = 1638 -- Scan to pallet
   BEGIN
   	IF @nStep = 3
   	BEGIN
   		IF @nInputKey = 1
   		BEGIN
            SELECT @cCurrentTrackNo=I_Field03
                  ,@cUserName =username
            FROM  rdt.rdtmobrec (NOLOCK)
            WHERE mobile=@nMobile


            SELECT @cBuyerPO=BuyerPO,
                  @cShipperkey = ShipperKey
            from orders (nolock)
            WHERE trackingno=@cCurrentTrackNo
            AND storerkey=@cStorerkey


            SELECT TOP 1 @cPrevTrackno=trackingno
            FROM palletdetail (Nolock)
            where palletkey=@cPalletKey
               AND storerkey=@cStorerkey

            IF EXISTS (SELECT 1 FROM orders (NOLOCK)
                        WHERE trackingno=@cPrevTrackno
                        AND storerkey=@cStorerkey
                        AND BuyerPO <>@cBuyerPO
                        AND ShipperKey<> @cShipperkey)
            BEGIN
               SET @nErrNo = 192901   
               SET @cErrMsg1 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- WrongCourrier  

               SET @cErrMsg2 ='BuyerPO:'
               SET @cErrMsg3 = @cBuyerPO
               SET @cErrMsg4 ='Shipperkey:'
               SET @cErrMsg5 = @cShipperkey
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,   
               @cErrMsg1, @cErrMsg2,@cErrMsg3,@cErrMsg4,@cErrMsg5
               GOTO Quit  
            END
   		END
   	END

   END
END

Quit:

SET QUOTED_IDENTIFIER OFF

GO