SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_PrintPackingListAndGS1_GS1                      */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Print GS1 label                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 28-05-2012 1.0  Ung      SOS245083 change master and child carton    */
/*                          on tracking no, print GS1                   */
/************************************************************************/

CREATE PROC [RDT].[rdt_PrintPackingListAndGS1_GS1] (
   @nMobile     INT,
   @cLangCode   NVARCHAR( 3),
   @cPrinter    NVARCHAR(10),
   @cStorerKey  NVARCHAR( 15), 
   @cFacility   NVARCHAR( 5),
   @cPickSlipNo NVARCHAR( 10),  
   @nCartonNo   INT, 
   @cDropID     NVARCHAR( 20),
   @cType       NVARCHAR( 10),
   @cWeight     NVARCHAR( 10), 
   @nErrNo      INT  OUTPUT,
   @cErrMsg     NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE 
   @b_success   INT,
   @b_Debug     INT, 
   @cLabelNo    NVARCHAR( 20), 
   @cTCPGS1Sent NVARCHAR( 1), 
   @cRefNo      NVARCHAR( 20), 
   @cRefNo2     NVARCHAR( 20), 
   @cBatchNo    NVARCHAR( 20), 
   @cDropIDType NVARCHAR( 10), 
   @cGS1TemplatePath NVARCHAR(120),
   @cEtcTemplateID   NVARCHAR( 60)
   
IF @cType IN ('MASTER', 'NORMAL')
BEGIN   
   -- Insert PackInfo
   IF NOT EXISTS( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
   BEGIN
      INSERT INTO dbo.PackInfo (PickSlipNo, CartonNo, Weight)
      VALUES ( @cPickSlipNo, @nCartonNo, CAST( @cWeight AS FLOAT))
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 76701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPKInfoFail
         GOTO Quit
      END
   END
   ELSE
   BEGIN
   	UPDATE dbo.PackInfo WITH (ROWLOCK)
   	   SET [Weight] = CAST( @cWeight AS FLOAT)
   	WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 76702
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPKInfoFail
         GOTO Quit
      END
   END
      
   SELECT TOP 1 @cLabelNo = LabelNo
   FROM dbo.PackDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND DropID = @cDropID

   -- Get StorerConfig
   DECLARE @cAgileProcess NVARCHAR( 1)
   SET @cAgileProcess = ''
   EXECUTE nspGetRight
      @cFacility,     -- facility
      @cStorerKey,    -- Storerkey
      NULL,           -- Sku
      'AgileProcess', -- Configkey
      @b_success      OUTPUT,
      @cAgileProcess  OUTPUT,
      @nErrNo         OUTPUT,
      @cErrMsg        OUTPUT
      
   -- Send rate from Agile (carrier consolidation system)
   IF @cAgileProcess = '1'
   BEGIN
      EXEC dbo.isp1156P_Agile_Rate
          @cPickSlipNo
         ,@nCartonNo
         ,@cLabelNo
         ,@b_Success  OUTPUT
         ,@nErrNo     OUTPUT
         ,@cErrMsg    OUTPUT
      IF @nErrNo <> 0 OR @b_Success <> 1
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO Quit
      END
   END
END

-- Get GS1 parameters
SET @cEtcTemplateID = ''
IF @cType = 'MASTER'
   SELECT TOP 1 
      @cLabelNo = LabelNo, 
      @cRefNo = RefNo,
      @cRefNo2 = RefNo2
   FROM dbo.PackDetail WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey 
      AND DropID = @cDropID
ELSE
   SELECT TOP 1 @cLabelNo = LabelNo 
   FROM dbo.PackDetail WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey 
   AND DropID = @cDropID

-- Get GS1 template file
SET @cGS1TemplatePath = ''
SELECT @cGS1TemplatePath = NSQLDescrip FROM RDT.NSQLCONFIG WITH (NOLOCK) WHERE ConfigKey = 'GS1TemplatePath'

-- Print GS1 label
SET @b_success = 0
EXEC dbo.isp_PrintGS1Label
   @c_DropID    = '',
   @c_PrinterID = @cPrinter,
   @c_BtwPath   = @cGS1TemplatePath,
   @c_PickSlipNo = '',
   @n_CartonNoParm = '',
   @c_MBOLKey = '',
   @b_Success   = @b_success OUTPUT,
   @n_Err       = @nErrNo    OUTPUT,
   @c_Errmsg    = @cErrMsg   OUTPUT,
   @c_LabelNo   = @cLabelNo,
   @c_BatchNo   = @cBatchNo  OUTPUT, -- (ChewKP02)
   @c_WCSProcess = 'Y',
   @c_CartonType = @cType
   
IF @nErrNo <> 0 OR @b_success = 0
   GOTO Quit

-- Get DropIDType
SET @cDropIDType = 'NON-WCS'
SELECT @cDropIDType = DropIDType FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cDropID

-- Check GS1 send to TCP before
SET @cTCPGS1Sent = 'N'
IF EXISTS( SELECT 1 FROM dbo.TCPSocket_OutLog WITH (NOLOCK) WHERE LEFT( Data, 8) = 'GS1LABEL' AND LabelNo = @cLabelNo)
   SET @cTCPGS1Sent = 'Y'

-- Send a command to WCS
IF @cType ='MASTER' AND @cDropIDType <> 'NON-WCS' AND @cTCPGS1Sent = 'N'
BEGIN
   EXECUTE dbo.isp_TCP_WCS_GS1_Label_OUT
      @c_BatchNo        = @cBatchNo
    , @b_Debug          = @b_Debug
    , @b_Success        = @b_Success  --OUTPUT
    , @n_Err            = @nErrNo     --OUTPUT
    , @c_Errmsg         = @cErrMsg    --OUTPUT
    , @c_DeleteGS1      = 'N'
    , @c_StorerKey      = @cStorerKey
    , @c_Facility       = @cFacility
    , @c_LabelNo        = @cRefNo2
    , @c_DropID         = @cRefNo
	
END
IF @cType ='NORMAL' AND @cDropIDType <> 'NON-WCS' AND @cTCPGS1Sent = 'N'
BEGIN
   EXECUTE dbo.isp_TCP_WCS_GS1_Label_OUT
      @c_BatchNo        = @cBatchNo
    , @b_Debug          = @b_Debug
    , @b_Success        = @b_Success  --OUTPUT
    , @n_Err            = @nErrNo     --OUTPUT
    , @c_Errmsg         = @cErrMsg    --OUTPUT
    , @c_DeleteGS1      = 'N'
    , @c_StorerKey      = @cStorerKey
    , @c_Facility       = @cFacility
    , @c_LabelNo        = @cLabelNo
    , @c_DropID         = @cDropID
END

-- Insert into DropID   
IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cDropID)
BEGIN
   INSERT INTO dbo.DropID (DropID, LabelPrinted, Status) VALUES (@cDropID, '1', '9')         
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 76703
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsDropIDFail
      GOTO Quit
   END
END

-- Update DropIDDetail
IF EXISTS (SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE ChildID = @cLabelNo AND LabelPrinted = '' )
BEGIN
   UPDATE dbo.DropIDDetail SET
      LabelPrinted = 'Y'
   WHERE ChildID = @cLabelNo
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 76704
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdDDEtFail
      GOTO Quit
   END
END
Quit:

GO