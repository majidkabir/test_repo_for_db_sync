SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtValid15                                   */
/* Purpose: Check for sostatus = PENDCANC.                              */
/*          If yes update order.status = 3. Prompt error screen and     */
/*          stop processing. Backend job will auto unallocate orders    */
/*                                                                      */
/* Called By: RDT Pack By Track No                                      */ 
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2022-12-06 1.0  James      WMS-20581 Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_840ExtValid15] (
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

   DECLARE @cSOStatus            NVARCHAR( 10),
           @cUserDefine10        NVARCHAR( 10)

   SET @nErrNo = 0

   IF @nStep = 1
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT 
            @cSOStatus = SOStatus, 
            @cUserDefine10 = UserDefine10
         FROM dbo.ORDERS AS o WITH (NOLOCK)
         WHERE o.OrderKey = @cOrderKey
         
         IF @cSOStatus = 'PENDCANC'
         BEGIN
            SET @nErrNo = 194451
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --PENDING CANC
            GOTO Quit  
         END
         
         IF @cUserDefine10 = '3'
         BEGIN
            SET @nErrNo = 194452
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --PARTIAL CANC
            GOTO Quit  
         END
      END
   END
   
   Quit:
   
   
SET QUOTED_IDENTIFIER OFF

GO