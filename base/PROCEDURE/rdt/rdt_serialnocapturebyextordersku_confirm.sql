SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_SerialNoCaptureByExtOrderSKU_Confirm            */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2023-12-14  1.0  Ung         WMS-24364 Created                       */
/************************************************************************/

CREATE   PROC [RDT].[rdt_SerialNoCaptureByExtOrderSKU_Confirm] (
   @nMobile                   INT,
   @nFunc                     INT,
   @cLangCode                 NVARCHAR( 3),
   @nStep                     INT,
   @nInputKey                 INT,
   @cFacility                 NVARCHAR( 5),
   @cStorerkey                NVARCHAR( 15),
   @cOrderKey                 NVARCHAR( 10),
   @cExternOrderKey           NVARCHAR( 50),
   @cSKU                      NVARCHAR( 20),
   @cSerialNo                 NVARCHAR( 30),
   @nSerialQTY                INT,
   @tSerialNoCfm              VARIABLETABLE READONLY,
   @nErrNo                    INT           OUTPUT,
   @cErrMsg                   NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount        INT
   DECLARE @b_Success         INT
   DECLARE @n_err             INT
   DECLARE @c_errmsg          NVARCHAR( 20)
   DECLARE @cOrderLineNumber  NVARCHAR( 5)
   DECLARE @cSerialNoKey      NVARCHAR( 10)

   -- Get 1st line, to keep it simple. 
   SELECT TOP 1 
      @cOrderLineNumber = OrderLineNumber
   FROM dbo.Orders O WITH (NOLOCK)
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( O.OrderKey = OD.OrderKey AND O.StorerKey = OD.StorerKey)
   WHERE O.StorerKey = @cStorerKey
      AND O.OrderKey = @cOrderKey
      AND OD.SKU = @cSKU
   ORDER BY OD.OrderLineNumber

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_Confirm
   
   -- Get serial no info
   SELECT @cSerialNoKey = SerialNoKey
   FROM dbo.SerialNo WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey 
      AND SKU = @cSKU 
      AND SerialNo = @cSerialNo

   -- Existing serial no
   IF @@ROWCOUNT > 0
   BEGIN
      UPDATE dbo.SerialNo SET
         OrderKey = @cOrderKey, 
         OrderLineNumber = @cOrderLineNumber, 
         Status = '5', 
         EditDate = GETDATE(), 
         EditWho = SUSER_SNAME(), 
         TrafficCop = NULL -- Need it for shipped serial no status = 9 --> 5 (trigger will block)
      WHERE SerialNoKey = @cSerialNoKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 209651
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD SNO fail
         GOTO RollBackTran
      END
   END
   ELSE
   BEGIN
      -- Get SerialNoKey
      EXECUTE dbo.nspg_GetKey
         'SerialNo',
         10 ,
         @cSerialNoKey OUTPUT,
         @b_success    OUTPUT,
         @n_err        OUTPUT,
         @c_errmsg     OUTPUT
      IF @b_success <> 1
      BEGIN
         SET @nErrNo = 209652
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Get key fail
         GOTO RollBackTran
      END

      -- Insert serial no
      INSERT INTO dbo.SerialNo (SerialNoKey, OrderKey, OrderLineNumber, StorerKey, SKU, SerialNo, QTY, Status)
      VALUES (@cSerialNoKey, @cOrderKey, @cOrderLineNumber, @cStorerKey, @cSKU, @cSerialNo, 1, '5')
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 209653
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS SNO fail
         GOTO RollBackTran
      END
   END
   
   COMMIT TRAN rdt_Confirm
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_Confirm
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_Confirm
END

GO