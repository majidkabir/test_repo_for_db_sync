SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispUPPCS01                                         */  
/* Creation Date: 05-Oct-2012                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: SOS#249056:Unpickpack Orders                                */  
/*          Storerconfig UnpickpackORD_SP={SPName} to enable UNpickpack */
/*          Process                                                     */
/*                                                                      */  
/* Called By: RCM Unpickpack Orders At Unpickpack Orders screen         */    
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/   
CREATE PROCEDURE [dbo].[ispUPPCS01]  
      @c_PickSlipNo     NVARCHAR(10) 
   ,  @c_LabelNo        NVARCHAR(20)  
   ,  @c_DropID         NVARCHAR(20)  
   ,  @c_UPPLoc         NVARCHAR(10)
   ,  @c_UnpickMoveKey  NVARCHAR(10)  OUTPUT
   ,  @b_Success        INT          OUTPUT 
   ,  @n_Err            INT          OUTPUT 
   ,  @c_ErrMsg         NVARCHAR(250) OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_Continue        INT
         , @c_Facility        NVARCHAR(5)
         , @c_MBOLKey         NVARCHAR(10)
         , @c_ExternMBOLKey   NVARCHAR(10)
         , @c_Loadkey         NVARCHAR(10)
         , @c_Wavekey         NVARCHAR(10)
         , @c_Orderkey        NVARCHAR(10)
         , @c_ConsoOrderkey   NVARCHAR(30)
         , @c_PickDetailKey   NVARCHAR(10)
         , @c_POrderkey       NVARCHAR(10) 
         , @c_Storerkey       NVARCHAR(15)
         , @c_Sku             NVARCHAR(20)
         , @c_Lot             NVARCHAR(10)    
         , @c_FromLoc         NVARCHAR(10)
         , @c_ID              NVARCHAR(18)
         , @c_PCaseID          NVARCHAR(20)
         , @c_PDropID         NVARCHAR(20)
         , @c_Packkey         NVARCHAR(10)
         , @c_UOM             NVARCHAR(10)   
         , @n_Qty             INT

         , @b_OpenPack        INT
         , @c_PickStatus               NVARCHAR(10)
         , @c_PackStatus               NVARCHAR(10)
         , @c_LoadStatus               NVARCHAR(10)
         , @c_CheckPickB4Pack          NVARCHAR(10)
         , @c_DisableAutoPickAfterPack NVARCHAR(10)

         , @n_CartonNo        INT
         , @n_TotCartons      INT
         , @n_TotWeight       REAL
         , @n_TotCube         REAL
         , @n_Weight          REAL
         , @n_Cube            REAL
         , @c_CartonType      NVARCHAR(10)
         
         , @b_Unpick          INT

   SET @n_err           = 0
   SET @b_success       = 1
   SET @c_errmsg        = ''

   SET @n_Continue      = 1

   SET @c_Facility      = ''
   SET @c_MBOLKey       = ''
   SET @c_ExternMBOLKey = ''
   SET @c_Loadkey       = ''
   SET @c_Wavekey       = ''
   SET @c_Orderkey      = ''
   SET @c_ConsoOrderkey = ''
   SET @c_UnpickMoveKey = ''
   SET @c_PickDetailKey = ''
   SET @c_POrderkey     = ''
   SET @c_Storerkey     = ''
   SET @c_Sku           = '' 
   SET @c_Lot           = ''  
   SET @c_FromLoc       = ''
   SET @c_ID            = '' 
   SET @c_PCaseID        = ''
   SET @c_PDropID       = ''
   SET @c_Packkey       = ''
   SET @c_UOM           = ''
   SET @n_Qty           = 0

   SET @b_OpenPack      = 0
   SET @c_PickStatus    = '0'
   SET @c_PackStatus    = '0'
   SET @c_LoadStatus    = '3'
   SET @c_CheckPickB4Pack= ''
   SET @c_DisableAutoPickAfterPack = ''

   SET @n_CartonNo      = 0
   SET @n_TotCartons    = 0
   SET @n_TotWeight     = 0.00
   SET @n_TotCube       = 0.00
   SET @n_Weight        = 0.00
   SET @n_Cube          = 0.00
   SET @c_CartonType    = ''

   SET @b_Unpick        = 0

   CREATE TABLE #TMPORD
      (  Facility       NVARCHAR(5)  NOT NULL DEFAULT('')
      ,  Orderkey       NVARCHAR(10) NOT NULL DEFAULT('')
      ,  ConsoOrderkey  NVARCHAR(30) NOT NULL DEFAULT('')
      ,  Wavekey        NVARCHAR(10) NOT NULL DEFAULT('')
      ,  Loadkey        NVARCHAR(10) NOT NULL DEFAULT('') 
      ,  MBOLKey        NVARCHAR(10) NOT NULL DEFAULT('')
      ,  ExternMBOLKey  NVARCHAR(30) NOT NULL DEFAULT(''))
   
   SELECT @c_Orderkey = ISNULL(RTRIM(Orderkey),'')
         ,@c_ConsoOrderkey = ISNULL(RTRIM(ConsoOrderkey),'')
   FROM PACKHEADER WITH (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo

   IF @c_Orderkey = ''
   BEGIN
      INSERT INTO #TMPORD  (Facility, Orderkey, ConsoOrderkey, Wavekey, Loadkey, MBOLKey, ExternMBOLKey)
      SELECT DISTINCT
            Facility = ISNULL(RTRIM(OH.Facility),'')
         ,  OH.Orderkey
         ,  ConsoOrderkey = ISNULL(RTRIM(OD.ConsoOrderkey),'')
         ,  Wavekey = ISNULL(RTRIM(OH.UserDefine09),'')
         ,  Laodkey = ISNULL(RTRIM(OH.LoadKey),'')
         ,  MBOLKey = ISNULL(RTRIM(OH.MBOLKey),'')
         ,  ExternMBOLKey = ISNULL(RTRIM(MB.ExternMBOLKey),'')
      FROM ORDERS      OH WITH (NOLOCK) 
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
      LEFT JOIN MBOL   MB WITH (NOLOCK) ON (OH.MBOLKey = MB.MBOLKey)
      WHERE OD.ConsoOrderkey = @c_ConsoOrderkey
   END
   ELSE
   BEGIN
      INSERT INTO #TMPORD  (Facility, Orderkey, ConsoOrderkey, Wavekey, Loadkey, MBOLKey, ExternMBOLKey)
      SELECT DISTINCT
            Facility = ISNULL(RTRIM(OH.Facility),'')
         ,  OH.Orderkey
         ,  ''
         ,  Wavekey = ISNULL(RTRIM(OH.UserDefine09),'')
         ,  Laodkey = ISNULL(RTRIM(OH.LoadKey),'')
         ,  MBOLKey = ISNULL(RTRIM(OH.MBOLKey),'')
         ,  ExternMBOLKey = ISNULL(RTRIM(MB.ExternMBOLKey),'')
      FROM ORDERS    OH WITH (NOLOCK)
      LEFT JOIN MBOL MB WITH (NOLOCK) ON (OH.MBOLKey = MB.MBOLKey)
      WHERE OH.Orderkey = @c_Orderkey
   END
   
   SELECT TOP 1 @c_Facility =  Facility
   FROM #TMPORD

   SELECT @c_PackStatus = RTRIM(Status)   
   FROM PACKHEADER WITH (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo

   IF @c_PackStatus = '9'
   BEGIN
      EXECUTE nspGetRight @c_Facility        -- facility    
                        , @c_Storerkey       -- Storerkey    
                        , NULL               -- Sku    
                        , 'CheckPickB4Pack'  -- Configkey    
                        , @b_success            OUTPUT    
                        , @c_CheckPickB4Pack    OUTPUT    
                        , @n_err                OUTPUT    
                        , @c_errmsg             OUTPUT  

      IF @b_success = 0 
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63321
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Getting Configkey ''CheckPickB4Pack'' value Fail. (ispUPCSO01)' 
         GOTO QUIT_SP
      END

      EXECUTE nspGetRight @c_Facility                 -- facility    
                        , @c_Storerkey                -- Storerkey    
                        , NULL                        -- Sku    
                        , 'DisableAutoPickAfterPack'  -- Configkey    
                        , @b_success                  OUTPUT    
                        , @c_DisableAutoPickAfterPack OUTPUT    
                        , @n_err                      OUTPUT    
                        , @c_errmsg                   OUTPUT   

      IF @b_success = 0 
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63322
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Getting Configkey ''DisableAutoPickAfterPack'' value Fail. (ispUPCSO01)' 
         GOTO QUIT_SP
      END
   END  

   EXECUTE nspg_GetKey
          'UnpickMove'
         ,10 
         ,@c_UnpickMoveKey OUTPUT 
         ,@b_success      	OUTPUT 
         ,@n_err       	   OUTPUT 
         ,@c_errmsg    	   OUTPUT

   IF @b_success = 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 63323
      SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Getting New UnpickMoveKey. (ispUPPCS01)' 
      GOTO QUIT_SP
   END   
 
   --Remove Dropid Table
   SELECT DISTINCT DropID 
   INTO #DROPID
   FROM  DROPIDDETAIL WITH (NOLOCK)
   WHERE ChildID = @c_LabelNo

   DELETE DROPIDDETAIL WITH (ROWLOCK)
   WHERE ChildID = @c_LabelNo 

   IF @@ERROR <> 0 
   BEGIN
      SET @n_continue = 3
      SET @n_err = 63324
      SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': DELETE LabelNo from DROPIDEDETAIL fail. (ispUPPCS01)' 
      GOTO QUIT_SP
   END 
   
   DELETE DROPID WITH (ROWLOCK)
   FROM #DROPID DID
   JOIN DROPID DI ON (DID.DropID = DI.DropID) 
   WHERE NOT EXISTS (SELECT 1 FROM DROPIDDETAIL WITH (NOLOCK)
                     WHERE DROPIDDETAIL.DROPID = DID.DropID)

   IF @@ERROR <> 0 
   BEGIN
      SET @n_continue = 3
      SET @n_err = 63325
      SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': DELETE DROPID fail. (ispUPPCS01)' 
      GOTO QUIT_SP
   END 

   -- Unpack
   DELETE PACKINFO WITH (ROWLOCK)
   FROM PACKINFO
   JOIN PACKDETAIL WITH (NOLOCK) ON (PACKINFO.PickSlipNo = PACKDETAIL.PickSlipNo) AND (PACKINFO.CartonNo = PACKDETAIL.CartonNo)
   WHERE PACKDETAIL.PickSlipNo = @c_PickSlipNo
   AND   PACKDETAIL.LabelNo    = @c_LabelNo

   IF @@ERROR <> 0 
   BEGIN
      SET @n_continue = 3
      SET @n_err = 63326
      SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': DELETE PACKINFO fail. (ispUPPCS01)' 
      GOTO QUIT_SP
   END 

   DELETE PACKDETAIL WITH (ROWLOCK)
   WHERE PickSlipNo = @c_PickSlipNo
   AND   LabelNo    = @c_LabelNo

   IF @@ERROR <> 0 
   BEGIN
      SET @n_continue = 3
      SET @n_err = 63327
      SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': DELETE PACKDETAIL fail. (ispUPPCS01)' 
      GOTO QUIT_SP
   END 

   --UnPick
   DECLARE CUR_MOVEPCK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
   SELECT OH.MBOLKey
         ,OH.ExternMBOLKey
         ,OH.Loadkey
         ,PD.PickDetailKey
         ,Storerkey = ISNULL(RTRIM(PD.Storerkey),'')
         ,Sku       = ISNULL(RTRIM(PD.Sku),'')
         ,Lot       = ISNULL(RTRIM(PD.Lot),'')
         ,Loc       = ISNULL(RTRIM(PD.Loc),'')
         ,ID        = ISNULL(RTRIM(PD.ID),'')
         ,CaseID    = ISNULL(RTRIM(PD.CaseID),'')
         ,DropID    = ISNULL(RTRIM(PD.DropID),'')
         ,Packkey   = ISNULL(RTRIM(SKU.Packkey),'')
         ,PackUOM3  = ISNULL(RTRIM(PACK.PackUOM3),'')
         ,PD.Qty
         ,PD.Status
   FROM #TMPORD     OH
   JOIN ORDERDETAIL OD   WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)   AND (OH.ConsoOrderkey = ISNULL(RTRIM(OD.ConsoOrderkey),'')) 
   JOIN PICKDETAIL  PD   WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)   AND (OD.OrderLineNumber = PD.OrderLineNumber)
   JOIN SKU         SKU  WITH (NOLOCK) ON (PD.Storerkey= SKU.Storerkey) AND (PD.Sku = SKU.Sku)
   JOIN PACK        PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey) 

   OPEN CUR_MOVEPCK   
   FETCH NEXT FROM CUR_MOVEPCK INTO @c_MBOLKey
                                 ,  @c_ExternMBOLKey
                                 ,  @c_Loadkey
                                 ,  @c_PickDetailKey
                                 ,  @c_Storerkey
                                 ,  @c_Sku
                                 ,  @c_Lot
                                 ,  @c_FromLoc
                                 ,  @c_ID
                                 ,  @c_PCaseID
                                 ,  @c_PDropID
                                 ,  @c_Packkey
                                 ,  @c_UOM
                                 ,  @n_Qty
                                 ,  @c_PickStatus

   WHILE @@FETCH_STATUS <> -1               
   BEGIN
      IF @c_PackStatus = '9' AND @c_CheckPickB4Pack <> '1' AND @c_DisableAutoPickAfterPack <> '1'
      BEGIN
         SET @c_PickStatus = '0'
      END  
      
      IF (@c_PCaseID = '' AND @c_PDropID = @c_DropID)  OR
         (@c_PCaseID <>'' AND @c_PCaseID = @c_LabelNo)
      BEGIN

         INSERT INTO dbo.UnpickMoveLog (
                  UnpickMoveKey
               ,  MBOLKey 
               ,  ExternMBOLKey 
               ,  LoadKey 
               ,  ConsoOrderkey
               ,  UnpickpackLoc
               ,  MoveWho
               ,  MoveDate
               ,  PickDetailKey       
               ,  CaseID              
               ,  PickHeaderKey       
               ,  OrderKey            
               ,  OrderLineNumber     
               ,  Lot                 
               ,  Storerkey           
               ,  Sku                 
               ,  AltSku              
               ,  UOM                 
               ,  UOMQty              
               ,  Qty                 
               ,  QtyMoved            
               ,  Status              
               ,  DropID              
               ,  Loc                 
               ,  ID                  
               ,  PackKey             
               ,  UpdateSource        
               ,  CartonGroup         
               ,  CartonType          
               ,  ToLoc               
               ,  DoReplenish         
               ,  ReplenishZone       
               ,  DoCartonize         
               ,  PickMethod          
               ,  WaveKey             
               ,  EffectiveDate       
               ,  TrafficCop          
               ,  ArchiveCop          
               ,  OptimizeCop         
               ,  ShipFlag            
               ,  PickSlipNo          
               ,  TaskDetailKey       
               ,  TaskManagerReasonKey
               ,  AddDate  
               ,  AddWho   
               ,  EditDate 
               ,  EditWho  
                   )
         SELECT   @c_UnpickMovekey 
               ,  @c_MBOLKey 
               ,  @c_ExternMBOLKey 
               ,  @c_LoadKey 
               ,  @c_ConsoOrderkey
               ,  @c_UPPLoc
               ,  SUser_Name()
               ,  Getdate()
               ,  PickDetailKey         
               ,  CaseID                
               ,  PickHeaderKey         
               ,  OrderKey              
               ,  OrderLineNumber       
               ,  Lot                   
               ,  Storerkey             
               ,  Sku                   
               ,  AltSku                
               ,  UOM                   
               ,  UOMQty                
               ,  Qty                   
               ,  QtyMoved              
               ,  @c_PickStatus                
               ,  DropID                
               ,  Loc                   
               ,  ID                    
               ,  PackKey               
               ,  UpdateSource          
               ,  CartonGroup           
               ,  CartonType            
               ,  ToLoc                 
               ,  DoReplenish           
               ,  ReplenishZone         
               ,  DoCartonize           
               ,  PickMethod            
               ,  WaveKey               
               ,  EffectiveDate         
               ,  TrafficCop            
               ,  ArchiveCop            
               ,  OptimizeCop           
               ,  ShipFlag              
               ,  PickSlipNo            
               ,  TaskDetailKey         
               ,  TaskManagerReasonKey  
               ,  AddDate               
               ,  AddWho                
               ,  EditDate              
               ,  EditWho                
         FROM  PICKDETAIL WITH (NOLOCK)
         WHERE PickDetailKey = @c_PickDetailKey

         IF @@ERROR <> 0 
         BEGIN
            SET @n_continue = 3
            SET @n_err = 63328
            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert Into UNPICKMOVELOG fail. (ispUPPCS01)' 
            GOTO QUIT_SP
         END 

         DELETE PICKDETAIL WITH (ROWLOCK)
         WHERE PickDetailKey = @c_PickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @n_continue= 3
            SET @n_err     = 63329
            SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Unallocate PICKDETAIL Fail. (ispUPPCS01)' 
            GOTO QUIT_SP
         END

         --Move to Unpickpack Loc
         EXEC nspItrnAddMove                   
               NULL          
            ,	@c_StorerKey      
            ,	@c_Sku               
            ,	@c_Lot                 
            ,	@c_FromLoc               
            ,	@c_ID              
            ,	@c_UPPLoc          
            ,	@c_ID              
            ,	''        
            ,	''        
            ,	''       
            ,	''       
            ,	NULL   
            ,	NULL    
            ,	0         
            ,	0             
            ,	@n_qty           
            ,	0             
            ,	0.00           
            ,	0.00           
            ,	0.00             
            ,	0.00             
            ,	0.00             
            ,	@c_PickDetailKey     
            ,	'ispUPCSO01'      
            ,	@c_PackKey         
            ,	@c_UOM                 
            ,	1             
            ,	NULL     
            ,	''              
            ,	@b_Success        OUTPUT
            ,	@n_err            OUTPUT
            ,	@c_errmsg         OUTPUT

         IF @b_Success = 0
         BEGIN
            SET @n_continue= 3
            SET @n_err     = 63330
            SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Move To Unpickpack Location Fail. (ispUPPCS01)' 
            GOTO QUIT_SP
         END
      END
      ELSE
      BEGIN
         IF @c_PackStatus = '9' AND @b_OpenPack = 1 AND @c_CheckPickB4Pack <> '1' AND @c_DisableAutoPickAfterPack <> '1'
         BEGIN
            UPDATE PICKDETAIL WITH (ROWLOCK)
            SET Status = '0'
            WHERE PickDetailKey = @c_PickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63336
               SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Unpick Orders. (ispUPPCS01)' 
               GOTO QUIT_SP
            END
         END 
      END

      FETCH NEXT FROM CUR_MOVEPCK INTO @c_MBOLKey
                                    ,  @c_ExternMBOLKey
                                    ,  @c_Loadkey
                                    ,  @c_PickDetailKey
                                    ,  @c_Storerkey
                                    ,  @c_Sku
                                    ,  @c_Lot
                                    ,  @c_FromLoc
                                    ,  @c_ID
                                    ,  @c_PCaseID
                                    ,  @c_PDropID
                                    ,  @c_Packkey
                                    ,  @c_UOM
                                    ,  @n_Qty
                                    ,  @c_PickStatus
   END
   CLOSE CUR_MOVEPCK            
   DEALLOCATE CUR_MOVEPCK 
   
   IF NOT EXISTS (SELECT 1 
                  FROM PACKHEADER WITH (NOLOCK)
                  WHERE PickSlipNo = @c_PickSlipNo)
   BEGIN
      DELETE PACKINFO WITH (ROWLOCK)
      WHERE PickSlipNo = @c_PickSlipNo

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63338
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete PACKINFO Fail. (ispUPPCS01)' 
         GOTO QUIT_SP
      END

      DELETE REFKEYLOOKUP WITH (ROWLOCK)
      WHERE PickSlipNo = @c_PickSlipNo

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63339
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete REFKEYLOOKUP Fail. (ispUPPCS01)' 
         GOTO QUIT_SP
      END

      DELETE PICKINGINFO WITH (ROWLOCK)
      WHERE PickSlipNo = @c_PickSlipNo

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63340
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete PICKINGINFO Fail. (ispUPPCS01)' 
         GOTO QUIT_SP
      END

      DELETE PICKHEADER WITH (ROWLOCK)
      WHERE PickHeaderKey = @c_PickSlipNo

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63341
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete PICKHEADER Fail. (ispUPPCS01)' 
         GOTO QUIT_SP
      END
   END  
   ELSE
   BEGIN
      IF @c_PackStatus = '9' AND @b_OpenPack = 1  
      BEGIN
         SET @c_PackStatus = '0'
         IF @c_CheckPickB4Pack <> '1' AND @c_DisableAutoPickAfterPack <> '1'
         BEGIN
            UPDATE PICKINGINFO WITH (ROWLOCK)
            SET ScanOutDate= NULL
               ,TrafficCop = NULL
               ,EditWho = SUSER_NAME()
            WHERE PickSlipNo = @c_PickSlipNo

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63342
               SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Reverse ScanOut fail. (ispUPPCS01)' 
               GOTO QUIT_SP
            END
         END
      END

      UPDATE PACKHEADER WITH (ROWLOCK)
      SET Status = @c_PackStatus
         ,TTLCnts =  ISNULL((SELECT COUNT(DISTINCT CartonNo) FROM PACKDETAIL WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo),0)
         ,TotCtnWeight = ISNULL((SELECT SUM(Weight) FROM PACKINFO WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo),0)
         ,TotCtnCube   = ISNULL((SELECT SUM(Cube) FROM PACKINFO WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo),0)
         ,ArchiveCop = NULL
         ,EditWho = SUSER_NAME()
         ,EditDate= GETDATE()
      WHERE PickSlipNo = @c_PickSlipNo

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63343
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Update PACKHEADER Fail. (ispUPPCS01)' 
         GOTO QUIT_SP
      END 
   END

   -- Update TotalCartons, Cube, Weight
   DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
   SELECT DISTINCT 
          OH.Orderkey
         ,OH.Loadkey
         ,OH.MBOLkey
   FROM #TMPORD OH
   ORDER BY OH.Orderkey 

   OPEN CUR_ORD   
   FETCH NEXT FROM CUR_ORD INTO  @c_POrderKey
                              ,  @c_Loadkey
                              ,  @c_MBOLkey
                               
   WHILE @@FETCH_STATUS <> -1               
   BEGIN
      SET @n_TotCartons = 0   
      SET @n_TotWeight  = 0.00
      SET @n_TotCube    = 0.00

      DECLARE CUR_PCKINFO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT PD.Storerkey
            ,PACK.CartonNo
            ,SUM(PACK.Qty * SKU.StdGrossWgt)
      FROM PICKDETAIL PD   WITH (NOLOCK) 
      JOIN PACKDETAIL PACK WITH (NOLOCK) ON (PD.PickSlipNo = PACK.PickSlipNo)
                                         AND((PD.DropID = CASE WHEN ISNULL(RTRIM(PD.CaseID),'') = '' AND ISNULL(RTRIM(PD.DropID),'') <> ''
                                                              THEN PACK.DropID END)
                                         OR (PD.CaseID = CASE WHEN ISNULL(RTRIM(PD.CaseID),'') <> '' THEN PACK.LabelNo END))
      JOIN SKU        SKU  WITH (NOLOCK) ON (PACK.Storerkey = SKU.Storerkey) AND (PACK.Sku = SKU.Sku)
      WHERE PD.Orderkey = @c_PORderkey
      GROUP BY PD.Storerkey, PACK.CartonNo
      ORDER BY PACK.CartonNo

      OPEN CUR_PCKINFO   
      FETCH NEXT FROM CUR_PCKINFO INTO @c_Storerkey
                                    ,  @n_CartonNo
                                    ,  @n_Weight
                          
      WHILE @@FETCH_STATUS <> -1               
      BEGIN
         SELECT @c_CartonType = CartonType
               ,@n_Weight = CASE WHEN ISNULL(Weight,0) > 0 THEN ISNULL(Weight,0) ELSE @n_Weight END
         FROM PACKINFO WITH (NOLOCK)
         WHERE PickSlipNo = @c_PickSlipNo 
         AND   CartonNo   = @n_CartonNo

         SET @n_Cube = 0
         SELECT @n_Cube = ISNULL(C.Cube,0)  
         FROM dbo.Cartonization C WITH (NOLOCK)  
         JOIN Storer S WITH (NOLOCK) ON (C.CartonizationGroup = S.CartonGroup)  
         WHERE C.CartonType = @c_CartonType  
         AND S.StorerKey = @c_StorerKey  

         SET @n_TotWeight  = @n_TotWeight + @n_Weight  
         SET @n_TotCube    = @n_TotCube   + @n_Cube  
         SET @n_TotCartons = @n_TotCartons + 1  

         FETCH NEXT FROM CUR_PCKINFO INTO @c_Storerkey
                                       ,  @n_CartonNo
                                       ,  @n_Weight
      END 

      CLOSE CUR_PCKINFO            
      DEALLOCATE CUR_PCKINFO 

      UPDATE LOADPLANDETAIL
      SET Weight = @n_TotWeight
         ,Cube   = @n_TotCube
         ,Trafficcop = NULL
         ,EditWho = SUSER_NAME() 
         ,EditDate= GETDATE()
      WHERE LoadKey = @c_Loadkey
      AND   Orderkey= @c_POrderKey

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63344
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Update LOADPLANDETAIL Fail. (ispUPPCS01)' 
         GOTO QUIT_SP
      END 
                                                   
      UPDATE MBOLDETAIL WITH (ROWLOCK)
      SET TotalCartons = @n_TotCartons
         ,Cube    = @n_TotCube
         ,Weight  = @n_TotWeight
         ,Trafficcop = NULL
         ,EditWho = SUSER_NAME() 
         ,EditDate= GETDATE()
      WHERE MBOLKey = @c_MBOLKey
      AND   Orderkey= @c_POrderKey

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63345
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Update MBOLDETAIL Fail. (ispUPPCO01)' 
         GOTO QUIT_SP
      END 


      FETCH NEXT FROM CUR_ORD INTO  @c_POrderKey
                                 ,  @c_Loadkey
                                 ,  @c_MBOLkey
   END
   CLOSE CUR_ORD            
   DEALLOCATE CUR_ORD  

   CREATE TABLE #TMPPACK   
      (PickSlipNo NVARCHAR(10),  
       LabelNo    NVARCHAR(20),  
       CartonNo   INT,  
       [WEIGHT]   REAL,  
       [CUBE]     REAL)  
  
   DECLARE CUR_MBOL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT MBOLKey 
   FROM #TMPORD  
  
   OPEN CUR_MBOL  
   FETCH NEXT FROM CUR_MBOL INTO @c_MBOLKey  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      INSERT INTO #TMPPACK (PickSlipNo, LabelNo, CartonNo, [WEIGHT], [CUBE])  
      SELECT DISTINCT PD.PickSlipNo, PACK.LabelNo, PACK.CartonNo,0, 0  
      FROM PICKDETAIL PD   WITH (NOLOCK)  
      JOIN PACKDETAIL PACK WITH (NOLOCK) ON (PD.PickSlipNo = PACK.PickSlipNo)
                                         AND((PD.DropID = CASE WHEN ISNULL(RTRIM(PD.CaseID),'') = '' AND ISNULL(RTRIM(PD.DropID),'') <> ''
                                                              THEN PACK.DropID END)
                                         OR (PD.CaseID = CASE WHEN ISNULL(RTRIM(PD.CaseID),'') <> '' THEN PACK.LabelNo END)) 
      JOIN  MBOLDETAIL MD WITH (NOLOCK) ON (PD.OrderKey = MD.OrderKey)  
      WHERE MD.MbolKey = @c_MBOLKey  
   
      UPDATE TP  
         SET [WEIGHT]  = pi1.[Weight],  
             TP.[CUBE] = CASE WHEN pi1.[CUBE] < 1.00 THEN 1.00 ELSE pi1.[CUBE] END  
      FROM #TMPPACK TP  
      JOIN PackInfo pi1 WITH (NOLOCK) ON pi1.PickSlipNo = TP.PickSlipNo AND pi1.CartonNo = TP.CartonNo  
  
      IF EXISTS(SELECT 1 FROM #TMPPACK WHERE [WEIGHT]=0)  
      BEGIN  
         UPDATE TP  
            SET TP.[WEIGHT]  = TWeight.[WEIGHT],  
                TP.[CUBE] = CASE WHEN TP.[CUBE] < 1.00 THEN 1.00 ELSE TP.[CUBE] END  
         FROM #TMPPACK TP  
         JOIN (SELECT PD.PickSlipNo, PD.CartonNo, SUM(S.STDGROSSWGT * PD.Qty) AS [WEIGHT]  
               FROM PACKDETAIL PD WITH (NOLOCK)  
               JOIN SKU S WITH (NOLOCK) ON S.StorerKey = PD.StorerKey AND S.SKU = PD.SKU  
               JOIN #TMPPACK TP2 ON TP2.PickSlipNo = PD.PickSlipNo AND TP2.CartonNo = PD.CartonNo  
               GROUP BY PD.PickSlipNo, PD.CartonNo) AS TWeight ON TP.PickSlipNo = TWeight.PickSlipNo  
                        AND TP.CartonNo = TWeight.CartonNo  
         WHERE TP.[WEIGHT] = 0  
  
      END  
  
      UPDATE MBOL WITH (ROWLOCK)
         SET [Weight]     = PK.WEIGHT,  
             MBOL.[Cube]  = PK.Cube,  
             MBOL.CaseCnt = PK.CaseCnt,  
             EditWho = SUSER_NAME(),  
             EditDate= GETDATE(), 
             TrafficCop=NULL  
      FROM MBOL  
      JOIN (SELECT @c_MBOLKey AS MBOLKEY, SUM(WEIGHT) AS Weight, SUM(CUBE) AS Cube, COUNT(1) AS CaseCnt  
            FROM #TMPPACK) AS PK ON MBOL.MbolKey = PK.MbolKey  
      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63346
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Update MBOL Fail. (ispUPPCO01)' 
         GOTO QUIT_SP
      END 
      DELETE FROM #TMPPACK
  
      FETCH NEXT FROM CUR_MBOL INTO @c_MBOLKey  
   END  
   CLOSE CUR_MBOL  
   DEALLOCATE CUR_MBOL  


   QUIT_SP:
   IF CURSOR_STATUS('LOCAL' , 'CUR_MOVEPCK') in (0 , 1)
   BEGIN
      CLOSE CUR_MOVEPCK            
      DEALLOCATE CUR_MOVEPCK 
   END 

   IF CURSOR_STATUS('LOCAL' , 'CUR_PCKINFO') in (0 , 1)
   BEGIN
      CLOSE CUR_PCKINFO            
      DEALLOCATE CUR_PCKINFO  
   END 

   IF CURSOR_STATUS('LOCAL' , 'CUR_ORD') in (0 , 1)
   BEGIN
      CLOSE CUR_ORD            
      DEALLOCATE CUR_ORD  
   END 

   IF CURSOR_STATUS('LOCAL' , 'CUR_MBOL') in (0 , 1)
   BEGIN
      CLOSE CUR_MBOL            
      DEALLOCATE CUR_MBOL  
   END 

   IF @n_Continue = 3
   BEGIN
       SET @b_success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispUPPCS01'  
   END   
END  

GO