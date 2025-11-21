SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_MbolChildCreation                                     */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Purpose: Populate orders into MBOL, MBOLDetail                             */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2022-12-23   1.0  yeekung  WMS-21331 Created                               */  
/******************************************************************************/
CREATE   PROC [RDT].[rdt_MbolChildCreation](
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cPalletkey   NVARCHAR( 20)
   ,@cCaseID      NVARCHAR( 20)
   ,@cDropID      NVARCHAR( 20)
   ,@cUserdefine02    NVARCHAR( 20)
   ,@cMBOLKey     NVARCHAR( 10)  OUTPUT
   ,@cStoreCode   NVARCHAR( 20)  OUTPUT
   ,@nCaseCnt     INT            OUTPUT 
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
   DECLARE @cOrderkey      NVARCHAR(20)
   DECLARE @cNewCaseID     NVARCHAR(20)
   DECLARE @cAllowIDBlank   NVARCHAR(20)
   DECLARE @cStoreChild    NVARCHAR(20)
   
   SELECT @cUserName = UserName
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @cAllowIDBlank = rdt.rdtGetConfig( @nFunc, 'AllowIDBlank', @cStorerKey)      
   IF @cAllowIDBlank = '0'      
      SET @cAllowIDBlank = ''  
   
   SET @nCaseCnt = 0

   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN MbolCreation -- For rollback or commit only our own transaction

   IF @cPalletkey<>''
   BEGIN

      IF ISNULL(@cAllowIDBlank,'') <> ''
      BEGIN
         SELECT @nCaseCnt= COUNT(DISTINCT PD.CaseID)
         FROM palletdetail PDL (nolock)
         JOIN pickdetail PD (NOLOCK) ON PDL.caseid=PD.caseid AND PDL.storerkey=PD.storerkey
         where PDL.Palletkey = @cPalletkey
            and PD.storerkey = @cstorerkey
            AND ISNULL(PD.CASEID,'') <> ''
            AND ISNULL(PD.ID,'') <> ''

         SET @cCurOrderkey = CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT PD.orderkey,PD.CaseID
         FROM palletdetail PDL (nolock)
         JOIN pickdetail PD (NOLOCK) ON PDL.caseid=PD.caseid AND PDL.storerkey=PD.storerkey
         where PDL.Palletkey = @cPalletkey
            and PD.storerkey = @cstorerkey
            AND ISNULL(PD.CASEID,'') <> ''
            AND ISNULL(PD.ID,'') <> ''
         GROUP BY  PD.orderkey,PD.CaseID
      END
      ELSE
      BEGIN
         SELECT @nCaseCnt= COUNT(DISTINCT PD.CaseID)
         FROM palletdetail PDL (nolock)
         JOIN pickdetail PD (NOLOCK) ON PDL.caseid=PD.caseid AND PDL.storerkey=PD.storerkey
         where PDL.Palletkey = @cPalletkey
            and PD.storerkey = @cstorerkey
            AND ISNULL(PD.CASEID,'') <> ''

         SET @cCurOrderkey = CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT PD.orderkey,PD.CaseID
         FROM palletdetail PDL (nolock)
         JOIN pickdetail PD (NOLOCK) ON PDL.caseid=PD.caseid AND PDL.storerkey=PD.storerkey
         where PDL.Palletkey = @cPalletkey
            and PD.storerkey = @cstorerkey
            AND ISNULL(PD.CASEID,'') <> ''
         GROUP BY  PD.orderkey,PD.CaseID
      END
   END
    
   IF @cCaseID<>''
   BEGIN  
      IF ISNULL(@cAllowIDBlank,'') <> ''
      BEGIN
         SELECT @nCaseCnt= COUNT(DISTINCT PD.CaseID)
         FROM  pickdetail PD (NOLOCK)
         where PD.CaseID = @cCaseID
            AND PD.storerkey = @cstorerkey
            AND ISNULL(CASEID,'') <> ''

         SET @cCurOrderkey = CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT PD.orderkey,PD.CaseID
         FROM  pickdetail PD (NOLOCK)
         where PD.CaseID = @cCaseID
            AND PD.storerkey = @cstorerkey
            AND ISNULL(CASEID,'') <> ''
         GROUP BY  PD.orderkey,PD.CaseID
      END
      ELSE
      BEGIN
         SELECT @nCaseCnt= COUNT(DISTINCT PD.CaseID)
         FROM  pickdetail PD (NOLOCK)
         where PD.CaseID = @cCaseID
            AND PD.storerkey = @cstorerkey
            AND ISNULL(CASEID,'') <> ''
             AND ISNULL(PD.ID,'') <> ''

         SET @cCurOrderkey = CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT PD.orderkey,PD.CaseID
         FROM  pickdetail PD (NOLOCK)
         where PD.CaseID = @cCaseID
            AND PD.storerkey = @cstorerkey
            AND ISNULL(CASEID,'') <> ''
            AND ISNULL(PD.ID,'') <> ''
         GROUP BY  PD.orderkey,PD.CaseID
      END
   END

   IF @cDropID <> ''
   BEGIN
      IF ISNULL(@cAllowIDBlank,'') <> ''
      BEGIN
         SELECT @nCaseCnt= COUNT(DISTINCT PD.CaseID)
         FROM dropiddetail DP (nolock)
            JOIN pickdetail PD (NOLOCK) ON DP.childid=PD.caseid
         where dp.dropid=@cDropID
            AND ISNULL(CASEID,'') <> ''

         SET @cCurOrderkey = CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT PD.orderkey,PD.CaseID
         FROM dropiddetail DP (nolock)
            JOIN pickdetail PD (NOLOCK) ON DP.childid=PD.caseid
         where dp.dropid=@cDropID
            AND ISNULL(CASEID,'') <> ''
         GROUP BY  PD.orderkey,PD.CaseID
      END
      ELSE
      BEGIN
         SELECT @nCaseCnt= COUNT(DISTINCT PD.CaseID)
         FROM dropiddetail DP (nolock)
            JOIN pickdetail PD (NOLOCK) ON DP.childid=PD.caseid
         where dp.dropid=@cDropID
            AND ISNULL(CASEID,'') <> ''
            AND ISNULL(PD.ID,'') <> '' 

         SET @cCurOrderkey = CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT PD.orderkey,PD.CaseID
         FROM dropiddetail DP (nolock)
            JOIN pickdetail PD (NOLOCK) ON DP.childid=PD.caseid
         where dp.dropid=@cDropID
            AND ISNULL(CASEID,'') <> ''
            AND ISNULL(PD.ID,'') <> '' 
         GROUP BY  PD.orderkey,PD.CaseID
      END
   END

   IF @cUserdefine02 <> ''
   BEGIN
      SELECT @nCaseCnt= COUNT(DISTINCT PD.CaseID)
      FROM Orderdetail OD (nolock)
      JOIN PICKDETAIL PD  WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)
                                          AND(OD.OrderLineNumber = PD.OrderLineNumber)
      where UserDefine02 = @cUserdefine02
        AND ISNULL(CASEID,'') <> ''
        AND ISNULL(PD.ID,'') <> ''

      SET @cCurOrderkey = CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT OD.orderkey,PD.CaseID
      FROM Orderdetail OD (nolock)
      JOIN PICKDETAIL PD  WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)
                                          AND(OD.OrderLineNumber = PD.OrderLineNumber)
      where UserDefine02 = @cUserdefine02
        AND ISNULL(CASEID,'') <> ''
        AND ISNULL(PD.ID,'') <> ''
      GROUP BY  OD.orderkey,PD.CaseID
   END

   IF ISNULL(@cMBOLKey,'')=''
   BEGIN
      SET @b_Success = 1
      EXECUTE dbo.nspg_getkey
         'MBOL'
         , 10
         , @cMBOLKey    OUTPUT
         , @b_Success    OUTPUT
         , @nErrNo      OUTPUT
         , @cErrMsg     OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @nErrNo = 195751
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
         GOTO RollBackTran
      END

      INSERT INTO MBOL (MBOLKey, ExternMBOLKey, Facility, STATUS, Remarks) VALUES 
      (@cMBOLKey, '', @cFacility, '0', 'rdt_MbolChildCreation')    

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 195752
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins MBOL Err
         GOTO RollBackTran
      END
   END

   OPEN @cCurOrderkey
   FETCH NEXT FROM @cCurOrderkey INTO @cOrderkey,@cNewCaseID
   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF @cCaseID <> ''
      BEGIN
         SELECT 
            @cStoreCode       = ISNULL(OD.UserDefine02,''),
            @cStoreChild      = ISNULL(OD.UserDefine09,'')
         FROM ORDERS       OH  WITH (NOLOCK)
            JOIN ORDERDETAIL  OD  WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
            JOIN PICKDETAIL   PD  WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)
               AND(OD.OrderLineNumber = PD.OrderLineNumber)
            JOIN SKU          SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)
            AND(PD.Sku = SKU.Sku)
            JOIN PACK         PCK WITH (NOLOCK) ON (SKU.Packkey = PCK.Packkey)
            JOIN CODELKUP     CL  WITH (NOLOCK) ON (CL.ListName = 'SPLITSOTYP')
               AND(CL.Code = OH.Type)
               AND(CL.Storerkey = OH.Storerkey)
         WHERE (OD.UserDefine10 = ''  OR OD.UserDefine10 IS NULL)
			      AND   (PD.ShipFlag <> 'Y' AND PD.Status < '9') /*SOS#333519*/
               AND   PD.CaseID =  @cCaseID 
               AND  od.orderkey=@cOrderkey
	      GROUP BY
			      ISNULL(OD.UserDefine09,''),ISNULL(OD.UserDefine02,'')
      END
      ELSE IF @cPalletkey <> ''
      BEGIN
         SELECT 
            @cStoreCode       = ISNULL(OD.UserDefine02,''),
            @cStoreChild      = ISNULL(OD.UserDefine09,'')
         FROM ORDERS       OH  WITH (NOLOCK)
            JOIN ORDERDETAIL  OD  WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
            JOIN PICKDETAIL   PD  WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)
               AND(OD.OrderLineNumber = PD.OrderLineNumber)
            JOIN SKU          SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)
            AND(PD.Sku = SKU.Sku)
            JOIN PACK         PCK WITH (NOLOCK) ON (SKU.Packkey = PCK.Packkey)
            JOIN palletdetail PDL WITH (NOLOCK) ON (PDL.CASEID  = PD.CASEID)
            JOIN CODELKUP     CL  WITH (NOLOCK) ON (CL.ListName = 'SPLITSOTYP')
               AND(CL.Code = OH.Type)
               AND(CL.Storerkey = OH.Storerkey)
         WHERE (OD.UserDefine10 = ''  OR OD.UserDefine10 IS NULL)
			      AND   (PD.ShipFlag <> 'Y' AND PD.Status < '9') /*SOS#333519*/
               AND  od.orderkey=@cOrderkey
               AND   PDL.Palletkey = @cPalletkey
	      GROUP BY
			      ISNULL(OD.UserDefine09,''),ISNULL(OD.UserDefine02,'')

         IF ISNULL(@cStoreCode,'') =''
         BEGIN
            SELECT 
               @cStoreCode       = ISNULL(OD.userdefine02,'')
            FROM ORDERS       OH  WITH (NOLOCK)
               JOIN ORDERDETAIL  OD  WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
               JOIN PICKDETAIL   PD  WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)
                  AND(OD.OrderLineNumber = PD.OrderLineNumber)
               JOIN SKU          SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)
               AND(PD.Sku = SKU.Sku)
               JOIN PACK         PCK WITH (NOLOCK) ON (SKU.Packkey = PCK.Packkey)
               JOIN palletdetail PDL WITH (NOLOCK) ON (PDL.CASEID  = PD.CASEID)
               JOIN CODELKUP     CL  WITH (NOLOCK) ON (CL.ListName = 'SPLITSOTYP')
                  AND(CL.Code = OH.Type)
                  AND(CL.Storerkey = OH.Storerkey)
            WHERE (OD.UserDefine10 = ''  OR OD.UserDefine10 IS NULL)
			         AND   (PD.ShipFlag <> 'Y' AND PD.Status < '9') /*SOS#333519*/
                  AND   od.orderkey=@cOrderkey
                  AND   PDL.Palletkey = @cPalletkey
	         GROUP BY
			         ISNULL(OD.userdefine02,'')
         END
      END
      ELSE IF @cDropID <> ''
      BEGIN
         SELECT 
            @cStoreCode       = ISNULL(OD.UserDefine02,''),
            @cStoreChild      = ISNULL(OD.UserDefine09,'')
         FROM ORDERS       OH  WITH (NOLOCK)
            JOIN ORDERDETAIL  OD  WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
            JOIN PICKDETAIL   PD  WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)
               AND(OD.OrderLineNumber = PD.OrderLineNumber)
            JOIN SKU          SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)
            AND(PD.Sku = SKU.Sku)
            JOIN PACK         PCK WITH (NOLOCK) ON (SKU.Packkey = PCK.Packkey)
            JOIN DROPIDDETAIL DPD WITH (NOLOCK) ON (PD.CaseID  = DPD.ChildID)
            JOIN DROPID       DP  WITH (NOLOCK) ON (DPD.DropID = DP.DropID)
            JOIN CODELKUP     CL  WITH (NOLOCK) ON (CL.ListName = 'SPLITSOTYP')
               AND(CL.Code = OH.Type)
               AND(CL.Storerkey = OH.Storerkey)
         WHERE (OD.UserDefine10 = ''  OR OD.UserDefine10 IS NULL)
			      AND   (DP.DropIDType = 'B')
			      AND   (DP.Status = '9')
			      AND   (PD.ShipFlag <> 'Y' AND PD.Status < '9') /*SOS#333519*/
               AND   DPD.Dropid = @cDropID
               AND  od.orderkey=@cOrderkey
	      GROUP BY
			      ISNULL(OD.UserDefine09,''),ISNULL(OD.UserDefine02,'')
      END
      ELSE
      BEGIN
         SELECT   @cStoreCode       = ISNULL(OD.UserDefine02,''),
                  @cStoreChild      = ISNULL(OD.UserDefine09,'')
         FROM Orderdetail OD (nolock)
         JOIN PICKDETAIL PD  WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)
                                             AND(OD.OrderLineNumber = PD.OrderLineNumber)
         where UserDefine02 = @cUserdefine02
           AND ISNULL(CASEID,'') <> ''
           AND ISNULL(PD.ID,'') <> ''
	      GROUP BY
			      ISNULL(OD.UserDefine09,''),ISNULL(OD.UserDefine02,'')
      END

      select @cOrderkey,@cNewCaseID,@cStoreCode,@cStoreChild,@cMBOLKey

      EXEC [dbo].[isp_ChildOrder_CreateMBOL]
            @cMBOLKey     
         ,   @cOrderKey
         ,   @cStoreCode       
         ,   @cStoreChild
         ,   @cNewCaseID
         ,   @b_Success      OUTPUT
         ,   @nErrNo         OUTPUT
         ,   @cErrMsg        OUTPUT


      IF @nErrNo <>0  
      BEGIN
         GOTO RollBackTran
      END

      FETCH NEXT FROM @cCurOrderkey INTO @cOrderkey,@cNewCaseID
   END
   CLOSE @cCurOrderkey
   DEALLOCATE @cCurOrderkey


   COMMIT TRAN MbolCreation -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN  -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
      
END

GO