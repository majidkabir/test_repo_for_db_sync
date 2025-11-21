SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1856MbolCreate02                                      */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Purpose: Populate orders into MBOL by Load                                 */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2023-03-03   1.0  yeekung    WMS-21891 CREATED                             */
/******************************************************************************/
CREATE   PROC [RDT].[rdt_1856MbolCreate02](
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
   DECLARE @cTransmethod NVARCHAR(20)

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
          OR  ISNULL(O.ECOM_PRESALE_FLAG,'') NOT IN ('','PR')))
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

   BEGIN TRAN
   SAVE TRAN rdt_1856MbolCreate02

   IF ISNULL(@cMBOLKey,'') =''
   BEGIN
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

      SELECT @cTransmethod=code
      FROM codelkup (NOLOCK)
      where listname='DEFTRANSM'
         AND code2=@cFacility
         AND storerkey=@cStorerkey

      -- Insert MBOL
      INSERT INTO MBOL (MBOLKey, ExternMBOLKey, Facility, Status, Remarks,transmethod) 
      VALUES (@cMBOLKey, '', @cFacility, '0', 'rdt_1856MbolCreate02',@cTransmethod)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 189009
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins MBOL Err
         GOTO RollBackTran
      END
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
         AND ISNULL(ECOM_PRESALE_FLAG,'') IN ('','PR')
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
   
   COMMIT TRAN rdt_1856MbolCreate02 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1856MbolCreate02 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO