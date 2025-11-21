SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_808CloseCart03                                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Close working batch. If rdtPTLCartlog.batchkey is           */
/*          starting with 'M' allow to delete                           */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2019-12-05  1.0  James       WMS-11371. Created                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_808CloseCart03] (
    @nMobile    INT
   ,@nFunc      INT
   ,@cLangCode  NVARCHAR( 3)
   ,@nStep      INT
   ,@nInputKey  INT
   ,@cFacility  NVARCHAR(5)
   ,@cStorerKey NVARCHAR( 15)
   ,@cCartID    NVARCHAR( 10)
   ,@cPickZone  NVARCHAR( 10)
   ,@cDPLKey    NVARCHAR( 10)
   ,@nErrNo     INT           OUTPUT
   ,@cErrMsg    NVARCHAR(250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowRef        INT
   DECLARE @nPTLKey        INT
   DECLARE @nTranCount     INT
   DECLARE @nIsB2BOrders   INT
   DECLARE @nCloseCart     INT = 0
   DECLARE @cMultiPickerBatch NVARCHAR( 1)
   DECLARE @cPickConfirmStatus   NVARCHAR(1)

   SET @cPickConfirmStatus = rdt.rdtGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus <> '3'     -- 3=Pick in progress
      SET @cPickConfirmStatus = '5'  -- 5=Pick confirm

   -- If this cart is doing B2B orders which rdtPTLCartlog.batchkey is starting with æMÆ, 
   -- then allow to unassign cart and delete record else unassign cart wonÆt delete records
   IF EXISTS ( SELECT 1  
               FROM rdt.rdtPTLCartLog WITH (NOLOCK)  
               WHERE CartID = @cCartID  
               AND   DeviceProfileLogKey = @cDPLKey  
               AND   LEFT( BatchKey, 1) = 'M')  
      SET @nIsB2BOrders = 1  
   ELSE  
      SET @nIsB2BOrders = 0  
   
   IF @nIsB2BOrders = 1
      SET @nCloseCart = 1
   
   -- Check this batch got any outstanding task. If no more task then close and release cart
   IF NOT EXISTS ( SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)
                   JOIN PTL.PTLTran PTL WITH (NOLOCK) ON 
                        ( PD.OrderKey = PTL.OrderKey AND PD.PickSlipNo = PTL.SourceKey)
                   WHERE PTL.DeviceProfileLogKey = @cDPLKey
                   AND   PD.Status < @cPickConfirmStatus
                   AND   PD.Status <> '4'
                   AND   PD.QTY > 0)
      SET @nCloseCart = 1      

   IF @nCloseCart = 1
   BEGIN
      SET @nTranCount = @@TRANCOUNT
      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_PTL_Cart -- For rollback or commit only our own transaction

      -- DeviceProfileLog
      DECLARE @curDPL CURSOR
      SET @curDPL = CURSOR FOR
         SELECT RowRef
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)
         WHERE CartID = @cCartID
            AND DeviceProfileLogKey = @cDPLKey

      OPEN @curDPL
      FETCH NEXT FROM @curDPL INTO @nRowRef
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Update rdtPTLCartLog
         DELETE rdt.rdtPTLCartLog WHERE RowRef = @nRowRef
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 146901
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL DPL Fail
            GOTO RollBackTran
         END
         FETCH NEXT FROM @curDPL INTO @nRowRef
      END

      -- PTLTran
      DECLARE @curPTL CURSOR
      SET @curPTL = CURSOR FOR
         SELECT PTLKey
         FROM PTL.PTLTran WITH (NOLOCK)
         WHERE DeviceProfileLogKey = @cDPLKey
            AND Status <> '9'
      OPEN @curPTL
      FETCH NEXT FROM @curPTL INTO @nPTLKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Update DeviceProfileLog
         UPDATE PTL.PTLTran SET
            Status = '9',
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE(), 
            TrafficCop = NULL
         WHERE PTLKey = @nPTLKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 146902
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL PTL Fail
            GOTO RollBackTran
         END
         FETCH NEXT FROM @curPTL INTO @nPTLKey
      END

      COMMIT TRAN rdtfnc_PTL_Cart_CloseCart
      GOTO Quit
   
      RollBackTran:
         ROLLBACK TRAN rdt_808CloseCart03 -- Only rollback change made here
      Quit:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
   END
END

GO