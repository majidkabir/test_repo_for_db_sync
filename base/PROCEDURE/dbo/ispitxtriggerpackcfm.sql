SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispITXTriggerPackCfm                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Retrigger Inditex pack confirm transmit log, after          */
/*          RDT merge carton                                            */
/*                                                                      */
/* Modifications log:                                                   */
/* Date       Rev  Author   Purposes                                    */
/* 2012-11-23 1.0  Ung      Created. SOS261923                          */
/************************************************************************/

CREATE PROC [dbo].[ispITXTriggerPackCfm] (
   @nMobile      INT,
   @nFunc        INT, 
   @cLangCode    NVARCHAR( 3), 
   @cUserName    NVARCHAR( 18), 
   @cFacility    NVARCHAR( 5), 
   @cStorerKey   NVARCHAR( 15),
   @cPickSlipNo  NVARCHAR( 10),
   @cFromLabelNo NVARCHAR( 20),
   @cToLabelNo   NVARCHAR( 20),
   @cCartonType  NVARCHAR( 10), 
   @cSKU         NVARCHAR( 20),
   @nQTY_Move    INT,
   @nErrNo       INT          OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_success INT
   
   DECLARE @cOrderKey NVARCHAR( 10)
   DECLARE @cStatus NVARCHAR( 1)
   
   -- Get PackHeader info
   SELECT 
      @cOrderKey = OrderKey, 
      @cStatus = [Status]
   FROM dbo.PackHeader WITH (NOLOCK)
   WHERE PickSlipNo = @cPickSlipNo
   
   IF @cStatus = '9' -- Pack confirmed
   BEGIN
      IF EXISTS( SELECT 1 
         FROM dbo.TransmitLog3 WITH (NOLOCK) 
         WHERE TableName = 'PICKCFMLOG' 
            AND Key1 = @cOrderKey 
            AND Key2 = ''
            AND Key3 = @cStorerKey 
            AND TransmitFlag = '9')
      BEGIN
         UPDATE TransmitLog3 SET
            TransmitFlag = '0'
         WHERE TableName = 'PICKCFMLOG'
            AND Key1 = @cOrderKey
            AND Key2 = ''
            AND Key3 = @cStorerKey
      END
   END
END

GO