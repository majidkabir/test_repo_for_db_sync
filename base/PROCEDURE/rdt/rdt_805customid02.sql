SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_805CustomID02                                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev Author      Purposes                                  */
/* 25-09-2020 1.0 YeeKung     WMS-14910 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_805CustomID02] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5) ,
   @cStorerKey   NVARCHAR( 15),
   @cType        NVARCHAR( 15),
   @cStation1    NVARCHAR( 10),
   @cStation2    NVARCHAR( 10),
   @cStation3    NVARCHAR( 10),
   @cStation4    NVARCHAR( 10),
   @cStation5    NVARCHAR( 10),
   @cMethod      NVARCHAR( 1),
   @cScanID      NVARCHAR( 20),
   @cSKU         NVARCHAR( 20),
   @nQTY         INT,
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR(250) OUTPUT,
   @cNewCartonID NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nSuccess INT

   IF @nFunc = 805 -- PTLStation
   BEGIN
      IF @nStep = 6 -- Close carton
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cCartonID   NVARCHAR( 20)
            DECLARE @cLOC        NVARCHAR( 10)
            DECLARE @cOrderKey   NVARCHAR( 10)
            DECLARE @cPickSlipNo NVARCHAR( 10)
            DECLARE @nCartonNo   INT
            DECLARE @cOrderType     NVARCHAR(10)
            
            -- Set session info
            SELECT 
               @cCartonID = I_Field01, 
               @cLOC = I_Field02
            FROM rdt.rdtMobRec WITH (NOLOCK)
            WHERE Mobile = @nMobile
            
            -- Get order key
            IF @cCartonID <> ''
               SELECT @cOrderKey = OrderKey
               FROM rdt.rdtPTLStationLog WITH (NOLOCK)
               WHERE Station IN( @cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
                  AND CartonID = @cCartonID
            ELSE 
               SELECT @cOrderKey = OrderKey
               FROM rdt.rdtPTLStationLog WITH (NOLOCK)
               WHERE Station IN( @cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
                  AND LOC = @cLOC

           -- Get order info
            SELECT 
               @cOrderType =Type
            FROM Orders WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
            
            IF @cOrdertype='IC'
            BEGIN
               EXEC isp_getucckey 
               @cStorerkey ,
               8,
               @cNewCartonID output ,
               @nSuccess output  ,
               @nErrNo output,
               @cErrMsg Output ,
               '0'  ,
               '1',
               '1'  

               IF @nErrNo<>0
                  GOTO QUIT
            END
            ELSE
            BEGIN
               EXEC isp_getucckey 
               @cStorerkey ,
               10,
               @cNewCartonID output ,
               @nSuccess output  ,
               @nErrNo output,
               @cErrMsg Output ,
               '0'  ,
               '1',
               '0'  
               
               IF @nErrNo<>0
                  GOTO QUIT
            END
         END
      END
   END
   
Quit:

END

GO