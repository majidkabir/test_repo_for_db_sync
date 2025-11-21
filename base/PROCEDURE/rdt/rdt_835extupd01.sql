SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_835ExtUpd01                                     */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Update ucc.status = 6 if finish pack                        */
/*                                                                      */
/* Called from: rdtfnc_Pallet_Pack                                      */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2021-06-03  1.0  James       WMS-17164.Created                       */
/* 2021-07-26  1.1  James       WMS-17549 Add update packinfo.cube      */
/*                              based on ucc.udf01 (james01)            */
/* 2021-08-04  1.2  James       Pack cfm only update ctntype (james02)  */
/************************************************************************/

CREATE PROC [RDT].[rdt_835ExtUpd01] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5), 
   @cStorerKey    NVARCHAR( 15),
   @tExtUpdate    VariableTable READONLY, 
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @cID            NVARCHAR( 18)
   DECLARE @nCount         INT = 0
   DECLARE @nRowRef        INT
   DECLARE @nTranCount     INT
   DECLARE @nCartonNo      INT
   DECLARE @cLabelNo       NVARCHAR( 20)
   DECLARE @cUserdefined01 NVARCHAR( 15)
   DECLARE @fCartonCube    FLOAT
   
   -- Variable mapping
   SELECT @cPickSlipNo = Value FROM @tExtUpdate WHERE Variable = '@cDocValue'
   SELECT @cID = Value FROM @tExtUpdate WHERE Variable = '@cPltValue'

   SET @nTranCount = @@TRANCOUNT  
  
   BEGIN TRAN  
   SAVE TRAN rdt_835ExtUpd01  
   
   IF @nStep = 2
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @nCount = 1
         FROM dbo.UCC UCC WITH (NOLOCK)
         WHERE Storerkey = @cStorerKey
         AND   Id = @cID
         AND   [Status] > '0'
         AND   [Status] < '6'
         AND   NOT EXISTS ( SELECT 1 FROM dbo.PackDetail PD WITH (NOLOCK)
                            WHERE UCC.UCCNo = PD.LabelNo
                            AND   UCC.Id = PD.DropID)
         
         IF @@ROWCOUNT = 0
         BEGIN
            DECLARE @curUPDUCC   CURSOR
            SET @curUPDUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT UCC_RowRef 
            FROM dbo.UCC WITH (NOLOCK)
            WHERE Storerkey = @cStorerKey
            AND   Id = @cID
            AND   [Status] > '0'
            AND   [Status] < '6'
            OPEN @curUPDUCC
            FETCH NEXT FROM @curUPDUCC INTO @nRowRef
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE dbo.UCC SET 
                  STATUS = '6',
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE()
               WHERE UCC_RowRef = @nRowRef
               
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 168851
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid PS#
                  GOTO RollBackTran
               END
               
               FETCH NEXT FROM @curUPDUCC INTO @nRowRef
            END
         END
         
         SELECT TOP 1 @cPickSlipNo = PickSlipNo
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   DropID = @cID
         ORDER BY 1

         -- (james02)
         IF NOT EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) 
                         WHERE PickSlipNo = @cPickSlipNo 
                         AND  [Status] = '9')
            GOTO Quit

         -- Pack confirm only process below
         -- This storer will use AssignPackLabelToOrdCfg, so packdetail.labelno = pickdetail.caseid
         DECLARE @curUPDPI CURSOR
         SET @curUPDPI = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT DISTINCT PickSlipNo, CartonNo, LabelNo
         FROM dbo.PackDetail PAD WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
         AND   EXISTS ( SELECT 1 FROM dbo.PICKDETAIL PID WITH (NOLOCK) 
                        WHERE PAD.StorerKey = PID.StorerKey 
                        AND   PAD.LabelNo = PID.CaseID 
                        AND   PAD.DropID = PID.ID)
         OPEN @curUPDPI
         FETCH NEXT FROM @curUPDPI INTO @cPickSlipNo, @nCartonNo, @cLabelNo
         WHILE @@FETCH_STATUS = 0
         BEGIN
            SELECT @cUserdefined01 = Userdefined01
            FROM dbo.UCC WITH (NOLOCK) 
            WHERE Storerkey = @cStorerKey 
            AND UCCNo = @cLabelNo 

            IF ISNULL( @cUserdefined01, '') <> ''
            BEGIN
               SELECT @fCartonCube = CZ.[Cube] 
               FROM dbo.CARTONIZATION CZ WITH (NOLOCK) 
               JOIN dbo.STORER ST WITH (NOLOCK) ON ( CZ.CartonizationGroup = ST.CartonGroup)
               WHERE CZ.CartonType = @cUserdefined01
               AND   ST.StorerKey = @cStorerKey
               
               UPDATE dbo.PackInfo SET 
               [Cube] = @fCartonCube, 
               CartonType = @cUserdefined01,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME() 
               WHERE PickSlipNo = @cPickSlipNo 
               AND   CartonNo = @nCartonNo

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 168852
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Upd PInfo Err
                  GOTO RollBackTran
               END
            END
            ELSE
            BEGIN
               UPDATE dbo.PackInfo SET 
               CartonType = 'CTN',
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME() 
               WHERE PickSlipNo = @cPickSlipNo 
               AND   CartonNo = @nCartonNo

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 168853
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Upd PInfo Err
                  GOTO RollBackTran
               END

            END
            FETCH NEXT FROM @curUPDPI INTO @cPickSlipNo, @nCartonNo, @cLabelNo
         END
      END
   END

   GOTO Quit  
  
   RollBackTran:  
         ROLLBACK TRAN rdt_835ExtUpd01  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN  

   Fail:  
END

GO