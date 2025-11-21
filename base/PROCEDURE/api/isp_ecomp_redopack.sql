SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/  
/* Trigger: [API].[isp_ECOMP_RedoPack]                                  */  
/* Creation Date: 26-APR-2016                                           */  
/* Copyright: Maersk                                                    */  
/* Written by: Maersk                                                   */  
/*                                                                      */  
/* Purpose: SOS#361901 - New ECOM Packing                               */  
/*        :                                                             */  
/* Called By:  n_cst_packheader_ecom                                    */  
/*          :  ue_redopack                                              */  
/* PVCS Version: 1.3                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author    Purposes                                       */  
/* 11-Apr-2023 Allen     #JIRA PAC-4 Initial                            */
/* 13-Dec-2023 Alex      #JIRA PAC-301 Delete PickHeader when Redo      */
/* 10-Sep-2024 Alex01    #PAC-353 - Bundle Packing validation           */
/************************************************************************/  
CREATE   PROC [API].[isp_ECOMP_RedoPack]
            @c_PickSlipNo NVARCHAR(10)         
         ,  @b_Success     INT = 0           OUTPUT   
         ,  @n_err         INT = 0           OUTPUT   
         ,  @c_errmsg      NVARCHAR(255) = ''OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE    
           @n_StartTCnt       INT  
         , @n_Continue        INT  
  
         --(Wan01) - START  
         , @c_TaskBatchNo     NVARCHAR(10)  
         , @c_Orderkey        NVARCHAR(10)   
         , @n_RowRef          BIGINT  
         --(Wan01) - END  
  
         , @n_CartonNo              INT            --(Wan02)  
         , @c_Facility              NVARCHAR(5)    --(Wan02)  
         , @c_Storerkey             NVARCHAR(15)   --(Wan02)  
         , @c_authority             NVARCHAR(30)   --(Wan02)  
         , @c_CTNTrackNoReverse_SP  NVARCHAR(30)   --(Wan02)  
         , @c_SQL                   NVARCHAR(MAX)  --(Wan02)  
         , @c_SQLParms              NVARCHAR(MAX)  --(Wan02)  
  
         , @c_EPACKVASActivity      NVARCHAR(30)   --(Wan03)  
         , @cur_ODR                 CURSOR         --(Wan03)  
         , @n_PackDetailInfoKey     BIGINT
  
   --SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
   SET @n_err      = 0  
   SET @c_errmsg   = ''  
  
   -- (Wan01) - START  
   SET @c_TaskBatchNo = ''  
   SET @c_Orderkey = ''  
   SELECT @c_TaskBatchNo = ISNULL(RTRIM(TaskBatchNo),'')  
         ,@c_Orderkey = ISNULL(RTRIM(Orderkey),'')  
   FROM PACKHEADER WITH (NOLOCK)  
   WHERE PickSlipNo = @c_PickSlipNo  
   -- (Wan01) - END  
  
   --(Wan02) - START  
   SET @c_Facility = ''  
   SET @c_StorerKey= ''  
   SELECT @c_Facility = Facility  
      ,   @c_StorerKey = Storerkey  
   FROM ORDERS WITH (NOLOCK)   
   WHERE Orderkey = @c_Orderkey  
  
   SET @c_authority = ''  
   EXEC nspGetRight        
         @c_Facility  = @c_Facility       
      ,  @c_StorerKey = @c_StorerKey        
      ,  @c_sku       = NULL        
      ,  @c_ConfigKey = 'EPACKCTNTrackNoReverse_SP'        
      ,  @b_Success   = @b_Success    OUTPUT        
      ,  @c_authority = @c_authority  OUTPUT        
      ,  @n_err       = @n_err        OUTPUT        
      ,  @c_errmsg    = @c_errmsg     OUTPUT  
   --(Wan02) - END  
  
   --BEGIN TRAN  
  
   --(Wan04) - START  
   SET @b_Success = 0        
   EXECUTE dbo.isp_PreRedoPack_Wrapper       
           @c_PickSlipNo= @c_PickSlipNo      
         , @b_Success   = @b_Success     OUTPUT        
         , @n_Err       = @n_err         OUTPUT         
         , @c_ErrMsg    = @c_errmsg      OUTPUT        
      
   IF @n_err <> 0        
   BEGIN       
      SET @n_continue= 3       
      SET @n_err = 60090      
      SET @c_errmsg = CONVERT(char(5),@n_err)      
      SET @c_errmsg = 'NSQL'+CONVERT(char(6), @n_err)+ ': Execute isp_PreRedoPack_Wrapper Failed. (isp_ECOMP_RedoPack) '       
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '      
      GOTO QUIT                            
   END       
   --(Wan04) - END  
  
   --(Wan02) - START  
   SET @c_CTNTrackNoReverse_SP = ''  
   IF EXISTS ( SELECT 1 FROM dbo.sysobjects   
               WHERE name = @c_authority  
               AND Type = 'P'  
         )  
   BEGIN  
      SET @c_CTNTrackNoReverse_SP = RTRIM(@c_authority)  
   END   
  
   DECLARE CUR_PACKINFO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT CartonNo   
   FROM   PACKINFO WITH (NOLOCK)  
   WHERE  PickSlipNo = @c_PickSlipNo  
   OPEN CUR_PACKINFO  
     
   FETCH NEXT FROM CUR_PACKINFO INTO @n_CartonNo  
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      IF @c_CTNTrackNoReverse_SP <> ''  
      BEGIN  
         SET @c_SQL =N'EXEC ' + @c_CTNTrackNoReverse_SP       
                    + ' @c_PickSlipNo, @n_CartonNo, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT'          
  
         SET @c_SQLParms = N'@c_PickSlipNo NVARCHAR(10)'  
                         +', @n_CartonNo  INT'  
                         +', @b_Success   INT OUTPUT'  
                         +', @n_err       INT OUTPUT'  
                         +', @c_errmsg    NVARCHAR(255) OUTPUT'  
                               
         EXEC sp_executesql @c_SQL            
               ,  @c_SQLParms    
               ,  @c_PickSlipNo   
               ,  @n_CartonNo           
               ,  @b_Success   OUTPUT  
               ,  @n_err       OUTPUT  
               ,  @c_errmsg    OUTPUT   
         
         IF @b_Success <> 1  
         BEGIN    
            SET @n_continue = 3  
            SET @n_err = 60005   
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing ' + @c_CTNTrackNoReverse_SP + '. (isp_ECOMP_RedoPack)'   
                         + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
            GOTO QUIT  
         END                                                                 
      END  
      FETCH NEXT FROM CUR_PACKINFO INTO @n_CartonNo  
   END  
   CLOSE CUR_PACKINFO  
   DEALLOCATE CUR_PACKINFO  
   --(Wan02) - END  
  
   --(Wan03) - START  
   SET @c_EPACKVASActivity = ''  
   EXEC nspGetRight        
         @c_Facility  = @c_Facility       
      ,  @c_StorerKey = @c_StorerKey        
      ,  @c_sku       = NULL        
      ,  @c_ConfigKey = 'EPACKVASActivity'        
      ,  @b_Success   = @b_Success           OUTPUT        
      ,  @c_authority = @c_EPACKVASActivity  OUTPUT        
      ,  @n_err       = @n_err               OUTPUT        
      ,  @c_errmsg    = @c_errmsg            OUTPUT  
  
   IF @c_EPACKVASActivity = '1'  
   BEGIN  
      SET @cur_ODR = CURSOR FAST_FORWARD READ_ONLY FOR        
         SELECT ODR.RowRef  
         FROM ORDERDETAILREF ODR WITH (NOLOCK)   
         WHERE ODR.Orderkey = @c_Orderkey  
         AND   ODR.RefType  = 'PI'  
  
      OPEN @cur_ODR  
      FETCH NEXT FROM @cur_ODR INTO @n_RowRef  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         UPDATE ORDERDETAILREF WITH (ROWLOCK)  
            SET PackCnt = 0  
               ,EditWho = SUSER_SNAME()  
               ,EditDate = GETDATE()  
               ,TrafficCop = NULL  
         WHERE RowRef = @n_RowRef  
  
         SET @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN  
            SET @n_continue = 3  
            SET @n_err = 60008   
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update ORDERDETAILREF Table. (isp_ECOMP_RedoPack)'   
                         + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
            GOTO QUIT  
         END  
  
         FETCH NEXT FROM @cur_ODR INTO @n_RowRef  
      END  
   END  
   --(Wan03) - END  
  
   --(Alex01) - Start
   DECLARE CUR_PTDI CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT PackDetailInfoKey   
   FROM PackDetailInfo WITH (NOLOCK)  
   WHERE PickSlipNo = @c_PickSlipNo
  
   OPEN CUR_PTDI  
     
   FETCH NEXT FROM CUR_PTDI INTO @n_PackDetailInfoKey  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      DELETE FROM PACKDETAILINFO
      WHERE PackDetailInfoKey = @n_PackDetailInfoKey
  
      FETCH NEXT FROM CUR_PTDI INTO @n_PackDetailInfoKey  
   END   
   CLOSE CUR_PTDI  
   DEALLOCATE CUR_PTDI  
   --(Alex01) - Start

   DELETE PACKDETAIL WITH (ROWLOCK)  
   WHERE PickSlipNo = @c_PickSlipNo  
  
   SET @n_err = @@ERROR  
   IF @n_err <> 0  
   BEGIN  
      SET @n_continue = 3  
      SET @n_err = 60010    
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Delete PACKDETAIL Table. (isp_ECOMP_RedoPack)'   
                   + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
      GOTO QUIT  
   END  
  
   DELETE PACKHEADER WITH (ROWLOCK)  
   WHERE PickSlipNo = @c_PickSlipNo  
  
   SET @n_err = @@ERROR  
   IF @n_err <> 0  
   BEGIN  
      SET @n_continue = 3  
      SET @n_err = 60020    
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Delete PACKHEADER Table. (isp_ECOMP_RedoPack)'   
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
      GOTO QUIT  
   END    
     
   -- (Wan01) - START  
   IF @c_Orderkey = ''  
   BEGIN  
      GOTO QUIT  
   END  
   
   DELETE FROM PICKHEADER WITH (ROWLOCK) 
   WHERE PickHeaderKey = @c_PickSlipNo

   DECLARE CUR_PTD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT RowRef   
   FROM PACKTASKDETAIL WITH (NOLOCK)  
   WHERE TaskBatchNo = @c_TaskBatchNo  
   AND   Orderkey = @c_Orderkey  
  
   OPEN CUR_PTD  
     
   FETCH NEXT FROM CUR_PTD INTO @n_RowRef  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      UPDATE PACKTASKDETAIL WITH (ROWLOCK)  
      SET Status     = '0'  
         ,PickSlipNo = ''  
         ,EditWho    = SUSER_NAME()  
         ,EditDate   = GETDATE()  
         ,TrafficCop = NULL  
      WHERE RowRef = @n_RowRef   
  
      SET @n_err = @@ERROR  
      IF @n_err <> 0  
      BEGIN  
         SET @n_continue = 3  
         SET @n_err = 60030  
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update PACKTASKDETAIL Table. (isp_ECOMP_RedoPack)'   
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
         GOTO QUIT  
      END  
  
      FETCH NEXT FROM CUR_PTD INTO @n_RowRef  
   END   
   CLOSE CUR_PTD  
   DEALLOCATE CUR_PTD   
   -- (Wan01) -  END  
  
QUIT:  
   -- (Wan01) -  START  
   IF CURSOR_STATUS( 'LOCAL', 'CUR_PTD') in (0 , 1)    
   BEGIN  
      CLOSE CUR_PTD  
      DEALLOCATE CUR_PTD  
   END  
   -- (Wan01) -  END  
  
   -- (Wan02) -  START  
   IF CURSOR_STATUS( 'LOCAL', 'CUR_PACKINFO') in (0 , 1)    
   BEGIN  
      CLOSE CUR_PACKINFO  
      DEALLOCATE CUR_PACKINFO  
   END  

   IF CURSOR_STATUS( 'LOCAL', 'CUR_PTDI') in (0 , 1)    
   BEGIN  
      CLOSE CUR_PTDI  
      DEALLOCATE CUR_PTDI  
   END  
   
   -- (Wan02) -  END  
  
   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_Success = 0  
      --IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
      --BEGIN  
      --   ROLLBACK TRAN  
      --END  
      --ELSE  
      --BEGIN  
      --   WHILE @@TRANCOUNT > @n_StartTCnt  
      --   BEGIN  
      --      COMMIT TRAN  
      --   END  
      --END  
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ECOMP_RedoPack'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      --WHILE @@TRANCOUNT > @n_StartTCnt  
      --BEGIN  
      --   COMMIT TRAN  
      --END  
   END  
END -- procedure  
GO