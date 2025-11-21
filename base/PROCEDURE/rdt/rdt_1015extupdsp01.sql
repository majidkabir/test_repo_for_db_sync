SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/            
/* Store procedure: rdt_1015ExtUpdSP01                                  */            
/* Copyright      : LF                                                  */            
/*                                                                      */            
/* Called from: rdtfnc_SerialNo_Serialize_Master                        */            
/*                                                                      */            
/* Purpose:                                                             */            
/*                                                                      */            
/* Modifications log:                                                   */            
/* Date        Rev  Author   Purposes                                   */            
/* 2017-08-04  1.0  ChewKP   WMS-1931 Created                           */          
/* 2020-04-05  1.1  YeeKung  WMS-13086 Update the UD01 (yeekung01)      */        
/* 2020-04-05  1.2  YeeKung  WMS-13084 Update the UD01 (yeekung02)      */        
/************************************************************************/        
    
CREATE PROC [RDT].[rdt_1015ExtUpdSP01] (          
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
            @cOriginalParentSerialNo NVARCHAR(20),        
            @cSerialType       NVARCHAR(1),        
            @cChildSerialNo    NVARCHAR(20),        
            @cOriginalMasterSerialNo NVARCHAR(20),        
            @nChildQty         INT,        
            @nParentQty        INT,      
            @nUserdefine01     NVARCHAR(30) ,        
            @nLocationCode     NVARCHAR(30)          
        
   SET @nTranCount = @@TRANCOUNT        
        
           
   DECLARE @tMasterSerialTemp TABLE (        
            -- [MasterSerialNoKey] [bigint] IDENTITY(1,1) NOT NULL,        
             [LocationCode] [nvarchar](10) NULL DEFAULT (''),        
             [UnitType] [nvarchar](10) NULL DEFAULT (''),        
             [PartnerType] [nvarchar](20) NULL DEFAULT (''),        
             [SerialNo] [nvarchar](50) NOT NULL DEFAULT (''),        
             [ElectronicSN] [nvarchar](50) NULL DEFAULT (''),        
             [Storerkey] [nvarchar](15) NOT NULL DEFAULT (''),        
             [Sku] [nvarchar](20) NOT NULL DEFAULT (''),        
             [ItemID] [nvarchar](50) NULL DEFAULT (''),        
             [ItemDescr] [nvarchar](100) NULL DEFAULT (''),        
             [ChildQty] [int] NULL DEFAULT ((0)),        
             [ParentSerialNo] [nvarchar](50) NULL DEFAULT (''),        
             [ParentSku] [nvarchar](20) NOT NULL DEFAULT (''),        
             [ParentItemID] [nvarchar](50) NULL DEFAULT (''),        
             [ParentProdLine] [nvarchar](50) NULL DEFAULT (''),        
             [VendorSerialNo] [nvarchar](50) NULL DEFAULT (''),        
             [VendorLotNo] [nvarchar](50) NULL DEFAULT (''),        
             [LotNo] [nvarchar](20) NULL DEFAULT (''),        
             [Revision] [nvarchar](10) NULL DEFAULT (''),        
             [CreationDate] [datetime] NULL,        
             [Source] [nvarchar](10) NULL DEFAULT (''),        
             [Status] [nvarchar](10) NULL DEFAULT ('0'),        
             [Attribute1] [nvarchar](50) NULL DEFAULT (''),        
             [Attribute2] [nvarchar](50) NULL DEFAULT (''),        
             [Attribute3] [nvarchar](50) NULL DEFAULT (''),        
             [RequestID] [int] NULL DEFAULT ((0)),        
             [UserDefine01] [nvarchar](30) NOT NULL DEFAULT (''),        
             [UserDefine02] [nvarchar](30) NOT NULL DEFAULT (''),        
             [UserDefine03] [nvarchar](30) NOT NULL DEFAULT (''),        
             [UserDefine04] [datetime] NULL,        
             [UserDefine05] [datetime] NULL,        
             [Addwho] [nvarchar](18) NULL  DEFAULT (suser_sname()),        
             [Adddate] [datetime] NULL  DEFAULT (getdate()),        
             [Editwho] [nvarchar](18) NULL  DEFAULT (suser_sname()),        
             [Editdate] [datetime] NULL  DEFAULT (getdate()),        
             [TrafficCop] [nchar](1) NULL,        
             [ArchiveCop] [nchar](1) NULL )          
        
   BEGIN TRAN        
   SAVE TRAN rdt_1015ExtUpdSP01        
           
   IF @nFunc = 1015        
   BEGIN        
      IF @nStep = 2         
      BEGIN        
         IF @nInputKey = 1         
         BEGIN        
        
            SET @cSerialType = RIGHT ( @cMasterserialNo , 1 )         
                 
            IF @cSerialType = ( '9' )         
            BEGIN        
               SET @nErrNo = 113363        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialType        
               GOTO RollBackTran         
                       
            END        
                 
            IF NOT EXISTS ( SELECT 1 FROM rdt.rdtserialNoLog WITH (NOLOCK)         
                           WHERE StorerKey = @cStorerKey        
                           AND Status = '5'         
                           AND Func = @nFromFunc        
                           AND SourceKey = @cWorkOrderNo        
                           AND ParentSerialNo = @cMasterserialNo )          
            BEGIN        
                       
        
               IF NOT EXISTS ( SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)         
                               WHERE ParentSerialNo = @cMasterserialNo        
                               AND StorerKey = @cStorerKey)        
               BEGIN         
                  SET @nErrNo = 113364            
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SerialNoNotExist        
                  GOTO RollBackTran        
               END        
                       
                IF NOT EXISTS ( SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)         
                               WHERE ParentSerialNo = @cMasterserialNo        
                               AND SKU = @cSKU        
                               AND StorerKey = @cStorerKey )        
               BEGIN         
                  SET @nErrNo = 113365            
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidSKU         
                  GOTO RollBackTran        
               END        
               
               SELECT @cUserName = UserName         
               FROM rdt.rdtMobrec WITH (NOLOCK)         
               WHERE Mobile = @nMobile         
                       
                       
               -- Create rdt.rdtSerialNoLog Records --         
               DECLARE CUR_SERIALSKU CURSOR LOCAL READ_ONLY FAST_FORWARD FOR         
                        
               SELECT SerialNo        
               FROM dbo.MasterSerialNo WITH (NOLOCK)         
               WHERE ParentSerialNo = @cMasterserialNo        
               AND StorerKey = @cStorerKey        
                       
               OPEN CUR_SERIALSKU        
               FETCH NEXT FROM CUR_SERIALSKU INTO  @cChildSerialNo        
               WHILE @@FETCH_STATUS <> -1         
               BEGIN        
                          
                  INSERT INTO rdt.rdtSerialNoLog ( StorerKey, Status, FromSerialNo, ToSerialNo, ParentSerialNo, FromSKU, ToSKU, SourceKey, SourceType, BatchKey, Remarks, Func, AddWho  )         
                  VALUES ( @cStorerKey, '5' , @cChildSerialNo, @cChildSerialNo, @cMasterserialNo, @cSKU, @cSKU,  @cWorkOrderNo, '', @cBatchKey, '' , 1013, @cUserName )         
                          
                  IF @@ERROR <> 0         
                  BEGIN        
                     SET @nErrNo = 113366            
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsrdtSerailFail         
                     GOTO RollBackTran        
                  ENd        
                          
                  FETCH NEXT FROM CUR_SERIALSKU INTO  @cChildSerialNo        
                          
               END        
                       
                       
               CLOSE CUR_SERIALSKU              
               DEALLOCATE CUR_SERIALSKU        
                       
                       
            END        
                 
            IF EXISTS ( SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)         
                                 WHERE SKU = @cSKU        
                                 AND ParentSerialNo = @cChildSerialNo        
                                 AND StorerKey = @cStorerKey  )         
            BEGIN        
               SET @nErrNo = 113209            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialNo            
               --SET @cChildSerialNo = ''        
               GOTO RollBackTran            
            END        
        
            IF EXISTS ( SELECT 1 FROM rdt.rdtserialNoLog WITH (NOLOCK)         
                        WHERE StorerKey = @cStorerKey        
                        AND Status = '5'         
                        AND Func = @nFromFunc        
                        AND ParentSerialNo = @cChildSerialNo        
                        AND BatchKey2 <> ''        
                        AND Func2 <> ''  )         
            BEGIN        
               SET @nErrNo = 113220            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SerialNoScanned            
               --SET @cChildSerialNo = ''        
               GOTO RollBackTran            
            END        
         END        
      END        
              
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
                    
                SET @nCLabelQty = @nCaseCnt / @nInnerQty        
            END         
            ELSE        
            BEGIN        
               SET @nCLabelQty = @nCaseCnt         
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
            AND Func = @nFromFunc         
            --AND AddWho = @cUserName        
            AND BatchKey2 = @cBatchKey        
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
        
                       
               -- Insert into Temp Table before Delete        
               INSERT INTO @tMasterSerialTemp (        
                            LocationCode        ,UnitType        ,PartnerType  ,SerialNo        ,ElectronicSN  ,Storerkey         
                         ,Sku               ,ItemID           ,ItemDescr     ,ChildQty       ,ParentSerialNo ,ParentSku     ,ParentItemID            
                         ,ParentProdLine    ,VendorSerialNo ,VendorLotNo  ,LotNo           ,Revision       ,CreationDate ,Source                
                         ,Status              ,Attribute1     ,Attribute2  ,Attribute3       ,RequestID        ,UserDefine01  ,UserDefine02          
                         ,UserDefine03        ,UserDefine04     ,UserDefine05   )        
               SELECT TOP 1 LocationCode    ,UnitType        ,PartnerType  ,SerialNo     ,ElectronicSN     ,Storerkey         
                     ,SKU               ,ItemID           ,ItemDescr     ,@nChildQty       ,ParentSerialNo   ,ParentSKU     ,ParentItemID            
                     ,ParentProdLine    ,VendorSerialNo ,VendorLotNo  ,LotNo           ,'1015'          ,CreationDate ,@cWorkOrderNo                
                     ,Status              ,Attribute1     ,Attribute2  ,Attribute3       ,RequestID           ,('NEW'+space(7))  ,@cLocationCode          
                     ,@cBatchKey        ,UserDefine04     ,UserDefine05          
               FROM dbo.MASTERSERIALNO WITH (NOLOCK)         
               WHERE SerialNo = @cToSerialNo        
               AND StorerKey = @cStorerKey        
      
               SELECT @nUserdefine01=UserDefine01,      
                @nLocationCode=LocationCode      
               FROM dbo.MasterSerialNo WITH (NOLOCK)       
               WHERE SerialNo = @cToSerialNo         
                AND StorerKey = @cStorerKey        
            
               -- Interface purpose.  (yeekung01)      
               UPDATE dbo.MasterSerialNo WITH (ROWLOCK)         
               SET Revision      = '1015'         
                  ,Source        = @cWorkOrderNo       
                  ,UserDefine02  = @cLocationCode      
               WHERE SerialNo = @cToSerialNo         
               AND StorerKey = @cStorerKey        
                       
               IF @@ERROR <> 0         
               BEGIN        
                 SET @nErrNo = 113362        
                 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelMasterSerialFail        
                 GOTO RollBackTran         
               END     
                       
               -- Delete MasterSerialNo Records         
               IF EXISTS ( SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)         
                           WHERE SerialNo = @cToSerialNo         
                           AND ParentSerialNo <> @cParentSerialNo        
                           AND StorerKey = @cStorerKey )        
               BEGIN        
                  --SELECT @cToSerialNo '@cToSerialNo' , @cParentSerialNo '@cParentSerialNo'         
        
                  DELETE FROM dbo.MasterSerialNo WITH (ROWLOCK)         
                  WHERE SerialNo = @cToSerialNo        
                  AND StorerKey = @cStorerKey        
                      
  
                  IF @@ERROR <> 0         
                  BEGIN        
                    SET @nErrNo = 113357        
                    SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelMasterSerialFail        
                    GOTO RollBackTran         
                  END        
  
                  -- Delete And Insert 9L Records --         
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
        
                  -- Insert New 9L Serial No Records  (yeekung01)      
                  INSERT INTO MASTERSERIALNO (        
                              LocationCode        ,UnitType        ,PartnerType  ,SerialNo        ,ElectronicSN  ,Storerkey         
                             ,Sku               ,ItemID       ,ItemDescr     ,ChildQty       ,ParentSerialNo ,ParentSku     ,ParentItemID            
                             ,ParentProdLine    ,VendorSerialNo ,VendorLotNo  ,LotNo           ,Revision       ,CreationDate ,Source                
                             ,Status              ,Attribute1     ,Attribute2  ,Attribute3       ,RequestID        ,UserDefine01  ,UserDefine02          
                             ,UserDefine03        ,UserDefine04     ,UserDefine05   )        
                  SELECT TOP 1 @cLocationCode    ,RIGHT(@cToSerialNo,1)        ,PartnerType  ,@cToSerialNo    ,ElectronicSN        ,Storerkey         
                         ,@cSKU               ,ItemID           ,ItemDescr     ,@nChildQty        ,@cParentSerialNo    ,@cSKU        ,ParentItemID            
                         ,ParentProdLine       ,VendorSerialNo ,VendorLotNo  ,LotNo           ,'1015'          ,CreationDate ,@cWorkOrderNo                
                         ,Status              ,Attribute1     ,Attribute2  ,Attribute3       ,RequestID           ,
                         ((CASE WHEN  @nUserdefine01 IS NOT NULL and @nLocationCode in ('FB', 'FN','FS','FL') THEN 'UPDATE'+SPACE(4) ELSE 'NEW' +SPACE(7) END )+(CASE WHEN @nUserdefine01 IS NULL THEN ''  WHEN Substring(@nUserdefine01,11,10)='' THEN 'NEW' WHEN Substring(@nUserdefine01,11,10)  IN ('NEW','UPDATE')  THEN 'UPDATE' END ))  
                         ,@cLocationCode          
                         ,@cBatchKey           ,UserDefine04     ,UserDefine05          
                  FROM @tMasterSerialTemp         
                  WHERE SerialNo = @cToSerialNo        
                  AND StorerKey = @cStorerKey        
                         
                  SELECT @nUserdefine01=UserDefine01 FROM dbo.MasterSerialNo(NOLOCK) WHERE  StorerKey = @cStorerKey  AND SERIALNO=@cToSerialNo       
      
                  UPDATE dbo.MasterSerialNoTRN SET USERDEFINE01=@nUserdefine01   
                  WHERE MasterSerialnoTrnKey=( SELECT MAX(MasterSerialnoTrnKey)   
                                                FROM dbo.MasterSerialNoTRN WITH (NOLOCK)   
                                                WHERE StorerKey = @cStorerKey    
                                                   AND SERIALNO=@cToSerialNo   
                                                   AND TRANTYPE='WD'   
                                                   AND LOCATIONCODE=@nLocationCode)      
        
  
                  IF @@ERROR <> 0         
                  BEGIN        
                     SET @nErrNo = 113358        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsMasterSerialFail        
                     GOTO RollBackTran        
                  END        
               END        
                     
               SET @nUserdefine01=NULL      
               SELECT @nUserdefine01=UserDefine01,      
                      @nLocationCode=LocationCode      
               FROM dbo.MasterSerialNo WITH (NOLOCK)       
               WHERE SerialNo = @cParentSerialNo   AND StorerKey = @cStorerKey          
        
               SET @cOriginalParentSerialNo = ''                                                   
               SELECT @cOriginalParentSerialNo = ParentSerialNo        
               FROM @tMasterSerialTemp         
               WHERE SerialNo = @cToSerialNo        
                                                                   
        
               IF @cOriginalParentSerialNo <>  @cParentSerialNo --@cMasterserialNo        
               BEGIN        
                          
                  --SELECT @cParentSerialNo '@cParentSerialNo'  , @cOriginalParentSerialNo 'cOriginalParentSerialNo'  , @cMasterserialNo '@cMasterserialNo'        
        
                  IF EXISTS ( SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)         
                             WHERE StorerKey = @cStorerKey        
                             AND ParentSerialNo = @cOriginalParentSerialNo        
                             AND StorerKey = @cStorerKey )         
                  BEGIN         
                      --(yeekung01)       
                     UPDATE dbo.MasterSerialNo         
                     SET Revision = '1015'         
                        ,Source = @cWorkOrderNo       
                        ,UserDefine01  = ((CASE WHEN @cLocationCode in ('FB', 'FN','FS','FL') THEN 'UPDATE'+SPACE(4) ELSE 'NEW' +SPACE(7) END )      
                                        +(CASE WHEN SUBSTRING(UserDefine01,11,10) <>'' THEN 'UPDATE' +SPACE(4) ELSE 'NEW' +SPACE(7) END ))        
                        ,UserDefine02  = @cLocationCode      
                     WHERE ParentSerialNo = @cOriginalParentSerialNo        
                     AND   Serialno = @cToSerialNo        
                     AND StorerKey = @cStorerKey        
                          
                     IF @@ERROR <> 0         
                     BEGIN        
                       SET @nErrNo = 113368        
                       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdrdtSerailFail        
                       GOTO RollBackTran         
                     END        
                          
                     DELETE FROM dbo.MasterSerialNo WITH (ROWLOCK)         
                     WHERE StorerKey = @cStorerKey        
                     AND ParentSerialNo = @cOriginalParentSerialNo        
                     AND Serialno = @cToSerialNo        
                             
        
                     IF @@ERROR <> 0         
                     BEGIN        
                       SET @nErrNo = 113359        
                       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelMasterSerailFail        
                       GOTO RollBackTran        
                     END        
                  END        
               END            
                       
               SET @cOriginalMasterSerialNo = ''                                                   
               SELECT @cOriginalMasterSerialNo = ParentSerialNo        
               FROM dbo.MasterSerialNo WITH (NOLOCK)          
               WHERE SerialNo = @cOriginalParentSerialNo        
               AND StorerKey = @cStorerKey        
                       
        
               IF @cOriginalMasterSerialNo <>  @cMasterserialNo        
               BEGIN        
                          
                  --SELECT @cOriginalMasterSerialNo '@@cOriginalMasterSerialNo'  , @cMasterserialNo '@cMasterserialNo' , @cOriginalParentSerialNo '@cOriginalParentSerialNo'                       
        
                  IF EXISTS ( SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)         
                             WHERE StorerKey = @cStorerKey        
                             AND SerialNo = @cParentSerialNo )         
                  BEGIN         
                       --(yeekung01)      
                     UPDATE dbo.MasterSerialNo         
                     SET Revision = '1015'         
                        ,Source = @cWorkOrderNo      
                        ,UserDefine01  = ((CASE WHEN @cLocationCode in ('FB', 'FN','FS','FL') THEN 'UPDATE'+SPACE(4) ELSE 'NEW' +SPACE(7) END )      
                                       +(CASE WHEN SUBSTRING(UserDefine01,11,10) <>'' THEN 'UPDATE' +SPACE(4) ELSE 'NEW' +SPACE(7) END ))       
                        ,UserDefine02  = @cLocationCode        
                     WHERE StorerKey = @cStorerKey        
                     AND   SerialNo  = @cParentSerialNo        
                     AND   ParentSerialNo = @cOriginalMasterSerialNo        
                          
                     IF @@ERROR <> 0         
                     BEGIN        
                       SET @nErrNo = 113368        
                       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdrdtSerailFail        
                       GOTO RollBackTran         
                     END        
                          
                     DELETE FROM dbo.MasterSerialNo WITH (ROWLOCK)         
                     WHERE StorerKey = @cStorerKey        
                     AND   SerialNo  = @cParentSerialNo        
                     AND   ParentSerialNo = @cOriginalMasterSerialNo        
        
                     IF @@ERROR <> 0         
                     BEGIN        
                       SET @nErrNo = 113359        
                       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelMasterSerailFail        
                       GOTO RollBackTran        
                     END        
                  END        
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
                     AND Func = @nFromFunc         
                     --AND ParentSerialNo = @cParentSerialNo        
                     --AND AddWho = @cUserName        
                     AND BatchKey2 = @cBatchKey        
                             
                     --SELECT @nInnerQty '@nInnerQty' , @cParentSerialNo '@cParentSerialNo' , @cMasterserialNo '@cMasterserialNo'        
        
                     -- Insert New Inner Serial No Records        
                     INSERT INTO MASTERSERIALNO (        
                                LocationCode        ,UnitType        ,PartnerType  ,SerialNo        ,ElectronicSN  ,Storerkey         
                                ,Sku               ,ItemID           ,ItemDescr     ,ChildQty       ,ParentSerialNo ,ParentSku     ,ParentItemID            
                                ,ParentProdLine    ,VendorSerialNo ,VendorLotNo  ,LotNo           ,Revision       ,CreationDate ,Source                
                                ,Status              ,Attribute1     ,Attribute2  ,Attribute3       ,RequestID       ,UserDefine01  ,UserDefine02          
                                ,UserDefine03        ,UserDefine04     ,UserDefine05   )        
                     SELECT TOP 1 @cLocationCode  ,RIGHT(@cParentSerialNo,1)     ,PartnerType     ,@cParentSerialNo    ,ElectronicSN     ,Storerkey         
                            ,@cSKU              ,ItemID           ,ItemDescr     ,@nParentQty      ,@cMasterserialNo    ,@cSKU     ,ParentItemID            
                            ,ParentProdLine    ,VendorSerialNo ,VendorLotNo  ,LotNo           ,'1015'          ,CreationDate ,@cWorkOrderNo                
                            ,Status           ,Attribute1     ,Attribute2  ,Attribute3       ,RequestID           ,
                            ((CASE WHEN  @nUserdefine01 IS NOT NULL and @nLocationCode in ('FB', 'FN','FS','FL') THEN 'UPDATE'+SPACE(4) ELSE 'NEW' +SPACE(7) END )+
                            (CASE WHEN  @nUserdefine01 IS NULL THEN '' WHEN @nUserdefine01 IS NOT NULL and SUBSTRING(@nUserdefine01,11,10) =''  THEN  'NEW' +SPACE(7)   WHEN  @nUserdefine01 IS NOT NULL and SUBSTRING(@nUserdefine01,11,10) <>'' THEN 'UPDATE' +SPACE(4)   END )) 
                            ,@cLocationCode          
                            ,@cBatchKey     ,UserDefine04     ,UserDefine05          
                     FROM dbo.MASTERSERIALNO WITH (NOLOCK)         
                     WHERE SerialNo = @cToSerialNo        
                     AND StorerKey = @cStorerKey        
                             
                     IF @@ERROR <> 0         
                     BEGIN        
                        SET @nErrNo = 113360        
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
               AND Func = @nFromFunc         
               AND BatchKey2 = @cBatchKey        
               --AND AddWho = @cUserName        
               AND RowRef = @nRowRef        
                       
               IF @@ERROR <>  0         
               BEGIN        
                   SET @nErrNo = 113361        
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
           
   IF @nFunc = 1013        
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
                SET @nInnerQty  = @nInnerPack --@nMasterQty * ( @nCaseCnt / @nInnerPack )         
                    
                SET @nCLabelQty = @nCaseCnt / @nInnerQty        
            END         
            ELSE        
            BEGIN        
               SET @nCLabelQty = @nCaseCnt         
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
      
               --PRINT  @cToSerialNo        
               IF ISNULL(@cParentSerialNo,'')  = ''         
               BEGIN         
                     SET @cParentSerialNo = @cMasterserialNo        
               END        
                       
               -- Delete And Insert 9L Records --         
                       
               -- Insert into Temp Table before Delete        
               INSERT INTO @tMasterSerialTemp (        
                            LocationCode        ,UnitType     ,PartnerType  ,SerialNo        ,ElectronicSN  ,Storerkey         
                         ,Sku               ,ItemID           ,ItemDescr     ,ChildQty       ,ParentSerialNo ,ParentSku     ,ParentItemID            
                         ,ParentProdLine    ,VendorSerialNo ,VendorLotNo  ,LotNo           ,Revision       ,CreationDate ,Source                
                         ,Status              ,Attribute1     ,Attribute2  ,Attribute3       ,RequestID        ,UserDefine01  ,UserDefine02          
                         ,UserDefine03        ,UserDefine04     ,UserDefine05   )        
               SELECT TOP 1 LocationCode    ,UnitType        ,PartnerType  ,SerialNo     ,ElectronicSN     ,Storerkey         
                     ,SKU        ,ItemID           ,ItemDescr     ,ChildQty       ,ParentSerialNo   ,ParentSKU     ,ParentItemID            
                     ,ParentProdLine    ,VendorSerialNo ,VendorLotNo  ,LotNo           ,Revision          ,CreationDate ,Source                
                     ,Status              ,Attribute1     ,Attribute2  ,Attribute3       ,RequestID           ,('NEW'+space(7))  ,UserDefine02          
                     ,@cBatchKey        , UserDefine04  ,UserDefine05          
               FROM dbo.MASTERSERIALNO WITH (NOLOCK)         
               WHERE SerialNo = @cToSerialNo        
               AND StorerKey = @cStorerKey        
      
               SET @nUserdefine01=NULL      
               SELECT @nUserdefine01=UserDefine01,      
                @nLocationCode=LocationCode      
               FROM dbo.MasterSerialNo WITH (NOLOCK)       
               WHERE SerialNo = @cToSerialNo     
                  AND StorerKey = @cStorerKey       
                            
               -- Interface purpose.        
               UPDATE dbo.MasterSerialNo WITH (ROWLOCK)         
               SET Revision = '1013'         
                  ,Source = @cWorkOrderNo        
                  ,UserDefine02  = @cLocationCode      
               WHERE SerialNo = @cToSerialNo         
               AND StorerKey = @cStorerKey        
                       
               IF @@ERROR <> 0         
               BEGIN        
                  SET @nErrNo = 113356        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelMasterSerialFail        
                  GOTO RollBackTran         
               END        
                       
               -- Delete MasterSerialNo Records         
               DELETE FROM dbo.MasterSerialNo WITH (ROWLOCK)         
               WHERE SerialNo = @cToSerialNo        
               AND StorerKey = @cStorerKey        
                       
               IF @@ERROR <> 0         
               BEGIN        
                 SET @nErrNo = 113351        
                 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelMasterSerialFail        
                 GOTO RollBackTran         
               END        
        
               SELECT @nChildQty = Count(RowRef)         
               FROM rdt.rdtSerialNoLog WITH (NOLOCK)         
               WHERE StorerKey = @cStorerKey        
               --AND Status = '5'         
               AND ToSKU = @cSKU        
               AND SourceKey = @cWorkOrderNo        
               --AND ParentSerialNo = CASE WHEN ISNULL(@cParentSerialNo,'') <> '' THEN @cParentSerialNo ELSE ParentSerialNo END        
               AND ParentSerialNo = CASE WHEN ISNULL(ParentSerialNo,'') <> '' THEN @cParentSerialNo ELSE ParentSerialNo END        
               AND Func = @nFunc         
               AND AddWho = @cUserName        
               AND BatchKey = @cBatchKey        
        
               --SELECT @nChildQty '@nChildQty' , @cParentSerialNo '@cParentSerialNo' , @cSKU '@cSKU' , @cWorkOrderNo '@cWorkOrderNo' , @nFunc '@nFunc' ,  @cUserName '@cUserName' , @cBatchKey '@cBatchKey'        
        
        
        
               -- Insert New 9L Serial No Records        
               INSERT INTO MASTERSERIALNO (        
                           LocationCode        ,UnitType        ,PartnerType  ,SerialNo        ,ElectronicSN  ,Storerkey         
                          ,Sku               ,ItemID           ,ItemDescr     ,ChildQty       ,ParentSerialNo ,ParentSku     ,ParentItemID            
                           ,ParentProdLine    ,VendorSerialNo ,VendorLotNo  ,LotNo           ,Revision       ,CreationDate ,Source                
                           ,Status,Attribute1     ,Attribute2  ,Attribute3       ,RequestID        ,UserDefine01  ,UserDefine02          
                          ,UserDefine03        ,UserDefine04     ,UserDefine05   )        
               SELECT TOP 1 @cLocationCode    ,RIGHT(@cToSerialNo,1)        ,PartnerType  ,@cToSerialNo    ,ElectronicSN        ,Storerkey         
                      ,@cSKU               ,ItemID           ,ItemDescr     ,@nChildQty       ,@cParentSerialNo    ,@cSKU        ,ParentItemID            
                      ,ParentProdLine       ,VendorSerialNo ,VendorLotNo  ,LotNo           ,'1013'          ,CreationDate ,@cWorkOrderNo                
                      ,Status              ,Attribute1     ,Attribute2  ,Attribute3       ,RequestID           ,((CASE WHEN  @nUserdefine01 IS NOT NULL and @nLocationCode in ('FB', 'FN','FS','FL') THEN 'UPDATE'+SPACE(4) ELSE 'NEW' +SPACE(7) END )      
                      +(CASE WHEN @nUserdefine01 IS NULL THEN ''  WHEN Substring(@nUserdefine01,11,10)='' THEN 'NEW' WHEN Substring(@nUserdefine01,11,10) IN ('NEW','UPDATE') THEN 'UPDATE' END ))  ,@cLocationCode          
                      ,@cBatchKey        ,UserDefine04     ,UserDefine05          
               FROM @tMasterSerialTemp         
               WHERE SerialNo = @cToSerialNo        
               AND StorerKey = @cStorerKey        
                       
               IF @@ERROR <> 0         
               BEGIN        
                  SET @nErrNo = 113352        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsMasterSerialFail        
                  GOTO RollBackTran        
               END        
        
               SET @nUserdefine01=NULL      
               SELECT @nUserdefine01=UserDefine01,      
                      @nLocationCode=LocationCode      
               FROM dbo.MasterSerialNo WITH (NOLOCK)       
               WHERE SerialNo = @cParentSerialNo         
                  AND StorerKey = @cStorerKey        
                                                        
               SELECT @cOriginalParentSerialNo = ParentSerialNo        
               FROM dbo.MasterSerialNo WITH (NOLOCK)         
               WHERE SerialNo = @cToSerialNo        
                  AND StorerKey = @cStorerKey        
                         
               IF EXISTS ( SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)         
                          WHERE StorerKey = @cStorerKey        
                          AND SerialNo = @cOriginalParentSerialNo )         
               BEGIN         
                  UPDATE dbo.MasterSerialNo --(yeekung02)         
                  SET Revision = '1013'         
                     ,Source = @cWorkOrderNo        
                     ,UserDefine01  = ((CASE WHEN @cLocationCode in ('FB', 'FN','FS','FL') THEN 'UPDATE'+SPACE(4) ELSE 'NEW' +SPACE(7) END )      
                                    +(CASE WHEN SUBSTRING(UserDefine01,11,10) <>'' THEN 'UPDATE' +SPACE(4) ELSE 'NEW' +SPACE(7) END ))       
                     ,UserDefine02  = @cLocationCode       
                  WHERE SerialNo = @cOriginalParentSerialNo        
                  AND StorerKey = @cStorerKey        
                          
                  IF @@ERROR <> 0         
                  BEGIN        
                    SET @nErrNo = 113367        
                    SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdrdtSerailFail        
                    GOTO RollBackTran         
                  END          
                          
                  DELETE FROM dbo.MasterSerialNo WITH (ROWLOCK)         
                  WHERE StorerKey = @cStorerKey        
                  AND SerialNo = @cOriginalParentSerialNo        
                
        
                  IF @@ERROR <> 0         
                  BEGIN        
                    SET @nErrNo = 113353        
                    SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelMasterSerailFail        
                    GOTO RollBackTran        
                  END        
               END        
           
               SELECT @nUserdefine01=USERDEFINE01   
               FROM dbo.MasterSerialNo(NOLOCK)   
               WHERE  StorerKey = @cStorerKey    
               AND SERIALNO=@cToSerialNo       
                 
               UPDATE dbo.MasterSerialNoTRN   
               SET USERDEFINE01=@nUserdefine01   
               WHERE MasterSerialnoTrnKey=(       
                SELECT MAX(MasterSerialnoTrnKey)   
                FROM dbo.MasterSerialNoTRN WITH (NOLOCK)   
                WHERE StorerKey = @cStorerKey    
                AND SERIALNO=@cToSerialNo   
                AND TRANTYPE='WD'   
                AND LOCATIONCODE=@nLocationCode      
             )      
       
               IF ISNULL(@nInnerQty,0 ) > 0         
               BEGIN         
                  
        
                  IF NOT EXISTS (SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)         
                                 WHERE StorerKey = @cStorerKey         
                                 AND SKU = @cSKU        
                                 AND SerialNo =  @cParentSerialNo)         
                  BEGIN        
                             
        
               -- Insert New Inner Serial No Records  (yeekung02)      
                     INSERT INTO MASTERSERIALNO (        
                                LocationCode        ,UnitType        ,PartnerType  ,SerialNo        ,ElectronicSN  ,Storerkey         
                                ,Sku               ,ItemID           ,ItemDescr     ,ChildQty       ,ParentSerialNo ,ParentSku     ,ParentItemID            
                                ,ParentProdLine    ,VendorSerialNo ,VendorLotNo  ,LotNo           ,Revision       ,CreationDate ,Source                
                                ,Status              ,Attribute1     ,Attribute2  ,Attribute3       ,RequestID        ,UserDefine01  ,UserDefine02          
                                ,UserDefine03        ,UserDefine04     ,UserDefine05   )        
                     SELECT TOP 1 @cLocationCode  ,RIGHT(@cParentSerialNo,1) ,PartnerType  ,@cParentSerialNo    ,ElectronicSN     ,Storerkey         
                            ,@cSKU              ,ItemID           ,ItemDescr     ,@nCLabelQty       ,@cMasterserialNo    ,@cSKU     ,ParentItemID            
                            ,ParentProdLine    ,VendorSerialNo ,VendorLotNo  ,LotNo           ,'1013'          ,CreationDate ,@cWorkOrderNo                
                            ,Status           ,Attribute1     ,Attribute2  ,Attribute3       ,RequestID           ,
                            ((CASE WHEN  @nUserdefine01 IS NOT NULL and @nLocationCode in ('FB', 'FN','FS','FL') THEN 'UPDATE'+SPACE(4) ELSE 'NEW' +SPACE(7) END )     
                            +(CASE WHEN  @nUserdefine01 IS NULL THEN '' WHEN @nUserdefine01 IS NOT NULL and SUBSTRING(@nUserdefine01,11,10) =''  THEN  'NEW' +SPACE(7)   
                            WHEN  @nUserdefine01 IS NOT NULL and SUBSTRING(@nUserdefine01,11,10) <>'' THEN 'UPDATE' +SPACE(4)   END )),      
                            @cLocationCode,@cBatchKey     ,UserDefine04,UserDefine05          
                     FROM dbo.MASTERSERIALNO WITH (NOLOCK)         
                     WHERE SerialNo = @cToSerialNo        
                     AND StorerKey = @cStorerKey        
                             
                     IF @@ERROR <> 0         
                     BEGIN        
                        SET @nErrNo = 113354        
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
                   SET @nErrNo = 113355        
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
      ROLLBACK TRAN rdt_1015ExtUpdSP01        
      
   Quit:        
 WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started        
         COMMIT TRAN rdt_1015ExtUpdSP01        
        
          
Fail:          
END 

GO