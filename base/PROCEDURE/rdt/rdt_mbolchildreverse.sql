SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_MbolChildReverse                                     */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Purpose: Populate orders into MBOL, MBOLDetail                             */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2022-12-23   1.0  yeekung  WMS-21334 Created                               */  
/******************************************************************************/
CREATE   PROC [RDT].[rdt_MbolChildReverse](
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cOrderKey    NVARCHAR( 10)
   ,@cPalletkey   NVARCHAR( 20)
   ,@cUDF02       NVARCHAR( 20)
   ,@cCaseID      NVARCHAR( 20)
   ,@cDropID      NVARCHAR( 20)
   ,@cRefNo3      NVARCHAR( 20)
   ,@cMBOLKey     NVARCHAR( 10)  OUTPUT
   ,@cStoreCode   NVARCHAR( 20)  OUTPUT
   ,@nErrNo       INT            OUTPUT
   ,@cErrMsg      NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   Declare @cCurCaseID Cursor
   Declare @cCurOrderkey Cursor

   
   /***********************************************************************************************
                                             Standard create
   ***********************************************************************************************/
   DECLARE @nTranCount     INT
   DECLARE @b_Success      INT
   DECLARE @cMBOlChkPlt    NVARCHAR( 20)
   DECLARE @cChkpallet     NVARCHAR(20)
   DECLARE @cUserName      NVARCHAR(20)
   DECLARE @cExternOrderkey NVARCHAR(20)
   DECLARE @cNewCaseID     NVARCHAR(20)
   
   SELECT @cUserName = UserName
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN MBOLReverse -- For rollback or commit only our own transaction

   IF @nStep ='2'
   BEGIN
      IF @cOrderKey <>''
      BEGIN
         SET @cCurOrderkey = CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT   MB.orderkey,
                  OH.Consigneekey,
                  PD.CaseID,
                  OD.ExternOrderkey
         FROM MBOLdetail MB(NOLOCK)
         JOIN ORDERS  OH  WITH (NOLOCK) ON (MB.Orderkey = OH.Orderkey)
         JOIN ORDERDETAIL  OD  WITH (NOLOCK) ON (OD.Orderkey = OH.Orderkey)
         JOIN PICKDETAIL  PD WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)           
            AND(OD.OrderLineNumber = PD.OrderLineNumber) 
         WHERE  MB.MBOLKEY = @cMBOLKey
            AND MB.Orderkey = @cOrderKey
            AND PD.storerkey=@cstorerkey

      END

      IF @cPalletkey<>''
      BEGIN
         SET @cCurOrderkey = CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT   MB.orderkey,
                  OH.Consigneekey,
                  PD.CaseID,
                  OD.ExternOrderkey
         FROM MBOLdetail MB(NOLOCK)
         JOIN ORDERS  OH  WITH (NOLOCK) ON (MB.Orderkey = OH.Orderkey)
         JOIN ORDERDETAIL  OD  WITH (NOLOCK) ON (OD.Orderkey = OH.Orderkey)
         JOIN PICKDETAIL  PD WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)           
            AND(OD.OrderLineNumber = PD.OrderLineNumber) 
         JOIN palletdetail PDL (nolock) ON PDL.caseid=PD.caseid AND PDL.storerkey=PD.storerkey
         WHERE  MB.MBOLKEY = @cMBOLKey
            AND PD.storerkey=@cstorerkey
            AND PDL.palletkey=@cpalletkey

      END
      ELSE IF @cUDF02 <> ''
      BEGIN
         SET @cCurOrderkey = CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT   MB.orderkey,
                  OH.Consigneekey,
                  PD.CaseID,
                  OD.ExternOrderkey
         FROM MBOLdetail MB(NOLOCK)
         JOIN ORDERS  OH  WITH (NOLOCK) ON (MB.Orderkey = OH.Orderkey)
         JOIN ORDERDETAIL  OD  WITH (NOLOCK) ON (OD.Orderkey = OH.Orderkey)
         JOIN PICKDETAIL  PD WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)           
            AND(OD.OrderLineNumber = PD.OrderLineNumber) 
         WHERE  MB.MBOLKEY = @cMBOLKey
            AND PD.storerkey=@cstorerkey
            AND OD.UserDefine02=@cUDF02

      END
      ELSE IF @cDropID <> ''
      BEGIN
         SET @cCurOrderkey = CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT   MB.orderkey,
                  OH.Consigneekey,
                  PD.CaseID,
                  OD.ExternOrderkey
         FROM MBOLdetail MB(NOLOCK)
         JOIN ORDERS  OH  WITH (NOLOCK) ON (MB.Orderkey = OH.Orderkey)
         JOIN ORDERDETAIL  OD  WITH (NOLOCK) ON (OD.Orderkey = OH.Orderkey)
         JOIN PICKDETAIL  PD WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)    
         JOIN DROPIDDETAIL DPD WITH (NOLOCK) ON (PD.CaseID  = DPD.ChildID)
         JOIN DROPID       DP  WITH (NOLOCK) ON (DPD.DropID = DP.DropID)
            AND(OD.OrderLineNumber = PD.OrderLineNumber) 
         WHERE  MB.MBOLKEY = @cMBOLKey
            AND PD.storerkey=@cstorerkey
            and dp.dropid = @cDropID
      END

          
      ELSE IF @cCaseID<>''
      BEGIN  
         SET @cCurOrderkey = CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT   MB.orderkey,
                  OH.Consigneekey,
                  PD.CaseID,
                  OD.ExternOrderkey
         FROM MBOLdetail MB(NOLOCK)
         JOIN ORDERS  OH  WITH (NOLOCK) ON (MB.Orderkey = OH.Orderkey)
         JOIN ORDERDETAIL  OD  WITH (NOLOCK) ON (OD.Orderkey = OH.Orderkey)
         JOIN PICKDETAIL  PD WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)   
            AND(OD.OrderLineNumber = PD.OrderLineNumber) 
         WHERE  MB.MBOLKEY = @cMBOLKey
            AND PD.storerkey=@cstorerkey
            and PD.Caseid = @cCaseID
      END


      OPEN @cCurOrderkey
      FETCH NEXT FROM @cCurOrderkey INTO @cOrderkey,@cStoreCode,@cDropID,@cExternOrderkey
      WHILE @@FETCH_STATUS = 0
      BEGIN

         EXEC [dbo].[isp_ChildOrder_Reverse]
            @cMBOLKey     
         ,   @cOrderKey
         ,   @cStoreCode       
         ,   @cExternOrderkey
         ,   @cDropID
         ,   @b_Success      OUTPUT
         ,   @nErrNo         OUTPUT
         ,   @cErrMsg        OUTPUT

         IF @nErrNo <>0  
         BEGIN
            GOTO RollBackTran
         END

         FETCH NEXT FROM @cCurOrderkey INTO @cOrderkey,@cStoreCode,@cDropID,@cExternOrderkey
      END
      CLOSE @cCurOrderkey
      DEALLOCATE @cCurOrderkey
   END
   ELSE IF @nStep ='4'
   BEGIN
      SET @cCurOrderkey = CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT   MB.orderkey,
               OH.Consigneekey,
               PD.CaseID,
               OD.ExternOrderkey
      FROM MBOLdetail MB(NOLOCK)
      JOIN ORDERS  OH  WITH (NOLOCK) ON (MB.Orderkey = OH.Orderkey)
      JOIN ORDERDETAIL  OD  WITH (NOLOCK) ON (OD.Orderkey = OH.Orderkey)
      JOIN PICKDETAIL  PD WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)           
                                    AND(OD.OrderLineNumber = PD.OrderLineNumber) 
      WHERE MB.MBOLKEY = @cMBOLKey
         AND PD.Storerkey = @cStorerkey
      OPEN @cCurOrderkey
      FETCH NEXT FROM @cCurOrderkey INTO @cOrderkey,@cStoreCode,@cDropID,@cExternOrderkey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         EXEC [dbo].[isp_ChildOrder_Reverse]
            @cMBOLKey     
         ,   @cOrderKey
         ,   @cStoreCode       
         ,   @cExternOrderkey
         ,   @cDropID
         ,   @b_Success      OUTPUT
         ,   @nErrNo         OUTPUT
         ,   @cErrMsg        OUTPUT

         IF @nErrNo <>0  
         BEGIN
            GOTO RollBackTran
         END
         FETCH NEXT FROM @cCurOrderkey INTO  @cOrderkey,@cStoreCode,@cDropID,@cExternOrderkey
      END
      CLOSE @cCurOrderkey
      DEALLOCATE @cCurOrderkey

      DELETE MBOL where MBOLKEY = @cMBOLKey
   END


   COMMIT TRAN MBOLReverse -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN  -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
      
END

GO