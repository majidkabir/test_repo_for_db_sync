SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtPackCfm05                                 */
/* Purpose: Pack cfm, stamp pickdetail.caseid = labelno and             */
/*          pickdetail.dropid = labelno                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2024-03-04  1.0  NLT013      UWP-16265                               */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtPackCfm05] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cStorerkey       NVARCHAR( 15),
   @cPickslipno      NVARCHAR( 10),
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount     INT
   DECLARE @nRowCount      INT

   SET @nTranCount = @@TRANCOUNT

   IF @nTranCount = 0
      BEGIN TRANSACTION
   ELSE
      SAVE TRANSACTION rdt_840ExtPackCfm05

   BEGIN TRY
      IF EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo
                  AND STATUS = '0')
      BEGIN
         UPDATE dbo.PackHeader SET
            STATUS = '9'
         WHERE PickSlipNo = @cPickSlipNo
      END

      UPDATE pkd
      SET 
         CaseID = packd.LabelNo,
         DropID = packd.LabelNo,
         EditWho = SUSER_SNAME(),
         EditDate = GETDATE()
      FROM dbo.PICKDETAIL AS pkd
      INNER JOIN dbo.ORDERDETAIL AS ord WITH(NOLOCK)
         ON pkd.StorerKey = ord.StorerKey
         AND pkd.OrderKey = ord.OrderKey
         AND pkd.OrderLineNumber = ord.OrderLineNumber
      INNER JOIN PackHeader AS packh WITH(NOLOCK)
         ON packh.StorerKey = ord.StorerKey
         AND packh.OrderKey = ord.OrderKey
      INNER JOIN PackDetail AS packd WITH(NOLOCK)
         ON packh.PickSlipNo = packd.PickSlipNo
         AND pkd.Sku = packd.Sku
        -- AND pkd.Qty = packd.Qty
      WHERE packd.PickSlipNo = @cPickSlipNo
         AND ord.StorerKey = @cStorerkey
   END TRY
   BEGIN CATCH
      SET @nErrNo = 200753
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ConfPackFail
      GOTO RollBackTran
   END CATCH

   GOTO Quit

   RollBackTran:
         ROLLBACK TRANSACTION
   Quit:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRANSACTION

GO