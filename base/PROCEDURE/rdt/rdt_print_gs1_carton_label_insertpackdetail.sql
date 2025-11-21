SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/        
/* Store procedure: rdt_Print_GS1_Carton_Label_InsertPackDetail         */        
/* Copyright      : IDS                                                 */        
/*                                                                      */        
/* Purpose: Insert PackDetail after each scan of Case ID                */        
/*                                                                      */        
/* Called from: rdtfnc_Scan_And_Pack                                    */        
/*                                                                      */        
/* Modifications log:                                                   */        
/*                                                                      */        
/* Date        Rev  Author    Purposes                                  */        
/* 21-Jan-2010 1.0  ChewKP    Created                                   */        
/* 01-Mar-2010 1.1  ChewKP    Add DropID Parameter for                  */        
/*                            isp_GSICartonLabel (ChewKP01)             */        
/* 21-Jul-2010 1.2  James     SOS182663 - Bug fix (james01)             */        
/* 28-07-2010  1.3  Leong     SOS# 183480 - Performance Trace           */        
/* 03-08-2010  1.4  Vicky     Revamp Error Message (Vicky02)            */       
/* 31-Mar-2011 1.5  Shong     TCP Printing Features for Bartender       */       
/* 06-Jul-2011 1.6  Shong     Bug Fixing                                */    
/* 06-08-2010  1.7  Shong     Do not generated DropIDDetail if Drop ID  */  
/*                            already generated (Shong01)               */  
/* 21-02-2011  1.8  ChewKP    Bug Fixes (ChewKP02)                      */  
/* 22-06-2011  1.9  ChewKP    SOS#219051 - Carter for Non BOM (ChewKP03)*/  
/* 06-01-2012  2.0  Ung       SOS231812 Standarize printGS1 use Exceed's*/  
/*                            From US Production                        */
/************************************************************************/        
        
CREATE PROC [RDT].[rdt_Print_GS1_Carton_Label_InsertPackDetail] (    
   @nMobile              INT,        
   @cFacility            NVARCHAR( 5),        
   @cStorerKey           NVARCHAR( 15),        
   @cDropID              NVARCHAR( 18),        
   @cOrderKey            NVARCHAR( 10),        
   @cPickSlipType        NVARCHAR( 10),        
   @cPickSlipNo          NVARCHAR( 10), -- can be conso ps# or discrete ps#; depends on pickslip type        
   @cBuyerPO             NVARCHAR( 20),        
   @cFilePath1           NVARCHAR( 20),        
   @cFilePath2           NVARCHAR( 20),        
   @n_PrePack            INT,        
   @cUserName            NVARCHAR( 18),        
   @cGS1TemplatePath_Final NVARCHAR( 120),        
   @cPrinter             NVARCHAR( 20),        
   @cLangCode            VARCHAR (3),        
   @nErrNo               INT          OUTPUT,        
   @cErrMsg              NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max        
) AS        
BEGIN    
    SET NOCOUNT ON        
    SET QUOTED_IDENTIFIER OFF        
    SET ANSI_NULLS OFF        
    SET ANSI_WARNINGS OFF 
        
    DECLARE @b_success       INT    
           ,@n_err           INT    
           ,@c_errmsg        NVARCHAR(255)        
        
    DECLARE @cPickHeaderKey  NVARCHAR(10)    
           ,@cLabelLine      NVARCHAR( 5)        
           ,@cComponentSku   NVARCHAR(20)    
           ,@nComponentQTY   INT    
           ,@nTranCount      INT    
           ,@cDateTime       NVARCHAR(17)    
           ,@cSPID           NVARCHAR(5)    
           ,@cFileName       NVARCHAR(215)    
           ,@nSumQtyPicked   INT    
           ,@nSumQtyPacked   INT    
           ,@nMax_CartonNo   INT    
           ,@cPackkey        NVARCHAR(10)    
           ,@nTotalLoop      INT    
           ,@nUPCCaseCnt     INT    
           ,@cParentSKU      NVARCHAR(20)    
           ,@nTotalBOMQty    INT    
           ,@nCaseCnt        INT    
           ,@cPDPackkey      NVARCHAR(10)    
           ,@cPalletID       NVARCHAR(10)    
           ,@nPDQTY          INT    
           ,@nCartonNo       INT    
           ,@cLabelNo        NVARCHAR(20)    
           ,@cGS1BatchNo     NVARCHAR(10)                         
        
    DECLARE @cMS             NVARCHAR(3)    
           ,@dTempDateTime   DATETIME        
           ,@nDropIDChild    INT  
           ,@cPrepackByBOM   NVARCHAR(1)  -- (ChewKP03)  
           ,@cSKU            NVARCHAR(20) -- (ChewKP03)  
        
    DECLARE @n_debug         INT        
    SET @n_debug = 0        

    IF ISNUMERIC(@cErrMsg) = 1 AND LEN(@cErrMsg) > 0 
       SET @cGS1BatchNo = @cErrMsg
    ELSE 
    BEGIN
       SET @cGS1BatchNo = ''
       EXEC isp_GetGS1BatchNo 5,  @cGS1BatchNo OUTPUT 
    END
            
--    IF @n_debug = 1    
--    BEGIN    
        DECLARE @d_starttime  DATETIME    
               ,@d_endtime    DATETIME    
               ,@d_step1      DATETIME    
               ,@d_step2      DATETIME    
               ,@d_step3      DATETIME    
               ,@d_step4      DATETIME    
               ,@d_step5      DATETIME    
               ,@c_col1       NVARCHAR(20)    
               ,@c_col2       NVARCHAR(20)    
               ,@c_col3       NVARCHAR(20)    
               ,@c_col4       NVARCHAR(20)    
               ,@c_col5       NVARCHAR(20)    
               ,@c_TraceName  NVARCHAR(80)
               ,@n_Step1Ctn   INT
               ,@n_Step2Ctn   INT
               ,@n_Step3Ctn   INT
               ,@n_Step4Ctn   INT
               ,@n_Step5Ctn   INT        
         
        SET @n_Step1Ctn = 0
        SET @n_Step2Ctn = 0
        SET @n_Step3Ctn = 0
        SET @n_Step4Ctn = 0
        SET @n_Step5Ctn = 0   
        SET @c_col1 = ''        
        SET @c_col1 = @cOrderKey     
        SET @c_col2 = @cPickSlipNo    
        SET @c_col3 = @cDropID        
        SET @c_col4 = sUser_sName() 
        SET @c_col5 = @cGS1BatchNo       
        SET @d_starttime = GETDATE()        
        SET @c_TraceName = 'rdt_Print_GS1_Carton_Label_InsertPackDetail'    
 --   END        
      
    -- (ChewKP03)  
    IF EXISTS (SELECT 1 FROM dbo.StorerConfig WITH (NOLOCK)  
        WHERE Storerkey = @cStorerKey  
            AND Configkey = 'PrepackByBOM'  
            AND SValue = '1')  
         SET @cPrepackByBOM = '1'  
    ELSE  
         SET @cPrepackByBOM = '0'  
  
        
    SET @nTranCount = @@TRANCOUNT     
        
    BEGIN TRAN     
    SAVE TRAN GS1_InsertPackDetail     
        
    IF @cPrepackByBOM = '1'        
    BEGIN    
        SET @d_step1 = GETDATE()        
        SET @nCartonNo = 0     
            
        --- GET USERNAME ---        
        SELECT @cUserName = UserName    
        FROM   RDT.RDTMOBREC WITH (NOLOCK)    
        WHERE  MOBILE = @nMobile        
            
        SET @cLabelLine = '00000'        
            
        BEGIN    
            SET @nTotalLoop = 0     
            -- Get the next label no  
                  
            IF @n_debug = 1  
            BEGIN  
               --SOS# 183480      
               INSERT INTO dbo.GS1LOG  
                 (  
                   MobileNo  
                  ,UserName  
                  ,TraceName  
                  ,PickSlipNo  
                  ,OrderKey  
                  ,DropId  
                  ,StorerKey  
                  ,Facility  
                  ,Col1  
                  ,Col2  
                  ,Col3  
                  ,Col10  
                 )  
               VALUES  
                 (  
                   @nMobile  
                  ,@cUserName  
                  ,'GS1SubSP'  
                  ,@cPickSlipNo  
                  ,@cOrderkey  
                  ,@cDropID  
                  ,@cStorerkey  
                  ,@cFacility  
                  ,@cPickSlipType  
                  ,@n_PrePack  
                  ,@@SPID  
                  ,'*'  
                 )      
            END 
                         
            DECLARE CUR_INSPACKDETAILBOM CURSOR LOCAL READ_ONLY FAST_FORWARD     
            FOR    
                SELECT DISTINCT LA.Lottable03    
                FROM   dbo.PickDetail PD WITH (NOLOCK)    
                       INNER JOIN dbo.LOTATTRIBUTE LA(NOLOCK)    
                            ON  (LA.Storerkey = PD.Storerkey AND LA.SKU = PD.SKU AND LA.LOT = PD.LOT)    
                WHERE  PD.StorerKey = @cStorerkey    
                AND    PD.Orderkey = @cOrderkey    
                AND    PD.DropID = @cDropID     
            OPEN CUR_INSPACKDETAILBOM     
            FETCH NEXT FROM CUR_INSPACKDETAILBOM INTO @cParentSKU        
            WHILE @@FETCH_STATUS <> - 1    
            BEGIN    
                SET @nTotalLoop = 0 -- SOS# 183480        
                SET @nUPCCaseCnt = 0 -- SOS# 183480        
                SET @nPDQTY = 0 -- SOS# 183480        
                SET @nTotalBOMQty = 0 -- SOS# 183480        
                    
                SELECT @nUPCCaseCnt = ISNULL(PACK.CaseCnt ,0)    
                FROM   dbo.PACK PACK WITH (NOLOCK)    
                       JOIN dbo.UPC UPC WITH (NOLOCK)    
                            ON  (UPC.Packkey = PACK.Packkey)    
                WHERE  UPC.SKU = @cParentSKU    
                AND    UPC.Storerkey = @cStorerkey    
                AND    UPC.UOM = 'CS'        
                    
                SELECT @nPDQTY = SUM(PD.QTY)    
                FROM   dbo.PickDetail PD WITH (NOLOCK)    
                       JOIN dbo.Lotattribute LA WITH (NOLOCK)    
                            ON  (PD.Storerkey = LA.Storerkey AND PD.SKU = LA.SKU AND PD.LOT = LA.Lot)    
                WHERE  PD.DropID = @cDropID    
                AND    LA.Lottable03 = @cParentSKU    
                AND    PD.Storerkey = @cStorerkey    
                AND    PD.Orderkey = @cOrderkey        
                    
                SELECT @nTotalBOMQty = SUM(BOM.QTY)    
                FROM   dbo.BillOfMaterial BOM WITH (NOLOCK)    
                WHERE  BOM.Storerkey = @cStorerKey    
                AND    BOM.SKU = @cParentSKU     

                IF @n_debug = 1  
                BEGIN  
                   --SOS# 183480      
                   INSERT INTO dbo.GS1LOG  
                     (  
                       MobileNo  
                      ,UserName  
                      ,TraceName  
                      ,PickSlipNo  
                      ,OrderKey  
                      ,DropId  
                      ,StorerKey  
                      ,Facility  
                      ,Col1  
                      ,Col2  
                      ,Col3  
                      ,Col4  
                      ,Col5  
                      ,Col6  
                      ,Col7  
                      ,Col10  
                     )  
                   VALUES  
                     (  
                       @nMobile  
                      ,@cUserName  
                      ,'GS1SubSP'  
                      ,@cPickSlipNo  
                      ,@cOrderkey  
                      ,@cDropID  
                      ,@cStorerkey  
                      ,@cFacility  
                      ,@cPickSlipType  
                      ,@n_PrePack  
                      ,@@SPID  
                      ,@cParentSKU  
                      ,@nTotalBOMQty  
                      ,@nUPCCaseCnt  
                      ,@nPDQTY  
                      ,'**'  
                     )   
                END
                
                IF @nTotalBOMQty > 0    
                AND @nUPCCaseCnt > 0 -- SOS# 183480    
                BEGIN    
                    SELECT @nTotalLoop = CEILING(@nPDQTY /(@nTotalBOMQty * @nUPCCaseCnt))    
                END        
                  
                -- (ChewKP03)  
                -- Added By SHONG on 06-Aug-2010  
                -- OverPacked Issues (Shong01)  
--                SET @nDropIDChild = 0  
--                SELECT @nDropIDChild = COUNT(*)  
--                FROM   DROPIDDETAIL WITH (NOLOCK)  
--                WHERE  DropID = @cDropID             
           
                --WHILE @nTotalLoop > @nDropIDChild -- (Shong01) -- (ChewKP03)  
                WHILE @nTotalLoop > 0    
                BEGIN    
                    EXECUTE [RDT].[rdt_GenUCCLabelNo]     
                    @cStorerKey,     
                    @nMobile,     
                    @cLabelNo OUTPUT,     
                    @cLangCode,     
                    @nErrNo OUTPUT,     
                    @cErrMsg OUTPUT  
                       
                    IF @n_debug = 1  
                    BEGIN  
                       --SOS# 183480      
                       INSERT INTO dbo.GS1LOG  
                         (  
                           MobileNo  
                          ,UserName  
                          ,TraceName  
                          ,PickSlipNo  
                          ,OrderKey  
                          ,DropId  
                          ,StorerKey  
                          ,Facility  
                          ,Col1  
                          ,Col2  
                          ,Col3  
                          ,Col4  
                          ,Col5  
                          ,Col6  
                          ,Col7  
                          ,Col10  
                         )  
                       VALUES  
                         (  
                           @nMobile  
                          ,@cUserName  
                          ,'GS1SubSP'  
                          ,@cPickSlipNo  
                          ,@cOrderkey  
                          ,@cDropID  
                          ,@cStorerkey  
                          ,@cFacility  
                          ,@cLabelNo  
                          ,@nErrNo  
                          ,''  
                          ,''  
                          ,''  
                          ,''  
                          ,''  
                          ,'UCCLBL'  
                         )  
                    END
                    
                    IF @nErrNo <> 0    
                    BEGIN    
                        SET @nErrNo = 68748        
                        SET @cErrMsg = rdt.rdtgetmessage(68748 ,@cLangCode ,'DSP') --'Gen LBLNo Fail'        
                        GOTO RollBackTran    
                    END     
                        
                    -----SOS# 183480 Start    
                    --    INSERT INTO dbo.DropIDDetail    
                    --    (DROPID, CHILDID, AddWho, EditWho, ArchiveCop)    
                    --    VALUES (@cDropID, @cLabelNo, @cUserName, @cUserName, 'd')    
                    --    
                    --    IF @@ERROR <> 0    
                    --    BEGIN    
                    --     SET @nErrNo = 68750    
                    --     SET @cErrMsg = rdt.rdtgetmessage( 68750, @cLangCode, 'DSP') --'InsDropIDDet'    
                    --     GOTO RollBackTran    
                    --    END    
                    -----SOS# 183480 End      
                        
                    DECLARE CUR_BOM  CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
                        SELECT ComponentSKU    
                              ,QTY       
                        FROM   dbo.BILLOFMATERIAL WITH (NOLOCK)    
                        WHERE  SKU = @cParentSKU    
                        AND    StorerKey = @cStorerKey -- (james01)        
                    OPEN CUR_BOM     
                    FETCH NEXT FROM CUR_BOM INTO @cComponentSKU, @nComponentQTY                                             
                    WHILE @@FETCH_STATUS <> - 1    
                    BEGIN    
                        IF NOT EXISTS (SELECT 1 FROM   dbo.PackDetail WITH (NOLOCK)    
                               WHERE  Pickslipno = @cPickSlipNo    
                               AND    Storerkey = @cStorerKey    
                               AND    SKU = @cComponentSku    
                               AND    LabelNo = @cLabelNo    
                           )    
                        BEGIN    
                            INSERT INTO dbo.PackDetail    
                              ( PickSlipNo ,CartonNo ,LabelNo ,LabelLine ,StorerKey    
                               ,SKU ,QTY ,Refno ,AddWho ,AddDate ,EditWho ,EditDate )    
                            VALUES    
                              ( @cPickSlipNo ,@nCartonNo ,@cLabelNo ,@cLabelLine ,@cStorerKey    
                               ,@cComponentSku ,@nComponentQTY ,@cDropID ,@cUserName     
                               ,GETDATE() ,@cUserName ,GETDATE() )        
                                
                            IF @@ERROR <> 0    
                            BEGIN    
                                SET @nErrNo = 68749        
                                SET @cErrMsg = rdt.rdtgetmessage(68749 ,@cLangCode ,'DSP') --'InsPackDFail'        
                                GOTO RollBackTran    
                            END    
                        END
                        SET @n_Step4Ctn = @n_Step4Ctn + 1
                        SEt @d_Step4    = GETDATE()     
                        FETCH NEXT FROM CUR_BOM INTO @cComponentSKU, @nComponentQTY 
                    END     
                    CLOSE CUR_BOM     
                    DEALLOCATE CUR_BOM     
                        
                    -----SOS# 183480 Start      
                    INSERT INTO dbo.DropIDDetail    
                      ( DROPID ,CHILDID ,AddWho ,EditWho ,ArchiveCop )    
                    VALUES    
                      ( @cDropID ,@cLabelNo ,@cUserName ,@cUserName ,'d' )        
                        
                    IF @@ERROR <> 0    
                    BEGIN    
                        SET @nErrNo = 68750        
                        SET @cErrMsg = rdt.rdtgetmessage(68750 ,@cLangCode ,'DSP') --'InsDropIDDet'        
                        GOTO RollBackTran    
                    END     
                    -----SOS# 183480 End      
                    SET @nTotalLoop = @nTotalLoop - 1    
                END -- @nTotalLoop > 0        
                SET @n_Step1Ctn = @n_Step1Ctn + 1 
                      
                FETCH NEXT FROM CUR_INSPACKDETAILBOM INTO @cParentSKU    
            END -- CUR_INSPACKDETAILBOM        
                
            CLOSE CUR_INSPACKDETAILBOM     
            DEALLOCATE CUR_INSPACKDETAILBOM    
        END   
        SET @d_Step4 = @d_Step4 - @d_step1 
        SET @d_step1 = GETDATE() - @d_step1 
    END -- @cPrepackByBOM = '1'  
    ELSE -- @cPrepackByBOM = '0'  
    BEGIN  
        SET @d_step2 = GETDATE()        
        SET @nCartonNo = 0     
            
        --- GET USERNAME ---        
        SELECT @cUserName = UserName    
        FROM   RDT.RDTMOBREC WITH (NOLOCK)    
        WHERE  MOBILE = @nMobile        
            
        SET @cLabelLine = '00000'        
            
        BEGIN    
            SET @nTotalLoop = 0     
            -- Get the next label no        
             
            DECLARE CUR_INSPACKDETAIL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
               SELECT DISTINCT PD.SKU , SKU.Packkey  
               FROM   dbo.PickDetail PD WITH (NOLOCK)  
               INNER  JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.SKU = PD.SKU AND SKU.Storerkey = PD.Storerkey )   
               WHERE  PD.StorerKey = @cStorerkey   
                  AND PD.Orderkey  = @cOrderkey   
                  AND PD.DropID    = @cDropID  
                       
            OPEN CUR_INSPACKDETAIL     
            FETCH NEXT FROM CUR_INSPACKDETAIL INTO @cSKU, @cPackkey   
            WHILE @@FETCH_STATUS <> - 1    
            BEGIN    
               SET @nTotalLoop = 0     
               SET @nCaseCnt = 0    
               SET @nPDQTY = 0      
                    
                SELECT @nCaseCnt = ISNULL(PACK.CaseCnt ,0)  
                FROM   dbo.PACK PACK WITH (NOLOCK)  
                WHERE  PackKey = @cPackKey  
                  
                SELECT @nPDQTY = SUM(PD.QTY)  
                FROM   dbo.PickDetail PD WITH (NOLOCK)  
                WHERE  PD.DropID = @cDropID AND  
                       PD.Storerkey = @cStorerkey AND  
                       PD.Orderkey = @cOrderkey   
                                  
                IF @nPDQTY>0 AND @nCaseCnt>0   
                BEGIN  
                      SELECT @nTotalLoop = CEILING(@nPDQTY/(@nCaseCnt))  
                END    
                  
                -- Added By SHONG on 06-Aug-2010  
                -- OverPacked Issues (Shong01)  
--                SET @nDropIDChild = 0  
--                SELECT @nDropIDChild = COUNT(*)  
--                FROM   DROPIDDETAIL WITH (NOLOCK)  
--                WHERE  DropID = @cDropID  
           
                --WHILE @nTotalLoop > @nDropIDChild -- (Shong01)  
                WHILE @nTotalLoop > 0    
                BEGIN    
                    EXECUTE [RDT].[rdt_GenUCCLabelNo]     
                    @cStorerKey,     
                    @nMobile,     
                    @cLabelNo OUTPUT,     
                    @cLangCode,     
                    @nErrNo OUTPUT,     
                    @cErrMsg OUTPUT     
                        
                     
                   IF @nErrNo <> 0    
                    BEGIN    
                        SET @nErrNo = 68748        
                        SET @cErrMsg = rdt.rdtgetmessage(68748 ,@cLangCode ,'DSP') --'Gen LBLNo Fail'        
                        GOTO RollBackTran    
                    END     
                        
                     IF NOT EXISTS (SELECT 1    
                            FROM   dbo.PackDetail WITH (NOLOCK)    
                            WHERE  Pickslipno = @cPickSlipNo    
                            AND    Storerkey = @cStorerKey    
                            AND    SKU = @cSKU    
                            AND    LabelNo = @cLabelNo)    
                     BEGIN    
                         INSERT INTO dbo.PackDetail    
                           ( PickSlipNo ,CartonNo ,LabelNo ,LabelLine ,StorerKey    
                            ,SKU ,QTY ,Refno ,AddWho ,AddDate ,EditWho ,EditDate)    
                         VALUES    
                           ( @cPickSlipNo ,@nCartonNo ,@cLabelNo ,@cLabelLine    
                            ,@cStorerKey ,@cSKU ,@nCaseCnt ,@cDropID ,@cUserName    
                            ,GETDATE() ,@cUserName ,GETDATE() )        
                             
                         IF @@ERROR <> 0    
                         BEGIN    
                             SET @nErrNo = 68749        
                             SET @cErrMsg = rdt.rdtgetmessage(68749 ,@cLangCode ,'DSP') --'InsPackDFail'        
                             GOTO RollBackTran    
                         END    
                     END     
                        
                    -----SOS# 183480 Start      
                    INSERT INTO dbo.DropIDDetail    
                      ( DROPID ,CHILDID ,AddWho ,EditWho ,ArchiveCop )    
                    VALUES    
                      ( @cDropID ,@cLabelNo ,@cUserName ,@cUserName ,'d')        
                        
                    IF @@ERROR <> 0    
                    BEGIN    
                        SET @nErrNo = 68750        
                        SET @cErrMsg = rdt.rdtgetmessage(68750 ,@cLangCode ,'DSP') --'InsDropIDDet'        
                        GOTO RollBackTran    
                    END     
                    -----SOS# 183480 End      
                     SET @n_Step5Ctn = @n_Step5Ctn + 1
                     SEt @d_Step5    = GETDATE() 
                      
                    SET @nTotalLoop = @nTotalLoop - 1    
                END -- @nTotalLoop > 0        
                SET @n_Step2Ctn = @n_Step2Ctn + 1
    
                FETCH NEXT FROM CUR_INSPACKDETAIL INTO @cSKU, @cPackkey   
            END -- CUR_INSPACKDETAIL        
                
            CLOSE CUR_INSPACKDETAIL     
            DEALLOCATE CUR_INSPACKDETAIL    
        END
        SET @d_Step5 = @d_Step5 - @d_step2
        SET @d_step2 = GETDATE() - @d_step2     
    END -- @cPrepackByBOM = '0'  
 
      /**********************************/                
      /* PRINT LABEL BY CARTON NO       */       
      /**********************************/  

    SET @d_step3 = GETDATE()

     SET @cLabelNo = ''        

     DECLARE @cGS1TemplatePath NVARCHAR( 120)  
     SET @cGS1TemplatePath = ''  
     SELECT @cGS1TemplatePath = NSQLDescrip  
     FROM RDT.NSQLCONFIG WITH (NOLOCK)  
     WHERE ConfigKey = 'GS1TemplatePath'  
       
     DECLARE CUR_GSILABEL  CURSOR LOCAL READ_ONLY FAST_FORWARD     
     FOR    
         SELECT DISTINCT PD.LabelNo    
               ,PD.CartonNo    
         FROM   dbo.PackDetail PD WITH (NOLOCK)    
                INNER JOIN dbo.PACKHEADER PH WITH (NOLOCK)    
                     ON  PD.PickslipNo = PH.PickslipNO    
         WHERE  PH.Orderkey = @cOrderkey    
         AND    PD.RefNo = @cDropID     
     OPEN CUR_GSILABEL     
     FETCH NEXT FROM CUR_GSILABEL INTO @cLabelNo, @nCartonNo                                      
     WHILE @@FETCH_STATUS <> - 1    
     BEGIN    
         -- Print GS1 label 
         SET  @cErrMsg = @cGS1BatchNo           
         SET @b_success = 0    
         EXEC dbo.isp_PrintGS1Label  
            @c_PrinterID = @cPrinter,  
            @c_BtwPath   = @cGS1TemplatePath,  
            @b_Success   = @b_success OUTPUT,  
            @n_Err       = @nErrNo    OUTPUT,  
            @c_Errmsg    = @cErrMsg   OUTPUT,   
            @c_LabelNo   = @cLabelNo  
         IF @nErrNo <> 0 OR @b_success = 0  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  
            EXEC rdt.rdtSetFocusField @nMobile, 2  
            GOTO RollBackTran   
         END
  
         SET @n_step3Ctn = @n_step3Ctn + 1

         FETCH NEXT FROM CUR_GSILABEL INTO @cLabelNo, @nCartonNo    
     END -- WHILE @nMax_CartonNo > 0        
     CLOSE CUR_GSILABEL     
     DEALLOCATE CUR_GSILABEL    
    --END    

    SET @d_step3 = GETDATE() - @d_step3
           
    GOTO Quit     
        
    RollBackTran:     
    ROLLBACK TRAN GS1_InsertPackDetail     
        
    Quit:        
   IF @n_debug = 1  
   BEGIN
      SET @d_endtime = GETDATE()

      INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5)
      VALUES ( @c_TraceName ,@d_starttime, @d_endtime,
         LEFT(CONVERT( NVARCHAR( 12), @d_endtime - @d_starttime, 114),8),
         LEFT(CONVERT( NVARCHAR( 12), @d_step1, 114),8) + '-' + CAST( @n_step1Ctn AS NVARCHAR( 3)),
         LEFT(CONVERT( NVARCHAR( 12), @d_step2, 114),8) + '-' + CAST( @n_step2Ctn AS NVARCHAR( 3)),
         LEFT(CONVERT( NVARCHAR( 12), @d_step3, 114),8) + '-' + CAST( @n_step3Ctn AS NVARCHAR( 3)),
         LEFT(CONVERT( NVARCHAR( 12), @d_step4, 114),8) + '-' + CAST( @n_step4Ctn AS NVARCHAR( 3)),
         LEFT(CONVERT( NVARCHAR( 12), @d_step5, 114),8) + '-' + CAST( @n_step5Ctn AS NVARCHAR( 3)),
         @c_Col1,
         @c_Col2,
         @c_Col3,
         @c_Col4,
         @c_Col5)
   END

    WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started        
          COMMIT TRAN GS1_InsertPackDetail    
END

GO