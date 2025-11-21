SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtValid03                                   */
/* Purpose: 1 Orders only 1 Carton no. Prompt error if user change      */
/*                                                                      */
/* Called By: RDT Pack By Track No                                      */ 
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2019-01-16 1.0  James      WMS7499 Created                           */
/* 2021-04-01 1.1  YeeKung    WMS-16717 Add serialno and serialqty      */
/*                            Params (yeekung01)                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtValid03] (
   @nMobile                   INT,
   @nFunc                     INT,
   @cLangCode                 NVARCHAR( 3),
   @nStep                     INT,
   @nInputKey                 INT, 
   @cStorerkey                NVARCHAR( 15),
   @cOrderKey                 NVARCHAR( 10),
   @cPickSlipNo               NVARCHAR( 10),
   @cTrackNo                  NVARCHAR( 20),
   @cSKU                      NVARCHAR( 20),
   @nCartonNo                 INT,
   @cCtnType                  NVARCHAR( 10),
   @cCtnWeight                NVARCHAR( 10),
   @cSerialNo                 NVARCHAR( 30), 
   @nSerialQTY                INT,          
   @nErrNo                    INT           OUTPUT,
   @cErrMsg                   NVARCHAR( 20) OUTPUT 
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cType                NVARCHAR( 10),
           @cRDS                 NVARCHAR( 1),
           @cShipperkey          NVARCHAR( 15), 
           @cCarrierName         NVARCHAR( 30), 
           @cKeyName             NVARCHAR( 30), 
           @cTrackingNo_Letter   NVARCHAR( 20),
           @cOrd_TrackingNo      NVARCHAR( 20),
           @cPickDetailKey       NVARCHAR( 10),
           @cLabelLine           NVARCHAR( 5),
           @nCount               INT, 
           @nTranCount           INT, 
           @nTtl_OrdQty          INT, 
           @nTtl_PckQty          INT 

   DECLARE @cErrMsg1       NVARCHAR( 20), 
           @cErrMsg2       NVARCHAR( 20), 
           @cErrMsg3       NVARCHAR( 20), 
           @cErrMsg4       NVARCHAR( 20), 
           @cErrMsg5       NVARCHAR( 20) 

   SET @nErrNo = 0

   IF @nStep = 3
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF @nCartonNo <> 1
         BEGIN
            SET @nErrNo = 133851  -- Only Carton #1
            GOTO Fail
         END
      END
   END

   GOTO Fail
Fail:

GO