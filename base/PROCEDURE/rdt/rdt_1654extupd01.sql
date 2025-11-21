SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1654ExtUpd01                                    */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Called from: rdtfnc_TrackNo_SortToPallet_CloseLane                   */  
/*                                                                      */  
/* Purpose: Insert into Transmitlog2 table                              */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2022-10-04  1.0  James    WMS-20667. Created                         */  
/* 2022-12-09  1.1  SYChua   JSM-116367 Fix to trigger at step 5 (SY01) */  
/* 2023-03-02  1.2  James    WMS-21679 If mbol shipped without split    */
/*                           lane for certain orders type then need     */
/*                           stamp new externmbolkey naming (james01)   */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_1654ExtUpd01] (  
   @nMobile        INT,  
   @nFunc          INT,  
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,  
   @nInputKey      INT,  
   @cFacility      NVARCHAR( 5),  
   @cStorerKey     NVARCHAR( 15),  
   @cLane          NVARCHAR( 20),  
   @cOption        NVARCHAR( 1),  
   @tExtUpdateVar  VariableTable READONLY,  
   @nErrNo         INT           OUTPUT,  
   @cErrMsg        NVARCHAR( 20) OUTPUT  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @bSuccess       INT  
   DECLARE @cMBOLKey       NVARCHAR( 10)  
   DECLARE @cNewLane       NVARCHAR( 30) = ''
   DECLARE @nStampPltDtl   INT = 0
   DECLARE @ccurPltDtl     CURSOR
   DECLARE @cPalletKey     NVARCHAR( 10)
   DECLARE @cPalletLineNumber     NVARCHAR( 5)
   
   DECLARE @nTranCount INT  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_1654ExtUpd01  
  
   --IF @nStep = 2      --SY01  
   IF @nStep IN (2, 5)  --SY01  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
         IF @cOption = '1'  
         BEGIN  
            SELECT @cMBOLKey = MBOLKey  
            FROM dbo.MBOL WITH (NOLOCK)  
            WHERE ExternMbolKey= @cLane  

            -- (james01)
            IF EXISTS ( SELECT 1 
                FROM dbo.CODELKUP CL WITH (NOLOCK)
                JOIN dbo.ORDERS O WITH (NOLOCK) ON ( O.Type = CL.Code2 AND O.StorerKey = CL.StorerKey)
                JOIN dbo.MBOL M WITH (NOLOCK) ON ( M.MBOLKey = O.MBOLKey)
                WHERE M.ExternMBOLKey = @cLane
                AND   CL.ListName = 'LANECONFIG'
                AND   CL.StorerKey = @cStorerKey
                AND   CL.Code = 'LANEGENTIMESTAMP'
                AND   CL.Short = '1')
            BEGIN
               -- Only generates for MBOL which hasn't been stamped
               IF CHARINDEX('|', @cLane) = 0
               BEGIN
                  SELECT @cNewLane = ExternMBOLKey + '|' + FORMAT(GETDATE(), 'yyMMddHHmmss')
                  FROM dbo.MBOL WITH (NOLOCK)
                  WHERE MBOLKey = @cMBOLKey

                  UPDATE dbo.MBOL SET
                     ExternMBOLKey = @cNewLane,  
                     EditDate = GETDATE(),  
                     EditWho = SUSER_SNAME()
                  WHERE MbolKey = @cMBOLKey

                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 192502  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd Mbol Fail  
                     GOTO RollBackTran  
                  END
                  
                  SET @nStampPltDtl = 1
               END  
               
               IF @nStampPltDtl = 1
               BEGIN
               	SET @ccurPltDtl = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               	SELECT PalletKey, PalletLineNumber
               	FROM dbo.PALLETDETAIL PD WITH (NOLOCK)
               	WHERE StorerKey = @cStorerKey 
               	AND   UserDefine03 = @cLane
               	AND   EXISTS ( SELECT 1
               	               FROM dbo.ORDERS O WITH (NOLOCK)
               	               WHERE PD.StorerKey = O.StorerKey
               	               AND   PD.UserDefine01 = O.OrderKey
               	               AND   O.MBOLKey = @cMBOLKey)
                  OPEN @ccurPltDtl
                  FETCH NEXT FROM @ccurPltDtl INTO @cPalletKey, @cPalletLineNumber
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                  	UPDATE dbo.PalletDetail SET
                  	   UserDefine03 = @cNewLane,  
                        EditDate = GETDATE(),  
                        EditWho = SUSER_SNAME()
                  	WHERE PalletKey = @cPalletKey
                  	AND   PalletLineNumber = @cPalletLineNumber
                  	
                  	IF @@ERROR <> 0
                     BEGIN  
                        SET @nErrNo = 192503  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd PlDtl Err 
                        GOTO RollBackTran  
                     END

                  	FETCH NEXT FROM @ccurPltDtl INTO @cPalletKey, @cPalletLineNumber
                  END
               END
            END
            /*
            -- Insert transmitlog2 here  
            EXECUTE ispGenTransmitLog2  
               @c_TableName      = 'WSCRSOCLOSEILS',  
               @c_Key1           = @cMBOLKey,  
               @c_Key2           = '',  
               @c_Key3           = @cStorerkey,  
               @c_TransmitBatch  = '',  
               @b_Success        = @bSuccess   OUTPUT,  
               @n_err            = @nErrNo     OUTPUT,  
               @c_errmsg         = @cErrMsg    OUTPUT  
  
            IF @bSuccess <> 1  
            BEGIN  
               SET @nErrNo = 192501  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Insert TL2 Err  
               GOTO RollBackTran  
            END  
            */

            EXEC [dbo].[isp_Carrier_Middleware_Interface]          
                 @c_OrderKey    = ''
               , @c_Mbolkey     = @cMbolKey         
               , @c_FunctionID  = @nFunc        
               , @n_CartonNo    = 0    
               , @n_Step        = @nStep    
               , @b_Success     = @bSuccess  OUTPUT          
               , @n_Err         = @nErrNo    OUTPUT          
               , @c_ErrMsg      = @cErrMsg   OUTPUT         

            IF @bSuccess <> 1  
            BEGIN  
               SET @nErrNo = 192501  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Insert TL2 Err  
               GOTO RollBackTran  
            END  

         END  
      END  
   END  
  
   GOTO Quit  
  
   RollBackTran:  
         ROLLBACK TRAN rdt_1654ExtUpd01  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN  
  
END


GO