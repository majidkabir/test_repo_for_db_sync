SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/
/* Store procedure: rdt_DynamicPick_PickAndPack_GetNextCartonLabel               */
/* Copyright      : IDS                                                          */
/*                                                                               */
/* Purpose: Get next location for Pick And Pack function                         */
/*                                                                               */
/* Called from: rdtfnc_DynamicPick_PickAndPack                                   */
/*                                                                               */
/* Exceed version: 5.4                                                           */
/*                                                                               */
/* Modifications log:                                                            */
/*                                                                               */
/* Date        Rev  Author      Purposes                                         */
/* 19-Jun-2008 1.0  UngDH       Created                                          */
/* 23-Dec-2008 1.1  James       Check if exists existing cartonno that           */
/*                              hasn't been used and resuse it (james01)         */
/* 16-Dec-2011 1.2  Ung         Implement DynamicPickPrePrintedLabelNo           */
/* 10-Jan-2014 1.3  Ung         Fix same cartonno different labelno              */
/* 05-Feb-2015 1.4  Ung         SOS318713 Book CartonNo only upon save           */
/* 28-Jul-2016 1.5  Ung         SOS375224 Add LoadKey, Zone optional             */
/* 07-Jun-2018 1.6  Ung         INC0228346 Standardize GetNextCartonLabel param  */
/*********************************************************************************/

CREATE PROC [RDT].[rdt_DynamicPick_PickAndPack_GetNextCartonLabel] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cUserName     NVARCHAR( 15),
   @cPrinter      NVARCHAR( 10), 
   @cDynamicPickCartonLabel       NVARCHAR(1),
   @cDynamicPickPrePrintedLabelNo NVARCHAR( 1), 
   @cPickSlipNo   NVARCHAR( 10),
   @cPickZone     NVARCHAR( 10), 
   @cFromLOC      NVARCHAR( 10), 
   @cToLOC        NVARCHAR( 10), 
   @nCartonNo     INT           OUTPUT, 
   @cLabelNo      NVARCHAR( 20) OUTPUT, 
   @nErrNo        INT           OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @b_success INT
   DECLARE @n_err     INT
   DECLARE @c_errmsg  NVARCHAR( 250)

   DECLARE @cPrintCartonLabel       NVARCHAR(1)

   -- Check print carton label
   IF @cPrinter <> '' AND              -- Login with printer
      @cDynamicPickCartonLabel = '1'   -- Carton label turn on
      SET @cPrintCartonLabel = 'Y'
   ELSE
      SET @cPrintCartonLabel = 'N'

   -- (james01) start
   SELECT @nCartonNo = '', @cLabelNo = ''
   SELECT TOP 1 @nCartonNo = CartonNo, @cLabelNo = LabelNo 
   FROM RDT.RDTDynamicPickLog WITH (NOLOCK)
   WHERE PickSlipNo = @cPickSlipNo 
      AND AddWho = @cUserName
   ORDER BY AddDate DESC

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_GetNextCartonLabel

   -- Get the next carton, reserve it if not exists
   IF ISNULL(@cLabelNo, '') <> ''
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND PickSlipno = @cPickSlipNo
            AND LabelNo = @cLabelNo
            AND SKU = '')
      BEGIN
         -- Gen new set of CartonNo & LabelNo
         IF @cDynamicPickPrePrintedLabelNo = '1'
            SET @cLabelNo = ''
         ELSE
         BEGIN
            SET @cLabelNo = ''
            EXECUTE dbo.nsp_GenLabelNo
               '',
               @cStorerKey,
               @c_labelno     = @cLabelNo  OUTPUT,
               @n_cartonno    = @nCartonNo OUTPUT,
               @c_button      = '',
               @b_success     = @b_success OUTPUT,
               @n_err         = @n_err     OUTPUT,
               @c_errmsg      = @c_errmsg  OUTPUT
            IF @b_success <> 1
            BEGIN
               SET @nErrNo = 64601
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenLabelFail'
               GOTO RollBackTran
            END
         END

         -- Book carton no and label no
         IF @cPrintCartonLabel = 'Y'
         BEGIN
            -- Insert PackDetail
            INSERT INTO dbo.PackDetail
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate)
            VALUES
               (@cPickSlipNo, 0, @cLabelNo, '', @cStorerKey, '', 0, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE())
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 64602
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDtlFail'
               GOTO RollBackTran
            END
   
            -- Get carton no (if insert cartonno = 0, system will auto assign max cartonno)
            SELECT TOP 1 
               @nCartonNo = CartonNo
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo 
               AND AddWho = 'rdt.' + @cUserName
            --ORDER BY AddDate DESC
            ORDER BY CartonNo DESC
         END
         ELSE
            SET @nCartonNo = 0
      END
   END
   ELSE  -- If label no is blank
   BEGIN
      -- Get the first carton, reserve it if not exists
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
            AND SKU = '')
      BEGIN
         -- Get label no
         IF @cDynamicPickPrePrintedLabelNo = '1'
            SET @cLabelNo = ''
         ELSE
         BEGIN
            SET @cLabelNo = ''
            EXECUTE dbo.nsp_GenLabelNo
               '',
               @cStorerKey,
               @c_labelno     = @cLabelNo  OUTPUT,
               @n_cartonno    = @nCartonNo OUTPUT,
               @c_button      = '',
               @b_success     = @b_success OUTPUT,
               @n_err         = @n_err     OUTPUT,
               @c_errmsg      = @c_errmsg  OUTPUT
            IF @b_success <> 1
            BEGIN
               SET @nErrNo = 64603
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenLabelFail'
               GOTO RollBackTran
            END
         END

         -- Create PackHeader if not exist
         IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)
         BEGIN
            -- Insert PackHeader
            INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey, LoadKey)
            SELECT PickHeaderKey, @cStorerKey, OrderKey, ExternOrderKey
            FROM PickHeader WITH (NOLOCK)
            WHERE PickHeaderKey = @cPickSlipNo
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 64604
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackHdrFail'
               GOTO RollBackTran
            END
         END

         -- Book carton no and label no
         IF @cPrintCartonLabel = 'Y'
         BEGIN
            -- Insert PackDetail
            INSERT INTO dbo.PackDetail
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate)
            VALUES
               (@cPickSlipNo, 0, @cLabelNo, '', @cStorerKey, '', 0, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE())
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 64605
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDtlFail'
               GOTO RollBackTran
            END
   
            -- Get carton no (if insert cartonno = 0, system will auto assign max cartonno)
            SELECT TOP 1 
               @nCartonNo = CartonNo
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo 
               AND AddWho = 'rdt.' + @cUserName
            --ORDER BY AddDate DESC
            ORDER BY CartonNo DESC
         END
         ELSE
            SET @nCartonNo = 0
      END
   END
   
   -- Update RDTDynamicPickLog (CartonNo, LabelNo)
   UPDATE rdt.rdtDynamicPickLog SET
      CartonNo = @nCartonNo, 
      LabelNo = @cLabelNo
   WHERE PickSlipNo = @cPickSlipNo
      AND Zone = @cPickZone
      AND FromLOC = @cFromLOC
      AND ToLOC = @cToLOC
      AND AddWho = @cUserName
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 64606
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPKInfoFail'
      GOTO RollBackTran
   END

   GOTO Quit

RollBackTran:
      ROLLBACK TRAN rdt_GetNextCartonLabel
Quit:         
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
END

GO