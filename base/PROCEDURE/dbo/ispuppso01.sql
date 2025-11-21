SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispUPPSO01                                         */  
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
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver  Purposes                                   */ 
/* 2015-05-07  CSCHONG  1.0  add new parameter for nspItrnAddMove(CS01) */
/* 25-JAN-2017  JayLim   1.1  SQL2012 compatibility modification (Jay01)*/
/* 2020-06-04  Wan      1.1  WMS-13120 - [PH] NIKE - WMS UnPacking Module*/ 
/************************************************************************/   
CREATE PROCEDURE [dbo].[ispUPPSO01]  
      @c_OrderKey       NVARCHAR(10) 
   ,  @c_Loadkey        NVARCHAR(10)  
   ,  @c_ConsoOrderkey  NVARCHAR(30)  
   ,  @c_UPPLoc         NVARCHAR(10)
   ,  @c_UnpickMoveKey  NVARCHAR(10)  OUTPUT
   ,  @b_Success        INT          OUTPUT 
   ,  @n_Err            INT          OUTPUT 
   ,  @c_ErrMsg         NVARCHAR(250) OUTPUT
   ,  @c_MBOLKey        NVARCHAR(10) = ''    --(Wan01) Add Default New Parameter
   ,  @c_WaveKey        NVARCHAR(10) = ''    --(Wan01) Add Default New Parameter
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_Continue        INT
         , @c_Facility        NVARCHAR(5)
         --, @c_MBOLKey         NVARCHAR(10) --(Wan01)
         , @c_ExternMBOLKey   NVARCHAR(10) 
         --, @c_Wavekey         NVARCHAR(10) --(Wan01)
         
         , @c_PickSlipNo      NVARCHAR(10)
         , @c_PickDetailKey   NVARCHAR(10)
         , @c_POrderkey       NVARCHAR(10) 
         , @c_Storerkey       NVARCHAR(15)
         , @c_Sku             NVARCHAR(20)
         , @c_Lot             NVARCHAR(10)    
         , @c_FromLoc         NVARCHAR(10)
         , @c_ID              NVARCHAR(18)
         , @c_Caseid          NVARCHAR(20)
         , @c_DropID          NVARCHAR(20)
         , @c_Packkey         NVARCHAR(10)
         , @c_UOM             NVARCHAR(10)   
         , @n_Qty             INT

         , @b_OpenPack        INT
         , @n_CartonNo        INT
         , @n_PackQty         INT
         , @c_LabelNo         NVARCHAR(20)
         , @c_LoadStatus      NVARCHAR(10)
         , @c_PickStatus      NVARCHAR(10)
         , @c_PackStatus      NVARCHAR(10)

         , @b_discrete        INT
         , @c_CheckPickB4Pack          NVARCHAR(10)
         , @c_DisableAutoPickAfterPack NVARCHAR(10)

         , @n_TotCartons      INT
         , @n_TotWeight       FLOAT
         , @n_TotCube         FLOAT
         , @n_Weight          FLOAT
         , @n_Cube            FLOAT
         , @c_CartonType     NVARCHAR(10)

   SET @n_err           = 0
   SET @b_success       = 1
   SET @c_errmsg        = ''

   SET @n_Continue      = 1

   SET @c_Facility      = ''
   SET @c_MBOLKey       = ''
   SET @c_ExternMBOLKey = ''
   SET @c_Wavekey       = ''
   SET @c_UnpickMoveKey = ''
   SET @c_PickSlipNo    = ''
   SET @c_PickDetailKey = ''
   SET @c_POrderkey     = ''
   SET @c_Storerkey     = ''
   SET @c_Sku           = '' 
   SET @c_Lot           = ''  
   SET @c_FromLoc       = ''
   SET @c_ID            = ''
   SET @c_Caseid        = ''
   SET @c_DropID        = '' 
   SET @c_Packkey       = ''
   SET @c_UOM           = ''
   SET @n_Qty           = 0
   
   SET @b_OpenPack      = 0
   SET @n_CartonNo      = 0
   SET @n_PackQty       = 0
   SET @c_LabelNo       = ''
   SET @c_LoadStatus    = '3'
   SET @c_PickStatus    = '0'
   SET @c_PackStatus    = '0'  

   SET @b_discrete = 0
   SET @c_CheckPickB4Pack= ''
   SET @c_DisableAutoPickAfterPack = ''

   SET @n_TotCartons    = 0
   SET @n_TotWeight     = 0.00
   SET @n_TotCube       = 0.00
   SET @n_Weight        = 0.00
   SET @n_Cube          = 0.00
   SET @c_CartonType    = ''

   --(Wan01) - START -- SP only unpickpack by orderkey, If unpickpack by mbolkey or wavekey, quit
   IF @c_Orderkey = ''                                
   BEGIN
      GOTO QUIT_SP
   END
   --(Wan01) - END
   
   CREATE TABLE #TMPORD
      (  Facility       NVARCHAR(5)  NOT NULL DEFAULT('')
      ,  Orderkey       NVARCHAR(10) NOT NULL DEFAULT('')
      ,  ConsoOrderkey  NVARCHAR(30) NOT NULL DEFAULT('')
      ,  Wavekey        NVARCHAR(10) NOT NULL DEFAULT('')
      ,  Loadkey        NVARCHAR(10) NOT NULL DEFAULT('') 
      ,  MBOLKey        NVARCHAR(10) NOT NULL DEFAULT('')
      ,  ExternMBOLKey  NVARCHAR(30) NOT NULL DEFAULT(''))

   CREATE TABLE #DROPID 
      (  DropID         NVARCHAR(20) NOT NULL DEFAULT('') )
   
--   SELECT @c_PickSlipNo = PickSlipNo
--   FROM PACKHEADER WITH (NOLOCK)
--   WHERE Orderkey = @c_Orderkey
--
--   IF @c_PickSlipNo = '' 
--   BEGIN
--      SELECT @c_PickSlipNo = PickSlipNo
--      FROM PACKHEADER WITH (NOLOCK)
--      WHERE ConsoOrderkey = @c_ConsoOrderkey
--   END
--   ELSE
--   BEGIN
--      SET @b_discrete = 1
--   END
--
--   IF @c_PickSlipNo = '' 
--   BEGIN
--      SELECT @c_PickSlipNo = PickSlipNo
--      FROM PACKHEADER WITH (NOLOCK)
--      WHERE Loadkey = @c_Loadkey
--   END


   SELECT @c_PickSlipNo = PickHeaderKey
   FROM PICKHEADER WITH (NOLOCK)
   WHERE Orderkey = @c_Orderkey


   IF @c_PickSlipNo = '' 
   BEGIN
      SELECT @c_PickSlipNo = PickHeaderKey
      FROM PICKHEADER WITH (NOLOCK)
      WHERE ConsoOrderkey = @c_ConsoOrderkey
   END
   ELSE
   BEGIN
      SET @b_discrete = 1
   END

   IF @c_PickSlipNo = '' 
   BEGIN
      SELECT @c_PickSlipNo = PickHeaderKey
      FROM PICKHEADER WITH (NOLOCK)
      WHERE ExternOrderkey = @c_Loadkey
   END

--   IF @c_PickSlipNo = ''
--   BEGIN
--      GOTO QUIT_SP
--   END  

   IF @c_ConsoOrderkey <> ''
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
      FROM ORDERS  OH WITH (NOLOCK) 
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
      LEFT JOIN MBOL    MB WITH (NOLOCK) ON (OH.MBOLKey = MB.MBOLKey)
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
      FROM ORDERS OH WITH (NOLOCK)
      LEFT JOIN MBOL    MB WITH (NOLOCK) ON (OH.MBOLKey = MB.MBOLKey)
      WHERE OH.Orderkey = @c_Orderkey
   END
 
   EXECUTE nspg_GetKey
          'UnpickMove'
         ,10 
         ,@c_UnpickMoveKey OUTPUT 
         ,@b_success      	OUTPUT 
         ,@n_err       	   OUTPUT 
         ,@c_errmsg    	   OUTPUT

   IF NOT @b_success = 1
   BEGIN
      SET @n_continue = 3
      SET @n_err = 63321
      SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Getting New loadkey. (ispUPPSO01)' 
      GOTO QUIT_SP
   END 
  
   IF @b_discrete = 1
   BEGIN
      --Remove DropID
      INSERT INTO #DROPID (DropID)
      SELECT DISTINCT DD.DropID 
      FROM PACKDETAIL   PD WITH (NOLOCK)
      JOIN DROPIDDETAIL DD WITH (NOLOCK) ON (PD.LabelNo = DD.ChildID)
      WHERE PD.PickSlipNo = @c_PickSlipNo

      DELETE DROPIDDETAIL WITH (ROWLOCK)
      FROM PACKDETAIL   PD WITH (NOLOCK)
      JOIN DROPIDDETAIL DD ON (PD.LabelNo = DD.ChildID) 
      WHERE PD.PickSlipNo = @c_PickSlipNo

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63322
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete LabelNo from DROPIDDETAIL Fail. (ispUPPSO01)' 
         GOTO QUIT_SP
      END
      
      DELETE DROPID WITH (ROWLOCK)
      FROM #DROPID DID
      JOIN DROPID DI ON (DID.DropID = DI.DropID) 
      WHERE NOT EXISTS (SELECT 1 FROM DROPIDDETAIL WITH (NOLOCK)
                        WHERE DROPIDDETAIL.DROPID = DID.DropID)

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63323
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete DropID from DROPID Fail. (ispUPPSO01)' 
         GOTO QUIT_SP
      END

      DELETE PACKDETAIL WITH (ROWLOCK)
      WHERE PickSlipNo = @c_PickSlipNo

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63324
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete PACKDETAIL Fail. (ispUPPSO01)' 
         GOTO QUIT_SP
      END
   END
   ELSE
   BEGIN
      SELECT @c_PackStatus = Status FROM PACKHEADER WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo  
      IF @c_PackStatus = '9'
      BEGIN
         SELECT TOP 1 @c_Facility = RTRIM(Facility)
         FROM #TMPORD

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
            SET @n_err     = 63325
            SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Getting Configkey ''CheckPickB4Pack'' value Fail. (ispUPPSO01)' 
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
            SET @n_err     = 63326
            SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Getting Configkey ''DisableAutoPickAfterPack'' value Fail. (ispUPPSO01)' 
            GOTO QUIT_SP
         END
      END
   END

   --UnPick
   DECLARE CUR_MOVEPCK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
   SELECT OH.Orderkey
         ,OH.MBOLKey
         ,OH.ExternMBOLKey
         ,PD.PickDetailKey
         ,ISNULL(RTRIM(PD.Storerkey),'')
         ,ISNULL(RTRIM(PD.Sku),'')
         ,ISNULL(RTRIM(PD.Lot),'')
         ,ISNULL(RTRIM(PD.Loc),'')
         ,ISNULL(RTRIM(PD.ID),'')
         ,ISNULL(RTRIM(PD.CaseID),'')
         ,ISNULL(RTRIM(PD.DropID),'')
         ,ISNULL(RTRIM(SKU.Packkey),'')
         ,ISNULL(RTRIM(PACK.PackUOM3),'')
         ,PD.Qty
         ,PD.Status
   FROM #TMPORD      OH
   JOIN ORDERDETAIL  OD   WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey) AND (OH.ConsoOrderkey = ISNULL(RTRIM(OD.ConsoOrderkey),''))
   JOIN PICKDETAIL   PD   WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey) AND (OD.OrderlineNumber = PD.OrderlineNumber)
   JOIN SKU          SKU  WITH (NOLOCK) ON (PD.Storerkey= SKU.Storerkey) AND (PD.Sku = SKU.Sku)
   JOIN PACK         PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
   ORDER BY PD.PickDetailKey

   OPEN CUR_MOVEPCK   
   FETCH NEXT FROM CUR_MOVEPCK INTO @c_POrderkey
                                 ,  @c_MBOLKey
                                 ,  @c_ExternMBOLKey
                                 ,  @c_PickDetailKey
                                 ,  @c_Storerkey
                                 ,  @c_Sku
                                 ,  @c_Lot
                                 ,  @c_FromLoc
                                 ,  @c_ID
                                 ,  @c_CaseID
                                 ,  @c_DropID
                                 ,  @c_Packkey
                                 ,  @c_UOM
                                 ,  @n_Qty
                                 ,  @c_PickStatus

   WHILE @@FETCH_STATUS <> -1               
   BEGIN
      IF @c_POrderkey = @c_Orderkey 
      BEGIN
         IF @b_discrete = 0
         BEGIN
            SET @n_CartonNo= 0
            SET @n_PackQty = 0

            IF @c_PackStatus = '9' AND @c_CheckPickB4Pack <> '1' AND @c_DisableAutoPickAfterPack <> '1'
            BEGIN
               SET @c_PickStatus = '0'
            END 

            IF @c_CaseID = '' AND @c_DropID <> ''
            BEGIN
               SELECT @n_CartonNo = CartonNo
                     ,@c_LabelNo  = LabelNo
                     ,@n_PackQty  = Qty
               FROM PACKDETAIL WITH (NOLOCK)
               WHERE PickSlipNo = @c_PickSlipNo
               AND   Storerkey  = @c_Storerkey
               AND   Sku        = @c_Sku
               AND   DropID     = @c_DropID
            END 
            ELSE 
            BEGIN
               SELECT @n_CartonNo = CartonNo
                     ,@c_LabelNo  = LabelNo
                     ,@n_PackQty  = Qty
               FROM PACKDETAIL WITH (NOLOCK)
               WHERE PickSlipNo = @c_PickSlipNo
               AND   LabelNo    = @c_CaseID
               AND   Storerkey  = @c_Storerkey
               AND   Sku        = @c_Sku
            END
            
            IF @n_CartonNo > 0 
            BEGIN
               IF @n_PackQty > @n_Qty
               BEGIN
                  UPDATE PACKDETAIL WITH (ROWLOCK)
                  SET Qty = Qty - @n_qty
                     ,EditWho  = SUSER_NAME()
                     ,EditDate = GETDATE()
                  WHERE PickSlipNo = @c_PickSlipNo
                  AND   CartonNo   = @n_CartonNo
                  AND   LabelNo    = @c_LabelNo
                  AND   Storerkey  = @c_Storerkey
                  AND   Sku        = @c_Sku

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_continue= 3
                     SET @n_err     = 63327
                     SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Reducing Carton qty fail. (ispUPPSO01)' 
                     GOTO QUIT_SP
                  END
               END
               ELSE
               BEGIN
                  DELETE PACKDETAIL WITH (ROWLOCK)
                  WHERE PickSlipNo = @c_PickSlipNo
                  AND   CartonNo   = @n_CartonNo
                  AND   LabelNo    = @c_LabelNo
                  AND   Storerkey  = @c_Storerkey
                  AND   Sku        = @c_Sku

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_continue= 3
                     SET @n_err     = 63328
                     SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete sku from carton fail. (ispUPPSO01)' 
                     GOTO QUIT_SP
                  END

                  INSERT INTO #DROPID (DropID)
                  SELECT DISTINCT DD.DropID 
                  FROM DROPIDDETAIL DD WITH (NOLOCK) 
                  WHERE ChildID = @c_LabelNo
                  AND   NOT EXISTS (SELECT 1 FROM #DROPID WHERE DropID = DD.DropID)

                  IF NOT EXISTS (SELECT 1 FROM PACKDETAIL WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo AND CartonNo = @n_CartonNo)
                  BEGIN
                     DELETE DROPIDDETAIL WITH (ROWLOCK)
                     WHERE ChildID = @c_LabelNo

                     IF @@ERROR <> 0
                     BEGIN
                        SET @n_continue= 3
                        SET @n_err     = 63329
                        SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete LabelNo from DROPIDDETAIL fail. (ispUPPSO01)' 
                        GOTO QUIT_SP
                     END

                     DELETE DROPID WITH (ROWLOCK)
                     FROM #DROPID DID
                     JOIN DROPID DI ON (DID.DropID = DI.DropID) 
                     WHERE NOT EXISTS (SELECT 1 FROM DROPIDDETAIL WITH (NOLOCK)
                                       WHERE DROPIDDETAIL.DROPID = DID.DropID)
                     IF @@ERROR <> 0
                     BEGIN
                        SET @n_continue= 3
                        SET @n_err     = 63330
                        SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete DropID from DROPID fail. (ispUPPSO01)' 
                        GOTO QUIT_SP
                     END

                     DELETE PACKINFO WITH (ROWLOCK) WHERE PickSlipNo = @c_PickSlipNo AND CartonNo = @n_CartonNo

                     IF @@ERROR <> 0
                     BEGIN
                        SET @n_continue= 3
                        SET @n_err     = 63331
                        SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete carton from PACKINFO fail. (ispUPPSO01)' 
                        GOTO QUIT_SP
                     END
                  END
               END
            END     
         
            DELETE REFKEYLOOKUP WITH (ROWLOCK)
            WHERE Orderkey = @c_Orderkey
            AND   PickdetailKey = @c_Pickdetailkey

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63332
               SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete pickdetailkey from REFKEYLOOKUP fail. (ispUPPSO01)' 
               GOTO QUIT_SP
            END
         END


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
               ,  SUSER_NAME()
               ,  GETDATE()
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
            SET @n_continue= 3
            SET @n_err     = 63333
            SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Insert Into UnpickMoveLog Fail. (ispUPPSO01)' 
            GOTO QUIT_SP
         END

         DELETE PICKDETAIL WITH (ROWLOCK)
         WHERE PickDetailKey = @c_PickDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue= 3
            SET @n_err     = 63334
            SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Unallocate PICKDETAIL Fail. (ispUPPSO01)' 
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
            ,	''      --(CS01)      
            ,	''      --(CS01)  
            ,	''      --(CS01)  
            ,	''      --(CS01)      
            ,	''      --(CS01)  
            ,	''      --(CS01) 
            ,	''      --(CS01)   
            ,	NULL    --(CS01) 
            ,	NULL    --(CS01)
            ,	NULL    --(CS01)
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
            ,	'ispUPPSO01'      
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
            SET @n_err     = 63335
            SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Move To Unpickpack Location Fail. (ispUPPSO01)' 
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
               SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Unpick Orders. (ispUPPSO01)' 
               GOTO QUIT_SP
            END
         END 
      END 

      FETCH NEXT FROM CUR_MOVEPCK INTO @c_POrderkey
                                       ,  @c_MBOLKey
                                       ,  @c_ExternMBOLKey 
                                       ,  @c_PickDetailKey
                                       ,  @c_Storerkey
                                       ,  @c_Sku
                                       ,  @c_Lot
                                       ,  @c_FromLoc
                                       ,  @c_ID
                                       ,  @c_CaseID
                                       ,  @c_DropID
                                       ,  @c_Packkey
                                       ,  @c_UOM
                                       ,  @n_Qty
                                       ,  @c_PickStatus
   END
   CLOSE CUR_MOVEPCK            
   DEALLOCATE CUR_MOVEPCK 

   IF NOT EXISTS (SELECT 1 FROM PACKDETAIL WITH (NOLOCK) WHERE PickSlipNo = @c_PickslipNo)
   BEGIN
      DELETE PACKINFO WITH (ROWLOCK)
      WHERE PickSlipNo = @c_PickSlipNo

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63337
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete PACKINFO Fail. (ispUPPSO01)' 
         GOTO QUIT_SP
      END

      DELETE PACKHEADER WITH (ROWLOCK)
      WHERE PickSlipNo = @c_PickSlipNo
      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63338
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete PACKHEADER Fail. (ispUPPSO01)' 
         GOTO QUIT_SP
      END

      DELETE REFKEYLOOKUP WITH (ROWLOCK)
      WHERE PickSlipNo = @c_PickSlipNo
      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63339
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete REFKEYLOOKUP Fail. (ispUPPSO01)' 
         GOTO QUIT_SP
      END

      DELETE PICKINGINFO WITH (ROWLOCK)
      WHERE PickSlipNo = @c_PickSlipNo

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63340
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete PICKINGINFO Fail. (ispUPPSO01)' 
         GOTO QUIT_SP
      END

      DELETE PICKHEADER WITH (ROWLOCK)
      WHERE PickHeaderkey = @c_PickSlipNo
      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63341
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete PICKHEADER Fail. (ispUPPSO01)' 
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
               SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Reverse ScanOut fail. (ispUPPSO01)' 
               GOTO QUIT_SP
            END
         END
      END

      UPDATE PACKHEADER WITH (ROWLOCK)
      SET Status = @c_PackStatus
         ,TTLCnts =  ISNULL((SELECT COUNT(DISTINCT CartonNo) FROM PACKDETAIL WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo),0)
         ,TotCtnWeight = ISNULL((SELECT SUM(Weight) FROM PACKINFO WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo),0)
         ,TotCtnCube   = ISNULL((SELECT SUM([Cube]) FROM PACKINFO WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo),0)
         ,ArchiveCop = NULL
         ,EditWho = SUSER_NAME()
         ,EditDate= GETDATE()
      WHERE PickSlipNo = @c_PickSlipNo

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63343
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Update PACKHEADER Fail. (ispUPPSO01)' 
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

      IF @b_discrete = 1 
      BEGIN
         DECLARE CUR_PCKINFO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
         SELECT PH.Storerkey
               ,PACK.CartonNo
               ,SUM(PACK.Qty * SKU.StdGrossWgt)
         FROM PACKHEADER PH   WITH (NOLOCK) 
         JOIN PACKDETAIL PACK WITH (NOLOCK) ON (PH.PickSlipNo = PACK.PickSlipNo)
         JOIN SKU        SKU  WITH (NOLOCK) ON (PACK.Storerkey = SKU.Storerkey) AND (PACK.Sku = SKU.Sku)
         WHERE PH.Orderkey = @c_PORderkey
         GROUP BY PH.Storerkey, PACK.CartonNo
         ORDER BY PACK.CartonNo
      END
      ELSE
      BEGIN
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
      END
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
         SELECT @n_Cube = ISNULL(C.[Cube],0)  
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
         ,[Cube]   = @n_TotCube
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
         ,[Cube]    = @n_TotCube
         ,Weight  = @n_TotWeight
         ,Trafficcop = NULL
         ,EditWho = SUSER_NAME() 
         ,EditDate= GETDATE()
      WHERE MBOLKey = @c_MBOLKey
      AND   Orderkey= @c_POrderKey

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63344
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
      IF @b_discrete = 1 
      BEGIN
         INSERT INTO #TMPPACK (PickSlipNo, LabelNo, CartonNo, [WEIGHT], [CUBE])  
         SELECT DISTINCT PH.PickSlipNo, PACK.LabelNo, PACK.CartonNo,0, 0  
         FROM PACKHEADER PH   WITH (NOLOCK)  
         JOIN PACKDETAIL PACK WITH (NOLOCK) ON (PH.PickSlipNo = PACK.PickSlipNo)
         JOIN MBOLDETAIL MD   WITH (NOLOCK) ON (PH.OrderKey = MD.OrderKey)  
         WHERE MD.MbolKey = @c_MBOLKey 
      END
      ELSE
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
      END 

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
             MBOL.[Cube]  = PK.[Cube],  
             MBOL.CaseCnt = PK.CaseCnt,  
             EditWho = SUSER_NAME(),  
             EditDate= GETDATE(), 
             TrafficCop=NULL  
      FROM MBOL  
      JOIN (SELECT @c_MBOLKey AS MBOLKEY, SUM(WEIGHT) AS Weight, SUM([CUBE]) AS 'Cube', COUNT(1) AS CaseCnt  
            FROM #TMPPACK) AS PK ON MBOL.MbolKey = PK.MbolKey  
      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63345
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

   IF @n_Continue = 3
   BEGIN
       SET @b_success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispUPPSO01'  
   END   
END  

GO