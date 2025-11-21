SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtUpd07                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2019-11-04 1.0  James       WMS-10890. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_838ExtUpd07] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cPickSlipNo      NVARCHAR( 10),
   @cFromDropID      NVARCHAR( 20),
   @nCartonNo        INT,
   @cLabelNo         NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cUCCNo           NVARCHAR( 20),
   @cCartonType      NVARCHAR( 10),
   @cCube            NVARCHAR( 10),
   @cWeight          NVARCHAR( 10),
   @cRefNo           NVARCHAR( 20),
   @cSerialNo        NVARCHAR( 30),
   @nSerialQTY       INT,
   @cOption          NVARCHAR( 1),
   @cPackDtlRefNo    NVARCHAR( 20), 
   @cPackDtlRefNo2   NVARCHAR( 20), 
   @cPackDtlUPC      NVARCHAR( 30), 
   @cPackDtlDropID   NVARCHAR( 20), 
   @cPackData1       NVARCHAR( 30), 
   @cPackData2       NVARCHAR( 30), 
   @cPackData3       NVARCHAR( 30), 
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLabelLine     NVARCHAR(5)
   DECLARE @nTranCount     INT
   DECLARE @curPD          CURSOR
   DECLARE @cPackDetailCartonID  NVARCHAR( 20)   
   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   

   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nStep = 6 --Print packlist
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF @cOption = '1'
            BEGIN
               -- Set focus on to Drop Id
               EXEC rdt.rdtSetFocusField @nMobile, 3
            END
         END
      END
      
      IF @nStep = 7 --Repack
      BEGIN
         IF @cOption = 1 --Yes to repack
         BEGIN
            SET @nTranCount = @@TRANCOUNT
            BEGIN TRAN
            SAVE TRAN rdt_Repack
      
            SET @cPackDetailCartonID = rdt.RDTGetConfig( @nFunc, 'PackDetailCartonID', @cStorerKey)
            IF @cPackDetailCartonID = '0' -- DropID/LabelNo/RefNo/RefNo2/UPC/NONE
               SET @cPackDetailCartonID = 'DropID'

            SELECT @cPackDtlRefNo = V_String9
            FROM RDT.RDTMOBREC R WITH (NOLOCK)
            WHERE R.Mobile = @nMobile

            SET @cSQL =   
            ' SELECT CartonNo, LabelNo, LabelLine ' +   
            ' FROM dbo.PackDetail WITH (NOLOCK) ' +
            ' WHERE PickSlipNo = @cPickSlipNo ' +
            ' AND ' + @cPackDetailCartonID + ' = ''' +  @cPackDtlRefNo + '''' + 
            ' ORDER BY CartonNo '       

            -- Open cursor  
            SET @cSQL =   
               ' SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR ' +   
                  @cSQL +   
               ' OPEN @curPD '   

            SET @cSQLParam = 
               '@curPD        CURSOR OUTPUT, ' + 
               '@nFunc        INT, '           + 
               '@cStorerKey   NVARCHAR( 15), ' +  
               '@cPickSlipNo  NVARCHAR( 10), ' +  
               '@nCartonNo    INT            OUTPUT, ' +  
               '@cLabelNo     NVARCHAR( 20)  OUTPUT, ' +  
               '@cLabelLine   NVARCHAR( 5)   OUTPUT ' 

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
               @curPD OUTPUT, @nFunc, @cStorerKey, @cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine

            FETCH NEXT FROM @curPD INTO @nCartonNo, @cLabelNo, @cLabelLine
            WHILE @@FETCH_STATUS = 0
            BEGIN
               DELETE FROM dbo.PackDetail
               WHERE PickSlipNo = @cPickSlipNo
               AND   CartonNo = @nCartonNo
               AND   LabelNo = @cLabelNo
               AND   LabelLine = @cLabelLine
               
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 146301
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Repack Error 
                  GOTO Repack_RollBackTran                  
               END

               FETCH NEXT FROM @curPD INTO @nCartonNo, @cLabelNo, @cLabelLine
            END
            
            GOTO Repack_Quit

            Repack_RollBackTran:
               ROLLBACK TRAN rdt_Repack

            Repack_Quit:
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
         END
      END
   END

   Quit:

END

GO