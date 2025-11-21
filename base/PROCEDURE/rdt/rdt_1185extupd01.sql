SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1185ExtUpd01                                    */  
/*                                                                      */  
/* Purpose: insert into OTMIDTRACK by cartonNo                          */  
/*                                                                      */  
/* Called from: 3                                                       */  
/*    1. From PowerBuilder                                              */  
/*    2. From scheduler                                                 */  
/*    3. From others stored procedures or triggers                      */  
/*    4. From interface program. DX, DTS                                */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2020-06-12 1.1  hcb        InsertToOtmidtrack                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1185ExtUpd01] (  
         @nMobile       INT,  
         @nFunc         INT,   
         @cLangCode     NVARCHAR( 3),  
         @nStep         INT,   
         @cOrderNo      NVARCHAR( 20),   
         @cKeyType      NVARCHAR( 5),   
         @cCarrierCode  NVARCHAR(15),   
         @cCartonNo     NVARCHAR(20),   
         @cUDF01        NVARCHAR(10),   
         @cUDF02        NVARCHAR(10),   
         @cUDF03        NVARCHAR(10),   
         @cUDF04        NVARCHAR(10),   
         @cUDF05        NVARCHAR(10),   
         @cStorerKey    NVARCHAR( 15),  
         @cFacility     NVARCHAR( 5),      
         @cUserName     NVARCHAR( 20),   
         @nErrNo        INT           OUTPUT,   
         @cErrMsg       NVARCHAR( 20) OUTPUT,   
         @nCount        INT           OUTPUT   
)  
AS  
  
  
SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
SET CONCAT_NULL_YIELDS_NULL OFF     
     
DECLARE   
   @f_Pif_Cube             FLOAT  
   ,@f_Pif_Weight           FLOAT  
   ,@n_Pif_Qty              INT   
   ,@c_Pif_CartonGID        NVARCHAR( 20)  
   ,@c_PD_LabelNo           NVARCHAR( 20)  
   ,@c_OH_ConsigneeKey      NVARCHAR( 20)  
   ,@c_PH_StorerKey             NVARCHAR( 20)  
   ,@cTableName             NVARCHAR(10)  
   ,@b_success              INT  
   ,@nTranCount             INT  
  
SET @f_Pif_Cube            = 0  
SET @f_Pif_Weight          = 0  
SET @n_Pif_Qty             = 0  
SET @c_Pif_CartonGID       = ''  
SET @c_PD_LabelNo          = ''  
SET @c_OH_ConsigneeKey     = ''  
SET @c_PH_StorerKey            = ''  
SET @cTableName            = ''  
SET @nCount                = 0  
  
SET @nTranCount = @@TRANCOUNT    
BEGIN TRAN    
SAVE TRAN rdt_1185ExtUpd01    
  
DECLARE @curDTMP CURSOR  
  
IF ISNULL(@cUDF01,'') <> ''  
BEGIN   
   SET @cTableName = @cUDF01  
  
   IF @cUDF05 = 'Y'  
   BEGIN   
      IF @cKeyType = 'M'  
      BEGIN   
         SET @curDTMP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT SUM(PIF.[Cube]),  
                  SUM(PIF.[Weight]),  
                  SUM(PIF.Qty),  
                  ISNULL(RTRIM(PIF.CartonGID),''),  
                  ISNULL(RTRIM(PD.LabelNo),''),  
                  ISNULL(RTRIM(OH.ConsigneeKey),''),  
                  ISNULL(RTRIM(PH.StorerKey),'')  
         FROM MBOLDetail MD(NOLOCK)  
         JOIN ORDERS OH(NOLOCK)  
         ON (OH.OrderKey = MD.OrderKey)  
         JOIN PackHeader PH(NOLOCK)           
         ON OH.loadkey = PH.loadkey  
         JOIN PackInfo PIF(NOLOCK)  
         ON PIF.PickSlipNo = PH.PickSlipNo  
         JOIN PackDetail PD(NOLOCK)  
         ON(PH.PickSlipNo = PD.PickSlipNo AND pd.CartonNo = PIF.CartonNo AND PH.StorerKey = PD.StorerKey)  
         WHERE MD.MBOLKey = @cOrderNo   
         GROUP BY ISNULL(RTRIM(PIF.CartonGID),''),  
                  ISNULL(RTRIM(PD.LabelNo),''),  
                  ISNULL(RTRIM(OH.ConsigneeKey),''),  
                  ISNULL(RTRIM(PH.StorerKey),'')  
  
      END   
      ELSE IF @cKeyType = 'L'  
      BEGIN   
         SET @curDTMP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT SUM(PIF.[Cube]),  
                  SUM(PIF.[Weight]),  
                  SUM(PIF.Qty),  
                  ISNULL(RTRIM(PIF.CartonGID),''),  
                  ISNULL(RTRIM(PD.LabelNo),''),  
                  ISNULL(RTRIM(OH.ConsigneeKey),''),  
                  ISNULL(RTRIM(PH.StorerKey),'')  
         FROM LoadPlanDetail LP(NOLOCK)  
         JOIN ORDERS OH(NOLOCK)  
         ON (OH.OrderKey = LP.OrderKey)  
         JOIN PackHeader PH(NOLOCK)           
         ON OH.loadkey = PH.loadkey  
         JOIN PackInfo PIF(NOLOCK)  
         ON PIF.PickSlipNo = PH.PickSlipNo  
         JOIN PackDetail PD(NOLOCK)  
         ON(PH.PickSlipNo = PD.PickSlipNo AND pd.CartonNo = PIF.CartonNo AND PH.StorerKey = PD.StorerKey)  
         WHERE LP.LoadKey = @cOrderNo   
         GROUP BY ISNULL(RTRIM(PIF.CartonGID),''),  
                  ISNULL(RTRIM(PD.LabelNo),''),  
                  ISNULL(RTRIM(OH.ConsigneeKey),''),  
                  ISNULL(RTRIM(PH.StorerKey),'')  
      END   
      ELSE IF @cKeyType = 'O'  
      BEGIN   
         SET @curDTMP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT SUM(PIF.[Cube]),  
                  SUM(PIF.[Weight]),  
                  SUM(PIF.Qty),  
                  ISNULL(RTRIM(PIF.CartonGID),''),  
                  ISNULL(RTRIM(PD.LabelNo),''),  
                  ISNULL(RTRIM(OH.ConsigneeKey),''),  
                  ISNULL(RTRIM(PH.StorerKey),'')  
         FROM ORDERS OH(NOLOCK)  
         JOIN PackHeader PH(NOLOCK)           
         ON OH.loadkey = PH.loadkey  
         JOIN PackInfo PIF(NOLOCK)  
         ON PIF.PickSlipNo = PH.PickSlipNo  
         JOIN PackDetail PD(NOLOCK)  
         ON(PH.PickSlipNo = PD.PickSlipNo AND pd.CartonNo = PIF.CartonNo AND PH.StorerKey = PD.StorerKey)  
         WHERE OH.OrderKey = @cOrderNo   
         GROUP BY ISNULL(RTRIM(PIF.CartonGID),''),  
                  ISNULL(RTRIM(PD.LabelNo),''),  
                  ISNULL(RTRIM(OH.ConsigneeKey),''),  
                  ISNULL(RTRIM(PH.StorerKey),'')  
      END   
  
      OPEN @curDTMP      
      FETCH NEXT FROM @curDTMP INTO @f_Pif_Cube  
                                    , @f_Pif_Weight  
                                    , @n_Pif_Qty  
                                    , @c_Pif_CartonGID  
                                    , @c_PD_LabelNo  
                                    , @c_OH_ConsigneeKey  
                                    , @c_PH_StorerKey  
      WHILE @@FETCH_STATUS = 0     
      BEGIN     
         INSERT INTO dbo.OTMIDTrack(TrackingNo, CaseID, Principal, MUStatus, GrossWeight, GrossVolume, MUType,CartonQty, ConsigneeKey,CartonGID, AddDate, EditDate, EditWho)  
         VALUES(@cOrderNo,                   -- TrackingNo - nvarchar(30)  
               @c_PD_LabelNo ,               -- CaseID - nvarchar(20)  
               @c_PH_StorerKey ,                 -- Principal - nvarchar(45)  
               N'5' ,                        -- MUStatus - nvarchar(5)  
               @f_Pif_Weight ,               -- GrossWeight - float  
               @f_Pif_Cube ,                 -- GrossVolume - float  
               N'OTMCTN' ,                   -- MUType - nvarchar(10)  
               '1',                   -- CartonQty - float  
               --@n_Pif_Qty,                   -- CartonQty - float  
         @c_OH_ConsigneeKey ,          -- ConsigneeKey - nvarchar(15)  
               @c_Pif_CartonGID,             --CartonGID - nvarchar(50)  
               GETDATE(),                    -- AddDate - datetime  
               GETDATE(),                    -- EditDate - datetime  
               SUSER_SNAME()                 -- EditWho - nvarchar(128)  
               )  
  
         IF @@ERROR <> 0    
         BEGIN     
            SET @nErrNo = 153651  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')   
            GOTO QUIT  
         END  
         SET @nCount = @nCount + 1  
  
         FETCH NEXT FROM @curDTMP INTO @f_Pif_Cube  
                                       , @f_Pif_Weight  
                                       , @n_Pif_Qty  
                                       , @c_Pif_CartonGID  
                                       , @c_PD_LabelNo  
                                       , @c_OH_ConsigneeKey  
                                       , @c_PH_StorerKey  
      END -- WHILE @@FETCH_STATUS = 0       
   END    --IF @cUDF05 = 'Y'  
   ELSE  
   BEGIN   
      IF @nStep = 2  
      BEGIN   
              
         INSERT INTO OTMIDTRACK ( TrackingNo, DropLoc, MUStatus, AddWho, AddDate, EditWho, EditDate )       
         VALUES ( @cOrderNo, @cCarrierCode,  '1' ,@cUserName, GetDATE(), @cUserName , GetDate())       
               
         IF @@ERROR <> 0       
         BEGIN      
            SET @nErrNo = 153652        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed        
            EXEC rdt.rdtSetFocusField @nMobile, 1        
            GOTO QUIT       
         END     
               
      END   
  
      IF @nStep = 3 OR @nStep = 4  
      BEGIN   
  
         INSERT INTO OTMIDTRACK ( TrackingNo, DropLoc, CaseID, MUStatus, AddWho, AddDate, EditWho, EditDate )       
         VALUES ( @cOrderNo, @cCarrierCode, @cCartonNo, '1', @cUserName, GetDATE(), @cUserName , GetDate()  )       
            
         IF @@ERROR <> 0       
         BEGIN      
            SET @nErrNo = 153653        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed        
            EXEC rdt.rdtSetFocusField @nMobile, 2        
            GOTO QUIT        
         END      
      END   
  
      SET @nCount = @nCount + 1  
  
   END   
  
   EXEC ispGenOTMLog @cTableName, @cOrderNo, '', @cStorerKey, ''       
      , @b_success OUTPUT       
      , @nErrNo OUTPUT       
      , @cErrMsg OUTPUT           
  
END  
  
     
IF ISNULL(@cUDF02,'') <> ''  
BEGIN   
   SET @cTableName = @cUDF02  
  
   IF @cUDF05 = 'Y'  
   BEGIN   
      IF @cKeyType = 'M'  
      BEGIN   
         SET @curDTMP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT SUM(PIF.[Cube]),  
                  SUM(PIF.[Weight]),  
                  SUM(PIF.Qty),  
                  ISNULL(RTRIM(PIF.CartonGID),''),  
                  ISNULL(RTRIM(PD.LabelNo),''),  
                  ISNULL(RTRIM(OH.ConsigneeKey),''),  
                  ISNULL(RTRIM(PH.StorerKey),'')  
         FROM MBOLDetail MD(NOLOCK)  
         JOIN ORDERS OH(NOLOCK)  
         ON (OH.OrderKey = MD.OrderKey)  
         JOIN PackHeader PH(NOLOCK)           
         ON OH.loadkey = PH.loadkey  
         JOIN PackInfo PIF(NOLOCK)  
         ON PIF.PickSlipNo = PH.PickSlipNo  
         JOIN PackDetail PD(NOLOCK)  
         ON(PH.PickSlipNo = PD.PickSlipNo AND pd.CartonNo = PIF.CartonNo AND PH.StorerKey = PD.StorerKey)  
         WHERE MD.MBOLKey = @cOrderNo   
         GROUP BY ISNULL(RTRIM(PIF.CartonGID),''),  
                  ISNULL(RTRIM(PD.LabelNo),''),  
                  ISNULL(RTRIM(OH.ConsigneeKey),''),  
                  ISNULL(RTRIM(PH.StorerKey),'')  
  
      END   
      ELSE IF @cKeyType = 'L'  
      BEGIN   
         SET @curDTMP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT SUM(PIF.[Cube]),  
                  SUM(PIF.[Weight]),  
                  SUM(PIF.Qty),  
                  ISNULL(RTRIM(PIF.CartonGID),''),  
                  ISNULL(RTRIM(PD.LabelNo),''),  
                  ISNULL(RTRIM(OH.ConsigneeKey),''),  
                  ISNULL(RTRIM(PH.StorerKey),'')  
         FROM LoadPlanDetail LP(NOLOCK)  
         JOIN ORDERS OH(NOLOCK)  
         ON (OH.OrderKey = LP.OrderKey)  
         JOIN PackHeader PH(NOLOCK)           
         ON OH.loadkey = PH.loadkey  
         JOIN PackInfo PIF(NOLOCK)  
         ON PIF.PickSlipNo = PH.PickSlipNo  
         JOIN PackDetail PD(NOLOCK)  
         ON(PH.PickSlipNo = PD.PickSlipNo AND pd.CartonNo = PIF.CartonNo AND PH.StorerKey = PD.StorerKey)  
         WHERE LP.LoadKey = @cOrderNo   
         GROUP BY ISNULL(RTRIM(PIF.CartonGID),''),  
                  ISNULL(RTRIM(PD.LabelNo),''),  
                  ISNULL(RTRIM(OH.ConsigneeKey),''),  
                  ISNULL(RTRIM(PH.StorerKey),'')  
      END   
      ELSE IF @cKeyType = 'O'  
      BEGIN   
         SET @curDTMP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT SUM(PIF.[Cube]),  
                  SUM(PIF.[Weight]),  
                  SUM(PIF.Qty),  
                  ISNULL(RTRIM(PIF.CartonGID),''),  
                  ISNULL(RTRIM(PD.LabelNo),''),  
                  ISNULL(RTRIM(OH.ConsigneeKey),''),  
                  ISNULL(RTRIM(PH.StorerKey),'')  
         FROM ORDERS OH(NOLOCK)  
         JOIN PackHeader PH(NOLOCK)           
         ON OH.loadkey = PH.loadkey  
         JOIN PackInfo PIF(NOLOCK)  
         ON PIF.PickSlipNo = PH.PickSlipNo  
         JOIN PackDetail PD(NOLOCK)  
         ON(PH.PickSlipNo = PD.PickSlipNo AND pd.CartonNo = PIF.CartonNo AND PH.StorerKey = PD.StorerKey)  
         WHERE OH.OrderKey = @cOrderNo   
         GROUP BY ISNULL(RTRIM(PIF.CartonGID),''),  
                  ISNULL(RTRIM(PD.LabelNo),''),  
                  ISNULL(RTRIM(OH.ConsigneeKey),''),  
                  ISNULL(RTRIM(PH.StorerKey),'')  
      END   
  
      OPEN @curDTMP      
      FETCH NEXT FROM @curDTMP INTO @f_Pif_Cube  
                                    , @f_Pif_Weight  
                                    , @n_Pif_Qty  
                                    , @c_Pif_CartonGID  
                                    , @c_PD_LabelNo  
                                    , @c_OH_ConsigneeKey  
                                    , @c_PH_StorerKey  
      WHILE @@FETCH_STATUS = 0     
      BEGIN     
         INSERT INTO dbo.OTMIDTrack(TrackingNo, CaseID, Principal, MUStatus, GrossWeight, GrossVolume, MUType,CartonQty, ConsigneeKey,CartonGID, AddDate, EditDate, EditWho)  
         VALUES(@cOrderNo,                   -- TrackingNo - nvarchar(30)  
               @c_PD_LabelNo ,               -- CaseID - nvarchar(20)  
               @c_PH_StorerKey ,                 -- Principal - nvarchar(45)  
               N'5' ,                        -- MUStatus - nvarchar(5)  
               @f_Pif_Weight ,               -- GrossWeight - float  
               @f_Pif_Cube ,                 -- GrossVolume - float  
               N'OTMCTN' ,                   -- MUType - nvarchar(10)  
               '1',                   -- CartonQty - float  
               --@n_Pif_Qty,                   -- CartonQty - float  
               @c_OH_ConsigneeKey ,          -- ConsigneeKey - nvarchar(15)  
               @c_Pif_CartonGID,             --CartonGID - nvarchar(50)  
               GETDATE(),                    -- AddDate - datetime  
               GETDATE(),                    -- EditDate - datetime  
               SUSER_SNAME()                 -- EditWho - nvarchar(128)  
               )  
  
         IF @@ERROR <> 0    
         BEGIN     
            SET @nErrNo = 153654  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')   
            GOTO QUIT  
         END  
         SET @nCount = @nCount + 1  
  
         FETCH NEXT FROM @curDTMP INTO @f_Pif_Cube  
                                       , @f_Pif_Weight  
                                       , @n_Pif_Qty  
                                       , @c_Pif_CartonGID  
                                       , @c_PD_LabelNo  
                                       , @c_OH_ConsigneeKey  
                                       , @c_PH_StorerKey  
      END -- WHILE @@FETCH_STATUS = 0       
   END    --IF @cUDF05 = 'Y'  
   ELSE  
   BEGIN   
      IF @nStep = 2  
      BEGIN   
              
         INSERT INTO OTMIDTRACK ( TrackingNo, DropLoc, MUStatus, AddWho, AddDate, EditWho, EditDate )       
         VALUES ( @cOrderNo, @cCarrierCode,  '1' ,@cUserName, GetDATE(), @cUserName , GetDate())       
               
         IF @@ERROR <> 0       
         BEGIN      
            SET @nErrNo = 153655        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed        
            EXEC rdt.rdtSetFocusField @nMobile, 1        
            GOTO QUIT       
         END     
               
         SET @nCount = @nCount + 1  
      END   
  
      IF @nStep = 3 OR @nStep = 4  
      BEGIN   
  
         INSERT INTO OTMIDTRACK ( TrackingNo, DropLoc, CaseID, MUStatus, AddWho, AddDate, EditWho, EditDate )       
         VALUES ( @cOrderNo, @cCarrierCode, @cCartonNo, '1', @cUserName, GetDATE(), @cUserName , GetDate()  )       
            
         IF @@ERROR <> 0       
         BEGIN      
            SET @nErrNo = 153656        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed        
            EXEC rdt.rdtSetFocusField @nMobile, 2        
            GOTO QUIT        
         END      
         SET @nCount = @nCount + 1  
      END   
  
   END   
  
   EXEC ispGenOTMLog @cTableName, @cOrderNo, '', @cStorerKey, ''       
      , @b_success OUTPUT       
      , @nErrNo OUTPUT       
      , @cErrMsg OUTPUT           
  
END  
  
IF ISNULL(@cUDF03,'') <> ''  
BEGIN   
   SET @cTableName = @cUDF03  
  
   IF @cUDF05 = 'Y'  
   BEGIN   
      IF @cKeyType = 'M'  
      BEGIN   
         SET @curDTMP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT SUM(PIF.[Cube]),  
                  SUM(PIF.[Weight]),  
                  SUM(PIF.Qty),  
                  ISNULL(RTRIM(PIF.CartonGID),''),  
                  ISNULL(RTRIM(PD.LabelNo),''),  
                  ISNULL(RTRIM(OH.ConsigneeKey),''),  
                  ISNULL(RTRIM(PH.StorerKey),'')  
         FROM MBOLDetail MD(NOLOCK)  
         JOIN ORDERS OH(NOLOCK)  
         ON (OH.OrderKey = MD.OrderKey)  
         JOIN PackHeader PH(NOLOCK)           
         ON OH.loadkey = PH.loadkey  
         JOIN PackInfo PIF(NOLOCK)  
         ON PIF.PickSlipNo = PH.PickSlipNo  
         JOIN PackDetail PD(NOLOCK)  
         ON(PH.PickSlipNo = PD.PickSlipNo AND pd.CartonNo = PIF.CartonNo AND PH.StorerKey = PD.StorerKey)  
         WHERE MD.MBOLKey = @cOrderNo   
         GROUP BY ISNULL(RTRIM(PIF.CartonGID),''),  
                  ISNULL(RTRIM(PD.LabelNo),''),  
                  ISNULL(RTRIM(OH.ConsigneeKey),''),  
                  ISNULL(RTRIM(PH.StorerKey),'')  
  
      END   
      ELSE IF @cKeyType = 'L'  
      BEGIN   
         SET @curDTMP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT SUM(PIF.[Cube]),  
                  SUM(PIF.[Weight]),  
                  SUM(PIF.Qty),  
                  ISNULL(RTRIM(PIF.CartonGID),''),  
                  ISNULL(RTRIM(PD.LabelNo),''),  
                  ISNULL(RTRIM(OH.ConsigneeKey),''),  
                  ISNULL(RTRIM(PH.StorerKey),'')  
         FROM LoadPlanDetail LP(NOLOCK)  
         JOIN ORDERS OH(NOLOCK)  
         ON (OH.OrderKey = LP.OrderKey)  
         JOIN PackHeader PH(NOLOCK)           
         ON OH.loadkey = PH.loadkey  
         JOIN PackInfo PIF(NOLOCK)  
         ON PIF.PickSlipNo = PH.PickSlipNo  
         JOIN PackDetail PD(NOLOCK)  
         ON(PH.PickSlipNo = PD.PickSlipNo AND pd.CartonNo = PIF.CartonNo AND PH.StorerKey = PD.StorerKey)  
         WHERE LP.LoadKey = @cOrderNo   
         GROUP BY ISNULL(RTRIM(PIF.CartonGID),''),  
                  ISNULL(RTRIM(PD.LabelNo),''),  
                  ISNULL(RTRIM(OH.ConsigneeKey),''),  
                  ISNULL(RTRIM(PH.StorerKey),'')  
      END   
      ELSE IF @cKeyType = 'O'  
      BEGIN   
         SET @curDTMP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT SUM(PIF.[Cube]),  
                  SUM(PIF.[Weight]),  
                  SUM(PIF.Qty),  
                  ISNULL(RTRIM(PIF.CartonGID),''),  
                  ISNULL(RTRIM(PD.LabelNo),''),  
                  ISNULL(RTRIM(OH.ConsigneeKey),''),  
                  ISNULL(RTRIM(PH.StorerKey),'')  
         FROM ORDERS OH(NOLOCK)  
         JOIN PackHeader PH(NOLOCK)           
         ON OH.loadkey = PH.loadkey  
         JOIN PackInfo PIF(NOLOCK)  
         ON PIF.PickSlipNo = PH.PickSlipNo  
         JOIN PackDetail PD(NOLOCK)  
         ON(PH.PickSlipNo = PD.PickSlipNo AND pd.CartonNo = PIF.CartonNo AND PH.StorerKey = PD.StorerKey)  
         WHERE OH.OrderKey = @cOrderNo   
         GROUP BY ISNULL(RTRIM(PIF.CartonGID),''),  
                  ISNULL(RTRIM(PD.LabelNo),''),  
                  ISNULL(RTRIM(OH.ConsigneeKey),''),  
                  ISNULL(RTRIM(PH.StorerKey),'')  
      END   
  
      OPEN @curDTMP      
      FETCH NEXT FROM @curDTMP INTO @f_Pif_Cube  
                                    , @f_Pif_Weight  
                                    , @n_Pif_Qty  
                                    , @c_Pif_CartonGID  
                                    , @c_PD_LabelNo  
                                    , @c_OH_ConsigneeKey  
                                    , @c_PH_StorerKey  
      WHILE @@FETCH_STATUS = 0     
      BEGIN     
         INSERT INTO dbo.OTMIDTrack(TrackingNo, CaseID, Principal, MUStatus, GrossWeight, GrossVolume, MUType,CartonQty, ConsigneeKey,CartonGID, AddDate, EditDate, EditWho)  
         VALUES(@cOrderNo,                   -- TrackingNo - nvarchar(30)  
               @c_PD_LabelNo ,               -- CaseID - nvarchar(20)  
               @c_PH_StorerKey ,                 -- Principal - nvarchar(45)  
               N'5' ,                        -- MUStatus - nvarchar(5)  
               @f_Pif_Weight ,               -- GrossWeight - float  
               @f_Pif_Cube ,                 -- GrossVolume - float  
               N'OTMCTN' ,                   -- MUType - nvarchar(10)  
               '1',                   -- CartonQty - float  
               --@n_Pif_Qty,                   -- CartonQty - float  
               @c_OH_ConsigneeKey ,          -- ConsigneeKey - nvarchar(15)  
               @c_Pif_CartonGID,             --CartonGID - nvarchar(50)  
               GETDATE(),                    -- AddDate - datetime  
               GETDATE(),                    -- EditDate - datetime  
               SUSER_SNAME()                 -- EditWho - nvarchar(128)  
               )  
  
         IF @@ERROR <> 0    
         BEGIN     
            SET @nErrNo = 153657  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')   
            GOTO QUIT  
         END  
         SET @nCount = @nCount + 1  
  
         FETCH NEXT FROM @curDTMP INTO @f_Pif_Cube  
                                       , @f_Pif_Weight  
                                       , @n_Pif_Qty  
                                       , @c_Pif_CartonGID  
                                       , @c_PD_LabelNo  
                                       , @c_OH_ConsigneeKey  
                                       , @c_PH_StorerKey  
      END -- WHILE @@FETCH_STATUS = 0       
   END    --IF @cUDF05 = 'Y'  
   ELSE  
   BEGIN   
      IF @nStep = 2  
      BEGIN   
              
         INSERT INTO OTMIDTRACK ( TrackingNo, DropLoc, MUStatus, AddWho, AddDate, EditWho, EditDate )       
         VALUES ( @cOrderNo, @cCarrierCode,  '1' ,@cUserName, GetDATE(), @cUserName , GetDate())       
               
         IF @@ERROR <> 0       
         BEGIN      
            SET @nErrNo = 153658        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed        
            EXEC rdt.rdtSetFocusField @nMobile, 1        
            GOTO QUIT       
         END     
               
         SET @nCount = @nCount + 1  
      END   
  
      IF @nStep = 3 OR @nStep = 4  
      BEGIN   
  
         INSERT INTO OTMIDTRACK ( TrackingNo, DropLoc, CaseID, MUStatus, AddWho, AddDate, EditWho, EditDate )       
         VALUES ( @cOrderNo, @cCarrierCode, @cCartonNo, '1', @cUserName, GetDATE(), @cUserName , GetDate()  )       
            
         IF @@ERROR <> 0       
         BEGIN      
            SET @nErrNo = 153659       
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed        
            EXEC rdt.rdtSetFocusField @nMobile, 2        
            GOTO QUIT        
         END      
         SET @nCount = @nCount + 1  
      END   
  
   END   
  
   EXEC ispGenOTMLog @cTableName, @cOrderNo, '', @cStorerKey, ''       
      , @b_success OUTPUT       
      , @nErrNo OUTPUT       
      , @cErrMsg OUTPUT           
  
END  
   
IF ISNULL(@cUDF04,'') <> ''  
BEGIN   
   SET @cTableName = @cUDF04  
  
   IF @cUDF05 = 'Y'  
   BEGIN   
      IF @cKeyType = 'M'  
      BEGIN   
         SET @curDTMP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT SUM(PIF.[Cube]),  
                  SUM(PIF.[Weight]),  
                  SUM(PIF.Qty),  
                  ISNULL(RTRIM(PIF.CartonGID),''),  
                  ISNULL(RTRIM(PD.LabelNo),''),  
                  ISNULL(RTRIM(OH.ConsigneeKey),''),  
                  ISNULL(RTRIM(PH.StorerKey),'')  
         FROM MBOLDetail MD(NOLOCK)  
         JOIN ORDERS OH(NOLOCK)  
         ON (OH.OrderKey = MD.OrderKey)  
         JOIN PackHeader PH(NOLOCK)           
         ON OH.loadkey = PH.loadkey  
         JOIN PackInfo PIF(NOLOCK)  
         ON PIF.PickSlipNo = PH.PickSlipNo  
         JOIN PackDetail PD(NOLOCK)  
         ON(PH.PickSlipNo = PD.PickSlipNo AND pd.CartonNo = PIF.CartonNo AND PH.StorerKey = PD.StorerKey)  
         WHERE MD.MBOLKey = @cOrderNo   
         GROUP BY ISNULL(RTRIM(PIF.CartonGID),''),  
                  ISNULL(RTRIM(PD.LabelNo),''),  
                  ISNULL(RTRIM(OH.ConsigneeKey),''),  
                  ISNULL(RTRIM(PH.StorerKey),'')  
  
      END   
      ELSE IF @cKeyType = 'L'  
      BEGIN   
         SET @curDTMP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT SUM(PIF.[Cube]),  
                  SUM(PIF.[Weight]),  
                  SUM(PIF.Qty),  
                  ISNULL(RTRIM(PIF.CartonGID),''),  
                  ISNULL(RTRIM(PD.LabelNo),''),  
                  ISNULL(RTRIM(OH.ConsigneeKey),''),  
                  ISNULL(RTRIM(PH.StorerKey),'')  
         FROM LoadPlanDetail LP(NOLOCK)  
         JOIN ORDERS OH(NOLOCK)  
         ON (OH.OrderKey = LP.OrderKey)  
         JOIN PackHeader PH(NOLOCK)           
         ON OH.loadkey = PH.loadkey  
         JOIN PackInfo PIF(NOLOCK)  
         ON PIF.PickSlipNo = PH.PickSlipNo  
         JOIN PackDetail PD(NOLOCK)  
         ON(PH.PickSlipNo = PD.PickSlipNo AND pd.CartonNo = PIF.CartonNo AND PH.StorerKey = PD.StorerKey)  
         WHERE LP.LoadKey = @cOrderNo   
GROUP BY ISNULL(RTRIM(PIF.CartonGID),''),  
                  ISNULL(RTRIM(PD.LabelNo),''),  
                  ISNULL(RTRIM(OH.ConsigneeKey),''),  
                  ISNULL(RTRIM(PH.StorerKey),'')  
      END   
      ELSE IF @cKeyType = 'O'  
      BEGIN   
         SET @curDTMP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT SUM(PIF.[Cube]),  
                  SUM(PIF.[Weight]),  
                  SUM(PIF.Qty),  
                  ISNULL(RTRIM(PIF.CartonGID),''),  
                  ISNULL(RTRIM(PD.LabelNo),''),  
                  ISNULL(RTRIM(OH.ConsigneeKey),''),  
                  ISNULL(RTRIM(PH.StorerKey),'')  
         FROM ORDERS OH(NOLOCK)  
         JOIN PackHeader PH(NOLOCK)           
         ON OH.loadkey = PH.loadkey  
         JOIN PackInfo PIF(NOLOCK)  
         ON PIF.PickSlipNo = PH.PickSlipNo  
         JOIN PackDetail PD(NOLOCK)  
         ON(PH.PickSlipNo = PD.PickSlipNo AND pd.CartonNo = PIF.CartonNo AND PH.StorerKey = PD.StorerKey)  
         WHERE OH.OrderKey = @cOrderNo   
         GROUP BY ISNULL(RTRIM(PIF.CartonGID),''),  
                  ISNULL(RTRIM(PD.LabelNo),''),  
                  ISNULL(RTRIM(OH.ConsigneeKey),''),  
                  ISNULL(RTRIM(PH.StorerKey),'')  
      END   
  
      OPEN @curDTMP      
      FETCH NEXT FROM @curDTMP INTO @f_Pif_Cube  
                                    , @f_Pif_Weight  
                                    , @n_Pif_Qty  
                                    , @c_Pif_CartonGID  
                                    , @c_PD_LabelNo  
                                    , @c_OH_ConsigneeKey  
                                    , @c_PH_StorerKey  
      WHILE @@FETCH_STATUS = 0     
      BEGIN     
         INSERT INTO dbo.OTMIDTrack(TrackingNo, CaseID, Principal, MUStatus, GrossWeight, GrossVolume, MUType,CartonQty, ConsigneeKey,CartonGID, AddDate, EditDate, EditWho)  
         VALUES(@cOrderNo,                   -- TrackingNo - nvarchar(30)  
               @c_PD_LabelNo ,               -- CaseID - nvarchar(20)  
               @c_PH_StorerKey ,                 -- Principal - nvarchar(45)  
               N'5' ,                        -- MUStatus - nvarchar(5)  
               @f_Pif_Weight ,               -- GrossWeight - float  
               @f_Pif_Cube ,                 -- GrossVolume - float  
               N'OTMCTN' ,                   -- MUType - nvarchar(10)  
               '1',                   -- CartonQty - float  
               --@n_Pif_Qty,                   -- CartonQty - float  
               @c_OH_ConsigneeKey ,          -- ConsigneeKey - nvarchar(15)  
               @c_Pif_CartonGID,             --CartonGID - nvarchar(50)  
               GETDATE(),                    -- AddDate - datetime  
               GETDATE(),                    -- EditDate - datetime  
               SUSER_SNAME()                 -- EditWho - nvarchar(128)  
               )  
  
         IF @@ERROR <> 0    
         BEGIN     
            SET @nErrNo = 153660  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')   
            GOTO QUIT  
         END  
         SET @nCount = @nCount + 1  
  
         FETCH NEXT FROM @curDTMP INTO  @f_Pif_Cube  
                                       , @f_Pif_Weight  
                                       , @n_Pif_Qty  
                                       , @c_Pif_CartonGID  
                                       , @c_PD_LabelNo  
                                       , @c_OH_ConsigneeKey  
                                       , @c_PH_StorerKey  
      END -- WHILE @@FETCH_STATUS = 0       
   END    --IF @cUDF05 = 'Y'  
   ELSE  
   BEGIN   
      IF @nStep = 2  
      BEGIN   
              
         INSERT INTO OTMIDTRACK ( TrackingNo, DropLoc, MUStatus, AddWho, AddDate, EditWho, EditDate )       
         VALUES ( @cOrderNo, @cCarrierCode,  '1' ,@cUserName, GetDATE(), @cUserName , GetDate())       
               
         IF @@ERROR <> 0       
         BEGIN      
            SET @nErrNo = 153661        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed        
            EXEC rdt.rdtSetFocusField @nMobile, 1        
            GOTO QUIT       
         END     
               
         SET @nCount = @nCount + 1  
      END   
  
      IF @nStep = 3 OR @nStep = 4  
      BEGIN   
  
         INSERT INTO OTMIDTRACK ( TrackingNo, DropLoc, CaseID, MUStatus, AddWho, AddDate, EditWho, EditDate )       
         VALUES ( @cOrderNo, @cCarrierCode, @cCartonNo, '1', @cUserName, GetDATE(), @cUserName , GetDate()  )       
            
         IF @@ERROR <> 0       
         BEGIN      
            SET @nErrNo = 153662        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed        
            EXEC rdt.rdtSetFocusField @nMobile, 2        
            GOTO QUIT        
         END      
         SET @nCount = @nCount + 1  
      END   
  
   END   
  
   EXEC ispGenOTMLog @cTableName, @cOrderNo, '', @cStorerKey, ''       
      , @b_success OUTPUT       
      , @nErrNo OUTPUT       
      , @cErrMsg OUTPUT           
  
END  
  
IF ISNULL(@cUDF05,'') <> ''  
BEGIN   
   SET @cTableName = @cUDF05  
  
   IF @cUDF05 <> 'Y'  
   BEGIN   
      IF @nStep = 2  
      BEGIN   
              
         INSERT INTO OTMIDTRACK ( TrackingNo, DropLoc, MUStatus, AddWho, AddDate, EditWho, EditDate )       
         VALUES ( @cOrderNo, @cCarrierCode,  '1' ,@cUserName, GetDATE(), @cUserName , GetDate())       
               
         IF @@ERROR <> 0       
         BEGIN      
            SET @nErrNo = 153663        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed        
            EXEC rdt.rdtSetFocusField @nMobile, 1        
            GOTO QUIT       
         END     
               
         SET @nCount = @nCount + 1  
      END   
  
      IF @nStep = 3 OR @nStep = 4  
      BEGIN   
  
         INSERT INTO OTMIDTRACK ( TrackingNo, DropLoc, CaseID, MUStatus, AddWho, AddDate, EditWho, EditDate )       
         VALUES ( @cOrderNo, @cCarrierCode, @cCartonNo, '1', @cUserName, GetDATE(), @cUserName , GetDate()  )       
            
         IF @@ERROR <> 0       
         BEGIN      
            SET @nErrNo = 153664        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed        
            EXEC rdt.rdtSetFocusField @nMobile, 2        
            GOTO QUIT        
         END      
         SET @nCount = @nCount + 1  
      END   
  
   END   
  
   EXEC ispGenOTMLog @cTableName, @cOrderNo, '', @cStorerKey, ''       
      , @b_success OUTPUT       
      , @nErrNo OUTPUT       
      , @cErrMsg OUTPUT           
  
END  
  
WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started        
   COMMIT TRAN rdt_1185ExtUpd01    
  
QUIT:  
IF @nErrNo <> 0    
BEGIN     
   ROLLBACK TRAN rdt_1185ExtUpd01   
END  

GO