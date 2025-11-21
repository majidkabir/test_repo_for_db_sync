SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1856MbolCreate01                                      */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Purpose: Populate orders into MBOL by Load                                 */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2022-07-29   1.0  Ung        WMS-20347 Created                             */
/* 2022-09-15   1.1  Ung        WMS-20347 Add LoadPlanDetail_dellog.Status = 5*/
/* 2022-10-11   1.2  Ung        WMS-20347 Add MBOLDetail.Weight               */
/******************************************************************************/
CREATE   PROC [RDT].[rdt_1856MbolCreate01](
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cOrderKey    NVARCHAR( 10)
   ,@cLoadKey     NVARCHAR( 10)
   ,@cRefNo1      NVARCHAR( 20)
   ,@cRefNo2      NVARCHAR( 20)
   ,@cRefNo3      NVARCHAR( 20)
   ,@tMbolCreate  VariableTable READONLY
   ,@cMBOLKey     NVARCHAR( 10)  OUTPUT
   ,@nErrNo       INT            OUTPUT
   ,@cErrMsg      NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT
   DECLARE @nSuccess    INT

   DECLARE @cMsg1 NVARCHAR( 20) = '' 
   DECLARE @cMsg2 NVARCHAR( 20) = '' 
   DECLARE @cMsg3 NVARCHAR( 20) = '' 
   DECLARE @cMsg4 NVARCHAR( 20) = '' 
   DECLARE @cMsg5 NVARCHAR( 20) = '' 
   DECLARE @cMsg6 NVARCHAR( 20) = '' 
   DECLARE @cMsg7 NVARCHAR( 20) = '' 
   DECLARE @cMsg8 NVARCHAR( 20) = '' 
   DECLARE @cMsg9 NVARCHAR( 20) = '' 

   -- Check Load
   IF @cLoadKey = ''
   BEGIN
      SET @nErrNo = 189001
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LoadKey
      GOTO Quit
   END

   -- Check Load had MBOL
   IF EXISTS( SELECT TOP 1 1 
      FROM dbo.Orders O WITH (NOLOCK) 
         JOIN MBOLDetail MD WITH (NOLOCK) ON (O.OrderKey = MD.OrderKey)
      WHERE O.LoadKey = @cLoadKey)
   BEGIN
      SET @nErrNo = 189002
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Load had MBOL
      GOTO Quit
   END

   -- Check order valid
   IF NOT EXISTS (SELECT TOP 1 1 
      FROM dbo.LoadPlanDetail WITH (NOLOCK)
      WHERE LoadKey = @cLoadKey)
   BEGIN
      SET @nErrNo = 189003
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Load No Orders
      GOTO Quit
   END
   
   -- Check order completed
   IF EXISTS (SELECT TOP 1 1 
      FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
      WHERE LPD.LoadKey = @cLoadKey
         AND O.Status < '5')
   BEGIN
      SET @nErrNo = 189004
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderNotFinish
      GOTO Quit
   END
   
   -- Check order valid
   IF EXISTS (SELECT TOP 1 1 
      FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
      WHERE LPD.LoadKey = @cLoadKey
         AND (O.SOStatus NOT IN ('0','5') 
          OR  O.ECOM_PRESALE_FLAG NOT IN ('','PR')))
   BEGIN
      SET @nErrNo = 189005
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BadOrderInLoad
      GOTO Quit
   END
   
   -- Get cancel orders 
   DECLARE @nOrderRemoved INT
   SELECT @nOrderRemoved = COUNT(1) 
   FROM dbo.LoadPlanDetail_dellog WITH (NOLOCK) 
   WHERE LoadKey = @cLoadKey
      AND Status <> '5'
   
   -- Loop cancel orders
   IF @nOrderRemoved > 0
   BEGIN
      DECLARE @cLoadLineNo NVARCHAR( 5)      
      DECLARE @nRec           INT
      DECLARE @nRecInPage     INT
      DECLARE @nMaxRecInPage  INT = 8

      -- Header
      SET @cMsg1 = rdt.rdtgetmessage( 189005, @cLangCode, 'DSP') --REMOVED ORDERS: 
      SET @cMsg1 = RTRIM( @cMsg1) + ' ' + CAST( @nOrderRemoved AS NVARCHAR( 3))

      DECLARE @cLog CURSOR
      SET @cLog = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT ROW_NUMBER() OVER(ORDER BY LoadLineNumber), LoadLineNumber
         FROM dbo.LoadPlanDetail_dellog WITH (NOLOCK) 
         WHERE LoadKey = @cLoadKey
            AND Status <> '5'
         ORDER BY 1
      OPEN @cLog
      FETCH NEXT FROM @cLog INTO @nRec, @cLoadLineNo
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Determine which line on page it should go to
         SET @nRecInPage = @nRec % @nMaxRecInPage
         IF @nRecInPage = 1 SET @cMsg2 = CAST( @nRec AS NVARCHAR( 3)) + '. ' + @cLoadLineNo ELSE
         IF @nRecInPage = 2 SET @cMsg3 = CAST( @nRec AS NVARCHAR( 3)) + '. ' + @cLoadLineNo ELSE
         IF @nRecInPage = 3 SET @cMsg4 = CAST( @nRec AS NVARCHAR( 3)) + '. ' + @cLoadLineNo ELSE
         IF @nRecInPage = 4 SET @cMsg5 = CAST( @nRec AS NVARCHAR( 3)) + '. ' + @cLoadLineNo ELSE
         IF @nRecInPage = 5 SET @cMsg6 = CAST( @nRec AS NVARCHAR( 3)) + '. ' + @cLoadLineNo ELSE
         IF @nRecInPage = 6 SET @cMsg7 = CAST( @nRec AS NVARCHAR( 3)) + '. ' + @cLoadLineNo ELSE
         IF @nRecInPage = 7 SET @cMsg8 = CAST( @nRec AS NVARCHAR( 3)) + '. ' + @cLoadLineNo ELSE
         IF @nRecInPage = 0 SET @cMsg9 = CAST( @nRec AS NVARCHAR( 3)) + '. ' + @cLoadLineNo 

         -- If page is full, send out
         IF @nRec % @nMaxRecInPage = 0
         BEGIN
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @cMsg1, @cMsg2, @cMsg3, @cMsg4, @cMsg5, @cMsg6, @cMsg7, @cMsg8, @cMsg9
            SELECT @cMsg2 = '', @cMsg3 = '', @cMsg4 = '', @cMsg5 = '', @cMsg6 = '', @cMsg7 = '', @cMsg8 = '', @cMsg9 = ''
         END
         
         FETCH NEXT FROM @cLog INTO @nRec, @cLoadLineNo
      END
      
      -- If page not full, send out
      IF @nRec % @nMaxRecInPage <> 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @cMsg1, @cMsg2, @cMsg3, @cMsg4, @cMsg5, @cMsg6, @cMsg7, @cMsg8, @cMsg9
   END
   ELSE
   BEGIN
      SET @cMsg2 = rdt.rdtgetmessage( 189006, @cLangCode, 'DSP') --NO CANCEL ORDER 
      EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @cMsg1, @cMsg2, @cMsg3, @cMsg4, @cMsg5, @cMsg6, @cMsg7, @cMsg8, @cMsg9
   END

   -- Get new MBOLKey
   SET @nSuccess = 1
   EXECUTE dbo.nspg_getkey
      'MBOL'
      , 10
      , @cMBOLKey    OUTPUT
      , @nSuccess    OUTPUT
      , @nErrNo      OUTPUT
      , @cErrMsg     OUTPUT
   IF @nSuccess <> 1
   BEGIN
      SET @nErrNo = 189008
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey fail
      GOTO RollBackTran
   END

   BEGIN TRAN
   SAVE TRAN rdt_1856MbolCreate01

   -- Insert MBOL
   INSERT INTO MBOL (MBOLKey, ExternMBOLKey, Facility, Status, Remarks) 
   VALUES (@cMBOLKey, '', @cFacility, '0', 'rdt_1856MbolCreate01')
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 189009
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins MBOL Err
      GOTO RollBackTran
   END

   -- Loop orders
   DECLARE @cExternOrderKey NVARCHAR( 50)
   DECLARE @nWeight FLOAT
   DECLARE @curOrder CURSOR
   SET @curOrder = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderKey, ExternOrderKey 
      FROM dbo.Orders WITH (NOLOCK)
      WHERE LoadKey = @cLoadKey
         AND Status = '5'
         AND SOStatus IN ('0','5') 
         AND ECOM_PRESALE_FLAG IN ('','PR')
   OPEN @curOrder
   FETCH NEXT FROM @curOrder INTO @cOrderKey, @cExternOrderKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Get order weight
      SELECT @nWeight = ISNULL( SUM( PInf.Weight), 0)
      FROM dbo.PackHeader PH WITH (NOLOCK)
         JOIN dbo.PackInfo PInf WITH (NOLOCK) ON (PH.PickSlipNo = PInf.PickSlipNo)
      WHERE PH.StorerKey = @cStorerKey
         AND PH.OrderKey = @cOrderKey
      
      -- Insert MBOLDetail
      INSERT INTO dbo.MBOLDetail
         (MBOLKey, MBOLLineNumber, OrderKey, LoadKey, ExternOrderKey, Weight, AddWho, AddDate, EditWho, EditDate)
      VALUES
         (@cMBOLKey, '00000', @cOrderKey, @cLoadKey, @cExternOrderKey, @nWeight, SUSER_SNAME(), GETDATE(), SUSER_SNAME(), GETDATE())
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 189010
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins MBOLDtl Err
         GOTO RollBackTran
      END

      FETCH NEXT FROM @curOrder INTO @cOrderKey, @cExternOrderKey
   END

   -- MBOL ship
   UPDATE dbo.MBOL SET
      Status = '9', 
      EditWho = SUSER_SNAME(), 
      EditDate = GETDATE()
   WHERE MBOLKey = @cMBOLKey
   SET @nErrNo = @@ERROR 
   IF @nErrNo <> 0
   BEGIN
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
      GOTO RollBackTran
   END
   
   COMMIT TRAN rdt_1856MbolCreate01 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1856MbolCreate01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO