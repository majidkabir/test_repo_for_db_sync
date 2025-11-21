SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Case_Pick_InsertPack                            */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Insert PackDetail, PackInfo & Generate URN label            */
/*                                                                      */
/* Called from: rdt_Case_Pick_ConfirmTask                               */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 26-Oct-2009 1.0  James       SOS151572 - Created                     */
/************************************************************************/

CREATE PROC [RDT].[rdt_Case_Pick_InsertPack] (
   @cStorerKey     NVARCHAR( 15),
   @cPickDetailKey NVARCHAR( 10),
   @cSKU           NVARCHAR( 20),
   @cPickSlipNo    NVARCHAR( 10),
   @nPD_Qty        INT,
   @nCartonNo      INT,
   @cLangCode      NVARCHAR( 3),
   @nErrNo         INT          OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max

)
AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
   @b_success           INT,
   @n_err               INT,
   @c_errmsg            NVARCHAR( 250),
   @cInterModalVehicle  NVARCHAR( 30),
   @cURNNo1             NVARCHAR( 20),
   @cURNNo2             NVARCHAR( 20),
   @cConsigneeKey       NVARCHAR( 15),
   @cExternOrderKey     NVARCHAR( 30),
   @cItemClass          NVARCHAR( 10),
   @cBUSR5              NVARCHAR( 30),
   @cBUSR3              NVARCHAR( 30),
   @cKeyname            NVARCHAR( 30),
   @cLabelNo            NVARCHAR( 20),
   @cLabelLine          NVARCHAR( 5),
   @nTranCount          INT

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN Case_Pick_InsertPack

   -- Generate label here
   SELECT @cItemClass = RTRIM(SKU.Itemclass), 
          @cBUSR5 = RTRIM(SKU.Busr5),
          @cBUSR3 = RTRIM(SKU.BUSR3)
   FROM dbo.SKU SKU WITH (NOLOCK)
   WHERE SKU.SKU = @cSKU
   AND   SKU.Storerkey = @cStorerKey

	SELECT TOP 1 
	   @cInterModalVehicle = RTRIM(O.IntermodalVehicle), 
	   @cConsigneeKey = O.ConsigneeKey, 
	   @cExternOrderKey = O.ExternOrderKey
	FROM dbo.PickDetail PD WITH (NOLOCK)
   JOIN dbo.ORDERS O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
	WHERE PD.PickDetailKey = @cPickDetailKey


   SELECT @cKeyname = @cInterModalVehicle
               
   EXECUTE dbo.nspg_getkey
    @cKeyname
  , 6
  , @cLabelNo OUTPUT
  , @b_success OUTPUT
  , @n_err OUTPUT
  , @c_errmsg OUTPUT

   IF @b_success <> 1
   BEGIN
      SET @nErrNo = 68191
      SET @cErrMsg = rdt.rdtgetmessage( 69191, @cLangCode, 'DSP') -- 'GetDetKeyFail'
      GOTO RollBackTran
   END

   SET @cURNNo1 = LEFT(@cConsigneeKey,4) + LEFT(@cInterModalVehicle,3) + LEFT(@cLabelNo,6) +
                  ISNULL(LEFT(@cBUSR5,5),'') 
   SET @cURNNo2 = RIGHT('000'+RIGHT(ISNULL(RTRIM(@cItemClass),''),3),3) +
                  LEFT(@cExternOrderKey,6) + RIGHT('000'+RTRIM(CONVERT(char(3),@nPD_Qty)),3) + '01'

   SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
   FROM dbo.PackDetail WITH (NOLOCK)
   WHERE Pickslipno = @cPickSlipNo
      AND CartonNo = @nCartonNo

   -- Insert PackDetail
   INSERT INTO dbo.PackDetail 
      (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, Refno)
   VALUES 
      (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nPD_Qty, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cPickDetailKey)

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 68192
      SET @cErrMsg = rdt.rdtgetmessage( 68192, @cLangCode, 'DSP') --'InsPDtlFail'
      GOTO RollBackTran
   END

   -- Insert PackInfo
   INSERT INTO dbo.PackInfo
     (PickSlipNo, CartonNo, AddWho, AddDate, EditWho, EditDate, CartonType, RefNo)
   VALUES 
     (@cPickSlipNo, @nCartonNo, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cBUSR3, RTRIM(@cURNNo1) + RTRIM(@cURNNo2))

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 68193
      SET @cErrMsg = rdt.rdtgetmessage( 68193, @cLangCode, 'DSP') --'InsPInfoFail'
      GOTO RollBackTran
   END
            
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN Case_Pick_InsertPack

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN Case_Pick_InsertPack
         
END

GO