SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdtfnc_PackSummary_PackConfirm                       */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Comfirm Pick                                                */
/*                                                                      */
/* Called from: rdtfnc_PackSummary                                      */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2010-08-16 1.0  ChewKP   Created                                     */
/* 2010-09-02 1.0  AQSKC    Fix logic issue (Kc01)                      */
/* 2010-09-17 1.0  AQSKC    Create PackInfo on each carton scan (Kc02)  */
/* 2018-11-12 1.1  Gan      Performance tuning                          */
/* 2021-03-10 1.2  YeeKung  RENAME packsummary_packcofirm to            */
/*                             packsummary_packconfirm (yeekung01)      */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_PackSummary_PackConfirm] (  
   @nMobile          INT,   
   @cPickSlipNo      NVARCHAR(10),
   @cStorerkey       NVARCHAR(15),
   @cPickSlipType    NVARCHAR(10),
   @cStatus          NVARCHAR(1),  -- 1 = Full Pack , 2 = Short Pack
   @cLangCode        NVARCHAR(3),
   @cUserName        NVARCHAR(18),
   @nErrNo           INT          OUTPUT,  
   @cErrMsg          NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max  
)  
AS  
BEGIN  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  
  
  
   DECLARE @nTranCount         INT  
     
   DECLARE  
    @cOrderkey       NVARCHAR(10)
   ,@nMaxCarton      INT
   ,@cSKU            NVARCHAR(20)
   ,@nQTY            INT
   ,@nCartonNo       INT
   ,@cLogPickSlipNo  NVARCHAR(20)
   ,@fWeight         FLOAT
   ,@cLabelNo        NVARCHAR(20)
   ,@cLabelLine      NVARCHAR(5)
   ,@nNoofSKU        INT
   ,@cLastSKU		   NVARCHAR(20)
   ,@nNoOfBoxPerSKU	INT
   ,@nCarton		   INT
   ,@nQtySKUPerBox	INT
   ,@nCurrentCarton	INT
   ,@nQtyToPack		INT
   ,@cUPC            NVARCHAR(30)
   ,@cRefNo2         NVARCHAR(30)
   
   -- Initialize Variable
   SET @nTranCount = @@TRANCOUNT  
   SET @cOrderkey    = ''
   SET @nMaxCarton   = 0
   SET @nQTY         = 0 
   SET @nCartonNo    = 0
   SET @cLogPickSlipNo = ''
   SET @fWeight      = 0 
   SET @cLabelNo     = ''
   SET @cLabelLine   = '00000' 
   SET @nNoofSKU     = 0
   SET @cUPC         = ''
   SET @cRefNo2      = ''
     
     
  
   BEGIN TRAN  
   SAVE TRAN PackConfirm  
   
   -- Get MaxCarton to be Pack   
   SELECT @nMaxCarton = Max(CartonNo) from rdt.RDTPackLog WITH (NOLOCK)
   WHERE Pickslipno = @cPickSlipNo 
   And   Status = '0'

   IF @cStatus = '1'
   BEGIN
      -- Get total number of distinct SKUs for the pickslip
      SELECT @nNoofSKU = ISNULL(COUNT(DISTINCT SKU),0)
      FROM  dbo.PICKDETAIL PICKDETAIL WITH (NOLOCK)
      WHERE Pickslipno = @cPickSlipNo 

      IF @nNoofSKU >= @nMaxCarton
      BEGIN
         SELECT @cLabelNo = LabelNo,
                @cUPC = UPC,
                @cRefNo2 = RefNo2 
         FROM dbo.PackDetail WITH (ROWLOCK)
         WHERE PickSlipNo = @cPickSlipNo
         AND CartonNo = @nMaxCarton


         DECLARE CUR_PACKDETAIL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT SKU, SUM(Qty)  from dbo.PickDetail PICKDETAIL WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
         GROUP BY SKU

         OPEN CUR_PACKDETAIL
         FETCH NEXT FROM CUR_PACKDETAIL INTO @cSKU, @nQTY
         WHILE @@FETCH_STATUS <> - 1
         BEGIN	
            IF EXISTS ( SELECT 1 FROM dbo.PACKDETAIL PACKDETAIL WITH (NOLOCK)
                        WHERE PickSlipNo = @cPickSlipNo AND SKU = @cSKU)
            BEGIN
               UPDATE dbo.PACKDETAIL WITH (ROWLOCK)
               SET QTY = @nQTY
               WHERE PickSlipNo = @cPickSlipNo 
               AND SKU = @cSKU

               IF @@ERROR <> 0
			      BEGIN
				      SET @nErrNo = 70921
				      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDFail'
				      GOTO RollBackTran
			      END
            END --packdetail for sku already exists
            ELSE
            BEGIN
               INSERT dbo.PackDetail
							(PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, UPC, Refno2)
               VALUES (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerkey, @cSKU, @nQty, @cUserName, GETDATE(), @cUserName, GETDATE(), @cUPC, @cRefNo2)

			      IF @@ERROR <> 0
			      BEGIN
				      SET @nErrNo = 70919
				      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDFail'
				      GOTO RollBackTran
			      END
            END --packdetail for sku does not exist
            FETCH NEXT FROM CUR_PACKDETAIL INTO @cSKU, @nQTY   
         END   
         CLOSE CUR_PACKDETAIL 
         DEALLOCATE CUR_PACKDETAIL 
      END   --@nNoofSKU >= @nMaxCarton
      ELSE
      BEGIN --@nNoofSKU < @nMaxCarton

         SET @nNoOfBoxPerSKU = @nMaxCarton / @nNoofSKU
         SET @nCurrentCarton = 1

         --retrieve last sku to be packed
         SELECT TOP 1 @cLastSKU = SKU
         FROM dbo.PICKDETAIL WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
         GROUP BY SKU
         ORDER BY SUM(QTY) DESC

         DECLARE CUR_PICKDETAIL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT SKU, SUM(Qty)  from dbo.PickDetail PICKDETAIL WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
         GROUP BY SKU
         ORDER BY SUM(QTY) ASC, SKU DESC
         
         OPEN CUR_PICKDETAIL
         FETCH NEXT FROM CUR_PICKDETAIL INTO @cSKU, @nQTY
         WHILE @@FETCH_STATUS <> - 1
         BEGIN	
            IF ISNULL(RTRIM(@cSKU),'')  = ISNULL(RTRIM(@cLastSKU),'')
            BEGIN
               --this is last sku to take up remainder of cartons
               SET @nNoOfBoxPerSKU = (@nMaxCarton / @nNoofSKU) + (@nMaxCarton % @nNoofSKU)
            END
            SET @nQtySKUPerBox = @nQty / @nNoOfBoxPerSKU

            SET @nCarton = 1
            WHILE (@nCarton <= @nNoOfBoxPerSKU)
            BEGIN
               IF @nCarton < @nNoOfBoxPerSKU
               BEGIN
                  SET @nQtyToPack = @nQtySKUPerBox
               END
               ELSE
               BEGIN
                  --last carton for the sku
                  SET @nQtyToPack = @nQtySKUPerBox + (@nQty % @nNoOfBoxPerSKU)
               END

               UPDATE dbo.PACKDETAIL WITH (ROWLOCK)
               SET   SKU = @cSKU,
                     QTY = @nQtyToPack
               WHERE PICKSLIPNO = @cPickSlipNo
               AND   CARTONNO = @nCurrentCarton

               IF @@ERROR <> 0
			      BEGIN
				      SET @nErrNo = 70926
				      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDFail'
				      GOTO RollBackTran
			      END

               SET @nCurrentCarton = @nCurrentCarton + 1
               SET @nCarton = @nCarton + 1
            END   --WHILE (@nCarton <= @nNoOfBoxPerSKU)
            
            FETCH NEXT FROM CUR_PICKDETAIL INTO @cSKU, @nQTY
         END --while
         CLOSE CUR_PICKDETAIL 
         DEALLOCATE CUR_PICKDETAIL
      END --@nNoofSKU < @nMaxCarton
   END   --@cStaus = '1'

   --(Kc02) - start
   /*
   -- Insert PackInfo (Start) --
   DECLARE CUR_PackInfo CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   
   SELECT PickSlipNo, CartonNo, Weight from rdt.rdtPackLog WITH (NOLOCK)
   WHERE PickSlipNo = @cPickSlipNo
     AND Status = '0'
   OPEN CUR_PackInfo
   FETCH NEXT FROM CUR_PackInfo INTO @cLogPickSlipNo, @nCartonNo, @fWeight
   WHILE @@FETCH_STATUS <> - 1
   BEGIN	
      
      INSERT INTO dbo.PackInfo (PickSlipNo, CartonNo, Weight)
      VALUES (@cLogPickSlipNo, @nCartonNo, @fWeight)
      
      IF @@ERROR <> 0
		BEGIN
				SET @nErrNo = 70920
				SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackIFail'
				GOTO RollBackTran
		END
		
		FETCH NEXT FROM CUR_PackInfo INTO @cLogPickSlipNo, @nCartonNo, @fWeight
      
   END
   CLOSE CUR_PackInfo 
   DEALLOCATE CUR_PackInfo
   -- Insert PackInfo (End) --
   */
   --(Kc02) - end
   
   -- Update PackHeader -- 
   UPDATE dbo.PackHeader WITH (ROWLOCK)
   SET Status = '9',
   TTLCNTS = @nMaxCarton
   WHERE PickSlipNo = @cPickSlipNo
   
   IF @@ERROR <> 0
	BEGIN
			SET @nErrNo = 70921
			SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDFail'
			GOTO RollBackTran
	END
   
   -- Update rdtPackLog --
   UPDATE rdt.RDTPackLog WITH (ROWLOCK)
   SET Status = '9'
   WHERE PickSlipNo = @cPickSlipNo
   
   IF @@ERROR <> 0
	BEGIN
			SET @nErrNo = 70922
			SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdRDTLogFail'
			GOTO RollBackTran
	END
   
   /*
   IF @cStatus = '2'
   BEGIN
      
      -- Insert PackInfo (Start) --
      DECLARE CUR_PackInfo CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      
      SELECT PickSlipNo, CartonNo, Weight from rdt.rdtPackLog WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
        AND Status = '0'
      OPEN CUR_PackInfo
      FETCH NEXT FROM CUR_PackInfo INTO @cLogPickSlipNo, @nCartonNo, @fWeight
      WHILE @@FETCH_STATUS <> - 1
      BEGIN	
         
         INSERT INTO dbo.PackInfo (PickSlipNo, CartonNo, Weight)
         VALUES (@cLogPickSlipNo, @nCartonNo, @fWeight)
         
         IF @@ERROR <> 0
			BEGIN
					SET @nErrNo = 70923
					SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackIFail'
					GOTO RollBackTran
			END
			
			FETCH NEXT FROM CUR_PackInfo INTO @cLogPickSlipNo, @nCartonNo, @fWeight
         
      END
      CLOSE CUR_PackInfo 
      DEALLOCATE CUR_PackInfo
      -- Insert PackInfo (End) --
      
      -- Update PackHeader -- 
      UPDATE dbo.PackHeader WITH (ROWLOCK)
      SET Status = '9',
      TTLCNTS = @nMaxCarton
      WHERE PickSlipNo = @cPickSlipNo
      
      IF @@ERROR <> 0
		BEGIN
				SET @nErrNo = 70924
				SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDFail'
				GOTO RollBackTran
		END
      
      
      -- Update rdtPackLog --
      UPDATE rdt.RDTPackLog WITH (ROWLOCK)
      SET Status = '9'
      WHERE PickSlipNo = @cPickSlipNo
      
      IF @@ERROR <> 0
		BEGIN
				SET @nErrNo = 70925
				SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdRDTLogFail'
				GOTO RollBackTran
		END
		
   END
         
   */   
      
   GOTO Quit  
  
   RollBackTran:  
      ROLLBACK TRAN PackConfirm  
  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN PackConfirm  
END  
  

GO