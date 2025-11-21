SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_868ExtUpd01                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-08-07 1.0  Ung        SOS317600                                 */
/* 2016-03-25 1.1  Leong      SOS365988 - Follow main rdtfnc_PickAndPack*/
/*                                        Step_6 @nInputKey.            */
/************************************************************************/

CREATE PROC [RDT].[rdt_868ExtUpd01] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT,
   @nInputKey   INT,
   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cOrderKey   NVARCHAR( 10),
   @cLoadKey    NVARCHAR( 10),
   @cDropID     NVARCHAR( 20),
   @cSKU        NVARCHAR( 20),
   @cADCode     NVARCHAR( 18),
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess INT

   IF @nFunc = 868 -- Pick and pack
   BEGIN
   /*
      IF @nStep = 3
      BEGIN
         IF @nInputKey = 0 -- ESC
         BEGIN
            -- If packed
            IF EXISTS( SELECT TOP 1 1
               FROM PackHeader PH WITH (NOLOCK)
                  JOIN PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
               WHERE PH.OrderKey = @cOrderKey
                  AND PD.DropID = @cDropID
                  AND PD.QTY > 1)
            BEGIN
               -- Get login info
               DECLARE @cUserName NVARCHAR(18)
               DECLARE @cPrinter  NVARCHAR(10)
               SELECT
                  @cUserName = UserName,
                  @cPrinter = Printer
               FROM rdt.rdtMobRec WITH (NOLOCK)
               WHERE Mobile = @nMobile

               -- Call Bartender standard SP
               EXECUTE dbo.isp_BT_GenBartenderCommand
                  @cPrinter,     -- printer id
                  'BOXLABEL',    -- label type
                  @cUserName,    -- user id
                  @cStorerKey,   -- parm01
                  @cOrderKey,    -- parm02
                  '',            -- parm03
                  '',            -- parm04
                  '',            -- parm05
                  '',            -- parm06
                  '',            -- parm07
                  '',            -- parm08
                  '',            -- parm09
                  '',            -- parm10
                  @cStorerKey,   -- StorerKey
                  '1',           -- no of copy
                  0,             -- @bDebug,
                  '',            -- return result
                  @nErrNo        OUTPUT,
                  @cErrMsg       OUTPUT
            END
         END
      END
*/

      IF @nStep = 6 -- Pick completed
      BEGIN
         IF @nInputKey IN (1, 0) -- ENTER/ESC -- SOS365988
         BEGIN
            IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND Status = '9')
            BEGIN
               -- Get storer config
               DECLARE @cAssignPackLabelToOrdCfg NVARCHAR(1)
               EXECUTE nspGetRight
                        @cFacility,
                        @cStorerKey,
                        '', --@c_sku
                        'AssignPackLabelToOrdCfg',
                        @bSuccess                 OUTPUT,
                        @cAssignPackLabelToOrdCfg OUTPUT,
                        @nErrNo                   OUTPUT,
                        @cErrMsg                  OUTPUT

               IF @cAssignPackLabelToOrdCfg = '1'
               BEGIN
                  -- Get PickSlipNo
                  DECLARE @cPickSlipNo NVARCHAR(10)
                  SELECT @cPickSlipNo = PickSlipNo FROM PackHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey

                  -- Update PickDetail, base on PackDetail.DropID
                  EXEC isp_AssignPackLabelToOrderByLoad
                       @cPickSlipNo
                     , @bSuccess OUTPUT
                     , @nErrNo   OUTPUT
                     , @cErrMsg  OUTPUT
               END

               EXEC isp_WS_UpdPackOrdSts
                    @cOrderKey
                  , @cStorerKey
                  , @bSuccess  OUTPUT
                  , @nErrNo    OUTPUT
                  , @cErrMsg   OUTPUT
            END
         END
      END
   END
Quit:
Fail:

GO