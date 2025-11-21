SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispUPPSO02                                         */  
/* Creation Date: 23-May-2019                                           */  
/* Copyright: IDS                                                       */  
/* Written by: Shong                                                    */  
/*                                                                      */  
/* Purpose: WMS-9149 Un pick & pack Orders                              */  
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
/* Date        Author   Ver  Purposes                                   */ 
/* 2020-06-04  Wan      1.1  WMS-13120 - [PH] NIKE - WMS UnPacking Module*/ 
/************************************************************************/   
CREATE PROCEDURE [dbo].[ispUPPSO02]  
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
         , @c_UCCNo           NVARCHAR(20)
         , @c_Packkey         NVARCHAR(10)
         , @c_UOM             NVARCHAR(10)   
         , @n_Qty             INT

         , @b_OpenPack        INT
         , @n_CartonNo        INT
         , @n_PackQty         INT
         , @c_LoadStatus      NVARCHAR(10)
         , @c_PickStatus      NVARCHAR(10)
         , @c_PackStatus      NVARCHAR(10)

         , @b_Discrete        INT
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
   SET @c_UCCNo        = '' 
   SET @c_Packkey       = ''
   SET @c_UOM           = ''
   SET @n_Qty           = 0
   
   SET @b_OpenPack      = 0
   SET @n_CartonNo      = 0
   SET @n_PackQty       = 0
   SET @c_UCCNo       = ''
   SET @c_LoadStatus    = '3'
   SET @c_PickStatus    = '0'
   SET @c_PackStatus    = '0'  

   SET @b_Discrete = 0
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

   CREATE TABLE #UCC 
      (  UCCNo NVARCHAR(20) NOT NULL DEFAULT('') )

   IF ISNULL(RTRIM(@c_OrderKey),'') = ''
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 64401
      SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Order Key Cannot be Blank. (ispUPPSO02)' 
      GOTO QUIT_SP
   END   	 
          

   SET @c_PickSlipNo = ''
   SELECT @c_PickSlipNo = PickHeaderKey
   FROM PICKHEADER WITH (NOLOCK)
   WHERE Orderkey = @c_Orderkey
   
   DECLARE CUR_UCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT u.UCCNo
   FROM PackDetail PD WITH (NOLOCK) 
   JOIN UCC AS u WITH(NOLOCK) ON pd.LabelNo = u.UCCNo 
   WHERE PD.PickSlipNo = @c_PickSlipNo 
   AND u.[Status] IN ('5','6','7','8','9') 
   
   OPEN CUR_UCC
   
   FETCH FROM CUR_UCC INTO @c_UCCNo
   
   WHILE @@FETCH_STATUS = 0
   BEGIN
   	UPDATE UCC WITH (ROWLOCK) 
   	   SET [Status] = '1', 
   	       TrafficCop = NULL, 
   	       EditDate = GETDATE(), 
   	       EditWho = SUSER_SNAME() 
   	WHERE UCCNo = @c_UCCNo 
      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 64402
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Update UCC Fail. (ispUPPSO02)' 
         GOTO QUIT_SP
      END   	
   
   	FETCH FROM CUR_UCC INTO @c_UCCNo
   END   
   CLOSE CUR_UCC
   DEALLOCATE CUR_UCC
   
   IF @n_Continue IN (1,2)
   BEGIN
      DELETE PACKDETAIL WITH (ROWLOCK)
      WHERE PickSlipNo = @c_PickSlipNo 
      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 64403
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete Pack Detail fail. (ispUPPSO02)' 
         GOTO QUIT_SP
      END   	
   END   

   IF @n_Continue IN (1,2)
   BEGIN
      DELETE PackInfo WITH (ROWLOCK)
      WHERE PickSlipNo = @c_PickSlipNo 
      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 64404
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete Pack Info fail. (ispUPPSO02)' 
         GOTO QUIT_SP
      END   	   	
   END   

   IF @n_Continue IN (1,2)
   BEGIN
      DELETE PACKHEADER WITH (ROWLOCK)
      WHERE PickSlipNo = @c_PickSlipNo 
      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 64405
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete Pack Header fail. (ispUPPSO02)' 
         GOTO QUIT_SP
      END   	   	
   END
      
   DECLARE CUR_PickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PickDetailKey
   FROM PICKDETAIL WITH (NOLOCK)
   WHERE OrderKey = @c_OrderKey 
   
   OPEN CUR_PickDetail
   
   FETCH FROM CUR_PickDetail INTO @c_PickDetailKey
   
   WHILE @@FETCH_STATUS = 0
   BEGIN
   	IF EXISTS(SELECT 1 FROM REFKEYLOOKUP WITH (NOLOCK)
   	          WHERE PickDetailkey = @c_PickDetailKey)
   	BEGIN
         DELETE REFKEYLOOKUP WITH (ROWLOCK)
         WHERE PickdetailKey = @c_Pickdetailkey  		
         IF @@ERROR <> 0
         BEGIN
            SET @n_continue= 3
            SET @n_err     = 64406
            SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete pickdetailkey from REFKEYLOOKUP fail. (ispUPPSO02)' 
            GOTO QUIT_SP
         END         
   	END

      DELETE PICKDETAIL WITH (ROWLOCK)
      WHERE PickDetailKey = @c_PickDetailKey

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 64407
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Unallocate PICKDETAIL Fail. (ispUPPSO02)' 
         GOTO QUIT_SP
      END   	
   
   	FETCH FROM CUR_PickDetail INTO @c_PickDetailKey
   END
   
   CLOSE CUR_PickDetail
   DEALLOCATE CUR_PickDetail

   IF @n_Continue IN (1,2)
   BEGIN
      DELETE PACKDETAIL WITH (ROWLOCK)
      WHERE PickSlipNo = @c_PickSlipNo 
      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 64408
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete Pack Detail fail. (ispUPPSO02)' 
         GOTO QUIT_SP
      END   	
   END   

   IF NOT EXISTS (SELECT 1 FROM PACKDETAIL WITH (NOLOCK) WHERE PickSlipNo = @c_PickslipNo)
   BEGIN
      DELETE PACKINFO WITH (ROWLOCK)
      WHERE PickSlipNo = @c_PickSlipNo

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 64409
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete PACKINFO Fail. (ispUPPSO02)' 
         GOTO QUIT_SP
      END

      DELETE PACKHEADER WITH (ROWLOCK)
      WHERE PickSlipNo = @c_PickSlipNo
      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 64410
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete PACKHEADER Fail. (ispUPPSO02)' 
         GOTO QUIT_SP
      END


      DELETE PICKINGINFO WITH (ROWLOCK)
      WHERE PickSlipNo = @c_PickSlipNo

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 64411
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete PICKINGINFO Fail. (ispUPPSO02)' 
         GOTO QUIT_SP
      END

      DELETE PICKHEADER WITH (ROWLOCK)
      WHERE PickHeaderkey = @c_PickSlipNo
      IF @@ERROR <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 64412
         SET @c_errmsg  ='NSQL'+CONVERT(char(5),@n_err)+': Delete PICKHEADER Fail. (ispUPPSO02)' 
         GOTO QUIT_SP
      END 
   END


   QUIT_SP:

   IF @n_Continue = 3
   BEGIN
       SET @b_success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispUPPSO02'  
   END   
END  

GO