SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/          
/* Store procedure: rdt_1014ExtUpdSP01                                  */          
/* Copyright      : LF                                                  */          
/*                                                                      */          
/* Called from: rdtfnc_SerialNo_Serialize_Master                        */          
/*                                                                      */          
/* Purpose:                                                             */          
/*                                                                      */          
/* Modifications log:                                                   */          
/* Date        Rev  Author   Purposes                                   */          
/* 2017-08-02  1.0  ChewKP   WMS-1931 Created                           */    
/* 2020-04-05  1.1  YeeKung  WMS-13083 Check Childloc (yeekung01)       */    
/* 2020-04-05  1.2  YeeKung  WMS-13085 Update the UD01 (yeekung02)      */        
/************************************************************************/          
          
CREATE PROC [RDT].[rdt_1014ExtUpdSP01] (          
      @nMobile          INT,        
      @nFunc            INT,         
      @cLangCode        NVARCHAR( 3),         
      @nStep            INT,         
      @nInputKey        INT,         
      @cFacility        NVARCHAR( 5),        
      @cStorerKey       NVARCHAR( 15),         
      @cWorkOrderNo     NVARCHAR( 10),         
      @nFromFunc        INT,         
      @cBatchKey        NVARCHAR( 10),         
      @cSKU             NVARCHAR( 20),         
      @cMasterserialNo  NVARCHAR( 20),         
      @nErrNo           INT           OUTPUT,         
      @cErrMsg          NVARCHAR( 20) OUTPUT        
) AS          
BEGIN          
   SET NOCOUNT ON          
   SET ANSI_NULLS OFF          
   SET QUOTED_IDENTIFIER OFF          
   SET CONCAT_NULL_YIELDS_NULL OFF          
           
   DECLARE         
            @nTranCount    INT,        
            @bSuccess      INT,        
            @cLocationCode     NVARCHAR( 10),        
            @cPackKey          NVARCHAR(10),        
            @nInnerPack        INT,        
            @nCaseCnt          INT,        
            @cPassed           NVARCHAR(1),        
            @nScanCount        INT,        
            @nCLabelQty        INT,        
            @n9LQty            INT,        
            @nInnerQty         INT,        
            @nMasterQty        INT,        
            @nRowRef           INT,        
            @cParentSerialNo   NVARCHAR(20),        
            --@cInnerSerialNo    NVARCHAR(20),        
            @cToSerialNo       NVARCHAR(20),        
            @cRemarks          NVARCHAR(20),        
            @cUserName         NVARCHAR(18),        
            @nCountItem        INT,        
            @nChildQty         INT,      
            @nParentQty        INT      
                   
                    
        
   SET @nTranCount = @@TRANCOUNT        
        
   BEGIN TRAN        
   SAVE TRAN rdt_1014ExtUpdSP01        
           
   IF @nFunc = 1014         
   BEGIN        
           
      IF @nStep = 3        
      BEGIN        
         IF @nInputKey = 1        
         BEGIN        
                    
                    
            SELECT @cLocationCode = SHORT         
            FROM dbo.CODELKUP WITH (NOLOCK)         
            WHERE LISTNAME = 'LOGILOC'         
            AND CODE = @cFacility        
        
            SET @cPackKey = ''        
            SELECT @cPackKey = PackKey        
            FROM dbo.SKU WITH (NOLOCK)         
            WHERE StorerKey = @cStorerKey        
            AND SKU         = @cSKU        
                    
            SELECT @nInnerPack = ISNULL(InnerPack,0)         
                  ,@nCaseCnt  = ISNULL(CaseCnt,0)         
            FROM dbo.Pack WITH (NOLOCK)         
            WHERE PackKey = @cPackKey         
                             
            SET @n9LQty     = 0         
            SET @nInnerQty  = 0            
            SET @cPassed    = ''           
                    
            --SET @n9LQty = @nMasterQty * @nCaseCnt        
            SET @nCLabelQty = 0         
        
                    
                    
            IF @nInnerPack > 0         
            BEGIN        
                SET @nInnerQty  = @nInnerPack --@nMasterQty * ( @nCaseCnt / @nInnerPack )         
                    
                SET @nCountItem = 0         
                 
                SELECT @nCountItem = Count(Distinct ParentSerialNo)         
                FROM rdt.rdtSerialNoLog WITH (NOLOCK)         
                WHERE StorerKey = @cStorerKey        
                AND Status = '5'         
                AND ToSKU = @cSKU        
                AND SourceKey = @cWorkOrderNo        
                AND Func = @nFromFunc         
                --AND AddWho = @cUserName        
                AND BatchKey2 = @cBatchKey        
                --AND SerialType = @nMobile         
                --ORDER By ParentSerialNo         
                        
                        
        
                IF @nCountItem = (@nCaseCnt / @nInnerQty )         
                  SET @nCLabelQty = @nCaseCnt / @nInnerQty        
                ELSE        
                  SET @nCLabelQty = @nCountItem        
        
                        
            END         
            ELSE        
            BEGIN        
               SET @nCountItem = 0         
                       
               SELECT @nCountItem = Count(RowRef)         
               FROM rdt.rdtSerialNoLog WITH (NOLOCK)         
               WHERE StorerKey = @cStorerKey        
               AND Status = '5'         
               AND ToSKU = @cSKU        
               AND SourceKey = @cWorkOrderNo        
               AND Func = @nFromFunc         
               --AND AddWho = @cUserName        
               AND BatchKey2 = @cBatchKey        
               --AND SerialType = @nMobile         
               --ORDER By ParentSerialNo         
                       
               IF @nCountItem  = @nCaseCnt         
                  SET @nCLabelQty = @nCaseCnt         
               ELSE        
                  SET @nCLabelQty = @nCountItem        
                       
            END        
                    
                    
            -- Create Master Records --         
            DECLARE CUR_SERIALSKU CURSOR LOCAL READ_ONLY FAST_FORWARD FOR         
                    
            SELECT RowRef, ToSerialNo, ParentSerialNo, Remarks        
            FROM rdt.rdtSerialNoLog WITH (NOLOCK)         
            WHERE StorerKey = @cStorerKey        
            AND Status = '5'         
            AND ToSKU = @cSKU        
            AND SourceKey = @cWorkOrderNo        
            AND Func = @nFromFunc         
            --AND AddWho = @cUserName        
            AND BatchKey2 = @cBatchKey        
            --AND SerialType = @nMobile         
            ORDER By ParentSerialNo         
                    
            OPEN CUR_SERIALSKU        
            FETCH NEXT FROM CUR_SERIALSKU INTO @nRowRef, @cToSerialNo, @cParentSerialNo, @cRemarks        
            WHILE @@FETCH_STATUS <> -1         
            BEGIN        
                       
               --PRINT  @cToSerialNo        
               IF ISNULL(@cParentSerialNo,'')  = ''         
               BEGIN         
                     SET @cParentSerialNo = @cMasterserialNo        
               END        
                       
               SELECT @nChildQty = Count(RowRef)         
               FROM rdt.rdtSerialNoLog WITH (NOLOCK)         
               WHERE StorerKey = @cStorerKey        
               --AND Status = '5'         
               AND ToSKU = @cSKU        
               AND SourceKey = @cWorkOrderNo        
               AND Func = @nFromFunc         
               AND ParentSerialNo = @cParentSerialNo        
               --AND AddWho = @cUserName        
               AND BatchKey2 = @cBatchKey        
               --AND SerialType = @nMobile         
        
        
               -- Insert New 9L Serial No Records        
               INSERT INTO MASTERSERIALNO (        
                           LocationCode        ,UnitType        ,PartnerType  ,SerialNo        ,ElectronicSN  ,Storerkey         
                          ,Sku               ,ItemID           ,ItemDescr     ,ChildQty       ,ParentSerialNo ,ParentSku     ,ParentItemID            
                          ,ParentProdLine    ,VendorSerialNo ,VendorLotNo  ,LotNo           ,Revision       ,CreationDate ,Source                
                          ,Status              ,Attribute1     ,Attribute2  ,Attribute3       ,RequestID        ,UserDefine01  ,UserDefine02          
                          ,UserDefine03        ,UserDefine04     ,UserDefine05   )        
               SELECT TOP 1 @cLocationCode    ,RIGHT(@cToSerialNo,1)        ,PartnerType  ,@cToSerialNo    ,ElectronicSN        ,Storerkey         
                      ,@cSKU               ,ItemID           ,ItemDescr     ,@nChildQty        ,@cParentSerialNo    ,@cSKU        ,ParentItemID            
                      --,@cSKU               ,ItemID           ,ItemDescr     ,CASE WHEN @nInnerPack > 0 THEN @nInnerPack ELSE @nCaseCnt END         ,@cParentSerialNo    ,@cSKU        ,ParentItemID            
                      ,ParentProdLine       ,VendorSerialNo ,VendorLotNo  ,LotNo           ,@nFunc          ,CreationDate ,@cWorkOrderNo                
                      ,Status              ,Attribute1     ,Attribute2  ,Attribute3       ,RequestID           ,('NEW'+space(7))  ,UserDefine02          
                      ,@cBatchKey        ,UserDefine04     ,UserDefine05          
               FROM dbo.MASTERSERIALNO WITH (NOLOCK)         
               WHERE StorerKey = @cStorerKey      
               --WHERE SerialNo = '1715HS0A8KA9'--@cFromSerialNo        
                       
               IF @@ERROR <> 0         
               BEGIN        
                  SET @nErrNo = 113216        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsMasterSerialFail        
                  GOTO RollBackTran        
               END        
        
                       
        
               IF ISNULL(@nInnerQty,0 ) > 0         
               BEGIN         
                          
        
                  IF NOT EXISTS (SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)         
                                 WHERE StorerKey = @cStorerKey         
                                 AND SKU = @cSKU        
                                 AND SerialNo =  @cParentSerialNo)         
                  BEGIN        
                             
        
                     -- Insert New Inner Serial No Records        
                     INSERT INTO MASTERSERIALNO (        
                                LocationCode        ,UnitType        ,PartnerType  ,SerialNo        ,ElectronicSN  ,Storerkey         
                                ,Sku               ,ItemID           ,ItemDescr     ,ChildQty       ,ParentSerialNo ,ParentSku     ,ParentItemID            
                                ,ParentProdLine    ,VendorSerialNo ,VendorLotNo  ,LotNo           ,Revision       ,CreationDate ,Source                
                                ,Status              ,Attribute1     ,Attribute2  ,Attribute3       ,RequestID        ,UserDefine01  ,UserDefine02          
                                ,UserDefine03        ,UserDefine04     ,UserDefine05   )        
                     SELECT TOP 1 @cLocationCode  ,RIGHT(@cParentSerialNo,1)        ,PartnerType  ,@cParentSerialNo    ,ElectronicSN     ,Storerkey         
                            ,@cSKU              ,ItemID           ,ItemDescr     ,@nCLabelQty       ,@cMasterserialNo    ,@cSKU     ,ParentItemID       
                            ,ParentProdLine    ,VendorSerialNo ,VendorLotNo  ,LotNo           ,@nFunc          ,CreationDate ,@cWorkOrderNo                
                            ,Status           ,Attribute1     ,Attribute2  ,Attribute3       ,RequestID           ,('NEW'+space(7)) ,UserDefine02          
                            ,@cBatchKey     ,UserDefine04     ,UserDefine05          
                     FROM dbo.MASTERSERIALNO WITH (NOLOCK)         
      WHERE SerialNo = @cToSerialNo        
                     AND StorerKey = @cStorerKey      
                             
                     IF @@ERROR <> 0         
                     BEGIN        
                        SET @nErrNo = 113217        
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsMasterSerialFail        
                        GOTO RollBackTran        
                     END        
                             
                  END        
               END        
                       
               --SELECT @cStorerKey '@cStorerKey' , @cWorkOrderNo '@cWorkOrderNo' , @nFromFunc '@nFromFunc' , @cBatchKey '@cBatchKey' , @nRowRef '@nRowRef', @cMasterserialNo '@cMasterserialNo'        
        
               UPDATE rdt.rdtSerialNoLog WITH (ROWLOCK)         
               SET Status = '9'        
                  ,Remarks = @cMasterserialNo         
               WHERE StorerKey = @cStorerKey        
               AND Status = '5'         
               AND SourceKey = @cWorkOrderNo        
               AND Func = @nFromFunc        
               AND BatchKey2 = @cBatchKey        
               --AND AddWho = @cUserName        
               AND RowRef = @nRowRef        
                       
               IF @@ERROR <>  0         
               BEGIN        
                   SET @nErrNo = 113218        
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdrdtSerailFail        
                   GOTO RollBackTran        
               END                           
                       
               FETCH NEXT FROM CUR_SERIALSKU INTO @nRowRef, @cToSerialNo, @cParentSerialNo, @cRemarks        
                       
            END        
            CLOSE CUR_SERIALSKU              
            DEALLOCATE CUR_SERIALSKU        
         END        
      END        
        
   END        
           
   IF @nFunc = 1010        
   BEGIN        
      IF @nStep = 5         
      BEGIN        
         IF @nInputKey = 1         
         BEGIN        
            SELECT @cLocationCode = SHORT         
            FROM dbo.CODELKUP WITH (NOLOCK)         
            WHERE LISTNAME = 'LOGILOC'         
            AND CODE = @cFacility        
        
            SET @cPackKey = ''        
            SELECT @cPackKey = PackKey        
            FROM dbo.SKU WITH (NOLOCK)         
            WHERE StorerKey = @cStorerKey        
            AND SKU         = @cSKU        
                    
            SELECT @nInnerPack = ISNULL(InnerPack,0)         
                  ,@nCaseCnt  = ISNULL(CaseCnt,0)         
            FROM dbo.Pack WITH (NOLOCK)         
            WHERE PackKey = @cPackKey         
                    
                    
            SET @n9LQty     = 0         
            SET @nInnerQty  = 0            
            SET @cPassed    = ''           
                    
            --SET @n9LQty = @nMasterQty * @nCaseCnt        
            SET @nCLabelQty = 0         
        
                    
                    
            IF @nInnerPack > 0         
            BEGIN        
                SET @nCountItem = 0         
                        
                SET @nInnerQty  = @nInnerPack --@nMasterQty * ( @nCaseCnt / @nInnerPack )         
                    
                SELECT @nCountItem = Count(Distinct ParentSerialNo)         
                FROM rdt.rdtSerialNoLog WITH (NOLOCK)         
                WHERE StorerKey = @cStorerKey        
                AND Status = '5'         
                AND ToSKU = @cSKU        
                AND SourceKey = @cWorkOrderNo        
                AND Func = @nFromFunc         
                --AND AddWho = @cUserName        
                AND BatchKey2 = @cBatchKey        
                --AND SerialType = @nMobile         
                --ORDER By ParentSerialNo         
        
                        
                        
                IF @nCountItem = (@nCaseCnt / @nInnerQty )         
                  SET @nCLabelQty = @nCaseCnt / @nInnerQty        
                ELSE        
                  SET @nCLabelQty = @nCountItem        
            END         
            ELSE     
            BEGIN        
               SET @nCountItem = 0         
                       
               SELECT @nCountItem = Count(RowRef)         
               FROM rdt.rdtSerialNoLog WITH (NOLOCK)         
               WHERE StorerKey = @cStorerKey        
               AND Status = '5'         
               AND ToSKU = @cSKU        
               AND SourceKey = @cWorkOrderNo        
               AND Func = @nFromFunc         
               --AND AddWho = @cUserName        
               AND BatchKey = @cBatchKey        
               --AND SerialType = @nMobile         
               --ORDER By ParentSerialNo         
        
                       
                       
               IF @nCountItem  = @nCaseCnt         
                  SET @nCLabelQty = @nCaseCnt         
               ELSE        
               BEGIN        
                  SET @nCLabelQty = @nCountItem        
               END        
        
                       
            END        
                    
            SELECT @cUserName = UserName         
            FROM rdt.rdtMobrec WITH (NOLOCK)         
            WHERE Mobile = @nMobile         
        
            -- Create Master Records --         
            DECLARE CUR_SERIALSKU CURSOR LOCAL READ_ONLY FAST_FORWARD FOR         
                     
            SELECT RowRef, ToSerialNo, ParentSerialNo, Remarks        
            FROM rdt.rdtSerialNoLog WITH (NOLOCK)         
            WHERE StorerKey = @cStorerKey        
            AND Status = '5'         
            AND ToSKU = @cSKU        
            AND SourceKey = @cWorkOrderNo        
            AND Func = @nFunc         
            AND AddWho = @cUserName        
            AND BatchKey = @cBatchKey        
            ORDER By ParentSerialNo         
                    
            OPEN CUR_SERIALSKU        
            FETCH NEXT FROM CUR_SERIALSKU INTO @nRowRef, @cToSerialNo, @cParentSerialNo, @cRemarks        
            WHILE @@FETCH_STATUS <> -1         
            BEGIN        
                       
               SELECT @nChildQty = Count(RowRef)         
               FROM rdt.rdtSerialNoLog WITH (NOLOCK)         
               WHERE StorerKey = @cStorerKey        
               --AND Status = '5'         
               AND ToSKU = @cSKU        
               AND SourceKey = @cWorkOrderNo        
               AND ParentSerialNo = CASE WHEN ISNULL(@cParentSerialNo,'') <> '' THEN @cParentSerialNo ELSE ParentSerialNo END        
               AND Func = @nFunc         
               AND AddWho = @cUserName        
               AND BatchKey = @cBatchKey        
        
               --PRINT  @cToSerialNo        
               IF ISNULL(@cParentSerialNo,'')  = ''         
               BEGIN         
                     SET @cParentSerialNo = @cMasterserialNo        
               END        
        
        
               -- Insert New 9L Serial No Records        
               INSERT INTO MASTERSERIALNO (        
                           LocationCode        ,UnitType        ,PartnerType  ,SerialNo        ,ElectronicSN  ,Storerkey         
                          ,Sku               ,ItemID           ,ItemDescr     ,ChildQty       ,ParentSerialNo ,ParentSku     ,ParentItemID            
                          ,ParentProdLine    ,VendorSerialNo ,VendorLotNo  ,LotNo          ,Revision       ,CreationDate ,Source                
                          ,Status              ,Attribute1     ,Attribute2  ,Attribute3       ,RequestID        ,UserDefine01  ,UserDefine02          
                          ,UserDefine03        ,UserDefine04     ,UserDefine05   )        
               SELECT TOP 1 @cLocationCode    ,RIGHT(@cToSerialNo,1)        ,PartnerType  ,@cToSerialNo    ,ElectronicSN        ,Storerkey         
                      ,@cSKU               ,ItemID           ,ItemDescr     ,@nChildQty     ,@cParentSerialNo    ,@cSKU        ,ParentItemID            
                      --,@cSKU               ,ItemID           ,ItemDescr     ,CASE WHEN @nInnerPack > 0 THEN @nInnerPack ELSE @nCaseCnt END         ,@cParentSerialNo    ,@cSKU        ,ParentItemID            
         ,ParentProdLine       ,VendorSerialNo ,VendorLotNo  ,LotNo           ,'1010'          ,CreationDate ,@cWorkOrderNo                
                      ,Status              ,Attribute1     ,Attribute2  ,Attribute3       ,RequestID           ,('NEW'+space(7)) ,UserDefine02          
                      ,@cBatchKey        ,UserDefine04     ,UserDefine05          
               FROM dbo.MASTERSERIALNO WITH (NOLOCK)         
               WHERE StorerKey = @cStorerKey      
               --WHERE SerialNo = '1715HS0A8KA9'--@cFromSerialNo        
                       
               IF @@ERROR <> 0         
               BEGIN        
                  SET @nErrNo = 113254        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsMasterSerialFail        
                  GOTO RollBackTran        
               END         
        
               IF ISNULL(@nInnerQty,0 ) > 0         
               BEGIN         
                          
        
                  IF NOT EXISTS (SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)         
                                 WHERE StorerKey = @cStorerKey         
                                 AND SKU = @cSKU        
                                 AND SerialNo =  @cParentSerialNo)         
                  BEGIN        
                     SELECT @nParentQty = Count(Distinct ParentSerialNo)         
                     FROM rdt.rdtSerialNoLog WITH (NOLOCK)         
                     WHERE StorerKey = @cStorerKey        
                     --AND Status = '5'         
                     AND ToSKU = @cSKU        
                     AND SourceKey = @cWorkOrderNo        
                     --AND ParentSerialNo = CASE WHEN ISNULL(@cParentSerialNo,'') <> '' THEN @cParentSerialNo ELSE ParentSerialNo END        
                     AND Func = @nFunc         
                     --AND AddWho = @cUserName        
                     AND BatchKey = @cBatchKey       
        
                     -- Insert New Inner Serial No Records        
                     INSERT INTO MASTERSERIALNO (        
                                LocationCode        ,UnitType        ,PartnerType  ,SerialNo        ,ElectronicSN  ,Storerkey         
                                ,Sku               ,ItemID           ,ItemDescr     ,ChildQty       ,ParentSerialNo ,ParentSku     ,ParentItemID            
                                ,ParentProdLine    ,VendorSerialNo ,VendorLotNo  ,LotNo           ,Revision       ,CreationDate ,Source                
                                ,Status              ,Attribute1     ,Attribute2  ,Attribute3       ,RequestID        ,UserDefine01  ,UserDefine02          
                                ,UserDefine03        ,UserDefine04     ,UserDefine05   )        
                    SELECT TOP 1 @cLocationCode  ,RIGHT(@cParentSerialNo,1)        ,PartnerType  ,@cParentSerialNo    ,ElectronicSN     ,Storerkey         
                            ,@cSKU              ,ItemID           ,ItemDescr     ,@nParentQty       ,@cMasterserialNo    ,@cSKU     ,ParentItemID            
                            ,ParentProdLine    ,VendorSerialNo ,VendorLotNo  ,LotNo          ,'1010'            ,CreationDate ,@cWorkOrderNo                
                            ,Status           ,Attribute1     ,Attribute2  ,Attribute3       ,RequestID           ,('NEW'+space(7))  ,UserDefine02          
                            ,@cBatchKey     ,UserDefine04     ,UserDefine05          
                     FROM dbo.MASTERSERIALNO WITH (NOLOCK)         
                     WHERE SerialNo = @cToSerialNo        
                     AND StorerKey = @cStorerKey      
                             
                     IF @@ERROR <> 0         
                     BEGIN        
                        SET @nErrNo = 113255        
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsMasterSerialFail        
                        GOTO RollBackTran        
                     END        
                             
                  END        
               END        
                       
               UPDATE rdt.rdtSerialNoLog WITH (ROWLOCK)         
               SET Status = '9'        
                  ,Remarks = @cMasterserialNo         
               WHERE StorerKey = @cStorerKey        
               AND Status = '5'         
               AND SourceKey = @cWorkOrderNo        
               AND Func = @nFunc         
               AND BatchKey = @cBatchKey        
               AND AddWho = @cUserName        
               AND RowRef = @nRowRef        
                       
               IF @@ERROR <>  0         
               BEGIN        
                   SET @nErrNo = 113256        
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdrdtSerailFail        
                   GOTO RollBackTran        
               END                           
                       
               FETCH NEXT FROM CUR_SERIALSKU INTO @nRowRef, @cToSerialNo, @cParentSerialNo, @cRemarks        
                       
            END        
            CLOSE CUR_SERIALSKU              
            DEALLOCATE CUR_SERIALSKU        
         END        
      END        
   END        
          
           
   GOTO Quit        
        
   RollBackTran:        
      ROLLBACK TRAN rdt_1014ExtUpdSP01        
        
   Quit:        
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started        
         COMMIT TRAN rdt_1014ExtUpdSP01        
        
          
Fail:          
END 

GO