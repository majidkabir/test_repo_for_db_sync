SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_SerialNoCapture_Confirm                         */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Split PackDetail                                            */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 21-Feb-2012 1.0  Ung      SOS236331 Created                          */
/* 14-Jul-2014 1.1  James    SOS315487 - Extend length of serial no     */
/*                           from 20 to 30 chars (james01)              */
/* 17-Dec-2019 1.2  Chermaine WMS-11486 Add Eventlog (cc01)             */
/************************************************************************/

CREATE PROC [RDT].[rdt_SerialNoCapture_Confirm] (
   @nMobile     INT,
   @cLangCode   VARCHAR (3),
   @nErrNo      INT          OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT,
   @cOrderKey   NVARCHAR( 10),
   @cStorerKey  NVARCHAR( 15),
   @cSKU        NVARCHAR( 20), 
   @cLotNo      NVARCHAR( 20), 
   @cSerialNo   NVARCHAR( 30),   -- (james01)
   @nQTY        INT -- NULL means without QTY
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_success INT
   DECLARE @n_err     INT
   DECLARE @c_errmsg  NVARCHAR( 20)
   DECLARE @cOrderLineNumber NVARCHAR( 5)
   DECLARE @cSerialNoKey     NVARCHAR( 10)
   
   --(cc01)
   DECLARE 
   @cUserName NVARCHAR(18),
   @nFunc     INT,
   @cFacility NVARCHAR( 5)   
     
   SELECT 
      @cUserName  = USERNAME,
      @nFunc      = Func,
      @cFacility  = Facility  
   FROM RDT.RDTMOBREC WITH (NOLOCK)  
   WHERE MOBILE=  @nMobile; 
   
   SET @nErrNo = 0
   SET @cErrMsg = ''
   
   -- Get OrderLineNumber
   SELECT TOP 1 
      @cOrderLineNumber = OrderLineNumber 
   FROM dbo.OrderDetail WITH (NOLOCK) 
   WHERE OrderKey = @cOrderKey 
      AND SKU = @cSKU

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
      SET @nErrNo = 63781
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
      GOTO Quit
   END

   -- Insert serial no
   INSERT INTO dbo.SerialNo (SerialNoKey, OrderKey, OrderLineNumber, StorerKey, SKU, SerialNo, LotNo, QTY)
   VALUES (@cSerialNoKey, @cOrderKey, @cOrderLineNumber, @cStorerKey, @cSKU, @cSerialNo, @cLotNo, @nQTY)

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 63782
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsSNOFail
      GOTO Quit
   END
   
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '3', 
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @cSKU        = @cSKU,
      @cSerialNo   = @cSerialNo,
      @cLot        = @cLotNo,
      @nQTY        = @nQTY

Quit:

END

GO