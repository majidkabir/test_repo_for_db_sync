SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PickAndPack_InsPack                             */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Comfirm Pick                                                */
/*                                                                      */
/* Called from: rdtfnc_PickAndPack                                      */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 14-Mar-2011 1.0  James       Created                                 */
/* 17-Mar-2011 1.1  James       Add in eventlog                         */
/* 19-Nov-2012 1.2  James       SOS261710 Store DropID as Labelno by    */
/*                              using configkey (james01)               */
/*                              Extend DropID to NVARCHAR(20)           */
/* 26-Mar-2014 1.3  James       SOS305925 - Add LoadKey (james02)       */
/* 02-Jun-2014 1.4  TLTING      Deadlock Tune                           */
/* 11-Oct-2016 1.5  SHONG01     Performance Tuning                      */
/* 11-Oct-2016 1.6  James       Performance Tuning                      */
/* 30-Mar-202a 1.7  James       WMS-16695 Add GenLabelNoSP (james03)    */
/************************************************************************/

CREATE PROC [RDT].[rdt_PickAndPack_InsPack] (
   @nMobile          INT,
   @nFunc            INT, 
   @cStorerKey       NVARCHAR( 15),
   @cUserName        NVARCHAR( 15),
   @cOrderKey        NVARCHAR( 10),
   @cSKU             NVARCHAR( 20),
   @cPickSlipNo      NVARCHAR( 10),
   @cDropID          NVARCHAR( 20),     -- (james01)
   @cLoadKey         NVARCHAR( 10),     -- (james02)
   @cLangCode        NVARCHAR( 3),
   @nErrNo           INT          OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT  

)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_success  INT,
   @n_err              INT,
   @c_errmsg           NVARCHAR( 250),
   @nPickQty           INT,
   @nRowRef            INT,
   @nTranCount         INT,
   @nPackQty           INT,
   @nCartonNo          INT,
   @cLabelNo           NVARCHAR( 20),
   @cLabelLine         NVARCHAR( 5),
   @cUOM               NVARCHAR( 10), 
   @cFacility          NVARCHAR( 5), 
   @nTotalPickedQty    INT,   
   @nTotalPackedQty    INT

   DECLARE 
   @cT_PickHeaderKey  NVARCHAR( 10), 
   @cT_OrderKey       NVARCHAR( 10), 
   @cSum_PickedQty    INT, 
   @cSum_PackedQty    INT
        
   DECLARE 
   @cSQLSelect        NVARCHAR(1000)  

   DECLARE @cGenLabelNo_SP    NVARCHAR( 20)
   DECLARE @cSQL              NVARCHAR( MAX)
   DECLARE @cSQLParam         NVARCHAR( MAX)
   
	SET @cSQLSelect = N''
		
	IF @cLoadKey <> ''
		SET @cOrderKey = ''
		  
	SELECT @cFacility = Facility FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

   SET @cGenLabelNo_SP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo_SP', @cStorerkey)  
   IF @cGenLabelNo_SP = '0'  
      SET @cGenLabelNo_SP = ''  

	SET @nTranCount = @@TRANCOUNT
		
	BEGIN TRAN
	SAVE TRAN PickAndPack_InsPack

	SELECT @cUOM = RTRIM(PACK.PACKUOM3)
	FROM dbo.PACK PACK WITH (NOLOCK)
	JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
	WHERE SKU.Storerkey = @cStorerKey
	AND   SKU.SKU = @cSKU

	IF @cOrderKey = ''
   BEGIN
		DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
		SELECT PickHeaderKey, OrderKey FROM dbo.PickHeader WITH (NOLOCK) 
		WHERE ExternOrderKey = @cLoadKey
		OPEN CUR_LOOP
		FETCH NEXT FROM CUR_LOOP INTO @cT_PickHeaderKey, @cT_OrderKey
		WHILE @@FETCH_STATUS <> -1
		BEGIN
      SELECT @cSum_PickedQty = ISNULL( SUM( QTY), 0)
      FROM dbo.PickDetail WITH (NOLOCK) 
      WHERE OrderKey = @cT_OrderKey
      AND   SKU = @cSKU

      SELECT @cSum_PackedQty = ISNULL( SUM( QTY), 0)
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE PickSlipNo = @cT_PickHeaderKey
      AND   SKU = @cSKU

      IF @cSum_PickedQty > @cSum_PackedQty
      BEGIN
         SET @cOrderKey = @cT_OrderKey
         -- tlting01 - Start deadlock tune
         IF EXISTS ( SELECT 1 FROM RDT.RDTPickLock WITH (NOLOCK)
         WHERE LoadKey = @cLoadKey
            AND DropID = @cDropID
            AND Status = '1'
            AND AddWho = @cUserName
            AND SKU = @cSKU )
         BEGIN
               
            DECLARE CUR_RDTPickLockLOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            SELECT RowRef FROM RDT.RDTPickLock WITH (NOLOCK)
            WHERE LoadKey = @cLoadKey
            AND DropID = @cDropID
            AND Status = '1'
            AND AddWho = @cUserName
            AND SKU = @cSKU
            OPEN CUR_RDTPickLockLOOP
            FETCH NEXT FROM CUR_RDTPickLockLOOP INTO @nRowRef
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               
               UPDATE RDT.RDTPickLock WITH (ROWLOCK) 
               SET OrderKey = @cOrderKey,
                  EditDate = GETDATE(),
                  EditWho = SUSER_SNAME() 
               WHERE RowRef = @nRowRef
               
               FETCH NEXT FROM CUR_RDTPickLockLOOP INTO @nRowRef
            END
            CLOSE CUR_RDTPickLockLOOP
            DEALLOCATE CUR_RDTPickLockLOOP               
         END
         -- tlting01 - End deadlock tune
            
         BREAK            
      END
      FETCH NEXT FROM CUR_LOOP INTO @cT_PickHeaderKey, @cT_OrderKey
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP
      
   IF @cOrderKey = '' 
   BEGIN
      SET @nErrNo = 66039
      SET @cErrMsg = rdt.rdtgetmessage( 66039, @cLangCode, 'DSP') --'SKU Overpacked'
      GOTO RollBackTran
		END
	END
   
	SET @cPickSlipNo = ''
    SET @nTotalPickedQty = 0 

    IF ISNULL( @cOrderKey, '') = ''
    BEGIN
       SELECT @cPickSlipNo = PickHeaderKey 
       FROM dbo.PickHeader WITH (NOLOCK) 
       WHERE ExternOrderKey = @cLoadKey

       SELECT @nTotalPickedQty = ISNULL(SUM(QTY), 0) 
       FROM dbo.PickDetail PD WITH (NOLOCK) 
       JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
       JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
       WHERE PD.StorerKey = @cStorerKey
       AND   O.LoadKey = @cLoadKey
       AND   PD.SKU = @cSKU
    END
    ELSE
    BEGIN
       SELECT @cPickSlipNo = PickHeaderKey 
       FROM dbo.PickHeader WITH (NOLOCK) 
       WHERE OrderKey = @cOrderKey

       SELECT @nTotalPickedQty = ISNULL(SUM(QTY), 0) 
       FROM dbo.PickDetail PD WITH (NOLOCK) 
       JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
       JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
       WHERE PD.StorerKey = @cStorerKey
       AND   PD.OrderKey = @cOrderKey
       AND   PD.SKU = @cSKU
    END

		-- Get total qty that need to be packed
		SELECT @nPackQty =  ISNULL(SUM(PickQty), 0)
		FROM RDT.RDTPickLock WITH (NOLOCK)
		WHERE StorerKey = @cStorerKey
			AND OrderKey = CASE WHEN @cOrderKey = '' THEN OrderKey ELSE @cOrderKey END
			AND LoadKey = CASE WHEN @cLoadKey = '' THEN LoadKey ELSE @cLoadKey END
			AND SKU = @cSKU
			AND Status = '1'
			AND AddWho = @cUserName
			AND DropID = @cDropID 
      
    SET @nTotalPackedQty = 0 
    SELECT @nTotalPackedQty = ISNULL(SUM(QTY), 0) 
    FROM dbo.PackDetail WITH (NOLOCK)
    WHERE StorerKey = @cStorerKey
       AND PickSlipNo = @cPickSlipNo
       AND SKU = @cSKU

    IF (@nTotalPackedQty + @nPackQty) > @nTotalPickedQty 
    BEGIN
       SET @nErrNo = 66039
       SET @cErrMsg = rdt.rdtgetmessage( 66039, @cLangCode, 'DSP') --'SKU Overpacked'
       GOTO RollBackTran
    END
            
    -- Same DropID + PickSlipNo will group SKU into a carton. 1 carton could be multi sku
    IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
       WHERE StorerKey = @cStorerKey
          AND PickSlipNo = @cPickSlipNo
          AND DropID = @cDropID)
    BEGIN
       IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)
       BEGIN
          INSERT INTO dbo.PackHeader
          (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
          SELECT O.Route, O.OrderKey, SUBSTRING(O.ExternOrderKey, 1, 18), O.LoadKey, O.ConsigneeKey, @cStorerkey, @cPickSlipNo -- SOS# 176144
          FROM  dbo.PickHeader PH WITH (NOLOCK)
          JOIN  dbo.Orders O WITH (NOLOCK) ON (PH.Orderkey = O.Orderkey)
          WHERE PH.PickHeaderKey = @cPickSlipNo

          IF @@ERROR <> 0
          BEGIN
             SET @nErrNo = 66040
             SET @cErrMsg = rdt.rdtgetmessage( 66040, @cLangCode, 'DSP') --'InsPHdrFail'
             GOTO RollBackTran
          END 
       END

       SET @nCartonNo = 0

       SET @cLabelNo = ''
       
       IF rdt.RDTGetConfig( @nFunc, 'PickAndPackUseDropIDAsLblNo', @cStorerKey) = '1' -- (james01)
       BEGIN
          SET @cLabelNo = @cDropID
       END
       ELSE
       BEGIN
         IF @cGenLabelNo_SP <> '' AND  
            EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGenLabelNo_SP AND type = 'P')
         BEGIN
            SET @nErrNo = 0
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cGenLabelNo_SP) +     
               ' @nMobile, @nFunc, @cLangCode, @cFacility, @cStorerkey, ' + 
               ' @cLoadKey, @cOrderKey, @cPickSlipNo, @cDropID, @cSKU, ' +
               ' @cLabelNo OUTPUT, @nCartonNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

               SET @cSQLParam =    
                  '@nMobile                   INT,           ' +
                  '@nFunc                     INT,           ' +
                  '@cLangCode                 NVARCHAR( 3),  ' +
                  '@cFacility                 NVARCHAR( 5),  ' +
                  '@cStorerkey                NVARCHAR( 15), ' +
                  '@cLoadKey                  NVARCHAR( 10), ' +
                  '@cOrderKey                 NVARCHAR( 10), ' +
                  '@cPickSlipNo               NVARCHAR( 10), ' +
                  '@cDropID                   NVARCHAR( 20), ' +
                  '@cSKU                      NVARCHAR( 20), ' +
                  '@cLabelNo                  NVARCHAR( 20) OUTPUT, ' +
                  '@nCartonNo                 INT           OUTPUT, ' +
                  '@nErrNo                    INT           OUTPUT, ' +
                  '@cErrMsg                   NVARCHAR( 20) OUTPUT  ' 
               
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
                  @nMobile, @nFunc, @cLangCode, @cFacility, @cStorerkey, 
                  @cLoadKey, @cOrderKey, @cPickSlipNo, @cDropID, @cSKU, 
                  @cLabelNo OUTPUT, @nCartonNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 
                  
            IF @nErrNo <> 0
            BEGIN
               SET @nErrNo = 66041
               SET @cErrMsg = rdt.rdtgetmessage( 66038, @cLangCode, 'DSP') --'GenLabelFail'
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
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
               SET @nErrNo = 66038
               SET @cErrMsg = rdt.rdtgetmessage( 66038, @cLangCode, 'DSP') --'GenLabelFail'
               GOTO RollBackTran
            END
         END
       END
       
       INSERT INTO dbo.PackDetail
          (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)
       VALUES
          (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSku, @nPackQty,
          '', 'rdt1.' + sUser_sName(), GETDATE(), 'rdt1.' + sUser_sName(), GETDATE(), @cDropID)

       IF @@ERROR <> 0
       BEGIN
          SET @nErrNo = 66035
          SET @cErrMsg = rdt.rdtgetmessage( 66035, @cLangCode, 'DSP') --'InsPackDtlFail'
          GOTO RollBackTran
       END 
       ELSE
       BEGIN
          EXEC RDT.rdt_STD_EventLog
            @cActionType   = '3', -- Picking
            @cUserID       = @cUserName,
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerkey,
            @cLocation     = '',
            @cID           = @cDropID,
            @cSKU          = @cSKU,
            @cUOM          = @cUOM,
            @nQTY          = @nPackQty,
            @cLot          = '',
            @cRefNo1       = '',
            @cRefNo2       = '',
            @cRefNo3       = @cOrderKey,
            @cRefNo4       = @cPickSlipNo, 
            @cDropID       = @cDropID 
       END
    END -- DropID not exists
    ELSE
		BEGIN
			IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
			WHERE StorerKey = @cStorerKey
				AND PickSlipNo = @cPickSlipNo
				AND DropID = @cDropID
				AND SKU = @cSKU)
			BEGIN
				SET @nCartonNo = 0

        SET @cLabelNo = ''

        SELECT @nCartonNo = CartonNo, @cLabelNo = LabelNo 
        FROM dbo.PackDetail WITH (NOLOCK)
        WHERE Pickslipno = @cPickSlipNo
           AND StorerKey = @cStorerKey
           AND DropID = @cDropID

        SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
        FROM dbo.PackDetail WITH (NOLOCK)
        WHERE Pickslipno = @cPickSlipNo
           AND CartonNo = @nCartonNo
           AND DropID = @cDropID

        INSERT INTO dbo.PackDetail
           (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)
        VALUES
           (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSku, @nPackQty,
           '', 'rdt1.' + sUser_sName(), GETDATE(), 'rdt1.' + sUser_sName(), GETDATE(), @cDropID)

        IF @@ERROR <> 0
        BEGIN
           SET @nErrNo = 66036
           SET @cErrMsg = rdt.rdtgetmessage( 66036, @cLangCode, 'DSP') --'InsPackDtlFail'
           GOTO RollBackTran
        END 
        ELSE
        BEGIN
           EXEC RDT.rdt_STD_EventLog
             @cActionType   = '3', -- Picking
             @cUserID       = @cUserName,
             @nMobileNo     = @nMobile,
             @nFunctionID   = @nFunc,
             @cFacility     = @cFacility,
             @cStorerKey    = @cStorerkey,
             @cLocation     = '',
             @cID           = @cDropID,
             @cSKU          = @cSKU,
             @cUOM          = @cUOM,
             @nQTY          = @nPackQty,
             @cLot          = '',
             @cRefNo1       = '',
             @cRefNo2       = '',
             @cRefNo3       = @cOrderKey,
             @cRefNo4       = @cPickSlipNo, 
             @cDropID       = @cDropID 
				END
			END   -- DropID exists but SKU not exists (insert new line with same cartonno)
			ELSE
			BEGIN
				UPDATE dbo.PackDetail WITH (ROWLOCK) SET
				   QTY = QTY + @nPackQty,
				   EditDate = GETDATE(),
				   EditWho = SUSER_SNAME()
				WHERE StorerKey = @cStorerKey
				   AND PickSlipNo = @cPickSlipNo
				   AND DropID = @cDropID
				   AND SKU = @cSKU

				IF @@ERROR <> 0
				BEGIN
				   SET @nErrNo = 66037
				   SET @cErrMsg = rdt.rdtgetmessage( 66037, @cLangCode, 'DSP') --'UpdPackDtlFail'
				   GOTO RollBackTran
				END
				ELSE
				BEGIN
				   EXEC RDT.rdt_STD_EventLog
				     @cActionType   = '3', -- Picking
				     @cUserID       = @cUserName,
				     @nMobileNo     = @nMobile,
				     @nFunctionID   = @nFunc,
				     @cFacility     = @cFacility,
				     @cStorerKey    = @cStorerkey,
				     @cLocation     = '',
				     @cID           = @cDropID,
				     @cSKU          = @cSKU,
				     @cUOM          = @cUOM,
				     @nQTY          = @nPackQty,
				     @cLot          = '',
				     @cRefNo1       = '',
				     @cRefNo2       = '',
				     @cRefNo3       = @cOrderKey,
				     @cRefNo4       = @cPickSlipNo, 
				     @cDropID       = @cDropID 
				END
			END   -- DropID exists and SKU exists (update qty only)
		END
		
		-- Stamp RPL's candidate to '5'
		UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
		   Status = '9',   -- Picked
		   EditDate = GETDATE(),
		   EditWho = SUSER_SNAME()
		WHERE StorerKey = @cStorerKey
		AND OrderKey = CASE WHEN @cOrderKey = '' THEN OrderKey ELSE @cOrderKey END
		AND LoadKey = CASE WHEN @cLoadKey = '' THEN LoadKey ELSE @cLoadKey END
		AND SKU = @cSKU
		AND Status = '1'
		AND AddWho = @cUserName

    IF @@ERROR <> 0
    BEGIN
       SET @nErrNo = 66033
       SET @cErrMsg = rdt.rdtgetmessage( 66033, @cLangCode, 'DSP') --'UPDPKLockFail'
       GOTO RollBackTran
    END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN PickAndPack_InsPack

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN PickAndPack_InsPack
END

GO