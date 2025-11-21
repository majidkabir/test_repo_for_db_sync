SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1016ExtUpdSP01                                  */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 08-09-2017  1.0  ChewKP   WMS-2881 Created                           */
/* 24-12-2018  1.1  ChewKP   WMS-7274 CR                                */
/************************************************************************/

CREATE PROC [RDT].[rdt_1016ExtUpdSP01] (
  @nMobile         INT,         
  @nFunc           INT,       
  @cLangCode       NVARCHAR( 3),  
  @nStep           INT,        
  @nInputKey       INT,       
  @cStorerKey      NVARCHAR( 15), 
  @cWorkOrderNo    NVARCHAR( 10), 
  @cSKU            NVARCHAR( 20), 
  @cMasterSerialNo NVARCHAR( 20), 
  @cChildSerialNo  NVARCHAR( 20), 
  @cOption         NVARCHAR( 10), 
  @nCompleteFlag   INT OUTPUT, 
  @nErrNo          INT OUTPUT,    
  @cErrMsg         NVARCHAR( 20) OUTPUT 
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_1016ExtUpd01   
   
   DECLARE @cPalletLineNumber NVARCHAR(5) 
          ,@cPackkey          NVARCHAR(10) 
          ,@nCaseCnt          INT
          ,@nScanCount        INT
          ,@cUserName         NVARCHAR(18) 
          ,@nRowRef           INT
          ,@cSerialNo         NVARCHAR(20) 
          ,@cParentSerialNo   NVARCHAR(20)
          ,@cSerialSKU        NVARCHAR(20) 
         
   SET @nCompleteFlag  = 0 

   SELECT @cUserName = UserName
   FROM rdt.rdtMobrec WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   IF @nFunc = 1016 
   BEGIN
      
      IF @nStep = 3  
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            INSERT INTO rdt.rdtSerialNoLog ( StorerKey, Status, FromSerialNo, ToSerialNo, ParentSerialNo, FromSKU, ToSKU, SourceKey, SourceType, BatchKey, Remarks, Func, AddWho  ) 
            VALUES ( @cStorerKey, '1' , @cChildSerialNo, @cChildSerialNo, @cMasterSerialNo, @cSKU, @cSKU,  @cWorkOrderNo, '', '', '' , @nFunc, @cUserName ) 
      
            IF @@ERROR <> 0 
            BEGIN
                  SET @nErrNo = 114503
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsrdtSerailFail
                  GOTO RollBackTran
            END 

            SELECT @cPackKey = PackKey 
            FROM dbo.SKU WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU 
            
            SELECT @nCaseCnt = CaseCnt
            FROM dbo.Pack WITH (NOLOCK) 
            WHERE Packkey = @cPackKey
            
            SELECT @nScanCount = Count(RowRef) 
            FROM rdt.rdtSerialNoLog WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
            AND SourceKey = @cWorkOrderNo
            AND Func = @nFunc
            AND AddWho = @cUserName
            AND ParentSerialNo = @cMasterSerialNo
            AND Status = '1'

            
            
            IF @nCaseCnt = @nScanCount 
            BEGIN
            
               DECLARE CUR_INSERT_MASTERSERIAL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT RowRef, FromSerialNo, ParentSerialNo, FromSKU
               FROM rdt.rdtSerialNoLog WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND SourceKey = @cWorkOrderNo
               AND Func = @nFunc
               AND AddWho = @cUserName
               AND ParentSerialNo = @cMasterSerialNo
               AND Status = '1'
               ORDER BY RowRef
               
               OPEN CUR_INSERT_MASTERSERIAL 
               FETCH NEXT FROM CUR_INSERT_MASTERSERIAL INTO @nRowRef, @cSerialNo, @cParentSerialNo, @cSerialSKU 
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  
                  

                  INSERT INTO MASTERSERIALNO (
                         	 LocationCode 	      ,UnitType 	      ,PartnerType 	,SerialNo 	      ,ElectronicSN 	,Storerkey	
                         	,Sku              	,ItemID 	         ,ItemDescr 	   ,ChildQty	      ,ParentSerialNo	,ParentSku 	   ,ParentItemID 	  
                         	,ParentProdLine	   ,VendorSerialNo	,VendorLotNo 	,LotNo 	         ,Revision	      ,CreationDate	,Source 	      
                         	,Status 	            ,Attribute1 	   ,Attribute2 	,Attribute3       ,RequestID 	      ,UserDefine01 	,UserDefine02 	
                         	,UserDefine03 	      ,UserDefine04 	   ,UserDefine05 	 )
                  VALUES (
                         	 '' 	         ,'SINGLECASE'     ,'' 	,@cSerialNo 	   ,'' 	               ,@cStorerkey	
                         	,@cSerialSKU   ,'' 	            ,'' 	,1	               ,@cParentSerialNo	   ,@cSerialSKU 	   ,'' 	  
                         	,''	         ,''	            ,'' 	,'' 	            ,''	               ,''	            ,@cWorkOrderNo
                         	,'' 	         ,'' 	            ,'' 	,''               ,'' 	               ,'' 	             ,'' 	
                         	,'' 	         ,'' 	            ,'' 	 )
                  
                  
                  IF @@ERROR <> 0 
                  BEGIN
                     SET @nErrNo = 114501
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsMasterSerialFail
                     GOTO RollBackTran
                  END

                  UPDATE rdt.rdtSerialNoLog WITH (ROWLOCK) 
                  SET Status = '9'
                  WHERE RowRef = @nRowRef 
                  
                  IF @@ERROR <> 0 
                  BEGIN
                     SET @nErrNo = 114502
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdRDTSerialFail
                     GOTO RollBackTran
                  END
                  
                  
                  
                  FETCH NEXT FROM CUR_INSERT_MASTERSERIAL INTO @nRowRef, @cSerialNo, @cParentSerialNo, @cSerialSKU 
               END
               CLOSE CUR_INSERT_MASTERSERIAL
               DEALLOCATE CUR_INSERT_MASTERSERIAL 
               
               SET @nCompleteFlag = 1 
            END   
            
            
         END
      END
      
      IF @nStep = 4  
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            
            IF @cOption = '1'
            BEGIN

               SELECT @cPackKey = PackKey 
               FROM dbo.SKU WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND SKU = @cSKU 
               
               SELECT @nCaseCnt = CaseCnt
               FROM dbo.Pack WITH (NOLOCK) 
               WHERE Packkey = @cPackKey
               
               SELECT @nScanCount = Count(RowRef) 
               FROM rdt.rdtSerialNoLog WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND SourceKey = @cWorkOrderNo
               AND Func = @nFunc
               AND AddWho = @cUserName
               AND ParentSerialNo = @cMasterSerialNo
               AND Status = '1'

               IF @nScanCount = 0 
               BEGIN 
                  SET @nErrNo = 114507
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 0Scanned
                  GOTO RollBackTran
               END
               
               --IF @nCaseCnt = @nScanCount 
               --BEGIN
               
               DECLARE CUR_INSERT_MASTERSERIAL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT RowRef, FromSerialNo, ParentSerialNo, FromSKU
               FROM rdt.rdtSerialNoLog WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND SourceKey = @cWorkOrderNo
               AND Func = @nFunc
               AND AddWho = @cUserName
               AND ParentSerialNo = @cMasterSerialNo
               AND Status = '1'
               ORDER BY RowRef
               
               OPEN CUR_INSERT_MASTERSERIAL 
               FETCH NEXT FROM CUR_INSERT_MASTERSERIAL INTO @nRowRef, @cSerialNo, @cParentSerialNo, @cSerialSKU 
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  
                  

                  INSERT INTO MASTERSERIALNO (
                         	 LocationCode 	      ,UnitType 	      ,PartnerType 	,SerialNo 	      ,ElectronicSN 	,Storerkey	
                         	,Sku              	,ItemID 	         ,ItemDescr 	   ,ChildQty	      ,ParentSerialNo	,ParentSku 	   ,ParentItemID 	  
                         	,ParentProdLine	   ,VendorSerialNo	,VendorLotNo 	,LotNo 	         ,Revision	      ,CreationDate	,Source 	      
                         	,Status 	            ,Attribute1 	   ,Attribute2 	,Attribute3       ,RequestID 	      ,UserDefine01 	,UserDefine02 	
                         	,UserDefine03 	      ,UserDefine04 	   ,UserDefine05 	 )
                  VALUES (
                         	 '' 	         ,'SINGLECASE'     ,'' 	,@cSerialNo 	   ,'' 	               ,@cStorerkey	
                         	,@cSerialSKU   ,'' 	            ,'' 	,1	               ,@cParentSerialNo	   ,@cSerialSKU 	   ,'' 	  
                         	,''	         ,''	            ,'' 	,'' 	            ,''	               ,''	            ,@cWorkOrderNo
                         	,'' 	         ,'' 	            ,'' 	,''               ,'' 	               ,'' 	             ,'' 	
                         	,'' 	         ,'' 	            ,'' 	 )
                  
                  
                  IF @@ERROR <> 0 
                  BEGIN
                     SET @nErrNo = 114504
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsMasterSerialFail
                     GOTO RollBackTran
                  END

                  UPDATE rdt.rdtSerialNoLog WITH (ROWLOCK) 
                  SET Status = '9'
                  WHERE RowRef = @nRowRef 
                  
                  IF @@ERROR <> 0 
                  BEGIN
                     SET @nErrNo = 114505
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdRDTSerialFail
                     GOTO RollBackTran
                  END
                  
                  
                  
                  FETCH NEXT FROM CUR_INSERT_MASTERSERIAL INTO @nRowRef, @cSerialNo, @cParentSerialNo, @cSerialSKU 
               END
               CLOSE CUR_INSERT_MASTERSERIAL
               DEALLOCATE CUR_INSERT_MASTERSERIAL 
                  
               SET @nCompleteFlag = 1 
               --END   
            
            END
            ELSE IF @cOption = '9'
            BEGIN
               
               DELETE FROM rdt.rdtSerialNoLog WITH (ROWLOCK) 
               WHERE StorerKey  = @cStorerKey
               AND SourceKey = @cWorkOrderNo
               AND FromSKU = @cSKU 
               AND Func = @nFunc
               AND AddWho = @cUserName
               AND Status <> '9'
               
               IF @@ERROR <> 0 
               BEGIN
                  SET @nErrNo = 114506
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelRDTSerialFail
                  GOTO RollBackTran
               END
               
            END
            
         END
      END

   END

   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_1016ExtUpd01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN   
END


GO