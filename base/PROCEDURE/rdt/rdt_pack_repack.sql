SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Pack_Repack                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 06-05-2016 1.0  Ung         SOS368666 Created                        */
/* 06-10-2016 1.1  Ung         WMS-458 Add pack UCC                     */
/* 01-06-2017 1.2  Ung         WMS-1919 Add serial no                   */
/* 13-03-2019 1.3  Ung         WMS-8134 Add data capture                */
/* 03-10-2019 1.4  Ung         WMS-10729 Add RepackSP                   */
/************************************************************************/

CREATE PROC rdt.rdt_Pack_Repack (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cType        NVARCHAR( 10)
   ,@cPickSlipNo  NVARCHAR( 10)
   ,@nCartonNo    INT
   ,@cLabelNo     NVARCHAR( 20) 
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR(250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT
   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   DECLARE @cRepackSP   NVARCHAR( 20)

   -- Get storer configure
   SET @cRepackSP = rdt.RDTGetConfig( @nFunc, 'RepackSP', @cStorerKey)
   IF @cRepackSP = '0'
      SET @cRepackSP = ''

   /***********************************************************************************************
                                              Custom repack
   ***********************************************************************************************/
   -- Custom logic
   IF @cRepackSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cRepackSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cRepackSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
            ' @cType, @cPickSlipNo, @nCartonNo, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            ' @nMobile      INT,                  ' + 
            ' @nFunc        INT,                  ' + 
            ' @cLangCode    NVARCHAR( 3),         ' + 
            ' @nStep        INT,                  ' + 
            ' @nInputKey    INT,                  ' + 
            ' @cFacility    NVARCHAR( 5),         ' + 
            ' @cStorerKey   NVARCHAR( 15),        ' + 
            ' @cType        NVARCHAR( 10),        ' + 
            ' @cPickSlipNo  NVARCHAR( 10),        ' + 
            ' @nCartonNo    INT,                  ' + 
            ' @cLabelNo     NVARCHAR( 20),        ' + 
            ' @nErrNo       INT           OUTPUT, ' + 
            ' @cErrMsg      NVARCHAR(250) OUTPUT  '
            
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
            @cType, @cPickSlipNo, @nCartonNo, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

         GOTO Quit
      END
   END

   /***********************************************************************************************
                                             Standard repack
   ***********************************************************************************************/
   DECLARE @cLabelLine NVARCHAR(5)
   DECLARE @cFirstLine NVARCHAR(5)
   DECLARE @cSKU       NVARCHAR(20)

   SELECT TOP 1 
      @cFirstLine = LabelLine
   FROM dbo.PackDetail WITH (NOLOCK)
   WHERE PickSlipNo = @cPickSlipNo
      AND CartonNo = @nCartonNo
      AND LabelNo = @cLabelNo
   ORDER BY LabelLine

   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_Pack_Repack -- For rollback or commit only our own transaction
   
   IF @cType = 'UCC'
   BEGIN
      DELETE dbo.PackDetail
      WHERE PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo
         AND LabelNo = @cLabelNo
         AND LabelLine = @cFirstLine
      SET @nErrNo = @@ERROR 
      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 100303
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelPackDtlFail
         GOTO RollBackTran
      END
   END
   ELSE
   BEGIN
      DECLARE @curPD CURSOR
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LabelLine, SKU
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
            AND LabelNo = @cLabelNo
   
      -- Loop PackDetail
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cLabelLine, @cSKU
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Blank the 1st line (to retain the CartonNo)
         IF @cLabelLine = @cFirstLine
         BEGIN
            UPDATE PackDetail SET
               SKU = '', 
               QTY = 0, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME(), 
               ArchiveCop = NULL
            WHERE PickSlipNo = @cPickSlipNo
               AND CartonNo = @nCartonNo
               AND LabelNo = @cLabelNo
               AND LabelLine = @cLabelLine 
            SET @nErrNo = @@ERROR 
            IF @nErrNo <> 0
            BEGIN
               SET @nErrNo = 100301
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
               GOTO RollBackTran
            END
            
            -- Serial no (PackDetail update trigger does not handle PackSerialNo)
            IF EXISTS( SELECT TOP 1 1 
               FROM PackSerialNo WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
                  AND CartonNo = @nCartonNo
                  AND LabelNo = @cLabelNo
                  AND LabelLine = @cLabelLine)
            BEGIN
               DECLARE @nPackSerialNoKey BIGINT
               DECLARE @curSNO CURSOR
               SET @curSNO = CURSOR FOR
                  SELECT PackSerialNoKey 
                  FROM PackSerialNo WITH (NOLOCK) 
                  WHERE PickSlipNo = @cPickSlipNo
                     AND CartonNo = @nCartonNo
                     AND LabelNo = @cLabelNo
                     AND LabelLine = @cLabelLine
               OPEN @curSNO
               FETCH NEXT FROM @curSNO INTO @nPackSerialNoKey 
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  DELETE PackSerialNo WHERE PackSerialNoKey = @nPackSerialNoKey
                  SET @nErrNo = @@ERROR 
                  IF @nErrNo <> 0
                  BEGIN
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                     GOTO RollBackTran
                  END
                  FETCH NEXT FROM @curSNO INTO @nPackSerialNoKey 
               END
            END

            -- Pack data (PackDetail update trigger does not handle PackDetailInfo)
            IF EXISTS( SELECT TOP 1 1 
               FROM PackDetailInfo WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
                  AND CartonNo = @nCartonNo
                  AND LabelNo = @cLabelNo
                  AND LabelLine = @cLabelLine)
            BEGIN
               DECLARE @nPackDetailInfoKey BIGINT
               DECLARE @curInfo CURSOR
               SET @curInfo = CURSOR FOR
                  SELECT PackDetailInfoKey 
                  FROM PackDetailInfo WITH (NOLOCK) 
                  WHERE PickSlipNo = @cPickSlipNo
                     AND CartonNo = @nCartonNo
                     AND LabelNo = @cLabelNo
                     AND LabelLine = @cLabelLine
               OPEN @curInfo
               FETCH NEXT FROM @curInfo INTO @nPackDetailInfoKey 
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  DELETE PackDetailInfo WHERE PackDetailInfoKey = @nPackDetailInfoKey
                  SET @nErrNo = @@ERROR 
                  IF @nErrNo <> 0
                  BEGIN
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                     GOTO RollBackTran
                  END
                  FETCH NEXT FROM @curInfo INTO @nPackDetailInfoKey 
               END
            END

         END
         ELSE
         BEGIN      
            DELETE dbo.PackDetail
            WHERE PickSlipNo = @cPickSlipNo
               AND CartonNo = @nCartonNo
               AND LabelNo = @cLabelNo
               AND LabelLine = @cLabelLine
            SET @nErrNo = @@ERROR 
            IF @nErrNo <> 0
            BEGIN
               SET @nErrNo = 100302
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelPackDtlFail
               GOTO RollBackTran
            END
         END
         
         FETCH NEXT FROM @curPD INTO @cLabelLine, @cSKU
      END
   END
   
   COMMIT TRAN rdt_Pack_Repack
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_Pack_Repack -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO