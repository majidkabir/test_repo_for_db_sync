SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_593FedexLabel01                                       */
/*                                                                            */
/* Customer: Granite                                                          */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2024-09-01 1.0  NLT03      FCR-727 Create                                  */
/* 2024-10-03 1.1  NLT03      Grainte urgent case fix                         */
/* 2024-10-05 1.2  NLT03      FCR-949 new request, enhancement                */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_593FedexLabel01] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 2), 
   @cParam1    NVARCHAR(60), 
   @cParam2    NVARCHAR(60), 
   @cParam3    NVARCHAR(60), 
   @cParam4    NVARCHAR(60), 
   @cParam5    NVARCHAR(60), 
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @cDropID                   NVARCHAR( 20),
      @cShipperKey               NVARCHAR( 15),
      @c_QCmdClass               NVARCHAR(10),
      @cTransmitLogKey           NVARCHAR(10),
      @tFedexLabelList           VariableTable,
      @nRowCount                 INT,
      @bSuccess                  INT,
      @b_Debug                   INT = 0

   SET @cDropID = ISNULL(@cParam1, '')
   SET @c_QCmdClass = ''

   IF TRIM(@cDropID) = ''
   BEGIN
      SET @nErrNo = 223001
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelNoNeeded
      GOTO Quit
   END

   IF LEN(@cDropID) = 20 AND LEFT(@cDropID, 2) = '00'
      SET @cDropID = RIGHT(@cDropID, 18)

   IF NOT EXISTS(SELECT 1 FROM dbo.PACKDETAIL WITH(NOLOCK) WHERE StorerKey = @cStorerKey AND LabelNo = @cDropID)
   BEGIN
      SET @nErrNo = 223002
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidLabel
      GOTO Quit
   END

   IF EXISTS(SELECT 1 FROM dbo.Transmitlog2 WITH(NOLOCK) 
            WHERE Tablename = 'WSSOECL'
               AND Key2 = @cDropID
               AND Key3 = @cStorerkey)
   BEGIN
      UPDATE dbo.Transmitlog2 WITH(ROWLOCK) 
      SET transmitflag = '0',
         AddWho = SYSTEM_USER
      WHERE Tablename = 'WSSOECL'
         AND Key2 = @cDropID
         AND Key3 = @cStorerkey

      GOTO Quit
   END

   SELECT DISTINCT @cShipperKey = ISNULL(ORM.ShipperKey, '')
   FROM dbo.PACKDETAIL PAK WITH(NOLOCK) 
   INNER JOIN dbo.PICKDETAIL PKD WITH(NOLOCK) ON PAK.StorerKey = PKD.StorerKey AND PAK.LabelNo = ISNULL(PKD.CaseID, '')
   INNER JOIN dbo.ORDERS ORM WITH(NOLOCK) ON PKD.StorerKey = ORM.StorerKey AND PKD.OrderKey = ORM.OrderKey
   WHERE PAK.StorerKey = @cStorerKey
      AND PAK.LabelNo = @cDropID

   SELECT @nRowCount = @@ROWCOUNT

   IF @nRowCount <> 1
   BEGIN
      SET @nErrNo = 223003
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DiffSCAC
      GOTO Quit
   END

   --Remove additional space 
   SET @cShipperKey = TRIM(@cShipperKey)

   IF EXISTS(SELECT 1 FROM dbo.CODELKUP WITH(NOLOCK) WHERE StorerKey = @cStorerKey AND LISTNAME = 'WSCourier' AND @cShipperKey = ISNULL(notes,'-1'))
   BEGIN
      DECLARE @cTrauncatedDropID    NVARCHAR(10) = @cDropID
      -- Insert transmitlog2 here
      EXECUTE ispGenTransmitLog2
         @c_TableName      = 'WSSOECL',
         @c_Key1           = @cTrauncatedDropID,
         @c_Key2           = @cDropID,
         @c_Key3           = @cStorerkey,
         @c_TransmitBatch  = '',
         @b_Success        = @bSuccess   OUTPUT,
         @n_err            = @nErrNo     OUTPUT,
         @c_errmsg         = @cErrMsg    OUTPUT

      IF @bSuccess <> 1
      BEGIN
         SET @nErrNo = 223004
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenTranLogFail
         GOTO Quit
      END

      SELECT @cTransmitLogKey = transmitlogkey
      FROM dbo.TRANSMITLOG2 WITH (NOLOCK)
      WHERE tablename = 'WSSOECL'
      AND   key1 = @cTrauncatedDropID
      AND   key2 = @cDropID
      AND   key3 = @cStorerkey
      
      EXEC dbo.isp_QCmd_WSTransmitLogInsertAlert 
         @c_QCmdClass         = @c_QCmdClass, 
         @c_FrmTransmitlogKey = @cTransmitLogKey, 
         @c_ToTransmitlogKey  = @cTransmitLogKey, 
         @b_Debug             = @b_Debug, 
         @b_Success           = @bSuccess    OUTPUT, 
         @n_Err               = @nErrNo      OUTPUT, 
         @c_ErrMsg            = @cErrMsg     OUTPUT 

      IF @bSuccess <> 1
      BEGIN
         SET @nErrNo = 223005
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QCmdFail
         GOTO Quit
      END
   END
   ELSE 
   BEGIN
      SET @nErrNo = 223006
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoCODELKUP
      GOTO Quit
   END

Fail:
   RETURN
Quit:

GO